function get_os
    set -l os_info (cat /etc/os-release)
    set -l os_name (string match -r '^NAME="?(.+)"?$' $os_info)[2]
    echo $os_name
end