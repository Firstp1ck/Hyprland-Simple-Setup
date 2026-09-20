# Release v0.3.0

## Key Features

### 1. Automated Setup & Dependency Management
- **Interactive Setup Script**: `Setup/Start_hyprland_setup.sh` automates installation, configuration, and verification of all required packages (Pacman & AUR), and guides the user through system-specific steps.
- **Logging**: All actions are logged to `~/Linux-Setup.log` for troubleshooting.
- **Package Verification**: Ensures all required packages are installed and reports missing ones.
- **Backup & Stow**: Dotfiles are managed with GNU stow, with automatic backup of existing files.

### 2. Modular Dotfile Structure
- **Config Organization**: All configs are split into modular files (monitors, keybindings, autostart, environment, etc.) for easy customization and troubleshooting.
- **Stow Deployment**: `.local/scripts/Start_stow_solve.sh` deploys dotfiles using stow.

### 3. Hyprland Desktop Environment
- **Multi-Monitor Support**: Interactive monitor configuration, per-monitor workspaces, and dynamic workspace assignment.
- **Window Management**: Advanced controls (edge snap, resize, floating/tiled toggle, window grouping/tabbing).
- **Custom Window Rules**: Easily define rules for floating, centering, opacity, and workspace assignment.
- **Keybindings**: Modular, user-editable keybindings for window management, media, screenshots, and more.

### 4. Visual & Usability Enhancements
- **Waybar Status Bar**: Custom modules (power, weather, updates, Dunst, etc.), system tray, workspace overview, network, volume, battery, and more. Toggle visibility with a script.
- **Wofi Launcher**: Themed, image-capable application launcher with custom menu and style.
- **Kitty Terminal**: Multiple layouts, session management, and custom key mappings.
- **Fish Shell**: Smart history, completions, and workflow aliases.
- **Modern CLI Tools**: Includes `bat`, `lsd`, `btop`, `fzf`, `fd`, and more for an enhanced terminal experience.
- **Theming**: JetBrains Mono Nerd Font, custom CSS for Waybar and Wofi, and easy appearance tweaks.

### 5. Wallpaper & Appearance Management
- **Random Wallpaper Script**: `change_wallpaper.sh` selects a random wallpaper (excluding the current one) and applies it to all monitors, with support for multiple formats.
- **Hyprpaper Integration**: Ensures the wallpaper daemon is running and applies changes live.
- **Night Light**: `hyprsunset.sh` toggles color temperature for day/night modes.

### 6. Notification & System Integration
- **Dunst Notifications**: Persistent critical notifications, action button support, and a script to ensure Dunst is running.
- **Autostart Checks**: `Startup_check.sh` verifies all essential processes (network, clipboard, notifications, etc.) are running and notifies the user of any failures.
- **File Manager Fixes**: `fix-dolphin.sh` ensures Dolphin file manager integration works as expected.

### 7. Productivity & Helper Scripts
- **Music Player**: `play_music.sh` provides a TUI for music playback, including album art and track selection.
- **Notes Utility**: `notes.sh` launches a note-taking session in Kitty and Neovim, with file management.
- **Toggle Scripts**: Scripts to toggle Waybar visibility and window floating state.

### 8. Security & Power Management
- **Screen Locking**: Hyprlock with custom styling and multi-monitor support.
- **Authentication**: Polkit and keyring integration for secure privilege escalation and credential storage.
- **Power Profiles**: Waybar integration for power profile switching and battery monitoring.

### 9. Customization & Extensibility
- **Easy Customization**: All configs are modular and well-commented for user extension.
- **Autostart Applications**: User-defined startup programs via modular config.
- **Environment Variables**: Locale, language, and environment settings are modular and easily adjustable.

### 10. Troubleshooting & Recovery
- **Comprehensive Logging**: All setup and runtime actions are logged for easy troubleshooting.
- **Helper Scripts**: For common issues (e.g., fixing Dolphin, restarting Dunst, checking autostart status).
- **Recovery Options**: Guidance for configuration errors and Hyprland startup issues.

## Supported Platforms
- **Arch Linux** and derivatives (EndeavourOS tested)
- **Wayland** (Hyprland compositor)

## Getting Started
1. Clone the repository and run the setup script to install dependencies and configure your system.
2. Deploy dotfiles using the provided stow script.
3. Customize configuration files as needed for your environment.

For detailed instructions, see the `README.md`.

## Additional Resources
- [Hyprland Wiki](https://wiki.hyprland.org/)
- [Waybar Wiki](https://github.com/Alexays/Waybar/wiki)
- [Kitty Documentation](https://sw.kovidgoyal.net/kitty/)
- [Fish Shell Docs](https://fishshell.com/docs/current/index.html)

For issues, suggestions, or contributions, please open an issue or pull request on GitHub.

