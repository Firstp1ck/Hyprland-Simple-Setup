# Grill Me Results

Generated: 2026-09-20T18:33:01.239Z

## Plan

Use existing plan: desktop harmonization master plan

## Shared Understanding

Completed the desktop harmonization product interview and synchronized plans/planned/desktop-harmonization-master.md plus all 12 subplans. All 54 explicit answers are recorded in order. Product choices P01-P07 are resolved for planning; native-provider feasibility, concrete implementation interfaces and actual VM/hardware behavior are not certified. Documentation checks passed for 12 subplans, 73 work packages, 17 roles, 73 role-option rows, four None states, 115 remaining generic packages, 160 local links and an acyclic 17-node execution graph. Changes are confined to planning Markdown and tool-managed Grill Me state; implementation source and HEAD are unchanged. No implementation, install, live activation, commit or publication was authorized. Future work stays on feat/harmonize-visual-design, followed by the user's step-by-step disposable Arch VM testing.

## Questions and Answers

### 1. Which plan should we examine? Recommendation: use the existing desktop harmonization master plan, since it coordinates the 12 subplans we just created.

**Recommended answer:** Use existing plan: desktop harmonization master plan, since it coordinates the 12 subplans we just created.

**User answer:** Use existing plan: desktop harmonization master plan

**Status:** resolved

**Notes:** Explicit intake answer preserved from completed questionnaire 21fe6c6f-3d91-4d0d-bc1f-7d4ef4700a62, revision 0. Batch recorder is now available. Subject: plans/planned/desktop-harmonization-master.md and its 12 linked subplans. No design decisions were recorded before this intake.

### 2. What must remain equivalent when a user changes apps? Recommendation: the same desktop workflows and shared controls, while retaining native app-specific features. This is achievable without trying to turn Nano into an IDE or every browser into the same product.

**Recommended answer:** The same desktop workflows and shared controls, while retaining native app-specific features; do not try to make every application's internal features identical.

**User answer:** Same desktop workflows; native application features may differ

**Status:** resolved

### 3. What is the mandatory functionality baseline for every bar? Recommendation: all currently active Waybar operations, including their menus, with hardware-dependent controls shown only when applicable. Do not promote unused module definitions automatically.

**Recommended answer:** All currently active Waybar operations and menus; hardware-dependent controls only when applicable, without automatically promoting inactive modules.

**User answer:** All active Waybar operations and menus

**Status:** resolved

### 4. If an existing app cannot satisfy a mandatory capability safely, what should happen? Recommendation: keep it selectable with a clear limited-support label, but do not call that option fully harmonized. This preserves choice without hiding a failed requirement.

**Recommended answer:** Keep the app selectable with a clear limited-support label and withhold full-parity status.

**User answer:** Keep selectable, label limitations, withhold full-parity status

**Status:** resolved

### 5. May the setup offer extra tools to fill gaps in a selected app? Recommendation: small local helpers or companion interfaces, disclosed before installation, with no second full desktop shell or competing notification daemon. Feasibility must be proven first.

**Recommended answer:** Offer small local helpers or companion interfaces with explicit installation consent, after proving feasibility; no second full desktop shell or competing notification daemon.

**User answer:** Use native app features only; no extra companion tools

**Status:** resolved

**Notes:** Follow-up needed to distinguish ordinary repository adapters/theme generation from implementing missing app capabilities.

### 6. Which notification experience must every fully supported choice provide? Recommendation: popups, actions, dismissal, real DND state and browsable history. The current Fnott DND action does nothing, so this is a requirement to prove, not an existing capability.

**Recommended answer:** Popups, actions, dismissal, DND, browsable history and truthful status, subject to actual provider feasibility.

**User answer:** Popups, actions, dismissal, DND, browsable history and truthful status

**Status:** resolved

**Notes:** Native-only policy means providers lacking these capabilities remain limited, not silently supplemented.

### 7. Must every fully supported audio choice provide per-application volume and output routing? Recommendation: yes, while keeping ALSA hardware mixing a separate operation. Choosing how to fill the ALSA gap comes after this requirement is settled.

**Recommended answer:** Yes: per-app volume and routing must remain available, with ALSA hardware mixing treated separately.

**User answer:** Yes: per-app volume and routing must remain available

**Status:** resolved

**Notes:** Native-only policy makes ALSA-only options limited unless native capability evidence proves otherwise; do not add a companion.

### 8. What should the standard launcher shortcut open for every launcher? Recommendation: desktop applications with the same discovery rules; executable-command search remains a separate action. Currently Bemenu uses command discovery instead.

**Recommended answer:** Desktop applications by default, with executable-command search remaining a separate action.

**User answer:** Desktop applications by default; command search stays separate

**Status:** resolved

**Notes:** Resolve whether native-only excludes a desktop-entry provider for Bemenu, while retaining the existing executable discovery route.

### 9. Which dock features are mandatory when a dock is enabled? Recommendation: pinned apps, running-app display, launch/focus, active indicators and keyboard access. Treat autohide and richer window controls as optional until requested.

**Recommended answer:** Pinned apps, running-app display, launch/focus, active indicators and keyboard access; autohide and richer window controls optional.

**User answer:** Pinned applications; Running-application display; Launch an app or focus its existing window; Running and active indicators

**Status:** resolved

**Notes:** Keyboard-accessible dock switching, autohide and window actions were not selected as mandatory.

### 10. What must be common across terminal and multiplexer combinations? Recommendation: reliable command/cwd/clipboard behavior plus explicit create, attach, detach and basic pane workflows through the selected multiplexer. Native terminal tabs, image protocols and agent-specific extras need not match.

**Recommended answer:** Common terminal behavior and explicit multiplexer create/attach/detach/basic pane workflows; native tabs, image protocols and agent extras need not match.

**User answer:** Common terminal behavior and multiplexer session/pane workflows

**Status:** resolved

### 11. Which visual direction should guide the reference design? Recommendation: refine the current dark, blue-accented Waybar look into one consistent theme. This preserves the setup's identity without keeping its conflicting palettes.

**Recommended answer:** Refine the current dark, blue-accented setup into one consistent theme.

**User answer:** Use a consistent Catppuccin-inspired desktop

**Status:** resolved

### 12. Which appearance variants belong in the first supported release? Recommendation: dark, light, high-contrast and reduced-motion support, with readable enlarged text. These are independent appearance preferences, not four separate desktop implementations.

**Recommended answer:** Dark, light, high-contrast and reduced-motion support with readable enlarged text.

**User answer:** Dark appearance; Light appearance

**Status:** resolved

**Notes:** Dedicated high-contrast, reduced-motion and enlarged-text variants were not selected; later clarify preservation of existing accessibility preferences rather than assuming they should be disabled.

### 13. How far should harmonization change native GTK, Qt, libadwaita, browser and Electron interfaces? Recommendation: supported preferences and app themes with shared colors/fonts/spacing intent, accepting native widget differences. Avoid patched toolkits and fragile global CSS overrides.

**Recommended answer:** Supported preferences and app themes; accept native widget differences and avoid patched toolkits or fragile global overrides.

**User answer:** Use supported theming; accept native widget differences

**Status:** resolved

### 14. Which distributions need verified support in the first harmonized release? Recommendation: Arch Linux as the tested reference, with EndeavourOS and CachyOS documented as unverified until separately tested. More certified distributions increase the test matrix.

**Recommended answer:** Verify Arch Linux; document other Arch-based distributions as unverified until separately tested.

**User answer:** Verify Arch Linux; other Arch-based distributions initially unverified

**Status:** resolved

### 15. Which application versions should compatibility guarantees cover? Recommendation: the fully updated repositories at each tested release, recording exact versions and revalidating upgrades. Do not promise arbitrary historical versions.

**Recommended answer:** Current fully updated packages with exact tested versions recorded and upgrades revalidated.

**User answer:** Current fully updated packages, with recorded tested versions

**Status:** resolved

### 16. How should harmonization adopt existing installations? Recommendation: preview changes, obtain consent, preserve custom settings and update only clearly managed sections. Conflicting files remain unchanged until resolved.

**Recommended answer:** Opt-in preview, preserve custom settings and update only clearly managed sections; block conflicting changes.

**User answer:** Opt-in preview; preserve custom settings; block conflicting changes

**Status:** resolved

### 17. After an approved theme or app-selection change, how should running apps be handled? Recommendation: safe supported reloads only; defer anything requiring termination or session restart and report what remains pending.

**Recommended answer:** Safe supported reloads only; defer restarts and report pending activation.

**User answer:** Reload safely where supported; defer restarts

**Status:** resolved

### 18. Should changing primary browser, graphical file manager or editor also change system URL/folder/file associations? Recommendation: offer an explicit association preview and separate consent. A shortcut preference should not silently overwrite existing defaults.

**Recommended answer:** Offer association changes with a separate preview and consent.

**User answer:** Make system associations follow the selected primary app

**Status:** resolved

**Notes:** Reconcile with opt-in migration: association effects should be disclosed in the approved selection-change preview, rather than silently occurring while browsing choices.

### 19. May completed parts ship before the entire program is finished? Recommendation: incremental opt-in releases with category-level support labels; reserve the full-desktop harmonization claim until all required categories pass.

**Recommended answer:** Incremental opt-in releases with explicit category-level status; full-desktop claim only after required categories pass.

**User answer:** Other: all changes will be done in this branch, i will then test it step by step in a AVM

**Status:** resolved

**Notes:** Preserved exact returned Other text, including the control character. Interpreted intent for follow-up: all work on current branch, user performs step-by-step VM testing; no release/publication authorization.

### 20. How should acceptance thresholds be established? Recommendation: require semantic visual review plus reproducible screenshots, then set numeric resource/latency limits from measured baselines before acceptance. Cross-toolkit pixel identity is not a useful universal threshold.

**Recommended answer:** Semantic visual review and reproducible screenshots, then measured and approved numeric resource/latency budgets.

**User answer:** Manual visual review and functional tests, without numeric budgets

**Status:** resolved

### 21. Which environments can be made available for later verification? Recommendation: a disposable Arch VM plus separately approved physical-device checks. This answer identifies resources only; it does not authorize installations or changes to your current desktop.

**Recommended answer:** A disposable Arch Linux VM plus separately approved physical-device checks; this identifies resources, not permission for changes.

**User answer:** Disposable Arch Linux VM

**Status:** resolved

### 22. Does native-only still allow repository scripts that configure themes, translate existing native CLI/API calls and collect native status? Recommendation: yes, but do not implement missing application features or install companion interfaces. The shared foundation needs these adapters to connect the chosen apps.

**Recommended answer:** Allow configuration, theme generation and adapters to existing native CLI/API capabilities; do not implement replacement features or install companion interfaces.

**User answer:** Allow configuration and native-API adapters; no replacement features or companions

**Status:** resolved

### 23. Which Catppuccin pair should define dark and light appearance? Recommendation: Mocha for dark and Latte for light, giving one clear reference for every app mapping.

**Recommended answer:** Mocha dark and Latte light.

**User answer:** Mocha dark and Latte light

**Status:** resolved

### 24. Which accent should be shared across the desktop? Recommendation: Catppuccin Blue in each variant, preserving the setup's blue emphasis without copying identical hex values between dark and light palettes.

**Recommended answer:** Catppuccin Blue in each variant.

**User answer:** Blue

**Status:** resolved

### 25. Which font policy should the theme use? Recommendation: Noto Sans for ordinary GUI text and JetBrains Mono Nerd Font for terminals/code, with a consistent readable size scale. Avoid bold monospace text everywhere.

**Recommended answer:** Noto Sans for GUI text and JetBrains Mono Nerd Font for terminals/code, with consistent readable sizing.

**User answer:** Noto Sans GUI text; JetBrains Mono Nerd Font terminals/code

**Status:** resolved

### 26. Which application icon family should be the common default? Recommendation: Breeze, already referenced by the GTK/Qt configuration, with dependencies checked explicitly. Do not bundle a new icon family just to imitate every app's branding.

**Recommended answer:** Breeze icons with explicit dependency verification and suitable dark/light variants.

**User answer:** Breeze icons, using an appropriate dark/light variant

**Status:** resolved

### 27. Which cursor direction should replace the current conflicting cursor settings? Recommendation: retain Rose Pine where supported and verify a matching XCursor fallback, rather than assigning an unsupported format to apps. If no coherent supported pair exists, report that before adopting it.

**Recommended answer:** Rose Pine with a verified matching XCursor compatibility fallback; report inability to provide a coherent supported pair before adoption.

**User answer:** Rose Pine cursor with a verified matching compatibility fallback

**Status:** resolved

**Notes:** Asset compatibility remains a technical verification task, not a user-approved fallback to another family.

### 28. What density should guide bars, launchers, notifications and custom dialogs? Recommendation: balanced desktop sizing with modest rounded corners, comfortable targets and compact spacing; native widgets keep their supported geometry.

**Recommended answer:** Balanced desktop sizing, modest rounding and comfortable targets; retain supported native widget geometry.

**User answer:** Balanced sizing, modest rounding and comfortable targets

**Status:** resolved

### 29. What effects policy should the theme follow? Recommendation: subtle transparency/blur on shell surfaces where supported, opaque readable application content, and no requirement to emulate unavailable effects.

**Recommended answer:** Subtle supported transparency/blur on shell surfaces, opaque application content, no emulation of unavailable effects.

**User answer:** Subtle shell transparency/blur; opaque application content

**Status:** resolved

### 30. What should a fresh installation use initially? Recommendation: dark mode by default with explicit manual dark/light switching; existing installations retain their approved preference. Automatic scheduling can stay outside this first version.

**Recommended answer:** Dark by default with manual dark/light switching; preserve existing approved preferences and omit automatic scheduling.

**User answer:** Dark by default; manual dark/light switching

**Status:** resolved

### 31. On a fresh multi-monitor setup, where should the bar appear? Recommendation: one bar on every connected output, using the same approved module layout and reacting safely to hotplug. Preserve existing custom output assignments during migration.

**Recommended answer:** One bar on every connected output, with safe hotplug behavior and existing custom assignments preserved during migration.

**User answer:** One bar on every connected output

**Status:** resolved

### 32. When a user enables a dock without existing pin settings, what should it pin initially? Recommendation: selected primary terminal, browser, graphical file manager and GUI editor when enabled, without pinning disabled optional roles.

**Recommended answer:** Pin the primary terminal, browser, graphical file manager and enabled GUI editor; omit disabled optional roles.

**User answer:** Pin the primary terminal, browser, file manager and enabled GUI editor

**Status:** resolved

### 33. What should do-not-disturb mean for fully supported notification providers? Recommendation: suppress all notification popups, including critical urgency, while keeping status truthful. Locking and security prompts remain separate from notification DND.

**Recommended answer:** Suppress all notification popups during DND, with truthful status; locking and authentication remain separate.

**User answer:** Suppress ordinary popups but allow critical notifications

**Status:** resolved

### 34. What retention policy should apply where the provider natively supports it? Recommendation: session-only history capped at 100 entries, with no added disk-backed cache. Providers unable to meet the agreed policy must disclose the limitation.

**Recommended answer:** Session-only native history capped at 100 entries, without an added disk-backed cache; disclose unsupported policy.

**User answer:** Native persistent history, maximum 24 hours and 100 entries

**Status:** resolved

**Notes:** Both retention limits apply; no new history backend or companion is authorized. Further privacy/locked-screen details may need clarification.

### 35. What notification content may appear while the screen is locked? Recommendation: none. Use supported native behavior and verify the lock-screen boundary; do not treat DND alone as a security barrier.

**Recommended answer:** Show no notification content while locked, with the lock-screen boundary independently verified.

**User answer:** Show no notification content while locked

**Status:** resolved

**Notes:** Lock privacy takes precedence over the critical-notification exception during ordinary unlocked DND.

### 36. Which file-manager workflows define full support? Recommendation: browse folders, open files with selected apps, open the selected editor, access already mounted volumes, and provide trash/recovery and archive workflows where native support exists. Missing required workflows produce limited status, not companions.

**Recommended answer:** Browse/open/edit, access mounted volumes, trash/recovery and archive workflows; missing native required workflows produce limited status, not companions.

**User answer:** Browse/open/edit, mounted volumes, trash/recovery and archive workflows

**Status:** resolved

### 37. What should a calendar provide on a fresh installation without online accounts? Recommendation: a usable local calendar for viewing, creating and editing events. Use native initialization only, and preserve all existing calendar data on upgrades.

**Recommended answer:** View, create and edit local events without an account, using native initialization and preserving existing data.

**User answer:** View, create and edit local events without an online account

**Status:** resolved

### 38. How should bars handle hardware that is not present, such as a VM with no battery or Bluetooth adapter? Recommendation: hide inapplicable hardware modules, but show failures or stale state when an expected device/backend stops working. Never confuse absence with a command failure.

**Recommended answer:** Hide genuinely absent hardware; show errors or stale state for expected devices/backends.

**User answer:** Keep modules visible with explicit unavailable states

**Status:** resolved

**Notes:** Overrides earlier recommendation of conditional display, not a reversal of a recorded user choice; keep absence, backend error and disabled states distinct.

### 39. Which power actions should require explicit confirmation? Recommendation: confirm logout, reboot and shutdown; keep lock immediate and suspend deliberate but without an extra dialog. Offer hibernate only when its prerequisites are verified.

**Recommended answer:** Confirm logout/reboot/shutdown, keep lock immediate and suspend direct, and offer hibernate only when prerequisites are verified.

**User answer:** Confirm logout/reboot/shutdown; immediate lock and direct suspend

**Status:** resolved

### 40. When a selected limited-support app cannot perform a requested standard action, what should the desktop do? Recommendation: keep its normal native launch available, but clearly disable or explain the unsupported action and return an honest unsupported result. Never silently substitute a different action or app.

**Recommended answer:** Explain or disable unsupported standard actions with an honest unsupported result, while keeping normal native launch available; no silent substitutions.

**User answer:** Explain/disable the unsupported action; keep normal native launch available

**Status:** resolved

### 41. Where should manual dark/light switching be available? Recommendation: installer settings plus a dedicated project command and an entry in the existing desktop tools menu. These configure native themes, not a new companion service; theme switching must not rerun package installation.

**Recommended answer:** Installer settings, a dedicated project theme command and an entry in the existing desktop tools menu; no package installation during theme switching.

**User answer:** Installer appearance setting; Dedicated Hyprland keyboard shortcut; Dedicated control on every supported bar

**Status:** resolved

**Notes:** User-facing command and tools-menu entry were not selected. A shared internal action is still needed behind the chosen controls; no scheduling daemon.

### 42. Within native-only support, may the installer declare required theme assets and the actual dependencies of existing native workflows? Recommendation: yes, with a package preview. This includes fonts/icons/cursors and currently missing calculator or music prerequisites, but not apps added to imitate missing features.

**Recommended answer:** Allow theme assets and genuine native-workflow dependencies with a package preview; do not add apps to imitate missing capabilities.

**User answer:** Allow theme assets and genuine native-workflow dependencies, with preview

**Status:** resolved

### 43. How should shell prompts be harmonized without forcing another tool? Recommendation: theme native prompts and preserve an existing selected Starship setup, rather than make Starship mandatory across Bash, Fish and Zsh.

**Recommended answer:** Theme native prompts and preserve existing Starship integration; do not make Starship mandatory.

**User answer:** Theme native prompts; preserve existing Starship integration

**Status:** resolved

### 44. When a dock is enabled on a fresh multi-monitor setup, where should it appear? Recommendation: on the designated primary output only, avoiding duplicated task controls while the bars remain on every output. Preserve existing custom assignments.

**Recommended answer:** Primary output only, preserving existing custom assignments during migration.

**User answer:** Follow the currently focused output, where natively supported

**Status:** resolved

**Notes:** A dock lacking native follow-focus support needs an explicit fallback policy; do not emulate missing features or silently change monitor behavior.

### 45. If GUI editor is set to None, what should text-file associations do? Recommendation: follow the primary TUI editor through a managed desktop entry and the selected terminal. This invokes existing native functionality and matches your rule that defaults follow the chosen primary.

**Recommended answer:** Use a managed desktop entry to launch the primary TUI editor through the selected terminal.

**User answer:** Open text files in the primary TUI editor through the selected terminal

**Status:** resolved

### 46. If an approved appearance or selection-change batch encounters a user-edited configuration conflict, how much should be applied? Recommendation: block that whole configuration batch before activation, show the conflict and leave the prior setup active. Unrelated package operations are not claimed to roll back.

**Recommended answer:** Block the whole configuration batch before activation, preserve the prior active setup and explain the conflict; no package rollback claim.

**User answer:** Apply nonconflicting apps and clearly mark the batch partially applied

**Status:** resolved

**Notes:** Requires dependency-aware activation units and reporting of mixed theme/selection state; cannot skip a shared prerequisite and still activate its dependents.

### 47. For the 24-hour history limit, is native cleanup on the next provider start sufficient when the provider was not running? Recommendation: yes, discard expired entries before they are displayed after startup. A strict deletion deadline while the provider is stopped would need capabilities we cannot assume under native-only support.

**Recommended answer:** Use native expiration while running and purge expired entries before display on restart; no invented off-process deletion guarantee.

**User answer:** Native expiration while running; purge expired entries before display on restart

**Status:** resolved

### 48. How should notifications marked transient or private by their sender be handled in persistent history? Recommendation: do not retain them when native provider policy can honor those hints, and disclose any limitation. Do not claim that arbitrary OTPs or secrets can be detected reliably.

**Recommended answer:** Exclude sender-marked transient/private notifications where native support permits and disclose limits; do not claim reliable arbitrary-secret detection.

**User answer:** Exclude sender-marked transient/private notifications where native support permits

**Status:** resolved

### 49. Which single authentication agent should the managed session use? Recommendation: Hyprpolkitagent, already a required dependency, and stop requesting the duplicate KDE agent in setup-owned autostart. Existing foreign session owners must not be terminated automatically.

**Recommended answer:** Hyprpolkitagent as the managed authentication agent; remove the duplicate setup-owned KDE autostart request without terminating foreign owners.

**User answer:** Hyprpolkitagent as the managed authentication agent

**Status:** resolved

### 50. What should the desktop logout action terminate? Recommendation: only the current Hyprland/login session. If that session cannot be identified safely, report an error rather than fall back to terminating every session belonging to the user.

**Recommended answer:** Terminate only the current session; fail safely when it cannot be identified.

**User answer:** Current session only; fail safely if it cannot be identified

**Status:** resolved

### 51. When the interview is complete, should I incorporate its decisions into the planning documents? Recommendation: save the interview record and update the master plus affected subplans, marking native-only limitations and VM-only verification accurately. This still authorizes no implementation or desktop changes.

**Recommended answer:** Save the interview record and update the master and affected subplans; no implementation or desktop changes.

**User answer:** Save the interview and update the master and affected subplans

**Status:** resolved

### 52. If a dock cannot natively follow the focused output, which fallback is acceptable? Recommendation: use a documented fixed primary output, preserve existing custom assignments, and label follow-focus unsupported. Do not emulate follow-focus with another service.

**Recommended answer:** Use a documented fixed primary output, preserve custom assignments and label follow-focus unsupported; no emulation service.

**User answer:** Use the fixed primary output and label follow-focus unsupported

**Status:** resolved

### 53. Which default shortcut should toggle dark/light mode? Recommendation: Super+Shift+T, unused in the shipped keybindings.lua. Detect and preserve custom binding conflicts during adoption rather than overwrite them.

**Recommended answer:** Super+Shift+T, with detection and preservation of existing custom-binding conflicts.

**User answer:** Super+Shift+T, with custom-binding conflict detection

**Status:** resolved

### 54. If the new primary app launches correctly but its user-edited theme configuration conflicts, should routing still switch? Recommendation: apply the approved primary choice and its system associations, preserve the conflicting theme file, and clearly report incomplete appearance. A broken required runtime dependency must still block its dependent action.

**Recommended answer:** Switch the approved primary routing and associations, preserve the conflicting theme file and report partial appearance; block actions with broken required runtime dependencies.

**User answer:** Switch routing/associations; preserve conflicting theme and report partial appearance

**Status:** resolved

## Agreed Decisions

- P01: Same desktop workflows, not identical app internals. Preserve active Waybar operations/menus, add the requested theme control, show bars on all outputs, and keep missing hardware modules visible with distinct unavailable/error/disabled states.
- P01/P05: Use native capabilities only. Configuration/theme generation and adapters to native CLI/APIs are allowed; no replacement features, missing-feature emulation or companion interfaces. Theme assets and genuine existing native-workflow dependencies may be included with a package preview.
- P05: Keep limited options selectable, preserve ordinary native launch and explain/disable unsupported actions. No silent substitutions or full-parity claims for incomplete options; no blanket block on branch delivery.
- P01: Standard launcher mode discovers desktop applications; executable search is separate. Native discovery gaps stay explicitly limited rather than gaining a feature provider.
- P01: Docks require pins, running-app display, launch/focus and active indicators. Seed primary terminal/browser/file manager/enabled GUI editor. Native follow-focus is preferred; otherwise use fixed primary output with a limitation label. Preserve custom assignments; autohide, dock-specific keyboard switching and window actions are optional.
- P01: Terminal/multiplexer parity includes command/cwd/clipboard and native create/attach/detach/basic-pane workflows. Common dashboards and terminal/agent-native extras are not mandatory. Theme native shell prompts and preserve existing Starship without making it mandatory.
- P01/P04: Full audio support requires native per-app volume/routing; ALSA hardware mixing remains separate. ALSA-only choices retain native launch and limited status without companion mixers.
- P01: Full file-manager workflows include browse/open/edit, already-mounted volumes, trash/recovery and archives. Calendars should view/create/edit local events without online accounts using native initialization; preserve existing data.
- P02: Mocha dark and Latte light, Blue accents, Noto Sans GUI text, JetBrains Mono Nerd Font terminals/code, Breeze icons and Rose Pine cursor with a verified matching compatibility fallback.
- P02: Balanced sizing and modest rounding; subtle supported shell blur/transparency and opaque app content. Supported native theming only; native widget differences accepted. Dark/light are required; dedicated high-contrast, enlarged-text and reduced-motion variants are not, and existing accessibility preferences remain preserved.
- P02: Dark default with manual switching through installer settings, Super+Shift+T with custom-binding conflict detection, and a dedicated control on each supported bar. Shared internal action allowed; no required public standalone command, tools-menu entry, scheduler or package-install rerun.
- P03: Full support includes popups, actions, dismissal, DND, browsable history and truthful status. Unlocked DND allows critical notifications but suppresses ordinary ones. While locked, no notification content may appear, overriding the critical exception.
- P03: Native persistent history capped at both 24 hours and 100 entries. Native expiration while running and purge-before-display on restart. Respect sender transient/private hints where natively supported and disclose limitations; no new cache/interception service, arbitrary-secret detection or secure-erasure claim.
- P05/P07: Current fully updated Arch packages with exact versions recorded. Other distributions and physical hardware unverified. All changes on the current branch, then user-led step-by-step disposable Arch VM tests. Manual visuals and functional tests without numerical visual/performance budgets or incremental publication.
- P06: Opt-in preview and preservation on existing installations. Skip conflicting app configs and apply independent nonconflicting units with partial-state reporting. Required shared/runtime failures block their dependents.
- P06: A launchable new primary may switch routing and system associations despite an appearance-only conflict; retain that file and report partial appearance. Approved primary changes drive URL/folder/file handlers. GUI editor None uses a managed desktop entry for the primary TUI editor through the selected terminal.
- P06: Safe supported reloads only; defer restarts. Hyprpolkitagent is the managed authentication agent; do not terminate foreign owners automatically. Logout only the current session, failing safely when it cannot be identified.
- P01: Confirm logout/reboot/shutdown, keep lock immediate and suspend direct, and expose hibernate only when prerequisites are verified. VM evidence does not certify physical suspend/hibernate.
- Interview scope: user approved saving the record and updating the master and affected subplans only. No implementation or live desktop changes.

## Open Risks

- Native notification history/DND, both retention limits, sensitive-hint handling and lock privacy need provider evidence. Some options may remain limited; do not add companions or weaken requirements.
- Native per-app audio routing, desktop-entry launcher modes, dock follow-focus and full file/calendar workflows remain provider-specific verification tasks.
- Rose Pine compatibility assets and actual native GTK/Qt/libadwaita/Electron/TUI theme mappings need validation; pixel identity is not promised.
- Independent partial application requires dependency-aware units, truthful desired-versus-active state, safe singleton handling and guarded rollback, particularly for shared global settings.
- The Arch VM does not verify physical radios/audio/battery/backlight, physical mixed-DPI/hotplug or suspend/hibernate; mark those claims unverified.
- Implementation, application tests and actual VM visual/functional review remain unperformed. The original independent subplan review preceded this policy amendment; the amendment received parent document checks, not another delegated review.

## Next Decision Needed

Obtain separate authorization to execute SPEC against these resolved choices. Verify native capabilities, concrete contracts and asset support, keeping unsupported options honestly limited. No currently identified product question needs to be repeated.
