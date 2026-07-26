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
- `meta/profiles/*` — plain-text lists of configs to install together for a given machine (e.g. `arch`).
- `meta/plugins/omnipkg.py` — custom Dotbot plugin that installs packages via whatever package manager is present (pacman, apt, dnf, or Homebrew).
- `meta/plugins/yay.py` — custom Dotbot plugin for AUR packages via `yay`.

## Testing

`tests/arch/Dockerfile` builds a clean Arch container and runs `install-profile arch` against it, for verifying changes without touching the host machine:

```bash
docker build -f tests/arch/Dockerfile -t dotfiles-test .
```

## License

MIT — see [LICENSE](./LICENSE).
