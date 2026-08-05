#!/usr/bin/env python3
"""One-shot known-vocab count for seeding a starting level estimate.

Reuses anki_vocab.py's own known-word aggregation (AnkiConnect decks +
Migaku export) instead of re-implementing it -- this is only a rough prior;
the conversation itself is what actually calibrates i+1 difficulty over time.
"""
import os
import sys

sys.path.insert(0, os.path.expanduser("~/anki-vocab-builder"))
import anki_vocab  # noqa: E402

BANDS = [
    (300, "pre-N5 (absolute beginner)"),
    (800, "N5"),
    (1500, "N4"),
    (3500, "N3"),
    (6000, "N2"),
    (float("inf"), "N1+"),
]


def band_for(count):
    for threshold, label in BANDS:
        if count < threshold:
            return label
    return "N1+"


def get_anki_known_words(decks):
    """One word per note, not anki_vocab.get_known_words()'s per-field union.
    That function also folds in the 'Expression' field (a full example
    *sentence*, not a word) since it's only ever used there for substring
    exclusion, where over-counting is harmless -- here it would wildly
    inflate a word count, so pick a single canonical field per note instead."""
    known = set()
    for deck in decks:
        note_ids = anki_vocab.anki_request("findNotes", query=f'deck:"{deck}"')
        if not note_ids:
            print(f"  warning: no notes found in deck '{deck}'", file=sys.stderr)
            continue
        infos = []
        for i in range(0, len(note_ids), 500):
            infos.extend(anki_vocab.anki_request("notesInfo", notes=note_ids[i:i + 500]))
        for note in infos:
            fields = note["fields"]
            for key in ("Target Word", "Vocabulary-Kanji", "Vocabulary-Kana"):
                if key in fields and fields[key]["value"].strip():
                    known.add(anki_vocab.strip_furigana_brackets(fields[key]["value"]))
                    break
        print(f"  {deck}: {len(infos)} notes", file=sys.stderr)
    return known


def main():
    known = set()

    try:
        known |= get_anki_known_words(anki_vocab.KNOWN_DECKS)
    except Exception as e:
        print(f"warning: AnkiConnect lookup failed ({e}) -- is Anki running?", file=sys.stderr)

    migaku_path = anki_vocab.find_latest_migaku_export()
    if migaku_path:
        migaku_known, exported_at = anki_vocab.load_migaku_known(migaku_path)
        known |= migaku_known
        print(f"  Migaku export ({os.path.basename(migaku_path)}, exported {exported_at}): "
              f"{len(migaku_known)} words", file=sys.stderr)
    else:
        print("  no Migaku export found -- Anki decks only", file=sys.stderr)

    count = len(known)
    print(f"known_vocab_count={count}")
    print(f"level_estimate={band_for(count)}")


if __name__ == "__main__":
    main()
