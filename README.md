# dotfiles

Personal dotfiles for an Arch Linux + Hyprland desktop, managed with [Dotbot](https://github.com/anishathalye/dotbot).

## Contents

| Config | What it links/installs |
| --- | --- |
| `alacritty` | Alacritty terminal + themes |
| `claude` | Claude Code settings, agents, commands, `notes` skill |
| `claude-japanese` | Japanese study / Anki skills (personal only) |
| `copilot` | GitHub Copilot CLI user instructions + `notes` skill |
| `fonts` | Iosevka Nerd Font + Iosevka Term, downloaded directly from upstream (used by `alacritty`/`kitty`) |
| `hypr` | Hyprland, Waybar, Rofi |
| `kitty` | Kitty terminal |
| `notes` | `~/notes` vault scaffolding: `AGENTS.md` schema + templates (notes themselves stay local) |
| `nvim` | Neovim (lazy.nvim config) |
| `obsidian` | Obsidian vault settings, templates, glossary |
| `sesh` | sesh tmux session manager (pinned release binary) + per-repo session layout config |
| `tmux` | tmux + plugins (TPM) |
| `zsh` | zsh, oh-my-zsh, Powerlevel10k |

`claude`, `claude-japanese`, `copilot`, `notes` and `obsidian` aren't in the `arch`/`ubuntu` profiles — install them explicitly with `install-standalone` if you want them on a given machine (e.g. `./install-standalone claude claude-japanese notes`).

Each config lives under `dots/<name>` and is symlinked into place; the matching `meta/configs/<name>.yaml` declares its packages and links.

`hypr` is Arch-only for now — Hyprland/Waybar/Rofi aren't in Ubuntu's official archives, so it's left out of the `ubuntu` profile.

## Install

```bash
git clone --recursive https://github.com/KayoticOrder/dotbot-dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

Install everything for this machine via a profile (see `meta/profiles/`: `arch`, `ubuntu`, `work`):

```bash
./install-profile arch
```

Or install individual configs:

```bash
./install-standalone nvim tmux zsh
```

Both scripts run `git submodule update --init --recursive` automatically, then apply `meta/base.yaml` plus the requested config(s) through Dotbot.

## Work machine

The `work` profile (Ubuntu on WSL) installs only the shareable configs — no GUI terminals/fonts (Windows Terminal handles those), Copilot CLI instead of Claude Code, and nothing personal (`claude-japanese`, `obsidian`, `anki-vocab-builder`). Clone over HTTPS with no push credentials and treat it as pull-only; make changes on a personal machine.

```bash
./install-profile work
git pull && ./install-profile work   # to update
```

Machine-specific shell settings go in `~/.zshrc.local`, which `.zshrc` sources if present and which is never committed.

## Notes vault

`~/notes` is long-term memory shared with any AI: one note per repo/topic, linked with `[[wikilinks]]`, cataloged in `index.md`. The `notes` config links in only the schema (`AGENTS.md`) and templates — the notes are plain local files, separate on every machine, so work notes never leave the work laptop. Open `~/notes` as an Obsidian vault to see the graph. Claude Code and the Copilot CLI both use it via the same `notes` skill (`dots/notes/skill`, linked by the `claude` / `copilot` configs); point other AIs at `~/notes/AGENTS.md`.

## How it works

- `meta/base.yaml` — shared defaults (force-relink, create `~/.config`, prune broken symlinks).
- `meta/configs/*.yaml` — one file per tool: packages to install and paths to symlink.
- `meta/profiles/*` — plain-text lists of configs to install together for a given machine (`arch`, `ubuntu`, `work`).
- `meta/plugins/omnipkg.py` — custom Dotbot plugin that installs packages via whatever package manager is present (pacman, apt, dnf, or Homebrew).
- `meta/plugins/yay.py` — custom Dotbot plugin for AUR packages via `yay`.

## Adding a config

1. Put the files under `dots/<name>/`, mirroring where they should end up (e.g. `dots/foo/.config/foo/...`).
2. Add `meta/configs/<name>.yaml` with an `omnipkg install` list, a `link` block, and/or a `shell` command — a config can use any combination. Copy the shape from an existing file: `claude.yaml` is link-only, `fonts.yaml` is shell-only (curls straight from upstream when there's no package manager involved at all).
3. If it needs a plugin/theme repo, add it as a submodule: `git submodule add <url> dots/<name>/.config/<name>/<subpath>`.
4. Add a `verify_<name>` function to `tests/verify.sh` (checks the symlink(s) resolve and the binary is on `PATH`).
5. Add `<name>` to the `configs.strategy.matrix.config` list in `.github/workflows/test.yml` for CI coverage (use `include:` instead if it only applies to one distro, like `hypr`).
6. Add it to any `meta/profiles/<profile>` file(s) it belongs in, or leave it out for a standalone-only config (see `claude`/`obsidian`).
7. Add a row to the Contents table above.

## Adding a profile

1. Add `meta/profiles/<name>`, one config per line (`#` comments out a line). By convention the first line is a same-named bootstrap config.
2. Add `meta/configs/<name>.yaml` for that bootstrap line — can be empty (see `arch.yaml`/`ubuntu.yaml`).
3. Confirm `meta/plugins/omnipkg.py` supports the platform's package manager (currently pacman, apt, dnf, Homebrew) — a new package manager needs a new `_setup*`/`_selectPackageManager` branch there.
4. If you want CI coverage, add `tests/<name>/Dockerfile` (copy an existing one, swap the package-manager bootstrap) and add `<name>` to the `distro` matrix in both jobs in `.github/workflows/test.yml`.
5. Update the profile list and Testing section in this README.

## Testing

`tests/<distro>/Dockerfile` (currently `arch` and `ubuntu`) builds a clean container, runs the profile or an individual config against it, then runs `tests/verify.sh` to confirm the expected symlinks and binaries actually exist — for verifying changes without touching the host machine:

```bash
# whole profile
docker build -f tests/arch/Dockerfile -t dotfiles-test .

# a single config
docker build -f tests/arch/Dockerfile \
  --build-arg INSTALLER=install-standalone \
  --build-arg TARGET=alacritty \
  --build-arg VERIFY_ARGS=alacritty \
  -t dotfiles-test .
```

GitHub Actions (`.github/workflows/test.yml`) runs both distros, each profile (`work` on ubuntu) and each config individually, on every push/PR.

## License

MIT — see [LICENSE](./LICENSE).
