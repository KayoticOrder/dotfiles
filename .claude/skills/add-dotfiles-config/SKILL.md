---
name: add-dotfiles-config
description: Add a new tool config or platform profile to this dotbot-based dotfiles repo, or safely apply a config/profile to the live system. Use when adding a new application's dotfiles (e.g. a new terminal, editor, or CLI tool), adding a new OS/distro profile, or running install-standalone/install-profile against a real machine.
---

# Adding a config

1. `dots/<name>/` — put the actual files where they should end up relative to `$HOME`, e.g. `dots/<name>/.config/<name>/...`. Not every config needs this — a pure package install (e.g. `fonts.yaml`) has no `dots/fonts/` at all.
2. `meta/configs/<name>.yaml` — an `omnipkg install` list and/or a `link` block; a config can have either or both. Copy the shape from an existing file. `claude.yaml` is link-only (npm-installed tool, no system package). `fonts.yaml` is install-only (no files to symlink) and shows the dict form of `omnipkg install` (`{pac: ..., apt: ..., else: ...}`) for packages that don't exist under the same name (or at all) on every package manager — omitted keys are skipped gracefully rather than erroring, and a `shell:` step can fill the gap for a manager with no package at all.
3. Vendored plugin/theme repo: add it as a submodule, `git submodule add <url> dots/<name>/.config/<name>/<subpath>`.
4. `tests/verify.sh` — add a `verify_<name>` function using `check_link`/`check_bin` for every path this config symlinks and every binary it installs.
5. `.github/workflows/test.yml` — add `<name>` to `configs.strategy.matrix.config`. Use `include:` instead if it's distro-specific (see how `hypr` is arch-only there).
6. `meta/profiles/<profile>` — add `<name>` if it belongs in a bundled profile, or leave it out for a standalone-only config (see `claude`, `obsidian`).
7. `README.md` — add a row to the Contents table.

# Adding a profile

1. `meta/profiles/<name>` — plain text, one config per line, `#` comments out a line. Convention: first line is a same-named bootstrap config.
2. `meta/configs/<name>.yaml` for that bootstrap line — can be empty (see `arch.yaml`/`ubuntu.yaml`).
3. Confirm `meta/plugins/omnipkg.py` supports the platform's package manager (currently pacman/apt/dnf/brew). A new manager needs a new `_setup*` method plus an entry in the `managers` list inside `_setupLinux` (or a new `_setupX`/platform branch if it's not Linux/macOS — note Windows isn't supported there at all yet).
4. Optional CI: `tests/<name>/Dockerfile` (copy an existing one, swap the package-manager bootstrap section), then add `<name>` to the `distro` matrix in both jobs of `.github/workflows/test.yml`.
5. `README.md` — update the profile list and Testing section.

# Applying a config/profile to the live system — read this before running install scripts

`meta/base.yaml` sets `link: { force: true, relink: true, create: true }`. If a target path already has real (non-symlink) content, dotbot **deletes it and replaces it with the symlink — no backup, no prompt.** Never assume this is safe without checking first.

Before running `install-standalone`/`install-profile` against a target that isn't already a symlink:
1. Diff the live file/dir against what's about to be committed into `dots/`, to check for local edits/unique content that would be lost.
2. Back it up by moving it aside — `mv ~/.config/foo ~/.config/foo.bak-$(date +%s)` — not deleting. Cheap, fully reversible, costs nothing even if the diff looked clean.
3. Only then run the install command.

`meta/base.yaml` also runs `omnipkg: [update, upgrade]` on every single invocation — a full system package upgrade (`sudo pacman -Syu` on Arch) as a side effect of applying *any* one config. That's a materially bigger, less reversible action than "set up a symlink." Call this out explicitly and confirm the user actually wants it triggered before running anything, rather than triggering it as a silent side effect.

`sudo` typically needs an interactive password and will fail non-interactively — harmlessly (pacman never starts, so no partial upgrade), and dotbot still proceeds to the `link` step afterward. But `install-standalone`'s `set -e` means if dotbot exits non-zero for one config in a multi-config call (e.g. `install-standalone a b`), the script aborts before processing the rest. When sudo is going to fail, run configs one at a time and verify each with `readlink -f` rather than batching them — a later config in the list can silently never run.
