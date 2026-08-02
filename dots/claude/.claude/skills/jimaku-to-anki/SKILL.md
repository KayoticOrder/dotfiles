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

3. **Generate a plan**, asking for a few more words than the user actually
   wants (curation below will drop some):
   ```
   cd ~/anki-vocab-builder
   python3 anki_vocab.py plan --input /tmp/jimaku-subs/<file>.srt --top <N+10> --out /tmp/jimaku-subs/<show>-plan.json
   ```
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

4. **Curate down to the words the user actually wants**: drop flagged
   character names (unless the user actually wants show-specific names
   carded), skip words that are too basic/grammatical to be worth a card,
   and take the next-highest-frequency real words to backfill. Check each
   remaining entry's `"sentence"` field — if it reads as a sentence
   fragment lacking context, search the original `.srt` for a fuller line
   containing that word (`grep -n "<word>" file.srt`, then read a few lines
   of surrounding context) and use that instead.

5. **Translate.** Fill in each entry's `"translation"` field yourself — this
   is exactly the step the plan file's docstring expects an LLM to do. Keep
   translations natural, not word-for-word.

6. **Preview, then add.** Deck names should nest under `studyy::` to match
   the user's existing hierarchy (e.g. `studyy::Show S1E01`):
   ```
   python3 anki_vocab.py add --plan /tmp/jimaku-subs/<show>-plan.json --deck-name "studyy::<Show> S<season>E<episode>" --dry-run
   python3 anki_vocab.py add --plan /tmp/jimaku-subs/<show>-plan.json --deck-name "studyy::<Show> S<season>E<episode>"
   ```
   Report back a table of what was added (word, reading, meaning, example
   sentence) — don't just say "done".

## Notes

- `anki_vocab.py`'s `KNOWN_DECKS` (currently `studyy::Core 2000 rand`,
  `studyy::MigakuNew`) defines what counts as "already known" — pass
  `--known-decks` to override if the user wants a different baseline.
- Pronunciation audio is fetched automatically per word when available; a
  missing clip for an obscure/slang word is expected, not a bug.
- For a single one-off word (not tied to an episode), use `anki-add-card`
  instead — this skill is for episode/season-scale batches.
