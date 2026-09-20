# F01 — Inventory and capability contracts

Status: product policy synchronized with the completed interview; implementation not started. P01-P07 refer to the resolved master section 9 and [decision record](../desktop-harmonization-grill.md); native feasibility, interface design and execution evidence remain pending.
Master: [Desktop harmonization master](../desktop-harmonization-master.md).
Source baseline: `610a18bac374e7e2ffd0bcb2d99b026131deedbc`, branch `feat/harmonize-visual-design`.

## 1. Scope and boundaries

Own the complete catalog inventory, generic-package classification policy, semantic capability ledger, schema evolution proposal, feature dependency closure, and compatibility evidence requirements.
Apply the resolved P01/P03/P04/P05 policy; prepare evidence, not repeat questions already answered.
Concrete schemas/interfaces remain recommendations until foundation verification. Keep limited options selectable, preserve their native launch and explain unsupported actions without granting a full-parity label.

Preserve every catalog option, current defaults, cardinalities, optional None states, primary routing, literal argv, official-agent installer allowlists and reliability behavior.
Primary controls routing; every selected member receives applicable theme coverage.
Do not implement runtime adapters, theme engines, chooser changes, installation, service activation or account/data migration.
Do not promise identical application internals or use package availability as proof of behavioral parity.

## 2. Verified repository evidence

| Anchor | Observation and implication |
|---|---|
| `packages.json:roles` | 17 roles and 73 option rows; `nwg-panel` occurs in both bar and dock. Identify options by role plus package, not executable alone. |
| `src/packages.rs:ROLE_ORDER`, `shipped_schema_has_all_roles_and_cardinalities` | Source asserts nine single-choice, eight multiple-choice and thirteen required roles; these assertions were inspected, not executed. |
| `PackagesRoot`, `RoleDefinition`, `RoleOption` | Rust uses `deny_unknown_fields`; adding JSON metadata alone breaks existing deserialization. |
| `PackagesRoot::validate`, `validate_option` | Source, role-specific fields, required-package exceptions and agent installer contracts are validated. |
| `role_controlled_packages`, `categorized` | Options and their extras are excluded from generic categories; classification must not accidentally change selection ownership. |
| `RoleSelection::selected_install_packages`, `export_env` | Installation unions all members; primary and membership export separately; primary must belong to membership. |
| `setup.sh:load_role_selections` | Unset, explicit empty, scalar-only and membership inputs have distinct semantics; nonempty membership without primary is rejected. |
| `setup.sh:prepare_package_selections` | Required packages survive role filtering; package unions are deduplicated; official-agent extras enter pacman selection. |
| `setup.sh:generate_roles_json` | Emits schema 2 with `.roles`, `.selected`, `.agent_executables`; selected metadata follows catalog option order. |
| `setup.sh:configure_roles` | Configures routing and managed lines; preserves special terminal matching and exact stock shortcut migration. |
| `Documents/app-selections.md` | Documents None, GUI-editor fallback, non-uninstallation, combined nwg-panel operation and live compatibility limitations. |
| `tests/check_packages_json.sh` | Rejects unknown keys and pins role policies/options; opt-in package lookup is not capability verification. |
| `tests/shell/roles_validation.sh`, `tests/shell/roles_membership.sh` | Fixtures cover invalid selections, schema 2, idempotence, package unions, None and literal argv. |
| `dotfiles/.config/waybar/config.jsonc` | Active module arrays differ from defined modules; taskbar and power-profiles definitions are inactive. |
| `dotfiles/.config/hypr/scripts/notification_control.sh` | Toggle means different operations by provider; Fnott DND currently exits successfully without an effect. |
| `dotfiles/.config/waybar/scripts/notification_status.sh` | SwayNC supplies status; other providers receive static generated status every five seconds. |

No installed-version, upstream API, graphical-session or hardware compatibility was verified.
Existing descriptions are repository claims, not authoritative proof of toolkit versions or native capabilities.

## 3. Complete role-option coverage

`M` means multiple selected members with one primary; `S` means single selection.
Toolkit/rendering families are provisional classification hints requiring per-option evidence in F01.1.

| Role | Cardinality | Exact package options; owner; family hints |
|---|---|---|
| `browser` | M required | `firefox`, `chromium`, `vivaldi`, `zen-browser-bin`, `brave-bin`; D06; browser-native/custom plus toolkit integration |
| `shell` | M required | `bash`, `fish`, `zsh`; D05; terminal-rendered |
| `terminal` | M required | `kitty`, `alacritty`, `ghostty`, `konsole`, `foot`; D05; custom/GTK/Qt families |
| `multiplexer` | M required | `tmux`, `zellij`, `herdr-bin`; D05; terminal-rendered |
| `file_manager` | S required | `dolphin`, `thunar`, `nautilus`, `nemo`, `pcmanfm-qt`; D06; Qt/GTK, libadwaita status to verify |
| `tui_file_manager` | M optional | `yazi`, `ranger`, `lf`, `nnn`, `mc`, `vifm`, None; D06 with D05 |
| `notifications` | S required | `swaync`, `mako`, `dunst`, `fnott`; D03; GTK/custom layer surfaces |
| `tui_editor` | M required | `neovim`, `helix`, `vim`, `nano`; D06 with D05 |
| `gui_editor` | M optional | `zed`, `visual-studio-code-bin`, `cursor-bin`, `kate`, `mousepad`, None; D06; custom/Electron/Qt/GTK |
| `bar` | S required | `waybar`, `ironbar`, `nwg-panel`; D01; GTK-family classification to verify |
| `dock` | S optional | `nwg-dock-hyprland`, `nwg-panel`, None; D01; layer surfaces |
| `calendar` | S required | `merkuro`, `gnome-calendar`, `korganizer`, `calcurse`, `khal`; D06; Qt/GTK/TUI |
| `bluetooth` | S required | `blueman`, `bluedevil`, `bluetui`, `bluetuith`; D04; GTK/Qt/TUI |
| `network` | S required | `network-manager-applet`, `nm-connection-editor`, `networkmanager`, `plasma-nm`; D04; GTK/TUI/Plasma |
| `audio` | S required | `pavucontrol`, `pavucontrol-qt`, `qastools`, `alsa-utils`, `ncpamixer`; D04; GTK/Qt/TUI |
| `launcher` | S required | `wofi`, `rofi`, `fuzzel`, `bemenu`, `tofi`; D02; GTK/custom/text-oriented |
| `agent` | M optional | `pi`, `opencode`, `claude-code`, `codex-cli`, `cursor-cli`, None; D05; terminal-rendered, manual authentication |

Create four explicit disabled-role coverage rows; None is a state, never an installable package.
Distinguish package from executable: examples include `qastools`/`qasmixer`, `networkmanager`/`nmtui`, `khal`/`ikhal`, and `zed`/`zeditor`.
Multi-member examples must include non-primary terminals, browsers, editors, shells, multiplexers, file managers and agents.

### Generic-package classification policy

Inventory the union of every package in `hyprland_packages`, `aur_packages` and `official_packages`; retain source and original category spelling.
Join each package to every role membership and extra-package edge before identifying the remaining generic entries.
Every package receives one accountable owner and one primary classification, with secondary tags where necessary:

- **Themed interface:** visible GUI/TUI surfaces, including Ark, GitHub Desktop, system monitors, package/user tools and Tk dialogs.
- **Integrated action:** capture, clipboard, wallpaper, media, brightness and administrative commands invoked by desktop workflows.
- **Backend dependency:** portals, NetworkManager, BlueZ, PipeWire/WirePlumber, keyring, runtimes, theme assets and supporting libraries.
- **Outside visual scope:** drivers, kernels, build/protocol tooling or unrelated CLI infrastructure, with a recorded reason rather than omission.

D07 contributes all remaining generic-package dispositions; D06 owns association semantics and F03 owns global asset/toolkit mappings.
F01 reconciles the single inventory and enforces set equality against the catalog; no unclassified package may pass Gate A.
Required status, default selection and visual classification are separate axes; classification never enables or removes a package.

## 4. Proposed ledger and semantic baseline

Recommend one machine-readable sidecar, **proposed** `capabilities.json`, adjacent to `packages.json`.
No existing capability-named file was found by scoped search; this path remains subject to parent approval.
F01 owns its structure and reconciliation; domains contribute evidence rows, not parallel catalogs.

Minimum descriptor fields: stable role/package identity, source, owner, rendering family, startup model, data boundary, renderer reference, actions, assets, dependencies and evidence.
Package identity remains catalog-authoritative; the sidecar must not duplicate executable strings, installer URLs or default choices.
Generic components use package identities; repeated role memberships retain distinct option identities.
Proposed capability records include observable outcome, applicability, prerequisite, failure states, evidence reference and acceptance-test reference.
Keep requirement level, native implementation mechanism and verification state separate. Allowed mechanisms are native behavior and configuration/native-API adapters. A new feature provider, replacement implementation or companion interface is outside the approved scope.
Theme assets and genuine dependencies of existing native workflows may enter package closure with a preview; do not misclassify feature-filling companions as dependencies.

### P01 baseline proposal

Preserve the active Waybar experience as the starting requirement candidate, pending user approval:

- Workspace selection/submap display, tray access, application/menu launch, keybinding viewing/editing and snapshot access.
- Clock/calendar launch, output/input audio status and controls, brightness adjustment/presets, temperature/system-monitor access.
- Battery and keyboard-lock status; network status/connect/edit; Bluetooth status/device management/radio controls.
- Update status, confirmation, check/update variants, firmware, pacnew review, cache maintenance and log viewing.
- Notification attention/history/DND semantics; power screen and shutdown/reboot/suspend/hibernate/logout actions.

D01 extracts exact gestures and linked menu/helper behavior before F01 freezes this list.
Do not infer effect-level behavior solely from tooltips or upstream module defaults.
Inactive taskbar and power-profiles definitions remain recorded extras unless P01 explicitly promotes them.
Equivalent role workflows additionally cover literal launch, terminal wrapping, primary routing and selected-member appearance.
Application-native extras—IDE plugins, browser internals, agent providers and calendar account services—are not automatically mandatory parity.

### State, theme and accessibility mapping

Capability support is static evidence; runtime availability is a separate observation.
Distinguish disabled None, missing package, unsupported capability/version, absent hardware, permission denial, stale/unknown status, command failure and cancellation.
An accepted invocation is not proof that its observable effect succeeded; never encode silent no-op as supported behavior.
Optional GUI-editor None retains explicit TUI-editor fallback; other optional None states must preserve existing role-specific behavior.
F03 supplies global toolkit tokens; domains supply renderer bindings for every selected member, with explicit native-only limits.
Acceptance records include readable focus, functional operation and dark/light appearance in the user's Arch VM. Preserve existing accessibility preferences; dedicated high-contrast/reduced-motion/enlarged-text variants and physical-hardware certification are not acceptance requirements.
Unknown accessibility or theme support blocks the corresponding claim rather than justifying invasive overrides.

## 5. Incoming and outgoing contracts

| Producer → consumer | Contract and gate |
|---|---|
| Master/user → F01 | Scope, baseline identity and P01/P03/P04/P05 approvals; discovery may precede approval. |
| [D01](D01-bars-docks.md)/[D02](D02-launchers-shared-menus.md)/[D03](D03-notifications-attention.md)/[D04](D04-device-controls.md)/[D07](D07-session-auxiliary-interfaces.md) → F01 | Pre-foundation operation extraction, launcher semantics, feasibility evidence and generic-package classification contributions. |
| F01 → [F02](F02-runtime-managed-configuration.md) | Approved descriptor meanings, schema compatibility strategy, capability states and singleton/dependency constraints; prerequisite to runtime implementation. |
| F01 → [F03](F03-visual-system-theme-generation.md) | Selected-member inventory, renderer-family tags and asset closure; P02 remains F03/user-owned. |
| F01 → [F04](F04-verification-foundation.md) | Coverage identities, observable outcomes, compatibility cases and evidence requirements. |
| F01 → [D05](D05-terminal-workspace-agents.md)/[D06](D06-applications-default-handlers.md) | Inventory and parity boundaries preserving terminal/agent routing, application data and handler consent. |
| F01 → [I01](I01-integration-rollout-acceptance.md) | Chooser explanations, dependency preview, limitations and decision records; no automatic default changes. |

Foundation drafts are concurrent and provisional; no sibling API is assumed approved.
Domain discovery, contract contributions and separately authorized bounded feasibility checks are **pre-foundation specification work**, not prerequisites involving completed domain adapters.
Gate A must not wait for later adapter implementation that itself requires the foundation gate.
Sequence: domain specification contributions → F01 contract approval → foundation implementation → domain adapters → frontend wiring.
Changes after Gate A require producer/consumer impact, migration and test updates, reconciled by the parent/integration owner.

## 6. Numbered implementation work packages

### F01.1 — Establish the exhaustive inventory
Status: not started. Prerequisite: implementation authorization and baseline recheck.
Deliverables: populate **proposed** `capabilities.json`; inventory all 73 role-option rows, four None states and all generic packages.
Record per-option startup/lifecycle, privacy boundary, rendering family, available actions, configuration surfaces, assets and evidence uncertainty.
Validation: catalog-to-ledger set equality, unique option IDs, valid owner references, no orphan generic entries or unclassified extras.
Done: every current choice has an owner and evidence-backed classification or explicitly unresolved blocking field.

### F01.2 — Freeze observable semantic requirements
Status: not started. Prerequisite: F01.1 identities; pre-foundation domain specifications; P01 approval for final freeze.
Deliverables: requirement/action/status records in the same ledger; exact active Waybar operation trace; separate native extras and inactive definitions.
D01 owns detailed panel extraction; D02-D07 contribute role outcomes without implementing a competing action bus.
Validation: each proposed mandatory outcome has an observable success condition and unsupported/failure/cancellation expectations.
Done: user approves P01, or all affected parity claims remain explicitly blocked.

### F01.3 — Prove risky options and establish compatibility evidence
Status: not started. Prerequisite: F01.2 candidate requirements; separate authorization for bounded feasibility spikes.
Deliverables: pre-foundation evidence from D02/D03/D04, decision briefs P03/P04/P05 and a version/platform matrix; completed adapters are not prerequisites.
Notification spike: separately test DND suppression/readback, history retrieval, actions and restart behavior under one notification owner.
Audio spike: verify hardware mixing separately from native per-app routing. Classify QasMixer/Alsamixer as limited when native stream control is absent; do not evaluate or implement a companion.
Launcher spike: verify native desktop-entry discovery/execution and cancellation. If Bemenu cannot provide the standard application mode natively, keep its command mode explicitly labeled and report the standard action unsupported; do not add a desktop-entry feature provider.
Validation: record exact tested versions, compositor/session/toolkit context, command/API, authoritative source, date, result and reproducible fixture.
Done: approved supported combinations have evidence; impossible/unproven cases remain blocking, never relabeled equivalent.

### F01.4 — Approve compatible schema evolution
Status: not started. Prerequisite: F01.1/F01.2 draft descriptors; F02/F04 specification review.
Deliverables: catalog/sidecar/runtime compatibility table and strict-reader fixtures; bounded changes to `src/packages.rs` and `tests/check_packages_json.sh` only if approved.
Recommend independent sidecar versioning while leaving catalog shape and runtime schema 2 unchanged initially.
Alternative: typed optional catalog metadata requires coordinated Rust/jq reader changes before emission; old strict readers still need an explicit compatibility strategy.
Because generation copies entire option objects, catalog additions can leak into runtime metadata; F02 must approve projection or consumer compatibility.
Validation: old catalog/new reader, new metadata/old reader, absent sidecar, malformed/unknown versions, stale catalog linkage and schema-2 fixture cases.
Done: consumers reject unsupported inputs clearly before writes; no predetermined runtime bump, weakened strictness or guessed capabilities.

### F01.5 — Specify deterministic feature dependency closure
Status: not started. Prerequisite: F01.2 requirements, F01.3 feasibility and approved dependency costs.
Deliverables: typed dependency graph in the ledger; F02/I01 integration specification, not installer implementation.
Preserve existing required/generic selection semantics; union selected members and extras by source, then approved feature/helper/asset dependencies.
Represent package, executable, service, protocol, renderer and asset requirements separately; prohibit dependency cycles and unresolved references.
Preserve existing same-source extras policy and official-agent pacman-extra exception; do not overload `extra_packages` to express arbitrary cross-source graphs.
Validation: all-selected, optional None, shared nwg-panel, non-primary members, missing asset/backend and explicitly unsupported native-capability scenarios.
Done: every enabled approved feature has explainable closure, one lifecycle owner and no silently added optional companion.

### F01.6 — Deliver Gate A evidence and regression coverage
Status: not started. Prerequisite: F01.1-F01.5; F04 fixture specification; user decisions for affected claims.
Deliverables: F01-owned registry tests, domain evidence references, contribution patches and Gate A review packet.
Extend existing Rust tests and shell checks; **proposed** `tests/shell/capability_contracts.sh` and **proposed** `tests/fixtures/capabilities/` need F04 coordination.
Validation: exhaustive option/None coverage plus targeted cross-role combinations; compare old and proposed selections, argv and schema-2 output.
Done: reviewer accepts inventory/schema/closure evidence; unresolved mandatory feasibility or approval gates explicitly prevent foundation acceptance.

## 7. Shared-file contributions and migration

F01 owns foundation metadata changes to `packages.json` and `src/packages.rs`; later domain changes route through I01.
F02 owns `setup.sh`, generated roles and managed-write interfaces; submit schema projection/dependency requirements, not concurrent edits.
F04 owns `tests/run.sh` and common fixtures; I01 owns `src/main.rs` and user-facing documentation integration.
Provide exact `Documents/app-selections.md` amendments to I01; do not claim its sole-writer role.

Keep existing schema-2 routing operational without a sidecar; missing metadata means unverified harmonization, not unsupported application selection.
Bind ledger revision to compatible catalog identities and reject mismatches for harmonization activation.
Stage and validate metadata before activation through F02; failed validation leaves previous routing and managed configuration intact.
Rollback restores the previous compatible metadata/configuration set; preserve Stow links and user-owned regions through F02 transactions.
Never uninstall alternatives or alter profiles, credentials, accounts, calendar data or agent configuration.
Do not run official installers or provider authentication merely to classify a package; evidence must exclude secrets and private content.
P06 governs later activation/handler changes; F01 records its prerequisite without approving them.

## 8. Acceptance scenarios and proposed commands

Current validation consisted only of source reads/searches and cross-checking anchors; no command below was executed.
Future offline commands: `cargo test`, `bash tests/check_packages_json.sh`, and `bash tests/run.sh tests/shell/roles_validation.sh tests/shell/roles_membership.sh`.
After creation, run **proposed** `tests/shell/capability_contracts.sh` through the existing isolated runner.
Test unchanged defaults, all members, every primary, optional None, scalar-only legacy input, explicit empty and unset inputs.
Reject duplicate members, invalid tokens, primary outside membership, required empty and extra single-role members.
Prove selection/argv preservation, catalog-ordered runtime membership, shared-package deduplication and official-agent contract preservation.
Test descriptor version rejection, stale evidence, missing dependencies/assets and unknown hardware without false success.
Future opt-in `HSS_LIVE_PACKAGE_CHECK=1 bash tests/check_packages_json.sh` checks package names only; it cannot close P05 capability evidence.
Graphical, accessibility, effect-level and hardware checks remain future F04/domain/I01 work under P07-approved coverage.

## 9. Decisions, risks and stop rules

P01-P07 product policy is resolved in master section 9. Full support uses the approved workflows and Mocha/Latte visual direction; native gaps produce limited labels rather than a whole-program block.
Verify notification native history/DND/privacy and audio stream capability without companions. Current fully updated Arch versions are the reference; other distributions and physical hardware remain unverified.
P06 preserves custom files, allows independent partial application and follows primary handlers; P07 uses manual VM visual review and functional tests without numeric budgets. None of these decisions authorizes implementation.
Stop on missing catalog coverage, weakened strict validation, changed default/cardinality, modified installer allowlists or silently changed argv/routing.
Escalate infeasible mandatory capabilities, competing singleton owners, second-shell dependencies, inaccessible mandatory workflows or unavoidable private-data migration.
An unproven fallback or declined companion cannot silently lower required parity or remove an application.
Local wiki paths supplied by the master were not consulted; no upstream/version claim depends on them. Future research must follow local-document routing.

## 10. Implementation checklist and confidence

1. Not started — F01.1: reconcile every role option, None state and generic package into the inventory.
2. Not started — F01.2: obtain pre-foundation specifications and user approval of P01 requirements.
3. Not started — F01.3: complete authorized feasibility evidence and resolve affected P03/P04/P05 gates.
4. Not started — F01.4: approve and verify strict catalog/sidecar/schema-2 compatibility.
5. Not started — F01.5: validate approved feature dependencies, assets and singleton ownership.
6. Not started — F01.6: deliver regression evidence and obtain independent Gate A acceptance.

Planning confidence: **94/100** in repository-grounded scope and identified compatibility hazards.
Feasibility remains unverified: installed/upstream versions, graphical effects and hardware behavior were not tested.

## Planning handoff

Workstream: F01; canonical destination: `plans/planned/desktop-harmonization/F01-inventory-capability-contracts.md`.
Source baseline: `610a18bac374e7e2ffd0bcb2d99b026131deedbc`; branch `feat/harmonize-visual-design`.
No repository mutations, staging, installations, service changes or implementation occurred; this recovery reused the prior inspected evidence.
Inspected files: complete master, `packages.json`, `src/packages.rs`, `Documents/app-selections.md`, scoped `setup.sh` symbols, `tests/check_packages_json.sh`, `tests/shell/roles_validation.sh`, `tests/shell/roles_membership.sh`, `tests/run.sh`, Waybar configuration and notification helpers named above.
Validation performed: read-only source inspection, scoped directory/path checks and contract cross-checking; no tests were run.
Validation omitted: baseline/index verification, upstream research, package lookup, graphical execution, accessibility measurements and live hardware/version compatibility.
Residual risks: concrete interface reconciliation, strict-reader rollout and native notification/audio/launcher feasibility remain open. Product policy is resolved; implementation evidence is not.
The parent remains the sole canonical-plan writer; no implementation acceptance or new authorization is implied.