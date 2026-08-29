#!/usr/bin/env python3

"""
Hyprland Keybinds Viewer

This module provides a graphical interface to view and manage Hyprland keybinds.
It allows users to:
- View all configured keybinds in a categorized tree view
- Search through keybinds
- Mark keybinds as favorites
- View tooltips with detailed information
- Filter and expand/collapse categories

The interface is built using tkinter and follows a modern, dark theme design.
"""

import tkinter as tk
from tkinter import ttk
import re
import json
import os
import logging
from pathlib import Path
from typing import Dict, List, Set, Tuple, Optional, Any, Union, Callable

class KeybindsConfig:
    """Configuration and constants for the Keybinds application."""
    
    # File paths
    FAVORITES_FILE: str = os.path.expanduser("~/.config/waybar/keybinds_favorites.json")
    LOG_FILE: str = os.path.expanduser("~/.config/waybar/scripts/keybinds.log")
    HYPR_KEYBINDS_FILE: str = os.path.expanduser("~/.config/hypr/sources/keybindings.lua")
    HYPR_APP_VARIABLES_FILE: str = os.path.expanduser("~/.config/hypr/sources/app_variables.lua")
    
    # Theme colors
    BG_COLOR: str = "#2E3440"  # Dark background
    FG_COLOR: str = "#ECEFF4"  # Light text
    ACCENT_COLOR: str = "#88C0D0"  # Accent color
    TREE_BG: str = "#3B4252"  # Slightly lighter background for tree
    TREE_SELECTED: str = "#4C566A"  # Selection color
    
    # Font configuration
    DEFAULT_FONT: Tuple[str, int] = ('JetBrains Mono', 10)
    HEADING_FONT: Tuple[str, int, str] = ('JetBrains Mono', 10, 'bold')
    TITLE_FONT: Tuple[str, int, str] = ('JetBrains Mono', 16, 'bold')
    
    # Categories and their patterns
    CATEGORIES: Dict[str, List[str]] = {
        "Favorites": [],  # Special category for favorites
        "Workspace": ["move to workspace", "open workspace", "workspace"],
        "Screenshot": ["screenshot", "screen capture", "screen shot", "take screenshot"],
        "Window Management": ["move window", "resize window", "focus window", "window", "monitor", "toggle"],
        "Application Launcher": ["launch", "open", "start", "exec"],
        "System Controls": ["exit", "kill", "quit", "lock", "logout", "shutdown", "reboot"],
        "Media Controls": ["volume", "audio", "media", "play", "pause", "next", "previous"],
        "Miscellaneous": []  # Default category for unmatched items
    }
    
    # Keycode mappings
    KEYCODE_MAP: Dict[int, str] = {
        # Numbers and symbols
        10: "1", 11: "2", 12: "3", 13: "4", 14: "5", 15: "6",
        16: "7", 17: "8", 18: "9", 19: "0", 20: "-", 21: "=",
        49: "§",  # Section symbol
        
        # Letters (top row)
        24: "q", 25: "w", 26: "e", 27: "r", 28: "t", 29: "y",
        30: "u", 31: "i", 32: "o", 33: "p", 34: "[", 35: "]",
        
        # Letters (middle row)
        38: "a", 39: "s", 40: "d", 41: "f", 42: "g", 43: "h",
        44: "j", 45: "k", 46: "l", 47: ";", 48: "'",
        
        # Letters (bottom row)
        52: "z", 53: "x", 54: "c", 55: "v", 56: "b", 57: "n",
        58: "m", 59: ",", 60: ".", 61: "/",
        
        # Special keys
        9: "Escape", 23: "Tab", 36: "Enter", 65: "Space",
        22: "Backspace", 104: "Enter", 107: "Insert", 118: "Delete",
        
        # Navigation keys
        110: "Home", 115: "End",
        111: "Up", 116: "Down", 113: "Left", 114: "Right",
        
        # Modifier keys
        66: "Shift", 37: "Control", 64: "Alt", 133: "Super",
        
        # Function keys
        67: "F1", 68: "F2", 69: "F3", 70: "F4",
        71: "F5", 72: "F6", 73: "F7", 74: "F8",
        75: "F9", 76: "F10", 95: "F11", 96: "F12"
    }
    
    # Modifier mappings
    MODIFIERS: Dict[int, str] = {
        1: "Shift", 2: "Caps", 4: "Ctrl", 8: "Alt",
        16: "Mod2", 32: "Mod3", 64: "Super", 128: "Mod5"
    }
    
    # Mouse button mappings
    MOUSE_MAP: Dict[int, str] = {
        272: "Left Click",
        273: "Right Click"
    }

class KeybindsData:
    """Handles data operations for keybinds."""
    
    def __init__(self):
        self._setup_logging()
        self.favorites: Set[str] = self.load_favorites()
        self.binds: List[Dict[str, Union[str, int]]] = []
    
    def _setup_logging(self) -> None:
        """Configure logging for the application."""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.StreamHandler(),
                logging.FileHandler(KeybindsConfig.LOG_FILE)
            ]
        )
        self.logger = logging.getLogger('keybinds')
        self.logger.info("Logging initialized")
    
    def load_favorites(self) -> Set[str]:
        """Load favorites from the favorites file."""
        try:
            if os.path.exists(KeybindsConfig.FAVORITES_FILE):
                self.logger.info(f"Loading favorites from {KeybindsConfig.FAVORITES_FILE}")
                with open(KeybindsConfig.FAVORITES_FILE, 'r') as f:
                    favorites = set(json.load(f))
                    self.logger.info(f"Loaded {len(favorites)} favorites")
                    return favorites
            self.logger.info("No favorites file found, returning empty set")
            return set()
        except Exception as e:
            self.logger.error(f"Error loading favorites from {KeybindsConfig.FAVORITES_FILE}: {str(e)}", exc_info=True)
            return set()
    
    def save_favorites(self) -> None:
        """Save favorites to the favorites file."""
        try:
            self.logger.info(f"Saving {len(self.favorites)} favorites to {KeybindsConfig.FAVORITES_FILE}")
            os.makedirs(os.path.dirname(KeybindsConfig.FAVORITES_FILE), exist_ok=True)
            with open(KeybindsConfig.FAVORITES_FILE, 'w') as f:
                json.dump(list(self.favorites), f)
            self.logger.info("Favorites saved successfully")
        except Exception as e:
            self.logger.error(f"Error saving favorites to {KeybindsConfig.FAVORITES_FILE}: {str(e)}", exc_info=True)
    
    def parse_lua_keybinds(self) -> List[Dict[str, Union[str, int]]]:
        """Parse keybinds directly from the Hyprland Lua config."""
        try:
            keybinds_path = Path(os.environ.get("HYPR_KEYBINDS_LUA", KeybindsConfig.HYPR_KEYBINDS_FILE)).expanduser()
            if not keybinds_path.exists():
                raise FileNotFoundError(f"Hyprland Lua keybind config not found: {keybinds_path}")

            self.logger.info(f"Parsing Hyprland Lua keybinds from {keybinds_path}")
            lua_text = keybinds_path.read_text()
            lua_vars = self._load_lua_symbols(lua_text)
            binds: List[Dict[str, Union[str, int]]] = []

            binds.extend(self._parse_lua_for_loops(lua_text, lua_vars))

            for statement in self._collect_lua_bind_statements(lua_text):
                bind = self._parse_lua_bind_statement(statement, lua_vars)
                if bind:
                    binds.append(bind)

            if not binds:
                raise ValueError(f"No valid keybinds found in {keybinds_path}")

            self.binds = binds
            self.logger.info(f"Successfully parsed {len(binds)} Lua keybinds")
            return binds
        except Exception as e:
            self.logger.error(f"Error parsing Lua keybinds: {str(e)}", exc_info=True)
            return []

    def parse_hyprctl_binds(self) -> List[Dict[str, Union[str, int]]]:
        """Compatibility wrapper: the viewer now reads Hyprland's Lua config."""
        return self.parse_lua_keybinds()

    def _load_lua_symbols(self, keybinds_text: str) -> Dict[str, str]:
        """Load simple local symbols and app variables used by keybindings.lua."""
        symbols = {"HOME": str(Path.home())}

        app_vars_path = Path(KeybindsConfig.HYPR_APP_VARIABLES_FILE).expanduser()
        if app_vars_path.exists():
            app_text = app_vars_path.read_text()
            for name, value in re.findall(r'\b([A-Za-z_][\w]*)\s*=\s*"([^"]*)"', app_text):
                symbols[f"vars.{name}"] = value
            if "vars.hyprscripts" not in symbols:
                symbols["vars.hyprscripts"] = str(Path.home() / ".config/hypr/scripts")
            if "vars.wayscripts" not in symbols:
                symbols["vars.wayscripts"] = str(Path.home() / ".config/waybar/scripts")
            if "vars.calendar" not in symbols and "vars.hyprscripts" in symbols:
                symbols["vars.calendar"] = f"{symbols['vars.hyprscripts']}/float_calendar.sh"

        for name, value in re.findall(r'\blocal\s+([A-Za-z_][\w]*)\s*=\s*"([^"]*)"', keybinds_text):
            symbols[name] = value
        for name, expr in re.findall(r'^\s*local\s+([A-Za-z_][\w]*)\s*=\s*(.+)$', keybinds_text, re.M):
            if name not in symbols and not expr.startswith(("rawget", "false", "true", "function")):
                symbols[name] = self._resolve_lua_expr(expr, symbols)

        return symbols

    def _collect_lua_bind_statements(self, lua_text: str) -> List[str]:
        """Collect top-level bind_exec, bind_dispatch, and hl.bind statements."""
        statements = []
        current: List[str] = []
        depth = 0
        collecting = False

        in_function = False
        for raw_line in lua_text.splitlines():
            stripped = raw_line.strip()
            if stripped.startswith("local function"):
                in_function = True
                continue
            if in_function:
                if stripped == "end" and raw_line.startswith("end"):
                    in_function = False
                continue
            if stripped.startswith("--"):
                continue
            if not collecting and not stripped.startswith(("bind_exec(", "bind_dispatch(", "hl.bind(")):
                continue

            collecting = True
            current.append(raw_line)
            depth += self._paren_delta(raw_line)
            if depth <= 0:
                statement = "\n".join(current)
                if '"F" .. i' not in statement and 'F" .. i' not in statement:
                    statements.append(statement)
                current = []
                depth = 0
                collecting = False

        return statements

    def _paren_delta(self, text: str) -> int:
        """Return net parenthesis delta while ignoring quoted Lua strings."""
        delta = 0
        quote = None
        i = 0
        in_long = False
        while i < len(text):
            ch = text[i]
            nxt = text[i:i + 2]
            if in_long:
                if nxt == "]]":
                    in_long = False
                    i += 2
                    continue
            elif quote:
                if ch == "\\":
                    i += 2
                    continue
                if ch == quote:
                    quote = None
            elif nxt == "[[":
                in_long = True
                i += 2
                continue
            elif ch in ('"', "'"):
                quote = ch
            elif ch == "(":
                delta += 1
            elif ch == ")":
                delta -= 1
            i += 1
        return delta

    def _parse_lua_bind_statement(self, statement: str, symbols: Dict[str, str]) -> Optional[Dict[str, Union[str, int]]]:
        statement = statement.strip()
        if statement.startswith("bind_exec("):
            args = self._split_lua_args(statement[len("bind_exec("):-1])
            if len(args) >= 3:
                keybind = self._format_keybind(self._resolve_lua_expr(args[0], symbols), self._resolve_lua_expr(args[1], symbols))
                command = self._resolve_lua_expr(args[2], symbols)
                description = self._description_from_flags(args[3:]) or self._describe_command(command)
                return {"keybind": keybind, "description": description, "command": command}
        elif statement.startswith("bind_dispatch("):
            args = self._split_lua_args(statement[len("bind_dispatch("):-1])
            if len(args) >= 3:
                keybind = self._format_keybind(self._resolve_lua_expr(args[0], symbols), self._resolve_lua_expr(args[1], symbols))
                dispatcher = self._resolve_lua_expr(args[2], symbols)
                dispatch_args = self._resolve_lua_expr(args[3], symbols) if len(args) > 3 else ""
                return {"keybind": keybind, "description": self._describe_dispatcher(dispatcher, dispatch_args)}
        elif statement.startswith("hl.bind("):
            args = self._split_lua_args(statement[len("hl.bind("):-1])
            if len(args) >= 2:
                if "hl.dsp.no_op" in args[1]:
                    return None
                keybind = self._normalize_keybind(self._resolve_lua_expr(args[0], symbols))
                description = self._description_from_flags(args[2:]) or self._describe_lua_action(args[1])
                return {"keybind": keybind, "description": description}
        return None

    def _parse_lua_for_loops(self, lua_text: str, symbols: Dict[str, str]) -> List[Dict[str, Union[str, int]]]:
        """Expand the simple numbered workspace loop used in keybindings.lua."""
        binds: List[Dict[str, Union[str, int]]] = []
        match = re.search(r'for\s+i\s*=\s*(\d+)\s*,\s*(\d+)\s+do(?P<body>.*?)\nend', lua_text, re.S)
        if not match:
            return binds

        start, end = int(match.group(1)), int(match.group(2))
        body = match.group("body")
        shift = symbols.get("mainMod2", "SHIFT")
        for i in range(start, end + 1):
            if 'hl.dsp.focus({ workspace = i })' in body:
                binds.append({"keybind": f"F{i}", "description": f"Open workspace {i}"})
            if 'hl.dsp.window.move({ workspace = i })' in body:
                binds.append({"keybind": f"{shift} + F{i}", "description": f"Move window to workspace {i}"})
        return binds

    def _split_lua_args(self, text: str) -> List[str]:
        args = []
        start = 0
        depth = 0
        quote = None
        in_long = False
        i = 0
        while i < len(text):
            ch = text[i]
            nxt = text[i:i + 2]
            if in_long:
                if nxt == "]]":
                    in_long = False
                    i += 2
                    continue
            elif quote:
                if ch == "\\":
                    i += 2
                    continue
                if ch == quote:
                    quote = None
            elif nxt == "[[":
                in_long = True
                i += 2
                continue
            elif ch in ('"', "'"):
                quote = ch
            elif ch in "({[":
                depth += 1
            elif ch in ")}]":
                depth -= 1
            elif ch == "," and depth == 0:
                args.append(text[start:i].strip())
                start = i + 1
            i += 1
        tail = text[start:].strip()
        if tail:
            args.append(tail)
        return args

    def _split_lua_concat(self, expr: str) -> List[str]:
        parts = []
        start = 0
        depth = 0
        quote = None
        i = 0
        while i < len(expr):
            ch = expr[i]
            nxt = expr[i:i + 2]
            if quote:
                if ch == "\\":
                    i += 2
                    continue
                if ch == quote:
                    quote = None
            elif ch in ('"', "'"):
                quote = ch
            elif ch in "({[":
                depth += 1
            elif ch in ")}]":
                depth -= 1
            elif nxt == ".." and depth == 0:
                parts.append(expr[start:i].strip())
                start = i + 2
                i += 2
                continue
            i += 1
        tail = expr[start:].strip()
        if tail:
            parts.append(tail)
        return parts

    def _split_lua_or(self, expr: str) -> Optional[Tuple[str, str]]:
        depth = 0
        quote = None
        i = 0
        while i < len(expr):
            ch = expr[i]
            if quote:
                if ch == "\\":
                    i += 2
                    continue
                if ch == quote:
                    quote = None
            elif ch in ('"', "'"):
                quote = ch
            elif ch in "({[":
                depth += 1
            elif ch in ")}]":
                depth -= 1
            elif depth == 0 and expr[i:i + 4] == " or ":
                return expr[:i].strip(), expr[i + 4:].strip()
            i += 1
        return None

    def _resolve_lua_expr(self, expr: str, symbols: Dict[str, str]) -> str:
        expr = expr.strip()
        while expr.startswith("(") and expr.endswith(")") and self._paren_delta(expr[1:-1]) == 0:
            expr = expr[1:-1].strip()

        if expr.startswith("[[") and expr.endswith("]]"):
            return expr[2:-2]
        if (expr.startswith('"') and expr.endswith('"')) or (expr.startswith("'") and expr.endswith("'")):
            return expr[1:-1]
        if expr.startswith("combo(") and expr.endswith(")"):
            args = self._split_lua_args(expr[len("combo("):-1])
            if len(args) == 2:
                return self._format_keybind(self._resolve_lua_expr(args[0], symbols), self._resolve_lua_expr(args[1], symbols))
        concat = self._split_lua_concat(expr)
        if len(concat) > 1:
            return "".join(self._resolve_lua_expr(part, symbols) for part in concat)
        lua_or = self._split_lua_or(expr)
        if lua_or:
            first, fallback = lua_or
            if first in symbols:
                return symbols[first]
            return self._resolve_lua_expr(fallback, symbols)
        if expr.startswith("os.getenv"):
            return str(Path.home())
        if expr in symbols:
            return symbols[expr]
        return re.sub(r'\s+', ' ', expr)

    def _format_keybind(self, mods: str, key: str) -> str:
        if not mods:
            return self._normalize_keybind(key)
        return self._normalize_keybind(f"{mods} + {key}")

    def _normalize_keybind(self, keybind: str) -> str:
        keybind = keybind.replace("code:104", "Enter")
        keybind = keybind.replace("code:110", "Home")
        keybind = keybind.replace("code:94", "Less")
        keybind = keybind.replace("code:49", "§")
        return re.sub(r'\s*\+\s*', ' + ', keybind).strip()

    def _description_from_flags(self, args: List[str]) -> str:
        joined = "\n".join(args)
        match = re.search(r'description\s*=\s*"([^"]+)"', joined)
        return match.group(1) if match else ""

    def _describe_command(self, command: str) -> str:
        command = command.strip()
        script_match = re.search(r'([^\s/]+)\.sh(?:\s|$)', command)
        if script_match:
            return script_match.group(1).replace("_", " ").replace("-", " ").title()
        if "hyprshot" in command or "satty" in command:
            return "Take screenshot"
        if command.startswith("wpctl set-volume"):
            return "Adjust volume"
        if command.startswith("wpctl set-mute"):
            return "Toggle mute"
        if command.startswith("brightnessctl"):
            return "Adjust brightness"
        if command.startswith("playerctl"):
            return f"Media {command.split(maxsplit=1)[1] if len(command.split()) > 1 else 'control'}"
        if "power_action.sh" in command:
            return command.rsplit(" ", 1)[-1].title()
        return f"Run: {command}"

    def _describe_dispatcher(self, dispatcher: str, args: str = "") -> str:
        suffix = f" {args}" if args else ""
        return f"Hyprland dispatch: {dispatcher}{suffix}"

    def _describe_lua_action(self, action: str) -> str:
        compact = re.sub(r'\s+', ' ', action.strip())
        if "window.close" in compact:
            return "Close window"
        if "fullscreen_state" in compact:
            return "Toggle fullscreen"
        if "window.pseudo" in compact:
            return "Toggle pseudo tiling"
        if "layout(\"togglesplit\")" in compact:
            return "Toggle split layout"
        if "group.toggle" in compact:
            return "Toggle group"
        if "group.next" in compact:
            return "Next group window"
        if "focus({ direction" in compact:
            match = re.search(r'direction\s*=\s*"([^"]+)"', compact)
            return f"Focus {match.group(1)}" if match else "Focus window"
        if "workspace = \"e+1\"" in compact:
            return "Next workspace"
        if "workspace = \"e-1\"" in compact:
            return "Previous workspace"
        if "window.drag" in compact:
            return "Move window with mouse"
        if "window.resize" in compact:
            return "Resize window with mouse"
        if "submap(\"clean\")" in compact or "get_current_submap" in compact:
            return "Toggle clean submap"
        if "exec_cmd" in compact:
            match = re.search(r'exec_cmd\((.*)\)', compact)
            if match:
                return self._describe_command(match.group(1).strip('"'))
        return "Lua action"
    
    def get_modifier_name(self, modmask: int) -> str:
        """Convert a modifier mask value to a human-readable string."""
        active_mods = []
        for value, name in sorted(KeybindsConfig.MODIFIERS.items(), reverse=True):
            if modmask >= value:
                active_mods.append(name)
                modmask -= value
        return " + ".join(active_mods) if active_mods else ""
    
    def get_keycode_name(self, keycode: Union[str, int]) -> str:
        """Convert a keycode to its human-readable name."""
        if isinstance(keycode, str) and keycode.startswith('mouse:'):
            mouse_code = int(keycode.split(':')[1])
            return KeybindsConfig.MOUSE_MAP.get(mouse_code, f"Mouse {mouse_code}")
        return KeybindsConfig.KEYCODE_MAP.get(int(keycode), f"Keycode {keycode}")

class KeybindsUI:
    """Handles the GUI components of the application."""
    
    def __init__(self, data: KeybindsData):
        self.data = data
        self.logger = logging.getLogger('keybinds')  # Use the same logger instance
        self.root = tk.Tk()
        self.root.title("Hyprland Keybinds")
        self._setup_ui()
    
    def _setup_ui(self) -> None:
        """Set up the main UI components."""
        try:
            self.logger.info("Setting up UI components")
            # Configure root window background
            self.root.configure(bg=KeybindsConfig.BG_COLOR)
            
            self._configure_styles()
            self._create_widgets()
            self._setup_bindings()
            self._center_window()
            self.logger.info("UI setup completed successfully")
        except Exception as e:
            self.logger.error(f"Error setting up UI: {str(e)}", exc_info=True)
    
    def _configure_styles(self) -> None:
        """Configure the styles for the UI components."""
        style = ttk.Style()
        style.theme_use('clam')
        
        # Configure Treeview
        style.configure("Treeview",
            background=KeybindsConfig.TREE_BG,
            foreground=KeybindsConfig.FG_COLOR,
            fieldbackground=KeybindsConfig.TREE_BG,
            borderwidth=0,
            font=KeybindsConfig.DEFAULT_FONT)
        
        style.configure("Treeview.Heading",
            background=KeybindsConfig.BG_COLOR,
            foreground=KeybindsConfig.ACCENT_COLOR,
            relief="flat",
            font=KeybindsConfig.HEADING_FONT)
        
        style.map('Treeview',
            background=[('selected', KeybindsConfig.TREE_SELECTED)],
            foreground=[('selected', KeybindsConfig.FG_COLOR)])
        
        # Configure other widgets
        style.configure("TEntry",
            fieldbackground=KeybindsConfig.TREE_BG,
            foreground=KeybindsConfig.FG_COLOR,
            borderwidth=0,
            font=KeybindsConfig.DEFAULT_FONT)
        
        style.configure("TLabel",
            background=KeybindsConfig.BG_COLOR,
            foreground=KeybindsConfig.FG_COLOR,
            font=KeybindsConfig.DEFAULT_FONT)
        
        style.configure("Title.TLabel",
            background=KeybindsConfig.BG_COLOR,
            foreground=KeybindsConfig.ACCENT_COLOR,
            font=KeybindsConfig.TITLE_FONT)
        
        style.configure("TCheckbutton",
            background=KeybindsConfig.BG_COLOR,
            foreground=KeybindsConfig.FG_COLOR,
            font=KeybindsConfig.DEFAULT_FONT)
        
        style.configure("TButton",
            background=KeybindsConfig.TREE_BG,
            foreground=KeybindsConfig.FG_COLOR,
            borderwidth=0,
            font=KeybindsConfig.DEFAULT_FONT)
    
    def _create_widgets(self) -> None:
        """Create and arrange the UI widgets."""
        # Create title frame
        title_frame = tk.Frame(self.root, bg=KeybindsConfig.BG_COLOR)
        title_frame.pack(fill=tk.X, padx=0, pady=(10, 5))
        
        title_label = ttk.Label(title_frame, text="Hyprland Keybinds", style="Title.TLabel")
        title_label.pack(padx=10)
        
        # Create search frame
        search_frame = ttk.Frame(self.root, style="TFrame")
        search_frame.pack(fill=tk.X, padx=10, pady=5)
        
        ttk.Label(search_frame, text="Search:", style="TLabel").pack(side=tk.LEFT, padx=(0, 5))
        self.search_var = tk.StringVar()
        search_entry = ttk.Entry(search_frame, textvariable=self.search_var, style="TEntry")
        search_entry.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 5))
        
        # Create toggle button
        self.toggle_var = tk.BooleanVar(value=False)
        toggle_button = ttk.Checkbutton(search_frame, text="Expand All", variable=self.toggle_var, style="TCheckbutton")
        toggle_button.pack(side=tk.LEFT)
        
        # Create clear favorites button
        clear_favorites_button = ttk.Button(search_frame, text="Clear Favorites", command=self._clear_all_favorites, style="TButton")
        clear_favorites_button.pack(side=tk.LEFT, padx=(10, 0))
        
        # Create main frame
        main_frame = ttk.Frame(self.root, style="TFrame")
        main_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=(0, 10))
        
        # Create Treeview
        self.tree = ttk.Treeview(main_frame, columns=('Keybind', 'Description'), show='tree headings', style="Treeview")
        self.tree.heading('Keybind', text='Keybind')
        self.tree.heading('Description', text='Description')
        
        # Configure column widths
        self.tree.column('Keybind', width=200)
        self.tree.column('Description', width=400)
        
        # Add scrollbar
        scrollbar = ttk.Scrollbar(main_frame, orient=tk.VERTICAL, command=self.tree.yview)
        self.tree.configure(yscrollcommand=scrollbar.set)
        
        # Pack widgets
        self.tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        
        # Create tooltip
        self.tooltip = tk.Toplevel(self.root)
        self.tooltip.withdraw()
        self.tooltip.overrideredirect(True)
        self.tooltip.configure(bg=KeybindsConfig.TREE_BG, bd=1, relief='solid')
        
        self.tooltip_label = ttk.Label(self.tooltip,
            background=KeybindsConfig.TREE_BG,
            foreground=KeybindsConfig.FG_COLOR,
            font=KeybindsConfig.DEFAULT_FONT,
            padding=5,
            wraplength=300)
        self.tooltip_label.pack()
        
        # Create context menu
        self.context_menu = tk.Menu(self.root, tearoff=0,
            bg=KeybindsConfig.TREE_BG,
            fg=KeybindsConfig.FG_COLOR,
            activebackground=KeybindsConfig.TREE_SELECTED,
            activeforeground=KeybindsConfig.FG_COLOR)
        self.context_menu.add_command(label="Toggle Favorite", command=self._toggle_favorite)
    
    def _setup_bindings(self) -> None:
        """Set up event bindings for the UI components."""
        self.tree.bind('<Enter>', lambda e: self._hide_tooltip(e))
        self.tree.bind('<Leave>', self._hide_tooltip)
        self.tree.bind('<Motion>', lambda e: self._show_tooltip(e, self.tree.identify_row(e.y)))
        self.tree.bind("<Button-3>", self._show_context_menu)
        self.tree.bind("<Button-1>", self._on_left_click)
        
        self.search_var.trace('w', self._filter_items)
        self.toggle_var.trace('w', self._toggle_groups)
        
        self.context_menu.bind("<Unmap>", self._on_menu_close)
        self.context_menu.bind("<Escape>", self._on_menu_close)
    
    def _center_window(self) -> None:
        """Center the window on the screen."""
        window_width = 700
        window_height = 600
        screen_width = self.root.winfo_screenwidth()
        screen_height = self.root.winfo_screenheight()
        x = (screen_width - window_width) // 2
        y = (screen_height - window_height) // 2
        self.root.geometry(f"{window_width}x{window_height}+{x}+{y}")
    
    def _show_tooltip(self, event: tk.Event, item: str) -> None:
        """Show tooltip for the given item."""
        try:
            if not item:
                self._hide_tooltip(event)
                return
            
            values = self.tree.item(item)['values']
            text = self.tree.item(item)['text']
            
            if text in KeybindsConfig.CATEGORIES:
                tooltip_text = f"Category: {text}"
            elif values:
                keybind, description = values
                tooltip_text = f"Keybind: {keybind}\nDescription: {description}"
            else:
                self._hide_tooltip(event)
                return
            
            # Check if tooltip window still exists
            if not self.tooltip.winfo_exists():
                self.logger.warning("Tooltip window does not exist, recreating")
                self._create_tooltip()
            
            self.tooltip_label.configure(text=tooltip_text)
            self.tooltip.update_idletasks()
            
            x = event.x_root + 10
            y = event.y_root + 10
            
            screen_width = self.root.winfo_screenwidth()
            screen_height = self.root.winfo_screenheight()
            
            if x + self.tooltip.winfo_width() > screen_width:
                x = screen_width - self.tooltip.winfo_width()
            if y + self.tooltip.winfo_height() > screen_height:
                y = event.y_root - self.tooltip.winfo_height() - 10
            
            self.tooltip.geometry(f"+{x}+{y}")
            self.tooltip.deiconify()
        except Exception as e:
            self.logger.error(f"Error showing tooltip: {str(e)}", exc_info=True)
            self._hide_tooltip(event)
    
    def _hide_tooltip(self, event: Optional[tk.Event] = None) -> None:
        """Hide the tooltip."""
        try:
            if self.tooltip.winfo_exists():
                self.tooltip.withdraw()
        except Exception as e:
            self.logger.error(f"Error hiding tooltip: {str(e)}", exc_info=True)
    
    def _create_tooltip(self) -> None:
        """Create a new tooltip window and label."""
        try:
            self.logger.info("Creating new tooltip window")
            self.tooltip = tk.Toplevel(self.root)
            self.tooltip.withdraw()
            self.tooltip.overrideredirect(True)
            self.tooltip.configure(bg=KeybindsConfig.TREE_BG, bd=1, relief='solid')
            
            self.tooltip_label = ttk.Label(self.tooltip,
                background=KeybindsConfig.TREE_BG,
                foreground=KeybindsConfig.FG_COLOR,
                font=KeybindsConfig.DEFAULT_FONT,
                padding=5,
                wraplength=300)
            self.tooltip_label.pack()
            self.logger.info("Tooltip window created successfully")
        except Exception as e:
            self.logger.error(f"Error creating tooltip: {str(e)}", exc_info=True)
    
    def _show_context_menu(self, event: tk.Event) -> None:
        """Show the context menu."""
        item = self.tree.identify_row(event.y)
        if item:
            # Don't show context menu for category items
            if self.tree.item(item)['text'] in KeybindsConfig.CATEGORIES:
                return
                
            self.tree.selection_remove(self.tree.selection())
            self.tree.selection_add(item)
            self.context_menu.post(event.x_root, event.y_root)
    
    def _on_left_click(self, event: tk.Event) -> None:
        """Handle left click events."""
        item = self.tree.identify_row(event.y)
        if not item:
            return
            
        # Handle category items
        if self.tree.item(item)['text'] in KeybindsConfig.CATEGORIES:
            # Toggle the open/closed state of the category
            self.tree.item(item, open=not self.tree.item(item)['open'])
            return
            
        # Handle regular items
        self.tree.selection_remove(self.tree.selection())
        self.tree.selection_add(item)
    
    def _on_menu_close(self, event: Optional[tk.Event] = None) -> None:
        """Handle menu close events."""
        pass
    
    def _toggle_favorite(self) -> None:
        """Toggle the favorite status of the selected keybind."""
        try:
            selected = self.tree.selection()
            if not selected:
                self.logger.debug("No item selected for favorite toggle")
                return
            
            item = selected[0]
            # Don't allow toggling favorites for category items
            if self.tree.item(item)['text'] in KeybindsConfig.CATEGORIES:
                self.logger.debug("Attempted to toggle favorite on category item")
                return
                
            values = self.tree.item(item)['values']
            if not values:
                self.logger.debug("Selected item has no values")
                return
            
            keybind, description = values
            keybind_id = f"{keybind}|{description}"
            
            if keybind_id in self.data.favorites:
                self.logger.info(f"Removing favorite: {keybind_id}")
                self.data.favorites.remove(keybind_id)
                for fav_item in self.tree.get_children(self.category_items["Favorites"]):
                    if self.tree.item(fav_item)['values'] == values:
                        self.tree.delete(fav_item)
            else:
                self.logger.info(f"Adding favorite: {keybind_id}")
                self.data.favorites.add(keybind_id)
                self.tree.insert(self.category_items["Favorites"], 'end', values=values)
            
            self.data.save_favorites()
        except Exception as e:
            self.logger.error(f"Error toggling favorite: {str(e)}", exc_info=True)
    
    def _clear_all_favorites(self) -> None:
        """Clear all favorites."""
        self.data.favorites.clear()
        self.data.save_favorites()
        for item in self.tree.get_children(self.category_items["Favorites"]):
            self.tree.delete(item)
        self.tree.selection_remove(self.tree.selection())
    
    def _filter_items(self, *args: Any) -> None:
        """Filter items based on the search term."""
        try:
            search_term = self.search_var.get().lower()
            self.logger.debug(f"Filtering items with search term: {search_term}")
            
            for item, parent, _, _ in self.all_items:
                self.tree.detach(item)
            
            matches = 0
            for item, parent, keybind, description in self.all_items:
                if (search_term in keybind.lower() or 
                    search_term in description.lower()):
                    self.tree.reattach(item, parent, 'end')
                    self.tree.item(parent, open=True)
                    matches += 1
            
            self.logger.debug(f"Found {matches} matching items")
        except Exception as e:
            self.logger.error(f"Error filtering items: {str(e)}", exc_info=True)
    
    def _toggle_groups(self, *args: Any) -> None:
        """Toggle expansion of all categories."""
        is_expanded = self.toggle_var.get()
        for category_id in self.category_items.values():
            self.tree.item(category_id, open=is_expanded)
    
    def populate_tree(self) -> None:
        """Populate the tree with keybinds."""
        try:
            self.logger.info("Starting tree population")
            # Create category items
            self.category_items = {}
            for category in KeybindsConfig.CATEGORIES:
                self.category_items[category] = self.tree.insert('', 'end', text=category, open=False)
            
            # Store all items for filtering
            self.all_items = []
            
            # Sort binds into categories
            for bind in self.data.binds:
                if 'keybind' in bind:
                    keybind = str(bind.get('keybind', ''))
                else:
                    mod = self.data.get_modifier_name(bind.get('modmask', 0))
                    key = bind.get('key', '')
                    keybind = f"{mod} + {key}" if mod else key
                description = str(bind.get('description', ''))
                
                # Determine category
                assigned_category = "Miscellaneous"
                for category, patterns in KeybindsConfig.CATEGORIES.items():
                    if any(pattern.lower() in description.lower() for pattern in patterns):
                        assigned_category = category
                        break
                
                # Insert into appropriate category
                item = self.tree.insert(self.category_items[assigned_category], 'end', values=(keybind, description))
                self.all_items.append((item, self.category_items[assigned_category], keybind, description))
                
                # If this is a favorite, also add it to the Favorites category
                keybind_id = f"{keybind}|{description}"
                if keybind_id in self.data.favorites:
                    self.tree.insert(self.category_items["Favorites"], 'end', values=(keybind, description))
            
            self.logger.info(f"Tree populated with {len(self.all_items)} items")
        except Exception as e:
            self.logger.error(f"Error populating tree: {str(e)}", exc_info=True)
    
    def run(self) -> None:
        """Run the application."""
        self.root.mainloop()

class KeybindsApp:
    """Main application class."""
    
    def __init__(self):
        self.data = KeybindsData()
        self.ui = KeybindsUI(self.data)
    
    def run(self) -> None:
        """Run the application."""
        # Parse keybinds from the Hyprland Lua config
        binds = self.data.parse_lua_keybinds()
        if not binds:
            return
        
        # Populate the tree
        self.ui.populate_tree()
        
        # Run the UI
        self.ui.run()

if __name__ == "__main__":
    app = KeybindsApp()
    app.run()
