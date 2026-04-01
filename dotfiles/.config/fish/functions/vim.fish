# Opens files with nvim if writable, otherwise uses sudoedit for root editing
function vim
    if test -z "$argv[1]"
        nvim $argv
    else if test -w "$argv[1]"; or not test -e "$argv[1]"
        nvim $argv
    else
        sudoedit $argv
    end
end