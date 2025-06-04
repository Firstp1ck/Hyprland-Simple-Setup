# Language Settings
set -gx LC_ALL de_CH.UTF-8
set -gx LANG de_CH.UTF-8
set -gx LANGUAGE de_CH:en_US

# Editor and Terminal Settings
set -gx EDITOR nvim
set -gx VISUAL nvim
set -x TERMINAL kitty
set -x TERM kitty
set -gx BROWSER "librewolf"
set -gx MANPAGER "nvim +Man!"

# Path Settings
set -x PATH /usr/local/bin $PATH
set -x PATH $PATH $HOME/go/bin

# Scripts Directory
set -x SCRIPTS_DIR "$HOME/Dokumente/GitHub/Linux-Setup/Scripts:$HOME/Dokumente/GitHub/Open-Linux-Setup/Other:$HOME/.local/scripts:$HOME/.local/share/applications:$HOME/.config/hypr/scripts:$HOME/.config/waybar/scripts"
set -x PATH "$PATH:$SCRIPTS_DIR" 