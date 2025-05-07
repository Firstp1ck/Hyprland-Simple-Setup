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

# Fish Shell Configuration Script
set -x SCRIPTS_DIR "$HOME/.local/scripts:$HOME/.local/share/applications:$HOME/.config/hypr/scripts"
set -x PATH "$PATH:$SCRIPTS_DIR"

set -gx FZF_CTRL_T_COMMAND '
    find . -maxdepth 1 -type d ! -name ".*" -printf "%P/\n" | sort
    find . -maxdepth 1 -type f ! -name ".*" -printf "%P\n" | sort
    find . -maxdepth 1 -type d -name ".*" ! -name "." ! -name ".." -printf "%P/\n" | sort
    find . -maxdepth 1 -type f -name ".*" -printf "%P\n" | sort
'

if test -d "$SCRIPTS_DIR"
    find "$SCRIPTS_DIR" -type f \( -name "*.sh" -o -name "*.desktop" \) -exec chmod +x {} \;
end

# Keybinding Aliases
# General alias
alias cls='clear'
bind \cl 'clear; commandline -f repaint'
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'
alias cd='z'
alias ls='lsd -lh --group-directories-first --color=auto'
alias top='btop'
alias vi="nvim"
alias vim='nvim'
alias fzf='fzf --bind "enter:execute(vim {})" -m --preview="bat --color=always --style=numbers --line-range=:500 {}"'
alias fd='fd -H --max-depth 4'
alias zj='zellij'

# Pacman/yay/apt alias
alias pcn='sudo pacman'
alias pacman='sudo pacman'
alias pacsy='sudo reflector --verbose --country DE,CH,AT --protocol https --sort rate --latest 20 --download-timeout 6 --save /etc/pacman.d/mirrorlist'
alias pacup='sudo pacman -Syu'
alias pacin='sudo pacman -S'
alias pacrm='sudo pacman -Rns'
alias search='yay -Ss'
alias apt-search='apt search'

# Git alias
alias git-rm-cache='git rm -rf --cached .'
alias gc='git commit -m'
alias ga='git add .'
alias gs='git status'
alias g='git'
alias gp='git push'
alias gl='git pull'
alias git-rm='git restore --staged'

# Grep alias
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# Bootloader alias
alias grub-update='sudo grub-mkconfig -o /boot/grub/grub.cfg'
alias update-grub='sudo grub-mkconfig -o /boot/grub/grub.cfg'
alias uuid='ls -l /dev/disk/by-uuid'
alias mount-check='sudo findmnt --verify --verbose'

# Systemctl alias
alias sysstat='systemctl status'
abbr --add sysen 'systemctl enable'
abbr --add sysdis 'systemctl disable'
abbr --add sysusr 'systemctl --user'

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

## LANGUAGE SETTINGS START
set -gx LC_ALL de_CH.UTF-8
set -gx LANG de_CH.UTF-8
set -gx LANGUAGE de_CH:en_US
## LANGUAGE SETTINGS END

set -x fish_history default

# Editor und Visual Terminal View (Add default terminal text editor)
set -ge EDITOR
set -gx EDITOR nvim
set -gx VISUAL nvim

set -x TERMINAL kitty
set -x TERM kitty

set -x PATH /usr/local/bin $PATH

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

set -x PATH $PATH $HOME/go/bin

# Vim Mode
fish_vi_key_bindings

zoxide init fish | source
