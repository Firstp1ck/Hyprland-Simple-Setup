# Ollama Settings
set -x OLLAMA_USE_GPU 1
set -x OLLAMA_MAX_LOADED_MODELS 1
set -x OLLAMA_NUM_PARALLEL 2
set -x OLLAMA_MAX_QUEUE 512
set -x OLLAMA_MODELS /mnt/SSD_NVME_4TB/Ollama/
set -gx HSA_OVERRIDE_GFX_VERSION 11.0.1
set -gx ROCR_VISIBLE_DEVICES 0
set -x OLLAMA_CONTEXT_LENGTH 32768
set -x OLLAMA_NUM_GPU_LAYERS 999
set -x OLLAMA_FLASH_ATTENTION 1
set OLLAMA_API_BASE "http://127.0.0.1:11434/v1"

# Less Pager Reader
set -gx LESS '-R --quit-if-one-screen --ignore-case --LONG-PROMPT --RAW-CONTROL-CHARS --HILITE-UNREAD --tabs=4 --no-init --window=-4'

# fzf Config Exports
set -gx FZF_DEFAULT_OPTS "--bind 'delete:execute(mkdir -p ~/.trash && mv {} ~/.trash/)+reload(find .)'"

# Wayland for OBS (Screen Recording)
set -x QT_QPA_PLATFORMTHEME qt5ct
set -x QT_QPA_PLATFORM wayland

# Hyprland DBus
set -x DBUS_SESSION_BUS_ADDRESS "unix:path=$XDG_RUNTIME_DIR/bus"
set -x XDG_CURRENT_DESKTOP Hyprland

# Android SDK
set -gx ANDROID_HOME /opt/android-sdk
set -gx PATH $PATH $ANDROID_HOME/platform-tools $ANDROID_HOME/build-tools/36.1.0

# Java (JDK 17 for Android/Gradle compatibility)
set -gx JAVA_HOME /usr/lib/jvm/java-17-openjdk