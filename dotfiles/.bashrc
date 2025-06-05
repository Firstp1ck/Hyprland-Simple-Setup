# .bashrc for Arch Linux

# shellcheck disable=SC1090

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

set -o vi

eval "$(zoxide init bash)"

# Git prompt setup - Arch-specific path
if [ -f /usr/share/git/completion/git-prompt.sh ]; then
    source /usr/share/git/completion/git-prompt.sh
fi

get_os() {
    os_info=$(cat /etc/os-release)
    os_name=$(echo "$os_info" | grep -oP '^NAME="?(.+)"?$' | sed 's/^NAME=//;s/"//g')
    echo "$os_name"
}

function bash_prompt {
    # Set color to green
    PS1="\[\e[32m\]"

    # Add OS name
    PS1+=$(get_os)" "

    # Reset color
    PS1+="\[\e[0m\]"

    # Add current working directory
    PS1+="\w"

    # Set color to yellow for git prompt
    PS1+="\[\e[33m\]"

    # Add git prompt (assuming you have a function or command for this)
    PS1+="$(git_prompt)"

    # Reset color
    PS1+="\[\e[0m\]"

    # Add prompt symbol
    PS1+=" > "
}

# Example git prompt function (you can customize this)
git_prompt() {
    git branch 2>/dev/null | grep '^\*' | sed 's/^\* / (/;s/$/)/'
}

vim() {
    if [ -w "$1" ] || [ ! -e "$1" ]; then
        nvim "$@"
    else
        sudoedit "$@"
    fi
}

# Set the prompt
PROMPT_COMMAND=bash_prompt

# Prompt configuration with git integration
# PS1='\[\033[32m\]EOS \[\033[0m\]\w\[\033[33m\]$(__git_ps1 " %s")\[\033[0m\] > '

# General alias
alias cls='clear'
bind 'Control-l: clear-screen'
alias ..='cd ..'
# alias rm='rm -i'
# alias mv='mv -i'
# alias cp='cp -i'
alias cd='z'
alias ls='lsd -lah --group-directories-first --color=auto'
alias top='btop'
alias cat='bat'
alias vi="nvim"
alias vim='nvim'
alias fzf='fzf --bind "enter:execute(nvim {})" -m --preview="bat --color=always --style=numbers --line-range=:500 {}"'
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
alias sysen='systemctl enable'
alias sysdis='systemctl disable'

# Custom Scripts
alias server='Start_ssh_server.sh'
alias update='Start_System_setup.sh --function update_arch'
alias update-o='Start_System_setup.sh --function update_specific_package'
alias backup='Start_System_setup.sh --function system_backup'
alias setup='Start_System_setup.sh'
alias stows='Start_stow_solve.sh'
alias note='Start_notes.sh'
alias notes='Start_notes.sh'

bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'
bind 'TAB:menu-complete'

set completion-ignore-case on
set show-all-if-ambiguous on
set completion-map-case on

export SCRIPTS_DIR="$HOME/Dokumente/GitHub/Linux-Setup/Scripts"
export PATH="$PATH:$SCRIPTS_DIR:$HOME/go/bin"

if [ -d "$SCRIPTS_DIR" ]; then
    find "$SCRIPTS_DIR" -type f -name "*.sh" -exec chmod +x {} \;
fi

# Language settings
export LANG="de_CH.UTF-8"
export LANGUAGE=de_CH:en_US

export HISTCONTROL=ignoreboth

# Git prompt settings
export GIT_PS1_SHOWDIRTYSTATE=1
export GIT_PS1_SHOWUNTRACKEDFILES=1
export GIT_PS1_SHOWUPSTREAM="auto"
export GIT_PS1_SHOWCOLORHINTS=1

# Editor settings
unset EDITOR
export EDITOR=nvim
export VISUAL=nvim

# Path and environment variables for Ollama
# export PATH=$PATH:/opt/rocm/bin:/opt/rocm/opencl/bin
export OLLAMA_USE_GPU=1
export OLLAMA_MAX_LOADED_MODELS=2
export OLLAMA_NUM_PARALLEL=4
export OLLAMA_MAX_QUEUE=512
export OLLAMA_MODELS=/mnt/SSD_NVME_4TB/Ollama/
export HSA_OVERRIDE_GFX_VERSION=11.0.1
export ROCR_VISIBLE_DEVICES=0

# export OLLAMA_HOST=0.0.0.0
# chmod -R 775 $OLLAMA_MODELS

#Java settings
# export INSTALL4J_JAVA_HOME=/usr/lib/jvm/java-17-openjdk

# Better history handling
export HISTTIMEFORMAT="%F %T "
export HISTSIZE=10000
export HISTFILESIZE=10000
export HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

# Better directory navigation
shopt -s autocd
shopt -s cdspell
shopt -s dirspell
shopt -s globstar

# Disable Ctrl+S freezing the terminal
stty -ixon

# Load bash completion if available
[[ -r /usr/share/bash-completion/bash_completion ]] && . /usr/share/bash-completion/bash_completion

# fzf Config Exports
export FZF_DEFAULT_OPTS="--bind 'delete:execute(mkdir -p ~/.trash && mv {} ~/.trash/)+reload(find .)'"

# Terminal settings
export TERMINAL=kitty
export TERM=kitty

# Less pager settings
export LESS='-R --quit-if-one-screen --ignore-case --LONG-PROMPT --RAW-CONTROL-CHARS --HILITE-UNREAD --tabs=4 --no-init --window=-4'

# Wayland and Hyprland settings
export QT_QPA_PLATFORMTHEME=qt5ct
export QT_QPA_PLATFORM=wayland
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
export XDG_CURRENT_DESKTOP=Hyprland

export ONEDRIVE_HTTP_PROTOCOL=HTTP/1.1
export ONEDRIVE_IP_VERSION=4

[ -f ~/.fzf.bash ] && source ~/.fzf.bash
