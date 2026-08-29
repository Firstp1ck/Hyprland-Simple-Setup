-- Hyprland's fallback rule handles every monitor that has no explicit rule.
-- Manual monitor setup replaces this file with output-specific rules.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- Example single-monitor configuration:
-- hl.monitor({ output = "DP-1", mode = "2560x1440@144", position = "0x0", scale = 1 })
-- hl.workspace_rule({ workspace = "1", monitor = "DP-1", default = true })

-- Example dual-monitor configuration:
-- hl.monitor({ output = "DP-1", mode = "2560x1440@144", position = "0x0", scale = 1 })
-- hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "2560x0", scale = 1 })
-- hl.workspace_rule({ workspace = "1", monitor = "DP-1", default = true })
-- hl.workspace_rule({ workspace = "2", monitor = "HDMI-A-1" })
