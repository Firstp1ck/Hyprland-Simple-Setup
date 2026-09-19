# Coding agents

Coding agents are an optional multi-select application role. The available choices are Pi, OpenCode, Claude Code, Codex CLI, and Cursor CLI. Pi is selected by default. Select any number of agents and mark one selected agent as primary, or choose **None** to disable agent integration. None and later deselection do not uninstall an existing CLI.

## Installation contract

The setup downloads only these fixed HTTPS endpoints:

| Choice | Executable | Official installer | Invocation |
| --- | --- | --- | --- |
| Pi | `pi` | `https://pi.dev/install.sh` | `sh` |
| OpenCode | `opencode` | `https://opencode.ai/install` | `bash --no-modify-path` |
| Claude Code | `claude` | `https://claude.ai/install.sh` | `bash` |
| Codex CLI | `codex` | `https://chatgpt.com/codex/install.sh` | `sh` |
| Cursor CLI | `cursor-agent` | `https://cursor.com/install` | `bash` |

The endpoint, interpreter, arguments, executable, and known user-local path are validated against this allowlist before side effects. Agent IDs never enter pacman, AUR-helper, or `pacman -T` operations. Only prerequisites for selected agents enter the pacman package union. Pi requires `nodejs` and `npm`, and setup verifies Node.js 22.19.0 or newer before invoking its installer.

An existing executable at a registered user-local path or the controlled installer PATH is reused without an upgrade. Otherwise setup downloads the script into the current run's private temporary directory with HTTPS-only redirects, bounded curl timeouts, bounded retries, and default curl configuration disabled for the script download. It then runs the script as the normal user with no controlling terminal, null stdin, a 600-second timeout, and a minimal environment. Setup never passes its sudo password or API-key environment variables to an installer. Pi receives a user-local npm prefix; Codex receives its noninteractive setting.

Installer exit success is not enough: setup resolves and verifies the expected executable afterward. Optional agent installation failures are reported as soft failures and desktop setup continues. Authentication, provider selection, and account setup remain manual; setup does not run an agent, call `--version`, sign in, or store credentials.

## Runtime metadata and PATH

Schema-2 `~/.config/hypr/roles.json` stores the primary choice under `.roles.agent`, all selections under `.selected.agent`, and verified absolute paths under `.agent_executables`. A legacy metadata file without the agent role means agent integration is disabled.

When at least one agent is selected, setup adds `~/.local/bin` and `~/.opencode/bin` to the repository-managed Fish and both Lua/Hyprlang Hyprland environment configurations. It does not rewrite `.bashrc` or `.zshrc`. Consumers should prefer `.agent_executables[agent_id]`, then registered candidate paths and PATH for compatibility with older metadata.

## Security and rollback limits

Official installer scripts are mutable third-party code executed with the user's permissions. The runner removes ambient credentials and bounds execution, but it is not a sandbox and the scripts are not pinned or covered by config-only rollback. The scripts may download additional vendor artifacts and modify their own user-local directories. Review the linked upstream installer before opting in if that trust model is not acceptable.

Dry-run reports each intended reuse/download without downloading or executing a script. Selecting None performs no agent download or installer execution.
