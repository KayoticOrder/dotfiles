#!/usr/bin/env python3
"""
Add a single Japanese vocab card to Anki via AnkiConnect, matching the
`Lapis` note-type field layout used in the user's real decks.

Usage:
    python3 add_card.py --word 適当 [--deck "studyy::Claude"] \
        [--reading てきとう] [--sentence "適当にやった。"] \
        [--translation "I did it half-heartedly."] [--dry-run]

If --reading is omitted, it's looked up via jisho.org. Definitions always
come from jisho.org. Pronunciation audio comes from the same
JapanesePod101 dictionary-audio endpoint AJT Japanese/Yomichan use; it's
silently skipped if no clip exists for the word.
"""
import argparse
import base64
import hashlib
import json
import sys
import time
import urllib.parse
import urllib.request

ANKI_CONNECT_URL = "http://localhost:8765"
NEW_CARD_MODEL = "Lapis"
JISHO_API = "https://jisho.org/api/v1/search/words?keyword="
AUDIO_API = "https://assets.languagepod101.com/dictionary/japanese/audiomp3.php?kanji={}&kana={}"
AUDIO_PLACEHOLDER_MD5 = "7e2c2f954ef6051373ba916f000168dc"
DEFAULT_DECK = "studyy::Claude"  # shared deck for all Claude-created cards; see ~/anki-vocab-builder/anki_vocab.py's CLAUDE_DECK


def anki_request(action, **params):
    payload = json.dumps({"action": action, "version": 6, "params": params}).encode("utf-8")
    req = urllib.request.Request(ANKI_CONNECT_URL, payload)
    with urllib.request.urlopen(req) as resp:
        result = json.load(resp)
    if result.get("error") is not None:
        raise RuntimeError(f"AnkiConnect error on {action}: {result['error']}")
    return result["result"]


def jisho_lookup(word):
    try:
        with urllib.request.urlopen(JISHO_API + urllib.parse.quote(word), timeout=8) as resp:
            data = json.load(resp)
    except Exception as e:
        print(f"jisho lookup failed: {e}", file=sys.stderr)
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


def fetch_word_audio(word, reading):
    url = AUDIO_API.format(urllib.parse.quote(word), urllib.parse.quote(reading))
    try:
        with urllib.request.urlopen(url, timeout=8) as resp:
            data = resp.read()
    except Exception as e:
        print(f"audio fetch failed: {e}", file=sys.stderr)
        return None
    if not data or hashlib.md5(data).hexdigest() == AUDIO_PLACEHOLDER_MD5:
        return None
    return data


def store_word_audio(word, reading, audio_bytes):
    filename = f"vocab-builder_{word}_{reading}.mp3"
    anki_request("storeMediaFile", filename=filename, data=base64.b64encode(audio_bytes).decode("ascii"))
    return filename


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--word", required=True, help="Dictionary form of the word, e.g. 適当")
    ap.add_argument("--deck", default=DEFAULT_DECK, help=f"Target deck (default: {DEFAULT_DECK})")
    ap.add_argument("--reading", help="Kana reading; looked up via jisho.org if omitted")
    ap.add_argument("--sentence", default="", help="Example sentence containing the word (word will be bolded)")
    ap.add_argument("--translation", default="", help="English translation of the sentence, stored in Misc info")
    ap.add_argument("--definitions", help="Semicolon-separated definitions; overrides jisho.org lookup")
    ap.add_argument("--dry-run", action="store_true", help="Preview without writing to Anki")
    args = ap.parse_args()

    anki_request("version")

    reading = args.reading
    if args.definitions:
        definitions = [d.strip() for d in args.definitions.split(";") if d.strip()]
    else:
        info = jisho_lookup(args.word)
        if info:
            reading = reading or info["reading"]
            definitions = info["definitions"]
        else:
            definitions = []
    reading = reading or ""

    def_html = f"<p>{args.word} ({reading})</p>" + "".join(f"<p>&middot; {d}</p>" for d in definitions)

    sentence_html = args.sentence
    if args.sentence and args.word in args.sentence:
        sentence_html = args.sentence.replace(args.word, f"<strong>{args.word}</strong>", 1)

    target_word = f"{args.word}[{reading}]" if reading else args.word
    misc_info = f"<p>{args.translation}</p>" if args.translation else ""

    audio_tag = ""
    if not args.dry_run and reading:
        audio_bytes = fetch_word_audio(args.word, reading)
        time.sleep(0.2)
        if audio_bytes:
            filename = store_word_audio(args.word, reading, audio_bytes)
            audio_tag = f"[sound:{filename}]"

    note = {
        "deckName": args.deck,
        "modelName": NEW_CARD_MODEL,
        "fields": {
            "Expression": args.word,
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
        "tags": ["quick-add"],
    }

    print(f"{args.word} ({reading}): {'; '.join(definitions) or '(no definition found)'}")
    if args.sentence:
        print(f"  sentence: {args.sentence}")
    if args.translation:
        print(f"  translation: {args.translation}")
    print(f"  audio: {'yes' if audio_tag else 'no'}")

    if args.dry_run:
        print("--dry-run set: not added to Anki.")
        return

    anki_request("createDeck", deck=args.deck)
    try:
        anki_request("addNote", note=note)
        print(f"Added to deck '{args.deck}'.")
    except RuntimeError as e:
        print(f"Not added: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
