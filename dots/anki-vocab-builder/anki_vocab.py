#!/usr/bin/env python3
"""
Generate Anki vocab cards from a piece of Japanese media (subtitles + optionally
a jpdb.io vocabulary-list URL for that media), skipping words already present in
your existing decks (or marked known/ignored/tracked in a Migaku core DB export --
see MIGAKU_DB_GLOB), with n+1 example sentences and word-pronunciation audio.

Two-step workflow (so sentence translations can be filled in by an LLM in between):

  1) plan: pick words + n+1 sentences, write a plan file, no Anki writes yet.
       python3 anki_vocab.py plan --input subs.srt --top 25 --out plan.json
       python3 anki_vocab.py plan --input subs.srt --jpdb-url "https://jpdb.io/anime/.../vocabulary-list" --top 25 --out plan.json

  2) (fill in plan.json's "translation" fields, e.g. by having an LLM translate
      each "sentence")

  3) add: build & push cards to Anki, using the plan (+ translations if present).
     Defaults to the shared CLAUDE_DECK; pass --source-tag to keep the source
     (e.g. show/episode) identifiable via a tag instead of a separate deck.
       python3 anki_vocab.py add --plan plan.json --source-tag "Show S1E1" [--dry-run]

Requires Anki running with AnkiConnect, and network access for jisho.org /
jpdb.io / the pronunciation-audio endpoint.
"""
import argparse
import base64
import glob
import hashlib
import html
import json
import os
import re
import sqlite3
import sys
import time
import urllib.parse
import urllib.request
from collections import Counter
from datetime import datetime, timezone

ANKI_CONNECT_URL = "http://localhost:8765"
CLAUDE_DECK = "studyy::Claude"  # where all Claude-created cards land, from any skill
KNOWN_DECKS = ["studyy::Core 2000 rand", "studyy::MigakuNew", CLAUDE_DECK]
NEW_CARD_MODEL = "Lapis"
ALLOWED_POS = {"名詞", "動詞", "形容詞", "形状詞", "副詞"}
JISHO_API = "https://jisho.org/api/v1/search/words?keyword="
AUDIO_API = "https://assets.languagepod101.com/dictionary/japanese/audiomp3.php?kanji={}&kana={}"
# MD5 of the fixed "word not in database" placeholder clip languagepod101 returns for unknown words
AUDIO_PLACEHOLDER_MD5 = "7e2c2f954ef6051373ba916f000168dc"

# The official Migaku browser extension stores its local SRS data as gzip'd
# SQLite blobs in the "srs" IndexedDB database on the study.migaku.com origin
# (object store "data", one row per synced DB file). This is pulled and
# decompressed via a JS snippet run against that page (see jimaku-to-anki
# skill notes), which is how WordList.tracked ends up available here -- it's
# not exposed through Migaku's own UI as an exportable field. The glob picks
# up whatever was last downloaded -- Chrome appends " (1)", " (2)", etc. on
# repeat downloads.
MIGAKU_DB_GLOB = os.path.expanduser("~/Downloads/migaku_core_export*.sqlite")
MIGAKU_EXCLUDE_STATUSES = {"KNOWN", "IGNORED"}
MIGAKU_STALE_DAYS = 3


# ---------------------------------------------------------------- AnkiConnect

def anki_request(action, **params):
    payload = json.dumps({"action": action, "version": 6, "params": params}).encode("utf-8")
    req = urllib.request.Request(ANKI_CONNECT_URL, payload)
    with urllib.request.urlopen(req) as resp:
        result = json.load(resp)
    if result.get("error") is not None:
        raise RuntimeError(f"AnkiConnect error on {action}: {result['error']}")
    return result["result"]


def strip_furigana_brackets(field_value):
    """'意外[いがい;h,a]' -> '意外'. Plain strings pass through unchanged."""
    return re.split(r"[\[［]", field_value)[0].strip()


def get_known_words(decks):
    known = set()
    for deck in decks:
        note_ids = anki_request("findNotes", query=f'deck:"{deck}"')
        if not note_ids:
            print(f"  warning: no notes found in deck '{deck}'", file=sys.stderr)
            continue
        infos = []
        for i in range(0, len(note_ids), 500):
            infos.extend(anki_request("notesInfo", notes=note_ids[i:i + 500]))
        for note in infos:
            fields = note["fields"]
            for key in ("Target Word", "Vocabulary-Kanji", "Expression", "Vocabulary-Kana"):
                if key in fields and fields[key]["value"].strip():
                    known.add(strip_furigana_brackets(fields[key]["value"]))
        print(f"  {deck}: {len(infos)} notes")
    return known


def find_latest_migaku_export():
    matches = glob.glob(MIGAKU_DB_GLOB)
    return max(matches, key=os.path.getmtime) if matches else None


def load_migaku_known(path):
    """Returns (words, exported_at) from a raw Migaku core SQLite DB export.
    words is the set to exclude from new-card candidates: anything KNOWN,
    IGNORED, or flagged tracked=1 (the user's personal marker for "I already
    made an Anki card for this"). Plain UNKNOWN/LEARNING words are left as
    candidates -- those are exactly what the user still wants to learn.
    exported_at is the file's mtime (the DB itself has no export timestamp)."""
    con = sqlite3.connect(path)
    try:
        cur = con.execute("SELECT dictForm, knownStatus, tracked FROM WordList WHERE del = 0")
        words = {
            dict_form
            for dict_form, known_status, tracked in cur.fetchall()
            if known_status in MIGAKU_EXCLUDE_STATUSES or tracked
        }
    finally:
        con.close()
    exported_at = datetime.fromtimestamp(os.path.getmtime(path), tz=timezone.utc).isoformat()
    return words, exported_at


# ---------------------------------------------------------------- media text loading

SRT_TIMESTAMP = re.compile(r"\d{2}:\d{2}:\d{2}[,.]\d{3}\s*-->\s*\d{2}:\d{2}:\d{2}[,.]\d{3}")
SRT_INDEX = re.compile(r"^\d+$")
HTML_TAG = re.compile(r"<[^>]+>")
ASS_TAG = re.compile(r"\{[^}]*\}")


def load_text(path):
    with open(path, encoding="utf-8", errors="ignore") as f:
        raw = f.read()

    ext = path.lower().rsplit(".", 1)[-1] if "." in path else ""

    if ext in ("srt", "vtt"):
        lines = []
        for line in raw.splitlines():
            line = line.strip()
            if not line or SRT_TIMESTAMP.search(line) or SRT_INDEX.match(line):
                continue
            if line.upper().startswith("WEBVTT"):
                continue
            lines.append(HTML_TAG.sub("", line))
        return "\n".join(lines)

    if ext == "ass":
        lines = []
        for line in raw.splitlines():
            if not line.startswith("Dialogue:"):
                continue
            parts = line.split(",", 9)
            if len(parts) == 10:
                text = ASS_TAG.sub("", parts[9])
                text = text.replace("\\N", " ").replace("\\n", " ")
                lines.append(text)
        return "\n".join(lines)

    return raw


SENTENCE_SPLIT = re.compile(r"[。！？\n]")
KATAKANA_ONLY = re.compile(r"^[ァ-ヶーヽヾ]+$")


def katakana_to_hiragana(text):
    """SudachiPy's reading_form() returns katakana by convention; the rest of
    this pipeline (jisho lookups, existing cards) uses hiragana, so normalize."""
    return "".join(chr(ord(c) - 0x60) if "ァ" <= c <= "ヶ" else c for c in text)


def tokenize_and_count(text):
    """Returns:
    counts: Counter of lemma -> frequency across the whole media
    lemma_surface: lemma -> a representative inflected surface form
    lemma_reading: lemma -> kana reading
    sentence_words: list of (sentence_text, [(lemma, surface), ...content words...])
      one entry per sentence, used later for n+1 example-sentence selection
    """
    from sudachipy import tokenizer, dictionary
    tok = dictionary.Dictionary().create()
    mode = tokenizer.Tokenizer.SplitMode.C

    sentences = [s.strip() for s in SENTENCE_SPLIT.split(text) if s.strip()]

    counts = Counter()
    lemma_surface = {}
    lemma_reading = {}
    sentence_words = []

    for sent in sentences:
        if len(sent) > 300:  # skip runaway lines (e.g. malformed subtitle blocks)
            continue
        words_in_sentence = []
        for m in tok.tokenize(sent, mode):
            pos = m.part_of_speech()
            major = pos[0]
            if major not in ALLOWED_POS:
                continue
            # Skip words sudachi's dictionary confidently recognizes as proper
            # nouns (place/person names etc). Note this only catches names
            # sudachi actually knows -- invented character names it doesn't
            # recognize get tagged as ordinary common nouns and slip through;
            # see the katakana-only "flag" in cmd_plan for those.
            if major == "名詞" and pos[1] == "固有名詞":
                continue
            lemma = m.dictionary_form()
            surface = m.surface()
            if len(lemma) < 2 and major != "動詞":
                continue
            if not re.search(r"[぀-ヿ一-鿿]", lemma):
                continue
            counts[lemma] += 1
            lemma_surface.setdefault(lemma, surface)
            reading = m.reading_form()
            if not KATAKANA_ONLY.match(lemma):
                reading = katakana_to_hiragana(reading)
            lemma_reading.setdefault(lemma, reading)
            words_in_sentence.append((lemma, surface))
        if words_in_sentence:
            sentence_words.append((sent, words_in_sentence))

    return counts, lemma_surface, lemma_reading, sentence_words


MIN_SENTENCE_LEN = 6  # avoid picking degenerate "sentences" that are just the word itself
MIN_OTHER_CONTENT_WORDS = 1  # require real supporting context, not just the target word alone
# Subtitle "sentences" are split on line breaks as well as 。！？, so a lot of
# candidates are actually mid-clause fragments cut off where the subtitle cue
# happened to end (e.g. "...には", "...なら"). These endings are a strong tell
# that the clause continues past this fragment rather than standing alone.
INCOMPLETE_ENDINGS = ("には", "なら", "ので", "たら", "けれども", "けれど", "けど", "って", "ながら", "し")


def pick_n_plus_1_sentence(target_lemma, sentence_words, known):
    """Find a sentence containing target_lemma where every OTHER content word
    is already known. Falls back to the candidate with fewest unknown extra
    words if no clean n+1 sentence exists. Prefers sentences with real
    supporting context that don't look grammatically cut off mid-clause,
    falling back tier by tier if nothing qualifies. Returns (sentence,
    surface, is_clean)."""
    candidates = []
    for sent, words in sentence_words:
        target_surfaces = [surf for lem, surf in words if lem == target_lemma]
        if not target_surfaces:
            continue
        other_lemmas = [lem for lem, surf in words if lem != target_lemma]
        unknown = [lem for lem in other_lemmas if lem not in known]
        cut_off = sent.endswith(INCOMPLETE_ENDINGS)
        candidates.append((len(unknown), len(other_lemmas), len(sent), sent, target_surfaces[0], cut_off))

    if not candidates:
        return None, None, False

    # Fewest unknown words first (the n+1 constraint), then richer context, then shorter.
    candidates.sort(key=lambda c: (c[0], -c[1], c[2]))
    substantial = [c for c in candidates if c[1] >= MIN_OTHER_CONTENT_WORDS and not c[5]]
    with_context = [c for c in candidates if c[1] >= MIN_OTHER_CONTENT_WORDS]
    with_length = [c for c in candidates if c[2] >= MIN_SENTENCE_LEN]
    unknown_count, _, _, sent, surface, _ = (substantial or with_context or with_length or candidates)[0]
    return sent, surface, unknown_count == 0


# ---------------------------------------------------------------- jpdb.io vocabulary lists

JPDB_ENTRY_RE = re.compile(
    r'<a href="/vocabulary/\d+/[^"#]+#a">(?P<ruby>.*?)</a>.*?'
    r'</div></div><div>(?P<meaning>[^<]*)</div></div><div><div></div>'
    r'<div style="opacity: 0\.5; margin-top: 1rem;">(?P<count>\d+)</div>',
    re.DOTALL,
)
RUBY_RE = re.compile(r"<ruby>(?P<base>[^<]*)(?:<rt>(?P<reading>[^<]*)</rt>)?</ruby>")
TOTAL_ENTRIES_RE = re.compile(r"from (\d+) entries")


def parse_jpdb_page(page_html):
    entries = []
    for m in JPDB_ENTRY_RE.finditer(page_html):
        ruby_html = m.group("ruby")
        word = ""
        reading = ""
        for rm in RUBY_RE.finditer(ruby_html):
            base = html.unescape(rm.group("base") or "")
            word += base
            reading += html.unescape(rm.group("reading")) if rm.group("reading") else base
        meaning = html.unescape(m.group("meaning")).strip()
        meanings = [s.strip() for s in meaning.split(";") if s.strip()]
        entries.append({
            "word": word,
            "reading": reading,
            "meanings": meanings,
            "count": int(m.group("count")),
        })
    total_match = TOTAL_ENTRIES_RE.search(page_html)
    total = int(total_match.group(1)) if total_match else None
    return entries, total


def fetch_jpdb_vocab_list(url, max_pages=10):
    base = url.split("?")[0]
    all_entries = []
    offset = 0
    for page in range(max_pages):
        page_url = f"{base}?sort_by=by-frequency-local&offset={offset}"
        req = urllib.request.Request(page_url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            page_html = resp.read().decode("utf-8", errors="ignore")
        entries, total = parse_jpdb_page(page_html)
        if not entries:
            break
        all_entries.extend(entries)
        offset += 50
        if total is not None and offset >= total:
            break
        time.sleep(0.3)
    return all_entries


# ---------------------------------------------------------------- dictionary + audio lookups

def jisho_lookup(word):
    try:
        with urllib.request.urlopen(JISHO_API + urllib.parse.quote(word), timeout=8) as resp:
            data = json.load(resp)
    except Exception as e:
        print(f"  jisho lookup failed for {word}: {e}", file=sys.stderr)
        return None
    if not data.get("data"):
        return None
    entry = data["data"][0]
    reading = entry["japanese"][0].get("reading", "") if entry["japanese"] else ""
    defs = []
    for sense in entry["senses"][:2]:
        eng = sense.get("english_definitions", [])
        if eng:
            defs.append(", ".join(eng))
    return {"reading": reading, "definitions": defs}


def fetch_word_audio(lemma, reading):
    url = AUDIO_API.format(urllib.parse.quote(lemma), urllib.parse.quote(reading))
    try:
        with urllib.request.urlopen(url, timeout=8) as resp:
            data = resp.read()
    except Exception as e:
        print(f"  audio fetch failed for {lemma}: {e}", file=sys.stderr)
        return None
    if not data or hashlib.md5(data).hexdigest() == AUDIO_PLACEHOLDER_MD5:
        return None
    return data


def store_word_audio(lemma, reading, audio_bytes):
    filename = f"vocab-builder_{lemma}_{reading}.mp3"
    anki_request("storeMediaFile", filename=filename, data=base64.b64encode(audio_bytes).decode("ascii"))
    return filename


# ---------------------------------------------------------------- plan command

def cmd_plan(args):
    print("Checking AnkiConnect...")
    anki_request("version")

    print("Loading known vocabulary...")
    known = get_known_words(args.known_decks)
    print(f"  from Anki decks: {len(known)}")

    if not args.no_migaku:
        migaku_path = args.migaku_export or find_latest_migaku_export()
        if migaku_path:
            migaku_known, exported_at = load_migaku_known(migaku_path)
            age_note = ""
            if exported_at:
                try:
                    exported_dt = datetime.fromisoformat(exported_at.replace("Z", "+00:00"))
                    age_days = (datetime.now(timezone.utc) - exported_dt).days
                    if age_days >= MIGAKU_STALE_DAYS:
                        age_note = f"  [!stale - exported {age_days}d ago, consider re-exporting from study.migaku.com/word-browser]"
                except ValueError:
                    pass
            print(f"  from Migaku export ({os.path.basename(migaku_path)}, exported {exported_at}): {len(migaku_known)}{age_note}")
            known |= migaku_known
        else:
            print(f"  no Migaku DB export found ({MIGAKU_DB_GLOB}) -- skipping. Pass --migaku-export or pull a fresh one from study.migaku.com first.")
    print(f"  total known words: {len(known)}")

    print(f"Loading and tokenizing media: {args.input}")
    text = load_text(args.input)
    counts, lemma_surface, lemma_reading, sentence_words = tokenize_and_count(text)
    local_lemmas = set(counts)
    print(f"  {len(counts)} distinct content words found in subtitles")

    if args.jpdb_url:
        print(f"Fetching jpdb vocabulary list: {args.jpdb_url}")
        jpdb_entries = fetch_jpdb_vocab_list(args.jpdb_url)
        print(f"  {len(jpdb_entries)} entries fetched from jpdb")
        # Keep only jpdb words that were actually detected as content words in
        # this episode's own subtitles (this also filters out jpdb's particles).
        matched = [e for e in jpdb_entries if e["word"] in local_lemmas]
        matched.sort(key=lambda e: -e["count"])
        print(f"  {len(matched)} matched against local subtitle content words")
        candidates = [(e["word"], e["count"], e["meanings"]) for e in matched]
        source = "jpdb"
    else:
        candidates = [(lemma, freq, None) for lemma, freq in counts.most_common()]
        source = "local"

    new_words = [(lemma, freq, meanings) for lemma, freq, meanings in candidates if lemma not in known]
    print(f"  {len(new_words)} are not in your known decks")
    new_words = new_words[: args.top]

    if not new_words:
        print("No new words found — nothing to plan.")
        return

    print(f"\nBuilding plan for {len(new_words)} words (readings/definitions + n+1 sentences)...")
    plan = []
    for lemma, freq, jpdb_meanings in new_words:
        sentence, surface, is_clean = pick_n_plus_1_sentence(lemma, sentence_words, known)
        if sentence is None:
            sentence, surface = "", lemma_surface.get(lemma, lemma)

        # Always prefer jisho for the reading: sudachi's reading_form() reflects
        # the inflected surface the word happened to appear as in the sentence
        # (e.g. "済ん" from "済んだ"), not the dictionary form -- only fall back
        # to it when jisho has no entry. jpdb's own meanings are still used when
        # available since they're more tailored to this specific show/media.
        info = jisho_lookup(lemma)
        time.sleep(0.3)
        reading = (info["reading"] if info else "") or lemma_reading.get(lemma, "")
        definitions = jpdb_meanings[:3] if jpdb_meanings else (info["definitions"] if info else [])

        possible_name = bool(KATAKANA_ONLY.match(lemma))

        plan.append({
            "lemma": lemma,
            "reading": reading,
            "surface": surface,
            "freq": freq,
            "definitions": definitions,
            "sentence": sentence,
            "is_clean_n1": is_clean,
            "possible_proper_noun": possible_name,
            "translation": "",  # fill this in before running `add`
            "source": source,
        })
        flags = []
        if not is_clean:
            flags.append("!n+1 - no clean sentence")
        if possible_name:
            flags.append("?katakana - verify this isn't a character/place name before adding")
        flag_str = f"  [{'; '.join(flags)}]" if flags else ""
        print(f"  {freq:>4}  {lemma} ({reading}){flag_str}")

    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(plan, f, ensure_ascii=False, indent=2)
    print(f"\nWrote plan to {args.out}")
    print("Next: fill in each entry's \"translation\" field, then run the `add` command.")


# ---------------------------------------------------------------- add command

def cmd_add(args):
    with open(args.plan, encoding="utf-8") as f:
        plan = json.load(f)

    print("Checking AnkiConnect...")
    anki_request("version")
    if not args.dry_run:
        anki_request("createDeck", deck=args.deck_name)

    added = 0
    skipped = 0
    for entry in plan:
        lemma = entry["lemma"]
        reading = entry["reading"]
        sentence = entry["sentence"]
        surface = entry["surface"]
        translation = entry.get("translation", "")

        def_html = f"<p>{lemma} ({reading})</p>" + "".join(f"<p>&middot; {d}</p>" for d in entry["definitions"])
        if surface and surface in sentence:
            sentence_html = sentence.replace(surface, f"<strong>{surface}</strong>", 1)
        else:
            sentence_html = sentence
        target_word = f"{lemma}[{reading}]" if reading else lemma
        misc_info = f"<p>{translation}</p>" if translation else ""

        audio_tag = ""
        if not args.dry_run and reading:
            audio_bytes = fetch_word_audio(lemma, reading)
            time.sleep(0.3)
            if audio_bytes:
                filename = store_word_audio(lemma, reading, audio_bytes)
                audio_tag = f"[sound:{filename}]"

        tags = ["auto-vocab-builder"]
        if args.source_tag:
            tags.append(re.sub(r"\s+", "-", args.source_tag.strip()))
        if not entry.get("is_clean_n1", True):
            tags.append("needs-review-sentence")
        if not translation:
            tags.append("needs-translation")
        if entry.get("possible_proper_noun"):
            tags.append("needs-review-name")

        note = {
            "deckName": args.deck_name,
            "modelName": NEW_CARD_MODEL,
            "fields": {
                "Expression": lemma,
                "ExpressionFurigana": "",
                "ExpressionReading": "",
                "ExpressionAudio": audio_tag,
                "SelectionText": "",
                "MainDefinition": def_html,
                "DefinitionPicture": "",
                "Sentence": sentence_html,
                "SentenceFurigana": "",
                "SentenceAudio": "",
                "Picture": "",
                "Glossary": "",
                "Hint": "",
                "IsWordAndSentenceCard": "",
                "IsClickCard": target_word,
                "IsSentenceCard": "",
                "IsAudioCard": "",
                "PitchPosition": "",
                "PitchCategories": "",
                "Frequency": "",
                "FreqSort": "",
                "MiscInfo": misc_info,
            },
            "options": {"allowDuplicate": False},
            "tags": tags,
        }

        print(f"{entry['freq']:>4}  {lemma:<10} {reading:<12} {'; '.join(entry['definitions'])[:50]}")
        if args.dry_run:
            continue
        try:
            anki_request("addNote", note=note)
            added += 1
        except RuntimeError as e:
            skipped += 1
            print(f"  skipped '{lemma}': {e}", file=sys.stderr)

    if args.dry_run:
        print("\n--dry-run set: no cards were added to Anki.")
    else:
        print(f"\nAdded {added} cards to deck '{args.deck_name}' ({skipped} skipped, e.g. duplicates).")


# ---------------------------------------------------------------- CLI

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="command", required=True)

    p_plan = sub.add_parser("plan", help="Select new words + n+1 sentences, write a plan file")
    p_plan.add_argument("--input", required=True, help="Path to subtitle/text file for the media")
    p_plan.add_argument("--jpdb-url", help="Optional jpdb.io vocabulary-list URL for this media, for word ranking")
    p_plan.add_argument("--top", type=int, default=25, help="How many new words to plan cards for")
    p_plan.add_argument("--known-decks", nargs="*", default=KNOWN_DECKS, help="Decks to treat as already-known vocab")
    p_plan.add_argument("--migaku-export", help=f"Path to a raw Migaku core SQLite DB export (default: newest match of {MIGAKU_DB_GLOB})")
    p_plan.add_argument("--no-migaku", action="store_true", help="Don't factor in the Migaku known/ignored/tracked word export")
    p_plan.add_argument("--out", required=True, help="Path to write the plan JSON file")
    p_plan.set_defaults(func=cmd_plan)

    p_add = sub.add_parser("add", help="Build cards from a (translated) plan file and push to Anki")
    p_add.add_argument("--plan", required=True, help="Path to plan JSON file (from `plan`, translations filled in)")
    p_add.add_argument("--deck-name", default=CLAUDE_DECK, help=f"Target deck (default: {CLAUDE_DECK}, shared by all Claude-generated cards)")
    p_add.add_argument("--source-tag", help="Optional tag identifying where these cards came from, e.g. a show/episode name (spaces become hyphens)")
    p_add.add_argument("--dry-run", action="store_true", help="Preview cards without writing to Anki")
    p_add.set_defaults(func=cmd_add)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
