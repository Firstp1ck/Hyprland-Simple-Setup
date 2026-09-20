#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
registry=${HSS_PACKAGES_JSON:-$repo_root/packages.json}

[[ -r $registry ]] || {
  printf 'not ok - package registry is not readable: %s\n' "$registry" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  printf 'not ok - jq is required to validate packages.json\n' >&2
  exit 1
}

if ! jq -e '
  def keys_exact($expected):
    ((keys - $expected) | length == 0) and (($expected - keys) | length == 0);
  def package_name: type == "string" and test("^[a-z0-9@._+-]+$");
  def executable_or_path: type == "string" and length > 0 and test("^[A-Za-z0-9@._+/-]+$");
  def restricted_token: type == "string" and length > 0 and test("^[A-Za-z0-9@._+-]+$");
  def string_array: type == "array" and all(.[]; type == "string");
  def no_controls:
    [paths(scalars) as $path
      | getpath($path)
      | select(type == "string" and test("[[:cntrl:]]"))]
    | length == 0;
  def valid_args:
    string_array and all(.[]; (contains("{HOME}") | not) or startswith("{HOME}/"));
  def registry_entries($field; $source):
    .[$field]
    | to_entries
    | map(.value[] as $package | {package: $package, source: $source});
  def option_keys($role):
    ["package", "source", "executable", "args", "extra_packages", "terminal"]
    + if $role == "browser" or $role == "terminal" then ["class"]
      elif $role == "shell" then ["shell_path"]
      elif $role == "gui_editor" then ["editor_bin", "desktop_file"]
      elif $role == "tui_editor" then ["editor_bin"]
      elif $role == "launcher" then ["dmenu_executable", "dmenu_args", "process", "namespace"]
      elif $role == "agent" then ["installer", "binary_paths"]
      else [] end;
  def valid_option($role):
    type == "object"
    and ((keys - option_keys($role)) | length == 0)
    and (.package | package_name)
    and (if $role == "agent" then .source == "official" else (.source == "pacman" or .source == "aur") end)
    and (.executable | executable_or_path)
    and (.args | valid_args)
    and ((.extra_packages // []) | type == "array" and all(.[]; package_name))
    and ((.terminal // false) | type == "boolean")
    and if $role == "browser" or $role == "terminal" then (.class | restricted_token)
        elif $role == "shell" then (.shell_path | executable_or_path and startswith("/"))
        elif $role == "gui_editor" then (.editor_bin | restricted_token) and (.desktop_file | restricted_token)
        elif $role == "tui_editor" then (.editor_bin | restricted_token)
        elif $role == "launcher" then
          (.dmenu_executable | executable_or_path)
          and (.dmenu_args | valid_args)
          and (.process | restricted_token)
          and (.namespace | restricted_token)
        elif $role == "agent" then
          (.installer | type == "object" and keys_exact(["args", "shell", "url"])
            and (.url | type == "string" and startswith("https://"))
            and (.shell == "sh" or .shell == "bash")
            and (.args | valid_args))
          and (.binary_paths | type == "array" and length > 0
            and all(.[]; type == "string" and startswith("{HOME}/") and test("^[{]HOME[}]/[A-Za-z0-9@._+/-]+$")))
        else true end;
  def role_policy:
    {
      browser: ["multiple", true, "zen-browser-bin"],
      shell: ["multiple", true, "fish"],
      terminal: ["multiple", true, "kitty"],
      multiplexer: ["multiple", true, "herdr-bin"],
      notifications: ["single", true, "swaync"],
      tui_editor: ["multiple", true, "neovim"],
      gui_editor: ["multiple", false, "visual-studio-code-bin"],
      bar: ["single", true, "waybar"],
      dock: ["single", false, null],
      calendar: ["single", true, "merkuro"],
      bluetooth: ["single", true, "bluedevil"],
      network: ["single", true, "plasma-nm"],
      audio: ["single", true, "pavucontrol-qt"],
      launcher: ["single", true, "wofi"],
      agent: ["multiple", false, "pi"]
    };
  def expected_options:
    {
      browser: ["brave-bin", "chromium", "firefox", "vivaldi", "zen-browser-bin"],
      shell: ["bash", "fish", "zsh"],
      terminal: ["alacritty", "foot", "ghostty", "kitty", "konsole"],
      multiplexer: ["herdr-bin", "tmux", "zellij"],
      notifications: ["dunst", "fnott", "mako", "swaync"],
      tui_editor: ["helix", "nano", "neovim", "vim"],
      gui_editor: ["cursor-bin", "kate", "mousepad", "visual-studio-code-bin", "zed"],
      bar: ["ironbar", "nwg-panel", "waybar"],
      dock: ["nwg-dock-hyprland", "nwg-panel"],
      calendar: ["calcurse", "gnome-calendar", "khal", "korganizer", "merkuro"],
      bluetooth: ["bluedevil", "blueman", "bluetui", "bluetuith"],
      network: ["network-manager-applet", "networkmanager", "nm-connection-editor", "plasma-nm"],
      audio: ["alsa-utils", "ncpamixer", "pavucontrol", "pavucontrol-qt", "qastools"],
      launcher: ["bemenu", "fuzzel", "rofi", "tofi", "wofi"],
      agent: ["claude-code", "codex-cli", "cursor-cli", "opencode", "pi"]
    };

  . as $root
  | type == "object"
  and keys_exact(["aur_packages", "hyprland_packages", "official_packages", "package_descriptions", "required", "roles"])
  and no_controls
  and (.hyprland_packages | type == "object" and length > 0
       and all(to_entries[]; (.key | length > 0) and (.value | type == "array" and all(.[]; package_name))))
  and (.aur_packages | type == "object" and length > 0
       and all(to_entries[]; (.key | length > 0) and (.value | type == "array" and all(.[]; package_name))))
  and (.official_packages | type == "object" and length > 0
       and ([to_entries[].value[]] | sort == ["claude-code", "codex-cli", "cursor-cli", "opencode", "pi"])
       and all(to_entries[]; (.key | length > 0) and (.value | type == "array" and all(.[]; package_name))))
  and (.package_descriptions | type == "object" and all(to_entries[]; (.key | package_name) and (.value | type == "string" and length > 0)))
  and (.required | type == "object" and keys_exact(["aur", "pacman"])
       and (.pacman | type == "array" and all(.[]; package_name) and (length == (unique | length)))
       and (.aur | type == "array" and all(.[]; package_name) and (length == (unique | length))))
  and (.roles | type == "object" and keys_exact(role_policy | keys))
  and all(.roles | to_entries[];
    .key as $role
    | .value as $definition
    | (role_policy[$role]) as $policy
    | (expected_options[$role]) as $expected
    | ($definition | type == "object" and keys_exact(["default", "label", "options", "required", "selection"]))
      and ($definition.label | type == "string" and length > 0)
      and ([$definition.selection, $definition.required, $definition.default] == $policy)
      and ($definition.options | type == "array" and length > 0 and all(.[]; valid_option($role)))
      and ([$definition.options[].package] | length == (unique | length))
      and ([$definition.options[].package] | sort == $expected)
      and (($definition.default == null) or ([ $definition.options[].package ] | index($definition.default) != null))
      and (($definition.required | not) or ($definition.default != null)))
  and (
    (registry_entries("hyprland_packages"; "pacman") + registry_entries("aur_packages"; "aur")
      + registry_entries("official_packages"; "official")) as $registry
    | ([.roles | to_entries[] | .key as $role | .value.options[] | . + {role: $role}]) as $options
    | ([.required.pacman[]] + [.required.aur[]]) as $required
    | (($registry | map(.package) | length) == ($registry | map(.package) | unique | length))
      and (($options | group_by(.package) | map(select(length > 1) | {package: .[0].package, roles: map(.role) | sort}))
           == [{package: "nwg-panel", roles: ["bar", "dock"]}])
      and all($options[];
        . as $option
        | any($registry[]; .package == $option.package and .source == $option.source)
          and all(($option.extra_packages // [])[];
            . as $extra
            | any($registry[];
                .package == $extra
                and .source == (if $option.source == "official" then "pacman" else $option.source end))))
      and all(.required.pacman[];
        . as $package | any($registry[]; .package == $package and .source == "pacman"))
      and all(.required.aur[];
        . as $package | any($registry[]; .package == $package and .source == "aur"))
      and all($required[];
        . as $package | ($package == "networkmanager") or all($options[]; .package != $package))
      and ([.required.pacman[]] | index("networkmanager") != null)
      and ([.required.pacman[]] | index("bluez") != null)
      and ([.required.pacman[]] | index("bluez-utils") != null)
      and (.roles.launcher.options[] | select(.package == "tofi") | .source == "aur")
      and (.roles.bluetooth.options[] | select(.package == "bluetuith") | .source == "aur")
      and (.roles.audio.options[] | select(.package == "ncpamixer") | .source == "aur")
      and (.roles.multiplexer.options == [
        {package:"tmux", source:"pacman", executable:"tmux", args:[], terminal:true},
        {package:"zellij", source:"pacman", executable:"zellij", args:[], terminal:true},
        {package:"herdr-bin", source:"aur", executable:"herdr", args:[], terminal:true}
      ])
      and (.roles.agent.options == [
        {package:"pi", source:"official", executable:"pi", args:[], extra_packages:["curl","nodejs","npm"], installer:{url:"https://pi.dev/install.sh",shell:"sh",args:[]}, binary_paths:["{HOME}/.local/bin/pi"]},
        {package:"opencode", source:"official", executable:"opencode", args:[], extra_packages:["curl","tar","gzip"], installer:{url:"https://opencode.ai/install",shell:"bash",args:["--no-modify-path"]}, binary_paths:["{HOME}/.opencode/bin/opencode"]},
        {package:"claude-code", source:"official", executable:"claude", args:[], extra_packages:["curl"], installer:{url:"https://claude.ai/install.sh",shell:"bash",args:[]}, binary_paths:["{HOME}/.local/bin/claude"]},
        {package:"codex-cli", source:"official", executable:"codex", args:[], extra_packages:["curl","tar","gzip"], installer:{url:"https://chatgpt.com/codex/install.sh",shell:"sh",args:[]}, binary_paths:["{HOME}/.local/bin/codex"]},
        {package:"cursor-cli", source:"official", executable:"cursor-agent", args:[], extra_packages:["curl","tar","gzip"], installer:{url:"https://cursor.com/install",shell:"bash",args:[]}, binary_paths:["{HOME}/.local/bin/cursor-agent"]}
      ])
      and all($options[]; .package as $package | $root.package_descriptions[$package] | type == "string" and length > 0)
  )
' "$registry" >/dev/null; then
  printf 'not ok - package registry failed offline schema checks: %s\n' "$registry" >&2
  exit 1
fi
printf 'ok - package registry passed offline structural and schema checks\n'

if [[ ${HSS_LIVE_PACKAGE_CHECK:-0} != 1 ]]; then
  printf 'ok - live package lookup skipped (set HSS_LIVE_PACKAGE_CHECK=1 for the release check)\n'
  exit 0
fi

case ${HSS_LIVE_PACKAGE_TIMEOUT:-15} in
  ''|*[!0-9]*)
    printf 'not ok - HSS_LIVE_PACKAGE_TIMEOUT must be an integer from 1 to 60\n' >&2
    exit 1
    ;;
esac
live_timeout=$((10#${HSS_LIVE_PACKAGE_TIMEOUT:-15}))
if ((live_timeout < 1 || live_timeout > 60)); then
  printf 'not ok - HSS_LIVE_PACKAGE_TIMEOUT must be an integer from 1 to 60\n' >&2
  exit 1
fi
for command in pacman curl timeout; do
  command -v "$command" >/dev/null 2>&1 || {
    printf 'not ok - live package lookup requires %s\n' "$command" >&2
    exit 1
  }
done

mapfile -t pacman_packages < <(jq -r '.hyprland_packages[][]' "$registry" | LC_ALL=C sort -u)
for package in "${pacman_packages[@]}"; do
  if ! timeout "${live_timeout}s" pacman -Si -- "$package" >/dev/null 2>&1; then
    printf 'not ok - pacman package lookup failed: %s\n' "$package" >&2
    exit 1
  fi
done
printf 'ok - %d pacman package names resolved\n' "${#pacman_packages[@]}"

mapfile -t aur_packages < <(jq -r '.aur_packages[][]' "$registry" | LC_ALL=C sort -u)
if ((${#aur_packages[@]} > 0)); then
  curl_args=(-fsS --max-time "$live_timeout" --get 'https://aur.archlinux.org/rpc/v5/info')
  for package in "${aur_packages[@]}"; do
    curl_args+=(--data-urlencode "arg[]=$package")
  done
  if ! aur_response=$(timeout "${live_timeout}s" curl "${curl_args[@]}"); then
    printf 'not ok - AUR RPC lookup failed or exceeded %ss\n' "$live_timeout" >&2
    exit 1
  fi
  if ! jq -e --argjson expected "$(printf '%s\n' "${aur_packages[@]}" | jq -Rsc 'split("\n")[:-1]')" '
      (.type == "multiinfo" or .type == "info")
      and (([.results[].Name] | sort) == ($expected | sort))
    ' <<<"$aur_response" >/dev/null; then
    printf 'not ok - one or more AUR package names did not resolve\n' >&2
    exit 1
  fi
fi
printf 'ok - %d AUR package names resolved\n' "${#aur_packages[@]}"
