# Application selections

The setup UI manages 15 independent application roles. Browser, shell, terminal, multiplexer, TUI editor, GUI editor, and coding agents may contain multiple installed choices; each nonempty role has one primary choice used by shortcuts and integrations. The required multiplexer role defaults to Herdr and also offers tmux and Zellij. Notifications, bar, calendar, Bluetooth, network, audio, launcher, and dock are single-choice roles. GUI editor, dock, and coding agents may be set to **None**.

## TUI controls

Open **Applications** with Enter from the main preflight window. The submenu lists all 15 groups and their current selections, with a short explanation of the highlighted app type below the list. Use Up/Down to choose a group, then Enter to open its package chooser.

The package chooser has two columns: app names on the left and wrapped descriptions on the right. The app-type explanation is in its own titled frame above the choices, separated by a blank row. Names retain selection markers, package sources and TUI labels. Row heights accommodate wrapping in either column, including optional None. The chooser grows to fit all entries when space permits; very short windows prioritize the focused row over the description panel. On smaller terminals, Up/Down scrolls the choices; Home/End jumps to the first/last choice and Page Up/Down moves five choices. The position indicator shows where you are in the list.

Use Space to select or clear an option. Single-choice groups replace the previous choice. In multi-choice groups, press `p` on a selected app to make it primary. Enter, Escape, or `q` returns to the group list; Escape or `q` from that list returns to the main window. Selections and the focused group are retained.

Required groups may be temporarily empty while editing, but installation cannot start until all have a selection. Optional groups have a None entry.

## Installer environment

For each role, the installer accepts two variables:

- `ROLE_<NAME>`: the primary package.
- `ROLE_<NAME>_PACKAGES`: a space-separated membership list.

For example:

```sh
ROLE_BROWSER=firefox \
ROLE_BROWSER_PACKAGES='firefox chromium' \
ROLE_MULTIPLEXER=zellij \
ROLE_MULTIPLEXER_PACKAGES='tmux zellij' \
ROLE_DOCK= \
ROLE_DOCK_PACKAGES= \
ROLE_AGENT= \
ROLE_AGENT_PACKAGES= \
./setup.sh
```

Unset variables use the catalog default. When `setup.sh` is run interactively without role variables, it prompts for numbered choices; multiple roles accept several numbers and then a primary choice, while optional roles expose `0) None`. A scalar without a list remains compatible with older callers and selects that one package. Empty values disable only optional roles. Package names are validated literally; shell expressions are never evaluated.

## Runtime schema

The installer writes `~/.config/hypr/roles.json` with schema version 2:

- `.roles.<name>` contains the primary option metadata, or `null` for a disabled optional role.
- `.selected.<name>` contains metadata for every selected member.
- `.agent_executables` maps selected agent IDs to verified absolute executable paths found after the installer stage.
- command arguments remain JSON arrays and are passed as separate argv fields.

Scripts use `role_exec.sh` to launch the primary application. Terminal applications are wrapped by the selected terminal. The preferred-multiplexer shortcut runs the primary multiplexer once through that terminal, preserving each argument literally rather than nesting another terminal command. If the GUI editor is disabled, explicit editor actions open the TUI editor in that terminal; it is not autostarted.

The generated `apps.multiplex` and `$multiplex` values are complete terminal actions. Setup migrates the exact former stock shortcuts to execute them directly. Custom bindings are not rewritten: if they prepend a terminal wrapper to either variable, remove that wrapper to avoid nesting terminals.

## Desktop controls

Hyprland and Waybar actions use the selected calendar, audio, Bluetooth, network, launcher, notification provider, bar, and optional dock. Selecting `nwg-panel` for both bar and dock combines the `bar` and `dock` profiles into one generated `hss-panels` configuration and one process; nwg-panel replaces other running instances. The notification selection also writes a user D-Bus service override for `org.freedesktop.Notifications`.

Konsole uses fixed `hss-*` tab titles and separate processes for role windows, since it has no application-ID flag. The installer configures title matching for its scratchpads; other terminals retain class-based matching. GUI calendar and audio buttons use native application classes with the existing focus/float helper.

When Waybar is selected, its role action updates preserve JSONC comments, unrelated settings, and trailing-comma syntax. Selecting another bar leaves the Waybar configuration unchanged. Toggling an nwg-panel bar sends its configured real-time signal to hide or show only the bar, without stopping the shared dock.

Changing a selection and rerunning setup rewrites the generated metadata and role-managed lines atomically. Zellij's Alacritty workspace example is enabled only when Alacritty and primary Zellij are selected; Kitty keeps its existing dashboard session independently of the multiplexer choice. Multiplexers remain on-demand applications and are not startup-health processes. Rerunning setup does not uninstall previously installed alternatives. Coding-agent choices use the fixed official installer contract described in [Coding agents](agents.md); None disables agent integration without uninstalling an existing CLI. NetworkManager, BlueZ, and BlueZ utilities remain installed as required backends regardless of UI choice.

## Startup errors

All launcher entry points use `menu_exec.sh`; Bemenu explicitly installs and selects its Wayland renderer. Launcher and panel stderr is appended under `${XDG_STATE_HOME:-$HOME/.local/state}/hyprland-simple-setup/apps/`:

- `launcher.log` for Wofi, Rofi, Fuzzel, Bemenu or tofi.
- `bar.log` and `dock.log` for the selected panel startup paths.

These logs help distinguish missing dependencies, invalid settings and compositor errors. The launcher itself opens on demand; it is not a persistent autostart process. Rerunning setup refreshes the repo-owned helpers and panel profiles in existing dotfiles.

## Limitations

Live compatibility still depends on each application and compositor version. Some notification providers expose fewer center or do-not-disturb controls than SwayNC. Dedicated `nwg-dock-hyprland` uses its upstream defaults; the repository only supplies named `nwg-panel` bar/dock profiles.
