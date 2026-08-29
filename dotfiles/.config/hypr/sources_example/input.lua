local apps = require("sources.app_variables")

hl.config({
    input = {
        kb_layout = "ch",
        kb_variant = "de_nodeadkeys",
        kb_model = "",
        kb_options = "numpad:pc",
        kb_rules = "",
        numlock_by_default = true,
        follow_mouse = 1,
        sensitivity = 0.0,
        accel_profile = "flat",
        force_no_accel = true,
        scroll_factor = 0.5,
        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.device({
    name = apps.mouse,
    sensitivity = 0,
})
