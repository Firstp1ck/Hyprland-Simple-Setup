# D01 — Bars and docks

Status: product policy synchronized with the completed interview; implementation not started. Master section 9 and the [decision record](../desktop-harmonization-grill.md) define P01-P07; native frontend evidence remains pending.
Master: [Desktop harmonization master](../desktop-harmonization-master.md).
Source baseline: `610a18bac374e7e2ffd0bcb2d99b026131deedbc`, branch `feat/harmonize-visual-design`.
Goal: preserve the active Waybar workflows across every bar choice and define reversible, independently selectable dock integration.

## 1. Scope and boundaries

D01 owns bar/dock presentation, app-specific F03 renderers, gesture mappings, panel layout, and domain acceptance evidence.
Cover Waybar, Ironbar, nwg-panel bar, nwg-dock-hyprland, nwg-panel dock, and dock None.
Preserve current selections, defaults, environment inputs, literal argv, reliability behavior, and primary/member distinctions.
Primary routing selects applications; every selected member receives applicable theme coverage through its owning domain.
D02/D03/D04/D07 supply menu, notification, device, and session/auxiliary provider contracts, not frontend dependencies.
No competing action bus, theme source, catalog, transaction framework, full desktop shell, or mandatory companion is proposed.
No installation, activation, implementation, data migration, commits, publication, or repository changes are authorized by this draft.

### Specific option coverage

| Role and option | Observed starting point | Required planning disposition |
|---|---|---|
| Bar: `waybar` | Required single-choice role; current default; rich active profile | Preserve exact active operations and compatible custom configuration |
| Bar: `ironbar` | Top, height 32; workspaces, centered clock, tray | Map every approved baseline capability; missing native support requires evidence and escalation |
| Bar: `nwg-panel` | Top, height 32; workspaces, clock, tray; generic controls/menu disabled | Expand presentation without silently enabling unrelated provider controls |
| Dock: `nwg-dock-hyprland` | Catalog executable with empty configured argv; no dedicated profile found in scoped search | Discover supported configuration and existing-user behavior before proposing managed output |
| Dock: `nwg-panel` | Bottom, height 56; Hyprland taskbar; generic controls/menu disabled | Preserve taskbar behavior and shared-process ownership |
| Dock: None | Optional single-choice role; current default is null | No dock output or activation; retain successful no-op launch behavior |

## 2. Observed source evidence

All observations are static source evidence, not installed-version or graphical compatibility proof.

| Anchor | Observation and consequence |
|---|---|
| `dotfiles/.config/waybar/config.jsonc` | Active arrays contain five left and ten right modules; definitions outside those arrays are not baseline features |
| `dotfiles/.config/waybar/style.css` | Literal palette, bold 15px Nerd Font, rounded module surfaces, warning/critical/muted states and menu styling need F03 mapping |
| Waybar `options_menu.xml`, `update_menu.xml`, `power_menu.xml`, `backlight_menu.xml` | Explicit menu IDs and ordering provide auditable action inventories |
| `scripts/lib/update-waybar-roles.py:update_document`, `update_bar` | Updates selected action keys in object/array JSONC while preserving comments and unrelated settings; notification interval/exec-if are removed |
| `setup.sh:update_waybar_role_config` | Existing action update runs only for selected Waybar; theme integration must not broaden this into unapproved edits to unrelated profiles |
| `hypr/scripts/nwg_panel.sh` under `.config` | Combines selected profiles into `hss-panels`; shared dock invocation exits without starting another process; only bar receives RT toggle configuration |
| `hypr/scripts/toggle_waybar.sh` under `.config` | Existing nwg-panel toggle sends RTMIN to the managed combined invocation; other bars are terminated if found or launched if absent |
| Waybar `audio_control.sh`, `alsamixer.sh`, `nmtui.sh`, `nmtui-connect.sh` | Both audio gestures route to selected audio; both network gestures currently route to the same selected network command |
| Waybar `notification_status.sh` | SwayNC supplies streaming status; other providers receive static presentation JSON every five seconds |
| Waybar `launch_system_update.sh`, `updates_status.sh` | Update launch uses argv arrays and a duplicate-safe user service; status wrapper owns and cleans up producer/formatter children |
| `packages.json:roles.bar` | Seven extras attach specifically to Waybar; dependency closure for alternative frontends is not established by their minimal profiles |

Source paths abbreviated as Waybar or Hyprland paths above are beneath `dotfiles/.config/`.
Existing script comments referencing particular upstream versions are not independently verified version evidence.

## 3. Exact active Waybar parity candidate

P01 approves the active Waybar operations and menus as the baseline. Keep this source inventory separate from verified effects. Add the explicitly approved dedicated dark/light control to every supported bar. Bars appear on every output; absent hardware modules remain visible as unavailable.
Active left order: `custom/power`, `custom/menu`, `tray`, `hyprland/workspaces`, `hyprland/submap`.
Active right order: `pulseaudio`, `backlight`, `custom/temperature`, `keyboard-state`, `battery`, `network`, `bluetooth`, `custom/updates`, `custom/notification`, `clock`.

| Active module | Observed display and gestures | Contract/evidence requirement |
|---|---|---|
| `custom/power` | Left: `launch_power_screen.sh`; right: power menu | D07 power screen; ordered menu entries suspend, hibernate, shutdown, reboot, logout |
| `custom/menu` | Left: `menu_exec.sh --toggle`; right: options menu | D02 applications/menu selection; ordered entries applications, view keybinds, open keybind config, snapshot |
| `tray` | 21px icons, spacing 5, passive items shown | Preserve tray access; item gestures are provider-dependent, not declared global bindings |
| `hyprland/workspaces` | Numeric IDs, numeric sorting; explicit click activate | Tooltip advertises previous/next scroll, but no explicit scroll binding: verify supported-version behavior before freezing |
| `hyprland/submap` | Italic submap text; no configured gesture | Preserve active-submap visibility and empty-state behavior |
| `pulseaudio` | Output/source volume, mute and Bluetooth formats | Left/right both open selected audio; implicit wheel behavior requires verification, not inference |
| `backlight` | Percentage; tooltip advertises scroll adjustment | Right menu presets 100/75/50/25/10 via `backlight.sh`; verify native scroll direction, step and target device |
| `custom/temperature` | JSON every two seconds; per-sensor tooltip; critical threshold 80°C | Left: system monitor through `sensor.sh`; missing sensor currently emits N/A |
| `keyboard-state` | Num Lock enabled; Caps Lock disabled; lock icons | Preserve configured scope; no custom gestures |
| `battery` | Capacity, charging/plugged formats; good 80, warning 30, critical 15 | Alternate time display and tooltip advertise left-click toggle; verify native implementation and absent-battery behavior |
| `network` | Wi-Fi strength, Ethernet, linked/no-IP, disconnected and disabled states | Left picker/right editor labels exceed current identical command routes; D04 resolves semantic differentiation |
| `bluetooth` | Controller/radio/connected-device status and optional device battery | Left selected manager; right `toggle_bluetooth.sh`; distinguish no controller from powered off |
| `custom/updates` | Conditional on updates executable; streaming count/details | Left confirmation; right check/update/without-AUR/firmware/pacnew/cache/log operations |
| `custom/notification` | Notification/DND/inhibited icon combinations | Left legacy `toggle`, right legacy `dnd`; D03 must supply honest state/effect contracts |
| `clock` | `Europe/Zurich`; date/time format; calendar tooltip | Left selected calendar via `float_calendar.sh`; retain timezone/custom format unless separately approved |

Update menu IDs map respectively to `--check`, no argument, `--without-aur`, `--firmware`, `--review-pacnew`, `--clean-cache`, `--show-log`.
Options-menu editing uses the selected TUI editor and `keybindings.lua`; snapshot invokes privileged Timeshift creation, not screenshot capture.
Power helper also defines lock, but lock is not an active power-menu entry.
Defined `wlr/taskbar` and `power-profiles-daemon`, empty `hidden_config.jsonc`, unused CSS selectors, and unreferenced helpers remain extras.
Do not activate taskbar middle-click close, ignored-window rules, power profiles, weather, clipboard, or other extras merely to claim parity.

## 4. Proposed capability, theme and handoff contracts

All concrete interface names remain provisional until foundation freeze; D01 contributes requirements rather than creating parallel schemas.

| Producer → consumer | Required handoff |
|---|---|
| D01 → [F01](F01-inventory-capability-contracts.md) | Exact operation/gesture inventory, inactive extras, dependency edges, native/helper feasibility and dock policy questions |
| F01 → D01 | Approved capability identities, P01 baseline, option ownership, feature closure and P05 support evidence |
| [F02](F02-runtime-managed-configuration.md) → D01 | Typed actions/status, cancellation/results, ownership, managed writes, compatibility wrappers and activation outcomes |
| [F03](F03-visual-system-theme-generation.md) → D01 | Frozen renderer inputs, semantic tokens, assets, variants, validation and activation descriptors |
| [F04](F04-verification-foundation.md) ↔ D01 | Fixtures, coverage identities, evidence levels, visual protocol and proposed P07 measurements |
| [D02](D02-launchers-shared-menus.md) → D01 | Shared menu descriptors, stable entry identity, safe desktop-entry execution and cancellation; D01 owns native menu presentation |
| [D03](D03-notifications-attention.md) → D01 | Attention/history/DND actions and truthful observations under one notification owner |
| [D04](D04-device-controls.md) → D01 | Network connect/edit, Bluetooth radio/devices, audio output/input and approved stream/hardware semantics |
| [D07](D07-session-auxiliary-interfaces.md) → D01 | Power, brightness, monitor, keybinding-viewer, snapshot and administration provider contracts; legacy Waybar helpers require explicit ownership reconciliation |
| D01 → [I01](I01-integration-rollout-acceptance.md) | Profiles/renderers, dependency and shared-file requests, nine bar/dock combination evidence, upgrade/rollback notes and unresolved limits |

D06 calendar and D05 terminal/editor routing remain existing consumer paths; D01 does not migrate calendar data or redesign launch adapters.
Discovery and contract contributions may precede foundation implementation; app implementation waits for frozen F01/F02/F03/F04 contracts.
Actual provider implementations gate complete frontend behavior, not initial foundation specification or fixture-driven renderer work.
Provider backends must not import D01 widgets, styles, or frontend-owned filesystem paths; retain compatibility wrappers during extraction.

### Presentation and dependency mapping

- Map F03 surfaces, text, accent, focus, selection, warning/error, disabled/stale states, metrics and typography into each app's supported styling surface.
- Register D01 renderers under F03's proposed `theme/renderers/`; validate each app's syntax rather than assuming CSS/API interchangeability.
- Cover bar/dock menus, tooltips, workspace/task states, tray spacing, device states and notification attention without embedding icons or markup in shared status.
- Require dark/light appearance and preserve existing accessibility preferences; dedicated high-contrast, enlarged-text and reduced-motion variants are not mandatory. Disclose native constraints.
- Distinguish None, missing executable/asset, unsupported capability, absent hardware, denied permission, stale observation, cancellation and failure.
- Audit Waybar extras: `plasma-systemmonitor`, `fwupd`, `pacman-contrib`, `zenity`, `curl`, `less`, `lm_sensors`; do not copy the list blindly to other roles.
- Also trace updates producer, Timeshift/polkit, Wlogout, Python/Tk/Xwayland, jq, systemd user services, fonts/icons and selected-role dependencies.
- Submit feature-based closure to F01; a generic catalog entry does not prove installation, and a cross-source dependency is not an arbitrary `extra_packages` addition.

## 5. Numbered work packages

### D01.1 — Freeze baseline and feasibility contributions
Status: not started. Prerequisite: planning approval; source/version discovery may precede the foundation gate.
Ownership: D01 contributes rows to F01's proposed capability ledger and F04's proposed coverage descriptor; producer owners integrate shared files.
Deliverables: full matrix above traced through helpers, explicit/native-default gesture evidence, dependency closure requests and dock policy brief.
Bounded future probes: alternative-bar custom controls/menus, keyboard reachability, task activation/pinning, output selection and autohide.
Validation: source-to-menu ID equality; distinguish confirmed routes from tooltip promises; record version/API evidence without live adoption.
Done: every active operation and option has a contract/evidence disposition; unresolved required support blocks parity rather than disappearing.

### D01.2 — Implement application theme mappings
Status: not started. Prerequisites: foundation gate; D01.1 identities; approved P02 values and P05 compatibility.
Ownership: D01's F03 renderer registrations and existing Waybar/Ironbar/nwg-panel app profiles; new dock/style paths remain proposed pending discovery.
Deliverables: deterministic staged app outputs, validators, asset references and per-app reload/restart/deferred descriptors.
Preserve behavior keys, user overrides and inactive extras; shared nwg-panel styling must have one deduplicated output owner.
Validation: F04 renderer fixtures for approved variants, missing assets, hostile strings, duplicate outputs, None and unchanged reruns.
Done: each selected bar/dock has declared visual coverage or a blocking limitation; renderers perform no live writes or activation.

### D01.3 — Wire complete bar presentation
Status: not started. Prerequisites: foundation gate, D01.1 contracts; D01.2 styling; real providers before behavior acceptance.
Ownership: existing app profiles, Waybar XML presentation and D01-owned formatting adapters; provider/helper extraction remains with F02/D02-D07.
Deliverables: equivalent approved controls for all three bars, including all menu entries and explicit failure/stale feedback.
Prefer verified native widgets; use bounded shared-provider interfaces where necessary, never a second desktop shell.
Validation: proposed `tests/shell/bars_parity.sh` traces every gesture to one intended invocation and independent modeled state; preserve legacy wrappers.
Done: every baseline operation has either a verified native implementation or an explicit disabled/explained unsupported control on a labeled limited option. No false success, silent substitute or missing-operation concealment; providers do not depend on widgets.

### D01.4 — Define dock workflows and output behavior
Status: not started. Prerequisites: foundation gate, D01.1 findings, P01/P05 approval for required dock capabilities.
Ownership: nwg-panel dock profile and app-specific nwg-dock renderer/configuration; output paths for the latter are proposed until verified.
Deliverables: pin identity/order and launch-versus-focus rules, task states, monitor placement, reserved-space and autohide descriptors.
Seed the primary terminal/browser/graphical file manager/enabled GUI editor when no user pins exist. Follow the focused output where natively supported; otherwise use the fixed primary output and label follow-focus unsupported. Preserve user assignments. Autohide, dock-specific keyboard switching and window actions are optional, not new mandatory features.
Validation: proposed `tests/shell/docks_behavior.sh` covers None transitions, malformed/missing desktop entries, duplicate windows, hotplug and keyboard access.
Done: both docks meet approved outcomes or retain explicit blockers; None neither launches nor generates dock-specific state.

### D01.5 — Integrate lifecycle and reversible switching
Status: not started. Prerequisites: D01.2-D01.4; F02 ownership/transactions; P06 before changed existing-install activation.
Ownership: D01 supplies specifications/tests; F02/I01 integrate `nwg_panel.sh`, `toggle_waybar.sh`, role routing, startup and installer changes.
Deliverables: all nine bar/dock combinations; combined nwg-panel starts once, dock launch remains a no-op when shared, bar toggle leaves dock visible.
Preserve current non-nwg toggle semantics until an explicit migration is approved; configured Waybar SIGUSR behavior is not the current toggle wrapper's behavior.
Validation: duplicate starts, malformed profiles, interrupted generation, consent refusal, switch-away, failed reload/restart and guarded restoration.
Done: shared activation happens once, owned-process scope is proven, and restored files versus deferred runtime recovery are reported separately.

### D01.6 — Deliver parity and acceptance evidence
Status: not started. Prerequisites: D01.2-D01.5; actual provider integration; P01-P07 disposition for affected claims.
Ownership: D01 domain tests and evidence contributions; F04 owns common infrastructure and I01 owns final integration acceptance.
Deliverables: proposed bar/dock suites, per-operation effect evidence, visual captures, accessibility results and migration limitations.
Validation: run existing regressions plus proposed suites; inspect real menus/status, mixed-DPI layouts, hotplug, keyboard focus and measured resource use.
Done: every required capability has the evidence level F04 specifies; absent hardware, untested versions and pending decisions remain visible blockers.

## 6. Shared-file contribution requests

| Shared area | Requested contribution and owner |
|---|---|
| `packages.json`, `src/packages.rs`, capability ledger | Feature dependencies and renderer references to F01; later integration through I01 |
| `setup.sh`, reliability library, managed sync list | Deliver new profiles/helpers, preserve modes and Stow topology, stage/validate before writes; F02 then I01 |
| `scripts/lib/update-waybar-roles.py` | Coordinate owned action-key changes with F02/I01; preserve JSONC grammar, arrays, comments and idempotence |
| Common Hyprland scripts and `sources_example/*.lua` | Lifecycle, activation and keybinding contributions to F02/I01; no independent dispatcher edits |
| Existing Waybar provider helpers | F02 extracts generic window mechanisms; D02-D07 own semantic providers; D01 retains presentation and compatibility-test contributions |
| `tests/run.sh`, shared fixtures, CI, documentation | Submit suite registration/evidence to F04/I01; parent alone writes canonical plan documents |

## 7. Preservation, activation, rollback and security

Keep source templates, installed configuration, generated combined profiles and runtime state distinct.
Retain schema-2/legacy inputs and independent selection; never uninstall alternatives or rewrite another role's membership.
Use F02 ownership declarations and validated merges; unknown user configuration blocks replacement rather than inviting whole-file overwrite.
Preserve custom timezone, layout, pins, output assignments and styles; do not import or migrate personal pin collections automatically.
Retain legacy helper paths and environment overrides until callers and upgrade fixtures are migrated.
Preview generated changes and process effects; absent applications remain unavailable, not auto-launched or installed.
Apply approved activation only after validation; restart shared nwg-panel once, and never terminate unrelated or foreign-owned instances.
Rollback restores bounded configuration with divergence checks; an already-started package update, snapshot or power action is not reversible configuration state.
Do not let bar reload/switching kill the independent update service; preserve duplicate-safe launches, confirmation cancellation and child-process cleanup.
Use structured argv and safe desktop-entry contracts; device names, titles, menu labels and token strings must not become shell code or unescaped markup.
Keep network addresses, SSIDs, Bluetooth aliases, window titles, notification contents and update logs out of collected evidence; use synthetic fixtures and sanitized captures.
No credentials, accounts, profiles, calendar data or application databases are accessed or migrated; privileged effects require existing authorization and separately consented testing.

## 8. Intended validation and decision gates

Existing checks, inspected but not executed: `roles_startup.sh`, `roles_controls.sh`, `roles_review_regressions.sh`, Waybar menu-contract tests and update/review wrappers.
Future existing-suite command: `bash tests/run.sh tests/shell/roles_startup.sh tests/shell/roles_controls.sh tests/shell/roles_review_regressions.sh tests/shell/waybar_updates.sh tests/shell/waybar_review_regressions.sh`.
Also retain existing membership/argv and reliability regressions identified by F02/F04; dispatch assertions are not real-effect proof.
Proposed checks: `bars_parity.sh`, `docks_behavior.sh` through the existing runner, plus D01 contribution cases in F04's proposed coverage descriptor.
Cover all nine bar/dock combinations, every menu entry, repeated activation, unavailable backends, invalid input, cancellation and rapid conflicting gestures.
Real-session acceptance includes tray interaction, workspace/submap changes, live status, dock launch/focus/pins, edge reveal, popup placement, fractional scaling and monitor removal.
No destructive power/update/firmware/snapshot operation runs in ordinary CI; isolated modeled effects precede separately authorized real-effect checks.

P01 fixes active Waybar operations, per-output bars, visible unavailable hardware and dock pins/follow-focus/fixed-primary fallback. Only the requested theme control is added to the baseline; other inactive modules remain optional.
P02 specifies Mocha/Latte and supported native appearance. P03/P04 define full-support notification/audio behavior; unsupported native providers remain selectable and limited.
P05 requires current Arch evidence; P06 permits independent partial application with safe reloads; P07 uses manual visual/functional VM testing with no numeric or physical-hardware acceptance gate.
Escalate unsupported mandatory gestures, inaccessible required workflows, unresolved dependency costs, foreign process ownership or non-recoverable configuration adoption.
No feature-filling companions are allowed. Native gaps retain the app and disable/explain the unsupported operation; they block that option's full-parity claim, not delivery of the whole branch.
Local wiki tools were unavailable and no web research occurred; future compatibility research must follow local-document routing before authoritative upstream verification.

## 9. Implementation checklist and confidence

1. Not started — D01.1: reconcile exact operations, dependencies and feasibility evidence.
2. Not started — D01.2: implement app mappings against frozen F03/F02 contracts.
3. Not started — D01.3: provide complete approved presentation across all three bars.
4. Not started — D01.4: implement approved dock workflows without new defaults.
5. Not started — D01.5: verify combined ownership, switching, activation and rollback.
6. Not started — D01.6: deliver effect, visual, accessibility and integration evidence.

Planning confidence: **93/100** for source-grounded scope and ownership; runtime feasibility is not certified.
Uncertainty remains in native gestures, alternative-app APIs, follow-focus support and provider feasibility. Product policy P01-P07 is resolved; VM-only tests cannot certify physical monitor/device behavior.

## Planning handoff

Workstream: D01 — Bars and docks; supplied source baseline: `610a18bac374e7e2ffd0bcb2d99b026131deedbc`.
Repository mutations: none; no writing, implementation, installation, activation, staging, commits or publication performed.
Inspected sources: complete master and F01-F04 drafts; bar/dock profiles, Waybar style/XML menus/hidden profile, named helper scripts, role updater, scoped package/setup/role routing anchors, domain test files and directory inventories.
Validation performed: read-only source inspection, operation/menu cross-checking, ownership/dependency review and existing-versus-proposed check separation.
Validation omitted: Git baseline verification, test execution, installed/upstream version checks, graphical sessions, screenshots, accessibility measurements and hardware effects.
Residual risks: provisional foundation contracts, native gesture ambiguity, missing alternative frontend evidence, lifecycle integration and open product decisions.
Canonical destination: `plans/planned/desktop-harmonization/D01-bars-docks.md`; parent owns canonical integration and the runtime saves this planning artifact.