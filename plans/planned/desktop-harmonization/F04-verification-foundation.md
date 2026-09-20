# F04 — Verification foundation

Status: product policy synchronized with the completed interview; implementation not started. Apply master section 9 and the [decision record](../desktop-harmonization-grill.md); execution evidence remains pending.
Master: [Desktop harmonization master](../desktop-harmonization-master.md).
Source baseline: `610a18bac374e7e2ffd0bcb2d99b026131deedbc`, branch `feat/harmonize-visual-design`.

## 1. Scope and boundaries

F04 owns early executable contract-test architecture, reusable fixtures, coverage descriptors and manual visual-review procedures for the disposable Arch VM. Numeric image/performance budgets and required physical-hardware certification are out of scope.
It extends existing shell/Rust/Python testing rather than introducing a competing test framework.
[I01](I01-integration-rollout-acceptance.md) owns the final release matrix, cross-role execution schedule, release evidence and acceptance decision.
Domain plans own application-specific tests and their observable outcomes.

All catalog choices, selection cardinalities, primary routing, argv boundaries, legacy inputs and reliability guarantees remain protected.
Non-goals: implementation during planning, changing defaults, mandatory companions, package installation, account/profile migration, live-session activation or declaring parity from screenshots alone.
All interfaces below are recommendations pending producer approval; concurrently drafted foundation documents are not frozen APIs.

### Coverage discovery boundary

Discover package identities from `packages.json` and capability identities from F01’s approved ledger; do not create a second catalog.

| Owner | Options requiring descriptors |
|---|---|
| [D01](D01-bars-docks.md) | Waybar, Ironbar, nwg-panel; nwg-dock-hyprland, nwg-panel dock, None |
| [D02](D02-launchers-shared-menus.md) | Wofi, Rofi, Fuzzel, Bemenu, tofi |
| [D03](D03-notifications-attention.md) | SwayNC, Mako, Dunst, Fnott |
| [D04](D04-device-controls.md) | nm-applet, nm-connection-editor, nmtui, plasma-nm; Blueman, Bluedevil, Bluetui, Bluetuith; Pavucontrol, Pavucontrol-Qt, QasMixer, Alsamixer, Ncpamixer |
| [D05](D05-terminal-workspace-agents.md) | Bash, Fish, Zsh; Kitty, Alacritty, Ghostty, Konsole, Foot; tmux, Zellij, Herdr; Pi, OpenCode, Claude Code, Codex CLI, Cursor CLI, None |
| [D06](D06-applications-default-handlers.md) | Firefox, Chromium, Vivaldi, Zen, Brave; Dolphin, Thunar, Nautilus, Nemo, PCManFM-Qt |
| D06 using D05 | Yazi, Ranger, lf, nnn, Midnight Commander, Vifm, None; Neovim, Helix, Vim, Nano |
| D06 | Zed, VS Code, Cursor, Kate, Mousepad, None; Merkuro, GNOME Calendar, KOrganizer, Calcurse, Khal |
| [D07](D07-session-auxiliary-interfaces.md) | Session/security, wallpaper/display, capture/clipboard and remaining auxiliary interfaces assigned by its inventory |

Infrastructure and toolkit families are descriptor dimensions, not additional competing catalogs.
Optional None applies to dock, coding agents, TUI file managers and GUI editors; required-role emptiness remains invalid.
Selected non-primary members require theme coverage even when launch routing continues to use the primary.

## 2. Inspected repository evidence

These are observations of source assertions, not reports of successful execution.

| Anchor | Observed contract and limitation |
|---|---|
| `tests/run.sh` | Discovers top-level shell tests, excludes `*_testlib.sh`, accepts explicit files, isolates HOME/XDG paths, prepends stubs and aggregates failures |
| `tests/shell/roles_testlib.sh` | Copies dotfiles, establishes selected Stow-like links and guarded setup inputs; fixture defaults are not product-default authority |
| `tests/shell/roles_matrix.sh` | Enumerates catalog options and asserts 73 cases, schema version 2, generated metadata, consumer configuration, dry-run and wrapper argv |
| `tests/shell/roles_controls.sh` | Asserts notification command argv, Fnott DND no-op and nwg-panel profile structure; does not prove notification effects |
| `tests/shell/roles_membership.sh` | Covers selected membership versus primary, optional emptiness, invalid inputs, shared packages, switching and GUI-editor None fallback argv |
| `tests/shell/harness_regressions.sh` | Checks runner isolation, failure propagation and malformed-registry rejection |
| `tests/shell/reliability_atomic.sh` | Asserts symlink preservation, modes, approved-root confinement, manifests, dry-run and separate run state |
| `tests/shell/reliability_rollback.sh`, `tests/shell/reliability_failures.sh` | Assert digest guards, manifest validation, partial-failure reporting, write failures and restoration boundaries |
| `tests/shell/reliability_lifecycle.sh` | Includes locks, signals, credential-log protection, managed sync, MIME effects and session helpers; many external interactions are stubbed |
| `tests/shell/reliability_two_runs.sh`, `tests/shell/reliability_latest_log.sh` | Assert consecutive-selection behavior, truthful manifests and constrained warning-log reads |
| `tests/shell/waybar_{keybinds,updates,review_regressions}.sh` | Bridge nested Waybar tests into shell discovery and include managed-sync fixtures |
| `dotfiles/.config/waybar/tests` | Contains static menu contracts, parser/regression tests and PATH-mocked update tests, not screenshot acceptance |
| `src/packages.rs::tests` | Asserts 17 roles, 73 options, nine single/eight multiple roles, 13 required roles, independent membership/primary and dependency behavior |
| `.github/workflows/ci.yml` | Runs Rust checks, guarded shell tests and registry validation on Ubuntu; does not establish graphical or hardware parity |
| `tests/verify_hypr_config.sh` | Uses an assembled fixture and returns 3 when Hyprland is absent; configuration verification is not desktop effect verification |
| `tests/fixtures/hypr/assemble.sh` | Copies compositor configuration into a fixture home; reusable assembly boundary, not a complete isolation sandbox |

No inspected test was executed.
Upstream application behavior, installed versions and screenshot tooling remain unverified.
No local-wiki or web-derived compatibility claim is made.

## 3. Incoming and outgoing contracts

- [F01](F01-inventory-capability-contracts.md) supplies approved capability IDs, option identities, cardinalities, observable outcomes, dependencies and P01/P03/P04/P05 disposition.
- [F02](F02-runtime-managed-configuration.md) supplies action/result, status, managed-write and lifecycle interfaces; concrete names remain its responsibility.
- [F03](F03-visual-system-theme-generation.md) supplies renderer inputs/outputs, semantic tokens, asset closure, variants and activation policy.
- F04 publishes descriptor validation, isolated fixture utilities, evidence classification and comparison procedures to D01–D07 and I01.
- Domains contribute provider-specific scenarios, observable outcomes and known limitations as **pre-foundation specification work** for F01/F04.
- Those discovery/contract contributions do not depend on later domain adapter implementation; Gate A must not wait for post-foundation adapters.
- After the foundation gate, domains implement their adapters/tests and provide real-effect probes, screenshots and truthful version/hardware evidence.
- I01 consumes descriptors and evidence without treating F04’s foundation sampling as the final release matrix.
- F04.1–F04.2 can establish infrastructure against provisional drafts; F04.3–F04.4 integration requires frozen producer interfaces.
- Domain implementation consumes the foundation gate only after representative action, renderer and singleton fixtures satisfy the master’s requirements.

### Recommended coverage descriptor

Use a proposed `tests/fixtures/harmonization/coverage.json` with a documented versioned format.
References to capabilities remain foreign keys into F01’s ledger, not duplicated definitions.

| Field group | Required information |
|---|---|
| Identity | Stable case ID, domain owner, role/package/capability IDs, contract revision |
| Selection | Selected members, primary, explicit None, source and target selection for transitions |
| Context | Source/config/runtime distinction, toolkit, versions, platform, session type, assets, scale and output topology |
| Preconditions | Genuine native dependencies/assets, services, hardware availability, permissions and activation requirements; no companions |
| Assertions | Expected outcome, independent oracle, cancellation/error states and cleanup |
| Evidence | Static, argv, modeled effect, real effect or visual; command/procedure and artifact references |
| Result | Passed, failed, blocked, skipped or not-run; reason and missing evidence |
| Limits | Unsupported combinations, hardware boundaries, decision IDs and approval references |

Default every new evidence result to not-run.
Missing capability rows, dangling test references and unexplained skips must be machine-detectable.
Separate test-reference lifecycle from evidence result. A planned reference names its owner, producing task and proposed destination and remains not-run; that file need not exist before its implementation wave. A delivered reference must resolve to an existing entry point. A passed result requires recorded execution evidence, not merely an existing file.
A passing argv result must never satisfy a descriptor requiring a real effect.

## 4. Implementation work packages

### F04.1 — Establish discovery and coverage validation

Status: not started. Prerequisite: F01 inventory draft and domain specification contributions; approved identities before integration.
Deliver proposed `tests/shell/harmonization_coverage.sh` and `tests/fixtures/harmonization/coverage.json` under F04 ownership.
Discover all existing options, all four optional None states and supporting-component assignments without silently rewriting the current 73-option guard.
Define domain contribution rules and reject duplicate case IDs, unknown capabilities and missing owners. Reject nonexistent delivered test entry points; allow explicitly planned references with an owner, producing task and not-run result. This lets domain test specifications precede their implementations without a foundation gate cycle.
Validation: synthetic missing-option, duplicate-ID, unowned-None and stale-reference fixtures must fail.
Done: every catalog option has a descriptor; requirements and unexecuted evidence are distinguishable without depending on completed domain adapters.

### F04.2 — Extend the isolated fixture foundation

Status: not started. Prerequisite: F04.1 evidence vocabulary; F02 isolation review.
Extend `tests/shell/roles_testlib.sh` and `tests/shell/harness_regressions.sh`; add proposed `tests/shell/harmonization_testlib.sh`, all under F04 ownership.
Retain existing runner discovery and explicit-file behavior; source-only helpers must remain excluded.
Add fixture-scoped stateful doubles, controllable clocks, failure injection, cleanup and side-effect recording without exposing production-only bypasses.
Audit inherited D-Bus/display/session variables, HOME/XDG coverage, PATH fallback and subprocess cleanup; HOME isolation alone is insufficient.
Validation: intentional failures, interruption, absent dependencies and hostile inherited variables must leave no host writes or fixture processes.
Done: offline fixtures fail closed before contacting host services and preserve existing harness contracts.

### F04.3 — Make shared action and status assertions executable

Status: not started. Prerequisite: F04.2 and frozen F02 invocation/status/lifecycle semantics.
Deliver proposed `tests/shell/harmonization_contracts.sh` and reusable state-transition fixtures under proposed `tests/fixtures/harmonization/`, owned by F04.
Assert literal argv, one invocation, cancellation without mutation, timeout, command failure, unsupported actions, stale/unknown status and missing hardware.
Model state transitions independently of the adapter output; an echoed requested state is not an oracle.
Add a representative singleton fixture asserting one owner, rejected competing ownership and cleanup during switching.
Validation: deliberately broken adapters that report success without changing fixture state must fail.
Done: the foundation gate has meaningful modeled-effect coverage, explicitly distinct from real-provider proof.

### F04.4 — Verify rendering and managed-theme transactions

Status: not started. Prerequisite: F04.2, frozen F02 transaction interface and F03 renderer interface.
Deliver proposed `tests/shell/harmonization_renderers.sh` under F04 ownership; coordinate bounded extensions to existing reliability tests with F02.
Own reusable transaction/coverage assertions and failure injection, not a second suite of toolkit token mappings. F03's `theme_rendering.sh` and `theme_activation.sh` consume these helpers for theme-specific assertions.
Assert deterministic outputs, asset resolution, semantic-token mapping, format validation and coverage for every selected member.
Exercise staged-validation failure, partial commit failure, refused activation, idempotent reruns, symlink chains, user overrides and guarded rollback.
Keep source snapshots, installed files and runtime activation evidence separate; generated text alone does not prove application adoption.
Validation: invalid assets, escaping paths and injected generation/rename failures must preserve approved previous state.
Done: one representative renderer completes the transaction fixture and restores safely without live-session activation.

### F04.5 — Establish visual evidence and semantic review

Status: not started. Prerequisite: F03 reference proposal; P02 approval before accepting reference images.
Deliver proposed `tests/fixtures/harmonization/visual-protocol.md` and a capture metadata template in that proposed directory, owned by F04.
Define capture preparation, reproducibility, privacy review, image pairing, semantic rubric and reviewer sign-off.
Evaluate capture/diff tooling in a disposable session before proposing CI dependencies; do not assume compositor capture support.
Validation: repeated identical scenes, intentionally clipped controls, missing glyphs and wrong-state indicators must exercise the review procedure.
Done: the user can manually compare reproducible scenes and distinguish rendering noise from missing or misleading controls; no numeric pixel threshold is required.

### F04.6 — Integrate functional checks and the VM verification handoff

Status: not started. Prerequisite: F04.1-F04.5 and F02/F03 representative fixtures; P07 policy is resolved.
Extend `tests/run.sh` and `.github/workflows/ci.yml` under F04 ownership; keep graphical/hardware jobs explicitly separated from offline checks.
Verify bounded timeouts, cancellation, status freshness/error handling and process cleanup functionally. Record any observed usability/resource regressions, but do not impose numeric resource or screenshot budgets.
Publish proposed `tests/fixtures/harmonization/evidence-template.json` for domain and I01 consumption.
Validation: omitted suites, unsupported environments, failed functional assertions and missing evidence must not become green parity results. Known native capability gaps are labeled limited rather than blocking the whole branch.
Done: foundation evidence is reproducible and I01 accepts descriptor/ownership handoff; final release coverage remains I01’s work.

## 5. Evidence levels and scenario design

1. **Static:** registry, configuration, menu wiring and renderer output assertions prove structure only.
2. **Argv:** NUL-delimited capture proves executable selection and argument boundaries, not provider behavior.
3. **Modeled effect:** a stateful double verifies adapter orchestration against independent fixture state.
4. **Real effect:** an actual provider/backend in an isolated approved environment produces independently observed state.
5. **Visual:** semantic review and image comparison establish presentation evidence, not hidden functional correctness.

### Required discovery scenarios

- Every option independently: metadata, required capability mapping, renderer assignment and missing-package behavior.
- Multiple-selection roles: every member once as primary and non-primary; all-members fixture; removal and primary replacement.
- Single-selection roles: replacement and invalid multiple membership; shared nwg-panel bar/dock process handling.
- Optional roles: None-to-option, option-to-None and repeated None; retain GUI-editor fallback routing and agent no-selection behavior.
- Every option: a declared inbound/outbound switching case; explicitly enumerate higher-risk pairings rather than claiming Cartesian coverage.
- Legacy environment inputs and runtime schema version 2: compatibility, malformed inputs and approved future-version rejection.
- State outcomes: success, cancellation, denied permission, unavailable package, absent hardware, unsupported feature, command error and stale observation.
- Reliability: dry-run, rerun, interruption, user edits after generation, Stow links, rollback conflicts and no unintended service activation.
- Theme state: light/dark and approved accessibility variants, reduced motion, keyboard focus, long text, empty/error states and mixed-DPI layouts.

Domains specify real-effect oracles before the foundation gate: notification delivery/DND/history; network connectivity/configuration distinction; audio routing versus hardware mixing; actual window launch; singleton ownership.
Their later execution supplies evidence, not a prerequisite for initial capability/specification discovery.
P03/P04 feasibility failures remain blocked requirements, not passing unsupported cases.
Pairwise interaction sampling is recommended for broad combinations, with explicit risk-driven additions and disclosed untested combinations.

## 6. Visual comparison and P07 proposal

Use manual semantic visual acceptance, optionally documented with screenshots; no automated image-diff or numeric pixel threshold is required.
Use approved active Waybar operations as the initial bar reference; configured-but-disabled modules are separate inventory entries.
Capture app/provider versions, renderer/token revision, fonts/icons, compositor/backend, locale, window geometry, scaling, outputs and selected memberships.
Use synthetic notifications, files and identities; fix clocks/content where possible and record every mask.
Masks may cover approved nondeterminism, never missing controls, errors or text that demonstrates the capability.
Compare within a pinned rendering environment first; review cross-toolkit equivalents semantically rather than demanding pixel identity.
Review hierarchy, token intent, readable contrast, typography, glyph completeness, alignment, spacing, focus, clipping and meaningful state indicators.
Exercise keyboard-only operation, mixed-DPI movement, multi-monitor placement, light/dark changes and reduced-motion behavior.
Retain reviewer identity, observations and rejection reasons; a changed baseline requires reviewed rationale, not automatic regeneration.

P07 is resolved: manual visual review and functional tests in a disposable Arch VM, after all changes are assembled on the current branch. No numeric image tolerance, latency/resource budget or required physical-hardware matrix is planned.
Keep ordinary automated regression/fixture tests. Screenshots may document manual review but are not a pixel-diff acceptance gate.
VM/headless evidence establishes only the recorded environment's behavior. Radios, physical audio devices, battery/backlight, physical mixed-DPI/hotplug and suspend/hibernate remain unverified where the VM cannot exercise them.
A missing device must produce an honest unavailable UI state and an unverified hardware claim; it is not proof of working hardware and does not prevent delivering the branch for VM testing.

## 7. Shared-file contributions and preservation

F04 owns common fixtures, runner and initial CI integration; I01 later serializes new-suite integration.
Domains retain their tests and nested Waybar entry points; do not move them merely to manufacture uniformity.
Request registry assertions through F01 for `src/packages.rs`; F04 must not independently revise catalog/schema ownership.
Request setup hooks and managed-write injection boundaries through F02, later I01; do not directly compete for `setup.sh`.
Request renderer failure fixtures and token metadata from F03; application mappings stay with domain owners.
Preserve existing argv/reliability assertions; an approved behavior change requires an explicit replacement contract and migration case.
In particular, the Fnott no-op assertion records current behavior, not acceptable future DND parity; revise only through P03/D03 agreement.

Tests must use disposable profiles and synthetic accounts; never copy credentials, calendar data, browser profiles or agent authentication.
Real-session tests require explicit opt-in, consented effects, scoped cleanup and restoration instructions.
Version fixture formats; reject incompatible descriptors clearly and retain schema-2/legacy fixtures through migration.
Roll back test infrastructure by reverting its bounded changes, not by resetting user configuration or refreshing golden images to hide failures.
No proposed fixture may install packages, invoke destructive device/power operations or activate services implicitly.

## 8. Intended validation, risks and stop rules

Future commands, not executed here: `cargo test --locked`, `tests/run.sh`, `tests/check_packages_json.sh`.
Run new proposed suites through `tests/run.sh tests/shell/harmonization_coverage.sh` and the other proposed F04 shell entry points.
Use `tests/verify_hypr_config.sh` only where its version-sensitive prerequisites are verified; its skip exit must remain visible.
Preserve existing CI formatting/lint checks; add descriptor-negative and harness-isolation tests before making new suites mandatory.
Visual/manual procedures and hardware runs require separately recorded evidence; ordinary CI success is insufficient.

P01-P07 are resolved product policy in the master and interview. Verify conformance to that policy: native-only support labels, dark/light visuals, independent partial application, primary handlers and manual VM acceptance. Concrete provider evidence remains open; do not reopen user choices or add numeric/hardware gates.
Bounded feasibility work must demonstrate safe isolation, independent state observation and reproducible capture before adopting new dependencies.
Stop on host-service leakage, ambiguous ownership, unsupported required capability, destructive cleanup or account/data access.
Stop a supported-capability claim when descriptor coverage is incomplete or required effects have only argv evidence. Mark untested physical claims unverified and proven native gaps limited; neither label may be represented as full parity.
Classify impossible native capabilities as limited under P05; escalate only new safety/product questions. Never remove catalog choices or misrepresent support, and do not invent numeric acceptance budgets.

## 9. Implementation checklist and confidence

1. Not started — F04.1: establish complete discovery descriptors and negative coverage validation.
2. Not started — F04.2: extend isolated fixtures and prove fail-closed harness behavior.
3. Not started — F04.3: implement shared action/status and singleton contract assertions.
4. Not started — F04.4: implement renderer, selected-member and transaction/rollback tests.
5. Not started — F04.5: establish reproducible visual evidence and semantic review.
6. Not started: F04.6, integrate functional checks and the step-by-step VM handoff with I01.

Planning confidence: **92/100** for repository-grounded architecture and ownership boundaries.
Runtime feasibility remains unverified; concrete producer interfaces and missing native/VM evidence prevent stronger compatibility claims. Product policy P01-P07 is resolved.

## 10. Planning handoff

Workstream: F04 verification foundation; canonical destination: `plans/planned/desktop-harmonization/F04-verification-foundation.md`.
Baseline: `610a18bac374e7e2ffd0bcb2d99b026131deedbc`; no repository mutations, staging, installation, tests, reloads or delegation performed.
Inspected previously: entire master; runner/helper/matrix/control/membership/harness files; all six `reliability_*.sh` files; Waybar wrappers, test listing and menu contracts; relevant `src/packages.rs` tests; registry cardinality fields; CI; compositor verifier and fixture assembler.
Validation performed: read-only source inspection, existing/proposed path distinction, dependency/ownership review and document-contract review; this recovery reused that evidence without further exploration.
Validation omitted: command execution, Git index verification, graphical capture, upstream/version checks, real-provider effects and physical hardware.
Residual risks: inherited host connections, stateful-double false assurance, visual nondeterminism, combination growth and unresolved user decisions.
Parent reconciliation and reviewer approval remain required; runtime identity must come from the enclosing workflow receipt.