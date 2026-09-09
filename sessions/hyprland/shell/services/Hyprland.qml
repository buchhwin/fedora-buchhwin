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

    function refresh() {
        if (!query.running) query.running = true
    }
    function refreshOutputs() { refresh() }

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
                var refresh = Math.round(Number(m.refreshRate || 0) * 1000)
                outs[String(m.name)] = {
                    name: String(m.name), make: String(m.make || ""),
                    model: String(m.model || ""), serial: String(m.serial || ""),
                    physical_size: [Number(m.physicalWidth || 0), Number(m.physicalHeight || 0)],
                    modes: [{ width: Number(m.width || 0), height: Number(m.height || 0),
                              refresh_rate: refresh, is_preferred: true }],
                    current_mode: 0, vrr_supported: Number(m.vrr || 0) > 0,
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
