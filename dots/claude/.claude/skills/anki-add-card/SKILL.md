---
name: anki-add-card
description: Add a single Japanese vocabulary card to the user's Anki collection via AnkiConnect. Use this whenever the user asks to add/save a word, sentence, or piece of vocab to Anki — e.g. "add this word to anki", "save this to my deck", "make a card for X", or when a new word comes up in conversation and they want it carded. Requires Anki desktop running locally with the AnkiConnect add-on (localhost:8765).
---

# Add a card to Anki

Adds one vocab card to the user's Anki collection, in the same field format as their real deck (`Lapis` note type, used in `studyy::MigakuNew`).

## How to use

Run the bundled script:

```
python3 ~/.claude/skills/anki-add-card/add_card.py --word 適当 [options]
```

Options:
- `--word` (required): dictionary form of the word, e.g. `適当`, `食べる`
- `--deck`: target deck, default `studyy::MigakuNew`
- `--reading`: kana reading; auto-looked-up via jisho.org if omitted
- `--sentence`: example sentence containing the word (the word gets auto-bolded)
- `--translation`: English translation of the sentence — stored in the card's "Misc info" field
- `--definitions`: semicolon-separated definitions, overrides the jisho.org lookup
- `--dry-run`: preview without writing to Anki

## Workflow

1. Check AnkiConnect is reachable before anything else: `curl -s http://localhost:8765 -X POST -d '{"action":"version","version":6}'`. If it fails, tell the user to open Anki (AnkiConnect only works while the app is running) and stop.
2. If the word came from something the user is reading/watching, grab the surrounding sentence for `--sentence` and translate it yourself for `--translation` — don't skip these if a sentence is available, they're what make the card useful.
3. Run the script. If a definition/reading looks wrong (jisho.org picked the wrong sense, e.g. homograph), override with `--definitions` and/or `--reading` rather than trusting the auto-lookup blindly.
4. Report back what was added (word, reading, definition, whether audio was found) — don't just say "done".

## Notes

- Duplicate detection is per-model in Anki: adding the same word+sentence pair twice will be rejected with a clear "duplicate" error, not silently double-added.
- Pronunciation audio comes from the same JapanesePod101 dictionary-audio source AJT Japanese/Yomichan use; some words (esp. slang/katakana) won't have a clip — that's expected, not a bug.
- For bulk word extraction from a whole episode/book/podcast (most-common-words-not-yet-known, from subtitles or a jpdb.io vocabulary list): if it's a specific anime episode and subs need to be sourced, use the `jimaku-to-anki` skill; otherwise drive `~/anki-vocab-builder/anki_vocab.py` directly. This skill is for one-off single-word adds.
