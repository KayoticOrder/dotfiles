#!/usr/bin/env bash
# Post-install checks: confirms configs actually got symlinked into the repo
# (not just that the install script exited 0) and that the packages each
# config installs are on PATH. Platform-agnostic - shared by every
# tests/<platform>/Dockerfile, since a symlink/PATH check doesn't care which
# distro produced it.
#
# Usage:
#   verify.sh                    check every config that has a verify_<name> function
#   verify.sh <config> [config...]   check only the given configs
#   verify.sh --profile <name>   check every config listed in meta/profiles/<name>;
#                                 entries with no verify_<name> function (e.g. the
#                                 bootstrap "arch"/"ubuntu" line) are skipped, not failed
set -uo pipefail

# Font checks below use fc-list, which trusts fontconfig's on-disk cache
# rather than always rescanning. That cache was built in a *different*
# Docker layer (the install-standalone/install-profile RUN step) - layer
# commits can shift directory mtimes even for unchanged files, which is
# enough for fontconfig to treat the cache as stale in ways that don't
# reproduce outside Docker. Rebuild it fresh here so this doesn't depend on
# a cache surviving a layer boundary.
command -v fc-cache >/dev/null 2>&1 && fc-cache -f >/dev/null 2>&1

fail=0

check_link() {
  local link="$1" expect_substr="$2"
  if [[ ! -L "$link" ]]; then
    echo "FAIL: $link is not a symlink"
    fail=1
    return
  fi
  local target
  target="$(readlink -f "$link")"
  if [[ "$target" != *"$expect_substr"* ]]; then
    echo "FAIL: $link -> $target (expected to contain $expect_substr)"
    fail=1
    return
  fi
  echo "OK: $link -> $target"
}

check_bin() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "FAIL: $1 not found on PATH"
    fail=1
    return
  fi
  echo "OK: $1 found on PATH"
}

check_font() {
  if ! fc-list | grep -qi "$1"; then
    echo "FAIL: no font matching '$1' found"
    fail=1
    return
  fi
  echo "OK: font matching '$1' found"
}

verify_fonts() {
  check_font "iosevka.*nerd"
  check_font "iosevka term"
}

verify_alacritty() {
  check_link "$HOME/.config/alacritty" "dots/alacritty/.config/alacritty"
  check_bin alacritty
}

verify_hypr() {
  check_link "$HOME/.config/hypr" "dots/hypr/.config/hypr"
  check_link "$HOME/.config/rofi" "dots/hypr/.config/rofi"
  check_link "$HOME/.config/waybar" "dots/hypr/.config/waybar"
  check_bin Hyprland
  check_bin waybar
  check_bin rofi
}

verify_kitty() {
  check_link "$HOME/.config/kitty" "dots/kitty/.config/kitty"
  check_bin kitty
}

verify_nvim() {
  check_link "$HOME/.config/nvim" "dots/nvim/.config/nvim"
  check_bin nvim
}

verify_tmux() {
  check_link "$HOME/.config/tmux" "dots/tmux/.config/tmux"
  check_bin tmux
}

verify_zsh() {
  check_link "$HOME/.zshrc" "dots/zsh/.zshrc"
  check_bin zsh
}

strict=true
if [[ "${1:-}" == "--profile" ]]; then
  profile="${2:?--profile requires a profile name}"
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  mapfile -t configs < <(grep -v '^#' "${repo_root}/meta/profiles/${profile}")
  strict=false
elif [[ $# -gt 0 ]]; then
  configs=("$@")
else
  mapfile -t configs < <(declare -F | awk '{print $3}' | sed -n 's/^verify_//p')
fi

for config in "${configs[@]}"; do
  if declare -f "verify_${config}" >/dev/null; then
    "verify_${config}"
  elif [[ "$strict" == true ]]; then
    echo "FAIL: no verification defined for config '$config'"
    fail=1
  else
    echo "SKIP: '$config' has no linked config to verify"
  fi
done

exit "$fail"
