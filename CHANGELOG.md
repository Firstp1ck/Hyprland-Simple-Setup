# Changelog

All notable changes to Hyprland-Simple-Setup will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [0.6.0] - 2026-04-01

# Release v0.6.0

This release focuses on **safer setup behavior**, **better shell/dotfiles**, and **TUI stability improvements**.

## Highlights
- **Setup script hardening**
  - Improved AUR helper detection and support for multiple helpers.
  - Better behavior for **Windows** and **dry-run** modes (skips dependency verification where appropriate while still checking AUR helper logic).
  - Mirror update improvements and better directory/Timeshift handling.
  - PAM configuration handling refactored for clearer and safer appending.
- **TUI improvements**
  - Fixed an input bug where pressing **`q`** in the password field could close the prompt.
  - Refactoring and cleanup to improve readability and maintainability.
  - Package selection/filtering logic improved.
- **Dotfiles & Hyprland tooling updates**
  - Fish shell improvements, including more robust non-interactive language configuration (`FISH_LANGUAGE_CHOICE`).
  - New/updated helper scripts for Hyprland and Waybar (utilities and toggles).
  - Updated themes/configs (Waybar, SwayNC, Kitty, Zellij, Starship, etc.).
- **Project automation**
  - Added/updated GitHub Actions workflows (Rust CI + release workflow).
  - Added `dev/scripts/release.fish` for release automation.

## Notable changes (since v0.5.0)
- Updated README to recommend the `hyprland-simple-setup` TUI command.
- `packages.json`: add `python` and `python-requests`.
- GitHub templates: bug report updated; PR template added.

## Upgrade notes
- If you use Fish in non-interactive setups, review your `FISH_LANGUAGE_CHOICE` usage (whitespace trimming + stricter validation).
- If you customized PAM handling previously, skim the updated `setup.sh` PAM section before re-running the installer.
- As always: consider running `setup.sh` in dry-run first to review planned actions.

## Full changelog
- Compare: `v0.5.0...v0.6.0` (tag this release as `v0.6.0` to enable the GitHub compare link)


---

---

## [0.5.0] - 2025-10-22

# Release Notes

This release is a big step forward for the **TUI installer** and overall setup reliability (dry-run, non-interactive flows, monitor/wallpaper handling, and theming).

## Highlights
- **TUI installer**
  - Added a full install flow with sections, progress/log output, and improved layout/theming.
  - Added monitor setup wizard + visual indicators.
  - Multiple fixes for scrolling, input handling, and install output stability.
  - Keybind help view and improved interaction patterns (including hidden password input).
- **Setup script improvements**
  - Added a **dry-run** option.
  - Improved package verification/auto-install logic and base-devel checks.
  - Better non-interactive behavior (language, wallpaper dir, monitor configuration).
  - Improved wallpaper/monitor detection and runtime-config preference.
  - Fixes for SDDM setup + Hyprlock wallpaper edge cases (incl. AUR installs).
- **Dotfiles / theming**
  - Added KDE theming support (`kdeglobals`) and improved Dolphin theming.
  - Waybar updates (new update button/script, icon/style tweaks, brightness handling improvements, weather tweaks).
  - Fish shell language/env fixes.
- **Docs & examples**
  - README refreshed multiple times and new example screenshots added.

## Notable changes (since v0.4.0)
- Added `Cargo.toml`/`Cargo.lock` and introduced the Rust-based TUI (`src/main.rs`).
- `setup.sh`: non-interactive install improvements + package verification hardening + dry-run support.
- Waybar: added update module/script and refined styles.

## Upgrade notes
- If you previously relied on the old shell-only workflow, review the new TUI flow and its options.
- For automated installs, check your non-interactive settings (language choice, wallpaper directory, monitor config).

## Full changelog
- Compare: `v0.4.0...v0.5.0`



---

## [0.4.0] - 2025-06-04

# Release Notes

## Recent Updates and Fixes

### System Updates and Maintenance
- Improved Arch Linux mirror handling with reflector integration
- Enhanced package management with better error handling
- Added support for Arch Linux specific configurations
- Added local Arch wiki documentation for better reference

### Hyprland Configuration
- Enhanced environment variable handling
- Added better error reporting for failed installations
- Fixed monitor setup issues for better display configuration
- Added brightness control functionality
- Implemented clipboard management with fzf search integration

### Shell and Theme Improvements
- Refactored Fish Shell configuration
- Added GTK and QT application theming support
- Implemented Simple SDDM theme for better login experience

### Notification and System Controls
- Replaced Dunst with SwayNC notification center
- Added Bluetooth toggle functionality (keybind and waybar integration)
- Added startup check for autostart applications on session start

### User Interface Enhancements
- Added Keybinds GUI for simple keybind overview
- Updated README with comprehensive documentation
- Added new example pictures for better visualization

### Testing
- Successfully tested on Arch Linux
- Verified package installations and updates
- Confirmed system configuration compatibility
- Tested mirror synchronization and package management

### Requirements
- Arch Linux or Arch-based distribution
- Base system with standard Arch Linux installation
- Sufficient disk space (minimum 10GB recommended)

### Installation
Please refer to the main README.md for detailed installation instructions.

### Support
For issues and support, please check the repository's issue tracker or refer to the CONTRIBUTING.md file.

**Full Changelog**: https://github.com/Firstp1ck/Hyprland_Simple_Setup/compare/v0.3.1...v0.4.0

---

## [0.3.1] - 2025-05-28

# Release Notes

## Recent Updates and Fixes

### System Updates and Maintenance
- Improved Arch Linux mirror handling with reflector integration
- Enhanced package management with better error handling
- Added support for Arch Linux specific configurations

### Hyprland Configuration
- Enhanced environment variable handling
- Added better error reporting for failed installations

### Testing
- Successfully tested on Arch Linux
- Verified package installations and updates
- Confirmed system configuration compatibility
- Tested mirror synchronization and package management

### Requirements
- Arch Linux or Arch-based distribution
- Base system with standard Arch Linux installation
- Sufficient disk space (minimum 10GB recommended)

### Installation
Please refer to the main README.md for detailed installation instructions.

### Support
For issues and support, please check the repository's issue tracker or refer to the CONTRIBUTING.md file.

**Full Changelog**: https://github.com/Firstp1ck/Hyprland_Simple_Setup/compare/v0.3.0...v0.3.1

---

## [0.3.0] - 2025-05-19

# Release Notes

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

---

## [0.2.0] - 2025-05-07

# Release Notes

## Version 0.2.0 (2024-05-07)

### Major Changes in Setup Script vs. Documentation

#### Package Management Updates
- Added new core Hyprland packages not listed in README:
  - `hyprcursor`
  - `wl-clipboard` and `wl-clip-persist`
  - `hyprgraphics`
  - `hyprland-qtutils`
  - `hyprland-qt-support`
  - `hyprwayland-scanner`

#### New Development Tools
- Added additional development tools:
  - `fd` - Modern alternative to `find`
  - `fzf` - Fuzzy finder
  - `nvim` - Neovim editor
  - `git` - Version control

#### Enhanced Terminal Experience
- Added new terminal utilities:
  - `khal` - Calendar application
  - `zoxide` - Smarter cd command
  - `lshw` - Hardware lister
  - `fastfetch` - System information tool
  - `tldr` - Simplified man pages
  - `konsole` - KDE terminal emulator

#### System Integration
- Added new system utilities:
  - `ntfs-3g` - NTFS filesystem support
  - `firewalld` - Firewall management
  - `qalculate-gtk` - Advanced calculator

#### AUR Package Updates
- Added new AUR packages not documented in README:
  - `lsplug` - Plugin manager
  - `waypaper-git` - Wallpaper manager
  - `pyprland` - Python bindings
  - `wl-clipboard-history-git` - Clipboard manager
  - `hyprsunset` - Night light feature
  - `github-desktop-bin` - GitHub desktop client

### Configuration Improvements

#### Language Configuration
- Added interactive language selection during setup:
  - de_CH (Swiss German)
  - de_DE (German)
  - en_US (US English)
- Automated fish shell language configuration

#### Monitor Configuration
- Added interactive monitor configuration:
  - Resolution prompt per monitor
  - Refresh rate customization
  - Automatic configuration file generation

#### Backup Management
- Added automatic backup creation for configuration files
- Implemented timestamp-based backup naming

### Script Enhancements

#### Error Handling
- Added comprehensive error checking
- Implemented dependency validation
- Added wallpaper directory validation

#### User Experience
- Added colored output messages
- Interactive prompts for critical decisions
- Progress feedback during installation

**Full Changelog**: https://github.com/Firstp1ck/Hyprland_Simple_Setup/compare/v0.1.0...v0.2.0

---

## [0.1.0] - 2025-03-27

# Release Notes

- **New Features:**
  - Initial release of the Hyprland Simple Setup.
  - Includes basic configuration for Hyprland, hyprlock, and other essential utilities.
  - Sample wallpapers and example images provided.

- **Improvements:**
  - Optimized startup scripts for faster configuration.
  - Enhanced documentation covering installation, customization, and troubleshooting.

- **Bug Fixes:**
  - Fixed minor issues with monitor configuration.
  - Resolved compatibility problems in hyprland.conf.

## Additional Information

For detailed documentation, please refer to the [README.md](README.md) file.  
For further troubleshooting and feedback, open an issue via [GitHub Issues](https://github.com/yourusername/Hyprland_Simple_Setup/issues).

Enjoy your new Hyprland experience!

