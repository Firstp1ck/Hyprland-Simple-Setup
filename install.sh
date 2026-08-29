#!/usr/bin/env bash
set -euo pipefail

print() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Hyprland-Simple-Setup bootstrap installer (curl | bash friendly)

Usage:
  curl -fsSL <raw-install.sh-url> | bash
  curl -fsSL <raw-install.sh-url> | bash -s -- [bootstrap options] -- [setup.sh options]

Bootstrap options:
  --repo <url>     Git repo URL (default: https://github.com/firstp1ck/Hyprland-Simple-Setup.git)
  --ref <ref>      Git ref to checkout (branch/tag/commit). Default: main
  --dir <path>     Install/clone directory (default: $HOME/Hyprland-Simple-Setup)
  --update         If dir exists and is a git repo, pull updates (default: enabled)
  --no-update      Do not pull updates when dir exists
  --tui            Prefer the Rust TUI (default)
  --no-tui         Do not run the TUI; run setup.sh directly
  --dry-run        Convenience: passes --dry-run to setup.sh
  --verbose        Convenience: passes --verbose to setup.sh
  -h, --help       Show this help

Notes:
  - Any args after `--` are passed directly to setup.sh.
  - For unattended runs, you can set env vars used by setup.sh, e.g.:
      NON_INTERACTIVE=true PROMPT_DEFAULT_YN=true ROLE_BROWSER=firefox ROLE_TERMINAL=kitty ROLE_SHELL=fish ROLE_GUI_EDITOR=zed ROLE_TUI_EDITOR=neovim ROLE_LAUNCHER=wofi FISH_LANGUAGE_CHOICE_OVERRIDE=1
EOF
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

is_git_repo_dir() {
  local dir="$1"
  [[ -d "$dir/.git" ]] && git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

default_repo="https://github.com/firstp1ck/Hyprland-Simple-Setup.git"
repo="${HSS_REPO:-$default_repo}"
ref="${HSS_REF:-main}"
dir="${HSS_DIR:-$HOME/Hyprland-Simple-Setup}"
do_update=true
prefer_tui=true

setup_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) repo="${2:-}"; [[ -n "$repo" ]] || die "--repo requires a value"; shift 2 ;;
    --ref) ref="${2:-}"; [[ -n "$ref" ]] || die "--ref requires a value"; shift 2 ;;
    --dir) dir="${2:-}"; [[ -n "$dir" ]] || die "--dir requires a value"; shift 2 ;;
    --update) do_update=true; shift ;;
    --no-update) do_update=false; shift ;;
    --tui) prefer_tui=true; shift ;;
    --no-tui) prefer_tui=false; shift ;;
    --dry-run) setup_args+=("--dry-run"); shift ;;
    --verbose) setup_args+=("--verbose"); shift ;;
    --help|-h) usage; exit 0 ;;
    --) shift; setup_args+=("$@"); break ;;
    *)
      warn "Unknown bootstrap option: $1 (passing through to setup.sh)"
      setup_args+=("$1")
      shift
      ;;
  esac
done

need_cmd git
need_cmd bash

print "Hyprland-Simple-Setup bootstrap"
print "  repo: $repo"
print "  ref:  $ref"
print "  dir:  $dir"

if [[ -e "$dir" && ! -d "$dir" ]]; then
  die "Path exists but is not a directory: $dir"
fi

if [[ ! -d "$dir" ]]; then
  print "Cloning repository..."
  git clone --depth 1 "$repo" "$dir"
else
  if is_git_repo_dir "$dir"; then
    if [[ "$do_update" == "true" ]]; then
      print "Updating existing clone..."
      git -C "$dir" fetch --tags --prune origin
    else
      print "Using existing clone (no update requested)."
    fi
  else
    die "Directory exists but is not a git repo: $dir"
  fi
fi

if is_git_repo_dir "$dir"; then
  print "Checking out ref: $ref"
  git -C "$dir" checkout -q "$ref" 2>/dev/null || {
    git -C "$dir" fetch --tags --prune origin "$ref" >/dev/null 2>&1 || true
    git -C "$dir" checkout -q "$ref"
  }
  if [[ "$do_update" == "true" ]]; then
    git -C "$dir" pull --ff-only >/dev/null 2>&1 || true
  fi
fi

if [[ "$prefer_tui" == "true" ]]; then
  if command -v hyprland-simple-setup >/dev/null 2>&1; then
    print "Launching TUI: hyprland-simple-setup"
    exec hyprland-simple-setup
  else
    warn "TUI requested but 'hyprland-simple-setup' not found in PATH. Falling back to setup.sh."
  fi
fi

[[ -f "$dir/setup.sh" ]] || die "Expected installer not found: $dir/setup.sh"

print "Running: bash \"$dir/setup.sh\" ${setup_args[*]:-}"
exec bash "$dir/setup.sh" "${setup_args[@]}"

