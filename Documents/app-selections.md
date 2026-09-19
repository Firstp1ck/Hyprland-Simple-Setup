# Application selections

The setup UI manages 13 independent application roles. Browser, shell, terminal, TUI editor, GUI editor, and Bluetooth may contain multiple installed choices; each nonempty role has one primary choice used by shortcuts and integrations. Notifications, bar, calendar, network, audio, launcher, and dock are single-choice roles. GUI editor and dock may be set to **None**.

## TUI controls

Open **Applications** with Enter from the main preflight window. The submenu lists all 13 groups and their current selections, with a short explanation of the highlighted app type below the list. Use Up/Down to choose a group, then Enter to open its package chooser.

Each package shows a short description explaining its distinguishing features, its package source, and a TUI label when it runs in a terminal. The chooser grows to fit all entries and their wrapped descriptions when space permits, including optional None. On smaller terminals, Up/Down scrolls the choices; Home/End jumps to the first/last choice and Page Up/Down moves five choices. The position indicator shows where you are in the list.

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
ROLE_DOCK= \
ROLE_DOCK_PACKAGES= \
./setup.sh
```

Unset variables use the catalog default. When `setup.sh` is run interactively without role variables, it prompts for numbered choices; multiple roles accept several numbers and then a primary choice, while optional roles expose `0) None`. A scalar without a list remains compatible with older callers and selects that one package. Empty values disable only optional roles. Package names are validated literally; shell expressions are never evaluated.

## Runtime schema

The installer writes `~/.config/hypr/roles.json` with schema version 2:

- `.roles.<name>` contains the primary option metadata, or `null` for a disabled optional role.
- `.selected.<name>` contains metadata for every selected member.
- command arguments remain JSON arrays and are passed as separate argv fields.

Scripts use `role_exec.sh` to launch the primary application. Terminal applications are wrapped by the selected terminal. If the GUI editor is disabled, explicit editor actions open the TUI editor in that terminal; it is not autostarted.

## Desktop controls

Hyprland and Waybar actions use the selected calendar, audio, Bluetooth, network, launcher, notification provider, bar, and optional dock. Selecting `nwg-panel` for both bar and dock uses separate `bar` and `dock` configurations. The notification selection also writes a user D-Bus service override for `org.freedesktop.Notifications`.

Konsole uses fixed `hss-*` tab titles and separate processes for role windows, since it has no application-ID flag. The installer configures title matching for its scratchpads; other terminals retain class-based matching. GUI calendar and audio buttons use native application classes with the existing focus/float helper.

When Waybar is selected, its role action updates preserve JSONC comments, unrelated settings, and trailing-comma syntax. Selecting another bar leaves the Waybar configuration unchanged. Toggling an nwg-panel bar targets its `bar` profile without stopping its `dock` profile.

Changing a selection and rerunning setup rewrites the generated metadata and role-managed lines atomically. It does not uninstall previously installed alternatives. NetworkManager, BlueZ, and BlueZ utilities remain installed as required backends regardless of UI choice.

## Limitations

Live compatibility still depends on each application and compositor version. Some notification providers expose fewer center or do-not-disturb controls than SwayNC. Dedicated `nwg-dock-hyprland` uses its upstream defaults; the repository only supplies named `nwg-panel` bar/dock profiles.
