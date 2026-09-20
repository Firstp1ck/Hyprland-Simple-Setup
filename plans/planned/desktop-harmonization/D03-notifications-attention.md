# D03 — Notifications and attention

Status: product policy synchronized with the completed interview; implementation not started. Master section 9 and the [decision record](../desktop-harmonization-grill.md) define P03; provider-native feasibility remains pending.
Master: [Desktop harmonization master](../desktop-harmonization-master.md).
Supplied baseline: `610a18bac374e7e2ffd0bcb2d99b026131deedbc`, branch `feat/harmonize-visual-design`.

## 1. Goal, scope and boundaries

Goal: preserve all four notification choices while providing explicit attention operations, truthful status, coherent appearance and safe singleton ownership.
Cover SwayNC, Mako, Dunst and Fnott; distinguish notification delivery, center visibility, history, dismissal, DND and notification actions.
D03 owns provider semantics, provider-specific adapters, application renderers and domain tests.
Consume F01's capability ledger, F02's runtime/transactions, F03's renderer interface and F04's verification infrastructure; create no competing framework.
Notifications remain required and single-choice, with the existing SwayNC default; no notification None option is introduced.
Preserve primary/member distinctions across the desktop and all existing optional None states; unrelated choices must not affect notification routing.
Preserve selection/environment inputs, literal argv, compatibility entry points, Stow topology and reliability guarantees.
No replacement daemon, companion interface, custom history cache or interception service is allowed. Native retention settings are an approved product requirement, but their adoption still needs preview and implementation verification; no installation or activation is authorized now.
Discovery and contract contributions may precede foundation implementation; application implementation waits for frozen F01/F02/F03/F04 contracts.

## 2. Observed source evidence

These observations describe repository contents, not tested provider capabilities or current upstream guarantees.

| Inspected anchor | Observation and consequence |
|---|---|
| `packages.json:roles.notifications` | Required, single-choice; `swaync`, `mako`, `dunst`, `fnott`, each with matching executable and empty catalog argv. |
| `dotfiles/.config/hypr/scripts/notification_control.sh` | Reads `HSS_ROLES_FILE` or the HOME-based roles file; defaults to `toggle`; unsupported combinations exit 2. |
| Same helper: SwayNC | `toggle` executes `swaync-client -t -sw`; `dnd` executes `swaync-client -d -sw`. |
| Same helper: Mako | `toggle` executes `makoctl dismiss --all`; `dnd` executes `makoctl mode -t do-not-disturb`. |
| Same helper: Dunst | `toggle` executes `dunstctl history-pop`; `dnd` executes `dunstctl set-paused toggle`. |
| Same helper: Fnott | `toggle` executes `fnottctl dismiss all`; `dnd` exits successfully without invoking a command. |
| `dotfiles/.config/waybar/scripts/notification_status.sh` | SwayNC delegates to `swaync-client -swb`; other providers emit a static bell/tooltip every five seconds. |
| `dotfiles/.config/waybar/config.jsonc:custom/notification` | Active module; left click invokes legacy `toggle`, right click invokes `dnd`; icon definitions include DND and inhibited combinations. |
| `dotfiles/.config/swaync/config.json` | Enables inhibitors/title/DND/notifications widgets; timeouts are 10/5/0 for normal/low/critical; transition time is 200. |
| Same configuration | Keyboard shortcuts enabled, inline replies disabled, 2FA action enabled; example scripts and a Spotify visibility rule exist. Preserve behavior separately from styling. |
| `dotfiles/.config/swaync/style.css` | Literal colors, urgency borders, radii, typography and several transition durations; focus uses background styling despite removed outline. |
| `dotfiles/.config/` inventory | SwayNC has shipped configuration; no Mako, Dunst or Fnott profile directories were found in the scoped inventory. |
| `dotfiles/.local/share/dbus-1/services/org.freedesktop.Notifications.service` | Activation delegates to `role_exec.sh notifications`; `role_exec.sh` dispatches the selected executable using argv arrays. |
| `setup.sh:configure_roles`; `sources_example/autostart.lua` | Autostart also invokes the notification role after a sleep; this is not proof of ownership/readiness coordination. |
| `setup.sh:sync_installer_managed_runtime_files` | Explicitly refreshes both notification helpers and the D-Bus service via atomic copying; executable-mode failures propagate. |
| `scripts/lib/setup-reliability.sh:hss_path_is_approved` | Notification service source/runtime locations are exact HOME-based exceptions, not permission to manage arbitrary D-Bus service files. |
| `tests/shell/roles_controls.sh` | Asserts exact legacy argv and Fnott's no-op; does not prove delivery, DND suppression or history behavior. |
| `tests/shell/roles_dbus_atomic.sh` | Asserts service symlink preservation, creation rollback, adjacent-path rejection and escaping-symlink rejection; does not test live bus ownership. |

`Documents/app-selections.md` already warns that notification providers expose differing controls.
Existing test comments cite command references, but those references were not independently revalidated here.
Local Hyprland search/extract tools were unavailable; no web lookup or version-dependent documentation claim is made.

## 3. Option, capability and theme mapping

The following is a discovery/renderer proposal, not a second capability catalog; approved records belong to F01.

| Option | Behavior needing verification | D03 appearance mapping consuming F03 |
|---|---|---|
| SwayNC | Center versus history semantics, DND readback, inhibitors, counts, dismissal, actions and restart retention. | Existing JSON/CSS: popup and center surfaces, urgency, focus, actions, timestamps, empty state and motion. |
| Mako | Whether the configured mode actually suppresses delivery; queryable state; history access/actions and dismissal scope. | Proposed native configuration mapping for font, surfaces, borders, urgency, geometry and supported interaction states. |
| Dunst | Pause semantics/readback; history-pop versus history browsing; dismissal, action validity and queue behavior. | Proposed native configuration mapping for typography, surfaces, urgency sections, dimensions and action affordances. |
| Fnott | Dismissal scope; bounded proof of DND/history/status possibilities; never infer support from the current no-op. | Proposed native configuration mapping for typography, surfaces, urgency, dimensions and supported interaction states. |

Native configuration keys, formats, reload commands and minimum versions require evidence before implementation.
Map semantic urgency without inventing urgency policy; presentation changes must not rewrite timeout or critical-notification behavior.
Apply approved Mocha/Latte dark/light inputs using native provider features; preserve existing accessibility preferences without adding mandatory variants.
For SwayNC, evaluate both JSON transition settings and CSS transitions; changing only one is insufficient evidence of reduced motion.
Prove keyboard operation, visible focus, readable long text, missing-icon fallback, action labels and mixed-DPI/multi-monitor placement.
The notification member is singular today; renderer selection nevertheless follows F03 member identities, not executable discovery or arbitrary installed alternatives.
Unavailable visual controls remain explicit limitations; pixel identity and unverified native configuration support are not promised.

## 4. Proposed semantic contracts

Names below are illustrative contributions to F01/F02, not frozen APIs.

| Operation | Required distinction and observable outcome |
|---|---|
| `notifications.center.open/close` | Changes center visibility only; cannot silently dismiss notifications or replay history. |
| `notifications.history.open` | Exposes retained entries under the approved policy; distinguishes an empty history from unavailable retrieval. |
| `notifications.history.replay` | Separate optional/native operation where supported; never presented as equivalent to browsing a center. |
| `notifications.dismiss` | Explicit target/scope, such as one active item or all active items; not synonymous with erasing retained history. |
| `notifications.history.clear` | Separate retention-changing operation with approved scope/confirmation policy; no accidental invocation from ordinary dismissal. |
| `notifications.dnd.set` | Explicit desired state and independently observed readback; a toggle convenience must not falsely report the requested state as observed. |
| `notifications.action.invoke` | Uses provider-scoped notification/action identity; distinguishes expiry, sender loss, cancellation and invocation failure. |
| Notification status | Reports observed provider/owner, readiness, DND, inhibition, center visibility and counts only where independently available. |

Distinguish active, queued, retained and unread counts; unsupported unread semantics must never become a fabricated zero.
Status carries availability, freshness and error information through F02, without icon names, markup, notification bodies or frontend text.
Do not start a daemon merely to inspect status; ownership/status probes must account for accidental activation.
Differentiate missing executable, unsupported capability/version, inactive service, ownership conflict, stale/unknown observation, timeout and command failure.
Notifications have no hardware prerequisite; absent display/session is unavailable environment, not a disabled role or successful headless visual test.
Unlocked DND suppresses low/normal popups but allows critical notifications. While locked, no notification content may appear, including critical notifications; DND alone is not the lock barrier. History must use native persistence capped at both 24 hours and 100 entries, with native expiration while running and purge-before-display on restart.
Delivery/action tests cover replacement IDs, close reasons, sender disappearance, expiration and default/explicit action selection.
Preserve sender timeout requests and existing user rules; record any provider-imposed limits rather than choosing universal timeout defaults.
No automatic retry of uncertain action invocation, dismissal or toggles; cancellation must not select a fallback action.
Legacy helper behavior remains available during extraction; new semantic APIs must not copy Fnott's false-success capability claim.

## 5. Producer-consumer handoffs and gates

| Producer → consumer | Deliverable and dependency |
|---|---|
| D03.1–D03.2 → [F01](F01-inventory-capability-contracts.md) | Four option evidence contributions, observable requirements, P03 feasibility brief and dependency costs; pre-foundation specification work. |
| F01 → D03 | Approved identities, P01 requirements, P03 disposition and P05 compatibility envelope; no private D03 catalog. |
| D03 → [F02](F02-runtime-managed-configuration.md) | Semantic distinctions, readback requirements, privacy limits and user-bus ownership cases for F02.1/F02.4. |
| F02 → D03.3–D03.5 | Frozen invocation/status/lifecycle/managed-write contracts; mechanisms remain F02-owned. |
| [F03](F03-visual-system-theme-generation.md) → D03.4 | Approved tokens, assets, pure-renderer registration, output ownership and activation descriptors. |
| D03 ↔ [F04](F04-verification-foundation.md) | Early independent-effect oracles and fixture requirements; later domain tests, evidence descriptors and visual cases. |
| D03 → [D01](D01-bars-docks.md) | Presentation-free notification actions/status and truthful support limits; D01 owns all bar presentation and gestures. |
| [D02](D02-launchers-shared-menus.md) → D03, conditionally | Shared presentation may invoke documented native provider actions; it must not implement a missing history center, persistence or DND capability. |
| D03 ↔ [D07](D07-session-auxiliary-interfaces.md) | Lock-session exposure and activation-order requirements; do not assume DND provides a privacy lock. |
| D03 → [I01](I01-integration-rollout-acceptance.md) | Shared-file requests, migration/support notes, switching evidence and unresolved blockers for release acceptance. |

Foundation freezing may use representative fixtures, not completed D03 adapters.
Backend semantics must not depend on D01 widgets or Waybar filesystem paths; frontend wiring follows backend implementation.

## 6. Concrete work packages

### D03.1 — Inventory and freeze operation distinctions
Status: not started. Prerequisite: authorized discovery; F01/F02 draft coordination, before foundation implementation where useful.
Ownership: D03 supplies contributions to F01's ledger and F04's coverage descriptor; their owners integrate shared records.
Deliverables: provider/version evidence template, exact legacy-call matrix, native-extra classification and proposed action/status definitions from §4.
Inventory native configuration, notification capabilities, timeout/urgency rules, history storage, action callbacks and startup ownership without reading personal history.
Validation: reconcile all four catalog choices and every known caller; map each proposed requirement to an independent observable outcome.
Done: F01/F02/F04 accept the specification contribution; unproved capability fields remain blocked rather than inferred.

### D03.2 — Bound P03 feasibility and retention policy
Status: not started. Prerequisite: D03.1 candidate requirements and separate authorization for isolated provider spikes.
Ownership: D03 supplies evidence and recommendations; F01 reconciles capability records; the user resolves P03.
Deliverables: finite probe matrix for DND suppression/readback, history retrieval, retained actions, status and restart behavior for all four providers.
Use synthetic events in a disposable session/private bus; record exact versions, configuration, commands, observations and cleanup.
Test only native APIs/configuration and adapters to those APIs. No helper/companion research, bus interception, custom persistence or feature emulation is part of this work.
Where a provider cannot meet history/DND/privacy requirements natively, keep it selectable with a limited label, preserve ordinary native launch and explain/disable the unsupported standard action.
Validation: compare observed delivery/state against requested operations, including urgency exceptions, restart loss and unavailable APIs.
Done: native evidence is mapped to the resolved P03 requirements. Unsupported providers have explicit limited status and cannot claim full parity; they do not block delivery of the entire branch.

### D03.3 — Implement provider actions and truthful status
Status: not started. Prerequisite: frozen F01/F02/F03/F04 contracts, D03.1 definitions and applicable P03/P05 approvals.
Ownership: D03 owns provider modules under proposed `dotfiles/.config/hypr/scripts/notification_providers/`; F02 owns shared dispatch.
Deliverables: four adapters, capability-aware errors, bounded observations and legacy compatibility contributions for `notification_control.sh`.
Keep existing argv/selection routes intact until reviewed migration; provide new explicit operations without silently redefining `toggle`.
Validation: proposed `tests/shell/notifications_contracts.sh` uses F04 stateful doubles for readback, cancellation, missing dependencies, malformed state and uncertain timeouts.
Done: supported operations satisfy independent modeled-effect assertions; unsupported operations are honest and no shared state contains frontend markup or private content.

### D03.4 — Implement four application renderers
Status: not started. Prerequisite: foundation gate, F03 renderer registration and applicable P02/P05 approvals.
Ownership: D03 owns proposed `theme/renderers/notifications/` registrations/templates within F03's framework.
Deliverables: mappings for existing `dotfiles/.config/swaync/{config.json,style.css}` and proposed Mako/Dunst/Fnott profiles.
Proposed profile paths are `dotfiles/.config/mako/config`, `dotfiles/.config/dunst/dunstrc` and `dotfiles/.config/fnott/fnott.ini`; verify native discovery before adopting them.
Render staged appearance only; preserve scripts, filtering, shortcuts, urgency policy, timeout rules and other nonappearance configuration.
Validation: proposed `tests/shell/notifications_rendering.sh` covers deterministic output, format validation, all approved variants, unknown user keys and missing assets.
Done: each option has verified mapping or an explicit blocked visual requirement; managed ownership and native activation limitations are registered with F03/F02.

### D03.5 — Integrate singleton lifecycle and reversible switching
Status: not started. Prerequisite: foundation gate, D03.3/D03.4 and P06 approval before changed activation.
Ownership: F02 supplies lifecycle/transaction mechanisms; D03 specifies provider readiness; I01 integrates service, setup and autostart contributions.
Deliverables: coordinated activation for autostart and D-Bus requests; selection-versus-active-provider reporting; migration and recovery instructions.
Enforce one `org.freedesktop.Notifications` owner per user bus, including multiple compositor sessions; a per-session lock is insufficient.
Reject foreign-owner takeover; stop only a verified setup-owned provider under approved switching policy, then check release/acquisition and readiness.
Validation: proposed `tests/shell/notifications_lifecycle.sh` covers concurrent launches, provider crash, foreign owner, failed acquisition, declined activation and failed restoration.
Done: singleton effects and recoverable file changes are independently demonstrated; runtime recovery remains separate from file rollback.

### D03.6 — Complete effect, privacy and frontend acceptance
Status: not started. Prerequisite: D03.2–D03.5, D01 integration, F04 fixtures and applicable P07 approval.
Ownership: D03 owns domain scenarios and proposed `tests/fixtures/notifications/`; F04/I01 integrate shared coverage and final execution.
Deliverables: all-provider effect matrix, redacted visual evidence, keyboard/monitor checks and exact operation/support notes for I01.
Validate synthetic delivery, DND, history, dismissal, actions, timeout/urgency, ownership and privacy using independent oracles.
Exercise each provider switching in and out, repeated setup, failures and rollback; disclose any untested provider-pair transitions.
Done: required outcomes have appropriate real-effect/visual evidence and approvals, or release parity remains explicitly blocked; argv tests alone cannot close acceptance.

## 7. Shared-file contribution requests

- F01, then I01: capability/renderer/dependency records affecting `packages.json` and `src/packages.rs`; preserve choices, defaults and cardinality.
- F02, then I01: shared dispatch, `role_exec.sh`, setup delivery lists and transaction boundaries; D03 does not own another lifecycle manager.
- I01 with F02: `setup.sh`, notification D-Bus service and `sources_example/{autostart,keybindings}.lua`; retain exact service-path confinement.
- D01: Waybar `notification_status.sh`, `config.jsonc` and other bar presentation; D03 provides status translation requirements, not competing frontend edits.
- F03: registration and output ownership for D03 renderers; no new token source or direct live writes.
- F04/I01: runner/coverage integration; preserve existing `roles_controls.sh` and `roles_dbus_atomic.sh` assertions unless an explicitly approved contract migration replaces them.
- I01: user-facing support, activation and recovery documentation; parent alone writes canonical plans.

## 8. Preservation, activation, rollback and privacy

Preview source templates, installed/Stow-linked outputs and runtime owner separately; changing selection does not prove the selected daemon is active.
Retain schema-2/legacy readers and `HSS_ROLES_FILE` behavior; unsupported metadata must fail before configuration changes.
Adopt only approved appearance keys/regions; preserve existing notification rules and executable hooks without running them during rendering or validation.
Use F02 staging, validation, per-file atomic replacement and guarded recovery; do not promise atomic multi-file visibility.
Register native reload/restart/deferred activation evidence with F03; no blanket process kill, session restart or automatic launch of alternatives.
Explain possible in-memory notification/history loss before a consented daemon restart or switch; do not export/import history between providers.
Rollback restores managed files and attempts only approved runtime restoration; it cannot restore dismissed events, executed actions or expired callbacks.
Detect user edits before restoration; do not overwrite conflicts or uninstall deselected providers.
Treat bodies, summaries, images, app identities, OTPs and action parameters as potentially sensitive; exclude them from logs, status, screenshots and fixture artifacts.
P03 fixes native persistent history at both 24 hours and 100 entries, excluding sender-marked transient/private notifications where supported. Expire while running and purge expired entries before display on restart. Lock-screen exposure is forbidden. Existing-user adoption follows P06 preview/preservation, not silent retention changes.
No new plaintext history cache, interception service or retention-enabled companion may appear as an incidental implementation detail.
No additional history storage/helper is approved. Native stores must disclose retention/filtering limitations; do not promise secure erasure or reliable detection of arbitrary secrets/OTPs.
Treat payload markup and action IDs as untrusted data; never interpolate them into shell commands or fetch remote images during rendering.
Routine status polling must not replay history, expose content, mutate DND or produce recurring error notifications.

## 9. Intended validation and decisions

Existing checks, inspected but not executed: `bash tests/run.sh tests/shell/roles_controls.sh tests/shell/roles_dbus_atomic.sh`.
These establish legacy argv and file-reliability assertions only; they do not establish provider effects or singleton ownership.
Proposed checks after creation: `bash tests/run.sh tests/shell/notifications_contracts.sh tests/shell/notifications_rendering.sh tests/shell/notifications_lifecycle.sh`. These are the three suites owned by D03.3-D03.5; D03.6 contributes real-provider and visual procedures rather than an unnamed fourth suite.
Require F04 isolation to exclude inherited host D-Bus/display connections; HOME/XDG isolation alone is insufficient.
Real-provider runs require explicit opt-in, synthetic data, recorded versions, scoped cleanup and no personal notification/history access.
Visual checks include approved variants, keyboard-only controls, long/multilingual text, action expiry, empty/error states and mixed-DPI placement.
Test status freshness, bounded timeout/error behavior and clean subscription shutdown functionally. Observe responsiveness manually in the VM; there is no P07 numeric performance budget.

P01/P02/P03 policy is resolved: full attention workflow, Mocha/Latte and the explicit DND/history/privacy rules above. Provider-native support remains unverified.
P05 requires tested current Arch versions and limited labels. P06 governs safe reload and independent partial adoption; P07 is manual VM visual/functional verification without numeric or physical-hardware gates.
P04 remains D04-owned and gives D03 no authority to change SwayNC device-related widget behavior.
Escalate if required behavior needs competing ownership, unproven interception, new persistent sensitive storage, an unapproved companion or catalog reduction.
An infeasible native capability leaves that option limited and its unsupported action disabled/explained. It is neither permission to add a companion nor a blanket block on branch delivery.

## 10. Not-started checklist and confidence

1. Not started — D03.1: reconcile option evidence and explicit operation contracts.
2. Not started — D03.2: complete authorized feasibility probes and obtain P03 decisions.
3. Not started — D03.3: implement provider adapters on frozen foundation contracts.
4. Not started — D03.4: implement and validate all four F03 renderer mappings.
5. Not started — D03.5: prove singleton switching, preservation and bounded recovery.
6. Not started — D03.6: deliver effect/privacy/visual evidence and frontend acceptance.

Planning confidence: **93/100** for repository-grounded scope, ownership and identified gaps.
Provider feasibility is not certified; provisional contracts, unresolved decisions and absent live/version testing limit implementation certainty.

## Planning handoff

Workstream: D03 — Notifications and attention.
Supplied source baseline: `610a18bac374e7e2ffd0bcb2d99b026131deedbc`; branch `feat/harmonize-visual-design`; not independently verified with Git.
Repository mutations: none; no implementation, installation, activation, commits or publication performed.
Inspected sources: entire master and all four supplied foundation drafts; both notification helpers; complete SwayNC configuration/CSS; notification D-Bus service; `role_exec.sh`; both requested shell tests; `tests/run.sh`; scoped catalog, setup, reliability, Waybar, session-template and selection-documentation anchors.
Validation performed: read-only source/path inspection and contract, ownership, dependency and existing-versus-proposed check review.
Validation omitted: command/test execution, Git verification, upstream/version research, live notification effects, screenshots, accessibility measurements and runtime rollback.
Residual risks: P03 feasibility/privacy policy, truthful provider readback, cross-session ownership, native configuration/version differences and irreversible notification effects.
Canonical destination: `plans/planned/desktop-harmonization/D03-notifications-attention.md`; parent owns canonical writing and shared integration.