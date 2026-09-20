# F02 — Shared runtime and managed configuration

Status: product policy synchronized with the completed interview; implementation not started. P01-P07 refer to resolved master section 9 and the [decision record](../desktop-harmonization-grill.md); native evidence and implementation gates remain pending.
Master: [Desktop harmonization master](../desktop-harmonization-master.md).
Source baseline: `610a18bac374e7e2ffd0bcb2d99b026131deedbc`, branch `feat/harmonize-visual-design`.

## 1. Scope and boundaries

F02 owns semantic action/status contracts, generic helper extraction, argv and cancellation boundaries, singleton ownership mechanisms, managed writes, activation coordination and compatibility entry points.
Extend existing reliability primitives; do not introduce another transaction engine, desktop shell, daemon-based action bus or plugin framework.
Provider semantics remain domain-owned; F02 supplies mechanisms rather than deciding which notification history, device controls or power policies are required.
Preserve every catalog choice, selection cardinality, primary/member distinction, environment input and existing agent/multiplexer route.
No feature-filling companions or replacement features are allowed. Apply approved product defaults through native configuration/API adapters only. Existing-user activation still requires the approved preview; no account/data migration is allowed.

Coverage includes all 17 roles through F01's authoritative option ledger:
- Browser, shell, terminal, multiplexer, TUI file manager, TUI editor, GUI editor and agents retain independent membership and primary routing.
- File manager, notifications, bar, calendar, Bluetooth, network, audio, launcher and dock retain existing single-choice semantics.
- Explicit None remains supported for TUI file manager, GUI editor, dock and agents; None is not equivalent to a missing executable.
- Exercise terminal-specific behavior for Kitty, Alacritty, Ghostty, Konsole and Foot; launcher behavior for Wofi, Rofi, Fuzzel, Bemenu and tofi.
- Exercise singleton combinations for Waybar, Ironbar, nwg-panel, nwg-dock-hyprland and dock None; notification providers remain SwayNC, Mako, Dunst and Fnott.
- Other option-specific action support comes from F01/domain contributions, not a second F02 capability catalog.

## 2. Repository evidence

These observations come from static inspection, not executed tests or verified upstream compatibility.

| Anchor | Observed behavior and planning consequence |
|---|---|
| `setup.sh:generate_roles_json` | Writes schema 2 with `.roles`, `.selected` and `.agent_executables`; avoids duplicate source/runtime writes when canonical destinations match. |
| `setup.sh:configure_roles` | Generates role commands, Lua/legacy configuration updates, Fish variables and selected Waybar actions; required write failures propagate. Preserve these routes. |
| `setup.sh:sync_installer_managed_runtime_files` | Refreshes an explicit helper/profile list using atomic writes and restores executable mode afterward. New helpers need installer delivery and mode-failure tests. |
| `scripts/lib/setup-reliability.sh:write_file_atomic` | Resolves approved destinations, backs up content, preserves symlink targets/modes, syncs a sibling temporary file and renames it. Atomicity is per file. |
| `hss_begin_run`, `hss_on_signal`, `hss_rollback` | Existing lock, run metadata, signal deferral and validated rollback already exist; rollback can report partial failure. No all-files atomic commit is established. |
| `hss_path_is_approved` | Configuration roots are principally HOME-based; notification D-Bus paths are exact exceptions. General nondefault-XDG write support must not be assumed. |
| `role_exec.sh`, `term_exec.sh` | Primary routing uses argv arrays; GUI-editor None falls back to TUI editor; dock None exits successfully; Konsole uses separate processes and stable titles. |
| `menu_exec.sh`, `app_log.sh` | Dmenu data channels remain untouched; launcher stderr is logged; Bemenu sets Wayland backend; toggle distinguishes no process from `pkill` errors. |
| `role_window.sh` | Calendar/audio GUI handling depends on `waybar/scripts/launch_qt_gui.sh`; terminal applications instead use role routing. |
| `launch_qt_gui.sh`, `float-active-window.sh` | Generic focus/float behavior lives beneath Waybar; window discovery polls 80 times at 0.1 seconds. Placement uses focused-monitor dimensions. |
| `nwg_panel.sh` | Combines bar/dock profiles into `hss-panels`, makes dock invocation a no-op when shared with bar, and assigns the bar real-time signal. Uses its own temporary-file rename. |
| `run_once.sh`, `startup_state.sh` | Process-held session locks and separately secured session-hashed readiness markers already exist; readiness is not process ownership. |
| Notification control/status helpers | Legacy toggle meanings differ; Fnott DND succeeds without action; non-SwayNC status emits static presentation JSON. These do not establish parity. |
| Notification D-Bus service; `autostart.lua` | D-Bus activation and startup both route notifications through role execution; two authentication agents are requested in the template. |
| Waybar `nmtui.sh`, `nmtui-connect.sh` | Both forward to the selected network role. Extraction must not accidentally invent distinct connect/edit semantics. |
| `Documents/app-selections.md` | Documents schema 2, selection inputs, preserved custom bindings, multi-member routing and compatibility limitations. |

Inspected tests assert symlink/mode preservation, exact D-Bus allowlisting, digest-guarded rollback, malformed-manifest rejection and failure propagation; they were not executed.
`roles_controls.sh` explicitly asserts existing notification argv and Fnott's no-op; a new honest capability result must not silently rewrite that legacy contract.
Repository comments about upstream instance replacement and terminal flags are implementation evidence, not fresh version verification.
Local wiki/upstream behavior was not investigated: the routed wiki tools were unavailable, and this draft makes no current-version claims.

## 3. Incoming and outgoing contracts

All names and formats below are recommendations pending reconciliation; concurrent foundation drafts are not approved APIs.
Domain discovery, feasibility findings and contract contributions are **pre-foundation specification work**, not dependencies on later domain adapter implementation.
Gate A must not wait for adapters whose implementation itself requires the foundation gate; approved specifications and bounded feasibility evidence resolve that ordering.

| Producer → consumer | Required handoff and gate |
|---|---|
| [F01](F01-inventory-capability-contracts.md) → F02 | Approved capability IDs, option identities, support states, dependency/ownership descriptors and schema compatibility strategy; blocks F02.1 implementation. |
| F02 → [F03](F03-visual-system-theme-generation.md) | F02.5 managed-output descriptor, validation/commit outcomes and F02.6 activation interface; required before production theme writes. |
| F03 → F02 | Pure renderer candidates, asset checks, target ownership, activation requirements and applicable accessibility variants; no direct destination writes. |
| F02 ↔ [F04](F04-verification-foundation.md) | Frozen action/status/write contracts, fake provider interfaces and failure fixtures; F04 owns shared harness integration. |
| [D02](D02-launchers-shared-menus.md), [D03](D03-notifications-attention.md), [D04](D04-device-controls.md), [D07](D07-session-auxiliary-interfaces.md) → F02 | Pre-foundation menu cancellation, notification/device semantics and session/security ownership specifications; later adapter implementation consumes the foundation rather than blocking its specification. |
| F02 → [D01](D01-bars-docks.md) | Presentation-free action/status interfaces and combined-panel ownership; widgets must not become backend dependencies. |
| F02 ↔ [D05](D05-terminal-workspace-agents.md), [D06](D06-applications-default-handlers.md) | Preserve terminal/agent/handler argv boundaries; D06 supplies consented handler intents rather than F02 selecting associations. |
| F02 → [I01](I01-integration-rollout-acceptance.md) | Setup contribution inventory, compatibility wrappers, recovery notes and gate evidence; I01 becomes sole later shared-file integrator. |

### Recommended action and status boundary

- Use ordinary executable entry points, not a background broker: proposed `dotfiles/.config/hypr/scripts/action_exec.sh` and `status_read.sh`.
- Illustrative action IDs are `role.open`, `window.present`, `menu.choose` and domain-qualified operations; F01/F02/domain owners freeze actual IDs together.
- Forward user arguments after `--` as distinct argv elements; prohibit `eval` and shell-string reconstruction at the shared boundary.
- Retain legacy stdin/stdout and exit behavior in compatibility wrappers; especially never mix result JSON into dmenu selection output.
- For new machine-facing operations, specify one result envelope containing action/provider identity, outcome, reason and underlying exit status.
- Distinguish completed, accepted-but-not-observed, cancelled, disabled, unsupported, missing dependency, unavailable hardware, timeout and failed outcomes.
- Freeze numeric exit mappings with F04; do not infer user cancellation from every nonzero launcher exit.
- Launch success does not prove that a window appeared; status-query failure does not mean a device is disabled.
- Status contains typed values, availability, observation age and error reason; no icons, markup or frontend tooltip text.
- Domain adapters provide one-shot queries and bounded subscriptions where native support exists. Use explicit engineering timeouts and cleanup, but P07 imposes no numeric performance acceptance budgets.
- Never automatically retry non-idempotent actions after an uncertain timeout; serialize conflicting transitions without suppressing deliberate repeated actions.
- Long-running application launch and bounded status queries need different timeout policies; cancellation must not kill unrelated application instances.

### Recommended managed-output boundary

- Descriptor fields: producer, input identity, requested output, canonical destination, ownership class, candidate, validator, dependency order and activation classification.
- Ownership classes distinguish generated files, narrowly managed regions and user-owned files; unclassified existing content blocks replacement.
- Sequence: resolve/preview, partition dependency-coherent units, render/validate, mark conflicting units skipped, commit independent valid units, verify, safely activate and report complete or partial state. Shared prerequisite failure blocks its dependents; unsafe global state must fail closed.
- Reuse `make_tmp`, `write_file_atomic`, run locking, backup manifests and validated restoration; preserve compatibility with existing five-column manifests.
- Source templates, installed Stow targets, persistent generated output and ephemeral runtime state must remain distinguishable.
- Promise per-file atomic replacement and recoverable batches, not instantaneous cross-file visibility or transactional rollback of external services.
- F02.5 must settle batch boundaries within an existing setup run before exposing this interface to F03.

## 4. Implementation work packages

Every work package is **not started**. Prerequisites below govern future implementation, not authorization to begin it.

### F02.1 — Freeze contracts and compatibility fixtures

Prerequisites: F01 Gate A contract approval; domain specification contributions and discovery occur before this gate where needed.
Deliverables: approved action/status/write schemas and legacy behavior matrix; proposed `Documents/runtime-managed-configuration.md`.
Files/ownership: F02 authors contract content; I01 integrates user-facing documentation; F04 receives fixture requests.
Preserve schema 2, legacy environment inputs, primary/member distinction, agent executable mapping and custom command boundaries; do not predetermine a schema bump.
Validation: fixture comparison for every role, optional None, malformed metadata, unknown future schema and spaces/metacharacters in argv.
Done: F01/F03/F04 acknowledge concrete interfaces and incompatible-input behavior; unresolved capability policy remains explicitly blocked.

### F02.2 — Extract generic window helpers without frontend dependencies

Prerequisites: F02.1; D01/D05 specification review of existing callers and presentation expectations, not completed domain implementations.
Deliverables: proposed `dotfiles/.config/hypr/scripts/window_present.sh` and `window_place.sh`, extracted from the existing Waybar helpers.
Files/ownership: F02 updates `role_window.sh`; retains `launch_qt_gui.sh` and `float-active-window.sh` as compatibility wrappers; I01 serializes shared caller changes.
Preserve GUI class matching, selected-terminal routes, focus behavior, supplied dimensions, argv and legacy timeout behavior during extraction.
Validation: old/new entry points produce equivalent argv and dispatches; test existing window, delayed window, missing executable, discovery timeout and placement failure.
Done: generic implementation has no Waybar filesystem dependency; legacy callers and installation-refresh delivery remain functional.

### F02.3 — Implement semantic invocation and typed observations

Prerequisites: F02.1; approved provider-semantic specifications for each operation implemented.
Deliverables: proposed action/status entry points and bounded adapter integration; proposed `tests/shell/runtime_contracts.sh`.
Files/ownership: F02 owns dispatch/result mechanics; D02-D07 own provider commands; D01 owns Waybar/Ironbar/nwg-panel formatting.
Keep legacy notification, menu and network wrappers unchanged until a separately reviewed migration; new APIs must report unsupported behavior honestly.
Validation: argv boundaries, empty arguments, cancellation, missing command, provider failure, stale state, unavailable hardware and uncertain timeout; ensure one invocation per request.
Done: a representative action/status integration passes F04 fixtures without frontend imports or invented parity claims; full domain backend implementation is not a prerequisite.

### F02.4 — Establish singleton ownership and readiness

Prerequisites: F02.1; pre-foundation D03.1-D03.2 notification specifications and the D07.1 authentication ownership/readiness specification; relevant P03/P06 approvals. Do not wait for D07.2 implementation.
Deliverables: shared lifecycle rules extending `run_once.sh`, `startup_state.sh`, `nwg_panel.sh` and notification launch routing; proposed `tests/shell/runtime_ownership.sh`.
Files/ownership: F02 supplies common mechanisms; D03/D07 specify provider readiness; I01 integrates autostart and D-Bus contributions.
Distinguish compositor-session processes from user-bus services; a per-Hyprland lock alone cannot establish notification ownership across sessions.
Probe existing ownership before starting; treat foreign owners as conflicts, not permission to terminate them; use bounded readiness rather than unconditional sleeps.
Validation: concurrent autostart/D-Bus requests, duplicate events, daemonizing child, stale lock, foreign owner, two sessions and every nwg-panel bar/dock combination.
Done: representative singleton fixture proves one owner and clear conflicts; no competing notification/authentication providers are introduced.

### F02.5 — Extend existing reliability for validated managed batches

Prerequisites: F02.1's frozen staging descriptor and the side-effect-free sample from F03.3a. This is fixture production, not completed F03.3b integration or the full theme pipeline.
The order is F02.1 interface freeze, F03.3a pure sample, F02.5 batch implementation, then F03.3b integrated renderer validation. F02.5 must not depend on its own downstream integration evidence.
Deliverables: bounded additions to `scripts/lib/setup-reliability.sh` and `setup.sh`; proposed `tests/shell/managed_configuration.sh`.
Resolve batch isolation using the existing run/manifest model; prove restoration touches only the affected operation, including destinations previously written in the run.
Stage and validate candidates before their unit is replaced; reject duplicate canonical targets and escaping links. Preserve conflicting user configs and skip affected dependency units while permitting independent valid apps to apply. Record skipped, applied, deferred and failed outcomes; skip unchanged candidates.
Preserve symlinks, existing modes, executable-helper delivery, dry-run reporting, signal handling and manifest validation; expose failure after rename accurately.
Validation: invalid candidate, disk/rename failure, manifest-update failure, interrupted batch, user edit during commit, custom XDG roots and Stow-linked destinations.
Done: staging failure changes no destination in its unit; independent valid units may apply. Commit failure yields verified recovery or explicit partial state. An appearance-only conflict may leave the new launchable primary and its associations active while preserving the old theme file; a required runtime failure blocks dependent actions. Unresolved isolation blocks production F03 integration.

### F02.6 — Preserve overrides and coordinate reversible activation

Prerequisites: F02.5; F03 activation descriptors; P06 approval before existing-installation activation.
Deliverables: managed ownership/override policy, preview and conflict reporting, activation outcome records and recovery instructions using existing run storage.
Recommended precedence: approved defaults → role/theme-generated values → explicit user overrides; F03/domain owners define application-specific merge support.
Use native includes where supported; otherwise update only proven managed regions or require explicit adoption. Do not promise lossless generic parsing.
Activate only after validated commit; order dependencies, restart a shared nwg-panel process once, and leave unsupported live activation pending.
Validation: untouched custom lines, changed generated files, rejected overrides, declined consent, idempotent rerun, reload failure and failed service restoration.
Done: user edits survive; rollback separates restored files from restored runtime effects; no operation reports full success when activation remains partial.

### F02.7 — Freeze the foundation handoff and migration evidence

Prerequisites: F02.2-F02.6; F04 fixture integration; representative F03 renderer and singleton integration available, not completion of D01-D07.
Deliverables: compatibility matrix, shared-file contribution packet, proposed test suites and documented limitations for I01.
Files/ownership: F02 owns its tests; F04 owns common fixtures/runner; I01 serializes subsequent setup, Lua/Hyprlang and documentation changes.
Validation: representative action → generated theme → managed commit → consented activation → injected failure → restoration in an isolated fixture.
Include every selected-member theme target even when only the primary supplies launch routing; leave domain visual assertions to F03/domain/F04 owners.
Done: foundation gate evidence is reviewed, compatibility wrappers remain installed, and all unsupported requirements have explicit blocking decisions.

## 5. Migration, rollback and security

- Retain existing helper paths until caller inventory and upgrade fixtures demonstrate safe migration; do not remove them merely because new entry points exist.
- Preserve exact legacy notification/menu routes during extraction; Fnott no-op compatibility is not evidence that the new DND capability is supported.
- Keep existing schema 2 readable; unsupported inputs fail before managed writes. F01 owns any schema evolution approval.
- Preserve `.selected` members independently of `.roles` primary; do not uninstall alternatives or rewrite agent authentication/configuration.
- Reconcile installer-refreshed helpers separately from user configuration: preview local modifications and retain recoverable copies before approved replacement.
- Nondefault XDG support requires canonical-root and ownership validation; never broaden the allowlist to arbitrary HOME paths as a shortcut.
- Keep temporary files and state private; do not record menu input, notification bodies, account data or complete sensitive argv in logs.
- Reuse the setup lock for managed configuration; separate short-lived runtime ownership locks must not block unrelated application launches.
- On failure, stop activation, report affected outputs and use validated backups; digest mismatches require existing confirmation safeguards.
- Do not roll back unrelated earlier setup writes to recover a theme batch. Unrecoverable partial state requires explicit operator instructions.
- Restoring files cannot undo emitted notifications, external power actions or all service effects; these remain separately reported outcomes.

## 6. Acceptance and proposed validation

Drafting validation performed: complete master read; scoped source/test inspection; existing directories and helper names checked; sibling links taken from the master.
No tests, shell commands, installations, desktop queries, service operations or repository mutations were performed.

Future commands, **not executed**:
- `bash tests/run.sh tests/shell/reliability_atomic.sh tests/shell/reliability_rollback.sh tests/shell/reliability_failures.sh tests/shell/roles_dbus_atomic.sh`
- `bash tests/run.sh tests/shell/roles_controls.sh tests/shell/roles_lua_argv.sh tests/shell/roles_membership.sh tests/shell/roles_startup.sh`
- `bash tests/run.sh tests/shell/runtime_contracts.sh tests/shell/runtime_ownership.sh tests/shell/managed_configuration.sh` — all three suites are proposed.

Required additional scenarios:
- Old installation, fresh installation, repeated setup and selection switch retain routing and user overrides; disabled optional roles do not become errors accidentally.
- Malformed registry/roles data, newline-bearing metadata argv and empty arguments either preserve defined boundaries or fail explicitly; no silent splitting.
- Failed status queries never display false healthy/disabled states; cancellation never triggers a fallback action without an approved domain rule.
- Concurrent configuration writers fail safely; crash recovery and metadata failure remain visible; dry-run performs no activation.
- Mixed-DPI/multi-monitor window placement, keyboard-only menus and readable failure feedback receive later real-session verification.
- Dark/light choices pass through F03 descriptors; preserve existing accessibility preferences without requiring new variants. Dispatch tests do not prove visual correctness.

## 7. Shared-file contributions, decisions and stop rules

F02 is the foundation writer for `setup.sh`, `scripts/lib/setup-reliability.sh` and common Hyprland adapters; later changes route through I01.
Request serialized contributions for `sources_example/{autostart,keybindings,app_variables,environment_variables,windows_and_workspaces}.lua` and existing legacy counterparts where affected.
F01 retains `packages.json`/`src/packages.rs`; F03 retains theme core; F04 retains `tests/run.sh` and shared fixtures; domains retain provider-specific code.

P01/P05 block capability and compatibility guarantees; P03/P04 block affected notification/audio semantics, not unrelated helper extraction.
P02 fixes the visual policy through F03. P06 allows independent partial application, primary-following handlers and safe reloads with restart deferral; verify their implementation before adoption. P07 requires manual VM visual review and functional tests, not numerical thresholds or physical-hardware certification.
Bounded feasibility gates: batch isolation/recovery; cross-session D-Bus ownership; daemon lifetime locking; native override composition; provider cancellation mapping.
Stop if any gate requires a second transaction framework, unrestricted write roots, mandatory companion, competing service owner or silent parity reduction.
Stop on ambiguous user-file ownership, unsupported schema, unresolved activation consent, foreign singleton ownership or unrecoverable partial write.
Return product decisions to the user through the owning plan; a blocked option remains cataloged and cannot receive a full-parity claim.
If a proposed prerequisite points back to later domain implementation, split out its discovery/specification contribution rather than creating a foundation dependency cycle.

## 8. Implementation checklist and confidence

1. Not started — Approve F01/F02 contracts and preserve legacy routing fixtures (F02.1).
2. Not started — Extract generic window helpers while retaining compatibility entry points (F02.2).
3. Not started — Implement semantic action/status boundaries and their contract tests (F02.3).
4. Not started — Verify singleton ownership, readiness and combined-panel behavior (F02.4).
5. Not started — Prove managed-batch recovery, override preservation and consented activation (F02.5-F02.6).
6. Not started — Complete representative foundation integration and hand off reviewed evidence to I01 (F02.7).

Planning confidence: **91/100** for scope, dependencies and repository-grounded work breakdown.
Remaining uncertainty concerns concrete sibling APIs, dependency-unit isolation/partial-state recovery and untested native/session behavior; implementation feasibility is not certified.

## 9. Planning handoff

Workstream: **F02 — Shared runtime and managed configuration**.
Source baseline: `610a18bac374e7e2ffd0bcb2d99b026131deedbc`; baseline identity supplied by the task, not rechecked with Git.
Repository mutations: **none**; no files written, edited, installed, staged or committed by this planner.
Inspected files: master; `Documents/app-selections.md`; scoped `setup.sh` sections; complete `scripts/lib/setup-reliability.sh`; all eight requested Hyprland scripts; `app_log.sh`; `sources_example/autostart.lua`; notification D-Bus service.
Also inspected: Waybar `launch_qt_gui.sh`, `float-active-window.sh`, `audio_control.sh`, `notification_status.sh`, `power_action.sh`, `nmtui.sh`, `nmtui-connect.sh`; `tests/run.sh`; requested reliability/D-Bus tests plus `reliability_failures.sh` and `roles_controls.sh`.
Validation performed: prior read/grep/ls inspection, source-to-contract comparison and proposed-path checks against existing directories; this recovery reused that evidence without further exploration.
Validation omitted: test execution, Git index/diff verification, upstream verification, graphical effects and hardware checks.
Residual risks: provisional foundation contracts; existing legacy semantic gaps; per-file versus batch recovery; XDG/Stow boundaries; singleton races; activation effects.
Canonical destination for parent integration: `plans/planned/desktop-harmonization/F02-runtime-managed-configuration.md`.
Runtime artifact delivery is handled by the enclosing workflow; no run identity is invented.