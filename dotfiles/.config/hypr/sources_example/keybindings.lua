local apps = require("sources.app_variables")

local main_mod = "SUPER"
local control = "CTRL"
local shift = "SHIFT"
local alt = "ALT"

local enter = "code:104"
local less = "code:94"
local doubles = "code:49"
local home_key = "code:110"

local function bind(keys, description, dispatcher, flags)
    flags = flags or {}
    flags.description = description
    hl.bind(keys, dispatcher, flags)
end

bind(main_mod .. " + SPACE", "Open Menu", hl.dsp.exec_cmd("pkill wofi || " .. apps.menu))
bind(control .. " + Y", "Open Preferred Terminal", hl.dsp.exec_cmd(apps.hyprscripts .. "/term_exec.sh -- " .. apps.multiplex))
bind(main_mod .. " + E", "Open Preferred File Manager", hl.dsp.exec_cmd(apps.file_manager))
bind(main_mod .. " + F", "Open Preferred Browser", hl.dsp.exec_cmd(apps.browser))
bind(main_mod .. " + C", "Open Preferred Editor", hl.dsp.exec_cmd(apps.editor))
bind(main_mod .. " + J", "Open Preferred Color Picker", hl.dsp.exec_cmd(apps.color_picker))
bind(main_mod .. " + K", "Open Preferred Calendar", hl.dsp.exec_cmd(apps.calendar))
bind(main_mod .. " + " .. enter, "Open Calculator", hl.dsp.exec_cmd(apps.calculator))
bind(main_mod .. " + CTRL + W", "Open Waypaper", hl.dsp.exec_cmd("waypaper"))
bind(main_mod .. " + " .. less, "Open Notification Center", hl.dsp.exec_cmd("sleep 0.1 && swaync-client -t -sw"))
bind(main_mod .. " + SHIFT + W", "Open ArchWiki Locally", hl.dsp.exec_cmd(apps.browser .. " /usr/share/doc/arch-wiki/html/en/Table_of_contents.html"))

bind(main_mod .. " + X", "Close Active Window", hl.dsp.window.close())
bind(main_mod .. " + Q", "Toggle Fullscreen", hl.dsp.window.fullscreen_state({ internal = 3, client = 0 }))
bind(main_mod .. " + B", "Toggle Pseudo Layout", hl.dsp.window.pseudo())
bind(main_mod .. " + N", "Toggle Split Layout", hl.dsp.layout("togglesplit"))
bind(main_mod .. " + CTRL + G", "Toggle Window Group", hl.dsp.group.toggle())
bind(alt .. " + TAB", "Cycle Window Group", hl.dsp.group.next())
bind(main_mod .. " + S", "Minimize per Workspace", hl.dsp.exec_cmd(apps.hyprscripts .. "/minimize_per_workspace.sh"))

bind(main_mod .. " + mouse:272", "Move Window", hl.dsp.window.drag(), { mouse = true })
bind(main_mod .. " + mouse:273", "Resize Window", hl.dsp.window.resize(), { mouse = true })

bind(main_mod .. " + CTRL + X", "Toggle Scratchpad Terminal", hl.dsp.exec_cmd("pypr toggle term"))
bind(main_mod .. " + CTRL + V", "Toggle Scratchpad Volume", hl.dsp.exec_cmd("pypr toggle volume"))
bind(main_mod .. " + CTRL + " .. less, "Toggle Keyboard Layout", hl.dsp.exec_cmd(apps.hyprscripts .. "/toggle_keyboardlayouts.sh"))

bind(main_mod .. " + Y", "Take Screenshot of Window", hl.dsp.exec_cmd(apps.screenshot .. " window --raw | satty --filename -"))
bind(main_mod .. " + " .. home_key, "Take Screenshot of Monitor", hl.dsp.exec_cmd(apps.screenshot .. " output --raw | satty --filename -"))
bind(home_key, "Take Screenshot of Region", hl.dsp.exec_cmd(apps.screenshot .. " region --raw | satty --filename -"))

bind(main_mod .. " + H", "Toggle Waybar", hl.dsp.exec_cmd(apps.hyprscripts .. "/toggle_waybar.sh"))
bind(main_mod .. " + V", "Toggle Floating", hl.dsp.exec_cmd(apps.hyprscripts .. "/toggle_floating.sh"))
bind(main_mod .. " + W", "Change Wallpaper", hl.dsp.exec_cmd(apps.hyprscripts .. "/change_wallpaper.sh"))
bind(main_mod .. " + CTRL + S", "Start Hyprsunset", hl.dsp.exec_cmd(apps.hyprscripts .. "/hyprsunset.sh"))
bind(main_mod .. " + CTRL + M", "Start Music Player", hl.dsp.exec_cmd([[hyprctl dispatch exec "[workspace 7 silent] ]] .. apps.terminal .. " -e " .. apps.hyprscripts .. [[/play_music.sh"]]))
bind(main_mod .. " + " .. doubles, "Open Notes", hl.dsp.exec_cmd(apps.hyprscripts .. "/notes.sh"))
bind(main_mod .. " + SHIFT + B", "Toggle Bluetooth", hl.dsp.exec_cmd(apps.hyprscripts .. "/toggle_bluetooth.sh"))
bind(main_mod .. " + CTRL + SPACE", "Open GitHub Repository Menu", hl.dsp.exec_cmd(apps.hyprscripts .. "/repos_wofi.sh"))

bind(main_mod .. " + L", "Lock Screen", hl.dsp.exec_cmd(apps.wayscripts .. "/power_action.sh lock"))
bind(main_mod .. " + M", "Exit Hyprland", hl.dsp.exec_cmd(apps.wayscripts .. "/power_action.sh logout"))
bind(main_mod .. " + O", "Reboot PC", hl.dsp.exec_cmd(apps.wayscripts .. "/power_action.sh reboot"))
bind(main_mod .. " + P", "Shut Down PC", hl.dsp.exec_cmd(apps.wayscripts .. "/power_action.sh shutdown"))

bind(main_mod .. " + left", "Move Focus Left", hl.dsp.focus({ direction = "left" }))
bind(main_mod .. " + right", "Move Focus Right", hl.dsp.focus({ direction = "right" }))
bind(main_mod .. " + up", "Move Focus Up", hl.dsp.focus({ direction = "up" }))
bind(main_mod .. " + down", "Move Focus Down", hl.dsp.focus({ direction = "down" }))

bind(main_mod .. " + CTRL + L", "Disable Global Hyprland Keybinds", hl.dsp.submap("clean"))
hl.define_submap("clean", function()
    bind(main_mod .. " + CTRL + L", "Enable Global Hyprland Keybinds", hl.dsp.submap("reset"))
end)

for workspace = 1, 10 do
    bind("F" .. workspace, "Open Workspace " .. workspace, hl.dsp.focus({ workspace = workspace }))
    bind(shift .. " + F" .. workspace, "Move to Workspace " .. workspace, hl.dsp.window.move({ workspace = workspace }))
end

bind(main_mod .. " + mouse_down", "Go to Next Workspace", hl.dsp.focus({ workspace = "e+1" }))
bind(main_mod .. " + mouse_up", "Go to Previous Workspace", hl.dsp.focus({ workspace = "e-1" }))

local media_flags = { locked = true, repeating = true }
bind("XF86AudioLowerVolume", "Lower Volume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), media_flags)
bind("XF86AudioRaiseVolume", "Raise Volume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
bind("XF86AudioMute", "Mute Volume", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
bind("XF86AudioMicMute", "Mute Microphone", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
bind("XF86MonBrightnessUp", "Increase Brightness", hl.dsp.exec_cmd("brightnessctl s 10%+"), { locked = true, repeating = true })
bind("XF86MonBrightnessDown", "Decrease Brightness", hl.dsp.exec_cmd("brightnessctl s 10%-"), { locked = true, repeating = true })
bind("XF86AudioNext", "Next Song", hl.dsp.exec_cmd("playerctl next"), { locked = true })
bind("XF86AudioPrev", "Previous Song", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
bind("XF86AudioPause", "Pause Audio", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
bind("XF86AudioPlay", "Play Audio", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
bind("XF86AudioPause", "Pause Special Audio", hl.dsp.exec_cmd("echo stop > /tmp/nightfall_control"), { locked = true })
bind("XF86AudioPlay", "Play Special Audio", hl.dsp.exec_cmd("echo toggle > /tmp/nightfall_control"), { locked = true })
