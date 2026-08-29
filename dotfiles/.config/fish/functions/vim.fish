# Opens files with the selected editor if writable, otherwise uses sudoedit.
function vim
    set -l editor $EDITOR
    if test -z "$editor"
        set editor vi
    end

    if test -z "$argv[1]"
        command $editor $argv
    else if test -w "$argv[1]"; or not test -e "$argv[1]"
        command $editor $argv
    else
        sudoedit $argv
    end
end
