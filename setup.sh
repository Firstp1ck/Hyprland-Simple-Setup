#!/bin/bash

############################################################## Disabled Shellcheck Messages ##############################################################
# shellcheck disable=SC2012
# Use find instead of ls to better handle non-alphanumeric filenames.

# shellcheck disable=SC1091
# Not following: /etc/os-release: openBinaryFile: does not exist (No such file or directory)

# shellcheck disable=SC2016
# Literal dollar signs are written into Hyprland, Fish, and Waybar configuration files.

##############################################################
# Hyprland Setup Script
# Based on your Start_system_setup.sh, this script installs
# Hyprland and its dependencies and configures Hyprland tools.
##############################################################

# Constants
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
CHECK_MARK=$'\e[1;32m\u2714\e[0m'
CROSS_MARK=$'\e[1;31m\u2718\e[0m'
CIRCLE=$'\u25CB'
LOG_FILE=""

SETUP_SCRIPT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib/setup-reliability.sh
source "$SETUP_SCRIPT_ROOT/scripts/lib/setup-reliability.sh"

# Arrays to store update statuses
mirror_updates=()
package_updates=()
aur_updates=()
failed_packages=()
config_statuses=()

# Final summary tracking arrays
SUMMARY_HARD_FAILURES=()
SUMMARY_WARNINGS=()
SUMMARY_SOFT_ERRORS=()
SUMMARY_SKIPPED=()
declare -A _SEEN_RECOMMENDATIONS=()
SUMMARY_RECOMMENDATIONS=()

# Selected AUR helper (paru preferred if available)
AUR_HELPER=""
AUR_HELPER_CHECKED=""

# Initialize DRY_RUN_OPERATIONS array early for all functions
declare -a DRY_RUN_OPERATIONS=()
FISH_LANGUAGE_CHOICE=""
SETUP_DIR=Hyprland-Simple-Setup
PACKAGE_REGISTRY=""
ROLE_DATA_FILE=""
ROLE_SELECTIONS_LOADED=false
PACKAGE_SELECTIONS_PREPARED=false
SELECTED_PACKAGES_VERIFIED=false
ROLE_NAMES=(browser terminal shell gui_editor tui_editor launcher)
declare -a SELECTED_PACMAN_LIST=()
declare -a SELECTED_AUR_LIST=()
declare -a SELECTED_ALL_PACKAGES=()

############################################################## Helper Functions ##############################################################

get_fish_language_choice() {
    if [ -z "$FISH_LANGUAGE_CHOICE" ]; then
        if [ "${NON_INTERACTIVE:-false}" = "true" ]; then
            FISH_LANGUAGE_CHOICE=${FISH_LANGUAGE_CHOICE_OVERRIDE:-1}
            print_verbose "Non-interactive mode: using FISH_LANGUAGE_CHOICE='$FISH_LANGUAGE_CHOICE'"
            return
        fi
        echo "Select your preferred language setting for Fish Shell:"
        echo "1) de_CH (Default: LANG=de_CH.UTF-8, LANGUAGE=de_CH:en_US)"
        echo "2) de     (German: LANG=de_DE.UTF-8, LANGUAGE=de_DE:en_US)"
        echo "3) us     (US English: LANG=en_US.UTF-8, LANGUAGE=en_US:de_CH)"
        read -rp "Enter selection number (1-3): " FISH_LANGUAGE_CHOICE
    else
        print_verbose "FISH_LANGUAGE_CHOICE already set to: '$FISH_LANGUAGE_CHOICE'"
    fi
}

role_env_name() {
    case "$1" in
        browser) printf '%s' ROLE_BROWSER ;;
        terminal) printf '%s' ROLE_TERMINAL ;;
        shell) printf '%s' ROLE_SHELL ;;
        gui_editor) printf '%s' ROLE_GUI_EDITOR ;;
        tui_editor) printf '%s' ROLE_TUI_EDITOR ;;
        launcher) printf '%s' ROLE_LAUNCHER ;;
        *) return 1 ;;
    esac
}

validate_package_name() {
    [[ "$1" =~ ^[a-z0-9@._+-]+$ ]]
}

resolve_package_registry() {
    local setup_root
    setup_root=$(find_hyprland_setup_dir) || {
        print_error "Could not locate packages.json because the setup directory was not found"
        return 1
    }
    PACKAGE_REGISTRY="$setup_root/packages.json"
    if [ ! -f "$PACKAGE_REGISTRY" ] || ! jq -e '.roles and .required' "$PACKAGE_REGISTRY" >/dev/null; then
        print_error "Invalid package registry: $PACKAGE_REGISTRY"
        return 1
    fi
}

load_role_selections() {
    [ "$ROLE_SELECTIONS_LOADED" = true ] && return 0
    [ -n "$PACKAGE_REGISTRY" ] || resolve_package_registry || return 1

    local role env_name value default label count choice
    for role in "${ROLE_NAMES[@]}"; do
        env_name=$(role_env_name "$role") || return 1
        value=${!env_name:-}
        default=$(jq -er --arg role "$role" '.roles[$role].default' "$PACKAGE_REGISTRY") || return 1
        label=$(jq -er --arg role "$role" '.roles[$role].label' "$PACKAGE_REGISTRY") || return 1

        if [ -z "$value" ]; then
            if [ "${NON_INTERACTIVE:-false}" = true ]; then
                value=$default
                print_message "$env_name was not set; using registry default '$value'"
            else
                echo "Select $label:"
                jq -r --arg role "$role" '.roles[$role].options | to_entries[] | "\(.key + 1)) \(.value.package)"' "$PACKAGE_REGISTRY"
                count=$(jq -r --arg role "$role" '.roles[$role].options | length' "$PACKAGE_REGISTRY")
                read -rp "Enter selection number (default: $default): " choice
                if [ -z "$choice" ]; then
                    value=$default
                elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
                    value=$(jq -er --arg role "$role" --argjson index "$((choice - 1))" '.roles[$role].options[$index].package' "$PACKAGE_REGISTRY") || return 1
                else
                    print_error "Invalid selection for $env_name"
                    return 1
                fi
            fi
        fi

        if ! validate_package_name "$value" || ! jq -e --arg role "$role" --arg package "$value" '.roles[$role].options | any(.package == $package)' "$PACKAGE_REGISTRY" >/dev/null; then
            print_error "$env_name has unknown package value '$value'"
            return 1
        fi
        printf -v "$env_name" '%s' "$value"
        export "${env_name?}"
        hss_meta_set "$env_name" "$value" || return 1
    done
    ROLE_SELECTIONS_LOADED=true
}

role_option_json() {
    local role=$1 env_name package
    env_name=$(role_env_name "$role") || return 1
    package=${!env_name:-}
    jq -ce --arg role "$role" --arg package "$package" '.roles[$role].options[] | select(.package == $package)' "$PACKAGE_REGISTRY"
}

role_field() {
    local role=$1 field=$2
    role_option_json "$role" | jq -er --arg field "$field" '.[$field]'
}

append_unique() {
    local array_name=$1 value=$2 existing
    local -n target=$array_name
    [ -n "$value" ] || return 0
    for existing in "${target[@]}"; do
        [ "$existing" = "$value" ] && return 0
    done
    target+=("$value")
}

append_package_words() {
    local array_name=$1 words=$2 package
    words=${words//,/ }
    for package in $words; do
        if ! validate_package_name "$package"; then
            print_error "Invalid package name '$package' in selected package input"
            return 1
        fi
        append_unique "$array_name" "$package"
    done
}

prepare_package_selections() {
    [ "$PACKAGE_SELECTIONS_PREPARED" = true ] && return 0
    load_role_selections || return 1

    local pacman_present=false aur_present=false package role option source
    [[ -v SELECTED_PACMAN_PACKAGES ]] && pacman_present=true
    [[ -v SELECTED_AUR_PACKAGES ]] && aur_present=true
    if [ "$pacman_present" != "$aur_present" ]; then
        print_error "SELECTED_PACMAN_PACKAGES and SELECTED_AUR_PACKAGES must either both be set or both be absent"
        return 1
    fi

    if [ "$pacman_present" = true ]; then
        append_package_words SELECTED_PACMAN_LIST "${SELECTED_PACMAN_PACKAGES:-}" || return 1
        append_package_words SELECTED_AUR_LIST "${SELECTED_AUR_PACKAGES:-}" || return 1
    else
        while IFS= read -r package; do append_unique SELECTED_PACMAN_LIST "$package"; done < <(
            jq -r '[.roles[].options[] | .package, (.extra_packages[]?)] as $exclusive | .hyprland_packages[][] as $package | select(($exclusive | index($package)) == null) | $package' "$PACKAGE_REGISTRY"
        )
        while IFS= read -r package; do append_unique SELECTED_AUR_LIST "$package"; done < <(
            jq -r '[.roles[].options[] | .package, (.extra_packages[]?)] as $exclusive | .aur_packages[][] as $package | select(($exclusive | index($package)) == null) | $package' "$PACKAGE_REGISTRY"
        )
        print_message "No SELECTED_* package variables were supplied; using non-role registry packages and role defaults"
    fi

    for role in "${ROLE_NAMES[@]}"; do
        option=$(role_option_json "$role") || return 1
        source=$(jq -er '.source' <<<"$option") || return 1
        package=$(jq -er '.package' <<<"$option") || return 1
        if [ "$source" = pacman ]; then
            append_unique SELECTED_PACMAN_LIST "$package"
            while IFS= read -r package; do append_unique SELECTED_PACMAN_LIST "$package"; done < <(jq -r '.extra_packages[]?' <<<"$option")
        else
            append_unique SELECTED_AUR_LIST "$package"
            while IFS= read -r package; do append_unique SELECTED_AUR_LIST "$package"; done < <(jq -r '.extra_packages[]?' <<<"$option")
        fi
    done

    append_package_words SELECTED_PACMAN_LIST "${USER_ADDED_PACMAN_PACKAGES:-}" || return 1
    append_package_words SELECTED_AUR_LIST "${USER_ADDED_AUR_PACKAGES:-}" || return 1
    for package in "${SELECTED_PACMAN_LIST[@]}" "${SELECTED_AUR_LIST[@]}"; do append_unique SELECTED_ALL_PACKAGES "$package"; done
    PACKAGE_SELECTIONS_PREPARED=true
}

is_windows() {
    case "$(uname -s)" in
        *CYGWIN*|*MINGW*|*MSYS*|*Windows_NT*) return 0 ;;
        *) return 1 ;;
    esac
}

is_dry_run() {
if is_windows; then
        print_warning "Running on Windows - forcing dry-run mode"
        return 0
    fi
    [[ "$DRY_RUN" == "true" ]]
}

log_dry_run_operation() {
    local function_name="$1"
    local operation="$2"
    DRY_RUN_OPERATIONS+=("[$function_name] $operation")
}

write_text_atomic() {
    local destination=$1 reason=$2 content=$3 tmp
    if is_dry_run; then
        write_file_atomic "$destination" /dev/null "$reason"
        return
    fi
    mkdir -p -- "$(dirname -- "$destination")"
    make_tmp tmp content.XXXXXX || return 1
    printf '%s' "$content" > "$tmp"
    write_file_atomic "$destination" "$tmp" "$reason"
}

append_text_atomic() {
    local destination=$1 reason=$2 content=$3 tmp
    if is_dry_run; then
        write_file_atomic "$destination" /dev/null "$reason"
        return
    fi
    make_tmp tmp append.XXXXXX || return 1
    [[ -f $destination ]] && cat -- "$destination" > "$tmp"
    printf '%s' "$content" >> "$tmp"
    write_file_atomic "$destination" "$tmp" "$reason"
}

sed_file_atomic() {
    local destination=$1 reason=$2
    shift 2
    edit_file_atomic "$destination" "$reason" sed "$@"
}

copy_file_atomic() {
    write_file_atomic "$1" "$2" "$3"
}

setup_etc_root() {
    if [[ ${HSS_TEST_MODE:-0} == 1 && -n ${HSS_TEST_ETC_ROOT:-} ]]; then
        printf '%s\n' "$HSS_TEST_ETC_ROOT"
    else
        printf '%s\n' /etc
    fi
}

should_init_dotfiles_git_repo() {
    # 1) Explicit CLI flag wins
    if [ "${INIT_DOTFILES_GIT_REPO:-false}" = "true" ]; then
        return 0
    fi
    # 2) Environment variable override (useful for non-interactive runs)
    case "${DOTFILES_GIT_INIT:-}" in
        1|true|yes|y|Y) return 0 ;;
        0|false|no|n|N) return 1 ;;
    esac
    # 3) Interactive prompt (default yes); non-interactive defaults to no
    if [ "${NON_INTERACTIVE:-false}" = "true" ]; then
        return 1
    fi
    if prompt_yes_no "Initialize a local git repo in \$HOME/dotfiles (no remote) after setup?"; then
        return 0
    fi
    return 1
}

init_dotfiles_git_repo() {
    local dotfiles_dir="$HOME/dotfiles"
    local repo_git_dir="$dotfiles_dir/.git"

    if ! should_init_dotfiles_git_repo; then
        print_verbose "Dotfiles git init skipped (not enabled)"
        return 0
    fi

    if [ ! -d "$dotfiles_dir" ]; then
        print_warning "Dotfiles directory not found at $dotfiles_dir; skipping git init."
        return 0
    fi

    if [ -d "$repo_git_dir" ]; then
        print_message "Dotfiles already have a git repo at $repo_git_dir; skipping git init."
        return 0
    fi

    if ! command -v git >/dev/null 2>&1; then
        print_warning "git not found; skipping dotfiles git repo initialization."
        return 0
    fi

    if is_dry_run; then
        log_dry_run_operation "init_dotfiles_git_repo" "Would init local git repo in $dotfiles_dir and create initial commit"
        return 0
    fi

    print_message "Initializing local git repo in $dotfiles_dir"
    if ! (cd "$dotfiles_dir" && git init -q); then
        print_warning "Failed to init git repo in $dotfiles_dir"
        return 1
    fi

    # Ensure local identity is set (avoid touching global git config)
    local existing_name existing_email
    existing_name=$(git -C "$dotfiles_dir" config --get user.name || true)
    existing_email=$(git -C "$dotfiles_dir" config --get user.email || true)
    if [ -z "$existing_name" ]; then
        git -C "$dotfiles_dir" config user.name "$USER" || true
    fi
    if [ -z "$existing_email" ]; then
        local host
        host="$(hostname 2>/dev/null || echo "localhost")"
        git -C "$dotfiles_dir" config user.email "${USER}@${host}" || true
    fi

    # Initial snapshot commit
    if ! (cd "$dotfiles_dir" && git add -A); then
        print_warning "Failed to stage dotfiles in $dotfiles_dir"
        return 1
    fi
    if git -C "$dotfiles_dir" diff --cached --quiet; then
        print_message "Dotfiles repo has nothing to commit (already clean)."
        return 0
    fi
    if ! (cd "$dotfiles_dir" && git commit -q -m "Initial dotfiles snapshot"); then
        print_warning "Failed to create initial commit in $dotfiles_dir"
        return 1
    fi

    print_message "Local dotfiles git repo created at $repo_git_dir"
}

execute_command() {
    local cmd="$1"
    local description="$2"
    local caller_function="${FUNCNAME[1]}"

    print_verbose "About to execute: $cmd (Description: $description)"

    # Regular command handling
    if is_dry_run; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would execute: $cmd"
        echo -e "${YELLOW}[DRY-RUN]${NC} Description: $description"
        log_dry_run_operation "$caller_function" "$description"
        sleep 0.05
        return 0
    else
        # Prefer using provided SUDO_PASSWORD to avoid prompts; fallback to -n in NON_INTERACTIVE
        local adjusted_cmd="$cmd"
        if [ -n "$SUDO_PASSWORD" ]; then
            # Define a shell sudo() that feeds the password to sudo -S
            bash -c 'sudo() { echo -n "$SUDO_PASSWORD" | command sudo -S "$@"; }; '"$adjusted_cmd"
        else
            if [ "$NON_INTERACTIVE" = "true" ]; then
                adjusted_cmd="${adjusted_cmd//sudo /sudo -n }"
            fi
            bash -c "$adjusted_cmd"
        fi
        local exit_code=$?
        print_verbose "Command executed: ${adjusted_cmd} (Exit code: $exit_code)"
        if [ $exit_code -ne 0 ]; then
            print_warning "Command for '$description' failed."
            record_soft_error "$caller_function" "$description"
        fi
        # Throttle UI output similarly to dry-run
        sleep 0.05
        return $exit_code
    fi
}

prompt_yes_no() {
    local prompt="$1"
    # Non-interactive shortcut: default to PROMPT_DEFAULT_YN (defaults to 'y')
    if [ "$NON_INTERACTIVE" = "true" ]; then
        case "${PROMPT_DEFAULT_YN:-y}" in
            [Yy]*) return 0 ;;
            *) return 1 ;;
        esac
    fi
    while true; do
        read -rp "$prompt (y/n): " yn
        # Default to 'Yy' if nothing is entered
        if [[ -z "$yn" ]]; then
            yn="y"
        fi
        case $yn in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Global confirmation gate (auto-accept in non-interactive mode)
user_confirmation() {
    if [ "$NON_INTERACTIVE" = "true" ]; then
        print_message "Non-interactive mode: auto-confirmed."
        return 0
    fi
    if prompt_yes_no "Proceed with Hyprland setup?"; then
        return 0
    else
        print_error "Setup aborted by user"
        exit 1
    fi
}

# Capture or validate sudo password once; in NON_INTERACTIVE mode a password must be provided via SUDO_PASSWORD
setup_sudo_password() {
    if [ -z "$SUDO_PASSWORD" ]; then
        if [ "$NON_INTERACTIVE" = "true" ]; then
            handle_error "SUDO_PASSWORD not provided in non-interactive mode."
        fi
        read -rsp "Enter sudo password (used for this setup only): " SUDO_PASSWORD
        echo ""
        export SUDO_PASSWORD
    fi
}

announce_step() {
    local step="$1"
    echo -e "\n${GREEN}=== $step ===${NC}\n"
}

extended_announce_step() {
    local step="$1"
    echo -e "\n${GREEN}========= $step =========${NC}\n"
}

print_dry_run_summary() {
    if [ ${#DRY_RUN_OPERATIONS[@]} -eq 0 ]; then
        echo -e "\n${YELLOW}[DRY-RUN SUMMARY]${NC} No operations were recorded."
        return
    fi

    echo -e "\n${YELLOW}[DRY-RUN SUMMARY]${NC} The following operations would have been performed:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local current_function=""
    local count=0

    for operation in "${DRY_RUN_OPERATIONS[@]}"; do
        # Extract function name from the operation string
        local function_name
        function_name=$(echo "$operation" | cut -d']' -f1 | sed 's/\[//')

        local op_description
        op_description=$(echo "$operation" | cut -d']' -f2- | sed 's/^ //')

        # Print function header when we move to a new function
        if [[ "$function_name" != "$current_function" ]]; then
            if [[ -n "$current_function" ]]; then
                echo "  Total: $count operation(s)"
                echo ""
            fi
            echo -e "${GREEN}▶ $function_name${NC}"
            current_function="$function_name"
            count=0
        fi

        # Print the operation description
        echo "  • $op_description"
        ((count++))
    done

    # Print the count for the last function
    if [[ -n "$current_function" ]]; then
        echo "  Total: $count operation(s)"
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}[DRY-RUN]${NC} No changes were made outside the run state directory: $HSS_RUN_DIR"
}

distro_install() {
    local -a packages
    packages=("$@")
    case "$DISTRO" in
        debian|ubuntu)
            execute_command "sudo apt install -y ${packages[*]}" "Install packages: ${packages[*]}"
            ;;
        fedora)
            execute_command "sudo dnf install -y ${packages[*]}" "Install packages: ${packages[*]}"
            ;;
        arch|endeavouros|cachyos)
            if ! execute_command "sudo pacman -S --needed --noconfirm ${packages[*]}" "Install packages: ${packages[*]}"; then
                check_yay
                print_warning "pacman failed, trying ${AUR_HELPER:-AUR helper} as fallback for: ${packages[*]}"
                if [ -n "$AUR_HELPER" ] && execute_command "$AUR_HELPER -S --needed --noconfirm ${packages[*]}" "Install packages with $AUR_HELPER: ${packages[*]}"; then
                    print_message "$AUR_HELPER fallback install succeeded for: ${packages[*]}"
                fi
            fi
            ;;
        *)
            print_warning "Distro '$DISTRO' not supported for package installation."
            return 1
            ;;
    esac
}

# Check if all packages of a pacman group are installed (e.g., base-devel)
is_pacman_group_installed() {
    local group="$1"
    # Only applicable on Arch-based systems with pacman
    if ! command -v pacman >/dev/null 2>&1; then
        return 1
    fi
    # Get group members
    local pkgs
    pkgs=$(pacman -Sgq "$group" 2>/dev/null) || return 1
    # If no packages found for the group, treat as not installed
    [ -z "$pkgs" ] && return 1
    # Verify each package is installed
    local pkg
    for pkg in $pkgs; do
        if ! pacman -Qq "$pkg" &>/dev/null; then
            return 1
        fi
    done
    return 0
}

# Detect first Hyprland monitor name from `hyprctl monitors`
get_first_hypr_monitor() {
    command -v hyprctl >/dev/null 2>&1 || return 1
    # Be tolerant to any leading whitespace in hyprctl output
    hyprctl monitors 2>/dev/null | awk '/^[[:space:]]*Monitor /{print $2; exit}'
}

# Ensure MONITORS is set in wallpaper config; if missing/placeholder, set to first monitor.
# Accepts an optional path to a change_wallpaper.conf; defaults to the runtime config under ~/.config.
ensure_wallpaper_monitors() {
    local wallpaper_conf="${1:-$HOME/.config/hypr/sources_specific/change_wallpaper.conf}"
    [ -f "$wallpaper_conf" ] || return 0

    # Read existing MONITORS line if any
    local current_line
    current_line=$(grep -E '^[[:space:]]*MONITORS=' "$wallpaper_conf" 2>/dev/null || true)

    # Decide if we need to set/update (no line, empty array, or contains placeholder MONITOR_N)
    local need_set=false
    if [ -z "$current_line" ]; then
        need_set=true
    elif echo "$current_line" | grep -qE 'MONITORS=\(\)'; then
        need_set=true
    elif echo "$current_line" | grep -qE 'MONITOR_[0-9]'; then
        need_set=true
    fi

    if [ "$need_set" = true ]; then
        local first_mon
        first_mon=$(get_first_hypr_monitor || true)
        if [ -z "$first_mon" ]; then
            print_warning "Could not auto-detect a monitor via hyprctl; leaving MONITORS unchanged."
            return 0
        fi
        print_message "Auto-detected monitor: $first_mon"
        replace_config_line "$wallpaper_conf" '^MONITORS=' "MONITORS=(\"$first_mon\")" "Set MONITORS to first detected monitor"
    fi
}

# Get ALL Hyprland monitor names (one per line).
get_all_hypr_monitors() {
    command -v hyprctl >/dev/null 2>&1 || return 1
    hyprctl monitors 2>/dev/null | awk '/^[[:space:]]*Monitor /{print $2}'
}

# Auto-populate monitors.conf when it contains no active (uncommented) monitor= lines.
# Generates a basic monitor=NAME,preferred,auto,1 entry for each detected monitor.
ensure_monitors_conf() {
    local monitors_conf="${1:-$HOME/.config/hypr/sources_specific/monitors.conf}"
    [ -f "$monitors_conf" ] || return 0

    # Check if there are already active monitor= lines
    if grep -qE '^[[:space:]]*monitor=' "$monitors_conf" 2>/dev/null; then
        return 0
    fi

    local monitor_names
    monitor_names=$(get_all_hypr_monitors || true)
    if [ -z "$monitor_names" ]; then
        print_warning "Could not auto-detect monitors via hyprctl; leaving monitors.conf unchanged."
        return 0
    fi

    print_message "Auto-populating monitors.conf with detected monitors..."
    local all_names=()
    local monitor_lines=()
    local x_offset=0
    while IFS= read -r mon_name; do
        [ -z "$mon_name" ] && continue
        all_names+=("$mon_name")
        local width
        width=$(hyprctl monitors 2>/dev/null | awk -v name="$mon_name" '
            /^[[:space:]]*Monitor /{found=($2==name)}
            found && /^[[:space:]]*[0-9]+x[0-9]+@/{split($1,a,"x"); split(a[2],b,"@"); print a[1]; exit}
        ')
        if ! [[ "${width:-}" =~ ^[0-9]+$ ]]; then
            width=0
        fi

        local pos="${x_offset}x0"
        monitor_lines+=("monitor=${mon_name},preferred,${pos},1")
        print_message "  Added monitor=${mon_name},preferred,${pos},1"
        x_offset=$((x_offset + width))
    done <<< "$monitor_names"

    local generated=""
    if [ "${#monitor_lines[@]}" -gt 0 ]; then
        generated+=$'\n'
        generated+="$(printf '%s\n' "${monitor_lines[@]}")"
        generated+=$'\n'
    fi
    if [ "${#all_names[@]}" -gt 0 ]; then
        local primary="${all_names[0]}"
        local secondary="${all_names[1]:-$primary}"
        generated+="$(printf '\nworkspace=1,monitor:%s,default:true\n' "$primary")"
        generated+=$'\n'
        if [ "${#all_names[@]}" -gt 1 ]; then
            generated+="$(printf 'workspace=2,monitor:%s\n' "$secondary")"
            generated+=$'\n'
        fi
    fi
    [[ -z $generated ]] || append_text_atomic "$monitors_conf" "auto-detected monitor configuration" "$generated"
}

# Apply MONITOR_CONFIG directly (name:resolution:scale;...) without requiring
# a live Hyprland session. This is primarily used by non-interactive/TUI runs.
apply_monitor_config_from_env() {
    local monitor_config="${MONITOR_CONFIG:-}"
    [ -n "$monitor_config" ] || return 1

    local hyprland_setup_dir=""
    hyprland_setup_dir="$(find_hyprland_setup_dir || true)"

    local monitor_targets=(
        "$HOME/.config/hypr/sources_specific/monitors.conf"
        "$HOME/dotfiles/.config/hypr/sources_specific/monitors.conf"
    )
    local wallpaper_targets=(
        "$HOME/.config/hypr/sources_specific/change_wallpaper.conf"
        "$HOME/dotfiles/.config/hypr/sources_specific/change_wallpaper.conf"
    )
    if [ -n "$hyprland_setup_dir" ]; then
        monitor_targets+=("$hyprland_setup_dir/dotfiles/.config/hypr/sources_specific/monitors.conf")
        wallpaper_targets+=("$hyprland_setup_dir/dotfiles/.config/hypr/sources_specific/change_wallpaper.conf")
    fi

    local entry
    local parsed_any=false
    local x_offset=0
    local monitor_lines=()
    local monitor_names=()
    IFS=';' read -ra entries <<< "$monitor_config"
    for entry in "${entries[@]}"; do
        [ -z "$entry" ] && continue
        local nm cfg sc
        nm="${entry%%:*}"
        cfg="${entry#*:}"
        sc="${cfg##*:}"
        cfg="${cfg%:*}"
        if [ -z "$nm" ] || [ -z "$cfg" ] || [ -z "$sc" ]; then
            continue
        fi

        local width="${cfg%%x*}"
        if ! [[ "$width" =~ ^[0-9]+$ ]]; then
            width=0
        fi
        local offset="${x_offset}x0"
        monitor_lines+=("monitor=${nm},${cfg},${offset},${sc}")
        monitor_names+=("$nm")
        parsed_any=true
        x_offset=$((x_offset + width))
    done

    if [ "$parsed_any" != true ]; then
        print_warning "MONITOR_CONFIG is set but could not be parsed: $monitor_config"
        return 1
    fi

    local workspace_lines=()
    if [ "${#monitor_names[@]}" -gt 0 ]; then
        workspace_lines+=("workspace=1,monitor:${monitor_names[0]},default:true")
    fi
    if [ "${#monitor_names[@]}" -gt 1 ]; then
        workspace_lines+=("workspace=2,monitor:${monitor_names[1]}")
    fi

    local mt content line
    content="# Check monitor names (e.g. DP-1, HDMI-A-1) with: \`hyprctl monitors\`"$'\n'
    for line in "${monitor_lines[@]}"; do content+="$line"$'\n'; done
    if [ "${#workspace_lines[@]}" -gt 0 ]; then
        content+=$'\n'
        for line in "${workspace_lines[@]}"; do content+="$line"$'\n'; done
    fi
    for mt in "${monitor_targets[@]}"; do
        write_text_atomic "$mt" "apply MONITOR_CONFIG" "$content"
        print_message "Applied MONITOR_CONFIG to $(basename "$mt")"
    done

    local monitors_str=""
    local m
    for m in "${monitor_names[@]}"; do
        monitors_str+="\"$m\" "
    done
    local wt
    for wt in "${wallpaper_targets[@]}"; do
        [ -f "$wt" ] || continue
        replace_config_line "$wt" '^MONITORS=' "MONITORS=($monitors_str)" "apply monitor wallpaper targets"
        print_message "Applied MONITORS to $(basename "$wt"): MONITORS=($monitors_str)"
    done

    return 0
}

############################################################## Verbosity and Error Handling Functions ##############################################################

print_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${YELLOW}[VERBOSE]${NC} $1"
    fi
}

handle_error() {
    local msg="$1"
    log_message "ERROR" "$msg"
    echo -e "${RED}[ERROR]${NC} $msg"
    exit 1
}

log_message() {
    local log_level=$1
    local message=$2
    local timestamp
    timestamp=$(date +"%Y-%m-%d %T")
    if [[ -n $LOG_FILE ]]; then
        printf '[%s] [%s] %s\n' "$timestamp" "$log_level" "$message" >> "$LOG_FILE"
    fi
}
# Function to print colored messages
print_message() {
    log_message "DEBUG" "$1"  # Log the debug message
    echo -e "${GREEN}[*] $1${NC}"
}

print_warning() {
    log_message "WARNING" "$1"  # Log the warning message
    echo -e "${YELLOW}[!] $1${NC}"
}

print_error() {
    log_message "ERROR" "$1"  # Log the error message
    echo -e "${RED}[ERROR] $1${NC}"
}

print_status_summary() {
    echo -e "\n${GREEN}========= Installation Summary =========${NC}"
    echo "Log file: $LOG_FILE"

    # Package installation results
    if [ ${#failed_packages[@]} -gt 0 ]; then
        echo -e "${RED}Failed packages:${NC}"
        for pkg in "${failed_packages[@]}"; do
            echo "  - $pkg"
        done
    else
        echo -e "${GREEN}All packages installed successfully!${NC}"
    fi

    # Configuration results
    if [ ${#config_statuses[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}Configuration Status:${NC}"
        for status in "${config_statuses[@]}"; do
            echo -e "  $status"
        done
        # Count failed configurations
        local failed_count=0
        for status in "${config_statuses[@]}"; do
            if [[ "$status" == *"$CROSS_MARK"* ]]; then
                ((failed_count++))
            fi
        done
        if [ "$failed_count" -gt 0 ]; then
            print_warning "Total failed configurations: $failed_count"
        else
            print_message "All configurations completed successfully!"
        fi
    else
        print_message "No configurations were processed"
    fi

    # Package verification
    echo -e "\n${GREEN}Package Verification:${NC}"
    verify_installed_packages
}

track_config_status() {
    local config_name="$1"
    local status="$2"
    config_statuses+=("$config_name: $status")
}

record_hard_failure() {
    local step="$1" detail="$2"
    SUMMARY_HARD_FAILURES+=("[$step] $detail")
}

record_warning() {
    local step="$1" detail="$2"
    SUMMARY_WARNINGS+=("[$step] $detail")
}

record_soft_error() {
    local step="$1" detail="$2"
    SUMMARY_SOFT_ERRORS+=("[$step] $detail")
}

record_skipped() {
    local step="$1" detail="$2"
    SUMMARY_SKIPPED+=("[$step] $detail")
}

add_recommendation_once() {
    local msg="$1"
    if [[ -z "${_SEEN_RECOMMENDATIONS[$msg]+_}" ]]; then
        _SEEN_RECOMMENDATIONS[$msg]=1
        SUMMARY_RECOMMENDATIONS+=("$msg")
    fi
}

build_summary_recommendations() {
    local entry

    for entry in "${SUMMARY_HARD_FAILURES[@]}"; do
        case "$entry" in
            *"install_pacman_packages"*)
                add_recommendation_once "Re-run failed pacman installs: sudo pacman -S --needed <package>"
                ;;
            *"install_aur_extras"*)
                add_recommendation_once "Re-run failed AUR installs: ${AUR_HELPER:-paru} -S --needed <package>"
                ;;
            *"update_arch_mirrors"*)
                add_recommendation_once "Update mirrors manually: sudo reflector --verbose --protocol https --sort rate --latest 20 --save /etc/pacman.d/mirrorlist"
                ;;
            *"configure_bluetooth"*)
                add_recommendation_once "Check bluetooth: sudo systemctl status bluetooth && sudo systemctl enable --now bluetooth"
                ;;
            *"configure_shell"*)
                add_recommendation_once "Verify the selected shell is installed and listed in /etc/shells, then run chsh for your user"
                ;;
            *"configure_network_manager"*)
                add_recommendation_once "Enable NetworkManager: sudo systemctl enable --now NetworkManager"
                ;;
            *"configure_environment"*"editor"*)
                add_recommendation_once "Install the selected TUI editor package and set EDITOR/VISUAL manually"
                ;;
            *"configure_timeshift"*)
                add_recommendation_once "Set up Timeshift manually: sudo pacman -S timeshift && sudo systemctl enable --now cronie.service"
                ;;
        esac
    done

    for entry in "${SUMMARY_SOFT_ERRORS[@]}"; do
        case "$entry" in
            *"update_arch_mirrors"*)
                add_recommendation_once "Retry mirror update: sudo reflector --verbose --protocol https --sort rate --latest 20 --save /etc/pacman.d/mirrorlist"
                ;;
            *"update_pacman"*)
                add_recommendation_once "Retry system update: sudo pacman -Syyu"
                ;;
            *"update_yay"*)
                add_recommendation_once "Retry AUR update: ${AUR_HELPER:-paru} -Sua"
                ;;
            *"enable_sddm"*)
                add_recommendation_once "Enable SDDM manually: sudo systemctl enable sddm"
                ;;
            *"EDITOR"*)
                add_recommendation_once "Set EDITOR manually: systemctl --user set-environment EDITOR=nvim"
                ;;
            *"configure_timeshift"*)
                add_recommendation_once "Create Timeshift snapshot manually: sudo timeshift --create --tags D"
                ;;
        esac
    done

    for entry in "${SUMMARY_WARNINGS[@]}"; do
        case "$entry" in
            *"wallpaper"*|*"Wallpaper"*)
                add_recommendation_once "Verify wallpaper directory exists and contains images for swww/hyprpaper"
                ;;
            *"backup"*|*"Backup"*)
                add_recommendation_once "Create a manual backup of ~/.config before making further changes"
                ;;
            *"workspace 11"*)
                add_recommendation_once "Remove workspace 11 entries from Hyprland/Waybar configs to avoid phantom workspaces"
                ;;
            *"PAM"*|*"gnome-keyring"*)
                add_recommendation_once "Verify PAM config: check /etc/pam.d/system-local-login for pam_gnome_keyring.so entries"
                ;;
            *"xdg-user-dirs"*)
                add_recommendation_once "Run xdg-user-dirs-update manually to create standard user directories"
                ;;
        esac
    done

    if [ ${#SUMMARY_HARD_FAILURES[@]} -gt 0 ]; then
        add_recommendation_once "Review the full log for details: $LOG_FILE"
    fi
}

print_final_recommendation_summary() {
    local total=$(( ${#SUMMARY_HARD_FAILURES[@]} + ${#SUMMARY_WARNINGS[@]} + ${#SUMMARY_SOFT_ERRORS[@]} + ${#SUMMARY_SKIPPED[@]} ))

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║            Final Setup Report                           ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"

    if [ "$total" -eq 0 ]; then
        echo -e "${GREEN}Everything completed without issues.${NC}"
        echo ""
        return
    fi

    if [ ${#SUMMARY_HARD_FAILURES[@]} -gt 0 ]; then
        echo ""
        echo -e "${RED}Hard Failures (${#SUMMARY_HARD_FAILURES[@]}):${NC}"
        for entry in "${SUMMARY_HARD_FAILURES[@]}"; do
            echo -e "  ${RED}$CROSS_MARK${NC} $entry"
        done
    fi

    if [ ${#SUMMARY_SOFT_ERRORS[@]} -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}Soft Errors (${#SUMMARY_SOFT_ERRORS[@]}):${NC}"
        for entry in "${SUMMARY_SOFT_ERRORS[@]}"; do
            echo -e "  ${YELLOW}!${NC} $entry"
        done
    fi

    if [ ${#SUMMARY_WARNINGS[@]} -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}Warnings (${#SUMMARY_WARNINGS[@]}):${NC}"
        for entry in "${SUMMARY_WARNINGS[@]}"; do
            echo -e "  ${YELLOW}~${NC} $entry"
        done
    fi

    if [ ${#SUMMARY_SKIPPED[@]} -gt 0 ]; then
        echo ""
        echo -e "Skipped Steps (${#SUMMARY_SKIPPED[@]}):"
        for entry in "${SUMMARY_SKIPPED[@]}"; do
            echo "  $CIRCLE $entry"
        done
    fi

    build_summary_recommendations

    if [ ${#SUMMARY_RECOMMENDATIONS[@]} -gt 0 ]; then
        echo ""
        echo -e "${GREEN}Recommendations:${NC}"
        local i=1
        for rec in "${SUMMARY_RECOMMENDATIONS[@]}"; do
            echo -e "  ${i}. $rec"
            ((i++))
        done
    fi

    echo ""
    echo "Log file: $LOG_FILE"
    echo ""
}

verify_installed_packages() {
    [ "$SELECTED_PACKAGES_VERIFIED" = true ] && return 0
    extended_announce_step "Verifying selected packages"
    prepare_package_selections || return 1

    if is_dry_run; then
        log_dry_run_operation "verify_installed_packages" "Would run pacman -T for ${#SELECTED_ALL_PACKAGES[@]} selected and role packages"
        print_message "Dry-run: skipping selected-package verification"
        SELECTED_PACKAGES_VERIFIED=true
        return 0
    fi

    local output status=0 package
    output=$(pacman -T "${SELECTED_ALL_PACKAGES[@]}" 2>&1) || status=$?
    if [ -z "$output" ]; then
        print_message "All ${#SELECTED_ALL_PACKAGES[@]} selected packages are satisfied"
        track_config_status "Package Verification" "$CHECK_MARK"
        SELECTED_PACKAGES_VERIFIED=true
        return 0
    fi

    print_warning "Selected packages are not satisfied:"
    while IFS= read -r package; do
        [ -n "$package" ] || continue
        printf '  - %s\n' "$package"
        record_hard_failure "verify_installed_packages" "Selected package '$package' is not satisfied (pacman -T exit $status)"
    done <<< "$output"
    track_config_status "Package Verification" "$CROSS_MARK"
    SELECTED_PACKAGES_VERIFIED=true
    return 1
}

############################################################## Check Functions ##############################################################

check_bootloader() {
    local bootloader="Unknown"

    if [ -d /sys/firmware/efi ]; then
        print_message "System is booted in UEFI mode."
    else
        print_message "System is booted in legacy BIOS mode."
    fi

    if [ -f /boot/grub/grub.cfg ] || [ -f /boot/grub2/grub.cfg ] || command -v grub-install &>/dev/null; then
        bootloader="GRUB"
    elif [ -d /boot/loader ] || [ -f /boot/loader/loader.conf ] || command -v bootctl &>/dev/null; then
        bootloader="systemd-boot"
    elif [ -d /EFI/refind ] || [ -f /boot/EFI/refind/refind.conf ] || command -v refind-install &>/dev/null; then
        bootloader="rEFInd"
    elif [ -f /boot/syslinux/syslinux.cfg ] || command -v syslinux &>/dev/null; then
        bootloader="Syslinux"
    fi

    print_message "Detected bootloader: $bootloader"
    export BOOTLOADER="$bootloader"
}

check_yay() {
    # Prevent duplicate checks/installs within one run
    if [ "$AUR_HELPER_CHECKED" = "true" ] && [ -n "$AUR_HELPER" ]; then
        return 0
    fi
    # Prefer paru if available
    if command -v paru &>/dev/null; then
        AUR_HELPER="paru"
        print_message "Detected paru. Using paru as AUR helper (skipping yay installation)."
        AUR_HELPER_CHECKED="true"
        return 0
    fi
    # Fallback to yay if installed
    if command -v yay &> /dev/null; then
        AUR_HELPER="yay"
        print_message "yay is already installed."
        AUR_HELPER_CHECKED="true"
        return 0
    fi

    print_message "No AUR helper found. Installing yay..."

    if is_windows; then
        print_message "Running on Windows - skipping yay installation"
        AUR_HELPER_CHECKED="true"
        return 0
    fi

    # Check for required packages
    local missing_packages=()
    # Simple base-devel presence check (handles modern Arch where it's a meta-package)
    if ! pacman -Qq base-devel 2>/dev/null | head -n1 | grep -qx 'base-devel'; then
        missing_packages+=("base-devel")
    fi
    if ! command -v debugedit &>/dev/null; then
        missing_packages+=("debugedit")
    fi
    if ! command -v git &> /dev/null; then
        missing_packages+=("git")
    fi

    # Install missing packages if any
    if [ ${#missing_packages[@]} -gt 0 ]; then
        print_message "Installing required packages: ${missing_packages[*]}"
        distro_install "${missing_packages[@]}"
    fi

    # Clone the yay repo and build it
    execute_command "git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay repository"
    cd /tmp/yay > /dev/null || return 
    execute_command "makepkg -si --noconfirm" "Build and install yay"

    # Verify installation was successful
    if ! command -v yay &> /dev/null; then
        handle_error "'yay' installation failed. Please install yay manually and re-run the script."
    else
        AUR_HELPER="yay"
        print_message "yay installed successfully!"
    fi
    AUR_HELPER_CHECKED="true"
}

check_disk_space() {
    local required_space=10000000  # 10GB in KB
    local available_space
    available_space=$(df /usr | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt "$required_space" ]; then
        handle_error "Insufficient disk space. At least 10GB required in /usr."
    else
        print_message "Sufficient disk space available: $((available_space / 1024)) MB"
    fi
}

check_dependencies() {
    # Skip dependency checks on Windows or in dry-run mode
    if is_windows || is_dry_run; then
        if is_windows; then
            print_message "Running on Windows - skipping dependency checks"
        else
            log_dry_run_operation "check_dependencies" "Would check and install missing dependencies"
            print_message "Dry-run: skipping dependency checks"
        fi
        # Still check for AUR helper (which will skip on Windows)
        check_yay
        return 0
    fi

    local deps_cmds=("git" "sudo" "debugedit")
    local missing_cmds=()

    for dep in "${deps_cmds[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_cmds+=("$dep")
        fi
    done

    # Determine Arch-based and check base-devel via pacman -Qq
    local need_base_devel=false
    if [[ "$DISTRO" == "arch" || "$DISTRO" == "endeavouros" || "$DISTRO" == "cachyos" ]]; then
        if ! pacman -Qq base-devel 2>/dev/null | head -n1 | grep -qx 'base-devel'; then
            need_base_devel=true
        fi
    fi

    # Install missing core deps first (so building yay works later)
    local to_install=()
    if [ ${#missing_cmds[@]} -gt 0 ]; then
        to_install+=("${missing_cmds[@]}")
    fi
    if [ "$need_base_devel" = true ]; then
        to_install+=("base-devel")
    fi

    if [ ${#to_install[@]} -gt 0 ]; then
        print_message "Installing missing dependencies: ${to_install[*]}"
        if ! distro_install "${to_install[@]}"; then
            print_error "Failed to install: ${to_install[*]}"
            exit 1
        fi
    fi

    # Re-verify core deps
    missing_cmds=()
    for dep in "${deps_cmds[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_cmds+=("$dep")
        fi
    done
    need_base_devel=false
    if [[ "$DISTRO" == "arch" || "$DISTRO" == "endeavouros" || "$DISTRO" == "cachyos" ]]; then
        if ! pacman -Qq base-devel 2>/dev/null | head -n1 | grep -qx 'base-devel'; then
            need_base_devel=true
        fi
    fi

    if [ ${#missing_cmds[@]} -gt 0 ] || [ "$need_base_devel" = true ]; then
        print_error "Missing dependencies after install attempt: ${missing_cmds[*]}${need_base_devel:+ base-devel}"
        exit 1
    fi

    # Ensure AUR helper exists (prefer paru, else install yay)
    check_yay
}

check_distro() {
    if is_windows; then
        print_message "Running on Windows in dry-run mode. Simulating Arch Linux environment."
        DISTRO="arch"
        return 0
    fi

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        print_message "Detected distro: $ID"
        DISTRO=$ID
    else
        handle_error "Could not detect Linux distribution. Ensure /etc/os-release exists and is readable."
    fi
}

check_desktop_environment() {
    if [ -n "$XDG_CURRENT_DESKTOP" ]; then
        print_message "Current Desktop Session: $XDG_CURRENT_DESKTOP"
    elif [ -n "$DESKTOP_SESSION" ]; then
        print_message "Current Desktop Session: $DESKTOP_SESSION"
    elif execute_command "pgrep -x plasmashell > /dev/null"; then
        print_message "Current Desktop Session: KDE"
    elif execute_command "pgrep -x Hyprland > /dev/null" || [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
        print_message "Current Desktop Session: Hyprland"
    elif execute_command "pgrep -x gnome-shell > /dev/null"; then
        print_message "Current Desktop Session: GNOME"
    elif execute_command "pgrep -x xfce4-session > /dev/null"; then
        print_message "Current Desktop Session: XFCE"
    else
        print_message "Current Desktop Session: Unknown"
    fi
}

check_hyprland() {
    print_message "Checking if Hyprland is running"
    if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && [ "$XDG_CURRENT_DESKTOP" = "Hyprland" ]; then
        return 0
    else
        return 1
    fi
}

check_environment() {
    local required_vars=("HOME" "USER" "SHELL" "PATH" "LANG" "PWD")
    local missing_vars=()

    # Check required environment variables
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -gt 0 ]; then
        handle_error "Missing required environment variables: ${missing_vars[*]}"
    fi

    # Check if running with correct permissions
    if [ "$(id -u)" -eq 0 ]; then
        handle_error "Script is being run as root. Please run as a regular user with sudo privileges."
    fi

    # Check if sudo is available and user has sudo rights
    if ! command -v sudo >/dev/null; then
        handle_error "'sudo' is not installed. Please install sudo and re-run the script."
    else
        # In dry-run we don't need to validate sudo
        if is_dry_run; then
            : # skip
        else
            if [ -n "$SUDO_PASSWORD" ]; then
                # Validate provided password; -k ignores any cached creds; -v validates only
                if ! echo "$SUDO_PASSWORD" | sudo -S -k -v &>/dev/null; then
                    handle_error "Invalid sudo password or sudo not configured for this user."
                fi
            else
                if [ "$NON_INTERACTIVE" = "true" ]; then
                    handle_error "SUDO_PASSWORD not provided in non-interactive mode."
                fi
                # Interactive validation (may prompt)
                if ! sudo -v &>/dev/null; then
                    handle_error "Unable to validate sudo credentials."
                fi
            fi
        fi
    fi

    # Validate log directory and permissions
    local logdir
    logdir=$(dirname "$LOG_FILE")
    if [ ! -d "$logdir" ]; then
        mkdir -p "$logdir" || { handle_error "Cannot create log directory: $logdir. Check permissions."; }
    fi
    if [ ! -w "$logdir" ]; then
        handle_error "Log directory $logdir is not writable. Check permissions."
    fi

    print_message "Environment validation successful"
}

############################################################## User Specific Functions ##############################################################

validate_wallpaper_dir() {
    if [ ! -d "$WALLPAPER_DIR" ]; then
        print_error "Wallpaper directory does not exist: $WALLPAPER_DIR"
        return 1
    fi

    # Check for at least one image file with error handling
    if ! find "$WALLPAPER_DIR" -maxdepth 1 -type f -print0 2>/dev/null | 
       xargs -0 file --mime-type 2>/dev/null | 
       grep -q "image/"; then
        print_error "No image files found in wallpaper directory"
        return 1
    fi
    return 0
}

# Prefer $HOME/Pictures; fallback to $HOME/Bilder; create Pictures if neither exists.
resolve_user_pictures_dir() {
    local pictures_dir="$HOME/Pictures"
    local bilder_dir="$HOME/Bilder"

    if [ -d "$pictures_dir" ]; then
        echo "$pictures_dir"
        return 0
    fi

    if [ -d "$bilder_dir" ]; then
        echo "$bilder_dir"
        return 0
    fi

    # If user doesn't have either (or uses custom XDG dirs), default to Pictures.
    if is_dry_run; then
        log_dry_run_operation "update_configs" "Would create directory $pictures_dir: user pictures directory"
    else
        mkdir -p "$pictures_dir"
    fi
    echo "$pictures_dir"
}

# Function to check and prompt user input for required variables
check_user_input() {
    # Find Hyprland-Simple-Setup directory first
    local hyprland_setup_dir
    hyprland_setup_dir=$(find_hyprland_setup_dir)
    if [ -z "$hyprland_setup_dir" ]; then
        print_error "Could not find $SETUP_DIR directory"
        return 1
    fi

    # Set default wallpaper directory
    local default_wallpaper_dir="$hyprland_setup_dir/Wallpaper"

    # Check if WALLPAPER_DIR is set, prompt if not
    if [ -z "$WALLPAPER_DIR" ]; then
        if [ "$NON_INTERACTIVE" = "true" ]; then
            export WALLPAPER_DIR="${WALLPAPER_DIR_OVERRIDE:-$default_wallpaper_dir}"
        else
            echo "WALLPAPER_DIR is not set."
            read -rp "Please enter the path to your wallpaper directory or use Default (Default: [$default_wallpaper_dir]): " input_wallpaper_dir
            export WALLPAPER_DIR="${input_wallpaper_dir:-$default_wallpaper_dir}"
        fi
    fi
}

find_hyprland_setup_dir() {
    # 0) Allow explicit override via environment variable
    if [ -n "${HYPRLAND_SETUP_DIR:-}" ] && [ -d "${HYPRLAND_SETUP_DIR}" ]; then
        echo "${HYPRLAND_SETUP_DIR}"
        return 0
    fi

    # 0b) Use HYPR_SETUP_PATH from AUR wrapper (points to setup.sh inside share dir)
    if [ -n "${HYPR_SETUP_PATH:-}" ]; then
        local from_wrapper
        from_wrapper="$(dirname -- "$HYPR_SETUP_PATH")"
        if [ -d "$from_wrapper" ]; then
            echo "$from_wrapper"
            return 0
        fi
    fi

    # 1) Prefer the directory of this script (repo root in typical layout)
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
    if [ -d "$script_dir/dotfiles" ] || [ "$(basename "$script_dir")" = "$SETUP_DIR" ]; then
        echo "$script_dir"
        return 0
    fi

    # 2) If inside a git repo, use the toplevel directory
    if command -v git >/dev/null 2>&1; then
        local git_root
        git_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null || true)"
        if [ -n "$git_root" ] && [ -d "$git_root" ]; then
            if [ -d "$git_root/dotfiles" ] || [ "$(basename "$git_root")" = "$SETUP_DIR" ]; then
                echo "$git_root"
                return 0
            fi
        fi
    fi

    # 3) Check known installed locations
    if [ -d "/usr/share/hyprland-simple-setup-git" ]; then
        echo "/usr/share/hyprland-simple-setup-git"
        return 0
    fi
    if [ -d "/usr/share/Hyprland-Simple-Setup" ]; then
        echo "/usr/share/Hyprland-Simple-Setup"
        return 0
    fi

    # 4) Search common user directories (wider net, slightly deeper)
    local search_paths=(
        "$PWD"
        "$HOME"
        "$HOME/Dokumente"
        "$HOME/Documents"
        "$HOME/Downloads"
        "$HOME/GitHub"
        "$HOME/Projects"
        "$HOME/Workspace"
    )
    local path
    for path in "${search_paths[@]}"; do
        if [ -d "$path" ]; then
            local found_dir
            found_dir=$(find "$path" -maxdepth 6 -type d \( -name "$SETUP_DIR" -o -name "hyprland-simple-setup-git" \) 2>/dev/null | head -n 1)
            if [ -n "$found_dir" ]; then
                echo "$found_dir"
                return 0
            fi
        fi
    done

    # Not found
    return 1
}

# Function to update configuration files with user input
update_configs() {
    announce_step "Update configs"

    # Find Hyprland-Simple-Setup directory
    local hyprland_setup_dir
    hyprland_setup_dir=$(find_hyprland_setup_dir)
    if [ -z "$hyprland_setup_dir" ]; then
        print_error "Could not find $SETUP_DIR directory"
        print_warning "Tip: set HYPRLAND_SETUP_DIR to the project root and re-run."
        track_config_status "Dotfiles Setup" "$CROSS_MARK"
        return 1
    fi

    # Check for dotfiles directory in $HOME
    if [ ! -d "$HOME/dotfiles" ]; then
        # Check if source directory exists
        if [ -d "$hyprland_setup_dir/dotfiles" ]; then
            # Copy Dotfiles directory to $HOME Directory
            if execute_command "cp -r '$hyprland_setup_dir/dotfiles' '$HOME/dotfiles'" "Copy dotfiles to Home directory"; then
                print_message "Dotfiles were successfully copied to Home directory"
            else
                print_error "Failed to copy dotfiles to Home directory"
            fi
        else
            print_error "Source dotfiles directory not found at $hyprland_setup_dir/dotfiles"
        fi
    else
        print_warning "Dotfiles directory already exists in Home directory"
    fi

    # Continue with the rest of the configuration
    local hypr_config_dir="$HOME/dotfiles/.config/hypr"

    if [ -d "$hypr_config_dir/sources_example" ]; then
        print_message "Copying sources_example to sources if not existent..."
        if [ ! -d "$hypr_config_dir/sources" ]; then
            execute_command "cp -r '$hypr_config_dir/sources_example' '$hypr_config_dir/sources'" "Copy sources_example to sources"
        fi
    else
        print_error "sources_example directory not found in $hypr_config_dir"
        execute_command "mkdir -p '$hypr_config_dir/sources'" "Create sources directory"
    fi

    # Update app_variables.conf to use hyprland_setup_dir instead of ~
    local app_vars_conf="$hypr_config_dir/sources/app_variables.conf"
    if [ -f "$app_vars_conf" ]; then
        print_message "Updating wallpaper path in app_variables.conf..."
        sed_file_atomic "$app_vars_conf" "Update wallpaper path in app_variables.conf" "s|\\\$wallpaper=~/$SETUP_DIR/Wallpaper/Forest_01.png|\\\$wallpaper=\"$hyprland_setup_dir/Wallpaper/Forest_01.png\"|g"
    else
        print_warning "app_variables.conf not found at $app_vars_conf"
    fi

    # Run stow script after copying sources_example
    if [ -f "$HOME/dotfiles/.local/scripts/Start_stow_solve.sh" ]; then
        print_message "Setting up dotfiles with Start_stow_solve.sh..."
        if is_dry_run; then
            log_dry_run_operation "update_configs" "Would run Stow setup from $HOME/dotfiles/.local/scripts/Start_stow_solve.sh"
        elif bash "$HOME/dotfiles/.local/scripts/Start_stow_solve.sh"; then
            print_message "Stow script executed successfully"
            track_config_status "Dotfiles Setup" "$CHECK_MARK"
            init_dotfiles_git_repo || true
        else
            print_error "Stow script failed to execute properly"
            track_config_status "Dotfiles Setup" "$CROSS_MARK"
        fi
    else
        print_warning "Start_stow_solve.sh not found at $HOME/dotfiles/.local/scripts"
        print_warning "Skipping dotfiles setup"
        track_config_status "Dotfiles Setup" "$CROSS_MARK"
    fi

    # Copy wallpapers into the user's pictures directory (Pictures or Bilder).
    # This ensures change_wallpaper.sh can pick wallpapers from a stable location.
    local source_wallpaper_dir="$WALLPAPER_DIR"
    local pictures_base
    pictures_base="$(resolve_user_pictures_dir)"
    local target_wallpaper_dir="$pictures_base/Wallpapers"
    execute_command "mkdir -p '$target_wallpaper_dir'" "Create wallpapers directory in pictures folder"
    execute_command "cp -a '$source_wallpaper_dir/.' '$target_wallpaper_dir/'" "Copy wallpapers into $target_wallpaper_dir"

    # Point WALLPAPER_DIR to the copied location from here on.
    WALLPAPER_DIR="$target_wallpaper_dir"

    # Update the wallpaper configuration file.
    # Keep both the runtime config under ~/.config and the stow source under ~/dotfiles in sync.
    local wallpaper_conf_runtime="$HOME/.config/hypr/sources_specific/change_wallpaper.conf"
    local wallpaper_conf_source="$HOME/dotfiles/.config/hypr/sources_specific/change_wallpaper.conf"
    local wallpaper_conf
    for wallpaper_conf in "$wallpaper_conf_runtime" "$wallpaper_conf_source"; do
        execute_command "mkdir -p '$(dirname "$wallpaper_conf")'" "Create wallpaper config directory ($(basename "$wallpaper_conf"))"
        if [ -f "$wallpaper_conf" ]; then
            replace_config_line "$wallpaper_conf" '^WALLPAPER_DIR=' "WALLPAPER_DIR=\"$WALLPAPER_DIR\"" "Update WALLPAPER_DIR without touching MONITORS ($(basename "$wallpaper_conf"))"
        else
            write_text_atomic "$wallpaper_conf" "Create initial wallpaper config ($(basename "$wallpaper_conf"))" "# Wallpaper Configuration
WALLPAPER_DIR=\"$WALLPAPER_DIR\"
"
        fi

        # Ensure MONITORS is set (auto-detect first monitor if user did not set)
        ensure_wallpaper_monitors "$wallpaper_conf"
    done

    # Auto-populate monitors.conf if it has no active monitor= lines
    local monitors_conf_runtime="$HOME/.config/hypr/sources_specific/monitors.conf"
    local monitors_conf_source="$HOME/dotfiles/.config/hypr/sources_specific/monitors.conf"
    for mc in "$monitors_conf_runtime" "$monitors_conf_source"; do
        [ -f "$mc" ] && ensure_monitors_conf "$mc"
    done

    print_message "Configuration files updated with user input."
}

# Function to update fish language config in fish config file
set_fish_language_config() {
    local fish_conf="$HOME/dotfiles/.config/fish/conf.d/01-env.fish"
    local lang language

    # Trim whitespace and ensure we have a valid numeric value
    FISH_LANGUAGE_CHOICE=$(echo "$FISH_LANGUAGE_CHOICE" | tr -d '[:space:]')
    
    print_verbose "FISH_LANGUAGE_CHOICE value: '$FISH_LANGUAGE_CHOICE'"

    case "$FISH_LANGUAGE_CHOICE" in
        1)
            lang="de_CH.UTF-8"
            language="de_CH:en_US"
            ;;
        2)
            lang="de_DE.UTF-8"
            language="de_DE:en_US"
            ;;
        3)
            lang="en_US.UTF-8"
            language="en_US:de_CH"
            ;;
        *)
            print_warning "Invalid FISH_LANGUAGE_CHOICE value: '$FISH_LANGUAGE_CHOICE'. Using default (de_CH)."
            lang="de_CH.UTF-8"
            language="de_CH:en_US"
            ;;
    esac
    
    print_verbose "Selected language: LANG=$lang, LANGUAGE=$language"

    # Check if file exists (try both dotfiles source and symlinked location)
    local fish_conf_runtime="$HOME/.config/fish/conf.d/01-env.fish"
    
    # Update the source file in dotfiles (this will propagate to symlink if stow has run)
    if [ ! -f "$fish_conf" ]; then
        print_message "Creating fish config file at $fish_conf"
        write_text_atomic "$fish_conf" "Add initial language settings" "# Language Settings
set -gx LANG \"$lang\"
set -gx LANGUAGE \"$language\"

"
    else
        print_message "Updating existing fish config file at $fish_conf"
        replace_config_line "$fish_conf" '^set -gx LANG ' "set -gx LANG \"$lang\"" "Update LANG"
        replace_config_line "$fish_conf" '^set -gx LANGUAGE ' "set -gx LANGUAGE \"$language\"" "Update LANGUAGE"
    fi
    
    # Also update the runtime location if it exists and is not a symlink (or if symlink is broken)
    if [ -f "$fish_conf_runtime" ] && [ ! -L "$fish_conf_runtime" ]; then
        print_message "Also updating runtime fish config file at $fish_conf_runtime"
        replace_config_line "$fish_conf_runtime" '^set -gx LANG ' "set -gx LANG \"$lang\"" "Update LANG in runtime config"
        replace_config_line "$fish_conf_runtime" '^set -gx LANGUAGE ' "set -gx LANGUAGE \"$language\"" "Update LANGUAGE in runtime config"
    fi

    print_message "Fish language settings updated: LANG=$lang, LANGUAGE=$language"
}

# Role-driven writers share the reliability transaction and preserve Stow symlinks.
role_write_file() {
    write_file_atomic "$1" "$2" "$3"
}

replace_config_line() {
    local file=$1 pattern=$2 replacement=$3 reason=$4 tmp
    [ -f "$file" ] || return 0
    if is_dry_run; then
        write_file_atomic "$file" /dev/null "$reason"
        return 0
    fi
    make_tmp tmp role-edit.XXXXXX || return 1
    awk -v pattern="$pattern" -v replacement="$replacement" '
        $0 ~ pattern {
            if (!replaced) print replacement
            replaced = 1
            next
        }
        { print }
        END { if (!replaced) print replacement }
    ' "$file" > "$tmp" && role_write_file "$file" "$tmp" "$reason"
}

replace_literal_assignment() {
    local file=$1 name=$2 replacement=$3 reason=$4 tmp
    [ -f "$file" ] || return 0
    if is_dry_run; then
        write_file_atomic "$file" /dev/null "$reason"
        return 0
    fi
    make_tmp tmp role-edit.XXXXXX || return 1
    awk -v name="$name" -v replacement="$replacement" '
        index($0, name) == 1 && substr($0, length(name) + 1) ~ /^[[:space:]]*=/ {
            if (!replaced) print replacement
            replaced = 1
            next
        }
        { print }
        END { if (!replaced) print replacement }
    ' "$file" > "$tmp" && role_write_file "$file" "$tmp" "$reason"
}

replace_literal_prefix() {
    local file=$1 prefix=$2 replacement=$3 reason=$4 tmp
    [ -f "$file" ] || return 0
    if is_dry_run; then
        write_file_atomic "$file" /dev/null "$reason"
        return 0
    fi
    make_tmp tmp role-edit.XXXXXX || return 1
    awk -v prefix="$prefix" -v replacement="$replacement" '
        index($0, prefix) == 1 {
            if (!replaced) print replacement
            replaced = 1
            next
        }
        { print }
        END { if (!replaced) print replacement }
    ' "$file" > "$tmp" && role_write_file "$file" "$tmp" "$reason"
}

remove_config_matching() {
    local file=$1 pattern=$2 reason=$3 tmp
    [ -f "$file" ] || return 0
    if is_dry_run; then
        write_file_atomic "$file" /dev/null "$reason"
        return 0
    fi
    make_tmp tmp role-edit.XXXXXX || return 1
    awk -v pattern="$pattern" '$0 !~ pattern { print }' "$file" > "$tmp" && role_write_file "$file" "$tmp" "$reason"
}

generate_roles_json() {
    load_role_selections || return 1
    local generated source_file runtime_file source_tmp runtime_tmp
    source_file="$HOME/dotfiles/.config/hypr/roles.json"
    runtime_file="$HOME/.config/hypr/roles.json"
    generated=$(jq -ce \
        --arg browser "$ROLE_BROWSER" \
        --arg terminal "$ROLE_TERMINAL" \
        --arg shell "$ROLE_SHELL" \
        --arg gui_editor "$ROLE_GUI_EDITOR" \
        --arg tui_editor "$ROLE_TUI_EDITOR" \
        --arg launcher "$ROLE_LAUNCHER" \
        --arg home "$HOME" '
        . as $registry |
        {browser: $browser, terminal: $terminal, shell: $shell, gui_editor: $gui_editor, tui_editor: $tui_editor, launcher: $launcher} as $selected |
        {schema_version: 1, roles: ($selected | to_entries | map(.key as $role | .value as $package | {key: $role, value: ($registry.roles[$role].options[] | select(.package == $package))}) | from_entries)} |
        walk(if type == "string" and startswith("{HOME}/") then $home + ltrimstr("{HOME}") else . end)
    ' "$PACKAGE_REGISTRY") || return 1

    ROLE_DATA_FILE=$runtime_file
    if is_dry_run; then
        write_file_atomic "$source_file" /dev/null "selected runtime role metadata"
        write_file_atomic "$runtime_file" /dev/null "selected runtime role metadata"
        return 0
    fi

    mkdir -p "$(dirname "$source_file")" "$(dirname "$runtime_file")"
    make_tmp source_tmp roles-json.XXXXXX || return 1
    printf '%s\n' "$generated" | jq . > "$source_tmp"
    role_write_file "$source_file" "$source_tmp" "selected runtime role metadata"

    if [ "$(readlink -f "$source_file")" != "$(readlink -f "$runtime_file" 2>/dev/null || printf '%s' "$runtime_file")" ]; then
        make_tmp runtime_tmp roles-json.XXXXXX || return 1
        printf '%s\n' "$generated" | jq . > "$runtime_tmp"
        role_write_file "$runtime_file" "$runtime_tmp" "selected runtime role metadata"
    fi
}

runtime_role_command() {
    local role=$1 field=${2:-args}
    jq -er --arg role "$role" --arg field "$field" '[.roles[$role].executable] + (.roles[$role][$field] // []) | @sh' "$ROLE_DATA_FILE"
}

configure_roles() {
    announce_step "Configuring selected application roles"
    generate_roles_json || return 1
    if is_dry_run; then
        # The remaining paths are still reported even though roles.json is not written in WS-3 dry-run mode.
        ROLE_DATA_FILE="$HOME/.config/hypr/roles.json"
    fi

    local terminal_command browser_command editor_command launcher_command
    local browser_exec browser_class terminal_exec editor_bin menu_dmenu launcher_process launcher_namespace
    if is_dry_run; then
        terminal_command=$(role_option_json terminal | jq -r '[.executable] + .args | @sh')
        browser_command=$(role_option_json browser | jq -r '[.executable] + .args | @sh')
        editor_command=$(role_option_json gui_editor | jq -r '[.executable] + .args | @sh')
        launcher_command=$(role_option_json launcher | jq -r '[.executable] + .args | @sh')
        browser_exec=$(role_field browser executable)
        browser_class=$(role_field browser class)
        terminal_exec=$(role_field terminal executable)
        editor_bin=$(role_field tui_editor editor_bin)
        menu_dmenu=$(role_option_json launcher | jq -r '[.dmenu_executable] + .dmenu_args | join(" ")')
        launcher_process=$(role_field launcher process)
        launcher_namespace=$(role_field launcher namespace)
    else
        terminal_command=$(runtime_role_command terminal)
        browser_command=$(runtime_role_command browser)
        editor_command=$(runtime_role_command gui_editor)
        launcher_command=$(runtime_role_command launcher)
        browser_exec=$(jq -er '.roles.browser.executable' "$ROLE_DATA_FILE")
        browser_class=$(jq -er '.roles.browser.class' "$ROLE_DATA_FILE")
        terminal_exec=$(jq -er '.roles.terminal.executable' "$ROLE_DATA_FILE")
        editor_bin=$(jq -er '.roles.tui_editor.editor_bin' "$ROLE_DATA_FILE")
        menu_dmenu=$(jq -er '[.roles.launcher.dmenu_executable] + .roles.launcher.dmenu_args | join(" ")' "$ROLE_DATA_FILE")
        launcher_process=$(jq -er '.roles.launcher.process' "$ROLE_DATA_FILE")
        launcher_namespace=$(jq -er '.roles.launcher.namespace' "$ROLE_DATA_FILE")
    fi

    local root file
    for root in "$HOME/dotfiles/.config/hypr/sources" "$HOME/dotfiles/.config/hypr/sources_example"; do
        file="$root/app_variables.conf"
        replace_literal_assignment "$file" '$terminal' "\$terminal = $terminal_command" "selected terminal"
        replace_literal_assignment "$file" '$menu' "\$menu = $launcher_command" "selected launcher"
        replace_literal_assignment "$file" '$browser' "\$browser = $browser_command" "selected browser"
        replace_literal_assignment "$file" '$editor' "\$editor = $editor_command" "selected GUI editor"

        file="$root/environment_variables.conf"
        replace_config_line "$file" '^env = BROWSER,' "env = BROWSER,$browser_exec" "selected browser environment"

        file="$root/keybindings.conf"
        replace_literal_prefix "$file" 'bindd = $mainMod, SPACE, Open Menu,' "bindd = \$mainMod, SPACE, Open Menu, exec, pkill $launcher_process || \$menu" "selected launcher process"

        file="$root/windows_and_workspaces.conf"
        remove_config_matching "$file" '^windowrule = workspace 2.*match:class' "replace browser role rule"
        replace_config_line "$file" '^windowrule = workspace 2.*match:class' "windowrule = workspace 2 silent, match:class $browser_class" "selected browser workspace rule"
        remove_config_matching "$file" '^layerrule = dim_around on, match:namespace' "replace launcher layer rule"
        replace_config_line "$file" '^layerrule = dim_around on, match:namespace' "layerrule = dim_around on, match:namespace $launcher_namespace" "selected launcher namespace"
    done

    local fish_files=(
        "$HOME/dotfiles/.config/fish/conf.d/01-env.fish"
        "$HOME/.config/fish/conf.d/01-env.fish"
    )
    for file in "${fish_files[@]}"; do
        [ -L "$file" ] && [ "$file" != "${fish_files[0]}" ] && continue
        replace_config_line "$file" '^set -gx EDITOR ' "set -gx EDITOR $editor_bin" "selected TUI editor"
        replace_config_line "$file" '^set -gx VISUAL ' "set -gx VISUAL $editor_bin" "selected TUI editor"
        replace_config_line "$file" '^set -x TERMINAL |^set -gx TERMINAL ' "set -gx TERMINAL $terminal_exec" "selected terminal"
        replace_config_line "$file" '^set -x BROWSER |^set -gx BROWSER ' "set -gx BROWSER $browser_exec" "selected browser"
        replace_config_line "$file" '^set -gx MANPAGER ' "set -gx MANPAGER '$editor_bin'" "selected TUI editor pager"
        replace_config_line "$file" '^set -gx MENU_DMENU ' "set -gx MENU_DMENU \"$menu_dmenu\"" "selected launcher dmenu command"
    done

    local aliases="$HOME/dotfiles/.config/fish/conf.d/02-aliases.fish"
    remove_config_matching "$aliases" '^alias (vi|vim)=' "remove stale editor aliases"
    if [ "$ROLE_TUI_EDITOR" = neovim ]; then
        replace_config_line "$aliases" '^# hss-role:editor-aliases$' "alias vi='nvim'; alias vim='nvim' # hss-role:editor-aliases" "Neovim aliases"
    else
        remove_config_matching "$aliases" '# hss-role:editor-aliases' "remove Neovim-only aliases"
    fi

    print_message "Configured roles: browser=$ROLE_BROWSER terminal=$ROLE_TERMINAL shell=$ROLE_SHELL gui_editor=$ROLE_GUI_EDITOR tui_editor=$ROLE_TUI_EDITOR launcher=$ROLE_LAUNCHER"
}
configure_hypr_autostart_optional_extras() {
    uncomment_line_if_cmd_exists() {
        local conf_file="$1"
        local cmd="$2"
        local line="$3"
        command -v "$cmd" >/dev/null 2>&1 || return 0
        replace_literal_prefix "$conf_file" "# $line" "$line" "Enable autostart: ${cmd}"
    }

    uncomment_line_if_unit_exists() {
        local conf_file="$1"
        local unit="$2"
        local line="$3"
        systemctl --user list-unit-files --all 2>/dev/null | awk '{print $1}' | grep -Fxq "$unit" || return 0
        replace_literal_prefix "$conf_file" "# $line" "$line" "Enable autostart: ${unit}"
    }

    uncomment_line_if_file_exists() {
        local conf_file="$1"
        local file="$2"
        local line="$3"
        [ -f "$file" ] || return 0
        replace_literal_prefix "$conf_file" "# $line" "$line" "Enable autostart: $(basename "$file")"
    }

    local configured_terminal=""
    configured_terminal=$(role_field terminal executable 2>/dev/null || true)

    local conf_files=(
        "$HOME/dotfiles/.config/hypr/sources/autostart.conf"
        "$HOME/dotfiles/.config/hypr/sources_example/autostart.conf"
    )

    local conf_file=""
    for conf_file in "${conf_files[@]}"; do
        [ -f "$conf_file" ] || continue

        uncomment_line_if_cmd_exists "$conf_file" "swaync" "exec-once = swaync"
        uncomment_line_if_cmd_exists "$conf_file" "nm-applet" "exec-once = nm-applet --indicator &"
        uncomment_line_if_cmd_exists "$conf_file" "pypr" "exec-once = pypr"
        uncomment_line_if_unit_exists "$conf_file" "app-org.kde.xwaylandvideobridge@autostart.service" "exec-once = systemctl --user start app-org.kde.xwaylandvideobridge@autostart.service &"

        # Lines that include Hyprland variables ($hyprscripts/$mouse) must stay literal.
        uncomment_line_if_file_exists "$conf_file" "$HOME/dotfiles/.config/hypr/scripts/fix-dolphin.sh" "exec-once = \$hyprscripts/fix-dolphin.sh &"
        uncomment_line_if_cmd_exists "$conf_file" "input-remapper-control" "exec-once = input-remapper-control --command autoload --device \$mouse &"

        uncomment_line_if_cmd_exists "$conf_file" "hyprsunset" "exec-once = hyprsunset"
        uncomment_line_if_cmd_exists "$conf_file" "blueman-applet" "exec-once = blueman-applet &"
        uncomment_line_if_cmd_exists "$conf_file" "blueman-tray" "exec-once = blueman-tray &"

        # Workspace 3 terminal examples: enable only when the referenced terminal + config exists.
        if [ "$configured_terminal" = "kitty" ]; then
            uncomment_line_if_file_exists "$conf_file" "$HOME/.config/kitty/my_layout.conf" "exec-once = [workspace 3 silent] kitty --session ~/.config/kitty/my_layout.conf"

            if command -v zellij >/dev/null 2>&1 && [ -f "$HOME/.config/zellij/layouts/sysmon.kdl" ]; then
                uncomment_line_if_cmd_exists "$conf_file" "kitty" "exec-once = [workspace 3 silent] kitty -e zellij -l ~/.config/zellij/layouts/sysmon.kdl"
            fi
        elif [ "$configured_terminal" = "alacritty" ]; then
            if command -v zellij >/dev/null 2>&1 && [ -f "$HOME/.config/zellij/layouts/sysmon.kdl" ]; then
                uncomment_line_if_cmd_exists "$conf_file" "alacritty" "exec-once = [workspace 3 silent] alacritty -e zellij -l ~/.config/zellij/layouts/sysmon.kdl"
            fi
        fi
    done
}

##############################################################
# Pacman Update and Hyprland Packages Installation
##############################################################

update_arch_mirrors() {
    announce_step "Updating Arch mirrors"
    if [[ "$DISTRO" == "manjaro" ]]; then
        print_message "Detected Manjaro. Using pacman-mirrors instead of reflector."
        if ! command -v pacman-mirrors &> /dev/null; then
            print_message "pacman-mirrors not installed. Installing pacman-mirrors..."
            if ! distro_install "pacman-mirrors"; then
                print_error "pacman-mirrors installation failed. Aborting mirror update."
                mirror_updates+=("Arch Mirrors: $CROSS_MARK")
                record_hard_failure "update_arch_mirrors" "Failed to install pacman-mirrors"
                return 1
            fi
        fi
        if execute_command "sudo pacman-mirrors --geoip --timeout 6 && sudo pacman -Syy" "Update Manjaro mirrors"; then
            mirror_updates+=("Arch Mirrors: $CHECK_MARK")
        else
            mirror_updates+=("Arch Mirrors: $CROSS_MARK")
            record_soft_error "update_arch_mirrors" "Manjaro mirror update failed"
        fi
        return 0
    fi
    if ! command -v reflector &> /dev/null; then
        print_message "Reflector not installed. Installing reflector..."
        if ! distro_install "reflector"; then
            print_error "Reflector installation failed. Aborting mirror update."
            record_hard_failure "update_arch_mirrors" "Failed to install reflector"
            return 1
        fi
    fi
    if execute_command "sudo reflector --verbose --protocol https --sort rate --latest 20 --download-timeout 6 --save /etc/pacman.d/mirrorlist" "Update Arch mirrors"; then
        mirror_updates+=("Arch Mirrors: $CHECK_MARK")
    else
        mirror_updates+=("Arch Mirrors: $CROSS_MARK")
        record_soft_error "update_arch_mirrors" "Reflector mirror update failed"
    fi
}

update_pacman() {
    announce_step "Updating pacman packages"
    if execute_command "sudo pacman -Syyu --noconfirm" "Update pacman packages"; then
        package_updates+=("Pacman Packages: $CHECK_MARK")
    else
        package_updates+=("Pacman Packages: $CROSS_MARK")
        record_soft_error "update_pacman" "System package update (pacman -Syyu) failed"
    fi
}

update_yay() {
    announce_step "Updating AUR packages"
    check_yay
    if [ -n "$AUR_HELPER" ] && execute_command "$AUR_HELPER -Sua --noconfirm" "Update AUR packages"; then
        aur_updates+=("AUR Packages: $CHECK_MARK")
    else
        aur_updates+=("AUR Packages: $CROSS_MARK")
        record_soft_error "update_yay" "AUR package update failed"
    fi
}

remove_cache() {
    announce_step "Removing pacman cache"
    check_yay
    if [[ "$DISTRO" == "endeavouros" ]]; then
        execute_command "sudo paccache -r && sudo pacman -Sc --noconfirm" "Remove pacman cache (EndeavourOS)"
        if [ -n "$AUR_HELPER" ]; then
            execute_command "$AUR_HELPER -Sc --noconfirm" "Remove AUR cache (EndeavourOS)"
        fi
    elif [[ "$DISTRO" == "arch" ]] || [[ "$DISTRO" == "cachyos" ]]; then
        execute_command "sudo pacman -Sc --noconfirm" "Remove pacman cache (Arch Linux/CachyOS)"
        if [ -n "$AUR_HELPER" ]; then
            execute_command "$AUR_HELPER -Sc --noconfirm" "Remove AUR cache (Arch Linux/CachyOS)"
        fi
    else
        execute_command "sudo pacman -Sc --noconfirm" "Remove pacman cache"
        if [ -n "$AUR_HELPER" ]; then
            execute_command "$AUR_HELPER -Sc --noconfirm" "Remove AUR cache"
        fi
    fi
    print_message "Pacman cache removed."
}

install_pacman_packages() {
    announce_step "Install pacman packages"
    prepare_package_selections || return 1
    print_message "Updating pacman database..."
    execute_command "sudo pacman -Sy" "Update pacman database" || return 1

    local pkg
    for pkg in "${SELECTED_PACMAN_LIST[@]}"; do
        if [ "$pkg" = timeshift ] && pacman -Qq cachyos-snapper-support &>/dev/null; then
            print_message "Skipping Timeshift because cachyos-snapper-support is installed"
            continue
        fi
        if ! execute_command "sudo pacman -S --needed --noconfirm $pkg" "Installing $pkg"; then
            print_warning "Failed to install $pkg. Please install manually if issues persist."
            record_hard_failure "install_pacman_packages" "Package '$pkg' failed to install via pacman"
        fi
    done
}

##############################################################
# AUR Extras Installation
##############################################################

install_aur_extras() {
    announce_step "Install AUR extras"
    prepare_package_selections || return 1
    [ ${#SELECTED_AUR_LIST[@]} -gt 0 ] || {
        print_message "No AUR packages selected"
        return 0
    }

    check_yay
    [ -n "$AUR_HELPER" ] || {
        record_hard_failure "install_aur_extras" "No AUR helper is available"
        return 1
    }
    local pkg
    for pkg in "${SELECTED_AUR_LIST[@]}"; do
        if ! execute_command "$AUR_HELPER -S --needed --noconfirm $pkg" "Install $pkg"; then
            print_warning "Installation of $pkg failed. Please install manually."
            record_hard_failure "install_aur_extras" "AUR package '$pkg' failed to install via $AUR_HELPER"
        fi
    done
}

##############################################################
# Hyprland Configurations
##############################################################

configure_shell() {
    announce_step "Configuring selected shell"
    load_role_selections || return 1
    local shell_path invoking_user shells_file
    shell_path=$(role_field shell shell_path) || return 1
    invoking_user=${SUDO_USER:-$(id -un)}
    shells_file=${HSS_ETC_SHELLS:-/etc/shells}

    if ! [[ "$invoking_user" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
        print_error "Invalid invoking username '$invoking_user'"
        return 1
    fi
    if ! grep -qxF "$shell_path" "$shells_file"; then
        print_error "Selected shell path '$shell_path' is not listed in $shells_file"
        record_hard_failure "configure_shell" "Shell path '$shell_path' is not approved"
        return 1
    fi
    if execute_command "sudo chsh -s '$shell_path' -- '$invoking_user'" "Set default shell for $invoking_user"; then
        track_config_status "Default Shell ($ROLE_SHELL)" "$CHECK_MARK"
    else
        track_config_status "Default Shell ($ROLE_SHELL)" "$CROSS_MARK"
        record_hard_failure "configure_shell" "Failed to set shell for $invoking_user"
        return 1
    fi

    [ "$ROLE_SHELL" = fish ] || return 0
    if [ "${HSS_TEST_MODE:-0}" = 1 ]; then
        print_message "Test mode: skipping fzf network integration"
        return 0
    fi
    print_message "Configuring fzf integration for Fish"
    if [ ! -d "$HOME/.fzf" ]; then
        execute_command "git clone --depth 1 https://github.com/junegunn/fzf.git '$HOME/.fzf'" "Download fzf repository"
    fi
    if [ -f "$HOME/.fzf/install" ]; then
        execute_command "'$HOME/.fzf/install' --all --no-bash --no-zsh --no-update-rc" "Install fzf integration for Fish"
    else
        print_warning "fzf install script not found at $HOME/.fzf/install"
    fi
}

configure_environment() {
    announce_step "Configuring Environment"
    load_role_selections || return 1
    local editor package
    editor=$(role_field tui_editor editor_bin) || return 1
    package=$ROLE_TUI_EDITOR
    if ! command -v "$editor" >/dev/null 2>&1; then
        print_message "$editor is not installed; installing $package"
        if ! distro_install "$package"; then
            print_error "Failed to install selected editor $package"
            record_hard_failure "configure_environment" "Failed to install selected editor '$package'"
            return 1
        fi
    fi
    if ! execute_command "systemctl --user set-environment EDITOR='$editor' VISUAL='$editor'" "Set selected editor environment"; then
        record_soft_error "configure_environment" "Failed to set EDITOR/VISUAL to $editor"
        return 1
    fi
    print_message "Environment configured with EDITOR=$editor"
}

configure_network_manager() {
    announce_step "Configuring NetworkManager"
    if command -v nm-connection-editor >/dev/null || command -v nm-applet >/dev/null || command -v nmcli >/dev/null; then
        if execute_command "sudo systemctl enable --now NetworkManager" "Enable NetworkManager"; then
            track_config_status "NetworkManager Setup" "$CHECK_MARK"
        else
            track_config_status "NetworkManager Setup" "$CROSS_MARK"
            record_hard_failure "configure_network_manager" "Failed to enable NetworkManager"
        fi
    else
        print_warning "Network Manager tools not found. Skipping NetworkManager setup."
        track_config_status "NetworkManager Setup" "$CIRCLE (Not installed)"
        record_skipped "configure_network_manager" "NetworkManager tools not installed"
    fi
}

configure_wifi() {
    announce_step "Configuring WiFi"
    if ! ip link show wlan0 &>/dev/null; then
        print_warning "No wireless device (wlan0) found"
        track_config_status "WiFi Configuration" "$CIRCLE (No wireless device)"
        record_skipped "configure_wifi" "No wireless device (wlan0) found"
        return 0
    fi
    if execute_command "sudo iw dev wlan0 set power_save off" "Disable WiFi power save"; then
        track_config_status "WiFi Configuration" "$CHECK_MARK"
    else
        track_config_status "WiFi Configuration" "$CROSS_MARK"
        record_soft_error "configure_wifi" "Failed to disable WiFi power save"
    fi
}

configure_bluetooth() {
    announce_step "Configuring Bluetooth"
    for pkg in bluez bluez-utils blueman; do
        if ! pacman -Qq "$pkg" &>/dev/null; then
            print_message "Installing missing package: $pkg"
            if ! distro_install "$pkg"; then
                print_error "Failed to install $pkg. Aborting Bluetooth configuration."
                record_hard_failure "configure_bluetooth" "Failed to install bluetooth package: $pkg"
                return 1
            fi
        fi
    done

    print_message "Enabling Bluetooth..."
    if execute_command "sudo systemctl enable --now bluetooth" "Enable and start Bluetooth"; then
        track_config_status "Bluetooth Setup" "$CHECK_MARK"
    else
        track_config_status "Bluetooth Setup" "$CROSS_MARK"
        record_hard_failure "configure_bluetooth" "Failed to enable bluetooth service"
    fi
}

configure_gnome_keyring() {
    announce_step "Configuring gnome-keyring"

    if [ "$XDG_CURRENT_DESKTOP" = "KDE" ] || [ "$XDG_CURRENT_DESKTOP" = "plasma" ] || pgrep -x "plasmashell" > /dev/null; then
        print_message "KDE environment detected. Skipping gnome-keyring configuration."
        track_config_status "Gnome-keyring Setup" "$CIRCLE (Not needed in KDE)"
        record_skipped "configure_gnome_keyring" "KDE environment detected, gnome-keyring not needed"
        return 0
    fi

    if ! command -v gnome-keyring-daemon >/dev/null 2>&1; then
        print_warning "gnome-keyring is not installed. Installing..."
        distro_install "gnome-keyring"
    else
        print_message "gnome-keyring is already installed."
    fi

    local pam_file="/etc/pam.d/login"
    # Determine include stack and candidates to verify
    local -a candidates=("$pam_file")
    if grep -Eq '^[[:space:]]*(auth|session|account|password)[[:space:]]+include[[:space:]]+system-local-login' "$pam_file" \
        && [ -f "/etc/pam.d/system-local-login" ]; then
        candidates+=("/etc/pam.d/system-local-login")
    fi
    if grep -Eq '^[[:space:]]*(auth|session|account|password)[[:space:]]+include[[:space:]]+system-login' "$pam_file" \
        && [ -f "/etc/pam.d/system-login" ]; then
        candidates+=("/etc/pam.d/system-login")
    fi
    # Safer write target: prefer system-local-login if present, else login
    local target_file="$pam_file"
    if printf '%s\n' "${candidates[@]}" | grep -qx "/etc/pam.d/system-local-login"; then
        target_file="/etc/pam.d/system-local-login"
    fi
    local has_auth="false"
    local has_session="false"
    for f in "${candidates[@]}"; do
        if [ "$has_auth" != "true" ] && grep -Eq '^[[:space:]]*auth[[:space:]]+optional[[:space:]]+pam_gnome_keyring\.so([[:space:]].*)?$' "$f"; then
            has_auth="true"
        fi
        if [ "$has_session" != "true" ] && grep -Eq '^[[:space:]]*session[[:space:]]+optional[[:space:]]+pam_gnome_keyring\.so.*auto_start' "$f"; then
            has_session="true"
        fi
    done

    if [ "$has_auth" != "true" ] || [ "$has_session" != "true" ]; then
        print_message "Adding PAM configurations for gnome-keyring to $target_file..."
        if [ "$has_auth" != "true" ]; then
            append_text_atomic "$target_file" "Add pam_gnome_keyring.so auth" $'auth optional pam_gnome_keyring.so\n'
        fi
        if [ "$has_session" != "true" ]; then
            append_text_atomic "$target_file" "Add pam_gnome_keyring.so session" $'session optional pam_gnome_keyring.so auto_start\n'
        fi
    else
        print_message "PAM configuration for gnome-keyring already exists (checked: ${candidates[*]})."
    fi

    # Verify PAM configuration is correctly set
    local pam_ok="false"
    # Verify PAM configuration is correctly set (in login or included)
    local verify_auth="false"
    local verify_session="false"
    for f in "${candidates[@]}"; do
        if [ "$verify_auth" != "true" ] && grep -Eq '^[[:space:]]*auth[[:space:]]+optional[[:space:]]+pam_gnome_keyring\.so([[:space:]].*)?$' "$f"; then
            verify_auth="true"
        fi
        if [ "$verify_session" != "true" ] && grep -Eq '^[[:space:]]*session[[:space:]]+optional[[:space:]]+pam_gnome_keyring\.so.*auto_start' "$f"; then
            verify_session="true"
        fi
    done
    if [ "$verify_auth" = "true" ] && [ "$verify_session" = "true" ]; then
        print_message "Verified PAM configuration for gnome-keyring in: ${candidates[*]}"
        pam_ok="true"
    else
        print_warning "PAM configuration for gnome-keyring may be missing or malformed (checked: ${candidates[*]}).\nPlease ensure these lines exist (uncommented) in /etc/pam.d/system-local-login (preferred) or /etc/pam.d/login:\n  auth    optional    pam_gnome_keyring.so\n  session optional    pam_gnome_keyring.so auto_start"
        pam_ok="false"
    fi

    print_message "Starting gnome-keyring-daemon..."
    if pgrep -x gnome-keyring-daemon >/dev/null; then
        print_message "gnome-keyring-daemon already running."
    else
        execute_command "/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh &>/dev/null &" "Start gnome-keyring-daemon"
    fi

    if [ "$pam_ok" = "true" ]; then
        track_config_status "Gnome-keyring Setup" "$CHECK_MARK"
    else
        track_config_status "Gnome-keyring Setup" "$CIRCLE (Manual verification needed)"
        record_warning "configure_gnome_keyring" "PAM configuration for gnome-keyring may need manual verification"
    fi
}

configure_filepicker() {
    announce_step "Configuring filepicker"

    if ! check_hyprland; then
        print_message "Not running in Hyprland. Skipping filepicker configuration."
        track_config_status "Filepicker Setup" "$CIRCLE (Not in Hyprland)"
        record_skipped "configure_filepicker" "Not running in Hyprland session"
        return 0
    fi
    local conf_dir="${HOME}/.config/xdg-desktop-portal"
    local conf_file="${conf_dir}/hyprland-portals.conf"
    local desired_content="[preferred]
default = hyprland;gtk
org.freedesktop.impl.portal.FileChooser = kde
"
    if [ -f "$conf_file" ]; then
        if grep -q "default = hyprland;gtk" "$conf_file" && grep -q "org.freedesktop.impl.portal.FileChooser = kde" "$conf_file"; then
            print_message "Filepicker configuration already set."
        else
            print_message "Updating filepicker configuration..."
            write_text_atomic "$conf_file" "Update filepicker configuration" "$desired_content"
        fi
    else
        print_message "Creating filepicker configuration..."
        write_text_atomic "$conf_file" "Create filepicker configuration" "$desired_content"
    fi

    if [ ! -L "/etc/xdg/menus/applications.menu" ]; then
        execute_command "sudo ln -s /etc/xdg/menus/plasma-applications.menu /etc/xdg/menus/applications.menu" "Symlink applications.menu to plasma-applications.menu"
    else
        print_message "Symlink for applications.menu already exists."
    fi

    track_config_status "Filepicker Setup" "$CHECK_MARK"
}

configure_pacman_color() {
    announce_step "Configuring Pacman Color"
    local pacman_conf
    pacman_conf="$(setup_etc_root)/pacman.conf"
    if is_dry_run; then
        write_file_atomic "$pacman_conf" /dev/null "enable pacman Color and ILoveCandy"
        return 0
    fi
    local tmp_conf
    make_tmp tmp_conf pacman.XXXXXX || return 1
    local color_found=false
    local candy_found=false
    local color_line_num=0
    local line_num=0

    # Read through the file and process
    while IFS= read -r line; do
        ((line_num++))
        # Check for Color (commented or not)
        if [[ "$line" =~ ^#?Color$ ]]; then
            color_found=true
            color_line_num=$line_num
            # Uncomment if commented
            echo "Color" >> "$tmp_conf"
        # Check for ILoveCandy (commented or not)
        elif [[ "$line" =~ ^#?ILoveCandy$ ]]; then
            candy_found=true
            echo "ILoveCandy" >> "$tmp_conf"
        else
            echo "$line" >> "$tmp_conf"
        fi
    done < "$pacman_conf"

    # If Color was not found, add it after [options]
    if ! $color_found; then
        local rewritten
        make_tmp rewritten pacman-rewrite.XXXXXX || return 1
        awk '/^\[options\]/{print;print "Color";next}1' "$tmp_conf" > "$rewritten" && cp "$rewritten" "$tmp_conf"
        color_found=true
        color_line_num=$(awk '/^Color$/{print NR; exit}' "$tmp_conf")
    fi

    # If ILoveCandy is not found, add it just below Color
    if ! $candy_found && $color_found; then
        make_tmp rewritten pacman-rewrite.XXXXXX || return 1
        awk -v cline="$color_line_num" '{print; if(NR==cline) print "ILoveCandy"}' "$tmp_conf" > "$rewritten" && cp "$rewritten" "$tmp_conf"
    fi

    # Only replace the original if changes were made
    if ! cmp -s "$pacman_conf" "$tmp_conf"; then
        write_file_atomic "$pacman_conf" "$tmp_conf" "enable pacman Color and ILoveCandy"
        print_message "Updated $pacman_conf: ensured 'Color' is uncommented and 'ILoveCandy' is present."
    else
        print_message "$pacman_conf already has 'Color' and 'ILoveCandy' set correctly."
    fi
}

configure_timeshift() {
    announce_step "Setting up Timeshift"

    # Skip Timeshift setup if CachyOS Snapper integration is present
    if pacman -Qq cachyos-snapper-support &>/dev/null; then
        print_message "Detected 'cachyos-snapper-support'. Skipping Timeshift configuration."
        track_config_status "Timeshift Setup" "$CIRCLE (Using CachyOS Snapper)"
        record_skipped "configure_timeshift" "CachyOS Snapper support detected, Timeshift not needed"
        return 0
    fi

    # Ensure Timeshift is installed
    if ! command -v timeshift &>/dev/null; then
        if ! distro_install "timeshift"; then
            track_config_status "Timeshift Setup" "$CROSS_MARK"
            record_hard_failure "configure_timeshift" "Failed to install Timeshift"
            return 1
        fi
    fi

    # Enable the cronie service (required for scheduling snapshots)
    if ! execute_command "sudo systemctl enable --now cronie.service" "Enable Cronie for Timeshift scheduling"; then
        track_config_status "Timeshift Setup" "$CROSS_MARK"
        record_hard_failure "configure_timeshift" "Failed to enable cronie service for Timeshift scheduling"
        return 1
    fi

    # Create an initial snapshot without a .snapshot suffix
    if execute_command "sudo timeshift --create --comments 'Automated snapshot created by Hyprland-Simple-Setup script' --tags D" "Create initial Timeshift snapshot"; then
        track_config_status "Timeshift Setup" "$CHECK_MARK"
    else
        track_config_status "Timeshift Setup" "$CROSS_MARK"
        record_soft_error "configure_timeshift" "Failed to create initial Timeshift snapshot"
    fi
}

configure_grub_btrfsd() {
    announce_step "Configuring grub-btrfsd"

    # Check if  Bootloader is GRUB
    if ! check_bootloader "grub"; then
        print_warning "Bootloader is not GRUB. Skipping grub-btrfsd configuration."
        track_config_status "grub-btrfsd Configuration" "$CIRCLE (Not GRUB bootloader)"
        record_skipped "configure_grub_btrfsd" "Bootloader is not GRUB"
        return 0
    fi

    # Check if the root filesystem is BTRFS
    if ! mount | grep "on / type btrfs" > /dev/null; then
        print_warning "Root filesystem is not BTRFS. Skipping grub-btrfsd configuration."
        track_config_status "grub-btrfsd Configuration" "$CIRCLE (Not BTRFS filesystem)"
        record_skipped "configure_grub_btrfsd" "Root filesystem is not BTRFS"
        return 0
    fi

    # Create systemd override directory if it doesn't exist
    if ! execute_command "sudo mkdir -p /etc/systemd/system/grub-btrfsd.service.d" "Create override directory for grub-btrfsd"; then
        track_config_status "grub-btrfsd Configuration" "$CROSS_MARK"
        return 1
    fi

    local etc_root
    etc_root=$(setup_etc_root)
    local service_file="$etc_root/systemd/system/grub-btrfsd.service"
    local override_file="$etc_root/systemd/system/grub-btrfsd.service.d/override.conf"
    local exec_start
    exec_start=$(grep '^ExecStart=' "$service_file" 2>/dev/null | sed 's/\.snapshot//g; s/$/ -t/' | head -n1)
    if write_text_atomic "$override_file" "configure grub-btrfsd override" "[Service]
ExecStart=
$exec_start
"; then
        print_message "grub-btrfsd override file created."
    else
        print_error "Failed to create grub-btrfsd override file."
        track_config_status "grub-btrfsd Configuration" "$CROSS_MARK"
        return 1
    fi

    # Reload systemd daemon and enable the service
    if execute_command "sudo systemctl daemon-reload && sudo systemctl enable --now grub-btrfsd" "Enable grub-btrfsd service"; then
        track_config_status "Enable grub-btrfsd service" "$CHECK_MARK"
    else
        track_config_status "grub-btrfsd Configuration" "$CROSS_MARK"
    fi
}

configure_monitor() {
    announce_step "Configuring monitor"

    # Ask user or auto-skip/setup in non-interactive mode
    if [ "$NON_INTERACTIVE" = "true" ]; then
        case "${MONITOR_SETUP_ENABLED:-false}" in
            true|1|yes|y|Y)
                print_message "Non-interactive: proceeding with monitor setup"
                ;;
            *)
                print_message "Non-interactive: MONITOR_SETUP_ENABLED is not set; falling back to auto-detection"
                local mc
                for mc in \
                    "$HOME/.config/hypr/sources_specific/monitors.conf" \
                    "$HOME/dotfiles/.config/hypr/sources_specific/monitors.conf"; do
                    [ -f "$mc" ] && ensure_monitors_conf "$mc"
                done
                local wc
                for wc in \
                    "$HOME/.config/hypr/sources_specific/change_wallpaper.conf" \
                    "$HOME/dotfiles/.config/hypr/sources_specific/change_wallpaper.conf"; do
                    [ -f "$wc" ] && ensure_wallpaper_monitors "$wc"
                done
                track_config_status "Monitor Setup" "$CIRCLE (Auto-detected)"
                return 0
                ;;
        esac
    else
        if ! prompt_yes_no "Would you like to configure your monitor settings?"; then
            print_message "Monitor setup skipped by user."
            track_config_status "Monitor Setup" "$CIRCLE (Skipped by user)"
            return 0
        fi
    fi

    # In non-interactive/TUI mode, prefer explicit MONITOR_CONFIG if provided.
    # This works even when Hyprland is not currently running in this shell.
    if [ "$NON_INTERACTIVE" = "true" ] && [ -n "${MONITOR_CONFIG:-}" ]; then
        if apply_monitor_config_from_env; then
            track_config_status "Monitor Setup" "$CHECK_MARK (Applied MONITOR_CONFIG)"
            return 0
        fi
    fi

    if check_hyprland; then
        local monitor_output
        monitor_output=$(hyprctl monitors 2>&1)
        print_message "Hyprland monitor configuration:"
        echo "$monitor_output"
        local monitor_count
        monitor_count=$(echo "$monitor_output" | grep -E -c "^[[:space:]]*Monitor")
        print_message "Detected $monitor_count monitor(s) on Hyprland."
        if [ "$monitor_count" -eq 0 ]; then
            print_warning "No monitors detected via hyprctl monitors."
            return
        fi

        # Get monitor names
        local monitor_names=()
        while IFS= read -r line; do
            monitor_names+=("$(echo "$line" | awk '{print $2}')")
        done < <(echo "$monitor_output" | grep -E "^[[:space:]]*Monitor")

        # Initialize variables for monitor configuration
        local primary_monitor=""
        local primary_width=""
        local configured_monitors=()
        # local monitors_conf_file="${HOME}/Dokumente/GitHub/$SETUP_DIR/dotfiles/.config/hypr/sources_example/monitors.conf"
        # Hyprland sources this file directly (see dotfiles/.config/hypr/hyprland.conf)
        local monitors_conf_file="${HOME}/.config/hypr/sources_specific/monitors.conf"
        # local wallpaper_conf="${HOME}/Dokumente/GitHub/$SETUP_DIR/dotfiles/.config/hypr/sources_example/change_wallpaper.conf"
        local wallpaper_conf="${HOME}/.config/hypr/sources_specific/change_wallpaper.conf"

        if [ ! -f "$monitors_conf_file" ]; then
            write_text_atomic "$monitors_conf_file" "Create monitor configuration" '# Check monitor names (e.g. DP-1, HDMI-A-1) with: `hyprctl monitors`
# Example single monitor configuration:
# monitor=DP-1,2560x1440@144,0x0,1
# workspace=1,monitor:DP-1,default:true
'
        fi

        # Function to get available modes for a monitor
        get_monitor_modes() {
            local monitor_name="$1"
            local modes_str
            modes_str=$(echo "$monitor_output" | grep -A 100 "Monitor $monitor_name" | grep "availableModes:" | head -n 1)
            echo "${modes_str#*availableModes: }"
        }

        # Function to calculate aspect ratio
        calculate_aspect_ratio() {
            local width="$1"
            local height="$2"
            gcd() {
                local a=$1
                local b=$2
                while [ "$b" -ne 0 ]; do
                    local temp=$b
                    b=$(( a % b ))
                    a=$temp
                done
                echo "$a"
            }
            local divisor
            divisor=$(gcd "$width" "$height")
            echo "$((width/divisor)):$((height/divisor))"
        }

        # Function to configure a single monitor
        configure_single_monitor() {
            local monitor_name="$1"
            local chosen_resolution=""
            local scale=""

            if [ "$NON_INTERACTIVE" = "true" ] && [ -n "$MONITOR_CONFIG" ]; then
                # Expect MONITOR_CONFIG entries like: name:1920x1080@60:1.0;name2:2560x1440@144:1.25
                local entry
                IFS=';' read -ra entries <<< "$MONITOR_CONFIG"
                for entry in "${entries[@]}"; do
                    local nm cfg sc
                    nm="${entry%%:*}"
                    cfg="${entry#*:}"
                    sc="${cfg##*:}"
                    cfg="${cfg%:*}"
                    if [ "$nm" = "$monitor_name" ]; then
                        chosen_resolution="$cfg"
                        scale="$sc"
                        break
                    fi
                done
            fi

            if [ -z "$chosen_resolution" ] || [ -z "$scale" ]; then
                local modes
                modes=$(get_monitor_modes "$monitor_name")

                declare -A ratio_modes
                for mode in $modes; do
                    if [[ "$mode" != *x* ]]; then
                        continue
                    fi
                    local res=${mode%%@*}
                    local width=${res%%x*}
                    local height=${res#*x}
                    if ! [[ "$width" =~ ^[0-9]+$ && "$height" =~ ^[0-9]+$ ]]; then
                        continue
                    fi
                    local ratio
                    ratio=$(calculate_aspect_ratio "$width" "$height")
                    if [[ ! " ${ratio_modes[$ratio]} " =~ ${mode} ]]; then
                        ratio_modes["$ratio"]+="$mode "
                    fi
                done

                print_message "Available ratios for $monitor_name:"
                local ratios=("${!ratio_modes[@]}")
                PS3="Select ratio number: "
                select selected_ratio in "${ratios[@]}"; do
                    if [ -n "$selected_ratio" ]; then
                        break
                    else
                        print_message "Invalid selection. Try again."
                    fi
                done

                read -ra resolutions <<< "${ratio_modes[$selected_ratio]}"
                print_message "Choose a resolution for ratio $selected_ratio:"
                PS3="Select resolution number: "
                select chosen_resolution in "${resolutions[@]}"; do
                    if [ -n "$chosen_resolution" ]; then
                        break
                    else
                        print_message "Invalid selection. Try again."
                    fi
                done

                read -rp "Enter scale for monitor $monitor_name (1.0 - 2.0): " scale
            fi

            # Calculate offset
            local offset
            if [ -z "$primary_monitor" ]; then
                primary_monitor="$monitor_name"
                primary_width="${chosen_resolution%%x*}"
                offset="0x0"
            else
                if [ "$monitor_name" = "$primary_monitor" ]; then
                    offset="0x0"
                else
                    offset="${primary_width}x0"
                fi
            fi

            replace_config_line "$monitors_conf_file" "^monitor=${monitor_name}," "monitor=${monitor_name},${chosen_resolution},${offset},${scale}" "Configure monitor $monitor_name"

            configured_monitors+=("$monitor_name")
        }

        # Configure each monitor
        for monitor_name in "${monitor_names[@]}"; do
            configure_single_monitor "$monitor_name"
            if [ "${#monitor_names[@]}" -gt 1 ] && ! prompt_yes_no "Configure another monitor?"; then
                break
            fi
        done

        # Update workspace assignments
        local primary="${configured_monitors[0]}"
        local secondary="${configured_monitors[1]:-$primary}"
        
        # Update workspace assignments in monitors.conf
        local workspace_tmp
        make_tmp workspace_tmp monitor-workspaces.XXXXXX || return 1
        awk -F, -v p="$primary" -v s="$secondary" 'BEGIN { OFS="," }
            /^workspace=/ {
                split($1, arr, "");
                ws=arr[2];
                if (ws % 2 == 1) { $2="monitor:" s } else { $2="monitor:" p }
                print
            }
            !/^workspace=/ { print }
        ' "$monitors_conf_file" > "$workspace_tmp" && write_file_atomic "$monitors_conf_file" "$workspace_tmp" "Update monitor workspace assignments"

        # Update wallpaper configuration (runtime + stow source if present)
        local monitors_str=""
        for m in "${configured_monitors[@]}"; do
            monitors_str+="\"$m\" "
        done

        local wallpaper_confs=(
            "$HOME/.config/hypr/sources_specific/change_wallpaper.conf"
            "$HOME/dotfiles/.config/hypr/sources_specific/change_wallpaper.conf"
        )
        local wc
        for wc in "${wallpaper_confs[@]}"; do
            if [ -f "$wc" ]; then
                replace_config_line "$wc" '^MONITORS=' "MONITORS=($monitors_str)" "Update wallpaper monitor list"
                print_message "Updated MONITORS in $(basename "$wc"): MONITORS=($monitors_str)"
            else
                print_warning "Wallpaper configuration file not found: $wc"
            fi
        done

        sed_file_atomic "$monitors_conf_file" "Remove monitor placeholders" '/MONITOR_[0-9]/d'
        for wc in "$HOME/.config/hypr/sources_specific/change_wallpaper.conf" "$HOME/dotfiles/.config/hypr/sources_specific/change_wallpaper.conf"; do
            [ -f "$wc" ] && sed_file_atomic "$wc" "Remove wallpaper monitor placeholders" '/MONITOR_[0-9]/d'
        done

        if [ -f "$HOME/dotfiles/.config/hypr/sources_specific/monitors.conf" ]; then
            copy_file_atomic "$HOME/dotfiles/.config/hypr/sources_specific/monitors.conf" "$monitors_conf_file" "Synchronize monitor source configuration"
        fi

    elif command -v kscreen-doctor &>/dev/null; then
        local monitor_output
        monitor_output=$(kscreen-doctor -o 2>&1)
        print_message "KDE Plasma monitor configuration:"
        echo "$monitor_output"
        local monitor_count
        monitor_count=$(echo "$monitor_output" | grep -E -c "^Monitor")
        print_message "Detected $monitor_count monitor(s) on KDE Plasma."
        if [ "$monitor_count" -eq 0 ]; then
            print_warning "No monitors detected via kscreen-doctor."
            return
        fi
    else
        print_warning "No supported monitor configuration tool found (hyprctl or kscreen-doctor)."
    fi
}

configure_sddm_theme() {
    announce_step "Configuring SDDM Theme"

    # Check if SDDM is the current display manager
    if ! systemctl is-enabled sddm &>/dev/null; then
        print_message "SDDM is not enabled as display manager. Skipping theme configuration."
        track_config_status "SDDM Theme Setup" "$CIRCLE (Not enabled)"
        record_skipped "configure_sddm_theme" "SDDM is not enabled as display manager"
        return 0
    fi

    # Create Downloads directory if it doesn't exist
    local downloads_dir="$HOME/Downloads"
    if [ ! -d "$downloads_dir" ]; then
        if ! execute_command "mkdir -p '$downloads_dir'"; then
            print_error "Failed to create Downloads directory."
            track_config_status "SDDM Theme Setup" "$CROSS_MARK"
            return 1
        fi
    fi

    # Check if theme already exists in Downloads
    if [ -d "$downloads_dir/eucalyptus-drop" ]; then
        print_message "SDDM theme already exists in Downloads directory, skipping clone."
    else
        # Clone the theme repository
        print_message "Cloning SDDM Eucalyptus Drop theme..."
        if ! execute_command "git clone https://gitlab.com/Matt.Jolly/sddm-eucalyptus-drop.git '$downloads_dir/eucalyptus-drop'"; then
            print_error "Failed to clone SDDM theme repository."
            track_config_status "SDDM Theme Setup" "$CROSS_MARK"
            return 1
        fi
    fi

    # Check if theme already exists in SDDM themes directory
    if [ -d "/usr/share/sddm/themes/eucalyptus-drop" ]; then
        print_message "SDDM theme already exists in themes directory, skipping copy."
    else
        # Copy the theme to SDDM themes directory
        print_message "Installing SDDM theme..."
        if ! execute_command "sudo cp -r '$downloads_dir/eucalyptus-drop' /usr/share/sddm/themes/"; then
            print_error "Failed to copy SDDM theme to themes directory."
            track_config_status "SDDM Theme Setup" "$CROSS_MARK"
            return 1
        fi
    fi

    # Configure SDDM to use the theme
    local sddm_conf_dir="/etc/sddm.conf.d"
    local sddm_conf="$sddm_conf_dir/sddm.conf"

    # Create sddm.conf.d directory if it doesn't exist
    if ! execute_command "sudo mkdir -p '$sddm_conf_dir'"; then
        print_error "Failed to create SDDM configuration directory."
        track_config_status "SDDM Theme Setup" "$CROSS_MARK"
        return 1
    fi

    # Create or update sddm.conf with the theme configuration
    if ! write_text_atomic "$sddm_conf" "Configure SDDM theme" $'[Theme]\nCurrent=eucalyptus-drop\n'; then
        print_error "Failed to create/update SDDM configuration."
        track_config_status "SDDM Theme Setup" "$CROSS_MARK"
        return 1
    fi

    # Clean up downloaded theme
    if ! execute_command "rm -rf '$downloads_dir/eucalyptus-drop'"; then
        print_warning "Failed to clean up downloaded theme from Downloads directory."
    fi

    print_message "SDDM theme configuration completed successfully."
    track_config_status "SDDM Theme Setup" "$CHECK_MARK"
}

# Enable and start SDDM as the final step of installation
enable_sddm_last() {
    announce_step "Enabling SDDM display manager"
    if command -v systemctl >/dev/null 2>&1; then
        if execute_command "sudo systemctl enable sddm" "Enable SDDM"; then
            print_message "SDDM has been enabled."
        else
            print_warning "Failed to enable SDDM. You can try manually: sudo systemctl enable sddm"
            record_soft_error "enable_sddm_last" "Failed to enable SDDM"
        fi
    else
        print_warning "systemctl not available; skipping SDDM enable."
        record_skipped "enable_sddm_last" "systemctl not available"
    fi
}

# Verify configs do not pre-create workspace 11
verify_workspace_config() {
    print_message "Verifying workspace configuration"
    local issues=0
    local files=(
        "$HOME/.config/hypr/sources_specific/monitors.conf"
        "$HOME/.config/hypr/sources/windows_and_workspaces.conf"
        "$HOME/dotfiles/.config/hypr/sources_specific/monitors.conf"
        "$HOME/dotfiles/.config/hypr/sources/windows_and_workspaces.conf"
        "$HOME/.dotfiles/.config/hypr/sources_specific/monitors.conf"
        "$HOME/.dotfiles/.config/hypr/sources/windows_and_workspaces.conf"
        "$HOME/.config/waybar/config"
        "$HOME/.config/waybar/config.jsonc"
        "$HOME/.dotfiles/.config/waybar/config"
        "$HOME/.dotfiles/.config/waybar/config.jsonc"
    )
    for f in "${files[@]}"; do
        [ -f "$f" ] || continue
        if grep -Eiq '\bworkspace[ =,]+1[1-9]|\bworkspace\s+11\b|\bworkspace=11\b' "$f"; then
            print_warning "Found explicit workspace 11 mapping in: $f"
            issues=$((issues+1))
        fi
        if [[ "$f" == *"waybar/"* ]] || [[ "$f" == *"waybar"* ]]; then
            if grep -qi 'persistent_workspaces' "$f" && grep -Eiq '"11"|: 11' "$f"; then
                print_warning "Waybar persistent_workspaces includes 11 in: $f"
                issues=$((issues+1))
            fi
        fi
    done

    if [ $issues -eq 0 ]; then
        print_message "No configuration found that pre-creates workspace 11."
    else
        print_warning "Please review the above files and remove workspace 11 entries."
        record_warning "verify_workspace_config" "Found $issues file(s) with explicit workspace 11 mappings"
    fi

    if command -v hyprctl >/dev/null 2>&1; then
        if hyprctl workspaces -j 2>/dev/null | grep -q '"id": 11'; then
            print_warning "Workspace 11 currently exists (active or with windows). Switch away and close apps to hide it."
        else
            print_message "Workspace 11 is not present in the current Hyprland state."
        fi
    fi
}
##############################################################
# Main Execution Flow
##############################################################

bootstrap_jq() {
    if command -v jq >/dev/null 2>&1; then
        return 0
    fi
    print_message "jq not found. Installing..."
    if ! distro_install jq; then
        print_error "Failed to install jq, which is required to load package roles"
        record_hard_failure "main" "Failed to install jq"
        return 1
    fi
}

main() {
    print_message "Starting Hyprland Setup..."

    if is_dry_run; then
        print_message "Dry-run: skipping sudo password capture"
    else
        setup_sudo_password
    fi

    check_disk_space
    check_distro
    bootstrap_jq || return 1
    load_role_selections || return 1
    prepare_package_selections || return 1
    if [ "$ROLE_SHELL" = fish ]; then
        get_fish_language_choice
    fi
    check_desktop_environment

    if ! command -v xdg-user-dirs-update &>/dev/null; then
        print_message "xdg-user-dirs not found. Installing..."
        if ! distro_install "xdg-user-dirs"; then
            print_error "Failed to install xdg-user-dirs"
            record_hard_failure "main" "Failed to install xdg-user-dirs"
            return 1
        fi
    fi

    if execute_command "xdg-user-dirs-update" "Creating User Environment"; then
        print_message "User Environment created"
    else
        print_warning "User Environment could not be created!"
        record_warning "main" "xdg-user-dirs-update failed"
    fi
    
    check_dependencies
    check_environment
    if ! is_dry_run; then
        hss_start_sudo_keepalive
    fi
    check_user_input
    
    if ! validate_wallpaper_dir; then
        if [ "$NON_INTERACTIVE" = "true" ]; then
            case "${AUTO_CONTINUE_ON_WARNINGS:-false}" in
                true|1|yes|y|Y)
                    print_warning "Continuing despite wallpaper validation failure (auto)"
                    record_warning "main" "Wallpaper directory validation failed (continued anyway)"
                    ;;
                *) print_error "Setup aborted due to wallpaper validation failure (non-interactive)"; exit 1 ;;
            esac
        else
            read -rp "Continue anyway? (y/N): " choice
            if [[ ! $choice =~ ^[Yy]$ ]]; then
                print_error "Setup aborted by user"
                exit 1
            fi
            record_warning "main" "Wallpaper directory validation failed (user chose to continue)"
        fi
    fi
    
    # Create backup of entire .config directory
    local backup_dir
    backup_dir="${HOME}/.config.bak.$(date +%Y%m%d_%H%M%S)"
    if [ -d "${HOME}/.config" ]; then
        print_message "Creating backup of .config directory..."
        if execute_command "cp -r '${HOME}/.config' '$backup_dir'" "Backup .config directory"; then
            print_message "Backup created successfully at: $backup_dir"
        else
            print_error "Failed to create backup of .config directory"
            record_warning "main" "Backup of .config directory failed"
            if [ "$NON_INTERACTIVE" = "true" ]; then
                case "${AUTO_CONTINUE_ON_WARNINGS:-false}" in
                    true|1|yes|y|Y) print_warning "Continuing despite backup failure (auto)" ;;
                    *) print_error "Setup aborted due to backup failure (non-interactive)"; exit 1 ;;
                esac
            else
                read -rp "Continue anyway? (y/N): " choice
                if [[ ! $choice =~ ^[Yy]$ ]]; then
                    print_error "Setup aborted by user"
                    exit 1
                fi
            fi
        fi
    else
        print_warning ".config directory not found, skipping backup"
        record_skipped "main" ".config directory not found, backup skipped"
    fi

    update_arch_mirrors
    update_pacman

    update_yay
    remove_cache
    install_pacman_packages
    install_aur_extras
    verify_installed_packages
    update_configs
    if [ "$ROLE_SHELL" = fish ]; then
        set_fish_language_config
    fi
    configure_roles
    configure_hypr_autostart_optional_extras
    configure_shell
    configure_environment
    configure_network_manager



    configure_wifi
    configure_bluetooth
    configure_gnome_keyring
    configure_filepicker
    configure_pacman_color
    configure_timeshift
    configure_grub_btrfsd
    configure_monitor
    configure_sddm_theme
    print_dry_run_summary
    print_status_summary
    verify_workspace_config
    print_final_recommendation_summary

    # As the very last step, enable and start SDDM (may end current session)
    enable_sddm_last

    announce_step "Hyprland setup completed successfully!"
}

run_role_test_scenario() {
    [ "${HSS_TEST_MODE:-0}" = 1 ] || {
        print_error "--test-scenario is available only when HSS_TEST_MODE=1"
        return 2
    }
    NON_INTERACTIVE=true
    DISTRO=${DISTRO:-arch}
    hss_begin_run "--test-scenario roles" || return $?
    bootstrap_jq || return 1
    load_role_selections || return 1
    prepare_package_selections || return 1
    configure_roles || return 1
    configure_shell || return 1
    configure_environment || return 1
    verify_installed_packages || return 1
    if is_dry_run; then
        print_dry_run_summary
    fi
}

run_reliability_test_scenario() {
    [ "${HSS_TEST_MODE:-0}" = 1 ] || return 2
    NON_INTERACTIVE=${NON_INTERACTIVE:-true}
    local action=${HSS_RELIABILITY_ACTION:-}
    case "$action" in
        lock-hold)
            hss_begin_run "reliability lock-hold" || return $?
            printf 'holder pid=%s run=%s\n' "$$" "$HSS_RUN_ID"
            sleep "${HSS_HOLD_SECONDS:-5}"
            ;;
        temp-wait)
            hss_begin_run "reliability temp-wait" || return $?
            local temp_path
            make_tmp temp_path signal.XXXXXX || return 1
            printf '%s\n' "$temp_path"
            sleep "${HSS_HOLD_SECONDS:-30}"
            ;;
        keepalive)
            hss_begin_run "reliability keepalive" || return $?
            hss_start_sudo_keepalive
            printf '%s\n' "$HSS_KEEPALIVE_PID"
            sleep "${HSS_HOLD_SECONDS:-1}"
            ;;
        atomic)
            hss_begin_run "reliability atomic" || return $?
            write_file_atomic "${HSS_DEST:?HSS_DEST is required}" "${HSS_SOURCE:?HSS_SOURCE is required}" "guarded atomic exercise"
            ;;
        dry-record)
            hss_begin_run "reliability dry-record" || return $?
            DRY_RUN=true
            write_file_atomic "${HSS_DEST:?HSS_DEST is required}" /dev/null "guarded dry-run exercise"
            print_dry_run_summary
            ;;
        rollback)
            hss_begin_run "reliability rollback" || return $?
            hss_rollback "${HSS_ROLLBACK_RUN_ID:?HSS_ROLLBACK_RUN_ID is required}"
            ;;
        *)
            print_error "Unknown reliability action '$action'"
            return 2
            ;;
    esac
}

if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
    return 0
fi

DRY_RUN=${DRY_RUN:-false}
VERBOSE=false
CONFIGURE_MONITOR_ONLY=false
CONFIGURE_SDDM_ONLY=false
TEST_SCENARIO=""
ROLLBACK_RUN_ID=""
LIST_RUNS=false
printf -v ORIGINAL_ARGS '%q ' "$@"
ORIGINAL_ARGS=${ORIGINAL_ARGS% }

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true ;;
        --verbose) VERBOSE=true ;;
        --configure-monitor) CONFIGURE_MONITOR_ONLY=true ;;
        --configure-sddm) CONFIGURE_SDDM_ONLY=true ;;
        --init-dotfiles-git) INIT_DOTFILES_GIT_REPO=true ;;
        --list-runs) LIST_RUNS=true ;;
        --rollback)
            [ "$#" -ge 2 ] || { print_error "--rollback requires a run ID"; exit 2; }
            ROLLBACK_RUN_ID=$2
            shift
            ;;
        --test-scenario)
            [ "$#" -ge 2 ] || { print_error "--test-scenario requires a name"; exit 2; }
            TEST_SCENARIO=$2
            shift
            ;;
        *) print_warning "Unknown parameter passed: $1" ;;
    esac
    shift
done

if [ "$LIST_RUNS" = true ]; then
    hss_list_runs
    exit $?
fi

if [ -n "$ROLLBACK_RUN_ID" ]; then
    hss_begin_run "$ORIGINAL_ARGS" || exit $?
    hss_rollback "$ROLLBACK_RUN_ID"
    exit $?
fi

if [ -n "$TEST_SCENARIO" ]; then
    case "$TEST_SCENARIO" in
        roles) run_role_test_scenario ;;
        reliability) run_reliability_test_scenario ;;
        *) print_error "Unknown test scenario '$TEST_SCENARIO'"; exit 2 ;;
    esac
    exit $?
fi

hss_begin_run "$ORIGINAL_ARGS" || exit $?

if [ "$CONFIGURE_MONITOR_ONLY" = true ]; then
    configure_monitor
    exit 0
fi

if [ "$CONFIGURE_SDDM_ONLY" = true ]; then
    configure_sddm_theme
    exit 0
fi

user_confirmation
main
