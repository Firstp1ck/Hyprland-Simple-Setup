# Prevents KDE-Plasma from starting if not commented out
# if [ -z "${DISPLAY}" ] && [ "${XDG_VTNR}" -eq 1 ]; then
#     exec Hyprland
# fi

if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi