// B33 · the Shift+Alt+Tab map, checked as arithmetic.
//
//   BUCHHWIN_TOOL=monitors-check QT_QPA_PLATFORM=offscreen qs -p shell
//
// ⚠️ WHY IT IS A PURE FUNCTION AND NOT A PAGE TO PHOTOGRAPH. "One column per
// monitor" is a statement about machines with two and three screens, and until
// today the lab VM had one — so the only way to check it would have been his
// laptop. `WorkspaceGeometry.monitorColumns` takes the output map, the workspace
// list and the windows and answers with the columns, so every case below runs
// headless on any machine.
//
// ⚠️ THE FIXTURE IS MEASURED, NOT INVENTED. The shape is what
// `hyprctl -j monitors` and `hyprctl -j workspaces` really answered on the lab
// VM once it had two heads:
//
//   Virtual-1  logical x=0    1280x800
//   Virtual-2  logical x=1280 5120x2160
//   workspaces id=1 idx=1 Virtual-1 · id=2 idx=2 Virtual-1 · id=3 idx=1 Virtual-2
//
// ⚠️⚠️ AND THE ONE FACT THE WHOLE PAGE HANGS ON: `idx` COUNTS PER OUTPUT. idx=1
// exists on BOTH screens above. A column therefore has to pick the workspace
// with that index *on its own monitor*, and a global sort by idx — which is what
// a global sort by index gives — mixes the two together.
import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

Scope {
    id: root

    property string report: ""
    property int failures: 0

    function note(s) { root.report += s + "\n"; out.setText(root.report) }
    function ok(what, good) {
        if (good) root.note("  ok    " + what)
        else { root.failures++; root.note("  FAIL  " + what) }
    }

    FileView { id: out; path: "/tmp/buchhwin-monitors-check.log" }

    Component.onCompleted: root.run()

    readonly property var outputs: ({
        "Virtual-2": { name: "Virtual-2",
                       logical: { x: 1280, y: 0, width: 5120, height: 2160, scale: 1 } },
        "Virtual-1": { name: "Virtual-1",
                       logical: { x: 0, y: 0, width: 1280, height: 800, scale: 1 } }
    })

    readonly property var spaces: [
        { id: 1, idx: 1, output: "Virtual-1", is_active: true,  is_focused: true },
        { id: 2, idx: 2, output: "Virtual-1", is_active: false, is_focused: false },
        { id: 3, idx: 1, output: "Virtual-2", is_active: true,  is_focused: false }
    ]

    // ⚠️ `at` AND `size`, IN GLOBAL COORDINATES — the shape `hyprctl -j clients`
    // really returns. This fixture used to carry `layout.pos_in_scrolling_layout`
    // and `layout.tile_size`, which is what the previous compositor reported and
    // what common/WorkspaceGeometry.qml was rebuilt away from. Nothing read those
    // fields any more, so every box came out with w=0, was skipped as
    // geometry-less, and the window list arrived empty — the check below then
    // threw on `a[0].w`, `run()` never reached `finish()`, and the tool hung
    // until the timeout killed it. A stale fixture does not fail, it hangs.
    //
    // ⚠️ GLOBAL IS THE POINT, not an accident of how it was written down.
    // Virtual-2 starts at x=1280, so its window sits at x=1280 in the layout and
    // at x=0 on its own screen. That difference is what `layoutWindows`' origin
    // arguments are for, and a fixture written in per-screen coordinates cannot
    // tell a shell that subtracts the origin from one that forgets to.
    readonly property var wins: [
        { id: 10, app_id: "kitty", workspace_id: 1,
          at: [24, 33], size: [1232, 734] },
        { id: 11, app_id: "brave", workspace_id: 2,
          at: [0, 0], size: [640, 800] },
        { id: 12, app_id: "code",  workspace_id: 3,
          at: [1280, 0], size: [2560, 2160] }
    ]

    function run() {
        var G = WorkspaceGeometry

        // ------------------------------------- 1 · one column per monitor
        var cols = G.monitorColumns(root.outputs, root.spaces, root.wins, 1, null)
        root.ok("one column per monitor", cols.length === 2)

        // ⚠️ LEFT TO RIGHT AS THEY REALLY STAND. The fixture deliberately lists
        // Virtual-2 FIRST in the map, because a JS object's iteration order is
        // not a layout: the columns have to come out in `logical.x` order or the
        // picture lies about which screen is where.
        root.ok("columns are ordered by their real position, not by map order",
                cols[0].output === "Virtual-1" && cols[1].output === "Virtual-2")

        // ------------------------------------- 2 · the same index everywhere
        //
        // His instruction: "auf allen monitoren wird der aktuelle workspace     // english-ok: the request, quoted
        // genommen".                                                            // english-ok: the request, quoted
        root.ok("every column opens on the wanted index",
                cols[0].ws.idx === 1 && cols[1].ws.idx === 1)

        // ⚠️⚠️ AND THEY ARE DIFFERENT WORKSPACES. Both have idx 1 and they are
        // ids 1 and 3 — if this ever comes back as the same id, the page has
        // fallen back to a global list and both columns show one screen.
        root.ok("…and those are two different workspaces, not one seen twice",
                cols[0].ws.id === 1 && cols[1].ws.id === 3)

        // ------------------------------------- 3 · the windows of that one
        root.ok("each column carries only its own workspace's windows",
                cols[0].windows.length === 1 && cols[0].windows[0].id === 10
                && cols[1].windows.length === 1 && cols[1].windows[0].id === 12)

        // ------------------------------------- 4 · an index a monitor lacks
        //
        // Virtual-2 has no idx=2. The compositor creates workspaces on demand, so this is
        // the normal state of a second screen rather than an edge case.
        var two = G.monitorColumns(root.outputs, root.spaces, root.wins, 2, null)
        root.ok("a monitor without that index still shows something",
                two[1].ws !== null && two[1].ws !== undefined)
        root.ok("…namely its own last workspace, not another monitor's",
                two[1].ws.output === "Virtual-2")
        root.ok("…while the monitor that has it shows exactly that one",
                two[0].ws.idx === 2 && two[0].ws.id === 2)

        // ------------------------------------- 5 · per-column override
        //
        // His example, and the reason a single shared index is not enough:
        // "wenn das fenster aufm 2. workspace ist aufm linken monitor, das ich   // english-ok: the request, quoted
        // den dann aufm 3ten workspace aufm rechten monitor ziehen kann".        // english-ok: the request, quoted
        var mixed = G.monitorColumns(root.outputs, root.spaces, root.wins, 1,
                                     { "Virtual-1": 2 })
        root.ok("one column can be paged without moving the others",
                mixed[0].ws.idx === 2 && mixed[1].ws.idx === 1)

        // ------------------------------------- 6 · the geometry is per screen
        //
        // ⚠️ EACH COLUMN IS DRAWN AGAINST ITS OWN OUTPUT. Virtual-1 is 1280 wide
        // and holds a 1232 window; Virtual-2 is 5120 and holds a 2560 one. Half
        // of one screen must look like half, whichever screen it is — that is
        // B53, and it is the thing a shared denominator would destroy.
        // ⚠️ THE ORIGIN IS PASSED, because ui/notch/pages/MonitorsPage.qml passes
        // it. A check that calls the function with fewer arguments than the only
        // caller does is checking a shape nothing runs.
        var a = G.layoutWindows(cols[0].windows,
                                cols[0].logical.width, cols[0].logical.height,
                                cols[0].logical.x, cols[0].logical.y)
        var b = G.layoutWindows(cols[1].windows,
                                cols[1].logical.width, cols[1].logical.height,
                                cols[1].logical.x, cols[1].logical.y)

        // ⚠️ THAT THERE IS A BOX AT ALL COMES FIRST, and it is not a formality.
        // `layoutWindows` drops a window it cannot measure, so a fixture whose
        // fields have gone stale yields an EMPTY list — and the two checks below
        // then throw on `a[0]` rather than failing. A thrown check leaves `run()`
        // without ever reaching `finish()`, which is a hang and not a red line.
        if (!a.length || !b.length) {
            root.ok("both screens placed their window (a=" + a.length
                    + ", b=" + b.length + ")", false)
            root.note("  --    do the fixture windows still carry `at` and `size`?")
            root.finish()
            return
        }

        root.ok("a nearly-full window on the small screen reads as nearly full",
                a[0].w > 0.95)
        root.ok("a half window on the big screen reads as half",
                Math.abs(b[0].w - 0.5) < 0.0005)

        // ⚠️ AND IT IS PLACED AT THE LEFT EDGE OF ITS OWN SCREEN. Hyprland
        // reports positions in the GLOBAL layout, so this window's `at` is 1280
        // — where Virtual-2 begins. Drawn without subtracting that origin it
        // lands a quarter of the way into its own thumbnail, and the picture is
        // wrong in a way that looks deliberate.
        root.ok("…at the left edge of that screen, not offset by where it starts",
                Math.abs(b[0].x) < 0.0005)

        // ------------------------------------- 7 · nothing to draw
        root.ok("no outputs yields no columns",
                G.monitorColumns(null, root.spaces, root.wins, 1, null).length === 0)
        var noWs = G.monitorColumns(root.outputs, [], [], 1, null)
        root.ok("outputs without workspaces still give a column each",
                noWs.length === 2 && !noWs[0].ws && noWs[0].windows.length === 0)

        root.finish()
    }

    function finish() {
        if (root.failures > 0)
            root.note("ABORT " + root.failures + " failed")
        else
            root.note("done")
        Qt.callLater(Qt.quit)
    }
}
