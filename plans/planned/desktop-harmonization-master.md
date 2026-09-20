# Desktop harmonization master plan

Status: planning complete; product policy resolved by the Grill Me interview. Native-capability verification and implementation remain not started. The interview authorizes documentation synchronization, not implementation.

Planning date: 2026-09-20.

Baseline: branch `feat/harmonize-visual-design`, commit `610a18bac374e7e2ffd0bcb2d99b026131deedbc`. The working tree was clean before this plan was created. Recheck the baseline before implementation.

## 1. Goal and authority

Let users choose any supported application in the existing selection catalog without losing the agreed desktop functionality or visual language. Preserve the active Waybar experience as the initial bar baseline, rather than reducing it to the simplest alternative.

This master coordinates foundation work, domain subplans, shared-file ownership, integration, decisions, and acceptance. The current request authorizes creating and reconciling planning documents with `openai-codex/gpt-6-astra` subagents. It does not authorize implementation, package installation, service changes, desktop reloads, commits, publication, or application-data migration.

Plan completion is not implementation completion. All documents remain under `plans/planned/` until their implementation and verification are complete. Archive the finished plan family together under the already ignored `plans/archive/` after final program acceptance, preserving relative links. Do not archive a foundation merely because its document has been drafted.

The parent is the integration owner and sole writer of the canonical plan family. Delegated planners inspect evidence and return separate draft artifacts. They do not edit the repository or one another's documents. A final cross-plan reviewer advises; the parent resolves every finding.

## 2. Product boundaries

### Required direction

- Cover all 17 existing roles, every selected member, and optional None states. Primary selection controls routing, not which installed apps receive theme support.
- Separate visual consistency, desktop workflow parity, and application-specific capabilities. Do not claim pixel identity or identical IDE/browser/agent internals.
- Keep all current app choices selectable. A missing required native capability produces an explicit limited-support label and blocks that option's full-parity claim, not delivery of the whole branch. Unsupported actions must explain the limitation rather than silently substitute an app or operation.
- Use native capabilities only. Repository configuration/theme generation and adapters to native CLI/APIs are allowed; replacement features, feature-emulation scripts and companion interfaces are not. Theme assets and genuine dependencies of existing native workflows are allowed with a package preview.
- Preserve existing package selection, environment-variable inputs, argv safety, Stow symlinks, configuration-preservation behavior, and rollback guarantees.
- Keep one owner for each singleton desktop service. Do not run competing notification or authentication providers to simulate parity.
- Do not migrate credentials, browser profiles, calendars, accounts, editor extensions, or agent configuration automatically.
- Keep source, installed configuration, and runtime state distinct. Missing packages, unavailable hardware, unsupported features, and command failures are different states.
- Require dark/light appearance, readable controls and preservation of existing accessibility preferences. Dedicated high-contrast, enlarged-text and reduced-motion variants are not required for this version. Verify functional behavior and appearance manually in the user's disposable Arch VM; physical hardware remains unverified.

### Non-goals

A new distribution, ISO implementation, wholesale application rewrites, mandatory cloud services, provider account setup, a new universal plugin framework, and replacing the existing installer are outside this program. Existing native extras remain available but need not become the parity baseline.

## 3. Verified starting point and evidence

The prior static audit is the starting hypothesis, not live compatibility proof. Revalidate version-sensitive behavior in F01.

| Evidence | Observation | Responsible plan |
|---|---|---|
| `packages.json`; `src/packages.rs` | 17 roles; strict Rust deserialization; package/default/primary metadata, but no harmonization capability contract | F01 |
| `Documents/app-selections.md`; `setup.sh:configure_roles` | Existing role generation and launch routing; schema version 2 | F01, F02 |
| `dotfiles/.config/hypr/scripts/role_exec.sh`, `term_exec.sh`, `role_window.sh`, `menu_exec.sh` | Reusable launch adapters already exist | F02, D02, D05 |
| `dotfiles/.config/waybar/config.jsonc` | Rich active controls and menus; some definitions are inactive | D01 |
| `dotfiles/.config/ironbar/config.toml`; `dotfiles/.config/nwg-panel/bar` | Workspaces, clock, tray only in shipped alternative bar profiles | D01 |
| `dotfiles/.config/nwg-panel/dock`; `hypr/scripts/nwg_panel.sh` | Basic taskbar dock; combined bar/dock process handling exists | D01 |
| `hypr/scripts/notification_control.sh`; `waybar/scripts/notification_status.sh` under `.config` | Toggle has different meanings; Fnott DND is a no-op; non-SwayNC status is static | D03 |
| `packages.json:roles.launcher` | Bemenu uses executable discovery, other launchers use desktop entries | D02 |
| `waybar/scripts/nmtui.sh`, `nmtui-connect.sh` under `.config` | Both invoke the same selected network command | D04 |
| `packages.json:roles.audio` | ALSA hardware mixers and stream-routing interfaces share a choice group | D04 |
| `dotfiles/.config/gtk-3.0`, `gtk-4.0`, `qt5ct`, `qt6ct`, `kdeglobals`, `kitty`, `waybar`, `wofi`, `swaync` | Divergent fonts, cursors, palettes, styles, component metrics | F03 and domain consumers |
| `dotfiles/.bashrc`; Fish configuration; `setup.sh:configure_roles` | Hardcoded Bash editor/multiplexer aliases versus role-aware Fish updates | D05 |
| `setup.sh:configure_filepicker` | GTK portal chooser and selected GUI editor MIME associations exist; broader handler policy needs work | F03, D06 |
| `hypr/sources_example/autostart.lua`, `app_variables.lua` under `.config` | Two authentication agents are launched; calculator references an uncataloged executable | D07 |
| `tests/shell/roles_*`; Waybar tests | Selection/argv/regression tests exist; visual and effect-level parity remain unverified | F04, I01 |

Paths abbreviated with `hypr/` or `waybar/` in the table are relative to `dotfiles/.config/`.

Documentation evidence available locally:

- `/usr/share/doc/arch-wiki/html/en/Uniform_look_for_Qt_and_GTK_applications.html`, sections Styles for both Qt and GTK and Breeze.
- `/usr/share/doc/arch-wiki/html/en/Qt.html`, Configuration of Qt 5/6 applications under environments other than KDE Plasma.
- `/usr/share/doc/arch-wiki/html/en/GTK.html`, GTK 3 and GTK 4. Treat libadwaita separately; do not make invasive theme overrides the default.
- `/home/firstpick/.hyprwiki/content/useful-utilities/status-bars.md`, Waybar and Widget systems.

No target application, package installation, graphical session, or hardware test was executed for this planning baseline. The repository exploration report is `/home/firstpick/.pi/agent/skills/repo-explorer/repo-explorer-effectiveness-2026-09-20T14-50-19-809Z-Hyprland-Simple-Setup-97d1e9e455.md`.

## 4. Program structure and canonical subplans

All twelve linked subplans have been drafted by `openai-codex/gpt-6-astra` children and reconciled by the parent. They specify future work; none is implemented. The planning ledger in section 12 records delivery and the review record distinguishes planning acceptance from implementation approval.

| ID | Subplan | Scope and concrete output | Implementation prerequisites | Wave |
|---|---|---|---|---|
| F01 | [Inventory and capability contracts](desktop-harmonization/F01-inventory-capability-contracts.md) | Complete option inventory, required capability baseline, schema evolution proposal, feature dependency and compatibility contract | Resolved P01/P03/P04/P05 policy; native evidence and concrete schemas still required | Foundation A |
| F02 | [Shared runtime and managed configuration](desktop-harmonization/F02-runtime-managed-configuration.md) | Action/status adapters, lifecycle ownership, transaction-safe configuration, compatibility entry points | F01 contract approval | Foundation B |
| F03 | [Visual system and theme generation](desktop-harmonization/F03-visual-system-theme-generation.md) | Visual tokens, toolkit settings, deterministic renderer interface, asset closure, theme application lifecycle | F01; F02 managed-write interface; P02 | Foundation B |
| F04 | [Verification foundation](desktop-harmonization/F04-verification-foundation.md) | Fixtures, capability assertions, renderer tests, screenshot methodology, test ownership and coverage manifest | F01; design against F02/F03 drafts, integrate against frozen interfaces | Foundation B |
| D01 | [Bars and docks](desktop-harmonization/D01-bars-docks.md) | Waybar baseline extraction, Ironbar/nwg-panel parity, both dock implementations | Foundation gate; D02/D03/D04/D07 action contracts available | Domain |
| D02 | [Launchers and shared menus](desktop-harmonization/D02-launchers-shared-menus.md) | Five launcher adapters, desktop-entry parity, shared selection/confirmation menus | Foundation gate | Domain |
| D03 | [Notifications and attention](desktop-harmonization/D03-notifications-attention.md) | Four provider adapters, DND/history/action semantics, honest status, singleton ownership | Foundation gate; P03 | Domain |
| D04 | [Network, Bluetooth and audio](desktop-harmonization/D04-device-controls.md) | Separate connect/edit/radio operations, pairing, audio stream and hardware controls | Foundation gate; P04; D02 chooser contract | Domain |
| D05 | [Terminal workspace and agents](desktop-harmonization/D05-terminal-workspace-agents.md) | All shells, terminals, multiplexers, coding agents and terminal launch behavior | Foundation gate; preserve current agent/triage contracts | Domain |
| D06 | [Applications and default handlers](desktop-harmonization/D06-applications-default-handlers.md) | Browsers, GUI/TUI file managers, GUI/TUI editors, calendars, MIME/URL/folder handlers | Foundation gate; D05 terminal contract | Domain |
| D07 | [Session and auxiliary interfaces](desktop-harmonization/D07-session-auxiliary-interfaces.md) | Lock/logout/login, authentication ownership, wallpaper, capture, clipboard, custom dialogs and auxiliary tools | Foundation gate; D02 menu and D05 terminal contracts | Domain |
| I01 | [Installer integration and branch/VM acceptance](desktop-harmonization/I01-integration-rollout-acceptance.md) | Chooser capability UX, shared-file integration, migration/switching, documentation and end-to-end acceptance | Foundation gate for incremental integration; all D plans for final acceptance | Integration |

D01-D07 own app-specific theme mappings using F03's renderer interface. F03 does not separately author those same application profiles. F03 owns global GTK/Qt/KDE/cursor/font settings and theme orchestration; D06 owns app-specific preferences and handler behavior.

F04 supplies test infrastructure early. I01 owns final cross-role evidence and the branch/VM handoff. No publication is authorized, and regression tests are not postponed until the final phase.

## 5. Foundation-first execution

### Foundation A: establish the truth and agree the contract

F01 must first enumerate every catalog option and classify it by role, toolkit/rendering family, startup model, data/privacy boundary, available actions, assets, package dependencies and version evidence. Distinguish active Waybar features from configured-but-disabled modules and native optional extras.

Create one capability ledger, not separate contradictory lists. Apply the resolved section 9 baseline and verify native capabilities before claiming parity. Bounded checks cover notification history/DND and ALSA versus stream controls; proven gaps get explicit limited labels without companion research.

Gate A evidence:

1. Every current option and optional None state has an owner and a coverage row.
2. Mandatory outcomes, optional native extras, allowed native-API adapters and unsupported capabilities are explicit. No companion-provided implementation is planned.
3. Proposed runtime/catalog changes preserve selection cardinalities and legacy input semantics; support labels are independent of package selection.
4. Capability definitions include observable outcomes and failure/unsupported states.
5. Product policy is applied accurately. Supported claims require evidence; native gaps are labeled limited and unavailable hardware unverified. New safety/product decisions are escalated without silently altering the resolved policy.

### Foundation B: build the smallest shared implementation

F02 implements common actions, status, lifecycle and managed configuration. F03 establishes the visual tokens and deterministic theme pipeline on the approved managed-write interface. F04 implements the test fixtures and acceptance assertions concurrently where file ownership permits.

Do not remove legacy Waybar/helper paths during extraction. Keep compatibility wrappers until all known callers and upgrade fixtures are migrated. Preserve existing independent application selection and agent-routing behavior.

Foundation gate evidence:

- One catalog/runtime schema strategy and compatibility reader behavior are approved and tested. No speculative schema version bump is predetermined by this master.
- Action and status semantics, cancellation, error reporting, argv boundaries, timeouts and unknown hardware states have executable contract tests.
- Managed generation supports staging, validation, atomic replacement, rollback, Stow-linked paths, user overrides and idempotent reruns.
- A representative action, theme renderer and singleton service pass an end-to-end fixture before domain fanout.
- Tests cover old installation inputs and current schema version 2. New unsupported inputs fail clearly rather than corrupting existing configuration.
- Global theme assets are resolvable; no live session reload or service restart occurs without the agreed activation policy.

Only then may domain implementations depend on these interfaces. Drafting domain plans may happen earlier against explicitly provisional foundation drafts.

## 6. Shared interfaces and dependency rules

These are required design properties, not a prematurely fixed implementation API. F01/F02/F03 publish concrete names, formats and versions at Gate A/B.

| Contract | Producer | Consumers | Required information |
|---|---|---|---|
| Capability/option descriptor | F01 | All plans, chooser, tests | Role and package identity; action support; renderer; dependencies; ownership; evidence and compatibility status |
| Action invocation/result | F02 | D01-D07 | Semantic action ID; structured argv; outcome; cancellation; unsupported/error distinction; timeout and no duplicate invocation |
| Status observation | F02 | D01, D03, D04, D07 | Typed state; availability; freshness/error; bounded refresh/subscription; no UI markup in shared state |
| Managed output transaction | F02 | F03, all domains, I01 | Input/output identity; validation; staging; activation; backup/restore; user-owned regions; XDG/Stow handling |
| Visual tokens/renderer | F03 | All visual consumers | Semantic colors, typography, component metrics, assets, accessibility variants; deterministic render and validation |
| Theme activation | F03 with F02 | All domains, I01 | Reload/restart support, per-app effect, user consent, failure rollback, selected-member coverage |
| Test/coverage descriptor | F04 | All domains, I01 | Capability ID; supported combinations; fixture/effect test; visual evidence; hardware/version limits |
| Default-handler intent | D06 | I01 and apps | Desktop ID; URI/MIME/folder behavior; user consent; fallback and restore without profile migration |

No domain planner may invent a competing global action bus, catalog, theme source, transaction engine or test framework. Propose a contract amendment with producer, consumer, migration and test impacts instead.

Avoid dependency cycles by splitting domain work into contract contribution, adapter implementation and frontend wiring. D01's panel frontend consumes the device/notification/menu action contracts; those action implementations must not depend on D01's widgets or filesystem paths. D07 owns power action semantics; D01 owns their panel presentation.

## 7. Implementation waves and integration ownership

1. **Discovery and decisions:** F01; start F04 acceptance design and F03 visual proposal without production writes.
2. **Shared foundations:** F02; F03 and F04 integrate on its approved interfaces. Freeze the foundation gate.
3. **Domain backends and renderers:** D02, D03, D04, D05, D06, D07. D01 can implement its own renderer/status shell against approved fixtures, but its full behavior gate waits for actual action providers.
4. **Desktop frontend parity:** finish D01 and connect shared menus, notification/device status, power actions and selected-app routing. Run real combined behavior checks.
5. **Integrated installer and upgrade:** I01 lands chooser and shared-file patches throughout prior waves on this branch, then completes switching, recovery and documentation. The user tests the resulting work step by step in a disposable Arch VM; no incremental publication or release campaign is authorized.

Potential critical path: F01 -> F02 -> F03/F04 foundation gate -> D02/D03/D04/D07 action adapters -> D01 parity -> I01 acceptance. D05 -> D06 is another required path. Feasibility decisions may extend either; no calendar estimates are asserted yet.

### Shared-file ownership

| File or area | Foundation owner | Later integration rule |
|---|---|---|
| `packages.json`, `src/packages.rs` | F01 | Domain contributors submit bounded metadata changes to I01; no concurrent registry edits |
| `setup.sh`, `scripts/lib/setup-reliability.sh` | F02 | I01 is the later sole integrator of setup hooks and dependency/activation changes |
| `src/main.rs` | I01 | Capability UX changes land only after F01 definitions are approved |
| Common `hypr/scripts/` adapters and generated roles | F02 | Domains own provider-specific modules; shared dispatcher edits route through integration owner |
| Global GTK/Qt/KDE settings and theme core | F03 | Domains register application renderers without redefining shared tokens |
| `sources_example/{autostart,keybindings,app_variables,environment_variables,windows_and_workspaces}.lua` | F02 establishes interfaces | I01 serializes domain contributions; D07 specifies session/security behavior |
| `tests/run.sh`, CI configuration, common fixtures | F04 | I01 integrates new suites; each domain owns its tests |
| User-facing documentation | I01 | Domains provide exact support limitations and operation notes |
| Canonical master and subplans | Parent coordinator | Delegated drafts are advisory artifacts; parent alone reconciles and writes final plans |

### Legacy helper handoff table

These assignments resolve planning ownership without choosing new API names or changing behavior now. I01 serializes shared-path changes. Extraction retains compatibility entry points until caller and upgrade fixtures are migrated.

| Existing helper/function family | Semantic owner | Boundary |
|---|---|---|
| `role_exec.sh`, shared dispatch/status/transaction/lifecycle code, `launch_qt_gui.sh`, `float-active-window.sh` | F02 | Generic mechanism; domain owners contribute supported operations and outcome requirements |
| `term_exec.sh` | F02 common mechanism, D05 terminal-provider contract | D05 contributes exact terminal argv/cwd/identity behavior; I01 lands later shared-wrapper changes |
| `menu_exec.sh`, `repos_wofi.sh` | D02 provider/menu semantics | F02 owns generic dispatch/result plumbing; D02 owns selection identity and caller adaptation |
| `notification_control.sh`, notification observation | D03 | D01 owns the Waybar `notification_status.sh` presentation adapter, not provider state semantics |
| `nmtui*.sh`, `audio_control.sh`, `alsamixer.sh`, `bluetooth_manager.sh`, `toggle_bluetooth.sh` | D04 | Device provider semantics; D01 owns panel gestures and display |
| `float_calendar.sh`, application handler intent | D06 | Calendar/application behavior uses F02 window mechanism and D05 terminal contract |
| `power_action.sh`, `launch_power_screen.sh`, brightness/backlight, sensors, snapshot, update/maintenance helpers, keybind viewer | D07 | Preserve existing update/confirmation safety; separate shared collection/action logic from D01 XML/status presentation, rather than rebuilding maintenance workflows |
| `nwg_panel.sh`, `toggle_waybar.sh` | F02 lifecycle mechanism, D01 panel contract | I01 lands shared changes; one combined nwg-panel process and independent bar toggle remain required |
| `waybar_launch.sh`, bar profiles/styles/XML and bar-specific formatting | D01 | Presentation/launch policy consumes shared contracts; no backend depends on these paths |
| Starship and terminal dashboards | D05 | D07 classifies supporting packages and owns btop/cava/fastfetch tool appearance; D05 owns prompt integration and dashboard layouts |

### Execution dependency graph

This graph is the scheduling authority. It separates specification, fixture production, implementation and acceptance so a reference back to a producer's draft does not become a cycle. All nodes remain not started. `none` means no earlier graph node, not authorization to act. P01-P07 gates still apply.

| Node | Depends on | Work covered |
|---|---|---|
| SPEC | none | F01.1-F01.3 discovery/requirements; F03.1; domain `.1` contributions and D03.2 bounded feasibility; F04 fixture specifications; I01.1 planning intake |
| GATE-A | SPEC | F01.4-F01.6 schema/closure evidence and approved contract baseline; no completed domain adapter required |
| INTERFACES | GATE-A | F02.1 concrete interfaces; F03.2 tokens/reference; F04 approved descriptor/isolation design |
| FIXTURES | INTERFACES | F04.1-F04.2 coverage/harness foundation, allowing owned planned/not-run test references |
| PURE-SAMPLE | INTERFACES | F03.3a deterministic renderer sample without live writes or a completed transaction implementation |
| RUNTIME | INTERFACES, FIXTURES, PURE-SAMPLE | F02.2-F02.6 mechanisms and recoverable batch implementation; pre-gate authentication contract comes from D07.1 |
| THEME | RUNTIME, PURE-SAMPLE | F03.3b integrated rendering and F03.4-F03.5 global mappings/activation |
| GATE-B | RUNTIME, THEME, FIXTURES | F02.7, representative F03.6, F04.3-F04.6 foundation verification; later all-domain coverage remains I01 acceptance |
| MENUS | GATE-B | D02 adapter/theme implementation and domain-local checks |
| ATTENTION | GATE-B, MENUS | D03 native-provider adapters/themes; existing native actions may use shared menu presentation, but no missing history/DND capability is emulated |
| WORKSPACE | GATE-B | D05 shell/terminal/multiplexer/agent implementation and domain-local checks |
| DEVICES | GATE-B, MENUS, WORKSPACE | D04 adapters and local tests; D07.1 ownership contract is already available |
| APPLICATIONS | GATE-B, WORKSPACE | D06 workflows/handlers/themes and local checks |
| AUXILIARY | GATE-B, MENUS, WORKSPACE | D07 session/auxiliary implementation and local checks |
| PANELS | GATE-B, MENUS, ATTENTION, DEVICES, APPLICATIONS, AUXILIARY | D01 complete frontend wiring; renderer prototypes can start against frozen fixtures earlier |
| INSTALLER | GATE-B | I01.2-I01.4 incremental chooser/setup/migration integration; each actual domain contribution lands only after its own producer is ready |
| FINAL | PANELS, APPLICATIONS, WORKSPACE, INSTALLER | D01-D07 combined frontend acceptance, I01.5-I01.6 complete matrix, documentation and rollout readiness |

Domain-local adapters and tests precede combined acceptance. For example D03.6 and D04.6 receive D01 frontend evidence at FINAL; D01 needs their tested providers, not their final cross-frontend sign-off, at PANELS. D05's notification-action contract is specified before GATE-A; integrated triage evidence follows the real notification implementation at FINAL. These are staged handoffs, not mutual prerequisites for beginning implementation.

Immediate next work after separate execution approval: start SPEC using the recorded P01-P07 policy, verify native capabilities and classify limitations, and prepare Catppuccin reference configurations for later manual VM review. Do not reopen resolved choices without new evidence. Do not start a bar redesign before shared contracts and configuration-preservation foundations exist.

During future implementation, one writer per cwd/worktree is mandatory. Concurrent code writers require clean isolated worktrees and independent path ownership. A dirty working tree is not permission to stash, reset, or drop changes. Same-tree contributions are serialized. Parent inspection and targeted validation precede integration acceptance.

## 8. Complete role and supporting-component coverage

| Role/group | Options/components to account for | Domain owner |
|---|---|---|
| Bar | Waybar, Ironbar, nwg-panel | D01 |
| Dock | nwg-dock-hyprland, nwg-panel, None | D01 |
| Launcher | Wofi, Rofi, Fuzzel, Bemenu, tofi | D02 |
| Notifications | SwayNC, Mako, Dunst, Fnott | D03 |
| Network | nm-applet, nm-connection-editor, nmtui, plasma-nm | D04 |
| Bluetooth | Blueman, Bluedevil, Bluetui, Bluetuith | D04 |
| Audio | Pavucontrol, Pavucontrol-Qt, QasMixer, Alsamixer, Ncpamixer | D04 |
| Shell | Bash, Fish, Zsh | D05 |
| Terminal | Kitty, Alacritty, Ghostty, Konsole, Foot | D05 |
| Multiplexer | tmux, Zellij, Herdr | D05 |
| Coding agents | Pi, OpenCode, Claude Code, Codex CLI, Cursor CLI, None | D05 |
| Browser | Firefox, Chromium, Vivaldi, Zen, Brave | D06 |
| Graphical file manager | Dolphin, Thunar, Nautilus, Nemo, PCManFM-Qt | D06 |
| TUI file manager | Yazi, Ranger, lf, nnn, Midnight Commander, Vifm, None | D06 using D05 terminal adapter |
| TUI editor | Neovim, Helix, Vim, Nano | D06 using D05 shell/editor variables |
| GUI editor | Zed, VS Code, Cursor, Kate, Mousepad, None | D06 |
| Calendar | Merkuro, GNOME Calendar, KOrganizer, Calcurse, Khal | D06 |
| Session/security | SDDM, Hyprlock, Hypridle, Wlogout, authentication agents | D07 |
| Wallpaper/display | Hyprpaper, Waypaper, Hyprsunset, compositor decorations | D07; global decoration tokens from F03 |
| Capture/clipboard | Hyprshot, Grim, Slurp, Satty, Hyprpicker, persistence/history helpers | D07 |
| Custom/administration interfaces | Tk keybinding viewer, Zenity, calculator, Notes/Music launchers, system monitors, snapshot/package/user tools, Ark, GitHub Desktop | D07 integration inventory; D06 handles associations; toolkit appearance from F03 |
| Infrastructure | PipeWire/WirePlumber, NetworkManager, BlueZ, portals, keyring, fonts/icons/cursors | F01 dependency ledger; F03 global settings; F02/D04/D07 lifecycle owners |

D07 must inspect the remaining generic catalog entries and assign each to themed interface, integrated action, backend dependency, or outside visual scope. This prevents non-role tools from disappearing from the program. GTK/Qt/Electron/libadwaita/custom-rendered/TUI classification is a second axis, not another competing role list.

## 9. Resolved product policy and remaining feasibility gates

The [completed Grill Me interview](desktop-harmonization-grill.md) records 54 explicit answers. Product policy P01-P07 is resolved for planning. References to these IDs throughout the subplans mean conformance to this policy, not a request to repeat an answered question. Native-provider behavior, actual assets, schema details and implementation evidence still require verification. The interview authorized synchronizing plans only.

| ID | Approved policy | Remaining technical gate |
|---|---|---|
| P01 | Same desktop workflows, not identical app internals; all active Waybar operations/menus plus the explicitly requested theme control. Native-only capabilities with native-API/configuration adapters allowed; no replacement features or companions | Verify actual outcomes; classify each option and action as supported, limited or unverified |
| P02 | Catppuccin Mocha dark/Latte light, Blue accents, Noto Sans GUI text, JetBrains Mono Nerd Font terminals/code, Breeze icons and Rose Pine cursor with a verified matching fallback. Dark default, manual switching, supported native theming | Validate native theme surfaces/assets and manually inspect the result; no invasive toolkit overrides |
| P03 | Full notification support requires popups/actions/dismissal/DND/browsable history/truthful status. Ordinary DND permits critical notifications; locked screens show no notification content. Native persistent history is capped at both 24 hours and 100 entries | Verify provider-native controls/retention/privacy. Expire while running and purge expired entries before display on restart; no custom cache or interception service |
| P04 | Per-app volume/routing is required for full audio support, separately from ALSA hardware control; no companion mixer or replacement feature | Mark ALSA-only or otherwise incomplete choices limited, retaining native launch and explicit unsupported operations |
| P05 | Current fully updated Arch Linux with recorded versions. Other distributions unverified. Keep limited options selectable; never mislabel them fully harmonized or silently substitute behavior | Maintain honest per-option/version evidence and approved fallback behavior |
| P06 | Opt-in preview for existing users; preserve conflicting configs and apply independent nonconflicting apps with partial-state reporting. Primary choices drive URL/folder/file handlers. Safe native reloads only, defer restarts | Prove dependency-aware application units, desired/active state, bounded rollback and singleton ownership |
| P07 | All work stays on this branch, then user-led step-by-step testing in a disposable Arch VM. Manual visual review and functional tests; no numeric screenshot/performance budgets, no required physical-hardware certification | Run repository/fixture checks when implementation is authorized; record VM results and physical evidence gaps honestly |

### Workflow details from the interview

- Bars appear on every connected output. Missing battery/Bluetooth/backlight or other hardware stays visible with an explicit unavailable state, distinct from disabled/error/stale states.
- Docks require pins, running apps, launch/focus and active indicators. Initial pins follow the primary terminal/browser/graphical file manager/enabled GUI editor. Follow the focused output when natively supported; otherwise use a fixed primary output and label the limitation. Preserve custom assignments. Autohide, dock-specific keyboard switching and richer window actions are optional.
- Launchers use desktop applications as the standard mode and keep executable search separate. An app lacking the required native mode stays limited; do not implement the missing mode or silently change the shortcut's meaning.
- Terminal/multiplexer parity covers command/cwd/clipboard behavior and create/attach/detach/basic panes. A common dashboard, native terminal tabs/image protocols and agent internals are not mandatory. Theme native shell prompts and preserve existing Starship rather than requiring it.
- Fully supported file managers cover browse/open/edit, already-mounted volumes, trash/recovery and archives. Calendars provide local event viewing/creation/editing without online accounts. Native gaps produce limited status; user data is preserved.

### Appearance and activation details

- Use balanced sizing, modest rounding and comfortable targets. Subtle supported shell transparency/blur is allowed; application content stays opaque. Native widget differences are accepted.
- Require only dark and light variants. Preserve existing high-contrast, reduced-motion and enlarged-text preferences; do not create new required variants or remove existing preferences.
- Manual switching is available through installer settings, a dedicated control on every supported bar, and `Super+Shift+T` in Hyprland. Detect custom-key conflicts instead of overwriting them. A shared internal action is necessary; a separate user-facing command or tools-menu entry is not required. Never rerun package installation for theme switching.
- Approved primary selection changes include associated handler changes in the preview, without an extra separate handler-consent step. With GUI editor None, a managed desktop entry launches the primary TUI editor through the selected terminal.
- An appearance-only conflict does not block a launchable new primary's routing/associations. Preserve its conflicting file, apply other independent changes and report partial appearance. A failed shared/runtime prerequisite blocks its dependent activation unit; skipping one file cannot justify an incoherent partial dependency group.

### Notification and session details

- Respect sender-marked transient/private hints where the provider supports them, and disclose limitations. Do not claim reliable arbitrary OTP/secret detection or secure erasure.
- No notification content while locked takes precedence over the unlocked critical-DND exception. DND itself is not the lock security boundary.
- Hyprpolkitagent is the managed authentication owner. Remove the duplicate setup-owned KDE startup request during implementation, but never terminate an existing foreign owner automatically.
- Confirm logout/reboot/shutdown, keep lock immediate and suspend direct. Logout affects the current session only and fails safely if that session cannot be identified. Hibernate is offered only after prerequisites are verified; the VM scope does not certify physical suspend/hibernate.

Version/API checks must use local installed documentation and authoritative upstream sources when needed. Known unsupported native features get limited labels under P05, not endless companion research or a blanket delivery block. Escalate only genuinely new product/security decisions. No implementation, installation, live activation, commit or publication is authorized by this interview.

## 10. Subplan document contract

Each subplan must contain:

1. Stable plan ID, status, master link, scope, non-goals and specific option coverage.
2. Verified starting evidence with file/symbol references; current behavior separated from proposals and unverified upstream assumptions.
3. Incoming prerequisites and outgoing deliverables, naming producer/consumer plan IDs and gate/task dependencies.
4. Numbered implementation work packages, normally 4-8, using `<plan-id>.<number>`. Each names expected outputs, file ownership, prerequisite, tests and a done condition.
5. Shared-file contribution requests rather than competing ownership claims.
6. Capability and theme mapping, including failure, cancellation, optional None and missing-hardware behavior where relevant.
7. Migration, existing-user preservation, activation, rollback and security/privacy boundaries.
8. Acceptance criteria with intended commands or observable scenarios, distinguishing current checks from tests that still need to be created.
9. Risks, unresolved decision IDs, bounded feasibility tasks and explicit stop/escalation conditions.
10. A final checklist and planning-confidence statement. No implementation work may be checked complete.

Proposed new paths must be marked proposed. Reuse existing helpers before inventing frameworks. Detailed plans should be executable work breakdowns, not repeated essays describing the goal.

## 11. Relation to existing work

The [bootable installer ISO plan](bootable-installer-iso.md) remains a separate planned program. Harmonization must expose reusable package/configuration contracts that the future ISO profile can consume; it must not implement disk operations, archiso packaging, offline mirrors, or change the ISO's existing product decisions.

Current agent/multiplexer/triage behavior and configuration-reliability work are inputs to preserve. Historical session summaries are not proof that their remaining runtime checks passed. F01/F04 re-baseline relevant tests; D05 does not redesign agent installation/authentication. No unrelated active-plan edits are authorized.

## 12. Planning delivery ledger

| Item | Planning status | Implementation status |
|---|---|---|
| Master and coordination contracts | Reconciled by parent | Not started |
| F01-F04 foundation subplans | Four successful recovered drafts, inspected and saved | Not started |
| D01-D07 domain subplans | Seven successful drafts, inspected and saved | Not started |
| I01 integration subplan | Successful draft, inspected and reconciled | Not started |
| Cross-plan review and parent reconciliation | Review completed; CPR-01 and CPR-02 accepted and corrected; parent refinements recorded | Not applicable |
| Initial link, coverage, dependency and scope validation | Passed before interview: twelve subplans, 73 work packages, 17 roles, 73 option rows, four None states, 115 generic packages, 146 local links and acyclic 17-node execution graph | Not applicable |
| Grill Me policy synchronization | Passed: 54 answers recorded; master and all twelve subplans synchronized; 160 links, preserved role/package coverage, acyclic graph and documentation/interview-metadata-only scope verified | Not started |

Delegation protocol: one asynchronous workflow per original or bounded same-protocol recovery pass; 12 distinct plan-drafting workstreams on `openai-codex/gpt-6-astra`, followed by one fresh read-only cross-plan reviewer on the same explicitly requested model. At most three children run concurrently. The discovered runtime has no dedicated planner role, so bounded read-only planning uses `delegate`; review uses `reviewer`. No code worker, duplicate scout, external CLI, oracle council, or unrelated researcher is needed for document drafting. Every child output is bound to a unique runtime-managed artifact, then inspected and integrated by the parent.

Foundation drafts are produced first. Domain planners read those artifacts as provisional contracts. I01 reads all drafts, then the reviewer checks the assembled draft set for contradictions and omissions. These draft dependencies are not a substitute for future implementation gates.

### Drafting recovery record

Original workflow `eb22be02-e9f4-4f99-8b67-3547f557eb95` stopped at its foundation barrier. All four children returned draft artifacts but the runner rejected them with `Subagent completed without making edits for an implementation task`. The task's phrase `Do not use write, edit or bash` and its compound file prohibition triggered the mutation-intent classifier. A read-only diagnostic reproduced the original classification as implementation and verified that the blanket instruction `Do not modify any files.` classifies as read-only with no mutation intent. No runtime package or global settings were changed.

All four children were verified failed and resumable before recovery; no downstream children had started. Source HEAD remained `610a18bac374e7e2ffd0bcb2d99b026131deedbc`, with only this master untracked and no source diff. Recovery permits one retained-child continuation per failed foundation, preserving model/context, then the unstarted domain/integration/review stages. It is not permission for code edits, model substitution, external CLI fallback or duplicate live runs.

| Workstream | Original rejected run |
|---|---|
| F01 | `e18f82d5-0149-4740-a39a-e30f5428d8b3` |
| F02 | `a867f49e-889e-4073-856b-4f097b32cf6d` |
| F03 | `bbd3756b-5947-48ed-b50a-b84118ba724a` |
| F04 | `b28ac3b0-56ed-4263-8a87-b74f08f4ff7b` |

Recovery workflow `139a433a-6fbf-44a4-9104-b131854b4655` completed all 13 children successfully: four retained foundation continuations, seven domain drafts, I01 and the cross-plan reviewer. Original rejected runs are not counted as successful deliveries. The parent read all recovered drafts and the review, imported only the twelve plans, and corrected the accepted findings.

Runtime receipt: `/tmp/pi-subagents-uid-1000/async-subagent-runs/139a433a-6fbf-44a4-9104-b131854b4655/workflow-receipt.json`. Draft/review artifacts are retention-managed under `/home/firstpick/.pi/agent/sessions/--mnt-SSD_NVME_4TB-GitHub-Hyprland-Simple-Setup--/subagent-artifacts/outputs/139a433a-6fbf-44a4-9104-b131854b4655/harmonization-recovered/`. Canonical repository copies and the [review and acceptance record](desktop-harmonization/REVIEW-AND-ACCEPTANCE.md) are durable.

The planning task is complete when every linked subplan exists, every catalog role has coverage, dependencies are acyclic, shared ownership agrees and recorded decisions are applied consistently. The interview amendment changes only planning documents and tool-managed interview state. Product choices P01-P07 are resolved; native feasibility, concrete interface design, implementation and live verification remain unstarted.
