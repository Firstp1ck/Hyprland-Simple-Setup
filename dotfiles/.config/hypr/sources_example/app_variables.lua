local home = os.getenv("HOME") or ""

return {
    terminal = "kitty",
    multiplex = "zellij",
    file_manager = "dolphin",
    menu = "wofi --show drun --style " .. home .. "/.config/wofi/menu.css",
    browser = "zen-browser",
    editor = home .. "/.config/hypr/scripts/role_exec.sh gui_editor",
    screenshot = "hyprshot --mode",
    cursor = "rose-pine-hyprcursor",
    color_picker = "hyprpicker --autocopy --format hex",
    calculator = "qalculate-gtk",
    wallpaper = home .. "/Pictures/Wallpapers",
    hyprscripts = home .. "/.config/hypr/scripts",
    calendar = home .. "/.config/hypr/scripts/role_exec.sh calendar",
    wayscripts = home .. "/.config/waybar/scripts",
    mouse = "",
}
