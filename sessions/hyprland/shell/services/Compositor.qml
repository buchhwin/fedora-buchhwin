pragma Singleton

// The compositor, as the rest of the shell is allowed to see it.
//
// A thin layer on purpose. Everything above this file talks about workspaces
// and windows; only services/Niri.qml knows that they arrive as JSON lines
// from `niri msg -j event-stream`. That boundary is the whole point: swapping
// the compositor later is one file, not a search through the interface.
//
// The `available` flag is not decoration. On a machine where the stream never
// comes up, a surface must be able to say "no compositor" instead of drawing
// an empty strip that looks like a bug.

import QtQuick
import Quickshell
import "." as Services

Singleton {
    id: root

    readonly property bool available: Services.Hyprland.available

    readonly property var workspaces: Services.Hyprland.orderedWorkspaces
    readonly property var windows: Services.Hyprland.windows
    readonly property var focusedWindow: Services.Hyprland.focusedWindow
    readonly property var focusedWorkspace: Services.Hyprland.focusedWorkspace
    readonly property bool overviewOpen: Services.Hyprland.overviewOpen
    readonly property string keyboardLayout: Services.Hyprland.keyboardLayout

    // A reload that failed leaves the PREVIOUS config running, which from the
    // outside looks like "my change did nothing". Surfaced so a surface can
    // say which it was.
    readonly property bool configFailed: Services.Hyprland.configFailed

    // The output the user is currently on, by connector name (DP-2, HDMI-A-1).
    //
    // ⚠️ THIS IS THE ONE THING A SERVICE MAY SAY ABOUT SCREENS, and it is not a
    // contradiction of the note below. "Which output is a given surface on" is
    // the caller's business; "which output is the user looking at" is a fact
    // about the compositor and lives nowhere else. Without it, opening the
    // quick panel put a copy on every monitor at once — his B1.
    //
    // ⚠️ NO NEW PROCESS AND NO POLLING. niri already reports an `output` field
    // on every workspace and the stream already parses it; this is the field
    // that was being read internally and never exported. The join key is the
    // connector name, which is exactly what Quickshell.screens[].name holds —
    // no translation table, nothing to drift.
    //
    // ⚠️ AND THE HONEST LIMIT: niri has no event for "focus moved to another
    // output" on its own. WorkspaceActivated is the only output-bearing signal,
    // and in practice moving focus to another monitor activates a workspace
    // there. Whether that is ALWAYS true is not documented and not measured, so
    // callers treat an empty string as "no opinion, show everywhere" rather
    // than as "nowhere".
    readonly property string activeOutput: {
        var ws = Services.Hyprland.focusedWorkspace
        return (ws && ws.output) ? String(ws.output) : ""
    }

    // What each monitor CAN do, as opposed to what it is doing — the mode list,
    // the physical size, whether it can do VRR, and where niri has put it.
    // Quickshell.screens answers the second question and cannot answer the
    // first, which is why the displays page needs both.
    //
    // ⚠️ IT IS EMPTY UNTIL `refreshOutputs()` HAS BEEN CALLED, and `outputsKnown`
    // is the difference between "no monitors" and "not asked yet". A page that
    // conflates them draws an empty list on a machine with three screens.
    readonly property var outputs: Services.Hyprland.outputs
    readonly property bool outputsKnown: Services.Hyprland.outputsKnown

    function refreshOutputs() { Services.Hyprland.refreshOutputs() }

    // Milli-hertz to the exact string niri's `mode` wants. Its wiki is explicit
    // that the refresh rate "must match exactly, down to the three decimal
    // digits" — so 60000 has to become "60.000" and not "60".
    //
    // ⚠️ HERE RATHER THAN IN THE PAGE, because the mode string is a fact about
    // the compositor's config language, and a second copy of this in a QML file
    // is how two spellings of the same mode end up in one shell.
    function modeString(w, h, milliHz) {
        return String(w) + "x" + String(h)
             + "@" + (Number(milliHz) / 1000).toFixed(3)
    }

    // Whether the focused window fills the given screen. The screen comes from
    // the caller — a surface knows which output it is on, a service does not.
    function focusedIsFullscreen(screenW, screenH) {
        return Services.Hyprland.isFullscreen(Services.Hyprland.focusedWindow, screenW, screenH)
    }

    function focusWorkspace(idx) { Services.Hyprland.focusWorkspace(idx) }
    function focusWindow(id) { Services.Hyprland.focusWindow(id) }
    function toggleOverview() { Services.Hyprland.toggleOverview() }
    function moveWindowToWorkspace(windowId, wsIdx) {
        Services.Hyprland.moveWindowToWorkspace(windowId, wsIdx)
    }
    // B33 · a named monitor, and optionally a workspace index on it.
    function moveWindowToMonitor(windowId, output, wsIdx) {
        Services.Hyprland.moveWindowToMonitor(windowId, output, wsIdx)
    }
    function focusMonitor(output) { Services.Hyprland.focusMonitor(output) }
}
