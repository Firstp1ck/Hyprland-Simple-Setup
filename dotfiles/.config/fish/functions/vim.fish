function vim
    if test -w "$argv[1]" -o ! -e "$argv[1]"
        nvim $argv
    else
        sudoedit $argv
    end
end