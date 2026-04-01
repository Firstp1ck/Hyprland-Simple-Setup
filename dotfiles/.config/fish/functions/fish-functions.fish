# Lists all Fish functions in ~/.config/fish/functions with their descriptions
function fish-functions
    for file in ~/.config/fish/functions/*.fish
        set fname (basename $file .fish)
        set desc (string match -r -g '^#\s*(.*)' -- (head -n 1 $file))
        if test -z "$desc"
            set desc "(No description found)"
        end
        printf "%-22s - %s\n" $fname $desc
    end
end
