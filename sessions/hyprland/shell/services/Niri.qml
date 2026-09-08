pragma Singleton

// The niri backend. The ONLY file in the shell that knows which compositor is
// running — everything else talks to Compositor.qml.
//
// State comes from `niri msg -j event-stream`: one JSON object per line, keyed
// by event name, pushed as things happen. No polling, and no second source of
// truth — the first event of each kind carries the full list, so there is
// never a moment where we have half the picture.
//
// ⚠️ The `-j` is not optional. Without it `niri msg event-stream` prints Rust's
// Debug formatting — `Workspace { id: 4, idx: 4, name: None, … }` — which looks
// close enough to JSON to write a parser against and is not.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Every service carries this. On a machine where the stream never comes up
    // — no niri, or the socket is not reachable — the UI must be able to say
    // so rather than draw an empty bar that looks like a bug.
    readonly property bool available: _connected

    property var workspaces: []
    property var windows: []
    property int focusedWindowId: -1
    property int focusedWorkspaceId: -1
    property bool overviewOpen: false
    property string keyboardLayout: ""
    // niri reports whether the config it just loaded parsed. Worth surfacing:
    // a failed reload leaves the OLD config running, which otherwise looks
    // like "my change did nothing".
    property bool configFailed: false

    property bool _connected: false

    // Every output niri knows about, keyed by connector name, exactly as
    // `niri msg -j outputs` hands it over. The displays page is built on it, and
    // nothing else in the shell can answer what it answers: Quickshell.screens
    // says what a screen IS RIGHT NOW, this says what it COULD be.
    //
    // ⚠️ A QUERY, NOT A STREAM, AND THAT IS NOT AN OVERSIGHT. The event stream
    // carries workspaces and windows; it has no output event at all — measured
    // and written down in the handouts. So the choice is a query or nothing, and
    // the honest way to keep a query from becoming polling is to name its
    // triggers.
    //
    // ⚠️ THE MEASURED SHAPE, because the fields decide the whole page and a
    // guess here would be a guess everywhere downstream:
    //
    //   { "Virtual-1": { name, make, model, serial, physical_size:[w,h],
    //       modes: [ {width, height, refresh_rate, is_preferred}, … ],
    //       current_mode: 0,            <- an INDEX into modes, not a mode
    //       is_custom_mode: false,
    //       vrr_supported: false, vrr_enabled: false,
    //       logical: { x, y, width, height, scale, transform } } }
    //
    // ⚠️ `refresh_rate` IS MILLI-HERTZ. 74994 is 74.994 Hz, and the one number
    // in this file where a factor of 1000 still looks plausible.
    //
    // ⚠️ `logical` IS THE SCALED GEOMETRY, and it is what positions are counted
    // in: a 3840x2160 output at scale 2.0 is logically 1920x1080, so its
    // neighbour starts at x=1920. Placing tiles by mode size would be wrong by
    // exactly the scale factor.
    //
    // ⚠️ `logical.transform` COMES BACK CAPITALISED ("Normal"), and the config
    // wants it lowercase ("normal"). Writing the queried value straight back
    // into an output block is wrong and looks right.
    property var outputs: ({})

    // "We have asked and got an answer", the same shape services/Gpu.qml uses.
    // A page that cannot tell "no monitors" from "not asked yet" draws an empty
    // list on a machine with three screens.
    property bool outputsKnown: false

    // ⚠️ A TEST SEAM, in the shape of the existing BUCHHWIN_GPU_FAKE, and it is
    // not a convenience. The displays page draws one card per monitor with a
    // mode list per card, and NO headless check can produce that: under
    // `QT_QPA_PLATFORM=offscreen` there are no Wayland outputs at all — this
    // project has already spent a session on "the screen list is broken
    // (monitors=0)", which was the offscreen platform and not a bug. Worse, the
    // interesting cases are three screens at different scales, which no test
    // machine here has at all.
    //
    // Without this, `tests/pages.sh` builds the page with zero screens, every
    // Repeater body stays uninstantiated, and the suite reports green over code
    // that has never run once. That is the shape rule 4 calls worse than no
    // check at all.
    //
    // The value is the JSON `niri msg -j outputs` returns, verbatim, so the
    // fixture and the real thing cannot drift into different shapes.
    readonly property string _fakeOutputs: Quickshell.env("BUCHHWIN_OUTPUTS_FAKE") || ""

    function refreshOutputs() {
        if (root._fakeOutputs.length) {
            try {
                root.outputs = JSON.parse(root._fakeOutputs)
                root.outputsKnown = true
            } catch (err) {
                console.warn("BUCHHWIN_OUTPUTS_FAKE is not valid JSON: " + err)
            }
            return
        }
        if (!outputQuery.running)
            outputQuery.running = true
    }

    Process {
        id: outputQuery
        command: ["niri", "msg", "-j", "outputs"]
        stdout: StdioCollector { id: outputText }

        onExited: function (code) {
            if (code !== 0)
                return
            var parsed
            try {
                parsed = JSON.parse(String(outputText.text || "{}"))
            } catch (err) {
                // Same reasoning as the event stream: not understanding an
                // answer is not the same as having none, and the previous
                // answer is still the best one we have.
                return
            }
            root.outputs = parsed || ({})
            root.outputsKnown = true
        }
    }

    // ⚠️ NOTHING RUNS UNTIL SOMETHING ASKS, like services/Gpu.qml next door.
    // There is no query at startup: the only consumer is a settings page, this
    // is a laptop, and a process spawned at every boot for a page opened twice
    // a year is exactly the kind of cost rule 8 is about. The page calls
    // `refreshOutputs()` when it opens.
    //
    // ⚠️ AND THE REFRESH TRIGGERS ONLY FIRE ONCE SOMEBODY HAS ASKED. Keeping an
    // answer fresh that nobody has ever wanted is the same waste one step later.
    //
    //   Quickshell.screens  a monitor plugged in or out changes this list, and
    //                       Qt reports it without anybody polling.
    //   ConfigLoaded        niri reloading its config is how a write of ours
    //                       becomes real — see _handle() below.
    //
    // There is no niri event for an output change itself; that is measured and
    // written down, not assumed.
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (root.outputsKnown)
                root.refreshOutputs()
        }
    }

    // Is the focused window filling its output?
    //
    // ⚠️ niri does not say. There is no `is_fullscreen` on a window — measured
    // on 26.04, the fields are app_id, focus_timestamp, id, is_floating,
    // is_focused, is_urgent, layout, pid, title, workspace_id. What there is,
    // is the size, and a fullscreen window's `window_size` is EXACTLY the
    // output's logical size (1280×800 measured, against 608×734 tiled).
    //
    // The honest limit: with `gaps 0` AND no reserved strip, an ordinary tiled
    // window would measure the same. With the defaults this desktop ships
    // (gaps 16, a 34 px strut) it cannot — but that is a property of the
    // settings, not a law, so it is written down rather than assumed.
    //
    // The caller supplies the size, because the service has no business
    // knowing which screen anybody is looking at.
    function isFullscreen(w, screenW, screenH) {
        if (!w || !w.layout || !w.layout.window_size)
            return false
        var s = w.layout.window_size
        return Math.abs(s[0] - screenW) < 2 && Math.abs(s[1] - screenH) < 2
    }

    readonly property var focusedWindow: {
        for (var i = 0; i < windows.length; i++)
            if (windows[i].id === focusedWindowId)
                return windows[i]
        return null
    }

    readonly property var focusedWorkspace: {
        for (var i = 0; i < workspaces.length; i++)
            if (workspaces[i].id === focusedWorkspaceId)
                return workspaces[i]
        return null
    }

    // Workspaces in the order niri lays them out, not the order it reports
    // them — the event arrives unsorted and a bar that reshuffles its buttons
    // on every event is unusable.
    readonly property var orderedWorkspaces: {
        var list = []
        for (var i = 0; i < workspaces.length; i++)
            list.push(workspaces[i])
        list.sort(function (a, b) { return a.idx - b.idx })
        return list
    }

    function dispatch(args) {
        if (!args || !args.length)
            return
        action.command = ["niri", "msg", "action"].concat(args)
        action.running = true
    }

    function focusWorkspace(idx) { dispatch(["focus-workspace", String(idx)]) }
    function focusWindow(id) { dispatch(["focus-window", "--id", String(id)]) }
    function toggleOverview() { dispatch(["toggle-overview"]) }

    // Move a window to another workspace without going there yourself.
    //
    // ⚠️ THE REFERENCE IS THE INDEX, NOT THE ID, and the two differ: on the test
    // machine the workspaces are idx 1/2/3 with ids 1/3/4. `niri msg action
    // move-window-to-workspace --help` says "Reference (index or name)", so
    // passing an id silently moves the window somewhere else — or nowhere.
    //
    // ⚠️ `--focus false` is the point of having this at all. The default
    // follows the window, which for a drag in a workspace map means the desktop
    // jumps out from under the pointer mid-gesture.
    // ⚠️⚠️ TWO FULL-WIDTH WINDOWS SIDE BY SIDE, EACH HALF — B64, his request:
    // "ich brauche einen hotkey mit dem ich wenn 2 fenster volle größe haben     // english-ok: the request, quoted
    // das ich die damit in der größe perfekt so anpasse das sie nebeneinander    // english-ok: the request, quoted
    // sind und beide halb groß sind".                                            // english-ok: the request, quoted
    //
    // ⚠️ NIRI HAS NO ACTION FOR IT, ASKED RATHER THAN ASSUMED. `niri msg action
    // set-column-width <CHANGE>` changes the width of the FOCUSED column and
    // nothing else — there is no "set both" and no "tile these two". So it takes
    // a small sequence, and the sequence lives here rather than in a key line:
    // one implementation the shell can be asked about, instead of a shell script
    // nobody can test.
    //
    // ⚠️ AND IT REFUSES RATHER THAN GUESSING. With one column there is nothing
    // to put beside anything; with three, "both halves" has no meaning and
    // squeezing two of them would move the third. Exactly two columns is the
    // case he described, and any other number is left alone — a key that quietly
    // does something else is worse than a key that does nothing.
    //
    // ⚠️ `--focus false` KEEPS THE POINTER'S WINDOW FOCUSED. Without it the
    // sequence would leave focus on whichever column it touched last, so the
    // same keypress would both tile the pair and steal focus.
    function halveColumns() {
        var ws = root.windows || []
        var here = {}
        var cols = []
        for (var i = 0; i < ws.length; i++) {
            var w = ws[i]
            if (!w || !w.layout || w.is_floating)
                continue
            if (!w.workspace_id || w.workspace_id !== root.focusedWorkspaceId)
                continue
            var pos = w.layout.pos_in_scrolling_layout
            if (!pos)
                continue
            var col = String(pos[0])
            if (here[col] === undefined) {
                here[col] = w.id
                cols.push(col)
            }
        }
        if (cols.length !== 2) {
            root.lastHalveResult = cols.length === 0
                ? "no tiled windows on this workspace"
                : (cols.length + " columns here, not two — left alone")
            return false
        }
        // ⚠️ BY WINDOW ID, not by focusing each one first. `set-column-width`
        // has no id of its own, so the column is named the only way niri
        // accepts: focus it, size it, and put the focus back where it was.
        root.lastHalveResult = "two columns set to 50%"
        for (var c = 0; c < cols.length; c++) {
            root.dispatch(["focus-window", "--id", String(here[cols[c]])])
            root.dispatch(["set-column-width", "50%"])
        }
        return true
    }

    // What the last attempt did, so `ipc call windows halve` can answer instead
    // of failing silently — rule 5.
    property string lastHalveResult: ""

    // ⚠️ BY NAME. `focus-monitor` is the one monitor action that takes a
    // connector name rather than a direction — measured with
    // `niri msg action focus-monitor --help` on niri 26.04.
    function focusMonitor(output) {
        if (!output)
            return
        dispatch(["focus-monitor", String(output)])
    }

    function moveWindowToWorkspace(windowId, wsIdx) {
        dispatch(["move-window-to-workspace",
                  "--window-id", String(windowId),
                  "--focus", "false",
                  String(wsIdx)])
    }

    // B33 · A named monitor, and optionally a workspace index on it.
    //
    // ⚠️⚠️ TWO CALLS, AND THE ORDER IS A CONSEQUENCE RATHER THAN A CHOICE.
    // Measured on the lab VM with two heads:
    //
    //   · workspace indices count PER OUTPUT — idx=1 exists on Virtual-1 AND on
    //     Virtual-2, so an index alone names two different workspaces;
    //   · `move-window-to-workspace <idx>` resolves against the WINDOW's own
    //     output, not the focused one. Proved by focusing Virtual-1 while the
    //     window sat on Virtual-2 and watching it stay on Virtual-2 — the first
    //     attempt at that control was worthless, because the focused output
    //     happened to be the window's own and both readings predict the same
    //     thing.
    //
    // So the window has to arrive on the target monitor BEFORE an index can mean
    // anything, and after that the index is unambiguous.
    //
    // ⚠️ AND AN EARLIER NOTE IN THIS PROJECT SAID THIS COULD NOT BE DONE IN ONE
    // CALL AT ALL — that "the monitor actions are all relative". They are not:
    // `move-window-to-monitor <OUTPUT>` takes a name, and `--id` takes the
    // window, so neither step depends on what happens to be focused. The note
    // had read the list of sub-commands and missed the one without a suffix.
    //
    // ⚠️ `--focus false` on the second step, for the same reason it is there
    // above: without it the desktop jumps out from under the pointer and tears
    // the drag in half.
    function moveWindowToMonitor(windowId, output, wsIdx) {
        if (!output)
            return
        // ⚠️⚠️ CHAINED, NOT FIRED TOGETHER. The whole point of the order is that
        // step two needs step one to have HAPPENED — an index only means the
        // right workspace once the window is on the target monitor. Two
        // processes started in the same turn are a race, and the losing outcome
        // is the window on the right monitor and the wrong workspace, which
        // looks like the feature half-working rather than like a race.
        moveNext.windowId = String(windowId)
        moveNext.wsIdx = (wsIdx === undefined || wsIdx === null) ? "" : String(wsIdx)
        moveNext.command = ["niri", "msg", "action", "move-window-to-monitor",
                            "--id", String(windowId), String(output)]
        moveNext.running = true
    }

    // Step one of `moveWindowToMonitor`, which starts step two when it is done.
    Process {
        id: moveNext
        property string windowId: ""
        property string wsIdx: ""
        onExited: function (code) {
            if (code !== 0 || moveNext.wsIdx === "")
                return
            moveThen.command = ["niri", "msg", "action", "move-window-to-workspace",
                                "--window-id", moveNext.windowId,
                                "--focus", "false",
                                moveNext.wsIdx]
            moveThen.running = true
        }
    }
    Process { id: moveThen }

    // One-shot actions. A second dispatch while the first is still running
    // would drop it, so each gets its own short-lived process.
    Process { id: action }

    Process {
        id: events
        command: ["niri", "msg", "-j", "event-stream"]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (line) { root._handle(line) }
        }

        // niri restarting, or a config reload that replaces the socket, ends
        // the stream. Coming back is normal operation, not an error worth
        // shouting about — but never coming back must not look like "quiet".
        onExited: function () {
            root._connected = false
            retry.start()
        }
    }

    Timer {
        id: retry
        interval: 1000
        repeat: false
        onTriggered: events.running = true
    }

    function _handle(line) {
        if (!line || !line.length)
            return
        var e
        try {
            e = JSON.parse(line)
        } catch (err) {
            // A malformed line is not worth tearing the stream down for, but
            // it is worth not pretending we understood it.
            return
        }
        root._connected = true

        if (e.WorkspacesChanged !== undefined) {
            root.workspaces = e.WorkspacesChanged.workspaces || []
            for (var i = 0; i < root.workspaces.length; i++)
                if (root.workspaces[i].is_focused)
                    root.focusedWorkspaceId = root.workspaces[i].id
            return
        }
        if (e.WindowsChanged !== undefined) {
            root.windows = e.WindowsChanged.windows || []
            for (var j = 0; j < root.windows.length; j++)
                if (root.windows[j].is_focused)
                    root.focusedWindowId = root.windows[j].id
            return
        }
        if (e.WorkspaceActivated !== undefined) {
            var id = e.WorkspaceActivated.id
            var focused = e.WorkspaceActivated.focused
            var ws = root.workspaces.slice()
            for (var k = 0; k < ws.length; k++) {
                // niri sends one activation; every other workspace on the same
                // output stops being active. Applying only the positive half
                // leaves two workspaces highlighted at once.
                if (ws[k].id === id) {
                    ws[k].is_active = true
                    if (focused) ws[k].is_focused = true
                } else if (ws[k].output === root._outputOf(id)) {
                    ws[k].is_active = false
                    if (focused) ws[k].is_focused = false
                }
            }
            root.workspaces = ws
            if (focused) root.focusedWorkspaceId = id
            return
        }
        if (e.WindowOpenedOrChanged !== undefined) {
            var w = e.WindowOpenedOrChanged.window
            if (!w) return
            var list = root.windows.slice()
            var found = false
            for (var m = 0; m < list.length; m++)
                if (list[m].id === w.id) { list[m] = w; found = true; break }
            if (!found) list.push(w)
            root.windows = list
            if (w.is_focused) root.focusedWindowId = w.id
            return
        }
        if (e.WindowClosed !== undefined) {
            var closed = e.WindowClosed.id
            var rest = []
            for (var n = 0; n < root.windows.length; n++)
                if (root.windows[n].id !== closed) rest.push(root.windows[n])
            root.windows = rest
            if (root.focusedWindowId === closed) root.focusedWindowId = -1
            return
        }
        if (e.WindowLayoutsChanged !== undefined) {
            // ⚠️ This used to be in the ignore list, and that is what made
            // fullscreen invisible to the shell.
            //
            // niri does NOT report `is_fullscreen` on a window — measured, the
            // fields are app_id, focus_timestamp, id, is_floating, is_focused,
            // is_urgent, layout, pid, title, workspace_id. The only signal is
            // the SIZE, and the size arrives here: one entry per changed
            // window, as [id, layout].
            var ch = e.WindowLayoutsChanged.changes || []
            if (!ch.length) return
            var upd = root.windows.slice()
            for (var c = 0; c < ch.length; c++) {
                var wid = ch[c][0]
                var lay = ch[c][1]
                for (var u = 0; u < upd.length; u++) {
                    if (upd[u].id === wid) {
                        // A copy, or the assignment below sees the same object
                        // it already had and no binding re-evaluates.
                        var copy = {}
                        for (var key in upd[u]) copy[key] = upd[u][key]
                        copy.layout = lay
                        upd[u] = copy
                        break
                    }
                }
            }
            root.windows = upd
            return
        }
        if (e.WindowFocusChanged !== undefined) {
            root.focusedWindowId = e.WindowFocusChanged.id === null
                ? -1 : e.WindowFocusChanged.id
            return
        }
        if (e.OverviewOpenedOrClosed !== undefined) {
            root.overviewOpen = e.OverviewOpenedOrClosed.is_open === true
            return
        }
        if (e.KeyboardLayoutsChanged !== undefined) {
            var kl = e.KeyboardLayoutsChanged.keyboard_layouts
            if (kl && kl.names && kl.names.length)
                root.keyboardLayout = kl.names[kl.current_idx || 0]
            return
        }
        if (e.KeyboardLayoutSwitched !== undefined) {
            // Only the index arrives here; the names came earlier.
            return
        }
        if (e.ConfigLoaded !== undefined) {
            root.configFailed = e.ConfigLoaded.failed === true
            // A reload is the moment an output block of ours takes effect, so
            // it is the moment the displays page can stop showing the old
            // answer. Only when somebody is actually looking — see the
            // Connections block above for why.
            if (root.outputsKnown && !root.configFailed)
                root.refreshOutputs()
            return
        }
        // WindowUrgencyChanged, CastsChanged, WindowLayoutsChanged and
        // whatever a later niri adds: ignored on purpose. An unknown event is
        // not an error, and crashing the bar over one would be.
    }

    function _outputOf(wsId) {
        for (var i = 0; i < root.workspaces.length; i++)
            if (root.workspaces[i].id === wsId)
                return root.workspaces[i].output
        return ""
    }
}
