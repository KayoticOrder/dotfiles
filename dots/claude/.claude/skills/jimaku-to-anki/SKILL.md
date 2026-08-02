---
name: jimaku-to-anki
description: Build Anki vocab cards from an anime episode's actual dialogue by pulling subtitles from Jimaku and running them through the frequency-based vocab builder. Use when the user asks for Anki/vocab cards for a specific show + episode (or season) — e.g. "make cards for the top 5 words in Frieren episode 3", "add vocab from re zero ep 1 to anki", "build a deck from this episode's subs".
---

# Jimaku subtitles -> Anki vocab deck

Chains two existing tools: the `jimaku-search` skill (fetches subtitle
files) and `~/anki-vocab-builder/anki_vocab.py` (frequency-ranks unknown
words against the user's existing decks, drafts n+1 example sentences).
The gap between them — picking the right entry, discarding character
names, translating — needs an LLM in the loop each time; this skill is
that orchestration, not a fully unattended script.

## Prerequisites

- AnkiConnect reachable: `curl -s http://localhost:8765 -X POST -d '{"action":"version","version":6}'`.
  If it fails, tell the user to open Anki and stop.
- Jimaku API key set up (see the `jimaku-search` skill) — same key resolution applies.

## Workflow

1. **Search & pick the entry.** Use the `jimaku-search` skill's script to find
   the show and resolve to an entry ID. If the user names a specific season,
   match it in the entry name (Jimaku has no separate season field — sequels
   are separate entries, e.g. "... 2nd Season").

2. **Download the episode's subtitles** to `/tmp/jimaku-subs/` (same
   convention as the `jimaku-search` skill — tmpfs, auto-cleared). Prefer a
   plain Japanese-only `.srt` over multi-episode/combined-cut files or
   dual-language `.ass` files when multiple options exist — a clean single
   track tokenizes better than one with heavy styling tags.

3. **Check the Migaku known-word export is fresh.** `anki_vocab.py plan`
   auto-loads the newest `~/Downloads/migaku_core_export*.sqlite` and excludes
   anything KNOWN, IGNORED, or `tracked=1` there (the user's personal marker
   for "I already made a card for this"), in addition to the Anki deck check.
   Its console output prints `[!stale - exported Nd ago...]` if that file is
   more than 3 days old. If it's stale or missing, pull a fresh one yourself
   (fully automatable — no manual clicking needed):

   a. Load the `claude-in-chrome` skill if its tools aren't loaded yet.
   b. Get/create a tab and navigate to `https://study.migaku.com/word-browser`
      (the user must already be logged in there in their normal Chrome profile).
   c. Run this via `javascript_tool` against that tab — it reads Migaku's own
      local IndexedDB (`srs` DB, `data` store), decompresses the gzip'd SQLite
      blob with the browser's native `DecompressionStream`, and triggers a
      real file download (lands in `~/Downloads/migaku_core_export.sqlite`,
      Chrome auto-suffixes `(1)`, `(2)`, ... on repeats — the glob picks the
      newest):
      ```js
      const db = await new Promise((resolve, reject) => {
        const req = indexedDB.open('srs');
        req.onsuccess = () => resolve(req.result);
        req.onerror = () => reject(req.error);
      });
      const tx = db.transaction('data', 'readonly');
      const all = await new Promise((resolve, reject) => {
        const req = tx.objectStore('data').getAll();
        req.onsuccess = () => resolve(req.result);
        req.onerror = () => reject(req.error);
      });
      db.close();
      const item = all[0];
      const bytes = new Uint8Array(item.data);
      let decompressed = bytes;
      if (bytes[0] === 0x1f && bytes[1] === 0x8b) {
        const ds = new DecompressionStream('gzip');
        const stream = new Blob([bytes]).stream().pipeThrough(ds);
        decompressed = new Uint8Array(await new Response(stream).arrayBuffer());
      }
      const blob = new Blob([decompressed], { type: 'application/octet-stream' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url; a.download = 'migaku_core_export.sqlite';
      document.body.appendChild(a); a.click(); a.remove();
      'triggered download of ' + decompressed.length + ' bytes';
      ```
   d. Confirm via Bash: `ls -t ~/Downloads/migaku_core_export*.sqlite | head -1`.

   This requires the user to have the official Migaku browser extension
   installed and logged in (it's what populates that IndexedDB) — no other
   extension or manual export tool is involved.

4. **Generate a plan**, asking for a few more words than the user actually
   wants (curation below will drop some):
   ```
   cd ~/anki-vocab-builder
   python3 anki_vocab.py plan --input /tmp/jimaku-subs/<file>.srt --top <N+10> --out /tmp/jimaku-subs/<show>-plan.json
   ```
   **Optional: rank by whole-series importance instead of just this episode**
   with `--jpdb-url`. Plain frequency-in-this-episode can surface trivial
   words (or, in early episodes, mostly character names) over words that
   matter to the show. To use it: go to `https://jpdb.io/anime-difficulty-list`,
   type the show's name into the search box, press Enter, follow "Show
   details..." for the right entry, and use that page's URL + `/vocabulary-list`
   (e.g. `https://jpdb.io/anime/3904/re-zero-kara-hajimeru-isekai-seikatsu/vocabulary-list`).
   Pass it as `--jpdb-url "<url>"`. This only changes which words get
   candidate-ranked (by frequency across the whole series, restricted to
   words that actually appear in this episode's subtitles) — it does **not**
   change where example sentences come from; those are still pulled from
   this episode's own subtitle file, so the same curation and sentence-fixing
   work in step 5 is still needed, sometimes more (a word can be important to
   the whole series while only appearing once in this particular episode,
   in a fragment with no usable sentence — drop it if so rather than forcing it).

   Console output flags each word:
   - `[?katakana - verify this isn't a character/place name before adding]` —
     sudachi can't reliably tell invented character names (e.g. isekai
     protagonist names) from real katakana vocab, since many are homophones
     of real words (スバル = Subaru/Pleiades, フェルト = felt fabric). Use your
     own knowledge of the show to judge these; when genuinely unsure, ask
     the user rather than guessing. Confirmed proper nouns sudachi's
     dictionary actually recognizes (real names/places) are already
     excluded automatically — this flag is only for the ones that slip
     through.
   - `[!n+1 - no clean sentence]` — no sentence exists where every other
     word is already known; the example sentence will contain other
     unfamiliar words too.

5. **Curate down to the words the user actually wants**: drop flagged
   character names (unless the user actually wants show-specific names
   carded), skip words that are too basic/grammatical to be worth a card,
   and take the next-highest-frequency real words to backfill. Check each
   remaining entry's `"sentence"` field — if it reads as a sentence
   fragment lacking context, search the original `.srt` for a fuller line
   containing that word (`grep -n "<word>" file.srt`, then read a few lines
   of surrounding context) and use that instead.

6. **Translate.** Fill in each entry's `"translation"` field yourself — this
   is exactly the step the plan file's docstring expects an LLM to do. Keep
   translations natural, not word-for-word.

7. **Dry-run, then show the user a review table before touching Anki.** These
   cards are permanent, so don't add for real without explicit go-ahead —
   this applies even if the user's original request sounded like a green
   light ("add cards for X"), since they haven't seen the actual curated
   words/sentences yet.
   ```
   python3 anki_vocab.py add --plan /tmp/jimaku-subs/<show>-plan.json --source-tag "<Show> S<season>E<episode>" --dry-run
   ```
   Present a table (word | reading | meaning | example sentence |
   translation), note the deck (`studyy::Claude` unless overridden) and tag,
   and call out anything you dropped or swapped during curation and why.
   Then stop and wait for the user to confirm or request changes.

8. **Add for real, only after the user confirms.** Same command without
   `--dry-run`:
   ```
   python3 anki_vocab.py add --plan /tmp/jimaku-subs/<show>-plan.json --source-tag "<Show> S<season>E<episode>"
   ```
   All Claude-generated cards land in the shared `studyy::Claude` deck
   (`anki_vocab.py add`'s default — don't pass `--deck-name` unless the user
   specifically asks for a separate deck). Report back what was actually
   added (and anything skipped as a duplicate) — don't just say "done".

## Notes

- `anki_vocab.py`'s `KNOWN_DECKS` (currently `studyy::Core 2000 rand`,
  `studyy::MigakuNew`, and `studyy::Claude` itself) defines what counts as
  "already known" — pass `--known-decks` to override if the user wants a
  different baseline. `--migaku-export <path>` overrides which export file
  to use; `--no-migaku` skips it entirely.
- Pronunciation audio is fetched automatically per word when available; a
  missing clip for an obscure/slang word is expected, not a bug.
- For a single one-off word (not tied to an episode), use `anki-add-card`
  instead — this skill is for episode/season-scale batches. Both skills now
  share the same `studyy::Claude` deck.
