# Sets up user key bindings for Fish shell, enabling fzf integration if available
function fish_user_key_bindings
  if type -q fzf
      fzf --fish | source
  end
end