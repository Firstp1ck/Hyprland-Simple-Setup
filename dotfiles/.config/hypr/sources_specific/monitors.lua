-- Check monitor names with `hyprctl monitors all`.
-- setup.sh populates this file when monitor auto-detection or manual setup runs.

-- Example single-monitor configuration:
-- hl.monitor({ output = "DP-1", mode = "2560x1440@144", position = "0x0", scale = 1 })
-- hl.workspace_rule({ workspace = "1", monitor = "DP-1", default = true })

-- Example dual-monitor configuration:
-- hl.monitor({ output = "DP-1", mode = "2560x1440@144", position = "0x0", scale = 1 })
-- hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "2560x0", scale = 1 })
-- hl.workspace_rule({ workspace = "1", monitor = "DP-1", default = true })
-- hl.workspace_rule({ workspace = "2", monitor = "HDMI-A-1" })
