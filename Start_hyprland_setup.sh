#!/bin/bash

##############################################################
# Hyprland Setup Script
# Based on your Start_system_setup.sh, this script installs
# Hyprland and its dependencies and configures Hyprland tools.
##############################################################

# Helper functions
print_message() {
    echo -e "\033[0;32m[*]\033[0m $1"
}
print_warning() {
    echo -e "\033[1;33m[!]\033[0m $1"
}
print_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}
execute_command() {
    local cmd="$1"
    local description="$2"
    print_message "$description"
    if eval "$cmd"; then
        return 0
    else
        print_error "Command failed: $cmd"
        return 1
    fi
}

##############################################################
# Pacman Update and Hyprland Packages Installation
##############################################################

# Array of Hyprland-related pacman packages
hyprland_packages=(
    "hyprland" 
    "waybar" 
    "hyprpaper" 
    "wofi" 
    "hyprlock" 
    "hypridle" 
    "hyprshot" 
    "hyprpolkitagent" 
    "xdg-desktop-portal-hyprland" 
    "xdg-desktop-portal-gtk" 
    "dunst" 
    "python-pywal" 
    "gnome-keyring" 
    "ttf-jetbrains-mono-nerd" 
    "polkit-kde-agent"
)

install_pacman_packages() {
    print_message "Updating pacman database..."
    execute_command "sudo pacman -Sy" "Update pacman database" || exit 1

    print_message "Installing Hyprland packages..."
    for pkg in "${hyprland_packages[@]}"; do
        if ! execute_command "sudo pacman -S --needed --noconfirm $pkg" "Installing $pkg"; then
            print_warning "Failed to install $pkg. Please install manually if issues persist."
        fi
    done
}

##############################################################
# AUR Extras Installation
##############################################################

aur_extras=(
    "xwaylandvideobridge-git" 
    "hyprshot"
)

install_aur_extras() {
    print_message "Installing Hyprland AUR extras: ${aur_extras[*]}"
    for pkg in "${aur_extras[@]}"; do
        if ! execute_command "yay -S --needed --noconfirm $pkg" "Install $pkg"; then
            print_warning "Installation of $pkg failed. Please install manually."
        fi
    done
}

##############################################################
# Hyprland Configurations
##############################################################

# Check if Hyprland is running
check_hyprland() {
    if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && [ "$XDG_CURRENT_DESKTOP" = "Hyprland" ]; then
        return 0
    else
        return 1
    fi
}

##############################################################
# Main Execution Flow
##############################################################
main() {
    print_message "Starting Hyprland Setup..."
    install_pacman_packages
    install_aur_extras
    print_message "Hyprland setup completed successfully!"
}

main
