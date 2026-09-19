# Startup checks and optional agent triage

Hyprland startup checks cover components that are expected to remain running: the wallpaper and idle services, clipboard helpers, and the selected notification, bar, and optional dock roles. Browsers, editors, launchers, and other clients a user may close are not treated as startup failures. Process checks are limited to the current user and shared `nwg-panel` bar/dock selections are checked once.

Numlock, wallpaper, and optional Dolphin setup publish markers beneath the current Hyprland session's private runtime directory. The checker never consumes or removes another session's markers. All markers and process checks share one bounded polling deadline so delayed startup does not create serial multi-minute waits. Setup migrates only the exact former shipped numlock command; custom commands are preserved and must publish their own current-session readiness marker.

## Troubleshoot action

When startup fails, the notification offers **Troubleshoot with _agent_** only if the configured primary coding agent is usable. `None`, missing legacy agent metadata, or a missing executable still produces the ordinary failure notification and makes no agent call.

Nothing is sent to an agent until the user clicks the action. The helper freezes a bounded tail of the supplied log before it detaches, strips terminal controls, and performs best-effort redaction of obvious credentials. It rejects symlinks, non-regular files, files owned by another user, and credential-like paths. Incident directories use mode `0700`, files use `0600`, and notification listeners expire after 24 hours. Count/age pruning runs when another incident is published; it is not a scheduled purge. An unconsumed or uncertain handoff can therefore remain on disk until the next publication/cleanup. Expired snapshots cannot launch an agent.

A click shares the frozen notification and diagnostic evidence with the selected agent and its configured provider. Redaction is best-effort and is **not** a secrecy guarantee. Embedded diagnostics are untrusted data, not instructions.

Dispatch order is deterministic:

1. a new unique tmux session, if tmux is installed;
2. a new unique Zellij session, if Zellij is installed;
3. a new Herdr workspace and its returned root pane, if the default Herdr API responds compatibly;
4. the selected primary terminal.

The helper does not install a multiplexer or reuse, mutate, or kill an existing session. It does not retry after an ambiguous launch that might already have run. The private incident runner claims each snapshot at most once and passes the prompt as one argument.

The selected agent starts in its supported read-only or planning mode: Pi receives only `read,grep,find,ls`; Claude uses plan permission mode; Codex uses the read-only sandbox; OpenCode uses its plan agent; and Cursor uses ask mode. These CLI and prompt restrictions are not a universal operating-system sandbox. The helper never logs in, chooses a model, bypasses permissions, performs an automatic fix, or runs as root.
