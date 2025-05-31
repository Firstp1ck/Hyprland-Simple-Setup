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
import subprocess
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
    
    def parse_hyprctl_binds(self) -> List[Dict[str, Union[str, int]]]:
        """Parse keybinds from hyprctl command output."""
        try:
            if not os.path.exists('/usr/bin/hyprctl'):
                self.logger.error("hyprctl not found at /usr/bin/hyprctl")
                raise FileNotFoundError("hyprctl not found. Please make sure Hyprland is installed.")
            
            self.logger.info("Executing hyprctl binds command")
            result = subprocess.run(['hyprctl', 'binds'], capture_output=True, text=True)
            if result.returncode != 0:
                self.logger.error(f"hyprctl command failed with return code {result.returncode}: {result.stderr}")
                raise subprocess.CalledProcessError(result.returncode, 'hyprctl', result.stderr)
            
            if not result.stdout.strip():
                self.logger.error("No keybinds found in hyprctl output")
                raise ValueError("No keybinds found. Please check your Hyprland configuration.")
            
            binds = []
            current_bind = {}
            
            self.logger.info("Parsing hyprctl output")
            for line in result.stdout.split('\n'):
                line = line.strip()
                if not line:
                    if current_bind and ('key' in current_bind or 'keycode' in current_bind) and 'description' in current_bind and current_bind['description']:
                        binds.append(current_bind)
                    current_bind = {}
                    continue
                
                if ':' in line:
                    key, value = line.split(':', 1)
                    key = key.strip()
                    value = value.strip()
                    
                    if key == 'modmask' and value != '0':
                        current_bind['modmask'] = int(value)
                    elif key == 'key' and value != '0':
                        if value.startswith('mouse:'):
                            mouse_code = int(value.split(':')[1])
                            current_bind['key'] = KeybindsConfig.MOUSE_MAP.get(mouse_code, f"Mouse {mouse_code}")
                        else:
                            current_bind['key'] = value
                    elif key == 'keycode' and value != '0':
                        current_bind['key'] = self.get_keycode_name(value)
                    elif key == 'description':
                        current_bind['description'] = value
            
            if current_bind and ('key' in current_bind or 'keycode' in current_bind) and 'description' in current_bind and current_bind['description']:
                binds.append(current_bind)
            
            if not binds:
                self.logger.error("No valid keybinds found after parsing")
                raise ValueError("No valid keybinds found in Hyprland configuration.")
            
            self.logger.info(f"Successfully parsed {len(binds)} keybinds")
            self.binds = binds
            return binds
            
        except Exception as e:
            self.logger.error(f"Error parsing keybinds: {str(e)}", exc_info=True)
            return []
    
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
                mod = self.data.get_modifier_name(bind.get('modmask', 0))
                key = bind.get('key', '')
                keybind = f"{mod} + {key}" if mod else key
                description = bind.get('description', '')
                
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
        # Parse keybinds
        binds = self.data.parse_hyprctl_binds()
        if not binds:
            return
        
        # Populate the tree
        self.ui.populate_tree()
        
        # Run the UI
        self.ui.run()

if __name__ == "__main__":
    app = KeybindsApp()
    app.run()
