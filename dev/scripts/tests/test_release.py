"""Release prompt tests in disposable terminals, without running release actions."""

import errno
import os
from pathlib import Path
import pty
import select
import shutil
import signal
import tempfile
import time
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "release.fish"
FISH = shutil.which("fish")


@unittest.skipUnless(FISH, "fish is required")
class ReleaseCancellationTests(unittest.TestCase):
    def run_terminal(self, code, prompt, answer):
        with tempfile.TemporaryDirectory(prefix="release-test-") as home:
            pid, fd = pty.fork()
            if pid == 0:
                os.environ.update(HOME=home, TERM="dumb", XDG_CONFIG_HOME=home)
                os.execv(
                    FISH,
                    [
                        FISH,
                        "--no-config",
                        "-c",
                        'source "$argv[1]" --help >/dev/null; or exit 99; ' + code,
                        str(SCRIPT),
                    ],
                )

            output = bytearray()
            sent = False
            status = None
            try:
                deadline = time.monotonic() + 8
                while time.monotonic() < deadline:
                    if select.select([fd], [], [], 0.05)[0]:
                        try:
                            chunk = os.read(fd, 65536)
                        except OSError as error:
                            if error.errno != errno.EIO:
                                raise
                            chunk = b""
                        output.extend(chunk)
                    ready = prompt.encode() in output and (
                        b"read> " in output or prompt == "TEST_COMMAND"
                    )
                    if not sent and ready:
                        time.sleep(0.05)
                        os.write(fd, answer)
                        sent = True
                    done, child_status = os.waitpid(pid, os.WNOHANG)
                    if done:
                        status = child_status
                        break
                self.assertIsNotNone(status, f"Terminal timed out: {output!r}")
                self.assertTrue(sent, f"Prompt not reached: {output!r}")
                return os.waitstatus_to_exitcode(status), output.decode(errors="replace")
            finally:
                if status is None:
                    os.killpg(pid, signal.SIGKILL)
                    os.waitpid(pid, 0)
                os.close(fd)

    def assert_cancelled(self, code, prompt, answer=b"\x03"):
        status, output = self.run_terminal(code, prompt, answer)
        self.assertEqual(status, 130, output)
        self.assertIn("Release cancelled", output)
        self.assertNotIn("CONTINUED", output)

    def test_confirmation_ctrl_c_and_eof(self):
        for answer in (b"\x03", b"\x04"):
            with self.subTest(answer=answer):
                self.assert_cancelled(
                    'confirm_continue "TEST_CONFIRM"; echo CONTINUED',
                    "TEST_CONFIRM",
                    answer,
                )

    def test_confirmation_answers(self):
        for answer, expected in ((b"\r", 0), (b"y\r", 0), (b"n\r", 1)):
            with self.subTest(answer=answer):
                status, output = self.run_terminal(
                    'confirm_continue "TEST_CONFIRM"; exit $status',
                    "TEST_CONFIRM",
                    answer,
                )
                self.assertEqual(status, expected, output)

    def test_wait_ctrl_c_and_eof(self):
        for answer in (b"\x03", b"\x04"):
            with self.subTest(answer=answer):
                self.assert_cancelled(
                    'wait_for_user "TEST_WAIT"; echo CONTINUED', "TEST_WAIT", answer
                )

    def test_wait_enter_continues(self):
        status, output = self.run_terminal(
            'wait_for_user "TEST_WAIT"; echo CONTINUED', "TEST_WAIT", b"\r"
        )
        self.assertEqual(status, 0, output)
        self.assertIn("CONTINUED", output)

    def test_documentation_stops_before_changelog(self):
        self.assert_cancelled(
            'function update_changelog; echo CONTINUED; end; '
            'phase2_documentation 0.7.0 0.7.0; echo CONTINUED',
            "After completing /release-new",
        )

    def test_version_prompt_ctrl_c(self):
        self.assert_cancelled(
            'function check_prerequisites; return 0; end; '
            'function check_preflight; return 0; end; '
            'function get_current_version; echo 0.7.0; end; '
            'main; echo CONTINUED',
            "Enter new version",
        )

    def test_running_command_ctrl_c(self):
        self.assert_cancelled(
            'echo TEST_COMMAND; dry_run_cmd "sleep 30"; echo CONTINUED',
            "TEST_COMMAND",
        )


if __name__ == "__main__":
    unittest.main()
