# Custom Fish shell prompt with OS icon detection based on /etc/os-release
function fish_prompt
    # Detect OS family from /etc/os-release without external tools
    set -l os_id ""
    set -l os_id_like ""
    while read -l line
        if test -z "$os_id"; and string match -q 'ID=*' $line
            set os_id (string lower (string replace -r '^ID=\"?(.+)\"?$' '$1' -- $line))
        else if test -z "$os_id_like"; and string match -q 'ID_LIKE=*' $line
            set os_id_like (string lower (string replace -r '^ID_LIKE=\"?(.+)\"?$' '$1' -- $line))
        end
    end < /etc/os-release

    # Default icon: Linux penguin
    set os_icon "🐧"
    if test "$os_id" = "arch"; or test "$os_id" = "endeavouros"; or string match -q -- "*arch*" "$os_id_like"
        set os_icon ""
    else if test "$os_id" = "debian"; or test "$os_id" = "ubuntu"; or string match -q -- "*debian*" "$os_id_like"
        set os_icon ""
    else if test "$os_id" = "fedora"; or string match -q -- "*fedora*" "$os_id_like"
        set os_icon ""
    end

    # Section 1: OS
    set_color 4fa3d1
    echo -n " $os_icon "(get_os)" "
    set_color 4fa3d1
    echo -n ""

    # Section 2: PWD
    set_color normal
    echo -n " "(pwd)" "
    set_color 4fa3d1
    echo -n ""

    # Section 3: Git
    set -l git_status (fish_git_prompt)
    if test -n "$git_status"
        set_color normal
        echo -n "$git_status"
        set_color 4fa3d1
        echo -n ""
    end

    echo -n " "
end