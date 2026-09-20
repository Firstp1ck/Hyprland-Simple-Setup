## Release v0.7.0

Changes since `v0.6.0`.

## Highlights

- Choose applications across 17 groups, with primary apps used by desktop shortcuts and controls.
- Track setup runs with separate logs, backups, and scoped configuration rollback.
- Use the updated Lua-based Hyprland configuration and expanded Waybar maintenance menu.
- Scroll live installer output without interrupting setup.

## Full Change Summary

### Installation and application choices

- Added a curl-friendly bootstrap installer with repository, revision, and destination options.
- Added independent choices for browsers, shells, terminals, editors, file managers, launchers, notifications, bars, docks, calendars, and desktop controls. Supported groups allow multiple selections and a primary app.
- Added tmux, Zellij, and Herdr multiplexer choices, plus optional terminal file managers. Ctrl+Y opens the primary multiplexer; Super+E opens the graphical file manager.
- Added optional Pi, OpenCode, Claude Code, Codex CLI, and Cursor CLI installation. Authentication remains manual.
- Added Pacsea and usrgrp-manager to the package catalog and corrected package names and sources.
- Shell language settings now apply to selected Bash, Fish, and Zsh installations.

### Installer reliability and interface

- Added `--list-runs` and `--rollback <run-id>`, with per-run manifests, backups, and file-change checks before rollback.
- Added atomic managed-file updates and stricter failure reporting for configuration writes, run metadata, and rollback.
- Application choosers now show descriptions, support scrolling, and prevent installation with empty required groups.
- Live output supports mouse and keyboard scrolling, a scrollbar, compact/detail views, and a Follow control. Full output is saved separately.

### Desktop and Waybar

- Desktop shortcuts, scratchpads, and Waybar actions now follow selected applications through generated `roles.json` metadata.
- Added a bundled system updater with AUR and repository-only modes, confirmation, duplicate-launch prevention, and logs. Separate menu actions cover firmware, `.pacnew` review, and package-cache cleanup.
- Updated temperature reporting, brightness controls, and the keybinding viewer for Lua configuration.
- Improved wallpaper startup diagnostics and retries, including wallpaper updates for active monitors.
- Startup checks now focus on persistent services and use session-specific readiness markers. An optional troubleshooting action shares diagnostics with the primary coding agent only after a click.

### Tests and maintenance

- Added Rust, shell, Python, and package-registry regression coverage, with separate Rust, shell, and JSON CI jobs.

## Breaking Changes

- The shipped Hyprland configuration now uses `hyprland.lua` and Lua modules. Retained `.conf` files are backups, not the active configuration. Monitor and wallpaper helpers now use `sources_specific/monitors.lua` and `change_wallpaper.lua`.
- Setup logs moved from `~/Hyprland-Simple-Setup.log` to `${XDG_STATE_HOME:-$HOME/.local/state}/hyprland-simple-setup/runs/<run-id>/log`. Update scripts that read the old path.

## Upgrade Notes

- Back up custom dotfiles and port existing Hyprland settings to the Lua files before switching. Rerunning setup refreshes managed helpers but does not replace an existing `~/dotfiles` tree or automatically convert all custom configuration.
- Review Applications before installing. Herdr is the default multiplexer, and Pi is selected by default under optional coding agents. Choose None to skip agent installation. Changing selections does not uninstall existing apps.
- Custom multiplexer bindings should execute `apps.multiplex` or `$multiplex` directly, without another terminal wrapper. Setup migrates only recognized stock bindings.
- For unattended installs, use `SHELL_LANGUAGE_CHOICE_OVERRIDE`; the older `FISH_LANGUAGE_CHOICE_OVERRIDE` remains a fallback.
- Rollback restores only files recorded in a run's manifest. It does not undo package installations, service changes, Stow links, or entire directory copies.
- Clicking agent troubleshooting shares diagnostic excerpts with the selected agent and its provider. Credential redaction is best-effort, not a secrecy guarantee.
