#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)

setup_role_fixture() {
  local root=$1
  export HOME="$root/home"
  export XDG_CONFIG_HOME="$HOME/.config"
  export XDG_STATE_HOME="$root/state"
  export XDG_RUNTIME_DIR="$root/runtime"
  export HYPRLAND_SETUP_DIR="$repo_root"
  export HSS_TEST_MODE=1
  export NON_INTERACTIVE=true
  export DISTRO=arch
  export STUB_LOG="$root/stub.log"
  export STUB_LOGIN_SHELL_FILE="$root/login-shell"
  export HSS_ETC_SHELLS="$root/shells"
  export PATH="$repo_root/tests/stubs:$PATH"
  export SELECTED_PACMAN_PACKAGES=""
  export SELECTED_AUR_PACKAGES=""
  unset STUB_INSTALLED

  mkdir -p "$HOME/.config" "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR"
  cp -a "$repo_root/dotfiles" "$HOME/dotfiles"
  rm -rf "$HOME/dotfiles/.config/hypr/sources"
  cp -a "$HOME/dotfiles/.config/hypr/sources_example" "$HOME/dotfiles/.config/hypr/sources"
  for name in hypr fish waybar pypr kitty zellij; do
    ln -s "$HOME/dotfiles/.config/$name" "$HOME/.config/$name"
  done
  printf '%s\n' /usr/bin/fish /bin/bash /usr/bin/zsh > "$HSS_ETC_SHELLS"
  printf '%s\n' /bin/bash > "$STUB_LOGIN_SHELL_FILE"
  : > "$STUB_LOG"
}

set_role_defaults() {
  export ROLE_BROWSER=zen-browser-bin
  export ROLE_TERMINAL=kitty
  export ROLE_SHELL=fish
  export ROLE_GUI_EDITOR=visual-studio-code-bin
  export ROLE_TUI_EDITOR=neovim
  export ROLE_LAUNCHER=wofi
}

set_role_value() {
  local role=$1 package=$2
  case "$role" in
    browser) export ROLE_BROWSER=$package ;;
    terminal) export ROLE_TERMINAL=$package ;;
    shell) export ROLE_SHELL=$package ;;
    gui_editor) export ROLE_GUI_EDITOR=$package ;;
    tui_editor) export ROLE_TUI_EDITOR=$package ;;
    launcher) export ROLE_LAUNCHER=$package ;;
    *) return 1 ;;
  esac
}
