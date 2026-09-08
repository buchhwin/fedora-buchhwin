-- Buchhwin Hyprland session. Kept separate from every Plasma setting.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("XCURSOR_THEME", "breeze_cursors")
hl.env("XCURSOR_SIZE", "24")

hl.config({
    general = {
        gaps_in = 6,
        gaps_out = 12,
        border_size = 2,
        layout = "dwindle",
    },
    decoration = {
        rounding = 12,
        active_opacity = 1.0,
        inactive_opacity = 0.96,
        blur = { enabled = true, size = 6, passes = 2 },
        shadow = { enabled = true, range = 12 },
    },
    input = {
        kb_layout = "de",
        follow_mouse = 1,
        repeat_rate = 40,
        repeat_delay = 300,
        touchpad = { natural_scroll = true, tap_to_click = true },
    },
})

-- Start only Buchhwin's user units. Plasma's panel and desktop are not part of
-- this session, while KDE's system services and applications remain available.
hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_CONFIG_HOME")
hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_CONFIG_HOME")
hl.exec_cmd("systemctl --user start graphical-session.target")
hl.exec_cmd("systemctl --user restart buchhwin-shell.service")

local function exec(key, command)
    hl.bind(key, hl.dsp.exec_cmd(command))
end

exec("SUPER + Return", "kitty")
exec("SUPER + Space", "qs -c buchhwin ipc call launcher toggle")
exec("SUPER + E", "dolphin")
exec("SUPER + SHIFT + C", "kate")
exec("SUPER + I", "systemsettings")
exec("SUPER + N", "systemsettings kcm_networkmanagement")
exec("SUPER + B", "systemsettings kcm_bluetooth")
exec("SUPER + L", "qs -c buchhwin ipc call lock lock")

hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + F", hl.dsp.window.fullscreen())
hl.bind("SUPER + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + H", hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + J", hl.dsp.focus({ direction = "down" }))
hl.bind("SUPER + K", hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER + Right", hl.dsp.focus({ direction = "right" }))

for i = 1, 9 do
    local key = tostring(i)
    hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

exec("XF86AudioRaiseVolume", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+")
exec("XF86AudioLowerVolume", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")
exec("XF86AudioMute", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
exec("XF86AudioMicMute", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
exec("XF86MonBrightnessUp", "brightnessctl set 5%+")
exec("XF86MonBrightnessDown", "brightnessctl set 5%-")
