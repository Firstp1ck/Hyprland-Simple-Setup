# Prints the OS name from /etc/os-release
function get_os
    set -l os_line ""
    while read -l line
        if string match -q 'NAME=*' $line
            set os_line $line
            break
        end
    end < /etc/os-release
    set -l os_name (string replace -r '^NAME=\"?(.+)\"?$' '$1' -- $os_line)
    echo $os_name
end