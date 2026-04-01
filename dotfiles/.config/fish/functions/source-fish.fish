# Sources all Fish configuration files in ~/.config/fish, ~/.config/fish/conf.d, ~/.config/fish/functions, and ~/.config/fish/completions; notifies on success
function source-fish
    for dir in ~/.config/fish ~/.config/fish/conf.d ~/.config/fish/functions ~/.config/fish/completions
        for file in $dir/*.fish
            if test -f $file
                source $file
            end
        end
    end
    if set -q DISPLAY; or set -q WAYLAND_DISPLAY
        if type -q notify-send
            notify-send "All Fish config files reloaded!"
        end
    else
        echo "All Fish config files reloaded!"
    end
end
