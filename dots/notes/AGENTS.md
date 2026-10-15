# Notes vault

Long-term memory shared between the user and any AI assistant: a map of
repos, topics, and how they relate. Plain markdown, readable in Obsidian
(graph view shows the links). Read this file before reading or writing notes.

`AGENTS.md` and `templates/` are symlinked from the user's dotfiles — don't
edit them here; suggest changes to the user instead.

## Layout

| Path | What goes there |
| --- | --- |
| `index.md` | Catalog of every note: `- [[id]] — one-line summary`, grouped under `## Repos` / `## Topics`. Read it first. |
| `log.md` | Append-only history, newest last. |
| `repos/` | One note per repository (template: `templates/repo.md`). |
| `topics/` | Concepts, tools, systems, decisions — anything that isn't a single repo (template: `templates/topic.md`). |

Create `index.md` / `log.md` if missing. Don't add new top-level folders
without asking the user.

## Notes

- Filename is the `id`: lowercase slug, e.g. `repos/dotfiles.md` → `id: dotfiles`.
- Start from the matching template; keep its frontmatter fields and set `updated` on every edit.
- Link related notes with `[[id]]` wikilinks. Every note links to at least one other note — the links are the map.
- Update an existing note rather than creating a near-duplicate; search first.
- Keep notes short and factual. Prefer bullet points and paths over prose.

## Rules

- Facts about a repo come from reading the repo, not from guessing. Mark anything unverified with `(unverified)`.
- Never write secrets, tokens, passwords, or credentials — reference where they live instead.
- This vault belongs to one context (personal or work). Never copy its contents into another vault, repo, or external service.
- After any change: update `index.md` if a note was added/renamed/re-summarized, then append to `log.md`:

  ```
  ## [YYYY-MM-DD] <add|update|lint> | <note id or short title>
  One line on what changed.
  ```
