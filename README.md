# Hyprland Setup

## Prerequisites
- [Hyprland](https://hyprland.org/) installed.
- Utilities like `hyprctl`, `hyprpaper`, and a shell environment.
- A directory containing your wallpapers.

## Installation & Configuration

1. Clone or copy this repository to your machine.
2. Update the following files with your system-specific details:
   - **Wallpaper Script:**  
     Update the `WALLPAPER_DIR` and `MONITORS` in [.config/hypr/change_wallpaper.sh](./.config/hypr/change_wallpaper.sh).
   - **Hyprland Configuration:**  
     Ensure your Hyprland configuration files are correctly placed in your dotfiles directory.

## Running the Wallpaper Script

The `change_wallpaper.sh` script:
- Checks if hyprpaper is running and starts it if necessary.
- Picks a random wallpaper from your specified directory (excluding the current one).
- Applies the new wallpaper to the specified monitors.

To run the script:
```bash
./.config/hypr/change_wallpaper.sh
```

## Customization
- Modify the script to add more monitors or change file extensions as needed.
- Integrate with other Hyprland features as per your requirements.

## Troubleshooting
- Ensure that the wallpaper directory exists and contains valid image files.
- Verify monitor names using `hyprctl monitors`.

## Additional Resources
- [Hyprland Wiki](https://wiki.hyprland.org/)
- [Hyprland GitHub Repository](https://github.com/vaxerski/Hyprland)
