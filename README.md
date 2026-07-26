# dotfiles

Personal dotfiles for an Arch Linux + Hyprland desktop, managed with [Dotbot](https://github.com/anishathalye/dotbot).

## Contents

| Config | What it links/installs |
| --- | --- |
| `alacritty` | Alacritty terminal + themes |
| `hypr` | Hyprland, Waybar, Rofi |
| `kitty` | Kitty terminal |
| `nvim` | Neovim (lazy.nvim config) |
| `obsidian` | Obsidian vault settings, templates, glossary |
| `tmux` | tmux + plugins (TPM) |
| `zsh` | zsh, oh-my-zsh, Powerlevel10k |

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
