local apps = require("sources.app_variables")

hl.env("HYPRCURSOR_THEME", apps.cursor)
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", apps.cursor)
hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("BROWSER", "zen-browser")
hl.env("PYTHONHTTPSVERIFY", "1")

hl.config({
    debug = {
        disable_logs = false,
    },
})
