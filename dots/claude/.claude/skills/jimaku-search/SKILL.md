---
name: jimaku-search
description: Search Jimaku (jimaku.cc) for Japanese subtitle files by anime/show name and optionally an episode number, then download the chosen file. Use whenever the user asks in plain text for subtitles/subs for a show — e.g. "get me subs for Frieren episode 3", "find jimaku subtitles for Bocchi the Rock", "download japanese subs for X".
---

# Jimaku subtitle search

Drives `jimaku_search.py` (bundled in this skill dir) in its non-interactive
`--json` mode to search Jimaku and fetch subtitle files from plain-text requests.

## Setup check

Requires an API key readable from `JIMAKU_API_KEY` env var or
`~/.config/jimaku/api_key`. If a run fails with "No API key found", tell the
user to save one via (they must run this themselves so the key isn't typed
into chat):

```
umask 177 && read -s -p "Jimaku API key: " k && printf '%s' "$k" > ~/.config/jimaku/api_key && unset k
```

Key is obtained at https://jimaku.cc/account (requires a Jimaku account).

## Workflow

1. Parse the user's request into a show title and, if mentioned, an episode
   number (e.g. "ep 12", "episode 3" -> `--episode 12`).

2. Search:
   ```
   python3 ~/.claude/skills/jimaku-search/jimaku_search.py "<title>" --json
   ```
   Returns a JSON array of entries (`id`, `name`, `english_name`,
   `japanese_name`, `anilist_id`, `tmdb_id`, ...).
   - No results: tell the user, suggest they check the spelling/romanization.
   - One result: use it directly.
   - Multiple results: pick the obvious best name match yourself; if it's
     genuinely ambiguous (e.g. multiple seasons/adaptations, or no close
     name match), list the candidates (name + english_name + id) and ask
     the user which one, rather than guessing.

3. List files for the chosen entry:
   ```
   python3 ~/.claude/skills/jimaku-search/jimaku_search.py --entry-id <ID> --json
   python3 ~/.claude/skills/jimaku-search/jimaku_search.py --entry-id <ID> --episode <N> --json
   ```
   Returns a JSON array of files (`name`, `size`, `last_modified`, `url`).
   Note: `--episode` filtering is a best-effort guess based on the filename,
   not a strict metadata field — if it returns nothing but the entry has
   files, retry without `--episode` and look for the episode number in the
   filenames yourself.

4. Present the matching file(s) to the user. If there's one obvious file for
   what they asked (e.g. they asked for one specific episode and only one
   file matches), download it directly; otherwise show the list (name +
   human-readable size) and ask which one.

5. Download by fetching the file's `url` directly (no auth header needed,
   these are public CDN links) into `/tmp/jimaku-subs/`:
   ```
   mkdir -p /tmp/jimaku-subs && curl -sL -o "/tmp/jimaku-subs/<file name>" "<url>"
   ```
   `/tmp` is tmpfs on this machine (cleared on reboot) and also auto-purged
   by systemd-tmpfiles after 10 days, so files here don't accumulate --
   don't download to the home directory or cwd by default. Report the saved
   path when done. Only save somewhere permanent (e.g. the user's cwd or a
   path they name) if the user explicitly asks to keep the file.

## Notes

- Jimaku entries are per-show (or per-season, as a separate entry) — there is
  no separate "season" field in the API. If a user asks for a specific
  season, treat it as part of the search query (e.g. search "Attack on
  Titan Final Season" as its own title) or disambiguate via the entries list.
- Rate limits (HTTP 429) are handled by the script — it exits with a message
  telling you how long to wait. Don't retry in a tight loop.
