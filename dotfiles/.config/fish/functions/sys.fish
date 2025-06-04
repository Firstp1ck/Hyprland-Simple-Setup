function sys
    switch $argv[1]
        case update
            Start_System_setup.sh --function update_arch
        case backup
            Start_System_setup.sh --function system_backup
        case grub
            sudo grub-mkconfig -o /boot/grub/grub.cfg
        case '*'
            echo "Usage: sys [update|backup|grub]"
            echo "  update - update Arch Linux system using Start_System_setup.sh"
            echo "  backup - create system backup using Start_System_setup.sh"
            echo "  grub  - regenerate GRUB configuration file"
    end
end