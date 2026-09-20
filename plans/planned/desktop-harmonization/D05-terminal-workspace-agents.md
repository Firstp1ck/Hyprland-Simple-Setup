# D05 — Terminal workspace and agents

Status: product policy synchronized with the completed interview; implementation not started. Apply master section 9 and the [decision record](../desktop-harmonization-grill.md); native profile/session evidence remains pending.
Master: [Desktop harmonization master](../desktop-harmonization-master.md).
Supplied baseline: `610a18bac374e7e2ffd0bcb2d99b026131deedbc`, branch `feat/harmonize-visual-design`.

## 1. Goal, scope and boundaries

Goal: harmonize selected terminal-workspace members while preserving independent choices, literal launch arguments, existing sessions and agent safety boundaries.
Own application-specific shell, terminal and multiplexer mappings; terminal launch/environment contributions; workspace/dashboard proposals; agent presentation and triage compatibility.
[D06](D06-applications-default-handlers.md) owns editor/file-manager configuration and handlers; D05 supplies their terminal/environment boundary.
Do not redesign agent installation, authentication, provider configuration, project discovery or application data.
Do not introduce another catalog, action bus, theme source, transaction engine or test framework.
Discovery and contract contributions may precede foundation implementation; application implementation waits for frozen F01/F02/F03/F04 contracts and the master foundation gate.
All proposed interfaces below remain provisional; this document grants no implementation, installation, activation or publication permission.

### Exact option coverage

| Role | Members and selection contract | D05 coverage |
|---|---|---|
| Shell | Bash `bash`, Fish `fish`, Zsh `zsh`; required multiple selection, one primary | Environment, locale preservation, prompt colors, selected-shell startup and managed aliases |
| Terminal | Kitty `kitty`, Alacritty `alacritty`, Ghostty `ghostty`, Konsole `konsole`, Foot `foot`; required multiple selection | ANSI palette, typography, padding, basic bindings, cwd, title/app identity and launch |
| Multiplexer | tmux `tmux`, Zellij `zellij`, Herdr `herdr-bin`/`herdr`; required multiple selection | Selected-member appearance, launch/attach, panes/workspaces and dashboard feasibility |
| Coding agent | Pi `pi`, OpenCode `opencode`, Claude Code `claude-code`/`claude`, Codex CLI `codex-cli`/`codex`, Cursor CLI `cursor-cli`/`cursor-agent`; optional multiple selection | Terminal presentation, executable resolution and preserved click-only triage |
| Agent None | Empty selection, no primary | No agent invocation or installation; ordinary notification fallback; no uninstall |

Current application defaults remain Fish, Kitty, Herdr and Pi. Approved appearance uses Mocha/Latte, Blue, Noto Sans GUI text and JetBrains Mono Nerd Font terminal/code text. Theme native shell prompts and preserve existing Starship; do not require a new prompt companion.
Required workspace parity is native command/cwd/clipboard behavior plus create/attach/detach/basic panes. Common dashboards, native terminal tabs/image protocols and agent-specific features remain optional.
Primary controls ordinary routing; every selected member receives applicable appearance coverage, including non-primary agents.
None is valid for agents, not shells/terminals/multiplexers; consumers must also preserve D06's GUI-editor and TUI-file-manager None behavior.

## 2. Observed source evidence

These are static observations, not successful test results or verified upstream compatibility.

| Source anchor | Observed behavior and implication |
|---|---|
| `packages.json:roles.shell/terminal/multiplexer/agent` | Independent multi-member roles, explicit executables and empty current argv; agent installers have fixed metadata |
| `dotfiles/.bashrc`, `.bash_profile` | Profile sources Bash rc; rc is interactive-gated, hardcodes Neovim/Kitty, `TERM=kitty`, Zellij alias, locale and Qt environment |
| `dotfiles/.config/fish/config.fish`, `conf.d/01-env.fish`, `02-aliases.fish`, `04-apps.fish` | Starship/vi bindings, hardcoded PATH replacement, interactive chmod, editor/multiplexer aliases and toolkit overrides need narrow ownership review |
| `fish/conf.d/fish_frozen_theme.fish` | File identifies itself as Fish-managed; do not overwrite it as an ordinary generated theme |
| `dotfiles/starship.toml` | Root-level file contains Catppuccin palettes and glyph-heavy prompt; `.config/starship.toml` is absent and scoped search found no `STARSHIP_CONFIG` reference |
| `kitty/kitty.conf`, `alacritty/alacritty.toml` under `.config` | Both explicitly start Fish; colors overlap but fonts, opacity, bindings and padding differ |
| `zellij/config.kdl` | Catppuccin Frappe, locked mode, Fish default shell, custom bindings and disabled pane frames |
| `kitty/my_layout.conf`, `zellij/layouts/sysmon.kdl` | Separate btop/fastfetch/cava dashboard layouts with different shell command forms |
| Scoped `dotfiles` inventory | No shipped tmux or Zsh config found; `.config` listing has no Ghostty, Konsole, Foot or Herdr profile directory |
| `setup.sh:configure_roles` | Generates one terminal-wrapped preferred-multiplexer action; updates Fish environment/editor aliases and exact stock shortcut migrations |
| `setup.sh:set_shell_language_config` | Updates every selected shell; supports XDG Fish and `ZDOTDIR`; deduplicates source/runtime aliases and uses reliability writes |
| `setup.sh:configure_shell` | Changes primary login shell through validated `/etc/shells` membership and verifies account result; not a theme operation |
| `setup.sh:configure_hypr_autostart_optional_extras` | Kitty dashboard remains independent of multiplexer; Alacritty/Zellij example requires primary Zellij; reconciles competing stock layout lines |
| `hypr/scripts/term_exec.sh`, `role_exec.sh` | Array-based launch, terminal-specific identity/title flags, no explicit cwd option, GUI-editor None fallback to TUI editor |
| `.local/scripts/troubleshoot_with_agent.py` | Private frozen incidents, click-only dispatch, selected-multiplexer fallback and at-most-once consumption |
| `Documents/agents.md`, `Documents/app-selections.md` | Document installer/credential boundaries, schema 2, primary/member separation and on-demand multiplexers |

Paths abbreviated in the table are beneath `dotfiles/`.
The Starship file's actual application consumption remains unverified; file existence is not adoption evidence.
Source comments describing application versions/defaults are not fresh upstream evidence.
No local-wiki tools were available; no web research or current-version claim was made.

## 3. Proposed capability and theme mapping

F01 owns capability identities and requirement levels; D05 contributes these mappings to its single ledger.
F03 owns semantic tokens, assets and variants; D05 renderers consume its interface and emit staged candidates only.

| Member/surface | Proposed mapping and observable workflow | Limit or feasibility gate |
|---|---|---|
| Bash | Prompt/error/selection intent where supported; role-aware environment and managed editor/multiplexer launch aliases | Preserve user prompt hooks, vi mode, noninteractive silence and history |
| Fish | Syntax/pager colors, existing Starship integration, role environment and aliases | Resolve frozen-theme precedence without changing universal user state |
| Zsh | Minimal managed environment/prompt integration using native facilities | No mandatory prompt framework or plugin bundle; honor `ZDOTDIR` safely |
| Kitty | ANSI 0–15, foreground/background, selection, cursor, tabs/borders, font and padding | Keep native layouts; background image/transparency adoption needs P02/P06 |
| Alacritty | Equivalent palette/font/padding/cursor and basic keyboard operations | Validate actual supported syntax; existing template comments are insufficient |
| Ghostty | Native palette/font/padding/binding mapping and existing launch identity | Configuration paths, syntax and reload support require P05 evidence |
| Konsole | Terminal profile/colorscheme plus existing separate-process/title behavior | F03 owns surrounding Qt appearance; profile activation needs native proof |
| Foot | Native terminal palette/font/padding/bindings and app-ID behavior | Confirm supported syntax and units before renderer implementation |
| tmux | Status/border/message colors; create, list, attach, detach and cwd behavior | Discover native config/attach details; no plugin dependency assumed |
| Zellij | Theme, status/pane states and existing locked-mode interaction | Preserve custom modes/layouts; distinguish attach from incident-session creation |
| Herdr | Native theme/workspace mapping if supported; explicit session targeting | Existing API calls are source evidence only; theme/attach capabilities unverified |
| All five agents | Terminal ANSI/font inheritance; optional native theme preferences only where verified | Never claim inherited ANSI proves full truecolor/internal UI harmonization |
| Agent None | No agent-specific output, activation or workspace action | Global terminal appearance remains independently applicable |

Request an F03 amendment for explicit terminal ANSI 0–15 mappings, default/bright foreground semantics and selection/cursor contrast pairs.
Do not derive ANSI values independently in each renderer or equate arbitrary RGB application output with configurable terminal colors.
Map the approved dark/light variants and retain readable non-color error/focus cues. Preserve existing accessibility preferences; dedicated high-contrast/enlarged-text/reduced-motion variants are not required.
Basic bindings cover copy/paste, search/scrollback and font adjustment where supported; tab/pane operations remain separate capability rows.
Preserve alternate-screen input and application shortcuts; reconcile collisions before recommending any common binding.
Missing package, unsupported version/capability, missing font, invalid configuration, cancellation and launch failure remain distinct.
Missing graphical session/output/audio source is unavailable evidence, not successful dashboard or scaling acceptance.

## 4. Producer–consumer handoffs

| Direction | Contract contribution and dependency |
|---|---|
| [F01](F01-inventory-capability-contracts.md) → D05 | Frozen option/member identities, capability requirements, dependency policy and P05 support envelope |
| D05 → F01 | Pre-foundation shell/terminal/multiplexer/agent rows, None semantics, dashboard alternatives and unresolved native-theme evidence |
| [F02](F02-runtime-managed-configuration.md) → D05 | Frozen argv/results, managed-output ownership, Stow/XDG handling, activation and rollback interfaces |
| D05 → F02 | Compatibility cases for `term_exec.sh`, cwd, identity, shell environments and triage's special dispatch boundary |
| [F03](F03-visual-system-theme-generation.md) → D05 | Frozen renderer registration, tokens/assets, variants and activation descriptors |
| D05 → F03 | ANSI token amendment, per-member mappings, native limits and output-collision/activation declarations |
| [F04](F04-verification-foundation.md) ↔ D05 | Coverage foreign keys, isolated fixtures, evidence levels and domain effect/visual scenarios |
| D05 → D06/D04/D07 | Literal terminal launch, inherited/explicit cwd specification, identity/title behavior and selected-editor environment |
| D06 → D05 | Editor executable/argv intent, pager limits and GUI-editor None fallback; no editor configuration ownership transfer |
| D05 ↔ [D03](D03-notifications-attention.md) | Preserve triage notification action key, click consent, dismissal and plain-notification fallback |
| D05 → [I01](I01-integration-rollout-acceptance.md) | Serialized shared-file requests, operation notes, switching cases and measured evidence |

D04 and D07 consumers are [Device controls](D04-device-controls.md) and [Session and auxiliary interfaces](D07-session-auxiliary-interfaces.md).
Specifications can flow before the foundation gate; completed D05 adapters must not become prerequisites for their own foundation.

### Launch and session contract contribution

Retain `term_exec.sh [--app-id …] [--title …] -- command args…` unchanged for existing callers.
Propose an additive explicit-cwd input only after F02 freezes validation/error semantics; omitted cwd keeps inherited process behavior.
Validate cwd without shell interpolation; missing/unreadable directories fail clearly rather than silently opening HOME.
Preserve Kitty/Alacritty class flags, Ghostty equals-form flags, Foot app-ID/no-`-e` form and Konsole `--separate` with fixed identity title.
Do not unify triage with generic terminal wrapping merely to remove duplication: its validated executable/environment boundary is deliberately narrower.
Ordinary session attach must be explicit and distinct from new session/workspace creation; never infer an arbitrary existing session.
Do not send agent prompts or keystrokes into an unrelated pane; triage creates fresh incident surfaces.
Preserve triage order: valid metadata uses primary then selected alternatives in catalog order; absent multiplexer role permits legacy tmux/Zellij/Herdr availability order.
Malformed present multiplexer metadata goes to plain terminal; installed-but-unselected multiplexers are not new-metadata fallbacks.
Herdr probe failure may fall through before mutation; uncertain create/run outcomes must not retry or dispatch elsewhere.
An accepted terminal spawn is not proof the command ran; preserve current at-most-once behavior while reporting evidence honestly.

## 5. Implementation work packages

All work packages are **not started**; future execution requires authorization.

### D05.1 — Freeze domain capability and compatibility contributions

Prerequisites: supplied baseline recheck and F01–F04 draft review; discovery may precede foundation implementation.
Ownership: D05 evidence/specification contributions; F01 ledger, F02 launch contract and F04 descriptor files remain producer-owned.
Deliverables: exhaustive member/None matrix, current routing fixtures, native-config evidence requests and P01/P02/P05 decision briefs.
Include Bash/Fish overrides, Starship consumption, unsupported native agent colors and dashboard/attach distinctions.
Validation: static caller trace and proposed isolated native-config probes with version/source evidence; no installer or authenticated-agent probe.
Done: producer owners reconcile contracts and unresolved requirements are marked blocking rather than declared supported.

### D05.2 — Implement role-aware shell environment and prompt mappings

Prerequisites: D05.1, frozen foundation gate; P02 for visual values and P06 for existing-user adoption.
Ownership: D05 owns bounded `.bashrc`, `.bash_profile`, Fish configuration and `dotfiles/starship.toml` contributions; setup wiring routes through I01.
Deliverables: shell-native managed regions/includes and F03 renderer registrations; Zsh include/profile paths are **proposed**, pending discovery.
Set role-derived editor/terminal/browser intent; keep command argv out of unsafe scalar reconstruction and preserve user PATH additions.
Resolve hardcoded `TERM`, terminal Fish overrides and toolkit variables with F02/F03; do not silently rewrite them during theme-only application.
Retain selected-member locale behavior and legacy language inputs; inventory Fish `LC_ALL` precedence without changing locale policy by assumption.
Validation: extend `shell_language.sh`; proposed `tests/shell/terminal_shell_environment.sh` covers all primaries/members, login/noninteractive modes, overrides and missing optional tools.
Done: approved stock migrations are reversible, custom aliases/hooks survive, shell startup adds no new network or broad chmod side effects.

### D05.3 — Implement five terminal renderers and launch compatibility

Prerequisites: D05.1–D05.2, frozen foundation gate, proven native syntax/assets and affected P02/P05 decisions.
Ownership: D05 terminal profiles and **proposed** `theme/renderers/d05/` registrations; F02/I01 owns shared `term_exec.sh` changes.
Deliverables: Kitty/Alacritty mappings plus **proposed** Ghostty/Konsole/Foot profile outputs whose exact destinations require native discovery.
Separate visual keys from shell-command/binding adoption; preserve unknown keys and explicit overrides through F02.
Validate all selected members even when one primary supplies launch routing; retain identity and cwd contracts for D06/D04/D07.
Validation: proposed `tests/shell/terminal_workspace.sh`, F03 deterministic-render fixtures and native parsing/effect checks for all five terminals.
Done: argv/identity compatibility holds, all approved visual mappings have evidence, and unsupported required mappings block parity.

### D05.4 — Implement multiplexer appearance and explicit workspace options

Prerequisites: D05.1/D05.3, foundation gate, P01 dashboard/session scope and P05 feasibility.
Ownership: D05 owns Zellij config/layouts and Kitty layout; tmux/Herdr profiles and provider-specific modules are **proposed** pending discovery.
Deliverables: three member mappings, explicit create/attach/detach behavior and dashboard feasibility evidence.
Preserve existing native dashboards as optional examples. Do not make a common dashboard mandatory, add companions or introduce a new autostart default. Any optional later enhancement requires separate scope approval.
Preserve Kitty's current dashboard independence, Alacritty/Zellij primary restriction, single-layout startup and on-demand multiplexer health semantics.
Validation: extend `multiplexer_runtime.sh`; test missing sessions, attach cancellation, existing work, nested contexts, missing btop/fastfetch/cava and duplicate startup.
Done: approved workspace workflows work without stealing sessions or changing current startup policy; unresolved mandatory dashboard parity stays blocked.

### D05.5 — Preserve agent/triage behavior and add bounded presentation

Prerequisites: D05.1/D05.3–D05.4, foundation gate; D03 notification contract; no authentication prerequisite.
Ownership: D05 owns `troubleshoot_with_agent.py` and its Python tests; agent installers remain unchanged shared integration inputs.
Deliverables: five-agent/None presentation descriptors, executable-resolution regression coverage and narrowly scoped native-theme proposals where supported.
Retain verified-path preference, registered paths/PATH fallback, current plan/read-only flags, fixed cwd and fresh incident surfaces.
Retain Pi tools restriction, OpenCode plan, Claude plan, Codex read-only and Cursor ask argv as repository contracts, not sandbox guarantees.
Validation: existing `agent_triage.sh` plus modeled five-terminal/three-multiplexer combinations, malformed metadata, uncertain handoff and deselection cases.
Done: no ambient-credential widening, auto-launch, prompt duplication, installer change or agent configuration migration; native theme gaps remain visible.

### D05.6 — Deliver migration, effect evidence and integration packet

Prerequisites: D05.2–D05.5; F04 fixtures; P06 activation consent and P07 acceptance criteria.
Ownership: D05 domain tests/evidence; F04 shared infrastructure and I01 shared files/documentation.
Deliverables: reviewed coverage descriptors, support limits, before/after previews and serialized setup/Lua/Hyprlang contributions.
Validation: fresh/upgrade/all-member/None switching, injected render/write/activation failures, guarded rollback and consented visual/keyboard sessions.
Done: every option has the required evidence level or explicit blocker; I01 receives no unqualified parity claim from static/argv tests alone.

## 6. Shared-file requests, preservation and security

Request `setup.sh` hooks for shell managed regions, renderer delivery, mode preservation and dashboard intent through F02 then I01.
Request coordinated `sources_example` and installed-source environment/keybinding/autostart/window-rule changes through I01; preserve exact-stock migration safeguards.
Request F01/I01 metadata amendments only for verified capabilities/dependencies; never alter installer allowlists or catalog defaults.
Request F04/I01 runner/coverage registration and I01 amendments to `Documents/agents.md` and `Documents/app-selections.md`.
Coordinate btop/cava/fastfetch appearance ownership with D07/F01; D05 owns dashboard launch/layout, not competing tool renderers.

F02 stages and validates managed outputs before commit; retain Stow topology, user regions, approved XDG roots and rollback manifests.
Do not adopt whole user rc/profile files, Fish universal variables or application-managed theme files without explicit ownership resolution.
Switching primary must not remove other selected members' themes; deselection removes only provably managed integration, never installed applications.
Theme activation must not invoke `chsh`, restart terminals, kill servers, detach sessions or discard unsaved work.
Use verified native reload only with approved activation policy; otherwise report next-launch/relogin requirements.
Rollback restores managed configuration with divergence guards; it cannot undo commands already executed, provider transmissions or vendor installer effects.
Keep current fixed installer endpoints/interpreters, reuse/soft-failure behavior, minimal installer environment and manual credential setup unchanged.
Retain root refusal, private incident ownership/modes, bounded snapshots/retention, best-effort redaction, environment filtering and at-most-once nonce claims.
Click consent may disclose evidence to the selected agent/provider; read-only CLI modes are not an OS sandbox.
Use synthetic projects/logs/screenshots; never inspect real credentials, export shell history or collect project paths/content for theme validation.
Do not broaden OSC clipboard permissions, remote asset fetching, plugin loading, session serialization or network dashboards as appearance work.

## 7. Acceptance, decisions and escalation

Existing checks to run later: `bash tests/run.sh tests/shell/multiplexer_runtime.sh tests/shell/agent_triage.sh tests/shell/shell_language.sh`.
Also retain existing roles membership/argv, agent installer/legacy-config, startup-triage and reliability suites; their existence is not evidence they passed.
Proposed checks: the D05.2/D05.3 suites, renderer fixtures and native effect procedures; none has been created or executed here.
Exercise each shell/terminal/multiplexer/agent as primary and non-primary, all-members selections, agent None, spaces/Unicode/metacharacters and invalid cwd.
Observe actual child cwd/argv, terminal identity, session creation/attach and ANSI/glyph rendering independently of adapter output.
Verify command/keyboard behavior, alternate-screen behavior and dark/light appearance in the VM. Preserve existing accessibility preferences; physical mixed-DPI/multi-monitor behavior remains unverified where unavailable.
Use synthetic agent executables offline; real provider checks require separate consent, no automatic authentication and recorded version limitations.

P01/P02 workflow, palette, font and prompt policy is resolved above; native extras remain optional. Starship is preserved when already used, not mandated.
P05 requires evidence for current Arch native profiles/APIs and truthful limited labels. P06 preserves conflicts, permits independent partial adoption and defers unsafe restarts.
P07 requires functional tests and manual VM visual review without numeric/hardware gates. P03 native notification-action feasibility still constrains triage; P04 remains D04's resolved native-only audio policy.
Escalate mandatory unsupported theme/workspace behavior, unsafe aliases/escaping, output collisions, uncertain session mutation or credential/data migration.
If a native requirement is unsupported, retain the option with a limited label and explain/disable that action. Do not add a companion, lower the full-support baseline or block the whole branch.

## 8. Not-started checklist and confidence

1. Not started — D05.1: reconcile exhaustive contracts and bounded feasibility requirements.
2. Not started — D05.2: implement reversible selected-shell environment/prompt mappings.
3. Not started — D05.3: implement five terminal renderers and compatible launch behavior.
4. Not started — D05.4: implement approved multiplexer/workspace mappings.
5. Not started — D05.5: verify five-agent/None presentation and triage preservation.
6. Not started — D05.6: deliver migration/effect evidence and shared integration requests.

Planning confidence: **92/100** for source-grounded scope and preservation requirements.
Native compatibility, foundation API details and user decisions remain unverified; implementation feasibility is not certified.

## Planning handoff

Workstream: D05 — Terminal workspace and agents.
Supplied source baseline: `610a18bac374e7e2ffd0bcb2d99b026131deedbc`; branch `feat/harmonize-visual-design`; not independently verified with Git.
Repository mutations: none; no files written, edited, installed, activated, staged or committed.
Inspected sources: complete master and F01–F04 drafts; scoped catalog/setup; Bash/Fish, Kitty/Alacritty/Zellij/Starship files; launch/triage helpers; agent/selection docs; named shell tests and focused triage Python tests.
Validation performed: read/grep/find/ls source inspection, option/contract comparison and existing-versus-proposed path checks.
Validation omitted: test execution, Git status, installed/upstream version probes, screenshots, native session/hardware effects and rollback execution.
Residual risks: unresolved decisions, provisional contracts, native theme/attach gaps, shell override migration, Starship adoption and security-sensitive dispatch compatibility.
Canonical destination: `plans/planned/desktop-harmonization/D05-terminal-workspace-agents.md`; parent alone reconciles and writes canonical documentation.