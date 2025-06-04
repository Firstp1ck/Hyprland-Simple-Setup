function pac
    switch $argv[1]
        case up
            sudo pacman -Syu
        case in
            sudo pacman -S $argv[2..-1]
        case rm
            sudo pacman -Rns $argv[2..-1]
        case sea
            yay -Ss $argv[2..-1]
        case mir
            sudo reflector --verbose --country DE,CH,AT --protocol https --sort rate --latest 20 --download-timeout 6 --save /etc/pacman.d/mirrorlist
        case '*'
            echo "Usage: pac [up|in|rm|sea|mir] [package_name]"
            echo "  up  - update system packages"
            echo "  in  - install package(s)"
            echo "  rm  - remove package(s) and dependencies"
            echo "  sea - search for packages"
            echo "  mir - update mirror list"
    end
end