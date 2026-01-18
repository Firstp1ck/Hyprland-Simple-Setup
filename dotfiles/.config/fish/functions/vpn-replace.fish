function vpn-replace --description "Delete and re-import a WireGuard connection"
    # Parse arguments
    argparse -n vpn-replace 'c/connection=' 'f/file=' -- $argv
    or return

    # Find and move *-FREE-*.conf files (retry loop)
    while true
        set -l free_files (find ~/Downloads -maxdepth 1 -name "*-FREE-*.conf" -type f 2>/dev/null)

        if test (count $free_files) -gt 0
            set -l selected_file

            if test (count $free_files) -eq 1
                # Only one file found, use it automatically
                set selected_file $free_files[1]
                echo "Found one FREE config file: $selected_file"
            else
                # Multiple files found, let user choose
                echo "Multiple FREE config files found:"
                for i in (seq (count $free_files))
                    echo "  [$i] $free_files[$i]"
                end

                read -P "Select file number (1-"(count $free_files)"): " choice
                set -l choice_num (string trim $choice)

                if test -z "$choice_num"; or not string match -qr '^[0-9]+$' "$choice_num"
                    echo "Invalid selection. Aborting."
                    return 1
                end

                if test $choice_num -lt 1 -o $choice_num -gt (count $free_files)
                    echo "Selection out of range. Aborting."
                    return 1
                end

                set selected_file $free_files[$choice_num]
            end

            # Move the selected file to /etc/wireguard/wg-proton.conf
            echo "Moving $selected_file to /etc/wireguard/wg-proton.conf"
            sudo mv "$selected_file" /etc/wireguard/wg-proton.conf
            or begin
                echo "Failed to move file. Aborting."
                return 1
            end
            break
        else
            echo "No *-FREE-*.conf files found in ~/Downloads."
            read -P "Have you created and downloaded the config file from https://account.proton.me/u/4/vpn/WireGuard? (y/n): " response
            set -l response_lower (string lower (string trim $response))
            if not string match -q "y*" "$response_lower"
                echo "Please download the config file from https://account.proton.me/u/4/vpn/WireGuard and try again."
                return 1
            end
            echo "Retrying..."
        end
    end

    # Set defaults
    set -q _flag_connection; or set _flag_connection wg-proton
    set -q _flag_file; or set _flag_file "/etc/wireguard/wg-proton.conf"

    # Delete existing connection (suppress errors if it doesn't exist)
    nmcli connection delete "$_flag_connection" 2>/dev/null

    # Import new connection
    sudo nmcli connection import type wireguard file "$_flag_file"
end
