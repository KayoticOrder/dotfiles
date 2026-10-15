---
name: notes
description: Read and write the user's long-term notes vault at ~/notes — a markdown map of their repos, topics, and how they relate, shared with any AI they use. Use when the user asks to remember/save/note something, map or document a repo ("add this repo to my notes", "map out this repo"), asks what they know about something ("check my notes", "what do my notes say about X"), or asks to clean up/lint their notes. Also check it when starting unfamiliar work in a repo that may already have a note.
---

# Notes vault

1. If `~/notes/AGENTS.md` doesn't exist, stop and tell the user to run `./install-standalone notes` from their dotfiles.
2. Read `~/notes/AGENTS.md` — it is the source of truth for layout, format, and rules. Follow it exactly; this skill only adds the workflows below.
3. Read `~/notes/index.md` before opening any other note.

## Workflows

**Recall** — find candidates in `index.md` (then `grep -ril` in `~/notes` if the index misses), read only those notes, and answer citing note ids. Say plainly if the notes don't cover it.

**Record** — find the existing note to update, or create one from the matching template. Confirm with the user before writing anything they didn't explicitly ask to save.

**Map a repo** — run from inside the repo (or the path the user gives). Read its README, manifest/build files, top-level layout, and how it's run and tested; fill `templates/repo.md` from what's actually there (`remote` from `git remote get-url origin`, `path` from the repo root). Link it to existing repo/topic notes it depends on or relates to, and add backlinks from those notes where it's useful. If a note already exists, update it and refresh `updated`.

**Lint** — report, then fix only what the user approves:
- notes missing from `index.md`, or index entries with no file
- `[[links]]` to ids that don't exist
- notes with no links in or out
- frontmatter missing required fields or `id` not matching the filename
- repo notes whose `path` no longer exists, or `updated` older than ~6 months

Finish every write by updating `index.md` and appending to `log.md` as `AGENTS.md` describes.
