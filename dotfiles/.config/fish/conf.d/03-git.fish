# Git prompt configuration
set -g __fish_git_prompt_show_informative_status 1
set -g __fish_git_prompt_showdirtystate 1
set -g __fish_git_prompt_showuntrackedfiles 1
set -g __fish_git_prompt_showupstream informative
set -g __fish_git_prompt_showstashstate 1
set -g __fish_git_prompt_showcolorhints 1

# Git prompt colors
set -g __fish_git_prompt_color_branch yellow
set -g __fish_git_prompt_color_dirtystate red
set -g __fish_git_prompt_color_stagedstate green
set -g __fish_git_prompt_color_untrackedfiles red
set -g __fish_git_prompt_color_upstream_ahead green
set -g __fish_git_prompt_color_upstream_behind red
set -g __fish_git_prompt_color_cleanstate green
set -g __fish_git_prompt_color_upstream yellow

# Git prompt characters
set -g __fish_git_prompt_char_dirtystate '✚'
set -g __fish_git_prompt_char_stagedstate '●'
set -g __fish_git_prompt_char_untrackedfiles '…'
set -g __fish_git_prompt_char_cleanstate '✔' 