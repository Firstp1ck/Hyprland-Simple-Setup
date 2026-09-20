# D07 — Session and auxiliary interfaces

Status: product policy synchronized with the completed interview; implementation not started. Apply master section 9 and the [decision record](../desktop-harmonization-grill.md); native session/security evidence remains pending.
Master: [Desktop harmonization master](../desktop-harmonization-master.md).
Supplied baseline: `610a18bac374e7e2ffd0bcb2d99b026131deedbc`, branch `feat/harmonize-visual-design`.

## 1. Scope, authority and boundaries

Cover session/login/lock/idle/logout, authentication ownership, wallpaper/nightlight, compositor appearance, capture/annotation/color picking, clipboard and auxiliary interfaces.
Contribute exhaustive remaining-generic-package classification to F01 before foundation implementation; this discovery does not depend on completed D07 adapters.
Application implementation waits for frozen F01/F02/F03/F04 contracts and the master foundation gate.
All contracts and proposed paths below remain recommendations, not implemented APIs.
Preserve application choices, defaults, selection cardinalities, primary/member distinctions, environment inputs, literal argv and reliability guarantees.
Primary controls routing; every selected member receives applicable appearance support.
Preserve dock, agent, TUI-file-manager and GUI-editor None states; GUI-editor None retains the existing TUI fallback.
D07 introduces no new selection role, catalog, action bus, theme source, transaction engine or framework.
Non-goals: ISO work, credential/account/data migration, authentication-policy changes, snapshot restoration, automatic package installation and live activation during planning.
No mandatory companions, silent approvals, reduced parity, lock bypass or guaranteed hibernation support.

## 2. Observed source evidence

Paths abbreviated as `hypr/`, `waybar/`, `wlogout/` and `satty/` are under `dotfiles/.config/`.
These are static observations, not installed-version or effect-level verification.

| Source anchor | Observation and consequence |
|---|---|
| `packages.json`; `src/packages.rs:categorized`, `role_controlled_packages` | Generic chooser categories exclude role options and role extras; preserve original source/category identities when contributing classification. |
| `hypr/sources_example/autostart.lua` | Requests both `systemctl --user start hyprpolkitagent` and `/usr/lib/polkit-kde-authentication-agent-1`; duplicate-start intent is verified, actual concurrent registration is not. |
| Same autostart template | Starts Hyprpaper, persistence/history helpers and Hypridle; optional Hyprsunset and Pyprland lines are initially commented. |
| `setup.sh` optional-extra handling | May enable Hyprsunset when its executable exists; template comments alone do not establish installed startup behavior. |
| `hypr/sources_example/app_variables.lua` | Calculator is `qalculate-gtk`, absent from the inspected catalog; color picker is `hyprpicker --autocopy --format hex`. |
| `hypr/sources_example/keybindings.lua` | Three Hyprshot modes pipe raw output to Satty; session shortcuts call Waybar's power helper; Music constructs terminal `-e` routing directly. |
| `waybar/scripts/power_action.sh` | Six actions use notification plus three-second delay; logout falls back from compositor exit to session termination, then user-wide termination without a session ID. |
| `wlogout/layout` | Bypasses that helper: direct loginctl/systemctl actions, including user-wide logout; current frontends therefore have different semantics. |
| `hypr/hypridle.conf` | Brightness dims at 240 seconds and restores on activity; lock requested at 300 seconds; before-sleep requests lock, after-sleep enables DPMS. |
| `hypr/hyprlock.conf` | Screenshot background with blur, Catppuccin include, literal gradients/font values and German placeholder; authentication success/readiness is not demonstrated. |
| `hypr/scripts/change_wallpaper.sh` | Parses Lua data without executing it, retries IPC, targets fallback/configured/active outputs, publishes readiness after successful requests and atomically updates a wallpaper cache link. |
| `waybar/scripts/launch_power_screen.sh` | Checks Wlogout availability, uses cached wallpaper with fallback warning, then launches layer-shell UI. |
| `hypr/scripts/hyprsunset.sh` | Contains two sequential switching implementations: kill/start with shader inspection, then temperature query/change; no reliable single toggle contract is established. |
| `satty/config.toml` | Copy command, save-after-copy, output filename, tools and annotation palette are configured; visual changes must not silently alter persistence behavior. |
| `waybar/scripts/clipboard.sh` | Selected terminal, stable window identity, five-second discovery and Fzf history selection; payload passes through an embedded shell pipeline. |
| `waybar/scripts/keybinds.py:KeybindsConfig` | Tk/ttk appearance uses hardcoded colors/fonts; parser and menu-contract tests exist separately from visual acceptance. |
| `hypr/scripts/notes.sh` | Uses selected terminal and TUI editor, preserves `HSS_NOTES_DIR`, creates/lists files; input paths need containment review without moving existing notes. |
| `hypr/scripts/play_music.sh` | Streams a fixed remote album through `ffplay`, uses indexed terminal colors and `/tmp/nightfall_control`; catalog lacks `ffmpeg`. |
| `waybar/scripts/snapshot.sh` | Executes `pkexec timeshift --create --comments "Manuel Snapshot"`; successful authentication or snapshot creation is unverified. |
| `setup.sh:configure_sddm_theme` | Clones Eucalyptus Drop when needed, copies into `/usr/share/sddm/themes`, writes theme selection under `/etc/sddm.conf.d`, then removes the download directory. |
| `hypr/sources_example/look_and_feel.lua` | Literal borders, spacing, opacity, blur and animations provide D07 compositor-renderer targets; behavior/layout keys need preservation. |

## 3. Exact package classification contribution

This is a source-grounded contribution to F01's single ledger, not a second authoritative catalog.
Classes: **T** themed interface; **A** integrated action; **B** backend dependency; **O** outside visual scope.
One primary class per listed package; secondary capabilities and final implementation owner remain ledger fields.
Toolkit hints require compatibility evidence; package descriptions alone do not certify GTK/Qt/Electron/libadwaita versions.
Original category spelling, including `desktop_evnironment`, must survive reconciliation.

| Source/category | Remaining generic exact packages grouped by primary class |
|---|---|
| Pacman `core_hyprland` | T: `hyprlock`, `hyprland-guiutils`, `hyprland`; A: `hyprpaper`, `hyprpicker`, `wl-clipboard`, `hyprsunset`; B: `hyprcursor`, `hypridle`, `hyprpolkitagent`, `wl-clip-persist`, `hyprgraphics`, `hyprland-qt-support`, `python`, `python-requests`, `python-pyquery`, `tk`, `xorg-xwayland`, `xdg-desktop-portal-hyprland`; O: `hyprwayland-scanner`, `arch-wiki-docs`. |
| Pacman `desktop_evnironment` | T: `htop`; A: `grim`, `slurp`; B: `iwd`, `polkit-kde-agent`, `qt5-wayland`, `qt6-wayland`, `wpa_supplicant`, `xdg-utils`; O: `openssh`, `smartmontools`, `wget`, `wireless_tools`. |
| Pacman `graphics_driver` | O: `intel-media-driver`, `libva-intel-driver`, `libva-mesa-driver`, `mesa`, `vulkan-intel`, `vulkan-nouveau`, `vulkan-radeon`, `xf86-video-amdgpu`, `xf86-video-ati`, `xf86-video-nouveau`, `xorg-server`, `xorg-xinit`. |
| Pacman `greeter` | T: `sddm`. |
| Pacman `audio` | B: `pipewire`, `pipewire-pulse`, `wireplumber`, `pulseaudio-qt`. |
| Pacman `kernel` | O: `linux`, `linux-headers`, `linux-api-headers`, `linux-firmware`. |
| Pacman `file_management` | T: `onefetch`, `fzf`, `ark`, `timeshift`, `satty`; B: `xdg-user-dirs`, `stow`, `7zip`, `grub-btrfs`, `inotify-tools`; O: `git`, `fd`. |
| Pacman `screenshots` | A: `hyprshot`. |
| Pacman `system_integration` | B: `xdg-desktop-portal-gtk`, `xdg-desktop-portal-kde`, `gnome-keyring`, `bluez`, `bluez-utils`; A: `ddcutil`. |
| Pacman `theming` | T: `cava`, `qt5ct`, `qt6ct`, `nwg-look`; B: `ttf-jetbrains-mono-nerd`, `ttf-nerd-fonts-symbols`, `ttf-nerd-fonts-symbols-common`, `otf-font-awesome`, `breeze`, `breeze5`, `breeze-gtk`. |
| Pacman `cli_tools` | T: `dysk`, `duf`, `bat`, `eza`, `btop`, `starship`, `fastfetch`, `tldr`, `psensor`; A: `playerctl`, `brightnessctl`, `reflector`; B: `firewalld`, `libnotify`, `jq`; O: `zoxide`, `lshw`, `ntfs-3g`. |
| AUR `core_hyprland` | B: `pyprland`. |
| AUR `gui_tools` | T: `github-desktop-bin`, `wlogout`. |
| AUR `theming` | T: `waypaper-git`; B: `rose-pine-hyprcursor`. |
| AUR `system_integration` | B: `xwaylandvideobridge`, `wl-clipboard-history-git`, `waybar-module-pacman-updates-git`; T: `input-remapper`. |
| AUR `cli_tools` | A: `lsplug`; T: `pacsea-bin`, `usrgrp-manager-bin`. |
| Remaining groups | Pacman `shell`, `browser`, `gui_tools`; AUR `browser`; official `coding_agents`: all entries are role-controlled options/extras, leaving no generic residual. |

O means no dedicated desktop renderer: kernel/graphics/protocol/build, storage, network or general CLI infrastructure remains available and unchanged.
`arch-wiki-docs` content remains outside visual scope; its browser-opening workflow remains covered.
Backend classification does not authorize competing network/authentication services or change required/default package status.
F01 must mechanically verify catalog-minus-role/extras set equality; this manual classification is not an executed completeness test.
Role-controlled extras still needing cross-domain coverage: `plasma-systemmonitor`, `zenity`, `fwupd`, `pacman-contrib`, `curl`, `less`, `lm_sensors`.
D07 covers their auxiliary-interface/action boundaries with D01; existing update orchestration remains preserved rather than duplicated.
Other excluded extras are `vivaldi-ffmpeg-codecs`, `kcmutils`, `plasma-workspace`, `bemenu-wayland`, `nodejs`, `npm`, `tar`, `gzip`; their role owners/F01 retain dependency coverage.
F03 owns global assets/toolkit settings; D04 owns device backends; D05 owns shell/prompt integration, including `starship`; D07 supplies classification rather than competing implementations.
Uncataloged `qalculate-gtk` and `ffplay` requirements are unresolved dependency findings, not approved additions.

## 4. Capability, appearance and handoff contracts

All proposed action names below are illustrative; F01/F02 freeze identities, outcomes and compatibility rules.
D07 provider implementations must operate without importing panel configuration or requiring Waybar to be selected.

| Surface/action | Proposed contract and F03 mapping |
|---|---|
| Lock/idle | Separate request, observed locked state and failure; retain authentication boundary. Map readable input, focus, error/check states, typography and approved opaque/privacy variants. |
| Power/logout | Shared six-action semantics for panels, keys and Wlogout; distinguish accepted request from completed effect. Map action emphasis and keyboard focus, never conceal unsupported actions as success. |
| Authentication | Hyprpolkitagent is the managed owner. Remove the duplicate setup-owned KDE startup request, but never terminate a foreign owner automatically. Native toolkit appearance only; no credential handling or authentication bypass. |
| SDDM | Separate privileged greeter deployment descriptor; map supported theme keys/assets only after isolated feasibility. User-session GTK/Qt settings are not proof of greeter theming. |
| Wallpaper/nightlight | Preserve chosen image/source and output targeting; report partial output failures and unknown temperature. F03 controls appearance tokens, not wallpaper content or unapproved temperature defaults. |
| Capture/Satty/Hyprpicker | Window/output/region, annotation, copy/save and hex-copy remain distinct effects; cancellation produces no unintended copy/save. Annotation content colors are not automatically UI-token colors. |
| Clipboard | Preserve history browsing, selection and stable terminal presentation; distinguish cancellation, missing history provider and command failure. No content in status/log envelopes. |
| Tk/Zenity/calculator | Tk consumes explicit F03 renderer output; native dialogs/calculator consume verified toolkit mappings; do not replace native confirmation with a new framework. |
| Notes/Music/TUIs | D05 terminal routing and palette contract; preserve Notes storage/editor and Music behavior. Screen size, text contrast and remote access limits are disclosed. |
| Administration/other GUIs | Native-toolkit or native-constrained coverage for monitors, Timeshift, Ark, GitHub Desktop, package/user tools and input remapping; authentication remains provider-owned. |
| Compositor | D07 renders F03 spacing, border, focus, opacity and motion tokens; retain unrelated layout/input behavior and expose explicit reduced-motion handling. |

Outcomes must distinguish disabled None, deselected optional package, missing executable, unsupported feature, unavailable hardware/session, cancellation, denial, timeout and command failure.
No renderer starts a service, discovers secrets, installs dependencies or mutates live settings.
Native-constrained appearance is an explicit limitation, not a full-parity claim.

| Producer → consumer | Deliverable and dependency |
|---|---|
| D07.1 → [F01](F01-inventory-capability-contracts.md) | Pre-foundation generic classification, dependencies, privacy boundaries, singleton findings and candidate observable outcomes. |
| D07.1 → F02.1/F02.4 | Pre-foundation authentication ownership/readiness specification, conflict and failure cases, scope across sessions, and P01/P05/P06 approval conditions. The specification precedes the foundation gate; D07.2 implements it afterward. |
| [F02](F02-runtime-managed-configuration.md) → D07 | Frozen action/status, lifecycle, managed-output and activation contracts; retain compatibility wrappers and source/runtime separation. |
| [F03](F03-visual-system-theme-generation.md) → D07 | Frozen tokens/assets/renderer registration; D07 supplies application mappings, validators and activation intent. |
| [F04](F04-verification-foundation.md) ↔ D07 | Shared isolated harness and coverage descriptors; D07 supplies security, effect and visual scenarios before the gate, implementations afterward. |
| [D02](D02-launchers-shared-menus.md) → D07 | Selection/confirmation/cancellation contract for shared menu consumers without shell reconstruction. |
| [D05](D05-terminal-workspace-agents.md) → D07 | Selected-terminal argv/window identity and terminal appearance; preserve all five terminal choices and editor routing. |
| D07 → [D01](D01-bars-docks.md) | Panel-independent power/session actions, capability/status records and auxiliary launch contracts; D01 owns widgets/menu presentation. |
| D07 ↔ [D06](D06-applications-default-handlers.md) | Ark/GitHub Desktop/capture association boundaries; D06 owns handler policy, not D07. |
| D07 → [I01](I01-integration-rollout-acceptance.md) | Serialized contribution packet, dependency previews, upgrade/rollback notes and evidence; parent owns canonical documentation. |

## 5. Implementation work packages

### D07.1 — Reconcile discovery and freeze domain requirements
Prerequisites: implementation authorization for future work; discovery/specification may precede Gate A.
Ownership: D07 evidence and domain descriptors; F01 alone reconciles the authoritative ledger.
Deliverables: exact package disposition, action/caller inventory, toolkit uncertainties, P01/P05 dependency briefs and the authentication ownership/readiness specification required by F02.1/F02.4.
Specify owner scope, existing/foreign-owner detection, readiness observations, duplicate-start prevention, failure behavior and the choices requiring P01/P05/P06 approval. Deliver this contract to F02 before the foundation gate, without starting or replacing an authentication agent.
Include two polkit starters, calculator/Music missing dependencies, power-path divergence and system-wide SDDM boundary.
Validation: proposed catalog set-equality check through F01/F04; inspect every remaining package and role-extra handoff.
Done: no orphan generic entry; each dependency/security decision has an owner and blocking impact, without waiting for adapters.

### D07.2 — Establish secure session, authentication and shared power adapters
Prerequisites: foundation gate; frozen D07.1 semantics; P01/P05 and relevant P06 decisions.
Ownership: D07 provider module at **proposed** `dotfiles/.config/hypr/scripts/session_control.sh`; existing Hyprlock/Hypridle and Wlogout profiles.
Deliverables: implementation of the approved D07.1 authentication ownership/readiness specification, unified six-action adapter and compatibility contribution for `power_action.sh`. D07.2 does not originate the pre-foundation specification.
Apply the resolved policy: confirm logout/reboot/shutdown, keep lock immediate and suspend direct, and expose hibernate only when prerequisites are verified. Logout targets the current session only and fails safely when identification fails; never fall back to user-wide termination. Verify lock-readiness/sleep ordering separately.
Validation: **proposed** `tests/shell/session_auxiliary.sh` uses isolated doubles for duplicate requests, denial, lock failure, absent session ID and uncertain timeout.
Done: approved frontends share outcomes; no duplicate authentication startup, automatic power retries, false lock success or unapproved user-wide termination.

### D07.3 — Render login, lock, logout and compositor appearance
Prerequisites: foundation gate, D07.2 ownership contract, P02/P05; privileged activation additionally requires P06.
Ownership: D07 application registrations under **proposed** `theme/renderers/d07/`; existing lock/logout profiles; shared Lua/setup changes requested through I01.
Deliverables: deterministic F03-consumer mappings, asset closure, validators, preserved keys and per-surface deferred/reload activation descriptors.
SDDM feasibility must separate remote theme acquisition, privileged copying, theme selection, service enablement and restoration.
Validation: **proposed** `tests/shell/session_auxiliary_rendering.sh`; synthetic greeter/lock scenes, missing assets, Stow links, overrides and reduced-motion cases.
Done: supported outputs validate deterministically; greeter deployment remains blocked unless privileged transaction/recovery is explicitly supported.

### D07.4 — Preserve wallpaper, nightlight, capture and clipboard effects
Prerequisites: foundation gate; D02 chooser and D05 terminal contracts; approved dependency/persistence policy.
Ownership: D07 existing wallpaper/nightlight helpers, Satty config and clipboard provider behavior; caller changes serialized through I01.
Deliverables: bounded nightlight feasibility result, preserved wallpaper readiness/cache behavior and capture/copy/save outcome mappings.
Separate wallpaper producer/cache consumer, avoid killing foreign providers, and preserve current terminal/window discovery contracts during extraction.
Validation: proposed D07 suites cover output hotplug, unavailable session, retry exhaustion, chooser cancellation, hostile filenames and synthetic clipboard payloads.
Done: each action has an independent observable effect or explicit blocker; no clipboard logging, changed save defaults or panel backend dependency.

### D07.5 — Adapt custom dialogs and auxiliary application surfaces
Prerequisites: foundation gate, D02/D05 contracts, D07.1 package assignments and approved calculator/Music dependency disposition.
Ownership: D07 `keybinds.py`, Notes/Music helper contributions and auxiliary renderers; shared launcher/helper edits remain coordinated with F02/I01.
Deliverables: Tk token mapping, native toolkit support records, terminal-based interface mappings and snapshot/package/user action boundaries.
Preserve keybinding parsing/favorites, Notes location/editor, Music content and current administrative argv; propose security changes separately where compatibility differs.
Validation: existing keybind tests plus proposed keyboard/focus, small-window, terminal-option, path-containment, FIFO ownership and synthetic authorization cases.
Done: every assigned interface has supported/native-constrained evidence or an explicit blocker; no data movement, silent dependency addition or privileged operation in tests.

### D07.6 — Integrate migration, evidence and release handoff
Prerequisites: D07.2–D07.5; F04 descriptors; P06 activation and P07 acceptance decisions.
Ownership: D07 domain tests/support notes; F04 common runner, I01 shared-file wiring and final release evidence.
Deliverables: legacy caller matrix, managed-output ownership map, upgrade preview, rollback procedure and selected-member/None regression evidence.
Validation: existing suites and proposed D07 suites; authorized isolated graphical/hardware scenarios only after offline gates.
Done: I01 accepts source/config/runtime-separated evidence, remaining blockers and rollback limits; documentation completion never marks implementation complete.

## 6. Shared-file requests, preservation and security

Request F01/I01 package metadata changes for verified theme assets and genuine dependencies of existing native workflows, including calculator/Music prerequisites where needed, with a package preview. Feature-filling companion packages remain excluded.
Request F02/I01 serialized `setup.sh`, managed-sync lists, common adapters and reliability-library changes; retain executable modes and legacy entry points.
Request I01 Lua contributions for autostart, keybindings, app/environment variables and window rules; D07 specifies session/security behavior.
Coordinate `look_and_feel.lua` appearance edits with F03 tokens; D01 owns panel configuration and compatibility caller wiring.
Request F04/I01 runner/fixture registration; parent alone writes canonical plans and I01 integrates user documentation.
Preserve existing schema-2 role inputs, custom commands, primary/member routing and optional None behavior; deselection does not uninstall applications.
Preview managed-key adoption; retain Stow symlinks, user overrides, modes and existing reliability backups through F02.
Stage/validate before commit; ambiguous ownership blocks replacement; rollback restores managed configuration without clobbering later user edits.
Theme application must not unlock, restart a locked session, terminate unsaved applications or restart the greeter automatically.
File rollback cannot undo poweroff, logout, snapshot creation or disclosure of clipboard/screenshot content; report these boundaries separately.
Use synthetic capture/history/notes in tests; never collect passwords, authentication responses, personal wallpaper paths or private content in evidence.
Review clipboard shell interpolation, Notes traversal and shared `/tmp/nightfall_control` ownership before extending those paths; do not silently change established argv.
Do not broaden privileged write allowlists for SDDM or reuse/delete an existing user download tree without explicit ownership approval.
Snapshot/package/user tools retain native authorization; no stored sudo passwords, polkit rule weakening, credential migration or automatic administrative action.

## 7. Intended validation and decision gates

Existing checks discovered, not executed: `roles_matrix.sh`, `roles_validation.sh`, `roles_lua_argv.sh`, `roles_membership.sh`, `startup_triage.sh`, `waybar_keybinds.sh` and reliability suites under `tests/shell/`.
Inspected assertions cover clipboard terminal argv/window handling, SDDM setup ordering and keybinding parsing; they do not prove secure locking or graphical parity.
Future existing command: `bash tests/run.sh tests/shell/roles_matrix.sh tests/shell/roles_membership.sh tests/shell/waybar_keybinds.sh`.
Future proposed command: `bash tests/run.sh tests/shell/session_auxiliary.sh tests/shell/session_auxiliary_rendering.sh`.
Offline tests must fail closed before contacting host loginctl/systemctl/pkexec, compositor sockets, clipboard or authentication services.
Later user VM tests check the lock boundary, readable focus and dark/light behavior on available virtual outputs. Preserve existing accessibility preferences; physical hotplug/mixed-DPI/power behavior remains unverified where unavailable.
Suspend/resume requires separately approved hardware evidence; hibernate remains unsupported/unverified until its platform prerequisites and effects are independently demonstrated.
P01/P02/P06 settle native workflows, Mocha/Latte appearance, Hyprpolkitagent ownership, power confirmations, current-session logout, preview/preservation and safe reloads. Privileged greeter deployment and native locking behavior still need safe implementation evidence; product policy does not authorize live operations.
P05/P07 target current Arch packages and manual VM visual/functional testing, without numeric budgets or physical certification. Physical suspend/hibernate/hotplug and radio/audio effects remain unverified where the VM cannot exercise them.
P03 forbids notification content while locked and allows critical popups only during unlocked DND; D07 must verify the lock boundary without companions. Do not add services to fill notification/audio gaps.
Escalate any required lock bypass, competing owner, unsafe privileged restoration, unavoidable data migration, new default or infeasible mandatory capability.
No local-wiki tools were available; no web research or upstream/version claim was made. Future API verification must follow local-document routing.

## 8. Not-started checklist and confidence

1. Not started — D07.1: reconcile inventory, dependencies and pre-foundation specifications.
2. Not started — D07.2: implement approved secure session/authentication/power semantics.
3. Not started — D07.3: render and validate session, greeter and compositor surfaces.
4. Not started — D07.4: verify wallpaper, nightlight, capture and clipboard adapters.
5. Not started — D07.5: adapt custom dialogs and auxiliary applications.
6. Not started — D07.6: complete migration, evidence and integration acceptance.

Planning confidence: **91/100** for source-grounded scope and ownership; runtime feasibility is unverified.
Confidence is limited by native configuration surfaces, concrete foundation interfaces and absent graphical/security/hardware tests. Product choices are resolved in the interview.

## Planning handoff

Workstream: D07 — Session and auxiliary interfaces.
Supplied source baseline: `610a18bac374e7e2ffd0bcb2d99b026131deedbc`; branch `feat/harmonize-visual-design`; not independently checked with Git.
Repository mutations: none; no write/edit/bash, installation, activation, commit, publication or delegation performed.
Inspected sources: complete master and F01–F04 drafts; complete catalog; scoped Rust filtering; Lua templates; session/capture profiles; named Hyprland/Waybar helpers; SDDM setup; scoped test assertions.
Validation performed: read/grep/find/ls source inspection, manual package classification, dependency/ownership review and existing-versus-proposed check separation.
Validation omitted: test execution, Git verification, installed/upstream compatibility, live effects, screenshots, credential access and hardware testing.
Residual risks: authentication conflicts, divergent power semantics, lock readiness, privileged SDDM recovery, nightlight ambiguity, missing dependencies and sensitive-content handling.
Canonical destination: `plans/planned/desktop-harmonization/D07-session-auxiliary-interfaces.md`; parent alone reconciles and writes the canonical plan.