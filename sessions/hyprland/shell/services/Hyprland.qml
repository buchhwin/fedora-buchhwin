pragma Singleton

// Hyprland backend for the compositor-neutral shell API.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool available: false
    property var workspaces: []
    property var windows: []
    property var outputs: ({})
    property bool outputsKnown: false
    property bool configFailed: false
    property string keyboardLayout: ""
    property string activeOutput: ""
    property var focusedWindowId: ""
    property int focusedWorkspaceId: -1

    readonly property var orderedWorkspaces: workspaces
    readonly property var focusedWindow: {
        for (var i = 0; i < windows.length; i++)
            if (windows[i].id === focusedWindowId) return windows[i]
        return null
    }
    readonly property var focusedWorkspace: {
        for (var i = 0; i < workspaces.length; i++)
            if (workspaces[i].id === focusedWorkspaceId) return workspaces[i]
        return null
    }

    // ⚠️ THE SEAM tests/displays.sh HANDS ITS FIXTURE THROUGH, and it belongs on
    // this side rather than in the check. Under QT_QPA_PLATFORM=offscreen there
    // is no compositor to ask and no Wayland output to find, so the displays
    // page gets built against zero screens: every card hangs off a Repeater over
    // this map, none of it is instantiated, and tests/pages.sh reports green
    // over code that has never run once.
    //
    // `BUCHHWIN_OUTPUTS_FAKE` carries the monitor map as JSON in exactly the
    // shape the parser below emits. Read HERE because that shape is this file's
    // business: a fixture assembled inside the tool could drift away from what
    // this file produces and nothing would catch it. Same seam Gpu.qml has as
    // `BUCHHWIN_GPU_FAKE`.
    //
    // ⚠️ AND IT SWITCHES THE REAL QUERY OFF ENTIRELY. A fake that races a live
    // poll is worse than no fake: the fixture lands, the timer fires a second
    // later, hyprctl answers nothing, and which of the two the page saw comes
    // down to timing. With the variable set, hyprctl is never asked.
    readonly property string outputsFake: Quickshell.env("BUCHHWIN_OUTPUTS_FAKE") || ""

    function refresh() {
        if (root.outputsFake.length) { root.loadFakeOutputs(); return }
        if (!query.running) query.running = true
    }
    function refreshOutputs() { refresh() }

    function loadFakeOutputs() {
        if (root.outputsKnown)
            return
        try {
            root.outputs = JSON.parse(root.outputsFake)
        } catch (e) {
            // Loud, and only once: outputsKnown stays false, so a caller can
            // still tell "no monitors" from "never answered".
            console.warn("BUCHHWIN_OUTPUTS_FAKE is not valid JSON:", String(e))
            return
        }
        root.outputsKnown = true
        root.available = true
    }

    // ⚠️ EVERY MODE THE MONITOR REPORTS, not just the one it is running.
    //
    // `hyprctl -j monitors` gives `availableModes` as strings — "3840x2160@
    // 59.99700Hz" — and this file used to synthesise a one-entry list out of the
    // CURRENT width, height and refreshRate instead. ui/settings/pages/
    // DisplaysPage.qml builds its resolution and refresh-rate menus out of this
    // list, so on real hardware both offered exactly one choice: the mode
    // already in use. The page looked finished and could not change anything.
    //
    // ⚠️ A pure function so it can be checked headless, the same reason
    // common/WorkspaceGeometry.qml is one. Returns { modes, current }, where
    // `current` is an INDEX into `modes` — that is what the page reads.
    //
    // ⚠️ NOTHING IS MARKED PREFERRED, and that is deliberate. Hyprland does not
    // report which mode the display prefers; the previous code set the flag on
    // the only entry it made, which put "(preferred)" beside whatever happened
    // to be on. A label that is guessed is worse than a label that is absent.
    function modesFrom(m) {
        var w = Number(m.width || 0), h = Number(m.height || 0)
        var hz = Math.round(Number(m.refreshRate || 0) * 1000)
        var modes = []
        var raw = m.availableModes || []
        for (var i = 0; i < raw.length; i++) {
            var f = /^(\d+)x(\d+)@([0-9.]+)Hz$/.exec(String(raw[i]))
            if (!f)
                continue
            modes.push({ width: Number(f[1]), height: Number(f[2]),
                         refresh_rate: Math.round(Number(f[3]) * 1000),
                         is_preferred: false })
        }

        // ⚠️ WITHIN A HERTZ, because the two numbers come from different places:
        // `refreshRate` is a float and the mode string is text, and 59.99700Hz
        // against 59.997 has already rounded apart by one milli-hertz on real
        // hardware. A stricter match would leave `current` at -1 on exactly the
        // screens that have several modes at one resolution.
        var current = -1
        for (i = 0; i < modes.length; i++)
            if (modes[i].width === w && modes[i].height === h
                && Math.abs(modes[i].refresh_rate - hz) <= 1) {
                current = i
                break
            }

        // ⚠️ A LIST THAT LEAVES OUT THE MODE IN USE IS NOT A LIST. If the strings
        // could not be parsed, or the running mode is somehow not among them,
        // the measured one goes in front rather than the page offering a set of
        // choices that excludes what is on the screen right now.
        if (current < 0) {
            modes.unshift({ width: w, height: h, refresh_rate: hz,
                            is_preferred: false })
            current = 0
        }
        return { modes: modes, current: current }
    }

    function run(args) {
        action.command = ["hyprctl", "dispatch"].concat(args)
        action.running = true
    }
    function focusWorkspace(idx) { run(["workspace", String(idx)]) }
    function focusWindow(id) { run(["focuswindow", "address:" + String(id)]) }
    function moveWindowToWorkspace(id, idx) {
        run(["movetoworkspacesilent", String(idx) + ",address:" + String(id)])
    }
    function moveWindowToMonitor(id, output, wsIdx) {
        run(["movewindow", "mon:" + String(output) + ",address:" + String(id)])
        if (wsIdx !== undefined) moveWindowToWorkspace(id, wsIdx)
    }
    function focusMonitor(output) { run(["focusmonitor", String(output)]) }
    function isFullscreen(win, screenW, screenH) {
        return win !== null && (win.fullscreen === true || win.fullscreen === 1)
    }

    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

    Process {
        id: action
        onExited: root.refresh()
    }

    Process {
        id: query
        command: ["sh", "-c", "jq -n --argjson c \"$(hyprctl -j clients)\" --argjson w \"$(hyprctl -j workspaces)\" --argjson m \"$(hyprctl -j monitors)\" --argjson a \"$(hyprctl -j activewindow)\" '{clients:$c,workspaces:$w,monitors:$m,active:$a}'"]
        stdout: StdioCollector { id: queryText }
        onExited: function(code) {
            if (code !== 0) { root.available = false; return }
            var data
            try { data = JSON.parse(String(queryText.text || "{}")) }
            catch (e) { root.available = false; return }

            var ws = [], wins = [], outs = ({})
            var rawWs = data.workspaces || []
            var rawClients = data.clients || []
            var rawMonitors = data.monitors || []
            var activeAddress = data.active && data.active.address
                                ? String(data.active.address) : ""

            for (var i = 0; i < rawMonitors.length; i++) {
                var m = rawMonitors[i]
                var modes = root.modesFrom(m)
                outs[String(m.name)] = {
                    name: String(m.name), make: String(m.make || ""),
                    model: String(m.model || ""), serial: String(m.serial || ""),
                    physical_size: [Number(m.physicalWidth || 0), Number(m.physicalHeight || 0)],
                    modes: modes.modes,
                    current_mode: modes.current, vrr_supported: Number(m.vrr || 0) > 0,
                    vrr_enabled: Number(m.vrr || 0) > 0,
                    logical: { x: Number(m.x || 0), y: Number(m.y || 0),
                               width: Number(m.width || 0) / Number(m.scale || 1),
                               height: Number(m.height || 0) / Number(m.scale || 1),
                               scale: Number(m.scale || 1), transform: "Normal" }
                }
                if (m.focused) root.activeOutput = String(m.name)
                if (m.focused) root.focusedWorkspaceId = Number(m.activeWorkspace.id)
            }

            rawWs.sort(function(a, b) { return Number(a.id) - Number(b.id) })
            for (i = 0; i < rawWs.length; i++) {
                var w = rawWs[i]
                ws.push({ id: Number(w.id), idx: Number(w.id), name: String(w.name || w.id),
                          output: String(w.monitor || ""), is_focused: Number(w.id) === root.focusedWorkspaceId,
                          is_active: Number(w.id) === root.focusedWorkspaceId, is_urgent: false })
            }
            for (i = 0; i < rawClients.length; i++) {
                var c = rawClients[i]
                var address = String(c.address || "")
                var wid = address
                // ⚠️ `at` AND `size` ARE THE POINT OF THIS OBJECT, and they were
                // missing. common/WorkspaceGeometry.qml was written against
                // the compositor, which reported a position inside a SCROLLING layout
                // (`layout.pos_in_scrolling_layout`, `layout.tile_size`).
                // Hyprland has no such concept and reports the real geometry
                // instead, so the thumbnails fell back to a straight line of
                // equal boxes and silently stopped resembling the screen.
                //
                // Both arrive from `hyprctl -j clients` as [x, y] and [w, h] in
                // layout pixels, which is what the geometry code wants anyway.
                var at = c.at || [0, 0]
                var size = c.size || [0, 0]
                wins.push({ id: wid, workspace_id: Number(c.workspace ? c.workspace.id : -1),
                            title: String(c.title || ""), app_id: String(c.class || c.initialClass || ""),
                            is_focused: address === activeAddress, is_urgent: false,
                            is_floating: !!c.floating, fullscreen: Number(c.fullscreen || 0),
                            at: [Number(at[0] || 0), Number(at[1] || 0)],
                            size: [Number(size[0] || 0), Number(size[1] || 0)] })
                if (address === activeAddress) root.focusedWindowId = wid
            }
            root.workspaces = ws
            root.windows = wins
            root.outputs = outs
            root.outputsKnown = true
            root.available = true
        }
    }
}
