# Reloads tmux configuration if a tmux server is running, with notification support
function treload
    if tmux ls > /dev/null 2>&1
        tmux source-file ~/.config/tmux/tmux.conf
        if set -q DISPLAY; or set -q WAYLAND_DISPLAY
            if type -q notify-send
                notify-send "Tmux configuration reloaded"
            end
        else
            echo "Tmux configuration reloaded"
        end
    else
        if set -q DISPLAY; or set -q WAYLAND_DISPLAY
            if type -q notify-send
                notify-send "No tmux server running, cannot reload config"
            end
        else
            echo "No tmux server running, cannot reload config"
        end
    end
end