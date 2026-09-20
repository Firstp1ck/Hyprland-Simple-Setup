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
  for name in hypr fish waybar pypr kitty zellij nwg-panel ironbar; do
    ln -s "$HOME/dotfiles/.config/$name" "$HOME/.config/$name"
  done
  printf '%s\n' /usr/bin/fish /bin/bash /usr/bin/zsh > "$HSS_ETC_SHELLS"
  printf '%s\n' /bin/bash > "$STUB_LOGIN_SHELL_FILE"
  : > "$STUB_LOG"
}

set_role_defaults() {
  export ROLE_BROWSER=zen-browser-bin
  export ROLE_SHELL=fish
  export ROLE_TERMINAL=kitty
  export ROLE_MULTIPLEXER=herdr-bin
  export ROLE_FILE_MANAGER=dolphin
  export ROLE_TUI_FILE_MANAGER=
  export ROLE_NOTIFICATIONS=swaync
  export ROLE_TUI_EDITOR=neovim
  export ROLE_GUI_EDITOR=visual-studio-code-bin
  export ROLE_BAR=waybar
  export ROLE_DOCK=
  export ROLE_CALENDAR=merkuro
  export ROLE_BLUETOOTH=bluedevil
  export ROLE_NETWORK=plasma-nm
  export ROLE_AUDIO=pavucontrol-qt
  export ROLE_LAUNCHER=wofi
  export ROLE_AGENT=
  local role list_env
  for role in browser shell terminal multiplexer file_manager tui_file_manager notifications tui_editor gui_editor bar dock calendar bluetooth network audio launcher agent; do
    list_env="ROLE_${role^^}_PACKAGES"
    unset "$list_env"
  done
}

set_role_value() {
  local role=$1 package=$2
  case "$role" in
    browser) export ROLE_BROWSER=$package ;;
    shell) export ROLE_SHELL=$package ;;
    terminal) export ROLE_TERMINAL=$package ;;
    multiplexer) export ROLE_MULTIPLEXER=$package ;;
    file_manager) export ROLE_FILE_MANAGER=$package ;;
    tui_file_manager) export ROLE_TUI_FILE_MANAGER=$package ;;
    notifications) export ROLE_NOTIFICATIONS=$package ;;
    tui_editor) export ROLE_TUI_EDITOR=$package ;;
    gui_editor) export ROLE_GUI_EDITOR=$package ;;
    bar) export ROLE_BAR=$package ;;
    dock) export ROLE_DOCK=$package ;;
    calendar) export ROLE_CALENDAR=$package ;;
    bluetooth) export ROLE_BLUETOOTH=$package ;;
    network) export ROLE_NETWORK=$package ;;
    audio) export ROLE_AUDIO=$package ;;
    launcher) export ROLE_LAUNCHER=$package ;;
    agent) export ROLE_AGENT=$package ;;
    *) return 1 ;;
  esac
}
