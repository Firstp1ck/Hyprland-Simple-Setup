# Interactive AUR package installer: select packages with fzf and install using yay
function yaf
    yay -Slq | fzf --multi --preview 'yay -Sii {}' --preview-window=down:75% --layout=default | xargs -ro yay -S
end