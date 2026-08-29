local function window_rule(class, effects)
    effects.match = { class = class }
    hl.window_rule(effects)
end

window_rule("hss-scratchpad", { float = true })
window_rule("org.pulseaudio.pavucontrol", { float = true })

window_rule("zen", { workspace = "2 silent" }) -- hss-role:browser-workspace

hl.window_rule({
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

window_rule("xwaylandvideobridge", { opacity = "0.0 override", no_anim = true, no_focus = true, no_blur = true })
window_rule("blueman-manager", { float = true, center = true })
window_rule("nm-connection-editor", { float = true, center = true })
window_rule("org.qbittorrent.qBittorrent", { float = true, center = true })
window_rule("input-remapper-gtk", { float = true, center = true })
window_rule("waypaper", { float = true, center = true })
window_rule("org.kde.filelight", { float = true, center = true })
window_rule("GParted", { float = true })
window_rule("polychromatic", { float = true, center = true })
window_rule("Tk", { float = true, center = true })
window_rule("Tor Browser", { float = true })
hl.window_rule({ match = { class = "python3", title = "Tor Browser Launcher Einstellungen" }, float = true })
window_rule("filezilla", { float = true, center = true, size = { 1330, 800 } })

hl.layer_rule({ match = { namespace = "wofi" }, dim_around = true }) -- hss-role:launcher-layer

window_rule("qalculate-gtk", { float = true })
window_rule("hss-notes", { float = true, center = true })
window_rule("hss-clipboard", { float = true })
window_rule("org.clipgrab.clipgrab", { float = true, center = true })
window_rule("libreoffice-calc", { tile = true })
window_rule("libreoffice-writer", { tile = true })
window_rule("wshowkeys", { float = true })
window_rule("hss-calendar", { float = true })
window_rule("psensor", { float = true, center = true })
window_rule("showmethekey-gtk", { float = true, move = { 100, 100 } })
window_rule("^(conky)$", { float = true, no_focus = true, pin = true, move = { 20, 40 } })
