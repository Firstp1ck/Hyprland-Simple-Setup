if status is-interactive
    # Commands to run in interactive sessions can go here
end

function get_os
    set -l os_info (cat /etc/os-release)
    set -l os_name (string match -r '^NAME="?(.+)"?$' $os_info)[2]
    echo $os_name
end

function fish_prompt
    set_color green
    echo -n (get_os)" "
    set_color normal
    echo -n (pwd)

    set_color yellow
    fish_git_prompt
    set_color normal

    echo -n " > "
end

function vim
    if test -w "$argv[1]" -o ! -e "$argv[1]"
        nvim $argv
    else
        sudoedit $argv
    end
end

set -U fish_greeting ""

# Keybinding Aliases
alias ls='lsd -lh --group-directories-first --color=auto'
alias top='btop'
alias cat='bat'
alias fzf='fzf --bind "enter:execute(vim {})" -m --preview="bat --color=always --style=numbers --line-range=:500 {}"'
alias fd='fd -H --max-depth 4'
alias zj='zellij'
alias grep='grep --color=auto'
alias pacman='sudo pacman'
alias pacup='sudo pacman -Syu'
alias pacin='sudo pacman -S'
alias pacrm='sudo pacman -Rns'
alias rm='rm -i'
alias mv='mv -i'
alias folder_backup='path/to/backup/folder'
alias grub-update='sudo grub-mkconfig -o /boot/grub/grub.cfg'
alias update-grub='sudo grub-mkconfig -o /boot/grub/grub.cfg'
alias uuid='ls -l /dev/disk/by-uuid'
alias mount-check='sudo findmnt --verify --verbose'
alias git-rm-cache='git rm -rf --cached .'
alias search='yay -Ss'
alias apt-search='apt search'

# Alias Function for cat=bat
function cat
    if command -v bat >/dev/null 2>&1
        bat $argv
    else
        command cat $argv
    end
end

# Git prompt configuration
set -g __fish_git_prompt_show_informative_status 1
set -g __fish_git_prompt_showdirtystate 1
set -g __fish_git_prompt_showuntrackedfiles 1
set -g __fish_git_prompt_showupstream informative

# Language Settings (Set your language settings here)
set -gx LC_ALL de_CH.UTF-8
set -gx LANG de_CH.UTF-8
set -gx LANGUAGE de_CH:en_US

set -x fish_history default

# Editor und Visual Terminal View (Add default terminal text editor)
set -e EDITOR
set -x VISUAL 
set -x EDITOR 

set -x TERMINAL kitty
set -x TERM kitty

set -x PATH /usr/local/bin $PATH

# Ollama Settings
# set -x PATH $PATH /opt/rocm/bin /opt/rocm/opencl/bin
set -x OLLAMA_USE_GPU 1
set -x OLLAMA_MAX_LOADED_MODELS 2
set -x OLLAMA_NUM_PARALLEL 4
set -x OLLAMA_MAX_QUEUE 512
set -x OLLAMA_MODELS /mnt/SSD_NVME_4TB/Ollama/
set -gx HSA_OVERRIDE_GFX_VERSION 11.0.1
set -gx ROCR_VISIBLE_DEVICES 0
# set -x OLLAMA_HOST 0.0.0.0
# chmod -R 775 $OLLAMA_MODELS

# Less Pager Reader
export LESS='-R --quit-if-one-screen --ignore-case --LONG-PROMPT --RAW-CONTROL-CHARS --HILITE-UNREAD --tabs=4 --no-init --window=-4'

# fzf Config Exports
set -gx FZF_DEFAULT_OPTS "--bind 'delete:execute(mkdir -p ~/.trash && mv {} ~/.trash/)+reload(find .)'"

# Wayland for OBS (Screen Recording)
set -x QT_QPA_PLATFORMTHEME qt5ct
set -x QT_QPA_PLATFORM wayland

# Hyprland DBus
set -x DBUS_SESSION_BUS_ADDRESS "unix:path=$XDG_RUNTIME_DIR/bus"
set -x XDG_CURRENT_DESKTOP Hyprland

# Vim Mode
fish_vi_key_bindings