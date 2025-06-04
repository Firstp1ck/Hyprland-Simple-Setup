# General alias
alias cls='clear'
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
alias pic='kitty +kitten icat --place 140x60@0x0'
alias src='source'
alias py='python'
alias py='python3'
alias fab='fabric-ai'
alias cwd='pwd -P'

# Pacman/yay/apt alias
alias pcn='sudo pacman'
alias pacman='sudo pacman'
alias pacsy='sudo reflector --verbose --country DE,CH,AT --protocol https --sort rate --latest 20 --download-timeout 6 --save /etc/pacman.d/mirrorlist'
alias pacup='sudo pacman -Syu'
alias pacin='sudo pacman -S || yay -S'
alias pacrm='sudo pacman -Rns'
alias search='yay -Ss'
alias apt-search='apt search'

# Git alias
alias git-rm-cache='git rm -rf --cached .'
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
alias usrstat='systemctl --user status'
alias sysstat='systemctl status'
alias sysen='systemctl enable'
alias sysdis='systemctl disable'
alias sysusr='systemctl --user'

# Custom alias
alias music 'play_music.sh'
alias stows='Start_stow_solve.sh'
alias note='notes.sh'
alias notes='notes.sh'
alias srcfsh='source ~/.config/fish/config.fish' 