hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 5,
        border_size = 3,
        col = {
            active_border = { colors = { "rgba(a591ffdd)", "rgba(91f8ffaa)" }, angle = 70 },
            inactive_border = "rgba(404040aa)",
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
        snap = {
            enabled = true,
            monitor_gap = 20,
            window_gap = 20,
        },
    },
    group = {
        col = {
            border_active = { colors = { "rgba(a591ffdd)", "rgba(91f8ffaa)" }, angle = 70 },
            border_inactive = "rgba(404040aa)",
        },
        groupbar = {
            font_size = 14,
            height = 22,
            scrolling = false,
            gradients = true,
            gradient_rounding = 10,
            indicator_height = 0,
            gaps_in = 10,
            gaps_out = 3,
            text_color = "rgba(ffffffaa)",
            col = {
                active = "rgba(a591ffdd)",
                inactive = "rgba(404040aa)",
            },
        },
    },
    decoration = {
        rounding = 5,
        rounding_power = 5,
        active_opacity = 0.9,
        inactive_opacity = 0.9,
        shadow = {
            enabled = true,
            range = 5,
            render_power = 3,
            color = "rgba(1a1a1aee)",
        },
        blur = {
            enabled = true,
            size = 3,
            passes = 3,
            xray = true,
            popups = true,
            vibrancy = 0.1696,
        },
    },
    animations = {
        enabled = true,
    },
    dwindle = {
        preserve_split = true,
    },
    master = {
        new_status = "master",
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
    },
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
