#!/usr/bin/env bash

set -euo pipefail

# Set your terminal:
terminal="alacritty"

# Config
wofi_style="$HOME/.config/wofi/menu.css"

die() {
  local msg="$1"
  printf '%s\n' "repos_wofi.sh: $msg" >&2
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u normal -a "hypr" "repos_wofi.sh" "$msg" >/dev/null 2>&1 || true
  fi
}

format_repo_label() {
  local abs="$1"

  # If there's a .../Github/<repo> or .../GitHub/<repo> segment, strip everything up to it.
  if [[ "$abs" == *"/Github/"* ]]; then
    printf '%s' "${abs#*"/Github/"}"
    return 0
  fi
  if [[ "$abs" == *"/GitHub/"* ]]; then
    printf '%s' "${abs#*"/GitHub/"}"
    return 0
  fi

  # Otherwise, keep $HOME-relative if possible.
  if [[ "$abs" == "$HOME" ]]; then
    return 1
  elif [[ "$abs" == "$HOME/"* ]]; then
    printf '%s' "${abs#"$HOME/"}"
    return 0
  fi

  # Fallback: absolute path.
  printf '%s' "$abs"
}

discover_git_repos() {
  # Defaulting to filesystem root (/) makes discovery expensive/noisy on most systems:
  # it traverses many unrelated/unreadable directories and can slow down the picker.
  # Prefer user locations by default; opt in to scanning / via REPOS_WOFI_INCLUDE_ROOT=1
  # or by explicitly listing / in REPOS_WOFI_ROOTS.
  local -a roots=()
  local max_depth="${REPOS_WOFI_MAX_DEPTH:-6}"

  if [[ -n "${REPOS_WOFI_ROOTS:-}" ]]; then
    # Colon-separated list of roots, e.g. "$HOME:$HOME/GitHub:/mnt/SSD_NVME_4TB/GitHub"
    IFS=':' read -r -a roots <<<"${REPOS_WOFI_ROOTS}"
  else
    roots=(
      "$HOME"
      "$HOME/GitHub"
      "$HOME/Github"
      "$HOME/Projects"
    )
    if [[ "${REPOS_WOFI_INCLUDE_ROOT:-0}" == "1" ]]; then
      roots+=("/")
    fi
  fi

  local root
  for root in "${roots[@]}"; do
    [[ -d "$root" ]] || continue

    if command -v fd >/dev/null 2>&1; then
      fd -H -I -t d --max-depth "$max_depth" \
        --exclude ".cache" --exclude ".claude" --exclude ".cargo" --exclude ".local" \
        --exclude "proc" --exclude "sys" --exclude "dev" --exclude "run" --exclude "tmp" \
        --exclude "System_BackUp" \
        -0 '^\.git$' "$root" \
        | xargs -0 -r -n1 dirname
    else
      # Fallback: slower than fd, but always available.
      find "$root" -maxdepth "$max_depth" \
        \( -path /proc -o -path /proc/\* -o -path /sys -o -path /sys/\* -o -path /dev -o -path /dev/\* -o -path /run -o -path /run/\* -o -path /tmp -o -path /tmp/\* -o -path /var/cache -o -path /var/cache/\* -o -path /var/tmp -o -path /var/tmp/\* -o -path /mnt/SSD_NVME_4TB/System_BackUp -o -path /mnt/SSD_NVME_4TB/System_BackUp/\* \) -prune -o \
        \( -type d \( -name ".cache" -o -name ".claude" -o -name ".cargo" -o -name ".local" \) -prune \) -o \
        \( -type d -name .git -print0 \) 2>/dev/null \
        | xargs -0 -r -n1 dirname
    fi
  done | sort -u
}

# Collect repos
repos="$(discover_git_repos || true)"
[[ -n "$repos" ]] || { die "No git repos found (max depth: ${REPOS_WOFI_MAX_DEPTH:-6}). Configure search roots via REPOS_WOFI_ROOTS or set REPOS_WOFI_INCLUDE_ROOT=1."; exit 1; }

# Pick repo
declare -A __label_counts=()
declare -A __label_to_abs=()
choices=()
while IFS= read -r abs; do
  [[ -n "$abs" ]] || continue
  label="$(format_repo_label "$abs" || true)"
  [[ -n "${label:-}" ]] || continue

  n="${__label_counts["$label"]:-0}"
  n=$((n + 1))
  __label_counts["$label"]="$n"

  if [[ "$n" -gt 1 ]]; then
    label="${label} (${n})"
  fi

  __label_to_abs["$label"]="$abs"
  choices+=("$label")
done <<<"$repos"
(( ${#choices[@]} > 0 )) || { die "No git repos found (after filtering)"; exit 1; }

if ! command -v wofi >/dev/null 2>&1; then
  die "Missing dependency: wofi"
  exit 1
fi

# wofi returns non-zero on cancel; don't let `set -e` kill the script.
chosen_dir="$(
  printf '%s\n' "${choices[@]}" \
    | wofi --dmenu --insensitive --lines 30 --prompt 'Projects:' --style "$wofi_style" \
    || true
)"
[[ -n "$chosen_dir" ]] || exit 0

chosen_abs="${__label_to_abs["$chosen_dir"]:-}"
if [[ -z "$chosen_abs" ]]; then
  die "Failed to map selection to a path: $chosen_dir"
  exit 1
fi

if [[ "$chosen_abs" = /* ]]; then
  dir="$chosen_abs"
else
  dir="$HOME/$chosen_abs"
fi
if [[ ! -d "$dir" ]]; then
  die "Chosen repo directory not found: $dir"
  exit 1
fi

# Open Neovim in the repo directory (terminal-specific flags)
case "$terminal" in
  alacritty)
    exec "$terminal" --working-directory "$dir" -e nvim .
    ;;
  *)
    exec "$terminal" -e "bash" "-lc" "cd \"$dir\" && nvim ."
    ;;
esac
