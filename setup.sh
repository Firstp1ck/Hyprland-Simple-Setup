#!/bin/bash

############################################################## Disabled Shellcheck Messages ##############################################################
# shellcheck disable=SC2012
# Use find instead of ls to better handle non-alphanumeric filenames.

# shellcheck disable=SC1091
# Not following: /etc/os-release: openBinaryFile: does not exist (No such file or directory)

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
LOG_FILE="${HOME}/Linux-Setup.log"

# Arrays to store update statuses
mirror_updates=()
package_updates=()
aur_updates=()
failed_packages=()
config_statuses=()

# Selected AUR helper (paru preferred if available)
AUR_HELPER=""
AUR_HELPER_CHECKED=""

# Initialize DRY_RUN_OPERATIONS array early for all functions
declare -a DRY_RUN_OPERATIONS=()
FISH_LANGUAGE_CHOICE=""
SETUP_DIR=Hyprland-Simple-Setup

############################################################## Helper Functions ##############################################################

get_fish_language_choice() {
    if [ -z "$FISH_LANGUAGE_CHOICE" ]; then
        if [ "$NON_INTERACTIVE" = "true" ]; then
            # default to 1 (de_CH) if not provided in env
            FISH_LANGUAGE_CHOICE=${FISH_LANGUAGE_CHOICE_OVERRIDE:-1}
            print_verbose "Non-interactive mode: FISH_LANGUAGE_CHOICE_OVERRIDE='$FISH_LANGUAGE_CHOICE_OVERRIDE', using FISH_LANGUAGE_CHOICE='$FISH_LANGUAGE_CHOICE'"
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
    echo -e "${YELLOW}[DRY-RUN]${NC} No actual changes were made to your system."
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
    hyprctl monitors 2>/dev/null | awk '/^Monitor /{print $2; exit}'
}

# Ensure MONITORS is set in wallpaper config; if missing/placeholder, set to first monitor
ensure_wallpaper_monitors() {
    local wallpaper_conf="$HOME/.config/hypr/sources/change_wallpaper.conf"
    [ -f "$wallpaper_conf" ] || return 0

    # Read existing MONITORS line if any
    local current_line
    current_line=$(grep -E '^[[:space:]]*MONITORS=' "$wallpaper_conf" 2>/dev/null || true)

    # Decide if we need to set/update (no line, empty array, or contains placeholder MONITOR)
    local need_set=false
    if [ -z "$current_line" ]; then
        need_set=true
    elif echo "$current_line" | grep -q 'MONITOR'; then
        need_set=true
    elif echo "$current_line" | grep -q 'MONITORS=()'; then
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
        if echo "$current_line" | grep -q 'MONITORS='; then
            execute_command "sed -i -E 's|^MONITORS=.*$|MONITORS=(\"$first_mon\")|' '$wallpaper_conf'" "Set MONITORS to first detected monitor"
        else
            execute_command "printf '%s\n' 'MONITORS=(\"$first_mon\")' >> '$wallpaper_conf'" "Append MONITORS to wallpaper config"
        fi
    fi
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
    echo "[$timestamp] [$log_level] $message" >> "$LOG_FILE"
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

list_packages() {
    announce_step "Generating Package Lists"
    local date_suffix packages_file aur_file is_endeavouros is_debian_based
    date_suffix=$(date +%Y-%m-%d)
    packages_file="$HOME/user_installed_packages_${date_suffix}.txt"
    aur_file="$HOME/aur_packages_${date_suffix}.txt"
    is_endeavouros=false
    is_debian_based=false

    if command -v eos-packagelist &> /dev/null && grep -q "EndeavourOS" /etc/os-release; then
        is_endeavouros=true
        print_message "EndeavourOS detected - will exclude default EndeavourOS packages."
    elif grep -q "CachyOS" /etc/os-release; then
        is_endeavouros=true
        print_message "CachyOS detected - will exclude default CachyOS packages."
    elif command -v apt &> /dev/null && (grep -q "Debian\\|Ubuntu\\|Mint" /etc/os-release || [ -f /etc/debian_version ]); then
        is_debian_based=true
        print_message "Debian-based system detected - will list manually installed packages."
    else
        print_message "Arch Linux detected - will list all explicitly installed packages."
    fi

    print_message "This utility will generate:"
    print_message "  1. A list of manually installed packages"
    if [ "$is_endeavouros" = true ]; then
        print_message "     (excluding EndeavourOS default packages)"
    elif [ "$is_debian_based" = true ]; then
        print_message "     (using apt-mark showmanual)"
    fi
    print_message "  2. A separate list of AUR packages"
    if [ "$is_debian_based" = true ]; then
        print_message "     (not applicable on Debian-based systems)"
    fi

    print_message "Generating package lists..."
    if [ "$is_endeavouros" = true ]; then
        echo -e "# User installed packages (excluding EndeavourOS defaults)" > "$packages_file"
    elif [ "$is_debian_based" = true ]; then
        echo -e "# Manually installed packages on Debian-based system" > "$packages_file"
    else
        echo -e "# User installed packages on Arch Linux" > "$packages_file"
    fi
    echo -e "# Generated on: $(date)\n" >> "$packages_file"

    if [ "$is_debian_based" = false ]; then
        echo -e "# AUR packages installed on the system" > "$aur_file"
        echo -e "# Generated on: $(date)\n" >> "$aur_file"
    fi

    print_message "Processing main package list..."
    if [ "$is_endeavouros" = true ]; then
        execute_command "comm -23 <(pacman -Qqet | sort) <(eos-packagelist KDE-Desktop 'EndeavourOS applications' 'Recommended applications selection' 'Spell Checker and language package' 'Firewall' 'LTS kernel in addition' 'Printing support' 'HP printer/scanner support' | sort) >> '$packages_file'" "List user packages (EndeavourOS)"
    elif [ "$is_debian_based" = true ]; then
        execute_command "apt-mark showmanual >> '$packages_file'" "List manually installed packages (Debian)"
    else
        execute_command "pacman -Qqet >> '$packages_file'" "List explicitly installed packages (Arch)"
    fi
    print_message "Main package list done."

    if [ "$is_debian_based" = false ]; then
        print_message "Processing AUR package list..."
        execute_command "pacman -Qqm >> '$aur_file'" "List AUR packages"
        print_message "AUR package list done."
    fi

    print_message "Package lists have been saved to:"
    print_message "  Main package list: $packages_file"
    print_message "  AUR package list: $aur_file"
    print_message "Total packages found: $(grep -v '^#' "$packages_file" | wc -l)"
    print_message "Total AUR packages found: $(grep -v '^#' "$aur_file" | wc -l)"
    print_message "Thank you for using the Package Installation History Utility!"
}

verify_installed_packages() {
    extended_announce_step "Verifying installed packages"

    # In dry-run, skip verification entirely (execute_command would always succeed)
    if is_dry_run; then
        log_dry_run_operation "verify_installed_packages" "Would verify installed packages via pacman/AUR helper"
        print_message "Dry-run: skipping package verification"
        return 0
    fi

    # Find the newest package list files
    local user_pkg_file
    user_pkg_file=$(ls -t "$HOME"/user_installed_packages_* 2>/dev/null | head -n1)
    local aur_pkg_file
    aur_pkg_file=$(ls -t "$HOME"/aur_packages_* 2>/dev/null | head -n1)

    if [ -z "$user_pkg_file" ] && [ -z "$aur_pkg_file" ]; then
        print_message "No package list files found in $HOME. Generating new package lists..."
        list_packages
        # Re-find the files after generation
        user_pkg_file=$(ls -t "$HOME"/user_installed_packages_* 2>/dev/null | head -n1)
        aur_pkg_file=$(ls -t "$HOME"/aur_packages_* 2>/dev/null | head -n1)
        if [ -z "$user_pkg_file" ] && [ -z "$aur_pkg_file" ]; then
            print_error "Failed to generate package list files."
            track_config_status "Package Verification" "$CROSS_MARK"
            return 1
        fi
    fi

    local missing_packages=()
    local missing_pacman=()
    local missing_aur=()
    local total_checked=0

    # Check standard packages
    if [ -n "$user_pkg_file" ]; then
        print_message "Checking packages from: $(basename "$user_pkg_file")"
        while IFS= read -r package; do
            # Skip empty lines and comments
            [[ -z "$package" || "$package" =~ ^[[:space:]]*# ]] && continue

            ((total_checked++))
            if ! execute_command "pacman -Qi '$package' >/dev/null 2>&1" "Check installed: $package"; then
                missing_packages+=("$package (Pacman)")
                missing_pacman+=("$package")
            fi
        done < "$user_pkg_file"
    fi

    # Check AUR packages
    if [ -n "$aur_pkg_file" ]; then
        print_message "Checking packages from: $(basename "$aur_pkg_file")"
        while IFS= read -r package; do
            # Skip empty lines and comments
            [[ -z "$package" || "$package" =~ ^[[:space:]]*# ]] && continue

            ((total_checked++))
            if ! execute_command "pacman -Qi '$package' >/dev/null 2>&1" "Check installed: $package (AUR)"; then
                missing_packages+=("$package (AUR)")
                missing_aur+=("$package")
            fi
        done < "$aur_pkg_file"
    fi

    # Attempt auto-install of missing packages (Arch-based only)
    if [[ "$DISTRO" == "arch" || "$DISTRO" == "endeavouros" || "$DISTRO" == "cachyos" ]]; then
        if [ ${#missing_pacman[@]} -gt 0 ] || [ ${#missing_aur[@]} -gt 0 ]; then
            print_warning "Found missing packages. Attempting to install them automatically."
            if [ ${#missing_pacman[@]} -gt 0 ]; then
                execute_command "sudo pacman -S --needed --noconfirm ${missing_pacman[*]}" "Install missing repo packages"
            fi
            if [ ${#missing_aur[@]} -gt 0 ]; then
                check_yay
                execute_command "$AUR_HELPER -S --needed --noconfirm ${missing_aur[*]}" "Install missing AUR packages"
            fi

            # Re-verify post-install
            local still_missing=()
            for pkg in "${missing_pacman[@]}"; do
                if ! pacman -Qi "$pkg" &>/dev/null; then
                    still_missing+=("$pkg (Pacman)")
                fi
            done
            for pkg in "${missing_aur[@]}"; do
                if ! pacman -Qi "$pkg" &>/dev/null; then
                    still_missing+=("$pkg (AUR)")
                fi
            done
            missing_packages=("${still_missing[@]}")
        fi
    fi

    # Report results
    if [ ${#missing_packages[@]} -eq 0 ]; then
        print_message "All packages from the lists are installed! ✅"
        print_message "Total packages checked: $total_checked"
        track_config_status "Package Verification" "$CHECK_MARK"
    else
        print_warning "Missing packages (${#missing_packages[@]} out of $total_checked total packages):"
        printf '\n%s\n' "Missing Packages:"
        printf '=====================================\n'
        printf '%s\n' "${missing_packages[@]}" | column
        printf '=====================================\n'
        track_config_status "Package Verification" "$CROSS_MARK"
    fi
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
    if is_dry_run; then
        log_dry_run_operation "update_configs" "Would update Hyprland sources and wallpaper config with WALLPAPER_DIR=$WALLPAPER_DIR"
        return 0
    fi

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
        execute_command "sed -i 's|\\\$wallpaper=~/$SETUP_DIR/Wallpaper/Forest_01.png|\\\$wallpaper=\"$hyprland_setup_dir/Wallpaper/Forest_01.png\"|g' '$app_vars_conf'" "Update wallpaper path in app_variables.conf"
    else
        print_warning "app_variables.conf not found at $app_vars_conf"
    fi

    # Run stow script after copying sources_example
    if [ -f "$HOME/dotfiles/.local/scripts/Start_stow_solve.sh" ]; then
        print_message "Setting up dotfiles with Start_stow_solve.sh..."
        if bash "$HOME/dotfiles/.local/scripts/Start_stow_solve.sh"; then
            print_message "Stow script executed successfully"
            track_config_status "Dotfiles Setup" "$CHECK_MARK"
        else
            print_error "Stow script failed to execute properly"
            track_config_status "Dotfiles Setup" "$CROSS_MARK"
        fi
    else
        print_warning "Start_stow_solve.sh not found at $HOME/dotfiles/.local/scripts"
        print_warning "Skipping dotfiles setup"
        track_config_status "Dotfiles Setup" "$CROSS_MARK"
    fi

    # Update the wallpaper configuration file
    # Use the active runtime config under ~/.config; if symlinked to dotfiles, it will update there too
    local wallpaper_conf="$HOME/.config/hypr/sources/change_wallpaper.conf"
    execute_command "mkdir -p '$(dirname "$wallpaper_conf")'" "Create wallpaper config directory"
    # If config exists, only update WALLPAPER_DIR in place to preserve MONITORS and other settings
    if [ -f "$wallpaper_conf" ]; then
        execute_command "if grep -q '^WALLPAPER_DIR=' '$wallpaper_conf'; then sed -i -E 's|^WALLPAPER_DIR=.*$|WALLPAPER_DIR=\"$WALLPAPER_DIR\"|' '$wallpaper_conf'; else printf '%s\n' 'WALLPAPER_DIR=\"$WALLPAPER_DIR\"' >> '$wallpaper_conf'; fi" "Update WALLPAPER_DIR without touching MONITORS"
    else
        # Create new file with header and WALLPAPER_DIR; leave MONITORS for monitor configurator or auto-detect in script
        execute_command "printf '%s\n' '# Wallpaper Configuration' 'WALLPAPER_DIR=\"$WALLPAPER_DIR\"' > '$wallpaper_conf'" "Create initial wallpaper config"
    fi

    # Ensure MONITORS is set (auto-detect first monitor if user did not set)
    ensure_wallpaper_monitors
    
    print_message "Configuration files updated with user input."
}

# Function to update fish language config in fish config file
set_fish_language_config() {
    if is_dry_run; then
        log_dry_run_operation "set_fish_language_config" "Would update fish language config"
        return 0
    fi
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
        execute_command "mkdir -p '$(dirname "$fish_conf")'" "Create fish config directory"
        execute_command "touch '$fish_conf'" "Touch fish config file"
        # Add initial language settings if file is new
        execute_command "echo '# Language Settings' >> '$fish_conf' && echo 'set -gx LANG \"$lang\"' >> '$fish_conf' && echo 'set -gx LANGUAGE \"$language\"' >> '$fish_conf' && echo '' >> '$fish_conf'" "Add initial language settings"
    else
        print_message "Updating existing fish config file at $fish_conf"
        # Replace existing language settings (handle both with and without quotes)
        execute_command "sed -i -E 's|^set -gx LANG .*|set -gx LANG \"$lang\"|' '$fish_conf'" "Update LANG"
        execute_command "sed -i -E 's|^set -gx LANGUAGE .*|set -gx LANGUAGE \"$language\"|' '$fish_conf'" "Update LANGUAGE"
    fi
    
    # Also update the runtime location if it exists and is not a symlink (or if symlink is broken)
    if [ -f "$fish_conf_runtime" ] && [ ! -L "$fish_conf_runtime" ]; then
        print_message "Also updating runtime fish config file at $fish_conf_runtime"
        execute_command "sed -i -E 's|^set -gx LANG .*|set -gx LANG \"$lang\"|' '$fish_conf_runtime'" "Update LANG in runtime config"
        execute_command "sed -i -E 's|^set -gx LANGUAGE .*|set -gx LANGUAGE \"$language\"|' '$fish_conf_runtime'" "Update LANGUAGE in runtime config"
    fi

    print_message "Fish language settings updated: LANG=$lang, LANGUAGE=$language"
}

##############################################################
# Pacman Update and Hyprland Packages Installation
##############################################################

# Array of Hyprland-related pacman packages
hyprland_packages=(
    # Core Hyprland packages
    "waybar"
    "hyprpaper"
    "hyprcursor"
    "hyprlock"
    "hypridle"
    "hyprpolkitagent"
    "hyprpicker"
    "wl-clipboard"
    "wl-clip-persist"
    "hyprgraphics" 
    "hyprland-qtutils" 
    "hyprland-qt-support" 
    "hyprwayland-scanner"
    "python-pyquery"
    "tk"
    "arch-wiki-docs"

    # Installed by "archinstall"-script: Desktop Type
    "dolphin"
    "grim"
    "htop"
    "hyprland"
    "iwd"
    "kitty"
    "nano"
    "openssh"
    "polkit-kde-agent"
    "qt5-wayland"
    "qt6-wayland"
    "slurp"
    "smartmontools"
    "vim"
    "wget"
    "wireless_tools"
    "wofi"
    "wpa_supplicant"
    "xdg-desktop-portal-hyprland"
    "xdg-utils"

    # Installed by "archinstall"-script: Graphics Driver
    "intel-media-driver"
    "libva-intel-driver"
    "libva-mesa-driver"
    "mesa"
    "vulkan-intel"
    "vulkan-nouveau"
    "vulkan-radeon"
    "xf86-video-amdgpu"
    "xf86-video-ati"
    "xf86-video-nouveau"
    "xorg-server"
    "xorg-xinit"

    # Installed by "archinstall"-script: Greeter (Login Manager)
    "sddm"
    
    # Installed by "archinstall"-script: Audio
    "pipewire"
    "pipewire-pulse"
    "wireplumber"

    # Installed by "archinstall"-script: Kernel
    "linux"
    "linux-headers"
    "linux-api-headers"
    "linux-firmware"

    # File Management
    "xdg-user-dirs"
    "git"
    "onefetch"
    "fd"
    "fzf"
    "stow"
    "nvim"
    "ark"
    "7zip"
    "timeshift"
    "grub-btrfs"
    "inotify-tools"
    "satty"
    
    # Shell
    "fish"
    
    # Browser
    "vivaldi"
    "vivaldi-ffmpeg-codecs"
    
    # System Integration
    "xdg-desktop-portal-gtk"
    "xdg-desktop-portal-kde"
    "gnome-keyring"
    "network-manager-applet"
    "networkmanager"
    "nm-connection-editor"
    "bluez"
    "bluez-utils"
    "blueman"
    "pipewire"
    "pipewire-pulse"
    "pavucontrol"
    "pulseaudio-qt"
    "swaync"
    "ddcutil"
    
    # Theming and Appearance
    "ttf-jetbrains-mono-nerd"
    "ttf-nerd-fonts-symbols"
    "ttf-nerd-fonts-symbols-common"
    "otf-font-awesome"
    "cava"
    "breeze"
    "breeze5"
    "breeze-gtk"
    "qt5ct"
    "qt6ct"
    "nwg-look"
    
    # CLI Tools
    "dysk"
    "duf"
    "bat"
    "lsd"
    "btop"
    "zoxide"
    "lshw"
    "ntfs-3g"
    "firewalld"
    "konsole"
    "fastfetch"
    "tldr"
    "zellij"
    "calcurse"
    "psensor"

    # Calculator
    "qalculate-gtk"
)

update_arch_mirrors() {
    announce_step "Updating Arch mirrors"
    if [[ "$DISTRO" == "manjaro" ]]; then
        print_message "Detected Manjaro. Using pacman-mirrors instead of reflector."
        if ! command -v pacman-mirrors &> /dev/null; then
            print_message "pacman-mirrors not installed. Installing pacman-mirrors..."
            if ! distro_install "pacman-mirrors"; then
                print_error "pacman-mirrors installation failed. Aborting mirror update."
                mirror_updates+=("Arch Mirrors: $CROSS_MARK")
                return 1
            fi
        fi
        if execute_command "sudo pacman-mirrors --geoip --timeout 6 && sudo pacman -Syy" "Update Manjaro mirrors"; then
            mirror_updates+=("Arch Mirrors: $CHECK_MARK")
        else
            mirror_updates+=("Arch Mirrors: $CROSS_MARK")
        fi
        return 0
    fi
        if ! command -v reflector &> /dev/null; then
        print_message "Reflector not installed. Installing reflector..."
        if ! distro_install "reflector"; then
            print_error "Reflector installation failed. Aborting mirror update."
            return 1
        fi
    fi
    if execute_command "sudo reflector --verbose --protocol https --sort rate --latest 20 --download-timeout 6 --save /etc/pacman.d/mirrorlist" "Update Arch mirrors"; then
        mirror_updates+=("Arch Mirrors: $CHECK_MARK")
    else
        mirror_updates+=("Arch Mirrors: $CROSS_MARK")
    fi
}

update_pacman() {
    announce_step "Updating pacman packages"
    if execute_command "sudo pacman -Syyu --noconfirm" "Update pacman packages"; then
        package_updates+=("Pacman Packages: $CHECK_MARK")
    else
        package_updates+=("Pacman Packages: $CROSS_MARK")
    fi
}

update_yay() {
    announce_step "Updating AUR packages"
    check_yay
    if execute_command "$AUR_HELPER -Sua --noconfirm" "Update AUR packages"; then
        aur_updates+=("AUR Packages: $CHECK_MARK")
    else
        aur_updates+=("AUR Packages: $CROSS_MARK")
    fi
}

remove_cache() {
    announce_step "Removing pacman cache"
    check_yay
    if [[ "$DISTRO" == "endeavouros" ]]; then
        execute_command "sudo paccache -r && sudo pacman -Sc --noconfirm && $AUR_HELPER -Sc --noconfirm" "Remove pacman/aur cache (EndeavourOS)"
    elif [[ "$DISTRO" == "arch" ]] || [[ "$DISTRO" == "cachyos" ]]; then
        execute_command "sudo pacman -Sc --noconfirm && $AUR_HELPER -Sc --noconfirm" "Remove pacman/aur cache (Arch Linux/CachyOS)"
    else
        execute_command "sudo pacman -Sc --noconfirm && $AUR_HELPER -Sc --noconfirm" "Remove pacman/aur cache"
    fi
    print_message "Pacman cache removed."
}

install_pacman_packages() {
    announce_step "Install pacman packages"
    print_message "Updating pacman database..."
    execute_command "sudo pacman -Sy" "Update pacman database" || exit 1

    # Determine packages to install from env override, default to hyprland_packages array
    local -a pkgs_to_install=()
    if [ -n "${SELECTED_PACMAN_PACKAGES}" ]; then
        # Allow comma or whitespace separated lists
        IFS=' ' read -r -a pkgs_to_install <<< "${SELECTED_PACMAN_PACKAGES//,/ }"
        print_message "Installing selected packages from TUI (${#pkgs_to_install[@]} items)"
    else
        pkgs_to_install=("${hyprland_packages[@]}")
        print_message "Installing default Hyprland packages..."
    fi

    # Append user-added pacman packages (if any)
    if [ -n "${USER_ADDED_PACMAN_PACKAGES}" ]; then
        read -r -a user_pac_arr <<< "${USER_ADDED_PACMAN_PACKAGES//,/ }"
        pkgs_to_install+=("${user_pac_arr[@]}")
    fi

    # Deduplicate pkgs_to_install while preserving order
    if [ ${#pkgs_to_install[@]} -gt 0 ]; then
        declare -A _seen
        local -a _dedup
        for p in "${pkgs_to_install[@]}"; do
            if [ -n "$p" ] && [ -z "${_seen[$p]}" ]; then
                _seen[$p]=1
                _dedup+=("$p")
            fi
        done
        pkgs_to_install=("${_dedup[@]}")
        unset _seen
    fi

    # If CachyOS Snapper support is present, skip installing Timeshift entirely
    if pacman -Qq cachyos-snapper-support &>/dev/null; then
        print_message "Detected 'cachyos-snapper-support'. Skipping installation of Timeshift."
        local -a _filtered
        for p in "${pkgs_to_install[@]}"; do
            if [ "$p" != "timeshift" ]; then
                _filtered+=("$p")
            fi
        done
        pkgs_to_install=("${_filtered[@]}")
        unset _filtered
    fi

    for pkg in "${pkgs_to_install[@]}"; do
        if ! execute_command "sudo pacman -S --needed --noconfirm $pkg" "Installing $pkg"; then
            print_warning "Failed to install $pkg. Please install manually if issues persist."
        fi
    done
}

##############################################################
# AUR Extras Installation
##############################################################

# Array of AUR packages
aur_extras=(
    "xwaylandvideobridge"
    "hyprshot"
    "visual-studio-code-bin"
    "lsplug"
    "waypaper-git"
    "pyprland"
    "wl-clipboard-history-git"
    "hyprsunset"
    "github-desktop-bin"
    "rose-pine-hyprcursor"
    "waybar-module-pacman-updates-git"
    "wlogout"
    # "nerd-fonts-noto-sans-mono"
)

install_aur_extras() {
    announce_step "Install AUR extras"
    local -a aur_to_install=()
    # Merge TUI-selected AUR packages and user-added AUR packages
    if [ -n "${SELECTED_AUR_PACKAGES}" ]; then
        IFS=' ' read -r -a aur_to_install <<< "${SELECTED_AUR_PACKAGES//,/ }"
        print_message "Installing selected AUR packages from TUI (${#aur_to_install[@]} items)"
    else
        aur_to_install=("${aur_extras[@]}")
        print_message "Installing default Hyprland AUR extras: ${aur_to_install[*]}"
    fi
    if [ -n "${USER_ADDED_AUR_PACKAGES}" ]; then
        # append user-added aur entries
        read -r -a user_aur_arr <<< "${USER_ADDED_AUR_PACKAGES//,/ }"
        aur_to_install+=("${user_aur_arr[@]}")
    fi

    # Deduplicate AUR list while preserving order
    if [ ${#aur_to_install[@]} -gt 0 ]; then
        declare -A _seen2
        local -a _dedup2
        for p in "${aur_to_install[@]}"; do
            if [ -n "$p" ] && [ -z "${_seen2[$p]}" ]; then
                _seen2[$p]=1
                _dedup2+=("$p")
            fi
        done
        aur_to_install=("${_dedup2[@]}")
        unset _seen2
    fi

    check_yay
    for pkg in "${aur_to_install[@]}"; do
        if ! execute_command "$AUR_HELPER -S --needed --noconfirm $pkg" "Install $pkg"; then
            print_warning "Installation of $pkg failed. Please install manually."
        fi
    done
}

##############################################################
# Hyprland Configurations
##############################################################

configure_fish() {
    announce_step "Setting default shell to fish"
    if execute_command "sudo chsh -s /usr/bin/fish" "Set fish as default shell"; then
        track_config_status "Default Shell (fish)" "$CHECK_MARK"
    else
        track_config_status "Default Shell (fish)" "$CROSS_MARK"
    fi

    print_message "Download fzf Repository for fzf file management integration in fish"
    if [ -d "$HOME/.fzf" ]; then
        print_message "fzf repository already exists at $HOME/.fzf, skipping clone."
    else
        execute_command "git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf" "Download fzf Github Repo"
    fi

    # Run fzf install script non-interactively for fish only
    if [ -f "$HOME/.fzf/install" ]; then
        execute_command "\"$HOME/.fzf/install\" --all --no-bash --no-zsh --no-update-rc" "Execute fzf Installation (non-interactive for fish)"
    else
        print_warning "fzf install script not found at $HOME/.fzf/install"
    fi
}

configure_environment() {
    announce_step "Configuring Environment"

    # Check if nvim is installed
    if ! command -v nvim &>/dev/null; then
        print_message "Neovim is not installed. Installing..."
        if ! distro_install "neovim"; then
            print_error "Failed to install Neovim. Please install it manually."
            echo "Configuration failed."
            return 1
        fi
    fi

    # Set EDITOR environment variable
    if ! execute_command "systemctl --user set-environment EDITOR=nvim" "Set EDITOR environment variable to nvim"; then
        print_error "Failed to set EDITOR environment variable."
        echo "Configuration failed."
        return 1
    fi

    echo "Configuration completed successfully."
}

configure_network_manager() {
    announce_step "Configuring NetworkManager"
    if command -v nm-connection-editor >/dev/null || command -v nm-applet >/dev/null || command -v nmcli >/dev/null; then
        if execute_command "sudo systemctl enable --now NetworkManager" "Enable NetworkManager"; then
            track_config_status "NetworkManager Setup" "$CHECK_MARK"
        else
            track_config_status "NetworkManager Setup" "$CROSS_MARK"
        fi
    else
        print_warning "Network Manager tools not found. Skipping NetworkManager setup."
        track_config_status "NetworkManager Setup" "$CIRCLE (Not installed)"
    fi
}

configure_wifi() {
    announce_step "Configuring WiFi"
    if ! ip link show wlan0 &>/dev/null; then
        print_warning "No wireless device (wlan0) found"
        track_config_status "WiFi Configuration" "$CIRCLE (No wireless device)"
        return 0
    fi
    if execute_command "sudo iw dev wlan0 set power_save off" "Disable WiFi power save"; then
        track_config_status "WiFi Configuration" "$CHECK_MARK"
    else
        track_config_status "WiFi Configuration" "$CROSS_MARK"
    fi
}

configure_bluetooth() {
    announce_step "Configuring Bluetooth"
    for pkg in bluez bluez-utils blueman; do
        if ! pacman -Qq "$pkg" &>/dev/null; then
            print_message "Installing missing package: $pkg"
            if ! distro_install "$pkg"; then
                print_error "Failed to install $pkg. Aborting Bluetooth configuration."
                return 1
            fi
        fi
    done

    print_message "Enabling Bluetooth..."
    if execute_command "sudo systemctl enable --now bluetooth" "Enable and start Bluetooth"; then
        track_config_status "Bluetooth Setup" "$CHECK_MARK"
    else
        track_config_status "Bluetooth Setup" "$CROSS_MARK"
    fi
}

configure_gnome_keyring() {
    announce_step "Configuring gnome-keyring"

    if [ "$XDG_CURRENT_DESKTOP" = "KDE" ] || [ "$XDG_CURRENT_DESKTOP" = "plasma" ] || pgrep -x "plasmashell" > /dev/null; then
        print_message "KDE environment detected. Skipping gnome-keyring configuration."
        track_config_status "Gnome-keyring Setup" "$CIRCLE (Not needed in KDE)"
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
            execute_command "sudo bash -c \"printf '%s\\n' 'auth optional pam_gnome_keyring.so' >> '$target_file'\"" "Add pam_gnome_keyring.so auth to $target_file"
        fi
        if [ "$has_session" != "true" ]; then
            execute_command "sudo bash -c \"printf '%s\\n' 'session optional pam_gnome_keyring.so auto_start' >> '$target_file'\"" "Add pam_gnome_keyring.so session to $target_file"
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
    fi
}

configure_filepicker() {
    announce_step "Configuring filepicker"

    if ! check_hyprland; then
        print_message "Not running in Hyprland. Skipping filepicker configuration."
        track_config_status "Filepicker Setup" "$CIRCLE (Not in Hyprland)"
        return 0
    fi
    local conf_dir="${HOME}/.config/xdg-desktop-portal"
    local conf_file="${conf_dir}/hyprland-portals.conf"
    local desired_content="[preferred]\ndefault = hyprland;gtk\norg.freedesktop.impl.portal.FileChooser = kde"
    execute_command "mkdir -p '$conf_dir'" "Create xdg-desktop-portal config dir"
    if [ -f "$conf_file" ]; then
        if grep -q "default = hyprland;gtk" "$conf_file" && grep -q "org.freedesktop.impl.portal.FileChooser = kde" "$conf_file"; then
            print_message "Filepicker configuration already set."
        else
            print_message "Updating filepicker configuration..."
            execute_command "echo -e '$desired_content' > '$conf_file'" "Update filepicker configuration"
        fi
    else
        print_message "Creating filepicker configuration..."
        execute_command "echo -e '$desired_content' > '$conf_file'" "Create filepicker configuration"
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
    if is_dry_run; then
        log_dry_run_operation "configure_pacman_color" "Would update /etc/pacman.conf for Color and ILoveCandy"
        return 0
    fi
    local pacman_conf="/etc/pacman.conf"
    local tmp_conf="/tmp/pacman.conf.$$"
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
        awk '/^\[options\]/{print;print "Color";next}1' "$tmp_conf" > "${tmp_conf}.new" && mv "${tmp_conf}.new" "$tmp_conf"
        color_found=true
        color_line_num=$(awk '/^Color$/{print NR; exit}' "$tmp_conf")
    fi

    # If ILoveCandy is not found, add it just below Color
    if ! $candy_found && $color_found; then
        awk -v cline="$color_line_num" '{print; if(NR==cline) print "ILoveCandy"}' "$tmp_conf" > "${tmp_conf}.new" && mv "${tmp_conf}.new" "$tmp_conf"
    fi

    # Only replace the original if changes were made
    if ! cmp -s "$pacman_conf" "$tmp_conf"; then
        sudo cp "$pacman_conf" "${pacman_conf}.bak.$(date +%Y%m%d%H%M%S)"
        sudo cp "$tmp_conf" "$pacman_conf"
        print_message "Updated $pacman_conf: ensured 'Color' is uncommented and 'ILoveCandy' is present."
    else
        print_message "$pacman_conf already has 'Color' and 'ILoveCandy' set correctly."
    fi
    rm -f "$tmp_conf"
}

configure_timeshift() {
    announce_step "Setting up Timeshift"

    # Skip Timeshift setup if CachyOS Snapper integration is present
    if pacman -Qq cachyos-snapper-support &>/dev/null; then
        print_message "Detected 'cachyos-snapper-support'. Skipping Timeshift configuration."
        track_config_status "Timeshift Setup" "$CIRCLE (Using CachyOS Snapper)"
        return 0
    fi

    # Ensure Timeshift is installed
    if ! command -v timeshift &>/dev/null; then
        if ! distro_install "timeshift"; then
            track_config_status "Timeshift Setup" "$CROSS_MARK"
            return 1
        fi
    fi

    # Enable the cronie service (required for scheduling snapshots)
    if ! execute_command "sudo systemctl enable --now cronie.service" "Enable Cronie for Timeshift scheduling"; then
        track_config_status "Timeshift Setup" "$CROSS_MARK"
        return 1
    fi

    # Create an initial snapshot without a .snapshot suffix
    if execute_command "sudo timeshift --create --comments 'Automated snapshot created by Linux-Setup script' --tags D" "Create initial Timeshift snapshot"; then
        track_config_status "Timeshift Setup" "$CHECK_MARK"
    else
        track_config_status "Timeshift Setup" "$CROSS_MARK"
    fi
}

configure_grub_btrfsd() {
    announce_step "Configuring grub-btrfsd"

    # Check if  Bootloader is GRUB
    if ! check_bootloader "grub"; then
        print_warning "Bootloader is not GRUB. Skipping grub-btrfsd configuration."
        track_config_status "grub-btrfsd Configuration" "$CIRCLE (Not GRUB bootloader)"
        return 0
    fi

    # Check if the root filesystem is BTRFS
    if ! mount | grep "on / type btrfs" > /dev/null; then
        print_warning "Root filesystem is not BTRFS. Skipping grub-btrfsd configuration."
        track_config_status "grub-btrfsd Configuration" "$CIRCLE (Not BTRFS filesystem)"
        return 0
    fi

    # Create systemd override directory if it doesn't exist
    if ! execute_command "sudo mkdir -p /etc/systemd/system/grub-btrfsd.service.d" "Create override directory for grub-btrfsd"; then
        track_config_status "grub-btrfsd Configuration" "$CROSS_MARK"
        return 1
    fi

    # Create (or overwrite) a drop-in override file that removes any '.snapshot' and appends '-t' to ExecStart
    if is_dry_run; then
        log_dry_run_operation "configure_grub_btrfsd" "Would write /etc/systemd/system/grub-btrfsd.service.d/override.conf"
    else
        if sudo bash -c "cat > /etc/systemd/system/grub-btrfsd.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=\$(grep '^ExecStart=' /etc/systemd/system/grub-btrfsd.service | sed 's/\.snapshot//g; s/\$/ -t/')
EOF"; then
            print_message "grub-btrfsd override file created."
        else
            print_error "Failed to create grub-btrfsd override file."
            track_config_status "grub-btrfsd Configuration" "$CROSS_MARK"
            return 1
        fi
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
                print_message "Non-interactive: skipping monitor setup"
                track_config_status "Monitor Setup" "$CIRCLE (Skipped by config)"
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

    if check_hyprland; then
        local monitor_output
        monitor_output=$(hyprctl monitors 2>&1)
        print_message "Hyprland monitor configuration:"
        echo "$monitor_output"
        local monitor_count
        monitor_count=$(echo "$monitor_output" | grep -E -c "^Monitor")
        print_message "Detected $monitor_count monitor(s) on Hyprland."
        if [ "$monitor_count" -eq 0 ]; then
            print_warning "No monitors detected via hyprctl monitors."
            return
        fi

        # Get monitor names
        local monitor_names=()
        while IFS= read -r line; do
            monitor_names+=("$(echo "$line" | awk '{print $2}')")
        done < <(echo "$monitor_output" | grep "^Monitor")

        # Initialize variables for monitor configuration
        local primary_monitor=""
        local primary_width=""
        local configured_monitors=()
        # local monitors_conf_file="${HOME}/Dokumente/GitHub/$SETUP_DIR/dotfiles/.config/hypr/sources_example/monitors.conf"
        local monitors_conf_file="${HOME}/.config/hypr/sources/monitors.conf"
        # local wallpaper_conf="${HOME}/Dokumente/GitHub/$SETUP_DIR/dotfiles/.config/hypr/sources_example/change_wallpaper.conf"
        local wallpaper_conf="${HOME}/.config/hypr/sources/change_wallpaper.conf"

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

            # Update monitor configuration
            if grep -q "^monitor=${monitor_name}," "$monitors_conf_file"; then
                sed -i "s|^monitor=${monitor_name},.*|monitor=${monitor_name},${chosen_resolution},${offset},${scale}|g" "$monitors_conf_file"
            else
                sed -i "1i monitor=${monitor_name},${chosen_resolution},${offset},${scale}" "$monitors_conf_file"
            fi

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
        awk -F, -v p="$primary" -v s="$secondary" 'BEGIN { OFS="," }
            /^workspace=/ {
                split($1, arr, "");
                ws=arr[2];
                if (ws % 2 == 1) { $2="monitor:" s } else { $2="monitor:" p }
                print
            }
            !/^workspace=/ { print }
        ' "$monitors_conf_file" > "${monitors_conf_file}.tmp" && mv "${monitors_conf_file}.tmp" "$monitors_conf_file"

        # Update wallpaper configuration
        if [ -f "$wallpaper_conf" ]; then
            local monitors_str=""
            for m in "${configured_monitors[@]}"; do
                monitors_str+="\"$m\" "
            done
            monitors_str=$(echo "$monitors_str")
            if grep -q "^MONITORS=" "$wallpaper_conf"; then
                sed -i "s|^MONITORS=.*|MONITORS=($monitors_str)|" "$wallpaper_conf"
            else
                echo "MONITORS=($monitors_str)" >> "$wallpaper_conf"
            fi
            print_message "Updated MONITORS in change_wallpaper.conf: MONITORS=($monitors_str)"
        else
            print_warning "Wallpaper configuration file not found: $wallpaper_conf"
        fi

        # Remove any remaining placeholder text
        sed -i '/MONITOR_[0-9]/d' "$monitors_conf_file"
        sed -i '/MONITOR_[0-9]/d' "$wallpaper_conf"

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
    if ! execute_command "echo -e '[Theme]\nCurrent=eucalyptus-drop' | sudo tee '$sddm_conf'"; then
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
        fi
    else
        print_warning "systemctl not available; skipping SDDM enable."
    fi
}

# Verify configs do not pre-create workspace 11
verify_workspace_config() {
    print_message "Verifying workspace configuration"
    local issues=0
    local files=(
        "$HOME/.config/hypr/sources/monitors.conf"
        "$HOME/.config/hypr/sources/windows_and_workspaces.conf"
        "$HOME/dotfiles/.config/hypr/sources/monitors.conf"
        "$HOME/dotfiles/.config/hypr/sources/windows_and_workspaces.conf"
        "$HOME/.dotfiles/.config/hypr/sources/monitors.conf"
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

main() {
    print_message "Starting Hyprland Setup..."

    # Skip sudo password setup in dry-run
    if is_dry_run; then
        print_message "Dry-run: skipping sudo password capture"
    else
        setup_sudo_password
    fi

    get_fish_language_choice
    check_disk_space
    check_distro
    check_desktop_environment

    # Check if xdg-user-dirs is installed
    if ! command -v xdg-user-dirs-update &>/dev/null; then
        print_message "xdg-user-dirs not found. Installing..."
        if ! distro_install "xdg-user-dirs"; then
            print_error "Failed to install xdg-user-dirs"
            return 1
        fi
    fi

    if execute_command "xdg-user-dirs-update" "Creating User Environment"; then
        print_message "User Environment created"
    else
        print_warning "User Environment could not be created!"
    fi
    
    check_dependencies
    check_environment
    check_user_input
    
    if ! validate_wallpaper_dir; then
        if [ "$NON_INTERACTIVE" = "true" ]; then
            case "${AUTO_CONTINUE_ON_WARNINGS:-false}" in
                true|1|yes|y|Y) print_warning "Continuing despite wallpaper validation failure (auto)" ;;
                *) print_error "Setup aborted due to wallpaper validation failure (non-interactive)"; exit 1 ;;
            esac
        else
            read -rp "Continue anyway? (y/N): " choice
            if [[ ! $choice =~ ^[Yy]$ ]]; then
                print_error "Setup aborted by user"
                exit 1
            fi
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
    fi

    update_arch_mirrors
    update_pacman

    update_yay
    remove_cache
    install_pacman_packages
    install_aur_extras
    update_configs
    set_fish_language_config
    configure_fish
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

    # As the very last step, enable and start SDDM (may end current session)
    enable_sddm_last

    announce_step "Hyprland setup completed successfully!"
}

# Add command line argument handling
DRY_RUN=false
VERBOSE=false
CONFIGURE_MONITOR_ONLY=false
CONFIGURE_SDDM_ONLY=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            ;;
        --verbose)
            VERBOSE=true
            ;;
        --configure-monitor)
            CONFIGURE_MONITOR_ONLY=true
            ;;
        --configure-sddm)
            CONFIGURE_SDDM_ONLY=true
            ;;
        *)
            print_warning "Unknown parameter passed: $1"
            ;;
    esac
    shift
done

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
