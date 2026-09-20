# D02 — Launchers and shared menus

Status: product policy synchronized with the completed interview; implementation not started. Apply master section 9 and the [decision record](../desktop-harmonization-grill.md); native launcher conformance remains unverified.
Master: [Desktop harmonization master](../desktop-harmonization-master.md).
Source baseline: `610a18bac374e7e2ffd0bcb2d99b026131deedbc`, branch `feat/harmonize-visual-design`.

## 1. Goal, scope and boundaries

Goal: preserve all five launcher choices while specifying safe application discovery, shared selection/confirmation semantics and F03-driven appearance.
Cover Wofi, Rofi, Fuzzel, Bemenu and tofi, including application launch, dmenu use, repository selection, errors, cancellation, monitor placement and toggle behavior.
Launcher remains required, single-choice and default Wofi; no launcher None option is introduced.
Other roles retain their existing None states, membership and primary routing; launcher discovery must not silently install or enable disabled roles.
Every selected member remains eligible for its domain’s appearance support; selecting a primary terminal does not restrict theme coverage to that terminal.
Desktop-entry discovery is not restricted to the selected-role inventory: installed applications outside role selections remain discoverable according to approved desktop-entry rules.
Non-goals: a second action bus, catalog, theme source, transaction engine, desktop shell, arbitrary command framework or application-data migration.
This document proposes contracts and future work only; discovery contributions may precede the foundation gate, but app implementation waits for frozen F01/F02/F03/F04 contracts.

## 2. Observed source evidence

All observations are static source findings, not verified provider behavior or test results.

| Anchor | Observed behavior and consequence |
|---|---|
| `packages.json:roles.launcher` | Five required single-choice options; Wofi default; Bemenu adds `bemenu-wayland`; tofi uses the AUR source. |
| `dotfiles/.config/hypr/scripts/menu_exec.sh` | Reads `HSS_ROLES_FILE` or HOME-based roles data; forwards normal/dmenu argv using arrays; it does not parse desktop entries. |
| Same helper, `--toggle` | Uses `pkill -u "$UID" -x -- "$process"`; success closes, status 1 opens, other failures propagate. Matching is user/process-wide, not proven session-scoped. |
| Same helper, Bemenu branch | Forces `BEMENU_BACKEND=wayland`; preserves separate application and dmenu executables. |
| `dotfiles/.config/hypr/scripts/app_log.sh` | Redirects stderr to the launcher log while preserving stdin/stdout; restrictive creation umask is attempted, but provider stderr is not sanitized. |
| `dotfiles/.config/hypr/scripts/repos_wofi.sh` | Bounded repository discovery, configurable roots/depth, exclusions, label-to-path mapping and selected TUI-editor/terminal launch already exist. |
| Same repository picker | `menu_exec.sh --dmenu || true` collapses errors into an empty-result path; line-based discovery cannot safely represent every pathname. |
| Same repository picker, label counts | Repeated labels receive suffixes; naturally suffixed labels can collide with generated suffixes, motivating identity-based selection. |
| `dotfiles/.config/wofi/config` | Centered 600×500 layout, Apps prompt, case-insensitive filtering, images/markup enabled, actions disabled and dark preference enabled. |
| `dotfiles/.config/wofi/menu.css` | Literal colors and dimensions; input outline removed, several selected styles and duplicate selected-text color declarations. |
| `dotfiles/.config/wofi/menu` | Separate Wi-Fi-menu position/field settings; its active consumer was not established and it must not be overwritten as a launcher theme. |
| `setup.sh:configure_roles` excerpts | Generates helper-based launch/toggle routes, Fish `MENU_DMENU` and launcher layer namespace; existing legacy template still contains a direct Wofi command. |
| `tests/shell/roles_matrix.sh` | Asserts catalog metadata/schema 2, wrapper argv, generated consumers, namespace and repository-picker wiring across 73 role cases. |
| `tests/shell/roles_startup.sh` | Asserts all five application argv, Bemenu backend/dependency, literal dmenu data, stderr/status propagation, helper refresh and toggle branches. |
| `dotfiles/.config/waybar/scripts/confirm_system_update.sh` | Zenity confirmation launches only on success; status 1 cancels successfully; missing dialog/launcher and other failures remain errors. |

Scoped filename searches did not identify dedicated alternative-launcher profiles; this is not proof that no indirect configuration exists.
No native desktop-entry compliance, icon support, cancellation exit mapping, focus behavior or application version was verified.

## 3. Option and capability/theme mapping

The command column records existing catalog behavior; renderer and capability columns are proposals requiring evidence.

| Option | Existing application / selection invocation | Proposed F03 consumption and limits |
|---|---|---|
| Wofi | `wofi --show drun --style {HOME}/.config/wofi/menu.css` / `wofi --dmenu` | D02-owned CSS/config mapping; consume semantic surfaces, selection, focus, fonts, spacing and image dimensions; preserve unrelated behavior keys. |
| Rofi | `rofi -show drun` / `rofi -dmenu` | D02-owned native theme/config mapping after supported syntax verification; do not presume identical drun/dmenu icon or output capabilities. |
| Fuzzel | `fuzzel` / `fuzzel --dmenu` | D02-owned native configuration mapping; verify prompt, selection identity, icon and monitor capabilities independently. |
| Bemenu | `bemenu-run` / `bemenu`, Wayland backend | D02-owned native appearance mapping; text-readable workflow required; desktop-entry parity needs a bounded helper feasibility check. |
| tofi | `tofi-drun --drun-launch=true` / `tofi` | D02-owned native configuration mapping; verify application execution separately from selection output; document text/icon limitations through P05. |

All five require independently recorded application-discovery, safe-execution, selection, cancellation, failure, keyboard and placement evidence.
Icon availability is presentation capability, not permission to omit applications or essential action meaning.
Text-only presentations must retain readable names, disambiguation and state words; approval of their appearance limits remains P01/P05-owned.
F03 supplies Mocha/Latte dark/light and asset inputs; D02 preserves existing accessibility preferences without introducing required extra variants or its own palette.
Map approved tokens to native controls, reporting unsupported radius, opacity, motion or icon features rather than claiming pixel identity.
No motion capability means no invented animation; enlarged text must not create clipped or unreachable choices.
Missing executable, renderer asset, unsupported feature and missing graphical output are different states; no hardware/session evidence means unverified or unavailable, not success.

## 4. Proposed shared contracts

Concrete identifiers, serialization and numeric exits remain F01/F02-owned and unfrozen.
D02 contributes menu-specific semantics to F02’s ordinary executable boundary, not an independent dispatcher.
Legacy `menu_exec.sh` normal, `--dmenu` and `--toggle` interfaces retain their current argv/data/status behavior until an explicitly reviewed migration.

### Selection and confirmation

- A request carries operation kind, plain prompt, finite choice records, opaque unique IDs, display labels, optional descriptions and presentation context.
- The caller retains ID-to-action/argv mapping; display labels, icons and arbitrary typed text are never executable commands.
- A result identifies exactly one offered ID or a typed cancelled/failed/unsupported/unavailable outcome; duplicate labels must remain distinguishable.
- Use provider-supported index/identity output where verified; otherwise assign collision-free display tokens and validate the entire returned selection against the request.
- Specify escaping and representability for Unicode, tabs, newlines, control characters and markup; reject unsupported transport inputs explicitly rather than truncating identity.
- Structured responses must use F02’s separate machine-facing channel; never insert JSON, diagnostics or status text into legacy dmenu stdout.
- Empty choice sets, empty labels, closed menus, invalid selections, provider errors and timeouts require separate fixtures; empty output alone does not prove cancellation.
- Cancellation performs no action and triggers no fallback; uncertain timeouts never retry non-idempotent actions automatically.
- Confirmation returns an explicit affirmative or cancellation/error outcome; the domain caller owns the actual action, authorization and effect verification.
- Recommend a non-affirmative initial selection for new confirmation interfaces, pending approval; timeout, focus loss or typing an arbitrary label must never imply consent.
- Preserve the existing update confirmation and its environment overrides until its owner approves migration; introducing shared confirmation does not mandate replacing Zenity.
- Passwords, PINs and credentials are outside this chooser contract; it is not a secret-entry or authentication interface.

### Desktop-entry discovery and execution

- Preserve Bemenu executable discovery as an explicit existing workflow; desktop-entry parity must be additive or separately consented, not a silent replacement of `bemenu-run`.
- Do not add a desktop-entry discovery/launch feature provider to fill a native gap. Configuration and adapters to an existing native application-mode API are allowed; missing native mode produces limited status and an explicit unsupported standard action.
- Specify XDG application directories, precedence, desktop IDs, same-ID shadowing, `Hidden`, `NoDisplay`, `TryExec`, `OnlyShowIn`, `NotShowIn` and localized-name fallback using authoritative evidence before freeze.
- Distinguish application entries from unsupported entry types; document desktop actions, D-Bus activation and native extras separately rather than accidentally promising them.
- Bind selection to a desktop ID and resolved source identity, not a localized display name or reconstructed `Exec` string; revalidate stale or changed entries before launching.
- Validate `Exec` quoting and supported field codes, including file/URL multiplicity and absent arguments; never pass parsed text through `eval` or an interpolated shell command.
- Preserve explicit commands authored in trusted entries, including intentional shell executables, without pretending desktop-entry launch is a sandbox.
- Resolve `Terminal=true` through the approved D05 terminal contract; preserve argv, working directory, title/app-ID behavior and missing-terminal errors.
- Preserve `Path` and relevant launch context where supported; unsupported required semantics block the affected parity claim.
- Native drun providers need real fixture evidence too; their names or successful process exits do not establish standards compliance.

### Monitor, focus and lifecycle

- Contribute explicit presentation context and supported placement modes to F02; do not invent a new default monitor/focus policy.
- Verify application launcher versus shared chooser namespaces, focus acquisition, Escape, keyboard navigation, focus restoration and missing-output handling.
- Preserve existing toggle behavior during extraction; user-wide exact-process matching remains a documented limitation, not safe ownership proof.
- A future session/request-scoped toggle requires F02 lifecycle design, provider identity evidence, compatibility cases and approval before changing semantics.
- Do not close unrelated launchers, kill launched applications on chooser cancellation or auto-reopen a failed menu.

## 5. Producer–consumer handoffs and gates

| Producer → consumer | Required deliverable and ordering |
|---|---|
| D02 → [F01](F01-inventory-capability-contracts.md), F01.2–F01.3 | Pre-foundation option rows, desktop-entry versus executable-discovery gap, text-only limits and bounded feasibility requirements. |
| D02 → [F02](F02-runtime-managed-configuration.md), F02.1/F02.3 | Pre-foundation identity, prompt, cancellation, result-channel and lifecycle specification; F02 freezes shared mechanics. |
| [F03](F03-visual-system-theme-generation.md) → D02 | Frozen renderer/token/asset/activation inputs; D02 returns five app-owned mappings and supported-effect declarations. |
| [F04](F04-verification-foundation.md) ↔ D02 | Coverage identities, isolated fixtures and evidence classes; D02 contributes scenarios before the gate and provider tests afterward. |
| [D05](D05-terminal-workspace-agents.md) ↔ D02 | Terminal-entry argv/working-directory requirements and repository-launch preservation; specification precedes adapters, integration waits for the approved implementation. |
| D02 → [D01](D01-bars-docks.md) | Launcher/chooser frontend contract and failure presentation; D01 owns bar gestures and update-menu wiring. |
| D02 → [D04](D04-device-controls.md) | Opaque device/network choice and confirmation semantics; D04 owns device identifiers, authorization and backend effects. |
| D02 → [D07](D07-session-auxiliary-interfaces.md) | Shared chooser/confirmation contract; D07 owns power, clipboard and sensitive auxiliary-action policy. |
| D02 ↔ [D06](D06-applications-default-handlers.md) | Desktop-ID and entry-launch compatibility requirements; D06 retains MIME/URL/folder policy and consent. |
| D02 → [I01](I01-integration-rollout-acceptance.md) | Serialized shared-file contributions, migration notes, coverage evidence and unresolved limitations. |

Dependency order: D02 specification contributions → foundation approval/implementation → D02 adapters/renderers → consumer wiring → I01 acceptance.
Foundation acceptance must not wait for completed D02 adapters that themselves require the foundation gate.

## 6. Implementation work packages

All packages are not started; prerequisites are future execution gates, not present authorization.

### D02.1 — Freeze launcher evidence and semantic contributions
Prerequisites: implementation/research authorization for new probes; F01 discovery and provisional F02/F04 contracts.
Ownership: D02 supplies evidence to F01’s ledger and F04’s descriptors; parent/integration owner writes shared canonical records.
Deliverables: five-option matrix, caller inventory, desktop-entry fixtures specification and P01/P05 brief for Bemenu and text-only presentation.
Intended validation: inspect local installed documentation first, then authoritative upstream material where needed; record actual versions and bounded isolated probe procedures.
Done: each required behavior has an observable outcome or explicit blocker; existing command/discovery behavior and native extras remain separately documented.

### D02.2 — Implement provider selection and confirmation adapters
Prerequisites: frozen F01/F02/F03/F04 foundation gate; approved D02.1 request/result semantics.
Ownership: D02 provider modules under proposed `dotfiles/.config/hypr/scripts/menu_adapters/`; F02/I01 owns shared dispatcher and compatibility-wrapper edits.
Deliverables: five adapters supporting stable selection identity, escaped prompts, explicit outcomes and side-effect-free confirmation responses.
Intended validation: proposed `tests/shell/launcher_menus.sh`; duplicate/suffixed labels, hostile strings, empty lists, invalid output, provider cancellation codes, failure and timeout.
Done: every supported provider returns only valid offered identities; legacy dmenu streams and argv remain unchanged and confirmation cannot execute on ambiguous input.

### D02.3 — Verify native desktop-application modes and label gaps
Prerequisites: foundation gate; D02.1 native-capability evidence; resolved P01/P05 policy; D05 terminal contract.
Ownership: D02 native configuration/API adapters; F02 owns common runtime mechanics. The previously proposed `desktop_entry_menu.py` feature provider is removed from scope.
Deliverables: native-provider conformance matrix, standard desktop-application mode where supported, and separately named executable search. Retain Bemenu's native command mode; if it lacks native desktop-application mode, label it limited and explain/disable that standard action instead of silently opening command search.
Intended validation: proposed `tests/shell/launcher_desktop_entries.sh` uses synthetic entries to test the native providers' visibility, locale, argv, terminal and working-directory behavior; it does not implement a missing discovery engine.
Done: every option's native modes and limitations are explicit, standard actions never silently change meaning, and missing capabilities block only the option's full-support claim.

### D02.4 — Render five application themes and presentation contexts
Prerequisites: foundation gate; frozen F03 renderer interface; P02 visual inputs and P05 supported configuration syntax.
Ownership: D02 app registrations/templates under proposed `theme/renderers/launchers/` and appearance contributions for existing `dotfiles/.config/wofi/`.
Deliverables: five deterministic renderers with managed-output declarations, native validators, capability limits and reload/restart/deferred activation descriptions.
Intended validation: proposed `tests/shell/launcher_themes.sh`; deterministic variants, missing assets, format rejection, text enlargement, keyboard focus and mixed-DPI/multi-monitor scenes.
Done: supported mappings consume only F03 tokens/assets; behavior settings and unrelated Wi-Fi-menu data are preserved, and graphical adoption is distinguished from rendered files.

### D02.5 — Migrate bounded consumers and preserve ownership
Prerequisites: D02.2–D02.4 supported paths; F02 lifecycle/managed-write contracts; consumer-owner approval and P06 where activation changes.
Ownership: D02 owns repository-picker adaptation in `repos_wofi.sh`; D01/D04/D07 own their callers; I01 serializes shared setup, bindings and documentation.
Deliverables: identity-safe repository selection preserving roots/depth/exclusions/editor/terminal routes; explicit failure reporting and approved chooser/toggle wiring.
Intended validation: proposed repository fixtures within `tests/shell/launcher_menus.sh`; duplicate labels, nonexistent paths, unchanged selection argv, cancellation, discovery failure and error-propagation migration.
Done: reviewed consumer routes invoke once, do not execute on cancel, preserve current user customizations and document any intentionally changed error semantics.

### D02.6 — Deliver regression, visual and recovery acceptance
Prerequisites: D02.2-D02.5; F04 evidence infrastructure and separately authorized manual VM visual/functional verification. No numeric thresholds are required.
Ownership: D02 owns its proposed suites and provider evidence; F04/I01 integrates runner coverage and final cross-role acceptance.
Deliverables: five-option evidence matrix, switching/rollback scenarios, operation notes and exact shared-file contribution packet.
Intended validation: existing role suites plus proposed D02 suites, isolated real-provider desktop launches, keyboard scenarios, consent refusal, interrupted apply and rollback divergence.
Done: required claims have the correct evidence class, all blockers remain visible, and I01 accepts the handoff without treating static/argv assertions as graphical proof.

## 7. Shared-file requests, preservation and security

Request `packages.json`/`src/packages.rs` metadata or dependency changes through F01, later I01; strict readers must change together if approved.
Request `menu_exec.sh`, `app_log.sh`, generated roles and any new helper delivery/mode handling through F02/I01; do not claim common-adapter ownership.
Request `setup.sh`, Lua/legacy bindings, namespace rules and Fish integration through I01; preserve stock-only migration and custom command boundaries.
Request shared test fixtures, runner registration and CI changes through F04/I01; D02 contributes tests, not a parallel harness.
Request F03 registration approval and output-collision review; alternative native configuration paths remain proposed until supported lookup/include behavior is verified.

Retain source templates, installed Stow targets, generated files and ephemeral chooser state as distinct objects.
Use F02 staging, validation, per-file atomic writes and recoverable batches; no domain renderer writes live destinations or performs hidden activation.
Preview managed appearance keys and conflicts; preserve unknown settings and overrides, or stop when safe merging cannot be established.
Keep schema 2, `HSS_ROLES_FILE`, selection inputs, existing catalog argv and Bemenu backend/dependency behavior operational.
Do not uninstall alternatives, migrate launch history or copy application profiles, repositories, credentials, accounts or agent configuration.
Apply approved launcher appearance on the next invocation where supported; do not terminate an open chooser or restart a session automatically.
Rollback restores the previous compatible managed files/routes with divergence checks; restoring configuration cannot undo an already launched application or confirmed action.
Use private request-scoped state, clean it on exit and avoid persistent raw candidate/query logs; repository roots and device labels may reveal private information.
Provider stderr may itself contain sensitive content: retain diagnostic reliability while designing reviewed redaction/minimization rather than claiming the existing log is secret-free.
Treat labels/icons/desktop files as untrusted inputs; disable or escape chooser markup, prevent option injection and avoid remote asset fetches.
No test may scan the host filesystem, contact host services or execute destructive confirmation actions implicitly.

## 8. Acceptance, decisions and stop conditions

Existing checks inspected, not executed: `roles_matrix.sh` and `roles_startup.sh` provide schema, argv, delivery, logging and toggle assertions.
Future existing-suite command: `bash tests/run.sh tests/shell/roles_matrix.sh tests/shell/roles_startup.sh`.
Future proposed-suite command: `bash tests/run.sh tests/shell/launcher_menus.sh tests/shell/launcher_desktop_entries.sh tests/shell/launcher_themes.sh`.
Proposed checks must include malformed/missing roles, unchanged legacy streams, unknown outcomes, literal arguments, no duplicate invocation and no private selection logging.
Real-session acceptance must independently observe the chosen application and terminal payload, not merely a successful launcher process.
Test each launcher as the selected option and in inbound/outbound switching; cross terminal-entry tests with all five D05 terminals and non-primary installed members.
Exercise dock/agent/TUI-file-manager/GUI-editor None through cross-role fixtures without treating disabled roles as launcher failures.
Visual evidence must record versions, fonts, locale, output topology, scale and approved variants; verify text-only choices remain actionable without icons.

P01 requires desktop applications on the standard launcher action and a separate executable-search action. Native-only gaps get explicit limited labels; no discovery feature is emulated.
P02 fixes Mocha/Latte native appearance; P05 requires current Arch evidence. P06 preserves conflicting user files and permits independent partial application with safe reloads. P07 uses manual VM review and functional tests, without numeric/hardware gates.
P03/P04 are resolved native-only notification/audio requirements; a chooser cannot supply a missing provider capability.
Escalate impossible desktop-entry parity, unsupported terminal semantics, ambiguous cancellation or unavoidable identity loss through F01/F02 and the parent.
Stop feature-emulation/companion proposals, unsafe process ownership or data/credential migration. Preserve conflicting user files and skip the affected unit while permitting safe independent changes under P06.
No silent approval, app removal, reduced parity or unsupported fallback may close a blocker.

## 9. Implementation checklist and confidence

1. Not started — D02.1: reconcile evidence, option coverage and pre-foundation contract contributions.
2. Not started — D02.2: implement five identity-safe selection and confirmation adapters.
3. Not started — D02.3: prove desktop-entry parity while preserving executable discovery.
4. Not started — D02.4: implement F03-driven app renderers and presentation evidence.
5. Not started — D02.5: integrate approved consumers with preserved routing and ownership.
6. Not started — D02.6: complete regression, accessibility, switching and recovery acceptance.

Planning confidence: **92/100** for source-grounded scope, ownership and identified hazards.
Runtime feasibility remains unverified; concrete foundation APIs, native desktop-entry modes and provider identity/cancellation support still need evidence. P01-P07 product choices are resolved.

## Planning handoff

Workstream: D02 — Launchers and shared menus.
Supplied source baseline: `610a18bac374e7e2ffd0bcb2d99b026131deedbc`, branch `feat/harmonize-visual-design`; not independently checked with Git.
Repository mutations: none; no implementation, installation, activation, commits or publication.
Inspected sources: entire master and F01–F04 draft artifacts; launcher catalog section; complete `menu_exec.sh`, `repos_wofi.sh`, `app_log.sh`, `term_exec.sh`, Wofi files, `roles_matrix.sh`, `roles_startup.sh` and update-confirmation helper; scoped setup, selection-documentation, caller and profile searches.
Validation performed: read-only source inspection, option/argv comparison and foundation ownership/dependency reconciliation.
Validation omitted: test execution, baseline/index checks, installed/upstream version research, desktop-entry probes, graphical captures, hardware effects and rollback execution.
Residual risks: provisional contracts, unapproved product decisions, Bemenu discovery coexistence, identity/transport limits, broad legacy toggle scope and unverified native semantics.
Canonical destination: `plans/planned/desktop-harmonization/D02-launchers-shared-menus.md`; parent alone reconciles and writes canonical plans.