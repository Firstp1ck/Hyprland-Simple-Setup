# Language Settings
set -gx LC_ALL de_CH.UTF-8
set -gx LANG de_CH.UTF-8
set -gx LANGUAGE de_CH:en_US

# Editor and Terminal Settings
set -gx EDITOR nvim
set -gx VISUAL nvim
set -x TERMINAL alacritty
set -x BROWSER zen
set -gx MANPAGER "nvim +Man!"

# PATH settings
# NOTE: This replaces PATH with a fixed list and does not preserve the inherited $PATH.
# That can drop distro/user-provided entries (e.g. from display/login managers, direnv, asdf, etc.).
# Prefer appending/prepending to the existing PATH (fish_add_path or `set -gx PATH <new> $PATH`)
# unless you intentionally want a fully fixed PATH.
set -x PATH /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin \
  $HOME/go/bin \
  $HOME/.local/bin \
  $HOME/.vscode/extensions \
  $HOME/.fzf/bin \
  /opt/rocm/bin /opt/rocm/hipopen/bin /opt/rocm/opencl/bin \
  /usr/local/sbin /usr/local/bin /usr/lib/jvm/default/bin \
  /usr/bin/site_perl /usr/bin/vendor_perl /usr/bin/core_perl \
  /usr/lib/rustup/bin \
  $HOME/.local/scripts \
  $HOME/.local/share/applications \
  $HOME/.config/hypr/scripts \
  $HOME/.config/waybar/scripts \
  $HOME/.npm-global/bin


# Make scripts executable
# NOTE: This currently runs `find ... -exec chmod +x` on every interactive shell start.
# That can be expensive and also mutates files as a side effect of launching a shell.
# Consider moving this to setup-time or a one-shot command instead.
set -l SCRIPTS_DIR_EXE \
  $HOME/.local/scripts \
  $HOME/.local/share/applications \
  $HOME/.config/hypr/scripts \
  $HOME/.config/waybar/scripts

if status is-interactive
    if type -q find
        for dir in $SCRIPTS_DIR_EXE
            if test -d $dir
                command find $dir -type f -name '*.sh' -exec chmod +x '{}' ';'
                command find $dir -type f -name '*.desktop' -exec chmod +x '{}' ';'
            end
        end
    end
end

# Python Environment Variables for Certificates
set -gx UV_NATIVE_TLS true
set -gx SSL_CERT_FILE /etc/ssl/certs/ca-certificates.crt
set -gx REQUESTS_CA_BUNDLE $SSL_CERT_FILE
set -x PYTHONHTTPSVERIFY 1

