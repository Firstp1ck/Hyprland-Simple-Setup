local apps = require("sources.app_variables")

hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd([[hyprctl keyword input:kb_numlock true && date "+%Y-%m-%d %H:%M:%S" > /tmp/numlock-set]])
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")

    -- Start hyprpaper through Hyprland, then apply the wallpaper after its IPC initializes.
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("sleep 1; " .. apps.hyprscripts .. "/change_wallpaper.sh")

    hl.exec_cmd("wl-clip-persist --clipboard regular")
    hl.exec_cmd("wl-clipboard-history -t")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("hyprctl setcursor " .. apps.cursor .. " 24")
    hl.exec_cmd([[sleep 1; "$HOME/.config/waybar/scripts/waybar_launch.sh"]])
    hl.exec_cmd("sleep 1; " .. apps.hyprscripts .. "/Startup_check.sh")

    hl.exec_cmd(apps.editor, { workspace = "1 silent" })
    hl.exec_cmd(apps.browser, { workspace = "2 silent" })
    hl.exec_cmd("systemctl --user start app-org.kde.xwaylandvideobridge@autostart.service")

    -- Optional extras. setup.sh enables these only when their dependencies exist.
    -- hl.exec_cmd("swaync")
    -- hl.exec_cmd("nm-applet --indicator")
    -- hl.exec_cmd("pypr")
    -- hl.exec_cmd(apps.hyprscripts .. "/fix-dolphin.sh")
    -- hl.exec_cmd("input-remapper-control --command autoload --device " .. apps.mouse)
    -- hl.exec_cmd("hyprsunset")
    -- hl.exec_cmd("blueman-applet")
    -- hl.exec_cmd("blueman-tray")

    -- Workspace 3 terminal examples.
    -- The run-once lock remains held by Kitty and suppresses duplicate start events.
    -- hl.exec_cmd(apps.hyprscripts .. "/run_once.sh kitty-layout kitty --session ~/.config/kitty/my_layout.conf", { workspace = "3 silent" })
    -- hl.exec_cmd("kitty -e zellij -l ~/.config/zellij/layouts/sysmon.kdl", { workspace = "3 silent" })
    -- hl.exec_cmd("alacritty -e zellij -l ~/.config/zellij/layouts/sysmon.kdl", { workspace = "3 silent" })
end)
