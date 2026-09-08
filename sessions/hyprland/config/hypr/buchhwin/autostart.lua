-- Autostart.
--
-- ⚠️ EVERYTHING HERE IS INSIDE hl.on("hyprland.start", …) AND THAT IS THE POINT.
-- A bare hl.exec_cmd() at the top level of a config file runs while the config
-- is being PARSED — before there is a Wayland socket, before the compositor can
-- accept clients. The previous version of this config did exactly that, so the
-- environment it pushed into systemd had no WAYLAND_DISPLAY in it yet.
--
-- What is NOT here, on purpose:
--   * the shell itself is a systemd user unit (buchhwin-shell.service), so it
--     restarts on failure instead of dying with one bad frame
--   * the clipboard watchers are units too (buchhwin-clipboard*.service)
--   * the polkit agent is spawned by the shell from Config.autostart
--   * the wallpaper is a surface the shell draws, not a program

hl.on("hyprland.start", function()
    -- ⚠️ IMPORT BEFORE START, NOT AFTER. Units started before the environment
    -- is imported inherit an empty WAYLAND_DISPLAY and connect to nothing. The
    -- two imports look redundant but are not: systemd's own environment and the
    -- D-Bus activation environment are separate stores, and the portal reads
    -- the second one.
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE XDG_CONFIG_HOME HYPRLAND_INSTANCE_SIGNATURE")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE XDG_CONFIG_HOME HYPRLAND_INSTANCE_SIGNATURE")

    hl.exec_cmd("systemctl --user start graphical-session.target")
    hl.exec_cmd("systemctl --user start buchhwin-shell.service")
end)
