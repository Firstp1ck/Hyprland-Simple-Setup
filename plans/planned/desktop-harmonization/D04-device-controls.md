# D04 — Network, Bluetooth and audio controls

Status: product policy synchronized with the completed interview; implementation not started. Apply master section 9 and the [decision record](../desktop-harmonization-grill.md); native device capability and physical effects remain unverified.
Master: [Desktop harmonization master](../desktop-harmonization-master.md).
Supplied baseline: `610a18bac374e7e2ffd0bcb2d99b026131deedbc`, branch `feat/harmonize-visual-design`.
Canonical destination: `plans/planned/desktop-harmonization/D04-device-controls.md`.

## 1. Scope and boundaries

Cover all four network, four Bluetooth and five audio options, preserving existing selections and launch behavior.
Separate application opening, network connection, profile editing, radio control, pairing, hardware mixing and per-application routing.
Supply presentation-free actions/status to panels and shared menus; application appearance consumes F03 and terminal appearance consumes D05.
Discovery and contract contributions may precede foundation implementation; application implementation waits for frozen F01/F02/F03/F04 contracts.
All interfaces below are proposals, not implemented APIs or approved product policy.
No competing catalog, action bus, theme source, transaction mechanism, desktop shell or test framework is introduced.
Do not add feature-filling companions, migrate credentials/data or automatically change connections, profiles or audio routes. Native-API adapters and genuine dependencies of existing native workflows are allowed with a package preview.
Network, Bluetooth and audio are required single-choice roles; no new None option is proposed.
Preserve existing None states for dock, agents, TUI file manager and GUI editor, including their role-specific behavior.
Primary controls routing; all selected members remain eligible for applicable appearance support, including non-primary terminals.

## 2. Observed source evidence

These are static source observations, not executed tests or verified application compatibility.

| Anchor | Observation and consequence |
|---|---|
| `packages.json:roles.network` | Four choices; default `plasma-nm`; nmtui is terminal-wrapped; Plasma uses `plasmawindowed org.kde.plasma.networkmanagement` with `plasma-workspace` extra. |
| `packages.json:roles.bluetooth` | Four choices; default `bluedevil`; Bluedevil uses `kcmshell6 kcm_bluetooth` with `kcmutils`; both TUI choices are terminal-wrapped. |
| `packages.json:roles.audio` | Five choices; default `pavucontrol-qt`; `qastools` launches `qasmixer`, `alsa-utils` launches `alsamixer`; Alsamixer/Ncpamixer are terminal-wrapped. |
| `packages.json` infrastructure lists | NetworkManager, BlueZ/BlueZ utilities, PipeWire, PipeWire-Pulse and WirePlumber are cataloged; package presence does not establish running services. |
| `waybar/scripts/nmtui.sh`, `nmtui-connect.sh` | Both execute `role_exec.sh network "$@"`; their names do not establish distinct connect/edit operations. |
| `waybar/scripts/audio_control.sh`, `alsamixer.sh` | Both execute `role_window.sh audio "$@"`; right click does not necessarily launch Alsamixer. |
| `waybar/scripts/bluetooth_manager.sh` | Opens the selected Bluetooth role through `role_exec.sh`, forwarding arguments. |
| `hypr/scripts/toggle_bluetooth.sh` | Parses `bluetoothctl show`; failed/empty observation can enter the power-on branch; notifications are not conditioned on successful power changes. |
| `hypr/scripts/role_exec.sh` | Uses primary metadata and argv arrays; terminal roles receive stable `hss-$role` identifiers through `term_exec.sh`. |
| `hypr/scripts/role_window.sh` | Audio GUI classes are explicit; TUI audio uses role execution; GUI placement requests 70% by 70% through the Waybar helper. |
| `waybar/scripts/launch_qt_gui.sh` | Checks executable availability, focuses an existing matching window, otherwise launches and polls 80 times at 0.1 seconds. |
| `waybar/config.jsonc` | Active network/Bluetooth/audio modules expose status; network tooltips promise picker/editor despite identical wrappers. |
| `hypr/sources_example/keybindings.lua` | Volume and microphone bindings use `wpctl`, independently of selected audio GUI/TUI; preserve their existing argv. |
| `hypr/sources_example/autostart.lua` | Blueman applet/tray lines are commented optional extras; no active device-applet lifecycle is established by this template. |
| `setup.sh` managed-helper list | Includes the five Waybar wrappers and `role_window.sh`; future modules need explicit delivery/mode handling contributions. |
| `tests/shell/roles_matrix.sh` | Enumerates 73 catalog cases and schema-2 metadata; device roles have no dedicated effect assertions in its role-consumer branch. |

Abbreviated `hypr/` and `waybar/` paths above are under `dotfiles/.config/`.
The matrix checks generic wrapper behavior; its final success message is source text, not a result obtained here.
No local-wiki or upstream claim is made: routed wiki tools were unavailable, and no web research was performed.
Future compatibility research must inspect local ArchWiki/Hyprland documentation first and record actual target platform/version evidence.

## 3. Complete option and appearance coverage

Capability/family descriptions below are planning classifications requiring F01 evidence, not guarantees about installed versions.
F03 owns global toolkit settings; D04 registers app-specific mappings only where supported configuration surfaces exist.

| Option identity → preserved launch | Capability investigation | Theme route |
|---|---|---|
| `network/network-manager-applet` → `nm-applet` | Persistent tray workflow, connection selection, editor access, duplicate-launch behavior | GTK mapping through F03; tray presentation through D01 |
| `network/nm-connection-editor` → `nm-connection-editor` | Profile editing versus connection selection; prove a bounded connect path separately | GTK through F03 |
| `network/networkmanager` → `nmtui` | Separate connection/edit entry points without changing legacy role-open argv | D05 terminal plus verified native TUI controls |
| `network/plasma-nm` → `plasmawindowed org.kde.plasma.networkmanagement` | Windowed network UI, connection/editor reachability outside a full Plasma session | F03 Qt/KDE/QML mapping; verify actual adoption |
| `bluetooth/blueman` → `blueman-manager` | Device management, pairing agent, optional applet lifecycle | GTK through F03 |
| `bluetooth/bluedevil` → `kcmshell6 kcm_bluetooth` | Pairing and authorization outside Plasma; required component readiness | F03 Qt/KDE mapping |
| `bluetooth/bluetui` → `bluetui` | Keyboard discovery/pair/connect workflow and pairing-agent ownership | D05 terminal; native palette only if verified |
| `bluetooth/bluetuith` → `bluetuith` | Keyboard discovery/pair/connect workflow, cancellation and agent lifetime | D05 terminal; native palette only if verified |
| `audio/pavucontrol` → `pavucontrol` | Output/input and per-application controls; backend compatibility | GTK through F03 |
| `audio/pavucontrol-qt` → `pavucontrol-qt` | Output/input and per-application controls; backend compatibility | Qt through F03 |
| `audio/qastools` → `qasmixer` | ALSA hardware mixing, not assumed stream routing; P04 | Qt through F03 |
| `audio/alsa-utils` → `alsamixer` | ALSA hardware mixing, not assumed stream routing; P04 | D05 terminal and verified native palette limits |
| `audio/ncpamixer` → `ncpamixer` | Terminal stream/mixer capabilities require effect verification | D05 terminal and verified native palette limits |

Retain every executable, catalog argument and extra-package relationship unless an explicit reviewed contract change is approved.
Do not force GUI configuration onto TUIs or create app overrides merely to duplicate F03 global settings.
Register native-constrained appearance honestly; keyboard focus, non-color state cues and readable errors remain acceptance requirements.
Use F03's approved Mocha/Latte dark/light inputs and preserve existing accessibility preferences; no additional mandatory visual variants.

## 4. Proposed semantic contracts

F01 owns capability identities; F02 freezes invocation, result, lifecycle and status formats.
The following illustrative operation names are contributions to those contracts, not a separate API.

- Network: `network.open`, `network.connect.choose`, `network.profile.edit`, `network.radio.set`, `network.status`.
- Bluetooth: `bluetooth.open`, `bluetooth.discover`, `bluetooth.pair`, `bluetooth.connect`, `bluetooth.disconnect`, `bluetooth.radio.set`, `bluetooth.status`.
- Audio: `audio.open`, output/input volume and mute operations, `audio.hardware.open`, `audio.streams.open`, explicit stream-route selection and `audio.status`.
- Separate “open interface” from “completed state change”; launching a profile editor must not imply a connection was changed.
- Profile saving, connection activation, pairing, radio changes and route changes require explicit user action; status/rendering never performs them.
- Prefer explicit radio targets over blind toggles; a legacy toggle must first obtain valid state and must not guess after query failure.
- Pairing, trust and connection are separate outcomes; do not auto-trust, auto-connect or remove bonds as a pairing side effect.
- Stable opaque target IDs carry device/profile/stream identity; display labels are never executable commands or sole identity keys.
- Fresh observations must revalidate selected targets before mutation; disappearing devices produce unavailable outcomes, not fallback changes.
- Results distinguish completed, accepted-but-unobserved, cancelled, unsupported, missing dependency, permission denied, unavailable hardware, timeout and failure.
- No automatic retry of uncertain connection, pairing or routing operations; cancellation never selects a fallback target.
- Read-only network status separates backend availability, interface/link state, radio state, address state and unknown connectivity.
- Bluetooth status separates backend availability, controller inventory, selected controller, power/block state, pairing/connection state and optional battery data.
- Audio status separates backend availability, output/input endpoint, volume/mute, hardware availability and supported stream controls.
- All status includes freshness/error information; absent hardware, disabled radio, disconnected device and stale observation are distinct.
- Keep shared status free of icons, markup and tooltip prose; D01/D02 own presentation and escaping.
- Queries/subscriptions are bounded through F02; status must not trigger active scans. P07 requires functional/manual VM checks, not numeric refresh budgets. Missing hardware remains visible as unavailable, distinct from disabled/error/stale states.

Persistent applets use F02 lifecycle ownership rather than repeated background launches on every click.
Prove nm-applet process/readiness/tray behavior; optional Blueman applets must not be silently activated or duplicated.
A tray disappearing during panel switching is not proof the applet died; expose degraded reachability without spawning replacements.
Coordinate BlueZ pairing-agent and authentication-provider requirements with D07; never add a competing agent to hide an unavailable workflow.

## 5. Producer-consumer handoffs

| Producer → consumer | Required handoff and gate |
|---|---|
| [F01](F01-inventory-capability-contracts.md) → D04 | Approved option/capability identities, dependency closure, P01/P04/P05 dispositions and support evidence format |
| D04 → F01 | Thirteen option mappings, connect/edit distinction, applet/agent requirements and ALSA-versus-stream feasibility brief; specification may precede Gate A |
| [F02](F02-runtime-managed-configuration.md) → D04 | Frozen action/status, lifecycle, managed-output and compatibility contracts after foundation acceptance |
| D04 → F02 | Provider outcomes, radio-state guards, cancellation/timeout rules and persistent-process requirements before interface freeze |
| [F03](F03-visual-system-theme-generation.md) → D04 | Token/renderer inputs, toolkit mappings, asset resolution and activation classifications |
| [F04](F04-verification-foundation.md) ↔ D04 | Coverage descriptors and isolated doubles in; domain scenarios, modeled/real-effect oracles and evidence out |
| [D02](D02-launchers-shared-menus.md) ↔ D04 | Typed chooser/confirmation and cancellation contract in; labeled device/profile/stream records and action results out |
| [D05](D05-terminal-workspace-agents.md) → D04 | Selected-terminal routing, literal argv, stable window identifiers and terminal appearance |
| D04 → [D01](D01-bars-docks.md) | Backend actions/status and availability fixtures; D01 owns panel widgets, gestures, tray and formatting |
| D04 ↔ [D07](D07-session-auxiliary-interfaces.md) | Authentication/pairing-agent ownership and backend readiness requirements without taking over session policy |
| D04 → [I01](I01-integration-rollout-acceptance.md) | Serialized shared-file contributions, support limitations, activation preview and acceptance evidence |

Backend implementation must not import D01 panel paths; menus consume device contracts rather than define them.
Foundation discovery must not wait for completed D04 adapters; later frontend wiring waits for tested providers.

## 6. Work packages

### D04.1 — Freeze device capability contributions

Status: not started. Prerequisite: authorization for discovery/feasibility; foundation drafts suffice for specification only.
Ownership: D04 evidence and contribution content; F01 owns the capability ledger and F04 owns shared coverage descriptors.
Deliverables: all thirteen option rows, operation/outcome matrix, applet/agent inventory, configuration surfaces and P04 decision brief.
Validation: trace every current wrapper/gesture; identify missing connect/edit paths and prove risky assumptions only in separately authorized isolated spikes.
Done: each required operation has an evidence requirement, owner and explicit blocker; no unapproved companion or inferred native capability passes as supported.

### D04.2 — Implement network separation and applet lifecycle

Status: not started. Prerequisites: frozen foundation gate, D04.1 network specification and D02 chooser contract.
Ownership: D04 provider module at proposed `dotfiles/.config/hypr/scripts/device_network.sh`; compatibility-wrapper changes coordinated with F02/I01.
Deliverables: distinct connect/edit/radio/status adapters for all four choices, plus nm-applet lifecycle/reachability behavior.
Keep legacy `nmtui.sh` and `nmtui-connect.sh` argv behavior during extraction; wire distinct semantics through separately reviewed frontend changes.
Validation: modeled connect versus profile-save effects, cancellation, duplicate clicks, missing tray/backend, denied authorization, rfkill, multiple interfaces and target disappearance.
Done: every choice exposes approved workflows or remains explicitly blocked; no status query, applet start or theme activation changes profiles/connections.

### D04.3 — Implement Bluetooth controls and pairing boundaries

Status: not started. Prerequisites: frozen foundation gate, D04.1 pairing specification, D02 chooser and D07 ownership agreement.
Ownership: D04 proposed `dotfiles/.config/hypr/scripts/device_bluetooth.sh` and `toggle_bluetooth.sh`; shared dispatcher changes remain F02/I01-owned.
Deliverables: four selected-manager routes, explicit radio operations, honest status and pairing workflow/error mapping.
Retain `bluetooth_manager.sh` compatibility; replace unconditional success notifications only through reviewed behavior migration.
Validation: no controller, multiple controllers, blocked/off states, missing BlueZ, foreign pairing agent, passkey refusal, cancellation, timeout and controller hot-unplug.
Done: independently observed state backs success; failed queries never cause power-on, and pairing cancellation leaves no unintended trust/connection change.

### D04.4 — Implement native audio controls and honest support limits

Status: not started. Prerequisites: frozen foundation gate and D04.1 native evidence; P04 product policy is resolved and excludes companions.
Ownership: D04 proposed `dotfiles/.config/hypr/scripts/device_audio.sh`; F02 owns shared window routing; I01 integrates media-key contributions.
Deliverables: five preserved application routes, output/input status/control semantics and separate hardware-versus-stream capability declarations.
For QasMixer/Alsamixer, preserve the native hardware-mixer route and mark per-app routing unsupported unless native evidence proves it exists. Do not add a companion mixer, substitute another selected app or emulate the missing feature.
Validation: independent hardware-mixer and stream-route oracles; missing server/card, no streams, denied control, unplugged endpoints and vanished streams.
Done: full-support options demonstrate native per-app volume/routing; ALSA-only options remain selectable with limited status and explicit unsupported stream controls. This does not block branch delivery.

### D04.5 — Register appearance and reversible activation

Status: not started. Prerequisites: frozen foundation gate, verified app surfaces, F03 renderer interface and P02/P06 approvals where applicable.
Ownership: D04 app mappings under proposed `theme/renderers/device-controls/`; F03 owns registration/global settings and D05 owns terminal profiles.
Deliverables: deterministic app-specific outputs or explicit global/native-constrained bindings, validators, managed-key ownership and deferred/reload classifications.
Validation: all thirteen mappings, non-primary terminal coverage, missing assets, output collisions, user overrides, Stow links and failure before/after commit.
Done: approved variants are readable and keyboard-operable; no renderer changes connections, credentials, audio routes or running applications.

### D04.6 — Verify providers and deliver frontend/integration evidence

Status: not started. Prerequisites: D04.2–D04.5, F04 fixtures, D01/D02 wiring and approved P05/P07 acceptance scope.
Ownership: D04 proposed `tests/shell/device_controls.sh` and `tests/shell/device_themes.sh`; shared fixtures/runner remain F04/I01-owned.
Deliverables: thirteen-option coverage, switching cases, applet concurrency tests, device failure fixtures and consented real-hardware/visual procedures.
Validation: static → argv → modeled effect → real effect → visual evidence; never use an earlier evidence level to satisfy a later requirement.
Done: I01 receives reviewed results and explicit not-run/blocked cases; full parity requires all mandatory effects, not just successful launches.

## 7. Shared-file contribution requests

- `packages.json`, `src/packages.rs`: send capability/dependency proposals to F01, later I01; preserve defaults, strict readers and extra-package semantics.
- `setup.sh`, `scripts/lib/setup-reliability.sh`: request helper delivery, executable-mode checks and managed activation through F02/I01.
- `role_exec.sh`, `role_window.sh`, common dispatchers: request bounded provider registration/window extraction; no domain-owned competing dispatcher.
- `sources_example/{autostart,keybindings,app_variables}.lua` and affected legacy counterparts: submit lifecycle/media-control contributions through I01 with D07 review.
- Waybar/Ironbar/nwg-panel profiles: D01 owns frontend wiring; D04 supplies exact operations, status fields and migration expectations.
- `tests/run.sh`, common fixtures and CI: F04/I01 integrate D04 suites; `Documents/app-selections.md` support/operation notes go to I01.
- Parent alone writes canonical plans and reconciles shared integration ownership.

## 8. Preservation, activation, rollback and privacy

Preserve schema 2, legacy environment inputs, member/primary distinctions, literal argv and required-role validation.
Retain compatibility paths until caller and upgrade fixtures cover migration; filenames must not silently acquire new semantics.
Preview source, installed and runtime effects separately; use F02 staging, validation, per-file atomic replacement and recoverable batches.
Adopt only approved appearance keys/regions, preserve Stow topology and user edits, and report ambiguous ownership as a conflict.
Role switching does not uninstall alternatives, disconnect networks/devices, reset mixers, or migrate NetworkManager profiles, BlueZ bonds or audio policy.
P06 gates existing-user activation; leave reload/restart pending rather than kill an applet, pairing prompt or application without consent.
Rollback restores managed outputs and only owned lifecycle changes; it cannot promise to undo user-confirmed external connection/pairing effects.
Stop on divergence after activation rather than overwrite newer edits; distinguish file recovery from live-state recovery.
Never log passwords, PIN/passkeys, keyring contents, raw credential-bearing argv or complete network/profile dumps.
SSID, address, device alias and stream/application names may be private: minimize persistence and use synthetic/redacted evidence.
Use established authorization paths; no sudo prompts, broad policy relaxation, automatic service enablement or credential collection in shared menus.
Validate IDs and escape labels for each frontend; never evaluate device names or menu selections as shell source.

## 9. Acceptance and decision gates

Existing inspected check: `tests/shell/roles_matrix.sh`; future invocation: `bash tests/run.sh tests/shell/roles_matrix.sh`.
Existing regression suites located for later use: `roles_membership.sh`, `roles_lua_argv.sh`, `reliability_atomic.sh` and `reliability_rollback.sh`; not executed here.
Proposed checks: `bash tests/run.sh tests/shell/device_controls.sh tests/shell/device_themes.sh` after those suites exist.
Fixtures must fail closed against host D-Bus/device access and record cancellation without mutation, literal hostile labels, stale state and uncertain timeout.
Real tests require explicit consent and disposable profiles/devices; record actual package versions, platform, backend, hardware and cleanup limits.
Exercise all thirteen choices, each inbound/outbound switch, multiple selected terminals, existing optional None states and panel/tray switching.
Verify keyboard-only flows, readable error/empty states, light/dark/accessibility variants, mixed-DPI movement and multi-monitor placement.
P01/P02/P04 are resolved: native device workflows, Mocha/Latte and per-app routing for full support with no companions. Verify their native implementation before claiming parity.
P05 targets current Arch versions. P06 permits independent partial configuration adoption with safe reloads; P07 uses VM manual visual review and functional tests. Real radio/audio/battery/backlight effects remain unverified without hardware and do not become a required certification gate.
P03 remains D03-owned: device feedback must not create another notification provider or treat notifications as an effect oracle.
Escalate unavailable editor/connect paths, pairing without safe agent ownership, mandatory companions, second-shell requirements or unsupported mandatory styling.
No missing hardware, declined companion or failed feasibility result authorizes reduced parity, removed choices, new defaults or silent approval.

## 10. Implementation checklist and confidence

1. Not started — D04.1: reconcile capability contributions and obtain affected decisions.
2. Not started — D04.2: implement network separation and persistent-applet behavior.
3. Not started — D04.3: implement Bluetooth state and pairing safeguards.
4. Not started — D04.4: implement audio distinctions under the P04 gate.
5. Not started — D04.5: register appearance and reversible activation.
6. Not started — D04.6: verify effects, presentation and integration handoffs.

Planning confidence: **92/100** for repository-grounded scope, ownership and identified gaps.
Runtime feasibility remains unverified; concrete contracts, native pairing-agent behavior, applet lifecycle and physical device effects limit stronger claims. The native-only ALSA policy is resolved.

## Planning handoff

Workstream: D04 — Network, Bluetooth and audio controls.
Supplied source baseline: `610a18bac374e7e2ffd0bcb2d99b026131deedbc`; branch `feat/harmonize-visual-design`; not independently Git-verified.
Repository mutations: none; no implementation, installation, activation, commits, publication or child delegation.
Inspected sources: complete master and all four supplied foundation drafts; scoped `packages.json`, `Documents/app-selections.md`, `setup.sh`, Waybar configuration, Hyprland autostart/keybindings and test directory.
Also inspected: all five requested Waybar wrappers, `toggle_bluetooth.sh`, `role_window.sh`, `role_exec.sh`, `launch_qt_gui.sh` and complete `tests/shell/roles_matrix.sh`.
Validation performed: read-only source/path inspection, thirteen-option cross-check, dependency/ownership review and existing-versus-proposed check separation.
Validation omitted: command/test execution, Git verification, installed-version/upstream checks, service queries, screenshots, physical hardware and rollback execution.
Residual risks: concrete foundation interfaces, native workflow gaps, unverified physical hardware and external-state recovery limits. Product policy is resolved.
Canonical destination: `plans/planned/desktop-harmonization/D04-device-controls.md`; parent alone integrates and writes the canonical plan.