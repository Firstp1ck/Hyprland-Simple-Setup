"""Mock-only tests for the generic failure-notification agent helper."""

from __future__ import annotations

import fcntl
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1]
ADAPTER = SCRIPTS / "troubleshoot_with_agent.sh"
HELPER = SCRIPTS / "troubleshoot_with_agent.py"


def load_helper():
    spec = importlib.util.spec_from_file_location("troubleshoot_with_agent", HELPER)
    if spec is None or spec.loader is None:
        raise RuntimeError("unable to load helper")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class TroubleshootWithAgentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="hss-agent-triage-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.state = self.root / "state"
        self.bin = self.root / "bin"
        self.cwd = self.home / "dotfiles"
        for path in (self.home, self.state, self.bin, self.cwd):
            path.mkdir(parents=True, exist_ok=True)
        self.notify_events = self.root / "notify.jsonl"
        self.terminal_events = self.root / "terminal.jsonl"
        self.release = self.root / "release"
        self.roles = self.home / "roles.json"
        self.agent = self.stub("pi", "#!/usr/bin/env bash\nexit 99\n")
        self.stub("kitty", self.argv_stub(self.terminal_events))
        self.stub("tmux", "#!/usr/bin/env bash\nexit 98\n")
        self.stub("notify-send", self.notify_stub())
        self.write_roles(agent="pi")
        self.env = {
            "HOME": str(self.home),
            "XDG_STATE_HOME": str(self.state),
            "HSS_ROLES_FILE": str(self.roles),
            "HSS_TRIAGE_CWD": str(self.cwd),
            "PATH": f"{self.bin}:/usr/bin:/bin",
            "PYTHONDONTWRITEBYTECODE": "1",
            "TEST_NOTIFY_EVENTS": str(self.notify_events),
            "TEST_TERMINAL_EVENTS": str(self.terminal_events),
            "TEST_NOTIFY_MODE": "hold",
            "TEST_RELEASE": str(self.release),
        }
        self.addCleanup(self.finish_listeners)

    def stub(self, name: str, content: str) -> Path:
        path = self.bin / name
        path.write_text(content)
        path.chmod(0o755)
        return path

    @staticmethod
    def argv_stub(event_path: Path) -> str:
        return f"""#!/usr/bin/env python3
import json, sys
with open({str(event_path)!r}, 'a') as output:
    output.write(json.dumps(sys.argv[1:]) + '\\n')
"""

    @staticmethod
    def notify_stub() -> str:
        return """#!/usr/bin/env python3
import json, os, sys, time
from pathlib import Path
with open(os.environ['TEST_NOTIFY_EVENTS'], 'a') as output:
    output.write(json.dumps(sys.argv[1:]) + '\\n')
mode = os.environ.get('TEST_NOTIFY_MODE', 'dismiss')
options = sys.argv[1:sys.argv.index('--')] if '--' in sys.argv else sys.argv[1:]
if mode == 'reject-action' and any(arg.startswith('--action=') for arg in options):
    sys.exit(4)
if mode == 'hold':
    deadline = time.monotonic() + 8
    while not Path(os.environ['TEST_RELEASE']).exists():
        if time.monotonic() > deadline:
            sys.exit(90)
        time.sleep(0.01)
elif mode == 'action':
    print('troubleshoot')
"""

    def write_roles(self, agent: str | None) -> None:
        primary = None
        executable_map = {}
        if agent is not None:
            executable = {
                "pi": "pi",
                "opencode": "opencode",
                "claude-code": "claude",
                "codex-cli": "codex",
                "cursor-cli": "cursor-agent",
            }[agent]
            primary = {"package": agent, "executable": executable, "binary_paths": []}
            executable_map[agent] = str(self.bin / executable)
        self.roles.write_text(
            json.dumps(
                {
                    "schema_version": 2,
                    "roles": {
                        "agent": primary,
                        "terminal": {"package": "kitty", "executable": "kitty", "args": []},
                    },
                    "selected": {"agent": []},
                    "agent_executables": executable_map,
                }
            )
        )

    def roles_with_multiplexers(self, primary: str, selected: list[str]) -> dict[str, object]:
        entries = {
            "tmux": {"package": "tmux", "executable": "tmux", "args": []},
            "zellij": {"package": "zellij", "executable": "zellij", "args": []},
            "herdr-bin": {"package": "herdr-bin", "executable": "herdr", "args": []},
        }
        roles = json.loads(self.roles.read_text())
        roles["roles"]["multiplexer"] = entries[primary]
        roles["selected"]["multiplexer"] = [entries[package] for package in selected]
        return roles

    def run_adapter(self, *extra: str, **environment: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(ADAPTER), "--source", "Startup_check.sh", "--title", "Startup failure", "--body", "A component failed", *extra],
            env={**self.env, **environment},
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=5,
        )

    def incident_paths(self) -> list[Path]:
        directory = self.state / "hyprland-simple-setup/agent-triage"
        return list(directory.glob("incident-*.json")) if directory.exists() else []

    def wait_for(self, predicate, message: str, timeout: float = 5) -> None:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(0.01)
        self.fail(message)

    @staticmethod
    def json_lines(path: Path) -> list[object]:
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def finish_listeners(self):
        self.release.touch()
        deadline = time.monotonic() + 3
        while self.incident_paths() and time.monotonic() < deadline:
            time.sleep(0.01)
        for path in self.incident_paths():
            path.unlink()

    def test_none_uses_plain_notification_and_creates_no_incident(self):
        self.write_roles(agent=None)
        result = self.run_adapter(TEST_NOTIFY_MODE="dismiss")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.json_lines(self.notify_events)
        self.assertEqual(len(calls), 1)
        self.assertFalse(any(value.startswith("--action") for value in calls[0]))
        self.assertEqual(self.incident_paths(), [])
        self.assertFalse(self.terminal_events.exists())

    def test_failed_action_notification_falls_back_once_without_agent_dispatch(self):
        result = self.run_adapter(
            '--title=--wait', '--body=--action=literal-body',
            '--urgency', 'critical', '--app-name', 'HSS', '--icon', 'dialog-warning',
            '--hint', 'string:test:value', TEST_NOTIFY_MODE='reject-action',
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.wait_for(lambda: len(self.json_lines(self.notify_events)) == 2, 'plain fallback did not arrive')
        self.wait_for(lambda: not self.incident_paths(), 'failed notification left evidence behind')
        calls = self.json_lines(self.notify_events)
        self.assertEqual(calls[1], [
            '--urgency=critical', '--app-name=HSS', '--icon=dialog-warning',
            '--hint=string:test:value', '--', '--wait', '--action=literal-body',
        ])
        self.assertFalse(self.terminal_events.exists())

    def test_dismissal_does_not_repost_or_dispatch(self):
        result = self.run_adapter(TEST_NOTIFY_MODE='dismiss')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.wait_for(lambda: self.notify_events.exists() and not self.incident_paths(), 'dismissal not cleaned up')
        self.assertEqual(len(self.json_lines(self.notify_events)), 1)
        self.assertFalse(self.terminal_events.exists())

    def test_unreadable_incident_falls_back_but_expiry_is_quiet(self):
        helper = load_helper()
        command = ['notify-send', '--action=troubleshoot=Troubleshoot', '--wait', '--', 'failure', 'body']
        with mock.patch.dict(os.environ, self.env, clear=True):
            directory = helper.state_directory()
            helper.ensure_private_directory(directory)
            invalid = directory / 'incident-invalid.json'
            helper.write_private(invalid, '{"schema":99}')
            with mock.patch.object(helper.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)) as run, mock.patch.object(helper, 'dispatch') as dispatch:
                self.assertEqual(helper.listen(invalid, command), 0)
                run.assert_called_once()
                self.assertEqual(run.call_args.args[0], ['notify-send', '--', 'failure', 'body'])
                dispatch.assert_not_called()
            expired = directory / 'incident-expired-notification.json'
            helper.write_private(expired, '{"schema":1}')
            old = time.time() - helper.RETENTION_SECONDS - 1
            os.utime(expired, (old, old))
            with mock.patch.object(helper.subprocess, 'run') as run:
                self.assertEqual(helper.listen(expired, command), 0)
                run.assert_not_called()
            self.assertFalse(expired.exists())

    def test_waiting_action_preserves_metadata_and_freezes_private_snapshot(self):
        log = self.root / "app.log"
        log.write_text("original diagnostic\npassword=hunter2\n")
        result = self.run_adapter(
            "--log", str(log), "--urgency", "critical", "--app-name", "HSS", "--icon", "dialog-warning", "--replace-id", "42", "--expire-time", "0", "--hint", "string:test:value"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.wait_for(lambda: self.notify_events.exists(), "notification did not start")
        call = self.json_lines(self.notify_events)[0]
        self.assertIn("--action=troubleshoot=Troubleshoot with Pi", call)
        for option in ("--urgency=critical", "--app-name=HSS", "--icon=dialog-warning", "--replace-id=42", "--expire-time=0", "--hint=string:test:value"):
            self.assertIn(option, call)
        snapshot = self.incident_paths()[0]
        incident = json.loads(snapshot.read_text())
        self.assertIn("original diagnostic", incident["log"]["tail"])
        self.assertNotIn("hunter2", incident["log"]["tail"])
        self.assertEqual(snapshot.stat().st_mode & 0o777, 0o600)
        self.assertEqual(snapshot.parent.stat().st_mode & 0o777, 0o700)

    def test_click_prefers_new_tmux_session_inside_selected_terminal(self):
        result = self.run_adapter(TEST_NOTIFY_MODE="action")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.wait_for(lambda: self.terminal_events.exists(), "terminal was not launched")
        args = self.json_lines(self.terminal_events)[0]
        self.assertIn("-e", args)
        command = args[args.index("-e") + 1 :]
        self.assertEqual(Path(command[0]).name, "tmux")
        self.assertEqual(command[1:3], ["new-session", "-s"])
        self.assertRegex(command[3], r"^hss-triage-[0-9a-f]+$")
        self.assertIn("--run-incident", command)
        self.assertEqual(len(self.incident_paths()), 1, "handoff must remain until the runner claims it")

    def test_detached_environment_keeps_only_desktop_and_handoff_variables(self):
        helper = load_helper()
        desktop = {
            "HOME": str(self.home), "PATH": str(self.bin), "LANG": "en_US.UTF-8",
            "LC_CTYPE": "en_US.UTF-8", "TERM": "xterm-256color",
            "DISPLAY": ":1", "WAYLAND_DISPLAY": "wayland-1",
            "XDG_RUNTIME_DIR": str(self.root / "runtime"),
            "XDG_STATE_HOME": str(self.state), "XDG_CONFIG_HOME": str(self.home / ".config"),
            "DBUS_SESSION_BUS_ADDRESS": "unix:path=/run/user/1000/bus",
            "HSS_ROLES_FILE": str(self.roles), "HSS_TRIAGE_CWD": str(self.cwd),
        }
        excluded = dict.fromkeys((
            "OPENAI_API_KEY", "ANTHROPIC_API_KEY", "AWS_SECRET_ACCESS_KEY",
            "AWS_SESSION_TOKEN", "GITHUB_TOKEN", "SUDO_PASSWORD", "SUDO_ASKPASS",
            "SSH_AUTH_SOCK", "HTTP_PROXY", "CUSTOM_CREDENTIAL", "UNRELATED_VALUE",
            "LD_PRELOAD", "PYTHONPATH", "BASH_ENV", "NODE_OPTIONS",
            "TMUX", "TMUX_PANE", "ZELLIJ", "ZELLIJ_SESSION_NAME", "HERDR_SOCKET",
        ), "synthetic-sensitive-value")
        with mock.patch.dict(os.environ, desktop | excluded, clear=True):
            self.assertEqual(helper.detached_environment(), desktop)

    def test_dispatch_filters_environment_for_every_destination(self):
        helper = load_helper()
        incident = {"nonce": "abc", "agent": {"label": "Pi"}}
        self.stub("zellij", "#!/bin/sh\nexit 0\n")
        self.stub("herdr", "#!/bin/sh\nexit 0\n")
        for primary in ("tmux", "zellij", "herdr-bin", None):
            roles = self.roles_with_multiplexers(primary or "tmux", [primary] if primary else [])
            responses = [
                {"type": "session_snapshot"},
                {"type": "workspace_created", "workspace": {"workspace_id": "new"}, "root_pane": {"pane_id": "new"}},
                {"type": "ok"}, {"type": "ok"},
            ]
            with self.subTest(primary=primary), mock.patch.dict(os.environ, self.env | {"SUDO_PASSWORD": "synthetic"}, clear=True), mock.patch.object(helper, "read_roles", return_value=roles), mock.patch.object(helper, "run_herdr", side_effect=responses) as herdr, mock.patch.object(helper.subprocess, "Popen") as spawn:
                helper.dispatch(Path("/snapshot"), incident)
                environments = [call.args[2] for call in herdr.call_args_list]
                environments += [call.kwargs["env"] for call in spawn.call_args_list]
                self.assertTrue(environments)
                for environment in environments:
                    self.assertNotIn("SUDO_PASSWORD", environment)
                    self.assertEqual(environment["HOME"], str(self.home))

    def test_incident_runner_refilters_environment_from_existing_multiplexer(self):
        helper = load_helper()
        with mock.patch.dict(os.environ, self.env | {"AWS_SESSION_TOKEN": "synthetic", "TMUX": "old-server"}, clear=True):
            directory = helper.state_directory()
            helper.ensure_private_directory(directory)
            path = directory / "incident-env.json"
            helper.write_private(path, json.dumps({
                "schema": 1, "nonce": "abc",
                "agent": {"id": "pi", "label": "Pi", "executable": str(self.agent)},
            }))
            with mock.patch.object(helper.os, "geteuid", return_value=1000), mock.patch.object(helper.os, "chdir"), mock.patch.object(helper.os, "execvpe") as execute:
                helper.run_incident(path, "abc")
            execute.assert_called_once()
            environment = execute.call_args.args[2]
            self.assertNotIn("AWS_SESSION_TOKEN", environment)
            self.assertNotIn("TMUX", environment)
            self.assertEqual(environment["PWD"], str(self.cwd))
            self.assertEqual(environment["HOME"], str(self.home))

    def test_log_bounds_redaction_and_unsafe_inputs(self):
        helper = load_helper()
        log = self.root / "large.log"
        log.write_text("x" * (40 * 1024) + "\x1b[31mred\x1b[0m\nAuthorization: Bearer abc\n")
        captured = helper.snapshot_log(str(log))
        self.assertEqual(captured["status"], "captured")
        self.assertLessEqual(len(captured["tail"].encode()), helper.MAX_LOG_BYTES + 64)
        self.assertNotIn("abc", captured["tail"])
        self.assertNotIn("\x1b", captured["tail"])
        fifo = self.root / "events.log"
        os.mkfifo(fifo)
        self.assertEqual(helper.snapshot_log(str(fifo))["status"], "rejected non-regular file")
        link = self.root / "link.log"
        link.symlink_to(log)
        self.assertEqual(helper.snapshot_log(str(link))["status"], "unreadable or unsafe")
        self.assertEqual(helper.snapshot_log(str(self.root / "api-token.log"))["status"], "rejected credential-like path")

    def test_agent_commands_are_explicit_read_only_or_plan_modes(self):
        helper = load_helper()
        expected = {
            "pi": ["--tools", "read,grep,find,ls"],
            "opencode": ["--agent", "plan", "--prompt"],
            "claude-code": ["--permission-mode", "plan"],
            "codex-cli": ["--sandbox", "read-only"],
            "cursor-cli": ["--mode", "ask"],
        }
        for agent_id, prefix in expected.items():
            with self.subTest(agent=agent_id):
                command = helper.agent_command({"id": agent_id, "executable": "/agent"}, "frozen prompt")
                self.assertEqual(command[1 : 1 + len(prefix)], prefix)
                self.assertEqual(command[-1], "frozen prompt")
                self.assertFalse(any(value in {"--yolo", "--dangerously-skip-permissions", "--auto"} for value in command))

    def test_claim_is_at_most_once_and_prompt_is_bounded(self):
        helper = load_helper()
        with mock.patch.dict(os.environ, self.env, clear=True):
            directory = helper.state_directory()
            helper.ensure_private_directory(directory)
            path = directory / "incident-test.json"
            incident = {"schema": 1, "nonce": "abc", "body": "x" * 100000}
            helper.write_private(path, json.dumps(incident))
            claimed, loaded = helper.claim_snapshot(path, "abc")
            self.assertEqual(loaded["nonce"], "abc")
            with self.assertRaises(helper.HelperError):
                helper.claim_snapshot(path, "abc")
            with self.assertRaises(helper.HelperError):
                helper.claim_snapshot(claimed, "abc")
            self.assertTrue(claimed.exists())
            prompt = helper.build_prompt(claimed, loaded)
            self.assertLessEqual(len(prompt.encode()), helper.MAX_PROMPT_BYTES)
            helper.safe_remove(claimed)

    def test_selected_multiplexer_order_supports_each_primary_with_multiple_choices(self):
        helper = load_helper()
        expected = {
            "tmux": ["tmux", "zellij", "herdr-bin"],
            "zellij": ["zellij", "tmux", "herdr-bin"],
            "herdr-bin": ["herdr-bin", "tmux", "zellij"],
        }
        for primary, order in expected.items():
            with self.subTest(primary=primary):
                roles = self.roles_with_multiplexers(primary, ["herdr-bin", "zellij", "tmux"])
                self.assertEqual(helper.selected_multiplexers(roles), order)

    def test_new_metadata_excludes_installed_but_unselected_multiplexers(self):
        helper = load_helper()
        roles = self.roles_with_multiplexers("tmux", ["tmux"])
        terminal = {"package": "kitty", "executable": str(self.bin / "kitty")}
        incident = {"nonce": "abc", "agent": {"label": "Pi"}}
        available = {"zellij", "herdr", "kitty"}
        with mock.patch.dict(os.environ, self.env, clear=True), mock.patch.object(helper, "read_roles", return_value=roles), mock.patch.object(helper, "resolve_terminal", return_value=terminal), mock.patch.object(helper, "working_directory", return_value=self.cwd), mock.patch.object(helper.shutil, "which", side_effect=lambda name, path=None: str(self.bin / name) if name in available else None), mock.patch.object(helper, "run_herdr") as run, mock.patch.object(helper, "spawn_terminal") as spawn:
            destination = helper.dispatch(Path("/snapshot"), incident)
        self.assertEqual(destination, "terminal")
        run.assert_not_called()
        self.assertNotIn("zellij", spawn.call_args.args[1])

    def test_missing_primary_uses_next_selected_multiplexer(self):
        helper = load_helper()
        roles = self.roles_with_multiplexers("tmux", ["tmux", "zellij", "herdr-bin"])
        terminal = {"package": "kitty", "executable": str(self.bin / "kitty")}
        incident = {"nonce": "abc", "agent": {"label": "Pi"}}
        available = {"zellij", "herdr", "kitty"}
        with mock.patch.dict(os.environ, self.env, clear=True), mock.patch.object(helper, "read_roles", return_value=roles), mock.patch.object(helper, "resolve_terminal", return_value=terminal), mock.patch.object(helper, "working_directory", return_value=self.cwd), mock.patch.object(helper.shutil, "which", side_effect=lambda name, path=None: str(self.bin / name) if name in available else None), mock.patch.object(helper, "run_herdr") as run, mock.patch.object(helper, "spawn_terminal") as spawn:
            destination = helper.dispatch(Path("/snapshot"), incident)
        self.assertEqual(destination, "Zellij")
        self.assertEqual(Path(spawn.call_args.args[1][0]).name, "zellij")
        run.assert_not_called()

    def test_malformed_present_metadata_falls_back_to_plain_terminal(self):
        helper = load_helper()
        terminal = {"package": "kitty", "executable": str(self.bin / "kitty")}
        incident = {"nonce": "abc", "agent": {"label": "Pi"}}
        malformed_values = [
            self.roles_with_multiplexers("tmux", []),
            self.roles_with_multiplexers("tmux", ["zellij"]),
            self.roles_with_multiplexers("tmux", ["tmux"]),
            self.roles_with_multiplexers("tmux", ["tmux"]),
        ]
        malformed_values[2]["roles"]["multiplexer"]["args"] = ["arbitrary"]
        malformed_values[3]["roles"]["multiplexer"]["executable"] = "untrusted-mux"
        for value in (None, [], {}, 1, True):
            for location in ("primary", "selected"):
                roles = self.roles_with_multiplexers("tmux", ["tmux"])
                if location == "primary":
                    roles["roles"]["multiplexer"] = {"package": value, "executable": "tmux", "args": []}
                else:
                    roles["selected"]["multiplexer"] = [{"package": value, "executable": "tmux", "args": []}]
                malformed_values.append(roles)
        for roles in malformed_values:
            with self.subTest(roles=roles), mock.patch.dict(os.environ, self.env, clear=True), mock.patch.object(helper, "read_roles", return_value=roles), mock.patch.object(helper, "resolve_terminal", return_value=terminal), mock.patch.object(helper, "working_directory", return_value=self.cwd), mock.patch.object(helper.shutil, "which", side_effect=lambda name, path=None: str(self.bin / name)), mock.patch.object(helper, "run_herdr") as run, mock.patch.object(helper, "spawn_terminal") as spawn:
                self.assertEqual(helper.dispatch(Path("/snapshot"), incident), "terminal")
                self.assertEqual(spawn.call_args.args[1][0], str(helper.Path(helper.__file__).resolve()))
                run.assert_not_called()

    def test_legacy_metadata_preserves_availability_order(self):
        helper = load_helper()
        roles = json.loads(self.roles.read_text())
        incident = {"nonce": "abc", "agent": {"label": "Pi"}}
        with mock.patch.dict(os.environ, self.env, clear=True), mock.patch.object(helper, "read_roles", return_value=roles), mock.patch.object(helper.shutil, "which", side_effect=lambda name, path=None: None if name in {"tmux", "zellij", "herdr"} else str(self.bin / name)), mock.patch.object(helper, "spawn_terminal") as spawn:
            destination = helper.dispatch(Path("/snapshot"), incident)
        self.assertEqual(destination, "terminal")
        spawn.assert_called_once()

    def test_herdr_probe_failure_falls_through_before_mutation(self):
        helper = load_helper()
        roles = self.roles_with_multiplexers("herdr-bin", ["tmux", "herdr-bin"])
        terminal = {"package": "kitty", "executable": str(self.bin / "kitty")}
        incident = {"nonce": "abc", "agent": {"label": "Pi"}}
        with mock.patch.dict(os.environ, self.env, clear=True), mock.patch.object(helper, "read_roles", return_value=roles), mock.patch.object(helper, "resolve_terminal", return_value=terminal), mock.patch.object(helper, "working_directory", return_value=self.cwd), mock.patch.object(helper.shutil, "which", side_effect=lambda name, path=None: str(self.bin / name)), mock.patch.object(helper, "run_herdr", side_effect=helper.HelperError("probe failed")) as run, mock.patch.object(helper, "spawn_terminal") as spawn:
            self.assertEqual(helper.dispatch(Path("/snapshot"), incident), "tmux")
        self.assertEqual(run.call_args.args[1], ["api", "snapshot"])
        self.assertEqual(Path(spawn.call_args.args[1][0]).name, "tmux")

    def test_zellij_and_herdr_use_new_incident_surfaces(self):
        helper = load_helper()
        terminal = {"package": "kitty", "executable": str(self.bin / "kitty")}
        incident = {"nonce": "abc", "agent": {"label": "Pi"}}
        zellij_roles = self.roles_with_multiplexers("zellij", ["zellij"])
        base_patches = (
            mock.patch.object(helper, "read_roles", return_value=zellij_roles),
            mock.patch.object(helper, "resolve_terminal", return_value=terminal),
            mock.patch.object(helper, "working_directory", return_value=self.cwd),
        )
        with mock.patch.dict(os.environ, self.env, clear=True), base_patches[0], base_patches[1], base_patches[2], mock.patch.object(helper.shutil, "which", side_effect=lambda name, path=None: str(self.bin / name) if name == "zellij" else None), mock.patch.object(helper, "spawn_terminal") as spawn:
            self.assertEqual(helper.dispatch(Path("/snapshot"), incident), "Zellij")
            command = spawn.call_args.args[1]
            self.assertEqual(Path(command[0]).name, "zellij")
            self.assertEqual(command[1:3], ["attach", "-c"])
            self.assertIn("--run-incident", command)

        responses = [
            {"type": "session_snapshot"},
            {"type": "workspace_created", "workspace": {"workspace_id": "new:workspace"}, "root_pane": {"pane_id": "new:pane"}},
            {"type": "ok"},
            {"type": "workspace_info"},
        ]
        herdr_roles = self.roles_with_multiplexers("herdr-bin", ["herdr-bin"])
        with mock.patch.dict(os.environ, self.env, clear=True), mock.patch.object(helper, "read_roles", return_value=herdr_roles), mock.patch.object(helper, "resolve_terminal", return_value=terminal), mock.patch.object(helper, "working_directory", return_value=self.cwd), mock.patch.object(helper.shutil, "which", side_effect=lambda name, path=None: str(self.bin / name) if name == "herdr" else None), mock.patch.object(helper, "run_herdr", side_effect=responses) as run, mock.patch.object(helper, "spawn_terminal") as spawn:
            self.assertEqual(helper.dispatch(Path("/snapshot"), incident), "Herdr")
        self.assertEqual(run.call_args_list[0].args[1], ["api", "snapshot"])
        self.assertEqual(run.call_args_list[1].args[1][:2], ["workspace", "create"])
        pane_run = run.call_args_list[2].args[1]
        self.assertEqual(pane_run[:3], ["pane", "run", "new:pane"])
        self.assertIn("--run-incident", pane_run[3])
        self.assertNotIn("Frozen evidence", pane_run[3])
        self.assertEqual(run.call_args_list[3].args[1], ["workspace", "focus", "new:workspace"])
        spawn.assert_not_called()

    def test_provider_secret_names_and_raw_tokens_are_redacted(self):
        helper = load_helper()
        for name in ("OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GITHUB_TOKEN", "AWS_SECRET_ACCESS_KEY"):
            with self.subTest(name=name):
                result = helper.sanitize_text(name + '=synthetic-value', 512)
                self.assertIn('[REDACTED]', result)
                self.assertNotIn('synthetic-value', result)
        result = helper.sanitize_text('HTTP_AUTHORIZATION: Bearer synthetic-value', 512)
        self.assertNotIn('synthetic-value', result)
        token = 'sk-proj-' + 'x' * 32
        self.assertNotIn(token, helper.sanitize_text('failure with ' + token, 512))
        for filename in ('.env', '.env.local', '.npmrc', 'auth.json'):
            self.assertEqual(helper.snapshot_log(str(self.root / filename))['status'], 'rejected credential-like path')

    def test_expired_and_oversized_snapshots_cannot_be_consumed(self):
        helper = load_helper()
        with mock.patch.dict(os.environ, self.env, clear=True):
            directory = helper.state_directory()
            helper.ensure_private_directory(directory)
            expired = directory / 'incident-expired.json'
            helper.write_private(expired, json.dumps({'schema': 1, 'nonce': 'abc'}))
            old = time.time() - helper.RETENTION_SECONDS - 1
            os.utime(expired, (old, old))
            with self.assertRaises(helper.HelperError):
                helper.claim_snapshot(expired, 'abc')
            large = directory / 'incident-large.json'
            helper.write_private(large, 'x' * (helper.MAX_INCIDENT_BYTES + 1))
            with self.assertRaises(helper.HelperError):
                helper.load_snapshot(large)
            helper.safe_remove(expired)
            helper.safe_remove(large)

    def test_herdr_workspace_mutation_failure_does_not_fall_back(self):
        helper = load_helper()
        roles = self.roles_with_multiplexers("herdr-bin", ["herdr-bin", "zellij"])
        terminal = {"package": "kitty", "executable": str(self.bin / "kitty")}
        incident = {"schema": 1, "nonce": "abc", "agent": {"label": "Pi"}}
        responses = [
            {"type": "session_snapshot"},
            subprocess.TimeoutExpired(["herdr", "workspace", "create"], 15),
        ]
        with mock.patch.dict(os.environ, self.env, clear=True), mock.patch.object(helper, "read_roles", return_value=roles), mock.patch.object(helper, "resolve_terminal", return_value=terminal), mock.patch.object(helper, "working_directory", return_value=self.cwd), mock.patch.object(helper.shutil, "which", side_effect=lambda name, path=None: str(self.bin / name) if name in {"herdr", "zellij"} else None), mock.patch.object(helper, "run_herdr", side_effect=responses) as run, mock.patch.object(helper, "spawn_terminal") as spawn:
            with self.assertRaises(helper.DispatchUncertain):
                helper.dispatch(Path("/snapshot"), incident)
        self.assertEqual(run.call_count, 2)
        spawn.assert_not_called()

    def test_ambiguous_herdr_dispatch_retains_evidence_without_fallback(self):
        helper = load_helper()
        incident = {'schema': 1, 'nonce': 'abc', 'agent': {'label': 'Pi'}}
        terminal = {'package': 'kitty', 'executable': str(self.bin / 'kitty')}
        responses = [
            {'type': 'session_snapshot'},
            {'type': 'workspace_created', 'workspace': {'workspace_id': 'new:workspace'}, 'root_pane': {'pane_id': 'new:pane'}},
            subprocess.TimeoutExpired(['herdr', 'pane', 'run'], 15),
        ]
        with mock.patch.dict(os.environ, self.env, clear=True):
            directory = helper.state_directory()
            helper.ensure_private_directory(directory)
            path = directory / 'incident-uncertain.json'
            helper.write_private(path, json.dumps(incident))
            roles = self.roles_with_multiplexers('herdr-bin', ['herdr-bin', 'zellij'])
            with mock.patch.object(helper, 'read_roles', return_value=roles), mock.patch.object(helper, 'resolve_terminal', return_value=terminal), mock.patch.object(helper, 'working_directory', return_value=self.cwd), mock.patch.object(helper.shutil, 'which', side_effect=lambda name, path=None: str(self.bin / name) if name in {'herdr', 'zellij'} else None), mock.patch.object(helper, 'run_herdr', side_effect=responses) as run, mock.patch.object(helper, 'spawn_terminal') as spawn:
                with self.assertRaises(helper.DispatchUncertain):
                    helper.dispatch(path, incident)
                self.assertEqual(run.call_count, 3)
                spawn.assert_not_called()
            clicked = subprocess.CompletedProcess(['notify-send'], 0, stdout='troubleshoot\n')
            with mock.patch.object(helper.subprocess, 'run', return_value=clicked), mock.patch.object(helper, 'dispatch', side_effect=helper.DispatchUncertain('uncertain')) as dispatch, mock.patch.object(helper, 'feedback'):
                self.assertEqual(helper.listen(path, ['notify-send']), 1)
                dispatch.assert_called_once()
            self.assertTrue(path.exists())
            helper.safe_remove(path)

    def test_detached_listener_does_not_inherit_source_lock(self):
        lock_path = self.root / "source.lock"
        descriptor = os.open(lock_path, os.O_RDWR | os.O_CREAT, 0o600)
        fcntl.flock(descriptor, fcntl.LOCK_EX)
        process = subprocess.Popen(
            [str(ADAPTER), "--source", "source", "--title", "Failure", "--body", "failed"],
            env=self.env,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            pass_fds=(descriptor,),
        )
        _, stderr = process.communicate(timeout=3)
        self.assertEqual(process.returncode, 0, stderr)
        os.close(descriptor)
        probe = os.open(lock_path, os.O_RDWR)
        try:
            fcntl.flock(probe, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            self.fail("detached listener retained an inherited lock")
        finally:
            os.close(probe)

    def test_listener_timeout_is_finite_and_removes_snapshot(self):
        helper = load_helper()
        with mock.patch.dict(os.environ, self.env, clear=True):
            directory = helper.state_directory()
            helper.ensure_private_directory(directory)
            path = directory / "incident-timeout.json"
            helper.write_private(path, json.dumps({"schema": 1, "nonce": "abc"}))
            with mock.patch.object(
                helper.subprocess,
                "run",
                side_effect=subprocess.TimeoutExpired(["notify-send"], helper.LISTENER_TIMEOUT_SECONDS),
            ) as run:
                self.assertEqual(helper.listen(path, ["notify-send"]), 1)
            self.assertGreater(run.call_args.kwargs["timeout"], helper.LISTENER_TIMEOUT_SECONDS - 2)
            self.assertLessEqual(run.call_args.kwargs["timeout"], helper.LISTENER_TIMEOUT_SECONDS)
            self.assertFalse(path.exists())

    def test_retention_caps_incidents_and_removes_expired_files(self):
        helper = load_helper()
        directory = self.state / "hyprland-simple-setup/agent-triage"
        directory.mkdir(parents=True, mode=0o700)
        now = time.time()
        for index in range(55):
            path = directory / f"incident-{index}.json"
            path.write_text("{}")
            os.chmod(path, 0o600)
            os.utime(path, (now - index, now - index))
        old = directory / "claimed-old.json"
        old.write_text("{}")
        os.chmod(old, 0o600)
        os.utime(old, (now - helper.RETENTION_SECONDS - 1,) * 2)
        helper.prune_incidents(directory, now)
        self.assertFalse(old.exists())
        self.assertLessEqual(len(list(directory.glob("*.json"))), helper.MAX_INCIDENTS - 1)


if __name__ == "__main__":
    unittest.main()
