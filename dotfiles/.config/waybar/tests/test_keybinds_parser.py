#!/usr/bin/env python3
"""Exercise the shipped Lua bindings without a display or Tk installation."""

import logging
import os
from pathlib import Path
import runpy
import tempfile
from types import ModuleType, SimpleNamespace
import unittest
from unittest.mock import patch

WAYBAR = Path(__file__).resolve().parents[1]
BUNDLED_BINDS = WAYBAR.parent / "hypr/sources_example/keybindings.lua"

# Only the parser is exercised here; GUI startup is a separate smoke check.
tk = ModuleType("tkinter")
tk.Event = object
tk.ttk = ModuleType("tkinter.ttk")
with patch.dict("sys.modules", {"tkinter": tk, "tkinter.ttk": tk.ttk}):
    viewer = SimpleNamespace(**runpy.run_path(str(WAYBAR / "scripts/keybinds.py")))


class KeybindsParserTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.data = viewer.KeybindsData.__new__(viewer.KeybindsData)
        self.data.logger = logging.getLogger("keybinds-test")
        self.data.binds = []
        app_vars = patch.object(viewer.KeybindsConfig, "HYPR_APP_VARIABLES_FILE",
                                str(Path(self.temp.name) / "app_variables.lua"))
        app_vars.start()
        self.addCleanup(app_vars.stop)

    def parse_file(self, path):
        with patch.dict(os.environ, {"HYPR_KEYBINDS_LUA": str(path)}):
            return self.data.parse_lua_keybinds()

    def parse(self, text):
        path = Path(self.temp.name) / "keybindings.lua"
        path.write_text(text)
        return self.parse_file(path)

    def test_bundled_config_populates_viewer(self):
        binds = self.parse_file(BUNDLED_BINDS)
        self.assertEqual(len(binds), 78)
        self.assertIn({"keybind": "SUPER + SPACE", "description": "Open Menu"}, binds)
        self.assertIn({"keybind": "SUPER + Enter", "description": "Open Calculator"}, binds)
        self.assertIn({"keybind": "XF86AudioMute", "description": "Mute Volume"}, binds)
        self.assertEqual(sum(b["keybind"] == "SUPER + CTRL + L" for b in binds), 2)
        for number in range(1, 11):
            self.assertIn({"keybind": f"F{number}", "description": f"Open Workspace {number}"}, binds)
            self.assertIn({"keybind": f"SHIFT + F{number}", "description": f"Move to Workspace {number}"}, binds)
        self.assertFalse(any(".." in b["keybind"] for b in binds))

    def test_helper_body_is_not_a_binding(self):
        binds = self.parse('''local function bind(keys, description, dispatcher, flags)
    hl.bind(keys, dispatcher, flags)
end
bind("SUPER + E", "Open editor", hl.dsp.exec_cmd("editor"))
''')
        self.assertEqual(binds, [{"keybind": "SUPER + E", "description": "Open editor"}])

    def test_multiline_helper_and_quoted_concatenation(self):
        binds = self.parse('''bind(
    "SUPER" .. " + " .. "E",
    "Open editor, with " .. "a comma",
    hl.dsp.exec_cmd("editor"),
    { locked = true }
)
''')
        self.assertEqual(binds, [{"keybind": "SUPER + E", "description": "Open editor, with a comma"}])

    def test_legacy_helpers_and_workspace_loop(self):
        binds = self.parse('''local mainMod = "SUPER"
local mainMod2 = "SHIFT"
bind_exec(mainMod, "E", "editor", { description = "Edit files" })
bind_dispatch(mainMod, "Q", "killactive")
hl.bind("SUPER + X", hl.dsp.window.close())
hl.bind("SUPER + N", hl.dsp.no_op())
for i = 1, 10 do
    hl.bind("F" .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(combo(mainMod2, "F" .. i), hl.dsp.window.move({ workspace = i }))
end
''')
        self.assertEqual(len(binds), 23)
        self.assertIn({"keybind": "F10", "description": "Open workspace 10"}, binds)
        self.assertIn({"keybind": "SHIFT + F10", "description": "Move window to workspace 10"}, binds)
        self.assertIn({"keybind": "SUPER + E", "description": "Edit files", "command": "editor"}, binds)
        self.assertIn({"keybind": "SUPER + Q", "description": "Hyprland dispatch: killactive"}, binds)
        self.assertIn({"keybind": "SUPER + X", "description": "Close window"}, binds)

    def test_multiple_loops_expand_once_each(self):
        binds = self.parse('''for workspace = 2, 3 do
    bind("F" .. workspace, "Workspace " .. workspace, hl.dsp.no_op())
end
for n = 4, 5 do
    bind("F" .. n, "Workspace " .. n, hl.dsp.no_op())
end
''')
        self.assertEqual([b["keybind"] for b in binds], ["F2", "F3", "F4", "F5"])

    def test_loop_expansion_is_bounded(self):
        with self.assertLogs("keybinds-test", level="ERROR"):
            self.assertEqual(self.parse('''for workspace = 1, 1000000 do
    bind("F" .. workspace, "Workspace " .. workspace, hl.dsp.no_op())
end
'''), [])


if __name__ == "__main__":
    unittest.main()
