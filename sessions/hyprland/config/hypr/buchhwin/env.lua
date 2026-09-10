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
-- QT_WAYLAND_DISABLE_WINDOWDECORATION is NOT set here on purpose: it is what
-- the `windows.noCsd` setting does, and the generator writes it into
-- generated/settings.lua. Setting it in both places would mean switching the
-- setting off left the variable behind, which reads as the setting not working.

-- Cursor: NOT here any more, and the comment that stood here was wrong twice
-- over. It said the session "deliberately reads KDE's choice instead of
-- imposing its own" — under three lines that imposed breeze_cursors and 24 as
-- literals, reading nothing from anywhere.
--
-- The real cost was on the other side: shell.json HAS cursor.theme and
-- cursor.size, with a row in the settings window and a writer that sets GTK
-- over gsettings, and these literals meant the compositor never heard about
-- either. Changing the size moved GTK's pointer and left the compositor's
-- alone — two pointers on one desktop, swapping at a window edge.
--
-- It is written by the generator now (tools/hypr/EmitSettings.qml), into
-- generated/settings.lua, and hyprland.lua carries the same two values as the
-- fallback for a machine that has not generated one yet. Exactly one of the two
-- ever runs, so nothing depends on which of two hl.env calls would win.

hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")

-- GTK applications are guests here. Breeze-Dark keeps the occasional GTK window
-- from standing out, and it is scoped to this session only — no dconf is written,
-- so Plasma's own GTK setting stays untouched.
hl.env("GTK_THEME", "Breeze-Dark")
