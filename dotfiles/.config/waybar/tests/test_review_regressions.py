"""Stub-only regressions for brightness controls and Waybar JSONC startup."""

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[4]
SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"


class WaybarReviewTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="hss-waybar-review-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.home = self.root / "home"
        self.config = self.home / ".config/waybar/config.jsonc"
        self.config.parent.mkdir(parents=True)
        self.events = self.root / "events.jsonl"
        self.env = {
            "HOME": str(self.home), "PATH": f"{self.bin}:/usr/bin:/bin",
            "EVENTS": str(self.events), "BUSES": "12 27", "CURRENT": "40",
            "PYTHONDONTWRITEBYTECODE": "1",
        }
        self.stub("ddcutil", '''#!/usr/bin/env python3
import json, os, sys
with open(os.environ['EVENTS'], 'a') as output:
    output.write(json.dumps(['ddcutil', *sys.argv[1:]]) + '\\n')
if sys.argv[1:] == ['detect']:
    for bus in os.environ['BUSES'].split():
        print('  I2C bus: /dev/i2c-' + bus)
elif 'getvcp' in sys.argv:
    print('VCP 10 C ' + os.environ['CURRENT'] + ' 100')
''')
        for name in ("pkexec", "waybar", "notify-send"):
            self.stub(name, '''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
with open(os.environ['EVENTS'], 'a') as output:
    output.write(json.dumps([Path(sys.argv[0]).name, *sys.argv[1:]]) + '\\n')
''')
        self.stub("gdbus", "#!/bin/sh\nexit 0\n")

    def stub(self, name, content):
        path = self.bin / name
        path.write_text(content)
        path.chmod(0o755)

    def calls(self, name):
        calls = [json.loads(line) for line in self.events.read_text().splitlines()] if self.events.exists() else []
        return [call for call in calls if call[0] == name]

    def run_script(self, name, *arguments, **environment):
        return subprocess.run(
            ["bash", str(SCRIPTS / name), *arguments], env=self.env | environment,
            capture_output=True, text=True, timeout=10,
        )

    def test_brightness_autodetects_without_privileged_reload(self):
        result = self.run_script("brightness.sh", "50")
        self.assertEqual(result.returncode, 0, result.stderr)
        writes = [call for call in self.calls("ddcutil") if "setvcp" in call]
        self.assertEqual([call[2] for call in writes], ["12", "27"])
        self.assertEqual(self.calls("pkexec"), [])

    def test_brightness_honors_explicit_and_partial_bus_overrides(self):
        for overrides, expected in (({"BUS1": "31", "BUS2": "42"}, ["31", "42"]),
                                    ({"BUS1": "27"}, ["27", "12"]),
                                    ({"BUS2": "12"}, ["27", "12"])):
            with self.subTest(overrides=overrides):
                self.events.write_text("")
                result = self.run_script("brightness.sh", "50", **overrides)
                self.assertEqual(result.returncode, 0, result.stderr)
                writes = [call for call in self.calls("ddcutil") if "setvcp" in call]
                self.assertEqual([call[2] for call in writes], expected)

    def test_brightness_handles_single_and_missing_monitors(self):
        result = self.run_script("brightness.sh", BUSES="12")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "40/?")
        self.events.write_text("")
        result = self.run_script("brightness.sh", BUSES="")
        self.assertEqual(result.stdout.strip(), "?/?")
        self.assertEqual(self.calls("ddcutil"), [["ddcutil", "detect"]])
        result = self.run_script("brightness.sh", "50", BUSES="")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls("pkexec"), [])

    def test_brightness_reload_requires_opt_in(self):
        result = self.run_script("brightness.sh", "+5", ENABLE_I2C_DEV_RELOAD="1", BUSES="12")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.calls("pkexec")), 1)
        writes = [call for call in self.calls("ddcutil") if "setvcp" in call]
        self.assertEqual(len(writes), 1)
        self.assertEqual(writes[0][-1], "45")

    def test_brightness_clamps_relative_adjustments_and_rejects_invalid_inputs(self):
        for delta, current, expected in (("+10", "95", "100"), ("-10", "5", "0"), ("+08", "40", "48")):
            with self.subTest(delta=delta):
                self.events.write_text("")
                result = self.run_script("brightness.sh", delta, BUSES="12", CURRENT=current)
                self.assertEqual(result.returncode, 0, result.stderr)
                writes = [call for call in self.calls("ddcutil") if "setvcp" in call]
                self.assertEqual(writes[0][-1], expected)
        for arguments, environment in ((("bad",), {}), (("50",), {"BUS1": "not-a-bus"})):
            with self.subTest(arguments=arguments, environment=environment):
                self.events.write_text("")
                self.assertNotEqual(self.run_script("brightness.sh", *arguments, **environment).returncode, 0)
                self.assertFalse(any("setvcp" in call for call in self.calls("ddcutil")))
                self.assertEqual(self.calls("pkexec"), [])

    def test_launcher_accepts_jsonc_and_role_updater_output_without_rewriting(self):
        spec = importlib.util.spec_from_file_location("waybar_roles", ROOT / "scripts/lib/update-waybar-roles.py")
        updater = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(updater)
        source = '''{ // custom layout
 "clock": {"format": "https://example.org/a/*literal*/",},
 "text": "escaped quote \\\" // still a string", /* block comment */
 "modules-left": ["clock",],
}'''
        for text in (source, "[" + source + ",]", updater.update_document(source), '{"clock":{}}'):
            with self.subTest(text=text):
                self.events.write_text("")
                self.config.write_text(text)
                result = self.run_script("waybar_launch.sh")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.calls("waybar"), [["waybar", "-c", str(self.config)]])
                self.assertEqual(self.config.read_text(), text)

    def test_launcher_rejects_missing_malformed_and_scalar_configs(self):
        for text in (None, '{"clock": invalid}', '{/* unterminated', '"scalar"', '{"a": 1,,}'):
            with self.subTest(text=text):
                self.events.write_text("")
                if text is None:
                    self.config.unlink(missing_ok=True)
                else:
                    self.config.write_text(text)
                result = self.run_script("waybar_launch.sh")
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.calls("waybar"), [])
                self.assertEqual(len(self.calls("notify-send")), 1)


if __name__ == "__main__":
    unittest.main()
