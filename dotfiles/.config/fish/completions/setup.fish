# fish completion for the 'setup' alias of Start_System_setup.sh

# Define completions for the 'setup' alias exactly as shown in desired output

# Note: The '-r' and '-y' flags showing up for dry-run are unexpected based on script flags.
# I am defining dry-run as --dry-run and -dry based on your earlier explicit request.
# If '-r' and '-y' are truly part of the dry-run completion you want, they would need
# to be added, but they don't correspond to the script's flag handling.

complete -c setup -l default -s d -d "Run the default set of steps"
complete -c setup -l function -s f -r -d "Run only the specified function"
complete -c setup -l help -s h -d "Show this help message"
complete -c setup -l list -s l -d "List all available functions"
complete -c setup -l dry-run -s dry -d "Does not change any settings/files"
complete -c setup -l verbose -s v -d "Add Verbose output for debugging"


# Function flag, which takes an argument
complete -c setup -l function -s f -r -d "Run only the specified function" \
    -a "update_eos_mirrors update_arch_mirrors update_pacman update_yay update_debian update_fedora remove_cache configure_pacman_color install_packages install_drivers update_firmware configure_drives Debug_ntfs_drives configure_fish configure_bluetooth configure_ssh configure_git configure_environment configure_dotfiles configure_virtual_env configure_ollama configure_razer configure_input_remapper configure_fingerprint configure_grub configure_timeshift configure_grub_btrfsd configure_network_manager configure_wifi configure_rust configure_gnome_keyring configure_filepicker configure_monitor configure_onedrive configure_onedrive_rclone sync_arch_to_nas configure_nas_sync configure_wallpaper_path configure_hyprlock_wallpaper configure_notification configure_waydroid configure_torbrowser"