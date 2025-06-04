# Ollama Settings
set -x OLLAMA_USE_GPU 1
set -x OLLAMA_MAX_LOADED_MODELS 2
set -x OLLAMA_NUM_PARALLEL 4
set -x OLLAMA_MAX_QUEUE 512
set -x OLLAMA_MODELS /mnt/SSD_NVME_4TB/Ollama/
set -gx HSA_OVERRIDE_GFX_VERSION 11.0.1
set -gx ROCR_VISIBLE_DEVICES 0

# Less Pager Reader
export LESS='-R --quit-if-one-screen --ignore-case --LONG-PROMPT --RAW-CONTROL-CHARS --HILITE-UNREAD --tabs=4 --no-init --window=-4'

# fzf Config Exports
set -gx FZF_DEFAULT_OPTS "--bind 'delete:execute(mkdir -p ~/.trash && mv {} ~/.trash/)+reload(find .)'"

# Wayland for OBS (Screen Recording)
set -x QT_QPA_PLATFORMTHEME qt5ct
set -x QT_QPA_PLATFORM wayland

# Hyprland DBus
set -x DBUS_SESSION_BUS_ADDRESS "unix:path=$XDG_RUNTIME_DIR/bus"
set -x XDG_CURRENT_DESKTOP Hyprland

# Onedrive Connection Settings
set -x ONEDRIVE_HTTP_PROTOCOL HTTP/1.1
set -x ONEDRIVE_IP_VERSION 4 