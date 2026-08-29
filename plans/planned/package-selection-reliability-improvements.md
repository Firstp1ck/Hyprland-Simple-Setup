# Package-selection and setup-reliability improvements

Status: implementation in progress (verified and unblocked on 2026-08-29)
Classification: complex
Source baseline revision: `main` at `7105e24` (the verified plan-only worktree modification is allowed before WS-1)
Verified against: Hyprland 0.56.2 (`extra/hyprland 0.56.2-1`), pacman sync database and AUR RPC as of 2026-08-29
Integration owner: parent Pi session or repository maintainer
Planned report: [`reports/package-selection-reliability-improvements.html`](../../reports/package-selection-reliability-improvements.html) (directory does not exist yet; create it in Wave 5)

## Goal

Implement the useful package-selection and reliability ideas from `feat/diff-package-selections` and `robustness-improvements` without merging either branch and without migrating Hyprland configuration to Lua.

## What was verified before this revision

Every claim below was checked against the working tree or a live command. Later workers can rely on these without re-deriving them. Where a claim in the first draft was wrong or imprecise, the correction is listed in the next section.

1. The reference commits exist: `9de0076` and `ff8cd5b` on `feat/diff-package-selections`, `ecaacac` on `robustness-improvements`. At the implementation base (`7105e24`), `feat/diff-package-selections` is 2 commits ahead and 1 behind; `robustness-improvements` is 1 ahead and 11 behind. Both remain read-only references.
2. A fixture built from `dotfiles/.config/hypr` with `sources_example` copied to `sources` fails `Hyprland --verify-config` on 0.56.2 with exactly three errors: `dwindle:pseudotile` (look_and_feel.conf line 96), `misc:vfr` (line 105), and the `togglesplit` dispatcher (keybindings.conf line 34). The verifier exits 1 on errors and 0 when clean. Without `XDG_RUNTIME_DIR` it tries to write `/hyprland.log`, so tests must set it.
3. The same verifier accepts `bind = SUPER, N, layoutmsg, togglesplit`, the `pseudo` dispatcher, a `dwindle` block without `pseudotile`, and a `misc` block without `vfr`. The Hyprland wiki returned HTTP 403 to automated fetches, so the replacements were validated empirically rather than from documentation.
4. Package availability (`pacman -Si`, AUR RPC v5):
   - `hyprshot` and `hyprsunset` are in `extra`; `packages.json` and the `aur_extras` array in `setup.sh` list both as AUR.
   - `input-remapper-2` exists nowhere. `input-remapper` 2.2.1 is in the AUR.
   - `rofi-wayland` no longer exists. `rofi` in `extra` supports Wayland.
   - `nvim` is not a package. `pacman -S nvim` works only because `neovim` provides it; `pacman -Si nvim` fails, and so would any exact-name check.
   - `ghostty`, `zed`, `helix`, `fuzzel`, `bemenu`, `chromium`, `firefox`, `zsh`, `vivaldi`, `neovim`, `rofi` are in `extra`. `zen-browser-bin`, `brave-bin`, `cursor-bin`, `visual-studio-code-bin` are in the AUR.
   - `xwaylandvideobridge` is flagged out of date on the AUR. Not this plan's problem, but package verification must report it as a failed install rather than a missing package if the build fails.
5. `setup.sh` on `main` has no `set -e`, no `trap`, no `flock`, no `mktemp`, and no sudo keepalive. The keepalive, `eval`-based cleanup, `rm -rf` on registered paths, whole-`~/.config` rollback (`mv ~/.config ~/.config.pre-rollback.*`), and resume state all live only in `ecaacac`.
6. `setup.sh` runs every command as a string through `bash -c` inside `execute_command()`. When `SUDO_PASSWORD` is set it wraps the string in a shell function that pipes the password into `sudo -S`. No command is passed as an argument array today.
7. `setup.sh` keeps its own `hyprland_packages` array (line 1899) and `aur_extras` array (line 2203). They already drift from `packages.json`: the shell array still contains `archinstall` (five times), `hyprland-guiutils`, `hyprutils`, `qalculate-gtk`, and lacks `brightnessctl`, `jq`, `libnotify`, `playerctl`, `python`, `python-requests`, `reflector`. The arrays are only used when `SELECTED_*` env vars are empty (running `setup.sh` without the TUI).
8. The TUI passes `TERMINAL_CHOICE_OVERRIDE` and `FISH_LANGUAGE_CHOICE_OVERRIDE` but never `BROWSER_CHOICE_OVERRIDE`. `setup.sh` therefore always configures zen-browser for TUI runs, even when the user deselects `zen-browser-bin` and selects `vivaldi`.
9. `src/main.rs` has zero `#[test]` functions. `.github/workflows/rust.yml` runs `cargo build` and `cargo test` only. `cargo fmt --check` and `cargo clippy --locked --all-targets -- -D warnings` both pass on `main`. `shellcheck -x setup.sh install.sh` fails with 5 findings (`install.sh` line 4 SC2034; `setup.sh` SC2116 at lines 596 and 2885, SC2126 at lines 935 and 936). `bash -n` passes.
10. `main.rs` locates `packages.json` by trying `./packages.json`, `../packages.json`, and two more parent levels relative to the current directory. If none match, the package selector silently shows nothing. The add-packages dialog runs `bash -lc "pacman -Si -- <name>"` with the user-typed name interpolated unquoted.
11. `ff8cd5b` derives roles in shell from package presence with a fixed priority (`resolve_selected_shell`: fish, then zsh, then bash). Selecting both fish and zsh silently configures fish. Its Rust side hardcodes eight choice groups, including `rofi-wayland`, `nwg-panel`, `yambar`, `mako`, `dunst`, in `required_choice_groups()`, separate from the JSON.
12. `configure_fish()` runs `sudo chsh -s /usr/bin/fish` with no username, which changes root's shell.
13. `verify_installed_packages()` does not check the selected set. It reads the newest `~/user_installed_packages_*.txt` and `~/aur_packages_*.txt`, generates them from `pacman -Qqet` if absent, and checks those with `pacman -Qi`. It runs from `print_status_summary()`, not from `main()` directly.
14. Dry-run returns early from `update_configs`, `configure_terminal`, `configure_browser`, and `configure_hypr_autostart_optional_extras` with a one-line description each. It reports no file paths.
15. Stow layout: `setup.sh` copies `dotfiles/` to `~/dotfiles`, copies `sources_example` to `sources`, then runs `Start_stow_solve.sh` so `~/.config/...` becomes symlinks into `~/dotfiles`. Config edits target `~/dotfiles/...` and some use `sed -i --follow-symlinks` on runtime paths. `~/dotfiles` is not refreshed when it already exists.
16. Consumers that hardcode a role today (all verified by grep):
    - `hypr/sources_example/app_variables.conf`: `$terminal`, `$menu` (wofi with a wofi-only style flag), `$browser`, `$editor`
    - `hypr/sources_example/autostart.conf`: `$editor` on workspace 1, `$browser` on workspace 2
    - `hypr/sources_example/keybindings.conf`: `pkill wofi || $menu`, `swaync-client`, `$terminal -e`
    - `hypr/sources_example/windows_and_workspaces.conf`: browser rule injection marker (`# Workspace 2`), `alacritty.term-top` float rule, `alacritty` + `Notes` float rule, `layerrule ... namespace wofi`
    - `fish/conf.d/01-env.fish`: `EDITOR nvim`, `TERMINAL alacritty`, `BROWSER zen`
    - `fish/conf.d/02-aliases.fish`: `vi` and `vim` aliased to `nvim`
    - `waybar/config.jsonc`: launcher `on-click` runs wofi
    - `waybar/scripts/clipboard.sh`: `alacritty --class alacritty-clipboard`
    - `hypr/scripts/repos_wofi.sh`: `terminal="alacritty"`, `nvim`, `wofi --dmenu`
    - `hypr/scripts/float_calendar.sh`: `alacritty -e calcurse`
    - `hypr/scripts/notes.sh`: `nvim`
    - `hypr/scripts/toggle_floating.sh`: `alacritty)` case arm
    - `hypr/scripts/term_exec.sh`: reads `$TERMINAL`, handles kitty and alacritty explicitly, falls back to `<term> -e`
    - `pypr/config.toml`: scratchpad `alacritty --class=alacritty.term-top`
    - `setup.sh configure_environment()`: installs neovim unconditionally and sets `EDITOR=nvim`
    - `setup.sh configure_fish()`: installs fzf integration for fish only

## Corrections to the first draft

- "Rofi Wayland" in the launcher role is now `rofi`. The `rofi-wayland` package is gone.
- The TUI editor entry is `neovim`, not `nvim`. `packages.json` must use real package names because package verification will check by name.
- The old shell code inferred roles by fixed priority, not "arbitrary ordering". The criterion now says what actually matters: no inference from package lists at all.
- "Stop sudo keepalive processes from an exit trap" assumed a keepalive exists. It does not. WS-4 introduces one (needed once the whole-`.config` `cp -r` and long AUR builds run under `sudo -n`), and the trap requirement applies to the new process.
- Package verification must check the selected set, not the leftover `~/user_installed_packages_*` files, and must use a provides-aware query.
- The non-goal "No whole-`~/.config` backup or restore" contradicted current behavior, which already copies `~/.config`. The pre-run copy stays for now; only whole-tree restore is out. See the decision record.
- `shellcheck` cannot be a hard gate until the 5 baseline findings are fixed. WS-3 fixes them because it is the first workstream that edits `setup.sh`.
- The acceptance check list now includes the shell test runner and the config fixture, and says what to do when Hyprland is not installed.

## Why this is complex

The work crosses `packages.json`, the Rust TUI, `setup.sh`, Hyprland configuration templates, fifteen dotfiles consumers, package-manager behavior, rollback semantics, and a new test harness. Package selection and reliability both modify `setup.sh`, so those workstreams run one after the other with one integrator.

## Source material

Treat the old branches as read-only references:

- `feat/diff-package-selections` at `9de0076` (feature commit `ff8cd5b`). Worth borrowing: the required-package locking UI in the package selector, the `[!]` marker, and the list of browsers, terminals, shells, and editors. Not worth borrowing: role inference in shell, hardcoded `required_choice_groups()` in Rust, taskbar and notification groups.
- `robustness-improvements` at `ecaacac`. Worth borrowing: the shape of `acquire_lock`, `atomic_file_edit`, `setup_sudo_keepalive`, `verify_copy`. Not worth borrowing: `eval` in cleanup, `rm -rf` on registered paths, whole-`.config` rollback, the resume state file.

Do not merge or rebase either branch into the implementation branch. Do not copy the robustness commit wholesale.

## Success criteria

1. Required base packages cannot be deselected in the TUI. They render with a lock marker and Space does nothing on them.
2. Every exclusive application role has exactly one selected package before setup can start. The TUI blocks the start button with a message naming the role until this holds.
3. `packages.json` is the only registry for role membership, package source (repo or AUR), required status, launch command, window class, and default. Rust deserializes it. `setup.sh` reads it with `jq`. Neither keeps a second list. The `hyprland_packages` and `aur_extras` arrays in `setup.sh` are deleted.
4. The TUI passes one `ROLE_<NAME>` env var per role holding a package name. `setup.sh` never derives a role from `SELECTED_*` package lists.
5. Every exposed alternative has a complete consumer path in the retained `.conf` files and scripts (the list in verified fact 16). Unsupported alternatives are not shown as role choices.
6. Package names and repository classifications match current Arch/AUR availability: `input-remapper` replaces `input-remapper-2`, `neovim` replaces `nvim`, `rofi` is the rofi entry, and `hyprshot` and `hyprsunset` move to the repo list.
7. Shell selection changes the invoking user's shell. `chsh` receives an explicit username and a path that appears in `/etc/shells`.
8. A second concurrent `setup.sh` exits with a message naming the holder's PID and start time. Temporary files are removed on exit and on SIGINT/SIGTERM. The sudo keepalive process is gone after exit. Every setup-managed configuration-file edit is atomic.
9. Rollback restores only files listed in a recorded run's manifest. It never moves or replaces `~/.config` or `~/dotfiles` as a whole.
10. No persistent state can make a later independent run skip work. Two consecutive runs with different role choices produce the second choice.
11. `--dry-run` performs no filesystem writes outside the run's own state directory and prints every path it would create or modify, with the reason.
12. The installed `.conf` layout passes `Hyprland --verify-config` on 0.56.2. No `hyprland.lua` and no Lua fragments.
13. `cargo fmt --check`, `cargo clippy -D warnings`, `cargo test`, `jq -e`, `bash -n`, `shellcheck`, the shell test runner, and the config fixture all pass on the integrated result.

## Scope

### Package selection

#### `packages.json` schema

Keep the existing top-level keys so the current TUI keeps working during WS-1. Add two keys:

```json
{
  "hyprland_packages": { "...unchanged category lists..." : [] },
  "aur_packages": { "...unchanged category lists..." : [] },
  "package_descriptions": { "...unchanged..." : "" },
  "required": {
    "pacman": [
      "hyprland", "xdg-desktop-portal-hyprland", "xdg-desktop-portal-gtk",
      "waybar", "hyprpaper", "hyprlock", "hypridle", "hyprpolkitagent",
      "wl-clipboard", "stow", "jq", "pipewire", "pipewire-pulse",
      "wireplumber", "swaync", "brightnessctl", "playerctl", "libnotify",
      "python", "python-requests", "hyprshot"
    ],
    "aur": []
  },
  "roles": {
    "browser": {
      "label": "Browser",
      "default": "zen-browser-bin",
      "options": [
        { "package": "zen-browser-bin", "source": "aur", "executable": "zen-browser", "args": [], "class": "zen" },
        { "package": "vivaldi", "source": "pacman", "executable": "vivaldi-stable", "args": ["--ozone-platform=wayland", "--enable-features=UseOzonePlatform"], "class": "vivaldi-stable", "extra_packages": ["vivaldi-ffmpeg-codecs"] },
        { "package": "firefox", "source": "pacman", "executable": "firefox", "args": [], "class": "firefox" },
        { "package": "chromium", "source": "pacman", "executable": "chromium", "args": [], "class": "chromium" },
        { "package": "brave-bin", "source": "aur", "executable": "brave", "args": [], "class": "brave-browser" }
      ]
    },
    "terminal": {
      "label": "Terminal",
      "default": "kitty",
      "options": [
        { "package": "kitty", "source": "pacman", "executable": "kitty", "args": [], "class": "kitty" },
        { "package": "alacritty", "source": "pacman", "executable": "alacritty", "args": [], "class": "Alacritty" },
        { "package": "ghostty", "source": "pacman", "executable": "ghostty", "args": [], "class": "com.mitchellh.ghostty" }
      ]
    },
    "shell": {
      "label": "Shell",
      "default": "fish",
      "options": [
        { "package": "fish", "source": "pacman", "executable": "fish", "args": [], "shell_path": "/usr/bin/fish" },
        { "package": "bash", "source": "pacman", "executable": "bash", "args": [], "shell_path": "/bin/bash" },
        { "package": "zsh", "source": "pacman", "executable": "zsh", "args": [], "shell_path": "/usr/bin/zsh" }
      ]
    },
    "gui_editor": {
      "label": "GUI editor",
      "default": "visual-studio-code-bin",
      "options": [
        { "package": "visual-studio-code-bin", "source": "aur", "executable": "code", "args": ["--ozone-platform=wayland", "--enable-features=UseOzonePlatform"], "editor_bin": "code" },
        { "package": "cursor-bin", "source": "aur", "executable": "cursor", "args": ["--ozone-platform=wayland", "--enable-features=UseOzonePlatform"], "editor_bin": "cursor" },
        { "package": "zed", "source": "pacman", "executable": "zed", "args": [], "editor_bin": "zed" }
      ]
    },
    "tui_editor": {
      "label": "TUI editor",
      "default": "neovim",
      "options": [
        { "package": "neovim", "source": "pacman", "executable": "nvim", "args": [], "editor_bin": "nvim" },
        { "package": "helix", "source": "pacman", "executable": "hx", "args": [], "editor_bin": "hx" },
        { "package": "vim", "source": "pacman", "executable": "vim", "args": [], "editor_bin": "vim" },
        { "package": "nano", "source": "pacman", "executable": "nano", "args": [], "editor_bin": "nano" }
      ]
    },
    "launcher": {
      "label": "Launcher",
      "default": "wofi",
      "options": [
        { "package": "wofi", "source": "pacman", "executable": "wofi", "args": ["--show", "drun", "--style", "{HOME}/.config/wofi/menu.css"], "dmenu_executable": "wofi", "dmenu_args": ["--dmenu"], "process": "wofi", "namespace": "wofi" },
        { "package": "rofi", "source": "pacman", "executable": "rofi", "args": ["-show", "drun"], "dmenu_executable": "rofi", "dmenu_args": ["-dmenu"], "process": "rofi", "namespace": "rofi" },
        { "package": "fuzzel", "source": "pacman", "executable": "fuzzel", "args": [], "dmenu_executable": "fuzzel", "dmenu_args": ["--dmenu"], "process": "fuzzel", "namespace": "fuzzel" },
        { "package": "bemenu", "source": "pacman", "executable": "bemenu-run", "args": [], "dmenu_executable": "bemenu", "dmenu_args": [], "process": "bemenu", "namespace": "bemenu" }
      ]
    }
  }
}
```

All 22 option objects above are normative. Fields per option:

| Field | Required | Meaning |
| --- | --- | --- |
| `package` | yes | exact pacman or AUR package name; must match `^[a-z0-9@._+-]+$` |
| `source` | yes | `pacman` or `aur` |
| `executable` | yes | executable name only, matching `^[a-zA-Z0-9@._+/-]+$` |
| `args` | yes | JSON string array of fixed launch arguments; never a shell command string |
| `class` | browser and terminal only | default window class for workspace and float rules |
| `extra_packages` | no | packages installed alongside (`vivaldi-ffmpeg-codecs`) |
| `shell_path` | shell only | `/usr/bin/fish`, `/bin/bash`, `/usr/bin/zsh` |
| `editor_bin` | editors only | the `EDITOR` value (`nvim`, `hx`, `vim`, `nano`) or the GUI executable (`code`, `cursor`, `zed`) |
| `dmenu_executable` | launcher only | executable name for dmenu mode |
| `dmenu_args` | launcher only | JSON string array for dmenu-mode arguments (`["--dmenu"]`, `["-dmenu"]`, or `[]`) |
| `process` | launcher only | exact process name used to close an existing launcher before opening a new one |
| `namespace` | launcher only | layer-shell namespace used by the launcher rule |

Rules the schema test enforces:

- every role option package appears in exactly one of `hyprland_packages` or `aur_packages`, under the category matching its `source`;
- `default` is one of the role's options;
- required packages are not role options (a required package cannot be exclusive);
- no package appears in two roles;
- every `package` and `extra_packages` value matches the package-name regex;
- every option has non-empty `executable` and string-array `args`; role-specific fields in the table are present, values contain no control characters, and `{HOME}` is allowed only as a leading path token in an argument;
- executable, process, namespace, editor, and shell-path fields match their field-specific allowlist regexes; unknown fields and shell command strings are rejected.

Role option values the implementer must confirm before marking WS-3 done: browser and terminal window classes, including `brave-bin` (`brave-browser`), Chromium, Kitty, Alacritty, and Ghostty. Use `hyprctl clients -j` on a real session, or the `StartupWMClass` line in the package's `.desktop` file when no session is available, and record which source was used. GUI editor classes are out of scope because no retained consumer needs them.

The terminal wrapper owns terminal-specific CLI syntax. `term_exec.sh` accepts stable setup-owned app IDs for scratchpads and clipboard windows, then maps those to Kitty, Alacritty, or Ghostty arguments. Pyprland and window rules match those stable IDs instead of deriving custom classes from package names.

#### TUI behavior (`src/main.rs`)

- Load `packages.json` from the directory that contains the resolved `setup.sh` path (already known via `HYPR_SETUP_PATH` or the search list), not from the current directory. If loading or schema validation fails, show the error in the TUI and disable the start button. Silent empty lists are a bug.
- Add a role selector: one row per role, left/right cycles options, a role with no selected package shows a warning marker. Selecting a role option selects its package and deselects the other options' packages in the package list. Toggling a role option's package in the package list updates the role. The two views are one state.
- Required packages: locked in the package list, always present in `SELECTED_*`.
- Remove `terminal_choice: u8`, `sync_terminal_package_selection()`, and the numeric `TERMINAL_CHOICE_OVERRIDE` export. Keep `FISH_LANGUAGE_CHOICE_OVERRIDE`; it is a locale choice, not a role, and only applies when the shell role is fish.
- Export per run: `ROLE_BROWSER`, `ROLE_TERMINAL`, `ROLE_SHELL`, `ROLE_GUI_EDITOR`, `ROLE_TUI_EDITOR`, `ROLE_LAUNCHER`, each holding a package name. Always export both `SELECTED_PACMAN_PACKAGES` and `SELECTED_AUR_PACKAGES`, including an empty string when that side has no selections, plus `USER_ADDED_*`.
- Fix the add-packages classification call: run `pacman` and `yay` directly with `.arg("-Si").arg("--").arg(name)` instead of interpolating into `bash -lc`.
- Move the schema, validation, and selection logic into a `src/packages.rs` module so it can be unit tested without the TUI.

#### `setup.sh` role consumers

- On start, read every `ROLE_*` var. Validate each against the name regex and against the role's option list in `packages.json` (via `jq`). Reject unknown values with a hard failure that names the variable. When a `ROLE_*` var is absent and the run is interactive, present a numbered menu generated from the registry. When absent and non-interactive, use the registry default and print which default was applied.
- `jq` must be present before role parsing. Extend the existing `xdg-user-dirs` bootstrap pattern in `main()` to install `jq` the same way.
- Replace `get_terminal_choice`, `get_browser_choice`, `configure_terminal`, `configure_browser`, and the browser `case` blocks in `install_pacman_packages` and `install_aur_extras` with registry-driven equivalents. Role packages and their `extra_packages` go into the install list from the role choice; the `SELECTED_*` lists stay authoritative for everything else. Treat both variables present as an explicit selection, including empty values. Treat both absent as a standalone `setup.sh` run and install every non-role registry package plus only the chosen or default package for each role and its `extra_packages`. If exactly one variable is present, abort with a contract error instead of guessing. Never install all mutually exclusive alternatives.
- Generate `~/.config/hypr/roles.json` as the shell-independent runtime role-data source. It has exact shape `{ "schema_version": 1, "roles": { "browser": <selected option object>, "terminal": <selected option object>, "shell": <selected option object>, "gui_editor": <selected option object>, "tui_editor": <selected option object>, "launcher": <selected option object> } }`. Each selected object is copied from `packages.json` after validation. Stable queries are `.roles.<name>.package`, `.executable`, `.args[]?`, `.class`, `.editor_bin`, `.shell_path`, `.dmenu_executable`, `.dmenu_args[]?`, `.process`, and `.namespace` as applicable. Generation expands only a leading `{HOME}` token to the invoking user's absolute home; it does not evaluate arbitrary text. Hyprland and Waybar scripts read the file with `jq`; Fish variables mirror it for interactive shells. Scripts must not depend on Fish startup files.
- `configure_shell` (renamed from `configure_fish`): `sudo chsh -s "<shell_path>" -- "$USER"` where `$USER` is resolved as `${SUDO_USER:-$(id -un)}`. Before that, check `grep -qxF "<shell_path>" /etc/shells`. Run fzf integration only when the shell is fish. Bash is a normal `pacman` role option listed in the shell category; because it is part of `base`, `pacman -T bash` normally reports it satisfied and no install occurs.
- `configure_environment`: install the selected TUI editor rather than `neovim` unconditionally, set `EDITOR` from `editor_bin`, and rewrite the `vi`/`vim` aliases in `02-aliases.fish` only when the editor is neovim (otherwise remove them).
- Config writes that change per role, all through the atomic-write helper once WS-4 lands (WS-3 may call the existing `execute_command` sed pattern and WS-4 swaps it):
  - `roles.json` (validated runtime role metadata for non-interactive consumers)
  - `app_variables.conf` (`$terminal`, `$menu`, `$browser`, `$editor`)
  - `environment_variables.conf` (`BROWSER`)
  - `windows_and_workspaces.conf` (browser workspace rule; launcher layer rule follows the selected `namespace`; Pyprland, Notes, calendar, and clipboard rules use stable setup-owned app IDs)
  - `keybindings.conf` (launcher process target)
  - `fish/conf.d/01-env.fish` (`TERMINAL`, `BROWSER`, `EDITOR`, `VISUAL`, `MANPAGER`, `MENU_DMENU`)
  - `fish/conf.d/02-aliases.fish` and `fish/functions/vim.fish` (selected TUI editor)
  - `waybar/config.jsonc` launcher actions, keybinding-editor action, and `wlr/taskbar.ignore-list`; remove terminal-specific `alacritty`/`alacritty-dropterm` entries and use stable `hss-scratchpad` and `hss-clipboard` app IDs
  - `pypr/config.toml` scratchpad command and stable class
- Scripts: stop rewriting scripts with `sed`. Make them read the generated runtime role registry:
  - `term_exec.sh` reads `roles.json`, supports Kitty, Alacritty, and Ghostty, and accepts stable setup-owned app IDs plus title/execute arguments. Use it from `float_calendar.sh`, `repos_wofi.sh`, and `waybar/scripts/clipboard.sh` instead of literal `alacritty`.
  - Add `menu_exec.sh` beside `term_exec.sh`. It reads the launcher's `dmenu_executable`, `dmenu_args`, and `process` from `roles.json`, loads arguments into a Bash array with `jq`, and executes the array directly. Use it in `repos_wofi.sh` and the Waybar launcher actions.
  - `notes.sh`, `repos_wofi.sh`, `waybar/scripts/weather.sh`, and the Waybar keybinding-editor action resolve editor, browser, and terminal values from `roles.json` rather than Fish.
  - `toggle_floating.sh` keeps its per-terminal size table but reads the selected terminal from `roles.json`.
  - Fish aliases, `MANPAGER`, and `fish/functions/vim.fish` follow the selected TUI editor; Neovim-only behavior is removed for other editors.
- Keep Waybar and SwayNC fixed. Do not add taskbar or notification roles. `swaync-client` in keybindings and the waybar autostart line stay as they are.

### Hyprland `.conf` compatibility

- Retain `hyprland.conf` and the `sources_example` and `sources_specific` fragments.
- `look_and_feel.conf`: delete the `pseudotile = true` line from `dwindle` (the `pseudo` dispatcher still passes the 0.56.2 verifier, so the `mainMod + B` bind keeps working; confirm on a live session that pseudotiling still toggles without the option). Delete `vfr = true` from `misc` (removed upstream; variable frame rate is not configurable there anymore). Leave a one-line comment naming the removed option and the Hyprland version, so nobody re-adds it.
- `keybindings.conf` line 34: `bindd = $mainMod, N, Toggle Split Layout, layoutmsg, togglesplit`.
- Add `tests/fixtures/hypr/` with a script that assembles the installed layout (`sources` from `sources_example`, `sources_specific` as shipped) into a temporary `HOME` and runs the verifier with `XDG_RUNTIME_DIR` pointed at a temp dir. It greps the output for `Config error` in addition to checking the exit code, because a future Hyprland could change one without the other.
- Keep Hyprlock, Hypridle, and Hyprpaper configuration unchanged. They have no `--verify-config` equivalent; note that in the test script's header.
- If the wiki is reachable when WS-2 runs, cite the page and the commit that removed each option in the handoff. If not, the verifier evidence stands, and say so.

### Reliability

Paths and formats are fixed here so WS-4 and WS-5 build the same thing.

- State root: `${XDG_STATE_HOME:-$HOME/.local/state}/hyprland-simple-setup/`.
- Lock: `flock -n` on `<state root>/lock`. On success write `pid=<pid> started=<ISO-8601>` into it. On failure read the file and print `Another setup run holds the lock (pid <pid>, started <time>). Wait for it or remove <path> if that process is gone.` and exit 2. Do not auto-remove stale locks; `flock` releases when the holder dies, so a stale file with no holder does not block.
- Run ID: `$(date -u +%Y%m%dT%H%M%SZ)-$(head -c3 /dev/urandom | od -An -tx1 | tr -d ' ')`. Run directory: `<state root>/runs/<run-id>/` containing `meta` (key=value: start, end, exit, args, every `ROLE_*` value, `DRY_RUN`), `manifest.tsv`, `backup/`, and `log`. Run initialization sets `LOG_FILE=<run-dir>/log`; remove the legacy `$HOME/Hyprland-Simple-Setup.log` destination so normal and dry runs write logs only inside their run directory. Finalization writes the validated run ID to `<state root>/latest-run`. `dotfiles/.config/hypr/scripts/check_setup_warnings.sh` validates that pointer with the run-ID regex and reads the corresponding run log. README troubleshooting and log references point to the state root, `latest-run`, and per-run `log`.
- Manifest row (tab separated): `kind`, `path`, `sha256_before` (or `-` for created files), `sha256_after`, `backup_relpath` (or `-`). `kind` is `created`, `modified`, or `symlink-target` (the path was reached through a symlink and the row's `path` is the resolved target). There is exactly one row per resolved path. The first write records the original digest and backup; later writes update only `sha256_after`. Files under `/etc` that setup edits (`pacman.conf`, the grub-btrfsd override) are manifest rows too; their backups are copied with `sudo` into `backup/` and made readable by the user.
- Temp files: `make_tmp()` wraps `mktemp` under `<run dir>/tmp/` and appends the path to a bash array. The exit trap removes only paths in that array, each checked with `[[ $p == "$run_tmp_dir"/* ]]` before `rm -f`. No `eval`, no `rm -rf` of caller-supplied paths.
- Sudo keepalive: after the password check, `( while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done ) &` with its PID stored in one variable. The exit trap kills it and waits. The interrupt trap does the same and then re-raises the signal.
- Atomic write `write_file_atomic <dest> <source-tmp>`: resolve `<dest>` with `readlink -f`; if `<dest>` is a symlink, the target is what gets replaced and the link stays untouched (this is what keeps Stow links alive). Create the temp file in the target's directory, copy mode and ownership from the existing target (`--reference`), fsync, then `mv -f`. New user-owned files default to mode `0644` and the invoking user's ownership. Privileged `/etc` writes create and rename the same-directory temp through `sudo`, preserve the existing reference metadata, and leave no root-owned temp behind. Record the manifest row before the rename and update its final digest after success. Refuse to write through a symlink whose target lies outside `$HOME` and `/etc`.
- Every setup-managed regular-file write in `setup.sh`, not only in-place edits, is routed through `write_file_atomic` or `edit_file_atomic`. The destination inventory is: role, environment, autostart, monitor, wallpaper, Fish, Waybar, Pyprland, and portal files under `$HOME/.config` or `$HOME/dotfiles/.config`; `/etc/pam.d/login` or `/etc/pam.d/system-local-login`; `/etc/pacman.conf`; `/etc/systemd/system/grub-btrfsd.service.d/override.conf`; and `/etc/sddm.conf.d/sddm.conf`. This covers current `sed -i`, `awk > tmp && mv`, append, heredoc, direct config copy, and `sudo tee` seams. `edit_file_atomic <path> <filter-command...>` reads current content, runs the filter with an argument array, and hands the result to `write_file_atomic`. Since `execute_command` is string-based, these helpers bypass it and call the filter directly. Package-manager and `systemctl` calls keep using `execute_command`.
- Internal run-state files under the state root are written directly by the reliability library. The initial `~/dotfiles` and pre-run `~/.config` tree copies, wallpaper/assets copies, SDDM theme directory copy, AUR build trees, directory creation, package operations, Stow links, and service state are non-file-transaction side effects: dry-run skips them, rollback does not reverse them, and the report states that limitation.
- Dry run: `write_file_atomic` and `edit_file_atomic` check `is_dry_run` first, append `would <kind> <path>: <reason>` to the dry-run operation list, and return. The dry-run summary prints these lines grouped by file. The early `return 0` at the top of `update_configs`, `configure_terminal`, `configure_browser`, and `configure_hypr_autostart_optional_extras` is removed so the functions reach the write helpers and report their paths. Dry run still writes its own `meta` and `log` under the run directory and nothing else.
- Package verification: after `install_pacman_packages` and `install_aur_extras`, run `pacman -T <every selected and role package>` once. `pacman -T` prints the names that are not satisfied and is provides-aware, so `neovim` satisfying `nvim` would not have been a false negative. Report the unsatisfied list in the status summary and record a hard failure for each. Delete the `~/user_installed_packages_*` based path from `verify_installed_packages`; leave `list_packages` as a standalone utility if anything else calls it, otherwise delete it too.
- Rollback: `setup.sh --rollback <run-id>` and `setup.sh --list-runs`. A run ID must match `^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{6}$`, and its canonical directory must be one direct child of `<state root>/runs`. Before any write, validate `meta` and every manifest field: exactly five tab-separated columns; kind in `created|modified|symlink-target`; unique canonical absolute destination path; no control characters; lowercase 64-hex digests, except `sha256_before=-` only for `created`; and `backup_relpath=-` only for `created`. Non-created backups must canonicalize below that run's `backup/` directory, cannot contain absolute or `..` traversal, and their actual SHA-256 digest must equal `sha256_before`. Destinations must canonicalize under `$HOME/.config` or `$HOME/dotfiles/.config`, or exactly match one approved `/etc` destination from the atomic-write inventory. Symlink targets must remain inside the same approved roots. Reject duplicate rows, out-of-scope paths, invalid hashes, invalid kinds, traversal, missing backups, or corrupted backup content before touching any file.
- After validation, rollback compares every current digest to `sha256_after`. Mismatches are listed and the user is asked once whether to overwrite them; in non-interactive mode a mismatch aborts. Modified targets are restored through `write_file_atomic`. A `created` row is deleted only when its current digest still matches `sha256_after`, or after the same explicit mismatch confirmation. A new run directory records rollback as its own run.
- Rollback scope is setup-managed files routed through the atomic helper, including generated `roles.json`. Package installations, service state, Stow-created links, copied directory trees, and the pre-run whole-`.config` backup are explicitly outside rollback. The atomic-write guarantee applies to setup-managed file edits, not package-manager, service, Stow, or directory-copy side effects.
- Checkpoints: none persist across runs. A run that fails leaves its run directory and its log; the next run starts from the beginning. `--resume` does not exist.
- The pre-run `cp -r ~/.config ~/.config.bak.<timestamp>` stays. It is the fallback if the manifest machinery has a bug in its first release. Removing it is a separate decision after one release with manifest backups.

### Tests and CI

- `setup.sh` becomes source-safe with a `BASH_SOURCE` guard. When and only when `HSS_TEST_MODE=1`, a bounded `--test-scenario <roles|reliability>` entry point runs production role/reliability functions without entering the full installer. It refuses test scenarios otherwise. The `roles` scenario calls the production run-state initializer and lock, registry load/validation, role resolution, `roles.json` generation, role consumer writer, shell configuration, selected-package verification, and finalizer. The `reliability` scenario exposes only named lock, temp, atomic-write, manifest, dry-run, and rollback exercises. Tests stage `dotfiles/` under the temporary `HOME`, copy `sources_example` to `sources`, and create the same `$HOME/.config` symlink layout expected after Stow before the scenario starts. Tests never run the unrestricted installer.
- `tests/run.sh`: runs every `tests/shell/*.sh` in a fresh temporary `HOME`, `XDG_CONFIG_HOME`, `XDG_STATE_HOME`, `XDG_RUNTIME_DIR`, with `HYPRLAND_SETUP_DIR` pointing at the checkout and `PATH` prefixed with `tests/stubs/`. Plain bash, no bats dependency; each test prints `ok` or `not ok` lines and the runner counts them.
- `tests/stubs/`: executable stand-ins for `pacman`, `yay`, `sudo`, `chsh`, `systemctl`, `stow`, `xdg-user-dirs-update`, `reflector`. Each appends its argv to `$STUB_LOG` and returns success. `pacman -T` in the stub reads an optional `$STUB_INSTALLED` list so a test can make a package look missing. `sudo` execs its arguments so stubs behind it still log.
- Shell tests, one file each: lock contention (two runs, second exits 2 with the holder PID in output), temp cleanup on SIGINT, keepalive gone after exit, atomic write through a symlink keeps the link and replaces the target, atomic write preserves mode, dry-run digest of `$HOME` before equals after and the summary lists the `app_variables.conf` path, two runs with `ROLE_TERMINAL=kitty` then `ROLE_TERMINAL=alacritty` end with Alacritty in `app_variables.conf` and both run directories present, manifest rows match the files actually changed, rollback restores only manifest files and refuses a malformed manifest, rollback stops on a digest mismatch, `chsh` stub receives the username and `/usr/bin/zsh`, `pacman -T` output with one missing package produces a hard failure naming it, unknown `ROLE_BROWSER` value aborts, mixed `SELECTED_*` presence aborts, and manifest validation rejects run-ID traversal, backup traversal, duplicate rows, invalid kinds/hashes, corrupted backup content, symlink escape, and out-of-scope destinations.
- Rust tests in `src/packages.rs`: schema parses the shipped `packages.json`; all schema rules above; selecting a role option deselects siblings; required packages survive "none" and a toggle attempt; exported env map contains every role; a role with zero selected options blocks start.
- `tests/check_packages_json.sh`: `jq -e`, plus a live check (`pacman -Si` for `source: pacman`, AUR RPC for `source: aur`) that runs only when `HSS_LIVE_PACKAGE_CHECK=1`. Not part of CI; part of the release checklist.
- `tests/verify_hypr_config.sh`: the fixture described under compatibility. Exit 0 on pass, 1 on config errors, 3 with `SKIPPED: Hyprland not installed` when the binary is absent. CI does not run it (Ubuntu runners have no Hyprland). The release checklist runs it and records the version.
- CI: replace `rust.yml` with `ci.yml` containing three jobs: `rust` (`cargo fmt --check`, `cargo clippy --locked --all-targets -- -D warnings`, `cargo test --locked`), `shell` (build a deterministic null-delimited file array from `scripts/lib` and `tests`, append the exact changed role scripts listed in the acceptance command, then run `bash -n`, `shellcheck -x`, and `tests/run.sh`), `json` (`jq -e . packages.json` and `tests/check_packages_json.sh` without the live flag). Keep `release.yml`.
- README: document `ROLE_*`, `--rollback`, `--list-runs`, the state directory, `latest-run` and per-run log lookup, removal of the legacy home log, and `tests/run.sh`.

## Non-goals

- No Lua migration and no `hyprland.lua`.
- No merge or rebase of either old branch.
- No automatic deletion of old local or remote branches.
- No whole-`~/.config` or whole-`~/dotfiles` restore. The pre-run copy stays; see decisions.
- No general rewrite of `setup.sh` beyond routing writes through the new helpers and removing the replaced role code.
- No persistent cross-run resume.
- No taskbar or notification-daemon roles, and no new Yambar, nwg-panel, Mako, or Dunst assets.
- No change to how `SUDO_PASSWORD` is passed (env var, piped to `sudo -S`). It is a known weakness and is recorded under deferred decisions.
- No package installation, service changes, compositor reload, or other live-system mutation during automated tests.

## Decisions and invariants

- `.conf` remains the active Hyprland format for this project until a separate migration is authorized.
- Exclusive roles select exactly one package. General categories stay multi-select.
- `packages.json` is the only registry. Rust deserializes it; `setup.sh` reads it with `jq`; the TUI passes package names only.
- `executable`, `args`, `class`, `dmenu_executable`, `dmenu_args`, `process`, `namespace`, and `editor_bin` are structured registry values. Runtime scripts load argument arrays with `jq` and execute arrays directly. Config renderers shell-quote each fixed argv element; no registry command string or `eval` is allowed.
- New shell code passes paths, usernames, packages, and command arguments as quoted expansions or arrays. Existing `execute_command` string calls that survive are limited to package-manager and service commands whose arguments are registry package names already validated by regex.
- `chsh` receives the explicit invoking username and a path present in `/etc/shells`.
- Exit and signal temporary cleanup never uses `eval` and never removes a path outside the run's temp directory. Explicit rollback may delete a manifest-listed setup-created file under the approved roots after digest verification.
- Atomic edits write beside the resolved target, validate, preserve mode, and rename only after the manifest row is recorded.
- Rollback is explicit and run-scoped. It refuses missing, malformed, or incomplete manifests and stops on digest mismatches.
- The integration owner alone resolves shared `setup.sh` changes and updates the progress and decision records.

## Execution DAG

```text
Wave 0: baseline and implementation branch
  |
  +--> Wave 1A: WS-1 package schema and TUI selection
  |       |
  |       +--> integrate; run Rust/JSON checks
  |
  +--> Wave 1B: WS-2 retained .conf compatibility
          |
          +--> integrate; run config fixture on Hyprland 0.56.2
                  |
                  v
Wave 2: WS-3 setup role consumers and package execution
  |
  +--> integrate; run dry-run fixture for every role option
          |
          v
Wave 3: WS-4 reliability primitives, manifests, rollback
  |
  +--> integrate; run shell behavior tests
          |
          v
Wave 4: WS-5 cross-workstream tests and CI
  |
  +--> full validation
          |
          v
Wave 5: two independent reviews, accepted fixes, revalidation, HTML report
```

WS-1 and WS-2 touch disjoint files but run sequentially in the active worktree. Everything that touches `setup.sh` is sequential. Read-only review or research may run alongside, but only one writer modifies the active worktree.

## Workstreams and ownership

### WS-1: package schema and Rust TUI

Owner: implementation worker 1

Write boundary: `packages.json`, `src/main.rs`, new `src/packages.rs`, `Cargo.toml`, `Cargo.lock`, Rust tests.

Forbidden: `setup.sh`, `dotfiles/**`, anything under `tests/` other than Rust fixtures.

Tasks:

1. Apply the package corrections in `packages.json`: `input-remapper`, `neovim`, `hyprshot` and `hyprsunset` into `hyprland_packages.core_hyprland` and `hyprland_packages.screenshots` (create the category), add `firefox`, `chromium`, `bash`, `zsh`, `ghostty`, `zed`, `helix`, `rofi`, `fuzzel`, `bemenu` to the matching pacman categories and `brave-bin`, `cursor-bin` to AUR categories, with descriptions.
2. Add `required` and `roles` per the schema section. Use the exact approved required set shown there; write the rationale for each in the handoff.
3. Create `src/packages.rs` with typed structs, `load(path)`, `validate()`, `RoleSelection`, and `export_env()`.
4. Replace the numeric terminal choice and add the role selector and required locking in the TUI.
5. Fix `packages.json` discovery and the `bash -lc` classification calls.
6. Unit tests listed under tests.

Handoff artifact: runtime-managed `handoffs/ws-1-package-tui.md`. Must include: the required set with reasons, the exact `ROLE_*` names exported, and `cargo test` output.

### WS-2: retained `.conf` compatibility

Owner: implementation worker 2

Write boundary: `dotfiles/.config/hypr/hyprland.conf`, `dotfiles/.config/hypr/sources_example/**`, `dotfiles/.config/hypr/sources_specific/**`, `tests/verify_hypr_config.sh`, `tests/fixtures/hypr/**`.

Forbidden: Lua files, `setup.sh`, Rust and `packages.json`.

Tasks:

1. Make the three edits under compatibility.
2. Write the fixture script and run it on the local 0.56.2 install. Paste the clean `Config parsing result` block into the handoff.
3. Grep `sources_example` for any other option the verifier warns about (warnings, not just errors) and list them in the handoff without fixing them unless they are one-line renames.

Handoff artifact: runtime-managed `handoffs/ws-2-conf-compatibility.md`.

### WS-3: setup role consumers and package execution

Owner: implementation worker 3, starting only after WS-1 and WS-2 are integrated

Write boundary: role parsing, package installation, `configure_shell`, `configure_environment`, the guarded test-mode dispatch, and the config-write sections of `setup.sh`; `install.sh` help text; every dotfiles consumer listed in verified fact 16 plus `environment_variables.conf`, both Waybar launcher actions, `weather.sh`, Fish `MANPAGER`/aliases/`vim.fish`, and `pypr/config.toml`; `tests/shell/roles_*.sh`; `tests/stubs/**` (initial version).

Forbidden: lock, trap, manifest, backup, rollback code in `setup.sh` (WS-4); `packages.json` schema changes without escalation; Lua.

Tasks:

1. Role parsing and validation with `jq`, including the `jq` bootstrap in `main()`.
2. Delete the `hyprland_packages` and `aur_extras` arrays, `get_terminal_choice`, `get_browser_choice`, and the browser `case` blocks. Install role packages plus `extra_packages` from the role choice.
3. Replace `configure_terminal` and `configure_browser` with one `configure_roles` that writes the files listed under consumers.
4. `configure_shell` with explicit user and `/etc/shells` check; `configure_environment` from `editor_bin`.
5. Script changes: `term_exec.sh` Ghostty support and stable app IDs, new `menu_exec.sh`, runtime lookups from `roles.json`, `pypr/config.toml`, and the role-aware Waybar consumers.
6. Package verification with `pacman -T` against the selected set.
7. Fix the 5 baseline `shellcheck` findings so `shellcheck -x` can become a gate.
8. Dry-run evidence: run the guarded role scenario once per role option (22 runs, scripted) with stubs on `PATH` and attach the summaries. Until WS-4 lands, the summaries may lack paths from functions that WS-4 has not yet routed through atomic helpers; list those omissions explicitly.

Handoff artifact: runtime-managed `handoffs/ws-3-role-consumers.md`. Must include the window-class verification method used for each browser and terminal.

### WS-4: reliability and rollback

Owner: implementation worker 4, starting from the integrated WS-3 revision

Write boundary: new `scripts/lib/setup-reliability.sh` (sourced by `setup.sh`), the lock, trap, keepalive, temp, atomic-write, one-row-per-path manifest, dry-run recording, created-file rollback, `--rollback`, `--list-runs` sections of `setup.sh`, the removal of the early dry-run returns, `dotfiles/.config/hypr/scripts/check_setup_warnings.sh`, `tests/shell/reliability_*.sh`, stub additions.

Forbidden: role behavior, Hyprland configuration content, Rust, any persistent resume.

Tasks: implement the reliability section as specified, route every setup-managed regular-file write through the atomic helpers, replace the legacy home-log consumer with the validated `latest-run` lookup, and write the shell tests listed under tests for locking, cleanup, keepalive, atomic writes, dry run, run isolation, manifests, rollback, and latest-log lookup.

Handoff artifact: runtime-managed `handoffs/ws-4-reliability.md`. Must include a sample `manifest.tsv` from a stubbed run and the output of a refused rollback.

### WS-5: cross-workstream tests and CI

Owner: implementation worker 5, starting after WS-4 integration

Write boundary: `tests/**`, `.github/workflows/**`, `README.md` sections named above, `CHANGELOG.md` unreleased section. Minimal production edits only when an accepted testability defect blocks a deterministic test; escalate before crossing another workstream's boundary.

Tasks: `tests/run.sh`, `tests/check_packages_json.sh`, the CI workflow, the end-to-end two-run test, a 22-case role assertion matrix, README and changelog entries, and a `reports/` directory with the HTML report skeleton for Wave 5. The matrix selects each option once with defaults for the other five roles and asserts the generated `roles.json` package/executable/argv metadata plus the affected config output: browser command/class, terminal stable app IDs and wrapper argv, shell path, GUI/TUI editor values and aliases, and launcher normal/dmenu argv, process, namespace, Waybar actions, and layer rule. Summary-only runs do not satisfy this gate.

Handoff artifact: runtime-managed `handoffs/ws-5-tests-ci.md`.

## Integration checkpoints

After each workstream the integration owner:

1. inspects the diff and confirms the write boundary;
2. records commands, exit codes, omissions, and residual risks;
3. integrates only after the workstream's focused checks pass;
4. reruns the affected checks on the combined revision;
5. updates the progress and decision records below.

WS-3 waits for WS-1 and WS-2. WS-4 waits for WS-3. WS-5 waits for WS-4.

## Acceptance checks

Run the applicable subset after each workstream and the full set before review:

```bash
jq -e . packages.json
cargo fmt --check
cargo check --locked
cargo test --locked
cargo clippy --locked --all-targets -- -D warnings
mapfile -d '' shell_files < <(find scripts/lib tests -type f -name '*.sh' -print0 | sort -z)
role_scripts=(
  dotfiles/.config/hypr/scripts/float_calendar.sh
  dotfiles/.config/hypr/scripts/menu_exec.sh
  dotfiles/.config/hypr/scripts/notes.sh
  dotfiles/.config/hypr/scripts/repos_wofi.sh
  dotfiles/.config/hypr/scripts/term_exec.sh
  dotfiles/.config/hypr/scripts/toggle_floating.sh
  dotfiles/.config/waybar/scripts/clipboard.sh
  dotfiles/.config/waybar/scripts/weather.sh
)
bash -n setup.sh install.sh "${shell_files[@]}" "${role_scripts[@]}"
shellcheck -x setup.sh install.sh "${shell_files[@]}" "${role_scripts[@]}"
tests/run.sh
tests/check_packages_json.sh
tests/verify_hypr_config.sh          # local and release gate; exit 3 means Hyprland is absent, which is not a pass
```

Baseline on `main`: `fmt`, `clippy`, `bash -n` pass; `shellcheck` fails with 5 findings; `cargo test` runs 0 tests. WS-3 clears the shellcheck findings; WS-1 adds the first tests.

The end-to-end test in `tests/shell/e2e_two_runs.sh` must:

- create isolated temporary home, config, state, and runtime directories;
- run `HSS_TEST_MODE=1 setup.sh --test-scenario roles` with stubs and `ROLE_TERMINAL=kitty`, then again with `ROLE_TERMINAL=alacritty` and `ROLE_BROWSER=firefox`;
- assert `app_variables.conf` ends with the second choices and that both run directories have complete manifests;
- assert the stub log shows `chsh` called with the username and shell path;
- run the guarded role scenario a third time with `DRY_RUN=true`, then assert the `$HOME` digest is unchanged and the summary lists `app_variables.conf`.

The config test constructs the installed layout and runs:

```bash
XDG_RUNTIME_DIR=<tmp> HOME=<fixture-home> Hyprland --verify-config --config <fixture-home>/.config/hypr/hyprland.conf
```

Record the tested Hyprland version in the handoff and the changelog. When Hyprland is unavailable the script exits 3 with a `SKIPPED` line; a release is not cut on a skip.

Rollback acceptance must prove:

- only manifest-listed files are restored;
- a file whose current digest differs from `sha256_after` stops rollback for confirmation, and aborts in non-interactive mode;
- a missing backup for a `modified` or `symlink-target` row, or a manifest with the wrong column count, fails before any write;
- rollback never moves or replaces `~/.config` or `~/dotfiles`.

## Review and finding disposition

After integration and full validation, run two fresh-context, read-only reviewers from different provider families when available. Both review the integrated result against this plan.

Reviewer angles:

1. package-selection correctness, `.conf` behavior, shell quoting, and user-visible regressions;
2. reliability, rollback safety, dry-run truthfulness, test quality, and failure handling.

For each finding record: reviewer run and provider/model; file or symbol; violated criterion or failure mode; evidence and severity; disposition (`accepted`, `rejected`, `deferred`, `needs verification`); revalidation evidence for accepted fixes.

## Rollback and recovery during implementation

- Use `7105e24` as the clean source baseline. The integration owner's verified plan-only modification is permitted before WS-1. Do not create or switch branches unless the repository maintainer asks; keep the active worktree single-writer and record each integrated workstream in the plan.
- Commit each integrated workstream separately.
- If a workstream fails its gate, revert only that workstream's commit or restore its isolated worktree. Do not reset or rewrite unrelated user work.
- Keep the two old branches until the successor implementation is integrated and verified. Branch deletion requires separate explicit authorization.
- When the plan completes, move this file to `plans/archive/` (already ignored by Git per the pending `.gitignore` change).

## Risks

| Risk | Mitigation |
| --- | --- |
| `setup.sh` ownership overlap | Sequential workstreams and one integration owner |
| JSON and Rust role definitions drift | One typed schema loaded from `packages.json`; schema tests; `setup.sh` arrays deleted |
| Window classes for new browsers or editors are wrong, so workspace rules silently do nothing | Verify on a live session or from `.desktop` files; record the method |
| Shell choice changes root | Explicit username and `/etc/shells` check; stub test asserts argv |
| Package names move between repositories | `tests/check_packages_json.sh` live mode in the release checklist |
| Atomic edits replace a Stow symlink with a regular file | Resolve the link and replace the target; test both cases |
| Rollback overwrites later user edits | Digest check against `sha256_after`; fail closed non-interactively |
| Dry run claims safety while a helper writes state | Digest of `$HOME` before and after in the e2e test |
| `.conf` removals change behavior | Only the three verifier-rejected lines change; verifier plus manual note in handoff |
| `jq` missing on a fresh system before role parsing | Bootstrap install in `main()` mirrors the existing `xdg-user-dirs` pattern |
| AUR build failure reported as "missing package" | `pacman -T` after install distinguishes unsatisfied from failed; failures carry the helper's exit code |
| Future Lua work conflicts with abstractions | Config mutation stays behind `edit_file_atomic` and `configure_roles`; no Lua started |

## Approved decisions

- Do not merge either old branch.
- Keep Hyprland `.conf` configuration for this effort.
- Repair current `.conf` compatibility without migrating format.
- Reimplement the robustness mechanisms rather than resolving and merging the stale branch.
- Exclude persistent resume behavior.
- Keep taskbar and notification alternatives out of role choices until complete assets exist.
- Keep the pre-run whole-`~/.config` copy in this release; remove whole-tree restore only.
- Lock the exact required foundation set recorded in the schema; role options and optional extras remain selectable.
- Use generated `~/.config/hypr/roles.json` as the shell-independent runtime role-data source.
- Use one manifest row per resolved path; preserve the first backup, update the final digest, and delete unchanged setup-created files on rollback.
- Limit rollback to setup-managed files. Packages, services, Stow-created links, copied trees, and the pre-run backup are outside rollback.
- Use the guarded `HSS_TEST_MODE=1 --test-scenario` seam for shell integration tests.

## Deferred decisions

- Hyprland Lua migration.
- Alternative taskbar and notification-daemon configuration assets.
- Deletion of the two old branches.
- Removal of the pre-run `~/.config` copy once manifest backups have shipped in a release.
- Passing `SUDO_PASSWORD` some other way than an environment variable piped into `sudo -S`.
- Refreshing `~/dotfiles` from the repository on re-runs when it already exists.
- Publication or release timing.

## Progress record

| Wave | Status | Revision/evidence | Notes |
| --- | --- | --- | --- |
| Plan | complete | `plans/planned/package-selection-reliability-improvements.md` | Initial plan created from branch audit |
| Plan verification | complete | oracle `51818a7d-c09b-42fd-a940-3ea983a4ab5c`; reviewers `9fdaeb6d-c6ee-4acb-8622-48302f0d8540`, `67da5478-8dce-49ed-aaed-6d4f2e6b576d`, `f594d66b-5a2c-4664-a2b1-24b89873a769`, `7698ce16-56ab-4381-b4b8-644484a9bacb` | Fixture verified on Hyprland 0.56.2; package availability checked; all plan blockers resolved; final focused gate GO at 98/100 confidence |
| WS-1 | complete | worker `6333730b-be43-4c43-9964-52b638d184ac`; parent reran JSON/Rust gates | Changed only `packages.json`, `src/main.rs`, and `src/packages.rs`; 6 tests pass; fmt/check/clippy/diff checks pass; interactive TUI walkthrough deferred to integrated validation |
| WS-2 | not started |  |  |
| WS-3 | not started |  |  |
| WS-4 | not started |  |  |
| WS-5 | not started |  |  |
| Integrated validation | not started |  |  |
| Independent reviews | not started |  |  |
| HTML report | not started |  |  |

## Decision record

| Date | Decision | Rationale |
| --- | --- | --- |
| 2026-08-29 | Use clean source baseline `7105e24`; allow the verified plan-only edit before WS-1; use old branches only as references | Neither branch passed merge-readiness review, and the corrected canonical plan must remain visible during implementation |
| 2026-08-29 | Retain `.conf` and defer Lua | Explicit user direction |
| 2026-08-29 | Use explicit exclusive roles | Configuration consumers require one active command |
| 2026-08-29 | Omit persistent cross-run resume | The old implementation silently skipped changed work on later runs |
| 2026-08-29 | Use scoped run manifests for rollback | Whole-directory rollback risks overwriting unrelated user configuration |
| 2026-08-29 | `rofi` replaces `rofi-wayland`; `neovim` replaces `nvim`; `input-remapper` replaces `input-remapper-2` | Verified against the sync database and AUR RPC; the old names no longer exist |
| 2026-08-29 | TUI passes package names in `ROLE_*`; `setup.sh` resolves commands from `packages.json` with `jq` | Keeps one registry and keeps command strings out of the environment |
| 2026-08-29 | Keep the pre-run `cp -r ~/.config` copy for this release | It is the only fallback if the manifest code has a first-release bug; removal deferred |
| 2026-08-29 | Validate `.conf` replacements with the 0.56.2 verifier | The wiki blocks automated fetches; the verifier is the authority that matters at install time |
| 2026-08-29 | Introduce a sudo keepalive in WS-4 and require the trap to end it | `main` has none today; long AUR builds under `sudo -n` need it |
| 2026-08-29 | Plain-bash test runner with PATH stubs instead of bats | No new dependency; stubs work because `execute_command` uses `bash -c` |
| 2026-08-29 | Approve the exact 21-package required foundation set | Removes the product decision from WS-1 while keeping role and optional packages selectable |
| 2026-08-29 | Generate `~/.config/hypr/roles.json` | Hyprland and Waybar scripts cannot rely on Fish startup files, especially when Bash or Zsh is selected |
| 2026-08-29 | Keep one manifest row per resolved path and delete unchanged created files on rollback | Repeated writes retain the original backup and rollback has defined created-file semantics |
| 2026-08-29 | Limit rollback to setup-managed files | Package, service, Stow, and directory-copy reversal is outside this release and must not be implied |
| 2026-08-29 | Add a guarded test scenario seam | Shell tests exercise production role and reliability functions without running unrestricted system setup |
