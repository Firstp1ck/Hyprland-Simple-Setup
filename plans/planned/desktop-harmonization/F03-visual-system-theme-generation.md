# F03 — Visual system and theme generation

Status: product policy synchronized with the completed interview; implementation not started. Apply resolved master section 9 and the [decision record](../desktop-harmonization-grill.md); native renderer/asset evidence remains pending.
Source baseline: `610a18bac374e7e2ffd0bcb2d99b026131deedbc`.
Branch supplied by coordinator: `feat/harmonize-visual-design`.
Master: [Desktop harmonization master](../desktop-harmonization-master.md).

## 1. Scope and boundaries

Own semantic visual tokens, global toolkit appearance, asset closure, deterministic rendering, and theme orchestration on F02 transactions.
Cover GTK2, GTK3, GTK4, libadwaita preferences, Qt5, Qt6, KDE appearance, fonts, icons, cursors, portal appearance, accessibility, and scaling.
All 17 catalog roles participate through F01's selected-member ledger; primary selection controls routing, not theme eligibility.
D01-D07 own application-specific renderers; F03 supplies their shared inputs and validation contract.
Optional None selections produce no application output or activation request; global toolkit settings remain independently applicable.
Preserve every catalog choice, existing argv boundaries, role inputs, launcher behavior, and reliability guarantees.
Do not change credentials, profiles, accounts, user data, editor extensions, MIME defaults, or application-specific behavior.
Do not introduce mandatory companions, patched libadwaita, a second desktop shell, or a promise of pixel identity.
P02 is resolved: Mocha dark/Latte light, variant-appropriate Blue accents, Noto Sans GUI text, JetBrains Mono Nerd Font terminals/code, Breeze icons and Rose Pine with a verified matching compatibility fallback. Dark is the fresh-install default; preserve existing approved preferences.

## 2. Inspected evidence

Repository observations below describe shipped files, not verified installed behavior.

| Anchor | Observation | Planning consequence |
|---|---|---|
| `dotfiles/.config/gtk-3.0/settings.ini` | Breeze-Dark, Noto Sans 10, Qogir cursor, animations enabled, fixed `gtk-xft-dpi=113049` | Reconcile assets and scaling; preserve unrelated interaction settings |
| `dotfiles/.config/gtk-4.0/settings.ini` | Breeze cursor, Noto Sans formatting differs, dark preference commented, same fixed DPI | GTK4 needs its own mapping and runtime verification |
| `dotfiles/.config/gtkrc-2.0` | Breeze-Dark, Sans 11, Breeze cursor | Prove this XDG-located file is consumed before claiming GTK2 coverage |
| GTK3/GTK4 `gtk.css` | Both import `colors.css` | Existing CSS ownership requires preservation and migration policy |
| GTK4 `colors.css` | Explicit Breeze-named foreground/background/state colors | Token extraction is possible; consumption by libadwaita is unproven |
| `qt5ct/qt5ct.conf` | Fusion, system darker palette, JetBrainsMono Nerd Font 12 | Qt5 differs from Qt6 in style, palette source, and font |
| `qt6ct/qt6ct.conf`, `style-colors.conf` | Breeze, home-relative palette path, bold mono fonts, three color-state arrays | Validate path interpretation, palette roles, and font resolution |
| `dotfiles/.config/kdeglobals` | Explicit color groups plus file-dialog and preview behavior | Manage appearance keys only; retain behavior and privacy settings |
| `hypr/sources_example/environment_variables.lua` | `QT_QPA_PLATFORMTHEME=qt6ct`; both cursor families use `apps.cursor` | Do not assume Qt5 or Xcursor compatibility from these declarations |
| `hypr/sources_example/app_variables.lua:11` | Cursor names `rose-pine-hyprcursor` | Hyprcursor and Xcursor asset identities may need separate resolved values |
| `hypr/sources_example/look_and_feel.lua` | Literal colors, opacity, dimensions, blur, and enabled animations | F03 provides tokens; D07 owns compositor mapping |
| `xdg-desktop-portal/hyprland-portals.conf` | Hyprland/GTK preference; GTK FileChooser | Preserve routing; appearance propagation is separate |
| `setup.sh:configure_filepicker` | Atomic portal write plus selected GUI-editor MIME updates | Request bounded integration; do not take ownership of MIME policy |
| `packages.json` theming groups | Breeze variants, qt5ct/qt6ct, Nerd fonts, Rose Pine cursor package | Distinguish declared packages from verified resources |
| `scripts/lib`, `tests/run.sh`, `tests/shell` | Existing reliability library, Python helper, shell runner and regression suites | Reuse foundations and runner; no parallel transaction framework |

Paths abbreviated above are under `dotfiles/.config/`.
GTK asset directories were inspected only for inventory; no full asset validation was performed.
The GTK4 backup file remains untouched and is not automatically adopted as a migration source.

### Local documentation evidence and limits

- `/usr/share/doc/arch-wiki/html/en/Uniform_look_for_Qt_and_GTK_applications.html:546-564` describes cross-toolkit styles and Breeze's GTK2/GTK3 mapping.
- `/usr/share/doc/arch-wiki/html/en/Qt.html:520-526` describes non-Plasma configuration and a Qt5/Qt6 platform-theme candidate.
- `/usr/share/doc/arch-wiki/html/en/GTK.html:656-685` distinguishes GTK versions and describes libadwaita theme-override caveats.
- These are local documentation snapshots, not current upstream compatibility guarantees.
- No wiki-specific search/extract tools were available; scoped local files were read directly, without web lookup.
- Qt plugin selection, GTK2 discovery, portal settings propagation, libadwaita preferences, and live reload remain feasibility checks.
- Documentation mentioning invasive overrides is not approval to deploy them.

## 3. Recommended design and options

Recommend semantic consistency with native widgets, explicit support limits, and reversible activation.
Produce Catppuccin Mocha/Latte reference configurations using supported native theming, balanced density, modest rounding and comfortable targets. Use subtle supported shell transparency/blur and opaque application content; native widget geometry may differ.
Required switching entry points are installer settings, a dedicated control on every supported bar and Super+Shift+T with custom-binding conflict detection. They share an internal configuration action; no public standalone command, tools-menu item, scheduling service or package-install rerun is required.

### Token proposal

- Colors: surface levels, foreground, muted text, border, focus, selection, accent, link/visited, success, warning, and error.
- States: active, inactive, hover, pressed, selected, disabled, and backdrop; pair foregrounds with backgrounds.
- Terminal colors: explicit ANSI indices 0-15, normal/bright foreground semantics, default foreground/background and selection/cursor contrast pairs. D05 contributes requirements; F03.2 owns schema and approved values. Native truecolor output may remain app-specific.
- Typography: proportional UI and monospace families, fallback families, size units, weight, line height, and symbol/icon fallback.
- Metrics: spacing scale, border/focus thickness, radius, control density, icon dimensions, and cursor size.
- Effects: motion enabled/reduced, duration categories, transparency preference, shadows, and blur intent.
- Variants: dark and light are required. Preserve existing accessibility preferences without resetting them; dedicated high-contrast, reduced-motion and enlarged-text variants are outside this version's required scope.
- Scaling: logical units and toolkit-specific conversion; monitor scale is runtime context, not another hardcoded global DPI.
- Assets: logical identifier, resource family, provider, supported variants, license/source evidence, and validated resolution.
- Readability: visible focus, readable text and non-color status cues are reviewed manually in the VM. No numeric visual/performance budgets or universal pixel threshold are required.

Prefer native libadwaita color-scheme/high-contrast behavior where verified; do not force arbitrary palette injection.
Do not globally set `GTK_THEME`, disable portals, spoof desktop identity, or install patched toolkits as a shortcut.
Compare Qt platform-theme options in a bounded spike; the local wiki example is not an approved environment change.
Retain existing DPI and appearance settings until migration preview and consent resolve their replacement.

## 4. Incoming and outgoing contracts

All sibling interfaces are provisional until parent reconciliation and foundation approval.

| Direction | Plan and dependency | Required contract |
|---|---|---|
| Incoming | [F01](F01-inventory-capability-contracts.md), Gate A | Option/member identities, toolkit families, dependencies, version evidence, support and None semantics |
| Incoming | [F02](F02-runtime-managed-configuration.md), managed-write gate | Staging, validation, ownership, Stow-safe installation, rollback, activation results, concurrency control |
| Incoming | User P02; P05 via F01 | Approved visual reference and supported toolkit/version envelope |
| Joint | [F04](F04-verification-foundation.md) | Determinism fixtures, visual matrix, effect assertions, P07 measurements |
| Outgoing | D01-D07 | Token schema, asset manifest, renderer contract, variant semantics, coverage/result descriptor |
| Outgoing | [I01](I01-integration-rollout-acceptance.md) | Preview/activation specification, shared-file contributions, migration and support notes |

Domain discovery, mapping requirements, and contract contributions are **pre-foundation specification work**.
Gate A and F03 interface design do not depend on completed domain adapters or frontend implementations.
Gate B uses a bounded representative integration fixture, not completion of every domain renderer.
Complete domain implementation and effect evidence are later dependencies of I01 release acceptance, avoiding a foundation/domain cycle.

### Proposed deterministic renderer interface

Input: approved token schema/version, resolved variant, F01 member identity, renderer revision, explicit compatibility facts, and resolved assets.
Treat user overrides as explicit validated input; rendering must not discover ambient home-directory preferences.
Output: staged relative files, content hashes, managed-key/region declarations, required assets, validation results, and activation intent.
Distinguish supported, native-constrained, unsupported, missing-dependency, conflict, and render-error outcomes without claiming equivalent effects.
Exclude runtime timestamps and absolute staging paths from deterministic file content and semantic hashes.
Renderers must not install packages, write live settings, access credentials, execute shell-expanded configuration, or restart applications.
Validate paths against F02's output boundary; reject traversal, colliding outputs, malformed tokens, and untrusted executable hooks.
Registration identifies owner, member/toolkit coverage, outputs, validator, and native reload/restart/deferred support.
F03 validates registration and gathers output; F02 alone performs managed mutation and records transaction results.
Resolve all selected members, deduplicate shared outputs, and distinguish missing installed members from unsupported rendering.
Global toolkit settings can affect unselected applications; preview must disclose that reach rather than promise per-app isolation.

## 5. Implementation work packages

### F03.1 — Resolve appearance inventory and feasibility

Status: not started. Prerequisites: F01 discovery and domain specification contributions; no production writes.
Deliverables: toolkit/resource evidence contribution to F01; P02 comparison sheets and bounded spike matrix.
Inspect GTK2 lookup, font identities, cursor formats, Qt plugin combinations, KDE/QML coverage, and portal appearance propagation.
Prove ordinary GTK4 and libadwaita behavior independently; identify sandbox/desktop-launch differences without changing catalog membership.
Validation: future isolated toolkit probes record versions, launch paths, observed settings, warnings, and unsupported cases.
Done: each toolkit/resource assumption has evidence or an explicit blocker; no unverified asset is labelled available.

### F03.2 — Freeze semantic tokens and reference variants

Status: not started. Prerequisites: F03.1; P02 approval for final values; F04 acceptance consultation.
Deliverables: proposed `theme/tokens.json`, `theme/tokens.schema.json`, and `theme/README.md`; F03 owns these proposed paths.
Define units, state pairs, variants, fallback behavior, schema compatibility, and override precedence without predetermining a catalog schema bump.
Provide proposed reference sheets and accessibility expectations to domain owners, including constrained native styling.
Validation: reject incomplete variants, invalid colors/units, cyclic aliases, unresolved assets, and unsupported schema versions.
Done: approved tokens resolve deterministically; reference and limitations are recorded under P02.

### F03.3 — Implement pure rendering and registration

Status: not started. Prerequisites: F03.2; frozen F01 descriptor and F02.1 staging contract. Split this package into two ordered milestones rather than waiting for a completed F02 transaction implementation.
F03.3a delivers a pure sample renderer and staged output set with no live writes; F02.5 consumes that sample. F03.3b validates the renderer against the completed F02.5 implementation and F04 fixtures. F03.3a does not require F03.3b or complete domain renderers.
Deliverables: proposed `scripts/lib/theme-render.py` and `theme/renderers/`; final language/interface requires foundation agreement.
Use a repository-compatible runtime; do not introduce a plugin platform or dependency merely to render templates.
Support all selected members, global-output deduplication, deterministic ordering, escaped serialization, and explicit coverage failures.
Validation: byte-identical reruns; shuffled-member inputs; spaces/Unicode; hostile token/path inputs; duplicate outputs; optional None.
Done: one global renderer and a domain-owned representative fixture pass F04/F02 integration without live writes or full domain completion.

### F03.4 — Implement global toolkit and asset mappings

Status: not started. Prerequisites: F03.1-F03.3; P02/P05; proven resource closure.
Deliverables: managed appearance mappings for existing GTK2/3/4, qt5ct/qt6ct, `kdeglobals`, cursor/font/icon settings, and portal preferences.
Keep libadwaita preference support separate from general GTK4 CSS; publish native-constrained mappings honestly.
Resolve Qt palette paths through explicit destination context; preserve unrelated geometry, file-dialog, preview, and interaction keys.
Route environment, GTK2 discovery, and non-file settings contributions through F02/I01 rather than competing writers.
Validation: syntax/semantic checks, absent assets, clean-home behavior, overrides, native dialogs, KDE widgets/QML, and portal consumers.
Done: supported global mappings have observed effects; unsupported required appearance remains blocked for approval.

### F03.5 — Orchestrate preview, activation, and rollback

Status: not started. Prerequisites: F03.3-F03.4; F02 transactions; P02 activation UX and P06 upgrade consent.
Deliverables: selected-member application report and activation specification integrated through F02; I01 owns installer wiring.
Preview distinguishes source changes, staged outputs, installed outputs, live effects, deferred restart, and unavailable applications.
Validate each dependency-coherent unit before commit. Cancelled units leave their state unchanged; conflicting app configs are preserved and skipped while independent valid apps may apply. Report partial appearance and deferred activation. Never auto-launch absent applications.
Use domain-supplied activation operations through F02, preserving argv and lifecycle ownership; avoid blanket process termination.
Validation: denied consent, render failure, write failure, activation failure, concurrent modification, repeated apply, and interrupted recovery.
Done: file rollback and runtime recovery/deferred reporting are demonstrated without promising impossible live-state atomicity.

### F03.6 — Verify accessibility, scaling, and domain adoption

Status: not started. Prerequisites: F03.4-F03.5 and F04 fixtures; apply P07 manual VM visual/functional acceptance without numerical thresholds.
Deliverables: proposed `tests/shell/theme_rendering.sh`, `tests/shell/theme_activation.sh`, and `tests/fixtures/theme/`.
These F03 suites own token resolution, toolkit mappings, serialization and theme-orchestration assertions. F04's `harmonization_renderers.sh` owns the reusable managed-transaction/coverage harness and failure injection; reuse its helpers instead of duplicating recovery tests.
Foundation verification uses representative fixtures; later complete coverage incorporates domain implementations without blocking Gate A.
Cover approved variants and selected-member mappings; D01-D07 retain ownership of app-specific effect tests.
Exercise readable focus, missing glyphs, cursor visibility and dark/light appearance. Preserve existing enlarged-text/reduced-motion preferences. Physical mixed-DPI behavior remains unverified unless a suitable later environment becomes available; no dedicated high-contrast surface is required.
Validation: isolated fixture commands and consented graphical sessions; screenshots supplement effect and keyboard checks.
Done: foundation sample passes Gate B; complete domain coverage and residual limits reach I01 before release acceptance.

## 6. Shared-file contributions and consumer boundaries

| File/consumer | F03 contribution; final integration owner |
|---|---|
| `packages.json`, `src/packages.rs` | Resource/dependency evidence and renderer references; F01 then I01 owns edits |
| `setup.sh`, `scripts/lib/setup-reliability.sh` | Theme staging/preview/activation hook requirements; F02 then I01 owns edits |
| `sources_example/environment_variables.lua`, `app_variables.lua` | Verified cursor/platform-theme values and preservation rules; F02/I01 serializes edits |
| `sources_example/look_and_feel.lua` | Decoration/motion tokens; [D07](D07-session-auxiliary-interfaces.md) owns compositor renderer |
| `xdg-desktop-portal/hyprland-portals.conf` | F03 appearance proposal; preserve chooser routing and coordinate shared writes through F02/I01 |
| `tests/run.sh`, common fixtures, CI | Suite registration and isolation requirements; F04/I01 owns shared changes |
| [D01](D01-bars-docks.md), [D02](D02-launchers-shared-menus.md), [D03](D03-notifications-attention.md) | Consume semantic states/metrics; own panel, menu, and notification profiles |
| [D04](D04-device-controls.md), [D05](D05-terminal-workspace-agents.md) | Consume toolkit/terminal tokens; retain actions, shell, routing, and agent behavior |
| [D06](D06-applications-default-handlers.md) | Own application preferences and handlers; F03 does not alter MIME associations |

## 7. Migration, activation, and security

Adopt only approved keys/regions; preserve unknown keys, comments where supported, and explicit user overrides.
When safe structured merging is unavailable, report conflict rather than replacing the whole file.
F02 distinguishes tracked Stow sources, installed symlinks, generated destinations, and runtime settings; never overwrite source by blindly following a link.
Record prior bytes, ownership, symlink topology, and per-key external settings needed for bounded restoration.
Treat GSettings or other non-file writes as reversible activation steps, not hidden renderer side effects.
Never dump or restore entire settings databases; scope snapshots to approved appearance keys.
Rollback must not clobber edits made after activation; detect divergence and request reconciliation.
Variant/member switching preserves routing and data; deselection cleanup touches only demonstrably managed outputs.
Defer session-environment changes requiring relogin; never restart a session or an app with unsaved work automatically.
Missing monitors or graphical sessions produce unverified/deferred results, not invented successful effects.
Do not fetch remote assets during rendering or rewrite root/system-wide appearance.

## 8. Acceptance scenarios and future commands

No commands below were executed; proposed theme suites do not yet exist.

- Proposed: `bash tests/run.sh tests/shell/theme_rendering.sh tests/shell/theme_activation.sh`.
- Existing suites to run later: `bash tests/run.sh tests/shell/reliability_atomic.sh tests/shell/reliability_rollback.sh tests/shell/roles_membership.sh tests/shell/roles_lua_argv.sh`.
- Clean install and upgrade: approved inputs produce equivalent managed appearance without changing selections.
- Multiple selected members with a non-default primary: each receives coverage; routing still uses the primary.
- None, missing package, missing asset, unsupported feature, cancellation, and command failure remain distinct.
- Approved variant combinations remain readable with visible keyboard focus and non-color status cues.
- Test 100%, fractional, and 200% scaling, mixed-DPI monitor movement, text enlargement, and cursor transitions where supported.
- Exercise Wayland/Xwayland and supported sandbox paths with actual font/icon resolution; record unavailable environments.
- Observe portal appearance/preferences separately from chooser routing; neither proves the other.
- Optional screenshots support manual comparison under recorded versions, fonts, scale and compositor settings; no numeric image tolerance gate.

## 9. Decisions, risks, and stop rules

P01/P02 visual and workflow policy is resolved; P05 requires evidence for current Arch versions and honest limited labels. Rose Pine compatibility assets still need verification before claiming a coherent cursor mapping.
P06 requires preview/preservation, independent partial application and safe reloads; P07 requires manual VM review and functional tests. Actual renderer behavior remains unverified.
P03/P04 remain with their domain owners; appearance work cannot solve or downgrade their capability requirements.
Stop affected work if a required member needs invasive overrides, missing mandatory assets, or an unapproved companion.
Stop if Qt5/Qt6 coexistence, GTK2 discovery, libadwaita preference support, or portal propagation lacks a reproducible supported path.
Stop on ambiguous ownership, unsafe Stow replacement, output collisions, non-reversible writes, or routing/argv regressions.
Escalate evidence and alternatives through F01/master decisions; never remove an app or silently lower parity.
Residual risks include toolkit drift, CSS leakage, plugin conflicts, font/cursor fallback, and incomplete live rollback.

## 10. Implementation checklist and confidence

1. Not started — F03.1: document toolkit/resource feasibility and P02 options.
2. Not started — F03.2: obtain approvals and freeze tokens, variants, and references.
3. Not started — F03.3: implement deterministic rendering on approved foundation contracts.
4. Not started — F03.4: implement verified global mappings and asset closure.
5. Not started — F03.5: integrate consented activation, preservation, and rollback.
6. Not started — F03.6: verify foundation fixtures, accessibility, scaling, and later domain coverage.

Planning confidence: **91/100** for scope, ownership, and static evidence; runtime feasibility remains unverified.
Confidence is limited by provisional foundation interfaces, unresolved user decisions, and absent graphical/version tests.

## Planning handoff

Workstream: F03 — Visual system and theme generation.
Source baseline: `610a18bac374e7e2ffd0bcb2d99b026131deedbc`; supplied baseline was not independently checked with Git.
Repository mutations: none; no files written, edited, staged, installed, or reloaded by this planner.
Inspected files: entire master; appearance files and setup/package excerpts listed in §2; `tests/run.sh`; scoped script/test/asset inventories; cited local documentation sections.
Validation performed: prior read-only source inspection, path inventory, and planning-contract review; recovery reused that evidence without new exploration.
Validation omitted: Git status/index inspection, tests, package probes, upstream freshness checks, screenshots, hardware/session validation, and rollback execution.
Residual risks: §9; parent reconciliation and independent review remain required; no implementation or runtime success is claimed.
Canonical destination: `plans/planned/desktop-harmonization/F03-visual-system-theme-generation.md`; parent owns canonical writing.