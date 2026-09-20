# I01: Installer integration and branch/VM acceptance

Status: product policy synchronized with the completed interview; implementation not started. Apply master section 9 and the [decision record](../desktop-harmonization-grill.md); implementation and VM evidence remain pending.
Master: [Desktop harmonization master](../desktop-harmonization-master.md).
Supplied baseline: `610a18bac374e7e2ffd0bcb2d99b026131deedbc`, branch `feat/harmonize-visual-design`.

## 1. Scope and authority

Own capability-aware installer UX, serialized shared-file landing, dependency/setup hooks, compatibility transitions, integrated activation/recovery and final acceptance.
Assemble all changes on `feat/harmonize-visual-design`, then provide the user a step-by-step disposable Arch VM test sequence. Coordinate documentation without replacing the installer or scheduling incremental releases/publication.
Parent alone writes canonical plans and accepts shared integration; foundation and domain owners retain their technical contracts.
All interfaces below are proposals; prerequisite drafts are not implemented APIs.
Preserve every application choice, default, argv boundary, selection cardinality, primary/member distinction and optional None behavior.
Discovery and contract contributions may precede the foundation implementation gate; application implementation waits for frozen F01/F02/F03/F04 contracts.
No competing catalog, action bus, theme source, renderer framework, transaction engine or test harness is proposed.
The [bootable installer ISO plan](../bootable-installer-iso.md) remains separate: expose reusable contracts, but perform no archiso, storage, offline-image or ISO-release work.

## 2. Observed source evidence

These findings are static observations, not executed tests or compatibility certification.

| Source anchor | Observation and integration consequence |
|---|---|
| `src/main.rs:draw_role_menu` | Two-column chooser preserves source/TUI labels and primary/member markers; optional None descriptions differ by role. Extend rather than replace this interaction model. |
| `src/main.rs:package_start_blocker` | Registry errors and missing required selections block installation; no capability-policy gate currently exists. Do not silently turn missing harmonization metadata into catalog exclusion. |
| `src/main.rs:load_package_registry` | Resolves `packages.json` beside canonicalized `setup.sh`; new approved resources need installed-layout discovery and delivery tests. |
| `src/main.rs` installer command construction | Exports role inputs separately and sanitizes displayed command rather than dumping environment; preserve credential boundaries. |
| `src/packages.rs:RoleOption`, `PackagesRoot` | Strict deserialization rejects unknown fields; metadata changes require coordinated readers, validators and delivery. |
| `RoleSelection::selected_install_packages/export_env` | Package closure includes all members and extras; primary and membership export independently. Official-agent extras use pacman. |
| `setup.sh:load_role_selections/prepare_package_selections` | Unset, explicit empty, scalar-only and membership inputs differ; required packages survive filtering and unions are deduplicated. |
| `setup.sh:generate_roles_json` | Emits schema 2 and copies selected option objects; added catalog fields could propagate into runtime output. |
| `setup.sh:sync_installer_managed_runtime_files/update_configs` | Explicit refresh list preserves unrelated existing dotfiles; helper executable modes and source/installed delivery require coordinated changes. |
| `setup.sh:configure_filepicker` | GTK chooser routing and two editor MIME associations are coupled; GUI-editor None has no explicit handler-policy branch before desktop-ID lookup. |
| `scripts/lib/setup-reliability.sh` | Atomic replacement is per file; roots are allowlisted, rollback is digest-guarded and partial restoration is reportable. Batch guarantees are not established. |
| `tests/run.sh`; `.github/workflows/ci.yml` | Existing isolated shell discovery and Rust/registry checks run in Ubuntu CI; they do not establish graphical, provider-effect or hardware parity. |
| `Documents/app-selections.md`; ISO plan | Existing setup preserves alternatives and schema-2 routing; ISO defaults/policies are separately agreed and must not replace current setup defaults. |

## 3. Complete option coverage

The final matrix derives identities from F01, not this explanatory table; retain all 73 role-option rows and four None states.
Multiple-choice roles require every member as primary and non-primary; single-choice roles retain their existing replacement semantics.

| Role | Options retained | Domain |
|---|---|---|
| Browser | Firefox, Chromium, Vivaldi, Zen, Brave | D06 |
| Shell | Bash, Fish, Zsh | D05 |
| Terminal | Kitty, Alacritty, Ghostty, Konsole, Foot | D05 |
| Multiplexer | tmux, Zellij, Herdr | D05 |
| Graphical file manager | Dolphin, Thunar, Nautilus, Nemo, PCManFM-Qt | D06 |
| TUI file manager | Yazi, Ranger, lf, nnn, Midnight Commander, Vifm, None | D06/D05 |
| Notifications | SwayNC, Mako, Dunst, Fnott | D03 |
| TUI editor | Neovim, Helix, Vim, Nano | D06/D05 |
| GUI editor | Zed, VS Code, Cursor, Kate, Mousepad, None | D06 |
| Bar | Waybar, Ironbar, nwg-panel | D01 |
| Dock | nwg-dock-hyprland, nwg-panel, None | D01 |
| Calendar | Merkuro, GNOME Calendar, KOrganizer, Calcurse, Khal | D06 |
| Bluetooth | Blueman, Bluedevil, Bluetui, Bluetuith | D04 |
| Network | nm-applet, nm-connection-editor, nmtui, plasma-nm | D04 |
| Audio | Pavucontrol, Pavucontrol-Qt, QasMixer, Alsamixer, Ncpamixer | D04 |
| Launcher | Wofi, Rofi, Fuzzel, Bemenu, tofi | D02 |
| Coding agents | Pi, OpenCode, Claude Code, Codex CLI, Cursor CLI, None | D05 |

D07 additionally supplies session/security, wallpaper/display, capture/clipboard, custom dialogs and auxiliary-package coverage.
F01 reconciles its generic-package classification and role-extra dependencies; no remaining package may disappear between domain and release inventories.
None produces no member-specific theme/activation request; GUI-editor fallback, TUI-file-manager unavailable behavior, dock no-op and agent disablement remain distinct.
Global toolkit settings may affect unselected applications; disclose that reach rather than claiming per-member isolation.

## 4. Incoming and outgoing handoffs

| Producer → consumer | Required handoff |
|---|---|
| [F01](F01-inventory-capability-contracts.md) → I01 | Approved option/capability identities, dependency closure, compatibility strategy and evidence limits; I01 returns chooser/installer requirements. |
| [F02](F02-runtime-managed-configuration.md) → I01 | Frozen action/status, managed-write, lifecycle and recovery contracts; I01 returns installer ordering, failure propagation and upgrade cases. |
| [F03](F03-visual-system-theme-generation.md) → I01 | Tokens, assets, renderer coverage and activation reports; I01 wires presentation/consent without owning theme semantics. |
| [F04](F04-verification-foundation.md) → I01 | Coverage descriptors, isolation, evidence levels and visual protocol; I01 owns final execution matrix and release evidence. |
| [D01](D01-bars-docks.md) → I01 | Full active-bar operation mapping, nine bar/dock combinations, process-sharing and frontend evidence. |
| [D02](D02-launchers-shared-menus.md) → I01 | Five-launcher limits, safe selection/desktop-entry behavior and preserved Bemenu discovery. |
| [D03](D03-notifications-attention.md) → I01 | Four-provider effects, P03 disposition, singleton switching and retention/privacy limits. |
| [D04](D04-device-controls.md) → I01 | Thirteen-option device coverage, connect/edit distinctions, applet/pairing ownership and P04 disposition. |
| [D05](D05-terminal-workspace-agents.md) → I01 | Shell/terminal/multiplexer/agent compatibility, terminal consumers, installer/triage preservation and native theme limits. |
| [D06](D06-applications-default-handlers.md) → I01 | Thirty-option application coverage, two None states, verified handler intents and calendar first-use limits. |
| [D07](D07-session-auxiliary-interfaces.md) → I01 | Generic inventory, session/authentication ownership, privileged greeter boundary and auxiliary acceptance evidence. |
| I01 → parent/user | Serialized contribution queue, decision briefs, acceptance report, documentation and explicit release blockers; no automatic approval. |

### Proposed I01-owned integration presentation

Compose a preview from approved producer outputs: selection delta, primary routing, member theme coverage, package additions/reasons, managed destinations, activation effects and unresolved decisions.
Reference producer identities/revisions rather than defining another capability schema; F04 owns evidence format and F02 owns transaction records.
Show requirement level, native/native-API-adapter mechanism and evidence status separately from runtime availability. Feature-filling companions and replacement features are excluded; limited apps remain selectable with honest unsupported actions.
Distinguish None, missing package/asset, unsupported feature/version, absent hardware/session, stale observation, cancellation, denial and failure.
Keep all options selectable under existing catalog rules; an unresolved mandatory capability blocks harmonization acceptance, not silent application removal.
Preserve Space, `p`, Enter/Escape/`q`, scrolling, focused-row readability and required-empty validation; use text labels, not color alone.
Preview genuine native-workflow dependencies and theme assets. No companion-consent workflow is needed because companions are outside scope. Existing warning auto-continue/default-yes settings must not silently authorize adoption of user-owned configurations.
Installer appearance may consume F03 through an I01-owned mapping; retain current appearance until approved, with no second palette authority.

## 5. Shared-file landing order and reconciliation

| Landing stage | Owner and bounded integration rule |
|---|---|
| Specification intake | Domains contribute discovery/oracles to F01–F04; I01 inventories shared changes without requiring completed domain adapters. |
| Catalog compatibility | F01 owns `packages.json`, `src/packages.rs` and registry validation; approved readers/validators land before new metadata emission. |
| Runtime foundation | F02 owns `setup.sh`, reliability library and common adapters; retain compatibility wrappers and existing runtime schema strategy. |
| Theme/test foundation | F03 owns theme core/global settings; F04 owns common fixtures, `tests/run.sh` and initial CI changes; representative integration closes the foundation gate. |
| Early incremental integration | After foundation freeze, I01 serializes chooser, delivery and setup-hook changes as domain contributions become ready; all domains need not be complete. |
| Provider then frontend wiring | D02/D03/D04/D07 backends precede full D01 behavior acceptance; D05 terminal implementation precedes dependent D06 integration. |
| Final integration | I01 reconciles shared files, full transition matrix, documentation and release evidence only after required D01–D07 outputs exist. |

Submit each contribution with producer/consumer revisions, exact paths, dependency/ownership impact, preservation rules, migration tests and rollback limits.
Later shared edits to `sources_example/{autostart,keybindings,app_variables,environment_variables,windows_and_workspaces}.lua`, affected legacy counterparts and `update-waybar-roles.py` route through I01.
Same-tree writes remain serialized; independent worktrees require explicit path ownership. Never stash/reset user changes to obtain a clean integration base.

Parent-reconciled planning boundaries and remaining technical gates:
- F01's proposed `capabilities.json` placement/versioning and runtime projection remain unfrozen; missing metadata must preserve legacy routing while withholding unsupported harmonization claims.
- Legacy helper ownership is assigned in the master's helper handoff table: F02 mechanisms, domain provider semantics and D01 presentation. I01 serializes wrapper/caller patches before migration; preserved legacy behavior is not a promise to retain known false-success semantics in the new API.
- F02 must prove batch isolation and approved XDG roots; D07 SDDM theme assets require a separately reviewed privileged boundary, not a broad allowlist expansion.
- F03.2 owns the ANSI token contract requested by D05. P02 fixes Mocha/Latte and Blue; I01 consumes canonical theme values instead of inventing colors. Required switching controls are installer, Super+Shift+T and each supported bar, backed by one internal action.
- D03 defines three named notification suites and separate D03.6 real-provider/visual procedures; there is no unnamed fourth shell suite.
- D07.1 supplies the authentication specification before F02.4; D07.2 implements it after the foundation gate. F03.3a supplies the pure renderer sample before F02.5; F03.3b validates integration afterward.
- F04 accepts owned planned/not-run test references during foundation specification, but delivered references and passing claims need files and evidence respectively.

## 6. Concrete work packages

### I01.1 — Establish the integration ledger and gate sequence
Status: not started. Prerequisites: authorization and baseline recheck; specification intake may precede foundation implementation.
Ownership: I01 integration records; parent canonical plans; producer owners retain contract definitions.
Deliverables: shared-file queue, contract-revision matrix, decision/blocker register and reader-before-writer delivery sequence.
Identify installed resource discovery beside resolved `setup.sh`, legacy wrappers and all shared destination collisions.
Intended validation: catalog/descriptor coverage review, dependency-cycle check and negative stale-contract cases through F04.
Done: every handoff has one accountable producer/consumer and landing owner; foundation evidence does not depend on completed domain adapters.

### I01.2 — Implement capability-aware chooser and preview
Status: not started. Prerequisites: foundation gate, approved F01 definitions and applicable P01/P02/P05 policies.
Ownership: `src/main.rs` and its Rust UI tests; F01 approves metadata-reader contributions.
Deliverables: concise capability details, dependency explanations, selected-member theme report and separate harmonization/activation blockers.
Preserve all selection controls, defaults, None descriptions, generic-package filtering and existing environment export.
Intended validation: extend existing TestBackend cases at normal, short and tiny sizes; test long labels, missing metadata, native-only limited options and unchanged exported selections.
Done: every choice remains reachable; unknown support is honest, and neither viewing nor confirming a selection silently approves activation.

### I01.3 — Integrate dependency, delivery and setup hooks
Status: not started. Prerequisites: foundation gate, I01.1 ordering and available approved domain contribution packets.
Ownership: I01 later integration of `setup.sh`, reliability hooks, managed-sync lists and shared Lua; F01 reviews catalog/Rust changes.
Deliverables: deterministic closure preview, approved resource delivery and F02/F03 staging/validation hooks integrated into existing setup.
Preserve required/generic/member package unions, official-agent allowlists and extras semantics; no package installation is triggered by rendering.
Intended validation: proposed `tests/shell/harmonization_installer.sh`, installed-layout fixtures, missing resources/modes, closure mismatch and hard-failure propagation.
Done: preview and execution agree; failed validation prevents harmonization activation, while unchanged legacy selection/installer contracts remain covered.

### I01.4 — Prove transition, activation and recovery behavior
Status: not started. Prerequisites: I01.3, F02 recovery proof, F03 activation descriptors and applicable P06 approval.
Ownership: I01 transition tests and orchestration; F02 owns mutation mechanisms, F03 theme orchestration and domains provider effects.
Deliverables: fresh/rerun/switch/upgrade matrix, consented activation ordering, partial-state reporting and operator recovery procedure.
Separate theme-only application from existing setup's package, shell, service and administrative operations; no full setup rerun as a hidden theme action.
Intended validation: proposed `tests/shell/harmonization_transitions.sh`; injected render/write/reload failures, interruption, user divergence and foreign singleton ownership.
Done: preserved files/routing and runtime effects are independently verified; declined consent leaves activation pending and recovery never silently overwrites newer edits.

### I01.5 — Execute final cross-role acceptance
Status: not started. Prerequisites: required D01–D07 implementations/evidence, I01.2–I01.4, F04 infrastructure and applicable P01–P07 approvals.
Ownership: I01 final matrix and execution schedule; domains own probes, F04 owns methodology/common fixtures.
Deliverables: proposed `Documents/desktop-harmonization-acceptance.md`, referencing F04 descriptors and exact candidate/contract identities.
Combine exhaustive option/member/None coverage with declared interaction sampling and explicit high-risk combinations; do not claim Cartesian coverage.
Intended validation: existing checks plus proposed integration suites, independent real effects, reviewed screenshots, accessibility and approved physical-device scenarios.
Done: each supported claim has sufficient passing evidence, native gaps remain selectable/limited, and unverified hardware is labeled accurately. Prepare branch delivery and the user VM checklist; do not require every selectable app to claim full parity.

### I01.6 — Complete branch delivery documentation and VM test handoff
Status: not started. Prerequisites: I01.5 branch-level evidence and truthful limitation reporting; user-led VM sessions and any future activation/publication need their appropriate authorization.
Ownership: I01 user documentation/rollout contributions; parent acceptance and canonical-plan lifecycle.
Deliverables: updated `Documents/app-selections.md`, coordinated agent notes and proposed `Documents/desktop-harmonization-vm-testing.md`. Sequence VM checks through foundations, theme switching, every role/option, independent partial application and recovery; provide expected results and evidence fields.
Document preview, preservation, consent, next-launch/relogin requirements, recovery, limitations and supported/tested environments.
Intended validation: disposable-install walkthroughs, old-entrypoint/package-layout smoke tests and documentation-to-evidence/link checks.
Done: rollout instructions match verified behavior; release authorization remains separate, and the plan family stays planned until implementation acceptance.

## 7. Preservation, migration, activation and rollback

| Scenario | Required contract |
|---|---|
| Fresh installation | Existing defaults remain; approved dependencies/assets resolve before rendering; absent session produces deferred activation, not a false success. |
| Identical rerun | Stable outputs and package closure; no duplicate services or repeated consented external effects; preserve executable modes and Stow topology. |
| Primary/member switch | Primary routing changes independently of member appearance; all retained members remain themed and deselected applications are not uninstalled. |
| Optional transitions | Test option↔None and repeated None for all four roles; preserve each role's distinct fallback/unavailable/no-op behavior. |
| Existing schema-2 upgrade | Retain scalar-only, unset and explicit-empty inputs, agent executable metadata, argv arrays and known helper paths. |
| Missing/new metadata | Missing harmonization metadata leaves legacy use available; malformed/incompatible harmonization input stops affected writes, not best-effort conversion. |
| Theme/handler activation | Preview effects; approved primary selection also applies its URL/folder/file associations. GUI-editor None uses the primary TUI editor through a managed desktop entry. Reload safely or report deferred next-launch/relogin activation. |
| Recovery/downgrade | Restore a compatible managed configuration/resource set through F02; unsupported older-reader combinations fail clearly before writes. |

Stage and validate candidates before commit; promise per-file atomic replacement and recoverable batches only after F02 proves their boundaries.
Preserve user regions, custom bindings, profiles, locale settings and nonappearance preferences. Skip conflicting app configs while applying independent valid units, reporting partial state. A launchable primary may switch routing/associations despite an appearance-only conflict; a broken runtime/shared prerequisite blocks its dependents.
No automatic app/session restart, foreign-owner takeover, `chsh` or greeter restart. Handler changes accompany an approved primary-selection application, never an incidental theme-only toggle.
Rollback distinguishes restored files, restored associations, attempted provider recovery and unresolved live effects.
Do not roll back unrelated setup writes or imply package/vendor-installer rollback; already executed power, update, pairing or notification actions are not reversible configuration state.

## 8. Final acceptance and evidence

Existing checks are present, not executed here: Rust chooser/selection tests; registry validation; role, membership, argv, startup, agent and reliability shell suites.
Future existing commands: `cargo fmt --check`, `cargo clippy --locked --all-targets -- -D warnings`, `cargo test --locked`, `bash tests/check_packages_json.sh`, `bash tests/run.sh`.
Proposed integration commands after creation: `bash tests/run.sh tests/shell/harmonization_installer.sh tests/shell/harmonization_transitions.sh`.
`tests/verify_hypr_config.sh` remains version-sensitive; its missing-Hyprland exit 3 must remain an explicit skip, not graphical acceptance.
F04 owns suite isolation and common CI changes; I01 integrates later suites without replacing the runner or treating Ubuntu CI as target-desktop proof.

| Cross-role slice | Required evidence |
|---|---|
| Entire catalog | Every option, four None states, primary/non-primary and all-member fixtures, inbound/outbound switching and unchanged defaults. |
| Panels/providers | All nine bar/dock combinations; every approved active Waybar operation; each notification/device provider with frontend wiring and ownership evidence. |
| Launchers/terminals/apps | All five launchers and terminals; desktop-entry/cwd/argv effects; D06 file/editor/calendar workflows and None fallback. |
| Shells/multiplexers/agents | Preserved locale/environment, session targeting and click-only at-most-once triage; offline synthetic agents, no authentication requirement. |
| Theme/toolkits | Every selected-member mapping; GTK/Qt/KDE, native-constrained/custom/TUI surfaces; assets, actual adoption and global-setting reach. |
| Session/auxiliary | Lock/authentication ownership, power policy, wallpaper/capture/clipboard, custom dialogs and generic-package dispositions. |
| Reliability | Stow/custom roots, user edits, failed staging/commit/activation, concurrent attempts, interruption and guarded partial recovery. |
| Readability/hardware | Readable focus and dark/light appearance in the VM; preserve existing accessibility preferences and mark unavailable physical device/mixed-DPI/power evidence unverified. |

Screenshots record candidate/provider versions, tokens/renderers, assets/fonts, locale, geometry, scale, output topology and synthetic scene identity.
Use F04 manual visual review and functional assertions in the disposable Arch VM. Screenshots are supporting evidence, not a numerical comparison gate; masks must not conceal missing controls or errors.
Real-effect oracles are independent of adapter output; argv success, generated files and screenshots cannot substitute for delivery, routing, locking or device effects.
Record VM/headless context and observed functional failures; numeric performance budgets are not required. Missing physical hardware remains explicitly unverified with a reason and visible unavailable UI state.
Deliver all changes on this branch for user-led step-by-step VM testing. Supported, limited, failed and unverified are separate labels; no full-parity claim for a limited option and no incremental release/publication program.

## 9. Security, decisions and escalation

Use synthetic profiles, notifications, calendars, repositories and clipboard content; do not migrate credentials, accounts, browser profiles, extensions or agent configuration.
Exclude passwords, PINs, notification bodies, private paths/URLs and sensitive device identifiers from previews, logs and published evidence.
Renderers never execute user hooks, bootstrap plugins, fetch remote assets or contact authenticated providers; real-session effects require separate opt-in and cleanup.
Do not weaken polkit, broaden privileged roots, run destructive power/device/administrative tests in ordinary CI or equate read-only agent modes with sandboxing.

| Decision | Resolved policy and evidence still needed |
|---|---|
| P01 | Native desktop workflows, active Waybar operations and the requested theme control; full-support requirements stay distinct from selectable limited options. |
| P02 | Mocha/Latte, Blue, Noto Sans/JetBrains Mono, Breeze icons, verified Rose Pine fallback; installer/keybinding/bar switching. Validate native mappings and manually review the result. |
| P03 | Native full-attention workflow; critical exceptions only in unlocked DND; no content while locked; native persistent history capped at 24 hours and 100 entries. Verify APIs/privacy, do not add storage/companions. |
| P04 | Native per-app routing for full support; retain ALSA-only choices as limited when necessary. No companion or forced mixer replacement. |
| P05 | Current tested Arch packages, explicit version evidence and support labels; other distributions and unavailable physical hardware unverified. |
| P06 | Preview/preservation, independent partial application, primary-following handlers and TUI-handler fallback; safe reloads, Hyprpolkitagent and current-session logout. Verify technical safety before activation. |
| P07 | Assemble the branch and hand off step-by-step user VM tests. Functional checks and manual visuals; no numeric thresholds or physical certification. |

Escalate infeasible mandatory capabilities, missing dependencies, unsafe ownership, unproven batch recovery, credential/data migration or incompatible reader rollout.
A declined companion, unavailable test environment or failed spike does not authorize reduced parity, application removal or a new default.

## 10. Not-started checklist and confidence

1. Not started — I01.1: reconcile contracts, shared-file ownership and acyclic landing order.
2. Not started — I01.2: implement capability-aware chooser and explicit preview.
3. Not started — I01.3: integrate approved dependencies, delivery and setup hooks.
4. Not started — I01.4: prove transitions, consented activation and recovery.
5. Not started: I01.5, complete supported-workflow checks, manual VM visuals and honest limitation labels.
6. Not started: I01.6, validate branch documentation and the step-by-step user VM test handoff.

Planning confidence: **93/100** for source-grounded integration scope and ordering.
Implementation feasibility remains conditional on concrete contracts, native provider support and unperformed graphical/recovery checks. Product policy is resolved; physical hardware remains outside current verification scope.

## Planning handoff

Workstream: **I01 — Installer integration, rollout and release acceptance**.
Supplied source baseline: `610a18bac374e7e2ffd0bcb2d99b026131deedbc`, branch `feat/harmonize-visual-design`; not independently Git-verified.
Repository mutations: **none**; no implementation, installation, activation, commits or publication.
Inspected sources: entire master, all eleven prerequisite drafts, complete selection documentation and ISO plan; scoped `src/main.rs`, `src/packages.rs`, catalog roles, setup/reliability functions, runner, CI, registry validator, compositor verifier and shell-test inventory.
Validation performed: read-only source inspection, option/handoff/ownership comparison and existing-versus-proposed validation separation.
Validation omitted: command/test execution, Git/index checks, installed/upstream version verification, screenshots, real effects, hardware and rollback execution; no compatibility results are claimed.
Residual risks: concrete interfaces, privileged/session boundaries, metadata delivery, dependency-aware partial recovery and incomplete native/VM evidence. P01-P07 product choices are resolved.
Canonical destination: `plans/planned/desktop-harmonization/I01-integration-rollout-acceptance.md`; parent alone reconciles and writes canonical documentation.