# Release v0.5.0

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

