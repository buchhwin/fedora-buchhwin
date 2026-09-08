-- Session environment.
--
-- These are the variables Hyprland itself exports to every child process. They
-- are NOT the whole story: bin/buchhwin-hyprland-session sets XDG_CONFIG_HOME
-- before Hyprland even starts, because the config path depends on it, and
-- buchhwin/autostart.lua pushes the runtime ones into systemd and D-Bus.

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")

-- ⚠️ "wayland;xcb" AND NOT PLAIN "wayland". The fallback is what keeps a Qt5
-- application that was never built with the Wayland platform plugin from
-- failing to start at all instead of merely running through XWayland.
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

-- Cursor: Breeze, the same one Plasma uses. The session deliberately reads
-- KDE's choice instead of imposing its own, so a cursor changed in System
-- Settings applies to both desktops.
hl.env("XCURSOR_THEME", "breeze_cursors")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")

-- GTK applications are guests here. Breeze-Dark keeps the occasional GTK window
-- from standing out, and it is scoped to this session only — no dconf is written,
-- so Plasma's own GTK setting stays untouched.
hl.env("GTK_THEME", "Breeze-Dark")
