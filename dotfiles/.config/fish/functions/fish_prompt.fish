function fish_prompt
    set_color green
    echo -n (get_os)" "
    set_color normal
    echo -n (pwd)

    # Git status with more detailed information
    set -l git_status (fish_git_prompt)
    if test -n "$git_status"
        set_color yellow
        echo -n " $git_status"
    end
    set_color normal

    echo -n " > "
end