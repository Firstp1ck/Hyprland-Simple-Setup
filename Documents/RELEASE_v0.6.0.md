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

