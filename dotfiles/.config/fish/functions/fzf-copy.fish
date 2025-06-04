function fzf-copy
    eval "$FZF_CTRL_T_COMMAND" | fzf --bind 'ctrl-alt-y:execute-silent(echo {} | wl-copy)+abort'
end