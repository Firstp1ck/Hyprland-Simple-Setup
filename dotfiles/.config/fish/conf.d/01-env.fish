# Language Settings
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

# Script directories
set LOCAL_SCRIPTS $HOME/.local/scripts
set LOCAL_APPLICATIONS $HOME/.local/share/applications
set HYPR_SCRIPTS $HOME/.config/hypr/scripts
set WAYBAR_SCRIPTS $HOME/.config/waybar/scripts

# Combine all script directories
set -x SCRIPTS_DIR_PATH "$LOCAL_SCRIPTS:$LOCAL_APPLICATIONS:$HYPR_SCRIPTS:$WAYBAR_SCRIPTS"
set -x PATH "$PATH:$SCRIPTS_DIR_PATH"

# Make scripts executable
set -l SCRIPTS_DIR_EXE $LOCAL_SCRIPTS $LOCAL_APPLICATIONS $HYPR_SCRIPTS $WAYBAR_SCRIPTS
find $SCRIPTS_DIR_EXE -type f '(' -name '*.sh' -o -name '*.desktop' ')' -exec chmod +x '{}' ';'