local home = os.getenv("HOME") or ""

return {
    terminal = "kitty",
    multiplex = "zellij",
    file_manager = "dolphin",
    menu = "wofi --show drun --style " .. home .. "/.config/wofi/menu.css",
    browser = "zen-browser",
    editor = "code --ozone-platform=wayland --enable-features=UseOzonePlatform",
    screenshot = "hyprshot --mode",
    cursor = "rose-pine-hyprcursor",
    color_picker = "hyprpicker --autocopy --format hex",
    calculator = "qalculate-gtk",
    wallpaper = home .. "/Pictures/Wallpapers",
    hyprscripts = home .. "/.config/hypr/scripts",
    calendar = home .. "/.config/hypr/scripts/float_calendar.sh",
    wayscripts = home .. "/.config/waybar/scripts",
    mouse = "",
}
