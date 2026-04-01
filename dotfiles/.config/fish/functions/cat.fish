# Wrapper for 'cat' that uses 'bat' for syntax highlighting if available, otherwise falls back to 'cat'
function cat
    if command -v bat >/dev/null 2>&1
        bat $argv
    else
        command cat $argv
    end
end