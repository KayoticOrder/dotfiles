# dotfiles

Personal dotfiles for an Arch Linux + Hyprland desktop, managed with [Dotbot](https://github.com/anishathalye/dotbot).

## Contents

| Config | What it links/installs |
| --- | --- |
| `alacritty` | Alacritty terminal + themes |
| `claude` | Claude Code settings, agents, commands, skills |
| `hypr` | Hyprland, Waybar, Rofi |
| `kitty` | Kitty terminal |
| `nvim` | Neovim (lazy.nvim config) |
| `obsidian` | Obsidian vault settings, templates, glossary |
| `tmux` | tmux + plugins (TPM) |
| `zsh` | zsh, oh-my-zsh, Powerlevel10k |

`claude` and `obsidian` are standalone-only (not part of any profile) — install them explicitly with `install-standalone` if you want them on a given machine.

Each config lives under `dots/<name>` and is symlinked into place; the matching `meta/configs/<name>.yaml` declares its packages and links.

`hypr` is Arch-only for now — Hyprland/Waybar/Rofi aren't in Ubuntu's official archives, so it's left out of the `ubuntu` profile.

## Install

```bash
git clone --recursive https://github.com/KayoticOrder/dotbot-dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

Install everything for this machine via a profile (see `meta/profiles/`):

```bash
./install-profile arch
```

Or install individual configs:

```bash
./install-standalone nvim tmux zsh
```

Both scripts run `git submodule update --init --recursive` automatically, then apply `meta/base.yaml` plus the requested config(s) through Dotbot.

## How it works

- `meta/base.yaml` — shared defaults (force-relink, create `~/.config`, prune broken symlinks).
- `meta/configs/*.yaml` — one file per tool: packages to install and paths to symlink.
- `meta/profiles/*` — plain-text lists of configs to install together for a given machine (`arch`, `ubuntu`).
- `meta/plugins/omnipkg.py` — custom Dotbot plugin that installs packages via whatever package manager is present (pacman, apt, dnf, or Homebrew).
- `meta/plugins/yay.py` — custom Dotbot plugin for AUR packages via `yay`.

## Adding a config

1. Put the files under `dots/<name>/`, mirroring where they should end up (e.g. `dots/foo/.config/foo/...`).
2. Add `meta/configs/<name>.yaml` with an `omnipkg install` list and a `link` block (see any existing file for the shape).
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

GitHub Actions (`.github/workflows/test.yml`) runs both distros, the full profile and each config individually, on every push/PR.

## License

MIT — see [LICENSE](./LICENSE).
