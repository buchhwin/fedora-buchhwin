pragma Singleton

// The default keybindings, in one place.
//
// They used to be 460 lines in the middle of Config.qml, which made the one
// file everybody has to read in order to change anything a third longer than it
// needed to be. Nothing else moved: Config still owns `binds` (defaults with
// the user's rebinds applied), `rebindOf`, `bindClash` and `setRebind`. This
// file is only the table.
//
// ⚠️ THIS IS dwl's LAYOUT, KEY FOR KEY. That is the whole point — muscle memory
// has to carry between the two sessions. Where dwl and a shell panel wanted the
// same key, dwl kept it and the panel moved to one dwl leaves free.
//
// ⚠️ AND IT MUST STAY IN STEP WITH config/hypr/buchhwin/binds.lua, which is the
// same table written out by hand for the case where the generator has never
// run. tests/bind-actions.sh compares the two.
//
// Shape of an entry:
//
//   key      the chord, in Hyprland's spelling: "SUPER + SHIFT + Q"
//   action   a name from the table in tools/hypr/Binds.qml — NOT a Hyprland
//            dispatcher. The generator owns that translation, so a rename
//            upstream is one edit there rather than sixty here.
//   arg      the action's argument, when it takes one
//   desc     what shows in the shortcut list and the hotkey overlay
//   repeat   true  = holding the key keeps going (volume, resizing)
//   locked   true  = works while the screen is locked (hardware keys only)
//   mouse    true  = this is a pointer binding, not a key
//
// Anything omitted is off. `repeat` and `locked` are deliberately opt-in: a
// transport key that repeats empties a playlist, and a bind that survives the
// lock screen is a security decision, not a convenience.

import QtQuick

QtObject {
    readonly property string mod: "SUPER"

    readonly property var defaultBinds: [
        // --- programs -------------------------------------------------------
        { key: "SUPER + Return",       action: "spawn",    arg: "@terminal",    desc: "Terminal" },
        { key: "SUPER + D",            action: "spawn-sh", arg: "qs -c buchhwin ipc call launcher toggle", desc: "App launcher" },
        { key: "SUPER + B",            action: "spawn",    arg: "@browser",     desc: "Web browser" },
        { key: "SUPER + E",            action: "spawn",    arg: "@fileManager", desc: "Files" },
        { key: "SUPER + C",            action: "spawn",    arg: "@editor",      desc: "VS Code" },

        // ⚠️ THE LOCK SCREEN IS A SEPARATE PROCESS, NOT AN IPC CALL. There is
        // no "lock" target in ipc/Ipc.qml — a bind that called one sat here for
        // months doing nothing. BUCHHWIN_MODE selects it, which is also why it
        // still works when the main shell has died.
        { key: "SUPER + L",            action: "spawn-sh", arg: "env BUCHHWIN_MODE=lock qs -c buchhwin", desc: "Lock screen" },

        // --- rescue: these have to survive a dead shell ----------------------
        { key: "SUPER + CTRL + SHIFT + R", action: "spawn-sh",
          arg: "systemctl --user restart buchhwin-shell.service", desc: "Restart the shell" },

        // --- window ----------------------------------------------------------
        { key: "SUPER + Q",            action: "close-window",      desc: "Close window" },
        { key: "SUPER + J",            action: "focus-next",        desc: "Focus next window" },
        { key: "SUPER + K",            action: "focus-previous",    desc: "Focus previous window" },
        { key: "SUPER + SHIFT + SPACE",action: "toggle-floating",   desc: "Toggle floating" },
        { key: "SUPER + SHIFT + F",    action: "toggle-fullscreen", desc: "Toggle fullscreen" },
        { key: "SUPER + SHIFT + M",    action: "maximize",          desc: "Monocle" },
        { key: "SUPER + SHIFT + 0",    action: "toggle-pin",        desc: "Pin to every workspace" },

        // --- master / stack --------------------------------------------------
        //
        // These are the reason general.layout is "master" and not "dwindle":
        // mfact, addmaster, removemaster and the orientation messages exist
        // only there. On dwindle every one of them is a silent no-op.
        { key: "SUPER + I",            action: "layout", arg: "addmaster",      desc: "More master windows" },
        { key: "SUPER + SHIFT + I",    action: "layout", arg: "removemaster",   desc: "Fewer master windows" },
        { key: "SUPER + SHIFT + Return", action: "layout", arg: "swapwithmaster", desc: "Promote to master" },
        { key: "SUPER + T",            action: "layout", arg: "orientationleft", desc: "Tiled layout" },
        { key: "SUPER + SPACE",        action: "layout", arg: "orientationnext", desc: "Cycle layout" },
        { key: "SUPER + ALT + SPACE",  action: "layout", arg: "orientationtop",  desc: "Top-and-bottom layout" },

        // Arrow keys only, and that is deliberate: dwl dropped upstream's
        // Super+H / Super+L for resizing and its CI still refuses them.
        { key: "SUPER + Left",         action: "mfact", arg: "-0.05", desc: "Shrink master", repeat: true },
        { key: "SUPER + Right",        action: "mfact", arg: "+0.05", desc: "Grow master",   repeat: true },

        // dwl's sethorizontalmfact: switch to the bottom stack AND move the
        // divider, in one key. Two dispatchers, so the generator emits a Lua
        // function rather than a dispatcher.
        { key: "SUPER + Up",           action: "horizontal-mfact", arg: "-0.05", desc: "Top stack, shrink", repeat: true },
        { key: "SUPER + Down",         action: "horizontal-mfact", arg: "+0.05", desc: "Top stack, grow",   repeat: true },

        // dwl's floating LAYOUT — every window on the workspace at once.
        { key: "SUPER + F",            action: "float-workspace", desc: "Float everything here" },

        // --- workspaces -------------------------------------------------------
        //
        // 1-9 are generated rather than typed out eighteen times; see
        // tools/hypr/Binds.qml. No shifted-keysym table is needed the way dwl
        // needed one: Hyprland resolves against the live XKB map.
        { key: "SUPER + TAB",          action: "previous-workspace", desc: "Previous workspace" },

        // dwl's Super+0 views every tag at once. Hyprland workspaces are
        // exclusive, so this opens the overview the shell draws instead.
        { key: "SUPER + 0",            action: "spawn-sh", arg: "qs -c buchhwin ipc call notch workspaces", desc: "Workspace overview" },

        // --- monitors ---------------------------------------------------------
        { key: "SUPER + COMMA",          action: "focus-monitor",   arg: "l", desc: "Focus left monitor" },
        { key: "SUPER + PERIOD",         action: "focus-monitor",   arg: "r", desc: "Focus right monitor" },
        { key: "SUPER + SHIFT + COMMA",  action: "move-to-monitor", arg: "l", desc: "Move to left monitor" },
        { key: "SUPER + SHIFT + PERIOD", action: "move-to-monitor", arg: "r", desc: "Move to right monitor" },

        // --- screenshots ------------------------------------------------------
        { key: "SUPER + S",             action: "spawn", arg: "buchhwin-screenshot region", desc: "Screenshot a region" },
        { key: "SUPER + Print",         action: "spawn", arg: "buchhwin-screenshot region", desc: "Screenshot a region" },
        { key: "SUPER + SHIFT + Print", action: "spawn", arg: "buchhwin-screenshot full",   desc: "Screenshot the screen" },
        { key: "SUPER + CTRL + Print",  action: "spawn", arg: "buchhwin-screenshot edit",   desc: "Screenshot and annotate" },

        // --- shell panels -----------------------------------------------------
        //
        // dwl has no counterpart for these, so they take keys it leaves free.
        { key: "SUPER + V",           action: "spawn-sh", arg: "qs -c buchhwin ipc call notch clipboard",     desc: "Clipboard history" },
        { key: "SUPER + N",           action: "spawn-sh", arg: "qs -c buchhwin ipc call notch notifications", desc: "Notifications" },
        { key: "SUPER + M",           action: "spawn-sh", arg: "qs -c buchhwin ipc call notch session",       desc: "Power menu" },
        { key: "SUPER + P",           action: "spawn-sh", arg: "qs -c buchhwin ipc call notch media",         desc: "Media" },
        { key: "SUPER + R",           action: "spawn-sh", arg: "qs -c buchhwin ipc call notch calculator",    desc: "Calculator" },
        { key: "SUPER + ESCAPE",      action: "spawn-sh", arg: "qs -c buchhwin ipc call notch collapse",      desc: "Collapse the island" },
        { key: "SUPER + SHIFT + C",   action: "spawn-sh", arg: "qs -c buchhwin ipc call notch quick",         desc: "Control centre" },
        { key: "SUPER + SHIFT + S",   action: "spawn-sh", arg: "qs -c buchhwin ipc call settings toggle",     desc: "Settings" },
        { key: "SUPER + F1",          action: "spawn-sh", arg: "qs -c buchhwin ipc call settings keys",       desc: "Keyboard shortcuts" },
        { key: "SUPER + SHIFT + K",   action: "spawn-sh", arg: "qs -c buchhwin ipc call notch calendar",      desc: "Calendar" },
        { key: "SUPER + SHIFT + Y",   action: "spawn-sh", arg: "qs -c buchhwin ipc call notch tray",          desc: "System tray" },
        { key: "SUPER + SHIFT + TAB", action: "spawn-sh", arg: "qs -c buchhwin ipc call notch monitors",      desc: "Monitors" },
        { key: "SUPER + SHIFT + E",   action: "spawn-sh", arg: "qs -c buchhwin ipc call notch emoji",         desc: "Emoji" },
        { key: "SUPER + SHIFT + N",   action: "spawn-sh", arg: "qs -c buchhwin ipc call notch event",         desc: "New event" },
        { key: "SUPER + SHIFT + W",   action: "spawn-sh", arg: "qs -c buchhwin ipc call notch wallpaper",     desc: "Wallpaper" },
        { key: "SUPER + SHIFT + T",   action: "spawn-sh", arg: "qs -c buchhwin ipc call notch theme",         desc: "Theme" },
        { key: "SUPER + SHIFT + Z",   action: "spawn-sh", arg: "qs -c buchhwin ipc call notch timer",         desc: "Timer" },
        { key: "SUPER + SHIFT + B",   action: "spawn-sh", arg: "qs -c buchhwin ipc call bar toggle",          desc: "Show or hide the bar" },
        { key: "CTRL + SHIFT + ESCAPE", action: "spawn-sh", arg: "qs -c buchhwin ipc call notch tasks",       desc: "Task manager" },

        // --- hardware keys ----------------------------------------------------
        //
        // The same commands dwl uses, including the 150 % cap on raising
        // volume. `locked` so they work on the lock screen.
        { key: "XF86AudioRaiseVolume",  action: "spawn-sh", arg: "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+", desc: "Volume up",   locked: true, repeat: true },
        { key: "XF86AudioLowerVolume",  action: "spawn-sh", arg: "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",        desc: "Volume down", locked: true, repeat: true },
        { key: "XF86AudioMute",         action: "spawn-sh", arg: "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",       desc: "Mute",        locked: true },
        { key: "XF86AudioMicMute",      action: "spawn-sh", arg: "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle",     desc: "Mute the microphone", locked: true },
        { key: "XF86MonBrightnessUp",   action: "spawn-sh", arg: "brightnessctl set 5%+", desc: "Brighter", locked: true, repeat: true },
        { key: "XF86MonBrightnessDown", action: "spawn-sh", arg: "brightnessctl set 5%-", desc: "Dimmer",   locked: true, repeat: true },

        // Transport keys must NOT repeat: holding "next" should skip one track,
        // not empty the playlist.
        { key: "XF86AudioPlay",  action: "spawn-sh", arg: "playerctl play-pause", desc: "Play or pause", locked: true },
        { key: "XF86AudioPause", action: "spawn-sh", arg: "playerctl play-pause", desc: "Play or pause", locked: true },
        { key: "XF86AudioNext",  action: "spawn-sh", arg: "playerctl next",       desc: "Next track",     locked: true },
        { key: "XF86AudioPrev",  action: "spawn-sh", arg: "playerctl previous",   desc: "Previous track", locked: true },

        // --- pointer -----------------------------------------------------------
        { key: "SUPER + mouse:272", action: "drag-window",   desc: "Move window",   mouse: true },
        { key: "SUPER + mouse:273", action: "resize-window", desc: "Resize window", mouse: true },

        // --- session ------------------------------------------------------------
        { key: "SUPER + SHIFT + Q", action: "exit", desc: "Log out" }
    ]
}
