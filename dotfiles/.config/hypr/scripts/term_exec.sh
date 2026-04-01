#!/usr/bin/env bash
set -euo pipefail

title=""

usage() {
  cat <<'EOF'
Usage:
  term_exec.sh [--title TITLE] -- <command> [args...]

Environment:
  TERMINAL  Terminal binary to use (e.g. kitty, alacritty). Defaults to kitty.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --title)
      shift
      [ $# -gt 0 ] || { usage >&2; exit 2; }
      title="$1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      # Back-compat: allow calling without "--"
      break
      ;;
  esac
done

[ $# -gt 0 ] || { usage >&2; exit 2; }

term="${TERMINAL:-kitty}"

case "$term" in
  alacritty)
    if [ -n "$title" ]; then
      exec alacritty -t "$title" --command "$@"
    else
      exec alacritty --command "$@"
    fi
    ;;
  kitty)
    if [ -n "$title" ]; then
      exec kitty --title "$title" -e "$@"
    else
      exec kitty -e "$@"
    fi
    ;;
  *)
    # Generic fallback: try "-e" (kitty, foot, wezterm, etc.)
    if [ -n "$title" ]; then
      exec "$term" -e "$@"
    else
      exec "$term" -e "$@"
    fi
    ;;
esac

