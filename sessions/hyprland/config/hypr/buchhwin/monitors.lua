-- Monitors.
--
-- Deliberately a single catch-all rule. Hyprland's own detection is better than
-- anything that could be guessed here, and real monitor layouts are per-machine
-- and therefore belong in overrides.lua, not in a repository shared between
-- machines. The shell's Displays page writes generated/settings.lua when the
-- user arranges screens; that file loads after this one and wins.
--
--   output = ""  matches every connector that has no more specific rule

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
