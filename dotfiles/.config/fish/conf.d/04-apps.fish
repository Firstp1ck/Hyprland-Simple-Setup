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