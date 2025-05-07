# Release Notes

## Version 0.2.0 (2024-05-07)

### Major Changes in Setup

#### Package Management Updates
- Added new core Hyprland packages:
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
- Added new AUR packages:
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