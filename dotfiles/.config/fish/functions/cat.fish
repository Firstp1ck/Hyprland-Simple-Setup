function cat
    if command -v bat >/dev/null 2>&1
        bat $argv
    else
        command cat $argv
    end
end