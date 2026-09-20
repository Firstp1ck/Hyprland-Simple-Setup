# D06 — Applications and default handlers

Status: product policy synchronized with the completed interview; implementation not started. Apply master section 9 and the [decision record](../desktop-harmonization-grill.md); native application/handler evidence remains pending.
Master: [Desktop harmonization master](../desktop-harmonization-master.md).
Source baseline: `610a18bac374e7e2ffd0bcb2d99b026131deedbc`, branch `feat/harmonize-visual-design`.

## 1. Goal, scope and boundaries

Goal: preserve every application choice while making approved desktop workflows, appearance and default-handler changes consistent, explicit and reversible.
Cover 30 application options across browsers, graphical/TUI file managers, graphical/TUI editors and calendars, plus two optional None states.
Primary selection controls routing; every selected member receives applicable theme coverage.
GUI file manager and calendar remain required single-choice roles; browser and TUI editor remain required multiple-choice roles.
TUI file manager and GUI editor remain optional multiple-choice roles.
Preserve current defaults, environment inputs, catalog argv, selection validation, schema-2 routing, Stow links and reliability guarantees.

Do not migrate browser profiles, calendar stores, accounts, credentials, editor extensions or user documents.
Native browser features, IDE services, editor plugins, file-manager extras and calendar synchronization are not automatically parity requirements.
No implementation, installation, activation, commits or publication is authorized by this draft.
Do not introduce a competing catalog, action bus, theme source, renderer framework or transaction engine.
All proposed contracts below require foundation reconciliation; a draft artifact is not an implemented API.

## 2. Observed source evidence

| Inspected anchor | Observed behavior and implication |
|---|---|
| `packages.json:roles.browser` | Five members; Vivaldi carries two Wayland flags and its codec extra; browser classes are recorded but desktop IDs are not. |
| `packages.json:roles.file_manager`, `roles.tui_file_manager` | Five required GUI alternatives; six optional terminal alternatives; TUI selection does not replace the GUI role. |
| `packages.json:roles.tui_editor`, `roles.gui_editor` | Four TUI editors expose `editor_bin`; five GUI editors expose desktop IDs; VS Code/Cursor retain Wayland argv. |
| `packages.json:roles.calendar` | Three GUI choices and two terminal choices; Khal launches `ikhal`, not `khal`. |
| `Documents/app-selections.md` | Documents schema 2, membership/primary separation, legacy inputs, None and non-uninstallation. |
| `setup.sh:configure_roles` | Generates browser/file/editor/calendar actions; GUI-editor None disables its managed autostart but preserves explicit TUI fallback. |
| `setup.sh:configure_roles` | Sets Fish editor/browser variables, Neovim-specific aliases and primary browser workspace matching; shared changes require integration ownership. |
| `setup.sh:configure_filepicker` | Chooses GTK FileChooser independently of file-manager selection; associates `text/plain` and `application/x-shellscript` with the selected GUI-editor desktop entry. |
| `setup.sh:desktop_application_exists` | Searches several desktop-entry roots; absence or unavailable `xdg-mime` produces warnings, not proof of effective associations. |
| `role_exec.sh` under `dotfiles/.config/hypr/scripts/` | Routes primary argv; GUI-editor None falls back to TUI editor; TUI-file-manager None currently reports unavailable and exits nonzero. |
| `term_exec.sh` in the same directory | Uses selected-terminal argv; Konsole uses separate processes and stable app-ID-derived titles. |
| `role_window.sh`, `float_calendar.sh` | Calendar GUI class matching delegates to a Waybar helper at 70% dimensions; terminal calendars use ordinary role execution. |
| `dotfiles/.config/dolphinrc` | Mixes BreezeDark appearance with navigation, preview, history and warning preferences; theme work must not replace the whole file. |
| `dotfiles/.config/nvim/init.lua` | Uses Tokyonight and Kickstart plugins; startup can clone/install tooling, so ordinary launch is not an offline-safe theme test. |
| `dotfiles/.config/calcurse/conf`; scoped Khal search | Calcurse configuration read returned no content; no Khal-named path was found under `dotfiles`; neither proves first-run usability. |
| `tests/shell/file_manager.sh` | Asserts all five selections, package filtering, managed shortcuts and literal directory argv. |
| `tests/shell/tui_file_manager.sh` | Asserts all six primaries, simultaneous membership, subsets, None and independent required GUI selection. |

These are static observations, not executed-test results or installed-version guarantees.
Calendar data directories were located but their contents were not inspected.
No upstream/toolkit-version claim was verified; local wiki tools were unavailable and no web research was performed.

## 3. Explicit option, capability and theme coverage

The following mapping is a proposed discovery/acceptance allocation, not a claim of verified support.
Each row must resolve into F01’s single ledger and F04’s coverage descriptors.
Theme-family hints require version evidence; application-specific mappings consume F03 tokens and assets.

| Role / option | Preserved identity and workflow target | Proposed appearance mapping / special check |
|---|---|---|
| Browser — Firefox | `firefox`; literal URL/local-document opening; verify desktop ID | Native browser chrome/system preference; no profile or `userChrome` adoption |
| Browser — Chromium | `chromium`; URL/file handlers and browser dialogs | Native/custom chrome plus toolkit integration; verify supported preference |
| Browser — Vivaldi | `vivaldi-stable`; preserve existing flags and codec extra | Custom browser UI; explicit native-constrained mapping |
| Browser — Zen | `zen-browser-bin` → `zen-browser`; retain class `zen` | Custom/Gecko-family UI; no profile discovery or rewriting |
| Browser — Brave | `brave-bin` → `brave`; retain class `brave-browser` | Native/custom chrome; do not alter wallet, rewards or privacy settings |
| GUI files — Dolphin | `dolphin`; folder, editor, mounts, trash and archive workflow | Qt/KDE through F03; narrowly manage approved `dolphinrc` appearance keys |
| GUI files — Thunar | `thunar`; same approved workflow outcomes | GTK mapping; retain custom actions and user navigation preferences |
| GUI files — Nautilus | `nautilus`; same approved workflow outcomes | GTK/native preferences; verify libadwaita constraints separately |
| GUI files — Nemo | `nemo`; same approved workflow outcomes | GTK mapping; preserve existing actions, extensions and behavior |
| GUI files — PCManFM-Qt | `pcmanfm-qt`; same approved workflow outcomes | Qt mapping; do not enable desktop management as a side effect |
| TUI files — Yazi | `yazi` in selected terminal; path and editor handoff | F03-derived TUI palette; preview/archiver dependencies audited separately |
| TUI files — Ranger | `ranger`; literal path and external editor/open action | TUI palette; preserve user commands and preview settings |
| TUI files — lf | `lf`; explicit opener/editor workflow | TUI palette; shell-command configuration needs injection review |
| TUI files — nnn | `nnn`; editor/open workflow without mandatory plugins | TUI color limits recorded; plugins remain native extras unless approved |
| TUI files — Midnight Commander | `mc`; file/editor/archive workflow | TUI skin mapping; built-in editor remains available, not silently replaced |
| TUI files — Vifm | `vifm`; path/editor/filetype workflow | TUI colorscheme mapping; preserve commands and keybindings |
| TUI files — None | No selected TUI member; GUI file manager remains required | No renderer/activation; preserve explicit-launch unavailable behavior |
| TUI editor — Neovim | `neovim` → `nvim`; edit/save and editor variables via D05 | Bounded generated theme integration; no plugin/tool bootstrap during rendering |
| TUI editor — Helix | `helix` → `hx`; edit/save and D05 variables | TUI theme mapping; retain language-server and user configuration |
| TUI editor — Vim | `vim`; edit/save and D05 variables | TUI colorscheme with supported color-depth evidence |
| TUI editor — Nano | `nano`; edit/save and D05 variables | TUI syntax/UI colors; preserve discoverable shortcut hints |
| GUI editor — Zed | `zeditor`; `dev.zed.Zed.desktop` | Custom-rendered theme/preferences; no workspace/account migration |
| GUI editor — VS Code | `code`; `visual-studio-code.desktop`; preserve flags | Electron/native editor theme mapping; no extension installation |
| GUI editor — Cursor | `cursor`; `cursor.desktop`; preserve flags | Electron-derived mapping verified independently; no credentials/AI settings |
| GUI editor — Kate | `kate`; `org.kde.kate.desktop` | Qt/KDE plus editor syntax mapping; preserve sessions/projects |
| GUI editor — Mousepad | `mousepad`; `org.xfce.mousepad.desktop` | GTK plus native syntax mapping; preserve user editing preferences |
| GUI editor — None | Explicit editor action opens primary TUI editor through D05 | No GUI autostart/theme; MIME fallback policy remains P06-blocked |
| Calendar — Merkuro | `merkuro-calendar`; existing GUI class/focus route | Qt/KDE/QML mapping to verify; clean-start local usability without accounts |
| Calendar — GNOME Calendar | `gnome-calendar`; existing GUI class/focus route | GTK/native preference mapping; verify constrained styling and first-run state |
| Calendar — KOrganizer | `korganizer`; existing GUI class/focus route | Qt/KDE mapping; distinguish app launch from backend readiness |
| Calendar — Calcurse | `calcurse` in selected terminal | TUI colors; usable empty state and local synthetic-event workflow |
| Calendar — Khal | `khal` → `ikhal` in selected terminal | TUI palette; configuration/store prerequisites require bounded feasibility |

All file-manager rows receive separate outcomes for browsing, editor launch, mounted-volume access, trash/recovery and archive opening/extraction.
P01 makes browse/open/edit, already-mounted volumes, trash/recovery and archive workflows the full-support baseline. Missing native outcomes produce limited labels and explicit unsupported actions, not companion implementations or a whole-branch block.
Do not assume TUI managers mount devices or provide trash. Native configuration/API adapters are permitted; feature-filling helpers and companion interfaces are excluded.
Read-only/offline fixtures cover permission denial, absent volumes, missing archive tools, cancelled operations and unavailable editor targets.
Theme coverage includes light/dark and approved accessibility variants, keyboard focus, enlarged text, reduced motion and mixed-DPI behavior.
Native-constrained appearance is explicit; it is neither pixel identity nor permission to remove an option.

## 4. Incoming and outgoing contracts

| Producer → consumer | Handoff and prerequisite |
|---|---|
| [F01](F01-inventory-capability-contracts.md) → D06 | Frozen identities, capability requirement levels, support states and dependency policy; D06 contributes all table rows before implementation. |
| [F02](F02-runtime-managed-configuration.md) → D06 | Frozen argv/result, generic window, managed-write and activation interfaces; preserve existing compatibility entry points. |
| [F03](F03-visual-system-theme-generation.md) → D06 | Frozen token/asset/renderer contract; D06 owns app renderers, not global GTK/Qt settings. |
| [F04](F04-verification-foundation.md) → D06 | Coverage schema, isolation, modeled-effect fixtures and visual procedures; D06 supplies provider-specific oracles. |
| [D05](D05-terminal-workspace-agents.md) ↔ D06 | D05 owns terminal wrapping and shell/session editor-variable delivery; D06 supplies primary `editor_bin`, browser identity and fallback requirements. |
| D06 → [D01](D01-bars-docks.md), [D02](D02-launchers-shared-menus.md) | App/calendar action semantics, desktop-ID evidence and truthful unavailable states; frontends do not own handlers. |
| D06 ↔ [D07](D07-session-auxiliary-interfaces.md) | Archive/editor workflow and auxiliary-app association boundaries; D07 inventories Ark, F03 owns toolkit appearance. |
| D06 → [I01](I01-integration-rollout-acceptance.md) | Handler intents, dependency proposals, migration preview, exact documentation contributions and acceptance evidence. |

Discovery and specification contributions may precede the foundation gate.
Application implementation waits for frozen F01/F02/F03/F04 contracts and the master’s representative foundation evidence.
D05’s terminal/editor contract additionally gates terminal-dependent implementation; completed D06 adapters must not block foundation specification.

### Proposed default-handler intent

D06 proposes a record referencing role/member identity, verified desktop ID, exact URI/MIME/folder targets, previous effective association, requested association, consent and restore scope.
F01 owns metadata placement; F02 owns persistence/transaction mechanics; I01 owns installer integration.
Candidate targets are HTTP/HTTPS, HTML, `inode/directory`, and existing text/shell-script MIME types; additions such as calendar import require explicit P01/P06 approval.
An approved primary-selection application includes its system association changes, disclosed in the adoption preview without another separate handler-consent step. Merely browsing or highlighting an option never applies it. Routing and handler operations remain separately validated technical steps.
Verify desktop-entry existence, supported field-code behavior and effective dispatch without evaluating `Exec` as shell text.
No browser/file-manager desktop ID is inferred from package spelling; obtain installed-package or authoritative evidence.
GUI-editor None uses a managed desktop entry invoking the primary TUI editor through the selected terminal for text-file associations. Preserve argv and existing user data; apply associations only with the approved selection change.
Missing packages, unsupported associations, consent refusal, cancellation, command failure and effective-handler mismatch remain distinct.
FileChooser backend choice is not a folder handler and must not be switched merely because a different file manager is selected.

## 5. Implementation work packages

All packages are **not started**; prerequisites describe future work, not authorization.

### D06.1 — Reconcile option evidence and workflow requirements
Prerequisites: baseline recheck when authorized; F01/F04 discovery interfaces; no foundation implementation required for specification.
Ownership: D06 evidence and descriptor contributions; F01 integrates the single capability ledger, F04 integrates shared coverage.
Deliverables: 30 option rows plus two None rows; verified desktop IDs/configuration surfaces; P01/P05 gaps and dependency proposals.
Validation: catalog-set equality, every primary/non-primary member, startup/data boundaries and independently observable workflow outcomes.
Done: every option has a renderer disposition and capability evidence or explicit blocking uncertainty; no invented support/version facts.

### D06.2 — Specify and implement reversible handler intents
Prerequisites: frozen foundation gate, D06.1, approved P06 policy before activation; D05 contract for any approved terminal-handler path.
Ownership: D06 provider logic in **proposed** `dotfiles/.config/hypr/scripts/application_handlers.sh`; setup changes requested through F02/I01.
Deliverables: preview/query/apply/restore behavior using F02 transactions; verified URI/MIME/folder targets; no new global dispatch framework.
Validation: **proposed** `tests/shell/application_handlers.sh`; missing desktop entry, conflicting defaults, refused consent, partial failure, custom XDG and rollback divergence.
Done: effective handler changes follow the approved primary selection, are previewed, observable and boundedly reversible. An appearance-only conflict may preserve the old theme file while routing/associations switch; a required runtime failure blocks dependent actions. Unsupported handler operations leave prior associations intact and report limitations.

### D06.3 — Preserve launch, focus and file/editor workflows
Prerequisites: frozen foundation gate, D06.1, D05 terminal/editor contract and approved P01 helper requirements.
Ownership: D06 provider mappings and file-manager tests; common `role_exec.sh`/`role_window.sh`/`term_exec.sh` edits remain F02/I01/D05 contributions.
Deliverables: workflow mappings for all file managers/editors/browsers; F02 generic-window consumption retaining `float_calendar.sh` compatibility.
Validation: extend existing file-manager suites; **proposed** `tests/shell/application_workflows.sh` covers literal URLs/paths, existing/delayed windows, focus failure and editor save effects.
Done: current launch argv and routing remain intact; GUI calendar focus/float is preserved; no new universal focus policy replaces ordinary launches silently.

### D06.4 — Establish calendar first-use usability
Prerequisites: frozen foundation gate, D06.1/D06.3, P01/P05 decisions; P06 consent for any persistent initialization.
Ownership: D06 calendar-specific configuration/rendering and **proposed** `tests/shell/calendar_workflows.sh`; shared launch machinery stays F02-owned.
Deliverables: five clean-start procedures; readable empty state, date navigation, readiness/error feedback and local-event feasibility evidence.
Validation: isolated synthetic calendars, absent configuration/backend, invalid locale/timezone inputs, cancellation and relaunch; no real calendar data.
Done: native fresh-profile initialization supports local event viewing/creation/editing without accounts, or the option is labeled limited. Preview persistent initialization as needed; never overwrite existing stores, import data or configure online sync.

### D06.5 — Implement app-owned F03 renderers
Prerequisites: frozen foundation gate, D06.1, approved P02/P05 scope and resolved assets.
Ownership: D06 registrations under **proposed** `theme/renderers/applications/`; bounded changes to existing `dolphinrc`, Neovim and Calcurse appearance surfaces.
Deliverables: deterministic per-member mappings, managed-key declarations, native constraints and reload/restart/deferred activation descriptors.
Validation: **proposed** `tests/shell/application_renderers.sh`; all members, None, overrides, missing assets, invalid syntax and no network/plugin bootstrap.
Done: every selected member has verified supported appearance or an explicit unresolved limitation; renderers never write live configuration or restart apps.

### D06.6 — Integrate preservation and acceptance evidence
Prerequisites: D06.2–D06.5; F04 fixtures; P06 activation and P07 acceptance policy; I01 integration schedule.
Ownership: D06 application tests/evidence; I01 canonical documentation/setup integration; F04 common runner and fixture contributions.
Deliverables: upgrade/switch/rollback scenarios, support notes, shared-file request packet and per-option evidence classifications.
Validation: old schema-2 inputs, every primary/member transition, both None transitions, interrupted activation and user edits after apply.
Done: I01 receives reviewed static/argv/modeled-effect/real-effect/visual evidence without treating unrun scenarios as passing.

## 6. Shared-file contribution requests

- `packages.json`, `src/packages.rs`: request desktop-ID evidence, renderer references and approved dependency metadata through F01, later I01.
- `setup.sh:configure_filepicker/configure_roles/configure_environment`: submit bounded handler consent, readiness and variable-delivery requirements through F02/I01.
- `scripts/lib/setup-reliability.sh`: request association snapshot/restore and external-setting boundaries; do not implement a second rollback engine.
- Shared Hyprland adapters and `sources_example/*.lua`: request preserved launch/focus/autostart behavior; I01 serializes edits.
- Global GTK/Qt/KDE/portal files: F03 owns appearance; D06 requests only necessary app/handler coordination.
- `tests/run.sh`, common fixtures and CI: submit suite registrations through F04/I01; domain suites remain D06-owned.
- `Documents/app-selections.md` and canonical plans: supply exact limitations/operation notes; I01 and parent retain their respective writing authority.

## 7. Preservation, activation, rollback and security

Preview source templates, installed configuration, external association state and runtime effects separately.
Use F02 ownership checks, staging, validation, backups, Stow-safe replacement and digest-guarded restoration.
Preserve unknown keys, user overrides, custom bindings and existing installed alternatives; deselection is not uninstallation.
Appearance adoption never resets Dolphin behavior, editor sessions, browser privacy settings or calendar configuration wholesale.
Association snapshots include absence and relevant list ordering; restore only approved changes, not an entire settings database.
Detect edits made after application before rollback; report conflicts instead of overwriting newer user choices.
Batch recovery is bounded and recoverable, not a promise of cross-file or external-service atomicity.
No browser/editor restart with unsaved work; unsupported live reload becomes deferred activation, not automatic termination.
Treat paths, URIs, desktop entries, archive names and filenames as untrusted input; retain argv boundaries and reject unsafe interpolation.
Do not log complete sensitive URLs, file paths, calendar content or credentials; screenshots use synthetic documents and events.
Mount tests use disposable fixtures and separately authorized devices; never format media, bypass authorization or recursively clean real directories.
Archive tests include traversal/symlink hazards without executing extracted content; trash tests never substitute permanent deletion.
Offline Neovim tests must avoid the shipped automatic plugin/tool downloads; renderer validation must not execute user hooks.

## 8. Intended validation and decision gates

Existing inspected checks, to run later: `bash tests/run.sh tests/shell/file_manager.sh tests/shell/tui_file_manager.sh`.
Existing foundation-referenced regression suites should also cover membership, Lua argv and atomic/rollback behavior; they were not executed here.
Proposed D06 suites listed in §5 must be created and registered before their intended runner commands are meaningful.
Real-session acceptance separately observes URL/folder/text dispatch, file edit/save, calendar readiness and focus/placement on multiple monitors.
F04 records versions, fonts, scale and toolkit constraints for manual VM visual review; no numeric image/performance tolerance is required, and argv tests cannot prove real application effects.
Each option needs inbound/outbound switching evidence; multiple-choice roles need primary and non-primary coverage, not merely one representative app.

P01/P02 define the file/calendar workflows above and Mocha/Latte supported native appearance. P05 requires current Arch evidence with selectable limited options.
P06 fixes primary-following handlers, the TUI-editor desktop-entry fallback and independent partial application while preserving conflicting files/data. Safe reload only; defer restarts.
P07 uses functional tests and manual VM visual review; physical mounts/devices remain unverified where unavailable. Product choices are resolved; actual APIs, desktop IDs and preservation behavior still need evidence.
Escalate unproven mounting/trash/archive helpers, profile-writing theme requirements, missing desktop IDs and calendar readiness dependencies.
Stop feature-filling companions, unsafe ownership, irreversible writes or unapproved argv changes. Preserve and skip conflicting user configs while applying independent valid units; report unsupported native workflows as limited.
A declined helper or unsupported renderer leaves the requirement blocked; it does not remove the application or silently redefine success.

## 9. Implementation checklist and confidence

1. Not started — D06.1: reconcile option evidence and obtain required workflow decisions.
2. Not started — D06.2: implement approved reversible handler intents.
3. Not started — D06.3: preserve launch/focus and verify file/editor workflows.
4. Not started — D06.4: establish five calendar first-use procedures.
5. Not started — D06.5: implement selected-member F03 application renderers.
6. Not started — D06.6: deliver preservation, switching and acceptance evidence to I01.

Planning confidence: **92/100** for source-grounded scope, ownership and dependency ordering.
Runtime feasibility remains unverified; provisional contracts, desktop IDs, calendar initialization and per-app theme constraints limit certainty.

## Planning handoff

Workstream: D06 — Applications and default handlers.
Supplied source baseline: `610a18bac374e7e2ffd0bcb2d99b026131deedbc`, branch `feat/harmonize-visual-design`; Git state was not independently rechecked.
Repository mutations: none; no files written/edited, commands executed, installations, activations, commits or publication.
Inspected sources: entire master and F01–F04 drafts; scoped `packages.json` and `setup.sh`; complete `Documents/app-selections.md`; role/terminal/window/calendar helpers; Dolphin, Neovim and Calcurse configuration; both requested file-manager tests; scoped configuration-path searches.
Validation performed: read-only source inspection, option/count reconciliation, ownership/dependency review and existing-versus-proposed check separation.
Validation omitted: test execution, upstream/version research, effective-handler queries, graphical/hardware checks, screenshots and rollback execution.
Residual risks: concrete foundations, native appearance/workflow limits, safe MIME restoration and native calendar first-use feasibility. Product policy P01-P07 is resolved.
Canonical destination: `plans/planned/desktop-harmonization/D06-applications-default-handlers.md`; parent alone reconciles and writes the canonical plan.