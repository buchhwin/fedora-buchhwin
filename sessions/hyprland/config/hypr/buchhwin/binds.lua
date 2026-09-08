-- Keybindings — dwl's layout, on Hyprland.
--
-- These are the bindings from the dwl session, key for key, because the point
-- is that muscle memory carries between the two desktops. Where dwl and the
-- Hyprland shell wanted the same key, dwl won and the shell panel moved.
--
-- ⚠️ THIS FILE IS THE FALLBACK, NOT THE SOURCE OF TRUTH.
-- Once the shell has generated generated/binds.lua, hyprland.lua loads that
-- INSTEAD of this file — never both, because two binds on one key leave you
-- guessing which one ran. Edit the defaults here; edit your own keys in the
-- shell's Shortcuts page, which is what writes the generated file.
--
-- Three dwl behaviours have no Hyprland equivalent and are deliberately absent
-- rather than quietly approximated:
--   * Super+Ctrl+N       toggleview  — dwl tags are a bitmask, so several tags
--   * Super+Ctrl+Shift+N toggletag     can be visible at once and one window can
--                                      carry several. Hyprland workspaces are
--                                      exclusive; there is nothing to map onto.
--   * Super+0 in dwl views ALL tags at once. Here it opens the shell's
--     workspace overview, which is the nearest honest thing.

local mod = "SUPER"

-- Programs are launched through the buchhwin-* wrappers rather than the binary,
-- exactly as dwl does. The wrapper carries the fallback chain, so a missing
-- Brave falls through to the XDG default instead of the key doing nothing.
local terminal   = "buchhwin-terminal"
local browser    = "buchhwin-browser"
local editor     = "buchhwin-code"
local files      = "dolphin"
local screenshot = "buchhwin-screenshot"

-- Talking to the shell. Every panel is reached the same way, so a key and a
-- click on the bar end up in the same code path.
local function ipc(verb)
    return "qs -c buchhwin ipc call " .. verb
end

local function exec(key, command, opts)
    hl.bind(key, hl.dsp.exec_cmd(command), opts)
end

-- ------------------------------------------------------------------ programs

exec(mod .. " + Return",        terminal,                   { description = "Terminal" })
exec(mod .. " + D",             ipc("launcher toggle"),     { description = "App launcher" })
exec(mod .. " + B",             browser,                    { description = "Web browser" })
exec(mod .. " + E",             files,                      { description = "Files" })
exec(mod .. " + C",             editor,                     { description = "VS Code" })
exec(mod .. " + V",             ipc("notch clipboard"),     { description = "Clipboard history" })
exec(mod .. " + N",             ipc("notch notifications"), { description = "Notifications" })
exec(mod .. " + M",             ipc("notch session"),       { description = "Power menu" })
exec(mod .. " + SHIFT + C",     ipc("notch quick"),         { description = "Control centre" })
exec(mod .. " + SHIFT + S",     ipc("settings toggle"),     { description = "Settings" })
exec(mod .. " + F1",            ipc("settings keys"),       { description = "Keyboard shortcuts" })

-- ⚠️ THE LOCK SCREEN IS ITS OWN PROCESS, NOT AN IPC CALL.
-- `ipc call lock lock` was bound here before and could never have worked: there
-- is no "lock" target in shell/ipc/Ipc.qml. The lock screen is a second
-- quickshell instance selected by BUCHHWIN_MODE, which is also why it survives
-- the main shell crashing.
exec(mod .. " + L", "env BUCHHWIN_MODE=lock qs -c buchhwin", { description = "Lock screen" })

-- ------------------------------------------------------------ window / layout

hl.bind(mod .. " + Q", hl.dsp.window.close(), { description = "Close window" })

-- focusstack +1 / -1
hl.bind(mod .. " + J", hl.dsp.window.cycle_next({ next = true }),  { description = "Focus next window" })
hl.bind(mod .. " + K", hl.dsp.window.cycle_next({ next = false }), { description = "Focus previous window" })

-- incnmaster: how many windows sit in the master area
hl.bind(mod .. " + I",         hl.dsp.layout("addmaster"),    { description = "More master windows" })
hl.bind(mod .. " + SHIFT + I", hl.dsp.layout("removemaster"), { description = "Fewer master windows" })

-- setmfact: the master/stack split. Arrow keys only — dwl deliberately dropped
-- upstream's Super+H / Super+L for this, and its CI still refuses them.
hl.bind(mod .. " + Left",  hl.dsp.layout("mfact -0.05"), { description = "Shrink master", repeating = true })
hl.bind(mod .. " + Right", hl.dsp.layout("mfact +0.05"), { description = "Grow master",   repeating = true })

-- sethorizontalmfact: dwl's own action. It switches to the bottom-stack layout
-- FIRST and then moves the divider, so one key both rearranges and resizes. A
-- dispatcher does one thing, so this is a plain Lua function — hl.bind accepts
-- one, which is the whole reason the dwl bindings can be reproduced at all.
local function horizontalMfact(delta)
    return function()
        hl.dispatch(hl.dsp.layout("orientationtop"))
        hl.dispatch(hl.dsp.layout("mfact " .. delta))
    end
end
hl.bind(mod .. " + Up",   horizontalMfact("-0.05"), { description = "Top stack, shrink", repeating = true })
hl.bind(mod .. " + Down", horizontalMfact("+0.05"), { description = "Top stack, grow",   repeating = true })

-- zoom: swap the focused window with the master
hl.bind(mod .. " + SHIFT + Return", hl.dsp.layout("swapwithmaster"), { description = "Promote to master" })

-- Layouts. dwl has four; Hyprland's master layout expresses the useful three as
-- orientations, and monocle as a maximised window.
hl.bind(mod .. " + T",           hl.dsp.layout("orientationleft"), { description = "Tiled layout" })
hl.bind(mod .. " + SPACE",       hl.dsp.layout("orientationnext"), { description = "Cycle layout" })
hl.bind(mod .. " + ALT + SPACE", hl.dsp.layout("orientationtop"),  { description = "Top-and-bottom layout" })
-- "maximized", not "maximize" — Hyprland accepts only fullscreen/maximized and
-- rejects the config outright otherwise.
hl.bind(mod .. " + SHIFT + M",   hl.dsp.window.fullscreen({ mode = "maximized" }), { description = "Monocle" })

hl.bind(mod .. " + SHIFT + SPACE", hl.dsp.window.float({ action = "toggle" }),      { description = "Toggle floating" })
hl.bind(mod .. " + SHIFT + F",     hl.dsp.window.fullscreen({ action = "toggle" }), { description = "Toggle fullscreen" })

-- dwl's floating LAYOUT: every window on the workspace floats at once. Hyprland
-- has no such layout, but it does have a query API, so the effect is
-- reproducible. Only "toggle" is used — the other action names are not worth
-- guessing at — and toggling only the windows in the wrong state is idempotent.
local function toggleWorkspaceFloating()
    local workspace = hl.get_active_workspace()
    if workspace == nil then return end
    local windows = hl.get_workspace_windows(workspace)
    if windows == nil or #windows == 0 then return end

    local anyTiled = false
    for _, window in ipairs(windows) do
        if not window.floating then
            anyTiled = true
            break
        end
    end

    for _, window in ipairs(windows) do
        if window.floating ~= anyTiled then
            hl.dispatch(hl.dsp.window.float({ action = "toggle", window = window }))
        end
    end
end
hl.bind(mod .. " + F", toggleWorkspaceFloating, { description = "Float everything on this workspace" })

-- ---------------------------------------------------------------- workspaces

-- dwl numbers its tags 1-9 and uses them as workspaces. No shifted-keysym table
-- is needed the way it was in dwl: Hyprland resolves against the live XKB map,
-- so "SUPER + SHIFT + 1" is right on a German layout and on a US one.
for index = 1, 9 do
    hl.bind(mod .. " + " .. index,
            hl.dsp.focus({ workspace = index }),
            { description = "Workspace " .. index })
    hl.bind(mod .. " + SHIFT + " .. index,
            hl.dsp.window.move({ workspace = index }),
            { description = "Move to workspace " .. index })
end

-- dwl's Super+Tab returns to the tagset you were on before.
hl.bind(mod .. " + TAB", hl.dsp.focus({ workspace = "previous" }), { description = "Previous workspace" })

-- dwl puts a window on every tag here, which is what "sticky" means there.
hl.bind(mod .. " + SHIFT + 0", hl.dsp.window.pin({ action = "toggle" }), { description = "Pin to every workspace" })

-- dwl's "view all tags". There is no such view in Hyprland, so this opens the
-- overview the shell draws instead.
exec(mod .. " + 0", ipc("notch workspaces"), { description = "Workspace overview" })

-- ------------------------------------------------------------------ monitors

hl.bind(mod .. " + COMMA",          hl.dsp.focus({ monitor = "l" }),       { description = "Focus left monitor" })
hl.bind(mod .. " + PERIOD",         hl.dsp.focus({ monitor = "r" }),       { description = "Focus right monitor" })
hl.bind(mod .. " + SHIFT + COMMA",  hl.dsp.window.move({ monitor = "l" }), { description = "Move to left monitor" })
hl.bind(mod .. " + SHIFT + PERIOD", hl.dsp.window.move({ monitor = "r" }), { description = "Move to right monitor" })

-- --------------------------------------------------------------- screenshots

exec(mod .. " + S",             screenshot .. " region", { description = "Screenshot a region" })
exec(mod .. " + Print",         screenshot .. " region", { description = "Screenshot a region" })
exec(mod .. " + SHIFT + Print", screenshot .. " full",   { description = "Screenshot the screen" })
exec(mod .. " + CTRL + Print",  screenshot .. " edit",   { description = "Screenshot and annotate" })

-- ------------------------------------------------------ shell panels (extras)
--
-- dwl has no counterpart for these, so they take keys dwl leaves free.

exec(mod .. " + P",           ipc("notch media"),      { description = "Media" })
exec(mod .. " + R",           ipc("notch calculator"), { description = "Calculator" })
exec(mod .. " + ESCAPE",      ipc("notch collapse"),   { description = "Collapse the island" })
exec(mod .. " + SHIFT + K",   ipc("notch calendar"),   { description = "Calendar" })
exec(mod .. " + SHIFT + Y",   ipc("notch tray"),       { description = "System tray" })
exec(mod .. " + SHIFT + TAB", ipc("notch monitors"),   { description = "Monitors" })
exec(mod .. " + SHIFT + E",   ipc("notch emoji"),      { description = "Emoji" })
exec(mod .. " + SHIFT + N",   ipc("notch event"),      { description = "New event" })
exec(mod .. " + SHIFT + W",   ipc("notch wallpaper"),  { description = "Wallpaper" })
exec(mod .. " + SHIFT + T",   ipc("notch theme"),      { description = "Theme" })
exec(mod .. " + SHIFT + Z",   ipc("notch timer"),      { description = "Timer" })
exec(mod .. " + SHIFT + B",   ipc("bar toggle"),       { description = "Show or hide the bar" })
exec("CTRL + SHIFT + ESCAPE", ipc("notch tasks"),      { description = "Task manager" })

-- The rescue key. If the shell is wedged, nothing above that starts with
-- `qs -c buchhwin` will answer — this restarts it without needing a terminal.
exec(mod .. " + CTRL + SHIFT + R", "systemctl --user restart buchhwin-shell.service",
     { description = "Restart the shell" })

-- ------------------------------------------------------------- hardware keys
--
-- Identical commands to dwl's, including the 150 % cap when raising volume.
-- locked = true so they work on the lock screen; repeating = true so holding
-- the key keeps going.

local hw = { locked = true, repeating = true }
exec("XF86AudioRaiseVolume",  "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+", hw)
exec("XF86AudioLowerVolume",  "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",        hw)
exec("XF86AudioMute",         "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",       hw)
exec("XF86AudioMicMute",      "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle",     hw)
exec("XF86MonBrightnessUp",   "brightnessctl set 5%+",                            hw)
exec("XF86MonBrightnessDown", "brightnessctl set 5%-",                            hw)

-- Transport keys must not repeat: holding "next" should skip one track, not
-- empty the playlist.
local media = { locked = true }
exec("XF86AudioPlay",  "playerctl play-pause", media)
exec("XF86AudioPause", "playerctl play-pause", media)
exec("XF86AudioNext",  "playerctl next",       media)
exec("XF86AudioPrev",  "playerctl previous",   media)

-- ---------------------------------------------------------------------- mouse

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- -------------------------------------------------------------------- session

hl.bind(mod .. " + SHIFT + Q", hl.dsp.exit(), { description = "Log out" })
