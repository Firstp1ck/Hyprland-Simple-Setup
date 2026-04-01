# System management helper: update, backup, or regenerate GRUB config
function sys
    switch $argv[1]
        case grub
            sudo grub-mkconfig -o /boot/grub/grub.cfg
        case '*'
            echo "Usage: sys [grub]"
            echo "  grub  - regenerate GRUB configuration file"
    end
end