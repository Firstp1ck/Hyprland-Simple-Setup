if status is-interactive
    # Commands to run in interactive sessions can go here
end

set -U fish_greeting ""

# FZF configuration
set -gx FZF_CTRL_T_COMMAND '
    find . -maxdepth 1 -type d ! -name ".*" -printf "%P/\n" | sort
    find . -maxdepth 1 -type f ! -name ".*" -printf "%P\n" | sort
    find . -maxdepth 1 -type d -name ".*" ! -name "." ! -name ".." -printf "%P/\n" | sort
    find . -maxdepth 1 -type f -name ".*" -printf "%P\n" | sort
'

# Keybindings
bind \cl 'clear; commandline -f repaint'

# History
set -x fish_history default

# Vim Mode
fish_vi_key_bindings

# Initialize zoxide
zoxide init fish | source
