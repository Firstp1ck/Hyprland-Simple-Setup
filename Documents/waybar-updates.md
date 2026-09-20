# Waybar system updates

The repository includes its own updater at `dotfiles/.config/waybar/scripts/system_update.sh`. The update button works after setup without another checkout or an environment variable.

## Actions

- **Update:** the left-click confirmation opens your selected terminal. The updater runs `paru -Syu`, or `yay -Syu` if Paru is unavailable. Helpers run as your normal user and request elevated access themselves.
- **Update without AUR:** runs `sudo pacman -Syu`, regardless of installed AUR helpers.
- **No AUR helper:** Update runs `sudo pacman -Syu` and explicitly reports that AUR updates were skipped. It does not install a helper automatically.
- **Check:** checks repository updates and uses the same Paru-then-Yay preference for AUR checks.
- **Show log:** opens the latest update session in the bundled updater's log.

Normal package-manager confirmations remain enabled. The updater does not change mirrors, remove packages/cache, update firmware, or run the complete setup process. Read distribution announcements and review package-manager prompts before accepting an upgrade. A failed update retains its exit status; it does not silently try another helper.

The existing user-service launcher prevents duplicate launches from the menu. Interactive update terminals remain open after success or failure until Enter is pressed.

## Logs and optional overrides

The default log is:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/hyprland-simple-setup/system-update.log
```

`WAYBAR_UPDATE_LOG_FILE` overrides the log location. The launcher forwards the resolved path to its user service so Update and Show log agree.

`WAYBAR_UPDATE_SCRIPT` is now optional. If set, it must point to an executable supporting both `--function update_arch` and `--function update_arch_without_aur`. Leave it unset to use the bundled script. A custom updater is responsible for its own logging; the launcher supplies `WAYBAR_UPDATE_LOG_FILE` to it.

Setup's managed-file synchronization includes the updater, launcher, confirmation wrapper and maintenance dispatcher, so rerunning setup can repair an existing dotfiles copy. This repository change does not modify an already-running desktop by itself.

## Verification

`bash tests/run.sh tests/shell/waybar_updates.sh` runs the updater, launcher and maintenance tests with fixture homes and a closed mock PATH. No real package manager, sudo, service manager or compositor is called. The suite also checks existing-dotfiles synchronization and dry-run preservation.
