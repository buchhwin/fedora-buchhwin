// B77 · B78 · the Super+Tab map, checked as arithmetic.
//
//   BUCHHWIN_TOOL=workspaces-check QT_QPA_PLATFORM=offscreen qs -p shell
//
// ⚠️ WHY THIS EXISTS AT ALL. The geometry used to live in four bindings inside a
// Repeater delegate, where the only way to read it was a pointer and a
// screenshot — and the lab VM has one screen, so "three windows side by side"
// could not be produced there on demand. `WorkspacesPage.layoutWindows` is a
// pure function for exactly that reason, and this drives it directly.
//
// ⚠️ THE FIXTURE IS A MEASUREMENT, NOT AN INVENTION. Every number below was read
// off the running compositor with three windows open:
//
//   hyprctl -j clients | jq '.[].layout'
//     pos_in_scrolling_layout [1,1] [2,1] [3,1]
//     tile_size               1232x734 each
//   hyprctl -j monitors        Virtual-1 logical 1280x800
//
// That is the case he reported — three windows, each nearly the full width of a
// 1280 screen, which as plain shares adds up to 2.9 boxes.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property string report: ""
    property int failures: 0

    function note(s) { root.report += s + "\n"; out.setText(root.report) }
    function ok(what, good) {
        if (good) root.note("  ok    " + what)
        else { root.failures++; root.note("  FAIL  " + what) }
    }
    // Fractions, so an exact compare would be a coin toss on the last bit.
    function near(a, b) { return Math.abs(a - b) < 0.0005 }

    FileView { id: out; path: "/tmp/buchhwin-workspaces-check.log" }

    Component.onCompleted: root.run()

    function run() {
        var comp = Qt.createComponent("../ui/notch/pages/WorkspacesPage.qml")
        if (comp.status === Component.Error) {
            root.ok("the page compiles: " + comp.errorString(), false)
            root.finish()
            return
        }
        var page = comp.createObject(null)
        if (!page) {
            root.ok("the page builds", false)
            root.finish()
            return
        }
        root.ok("the page builds", true)

        // ⚠️ THE FIXTURE SPEAKS THE NEW SHAPE, AND IT TAKES A POSITION.
        // It used to build a [column, row] index and a tile size, because that
        // is all the previous compositor reported — a scrolling layout has no
        // single frame to give coordinates in. Hyprland reports the real
        // rectangle, so a window here is an `at` and a `size`, exactly as
        // `hyprctl -j clients` hands them over.
        //
        // ⚠️ x IS EXPLICIT RATHER THAN DERIVED FROM THE COLUMN. The first
        // attempt computed it as (col - 1) * w, which is only right when every
        // window is the same width — and case 3 below is deliberately three
        // windows of two different widths, so it put the middle one 160 px to
        // the left of where it belongs and failed a check that was correct.
        function win(x, y, w, h, id) {
            return { id: id, app_id: "x", workspace_id: 1, is_focused: false,
                     at: [x, y], size: [w, h] }
        }

        // ------------------------------------------- 1 · the reported case
        var three = [win(0, 0, 1232, 734, 1), win(1232, 0, 1232, 734, 2),
                     win(2464, 0, 1232, 734, 3)]
        var p = page.layoutWindows(three, 1280, 800)
        root.ok("three windows produce three rectangles", p.length === 3)

        // ⚠️ THE ONE THAT MATTERS. Nothing may end past the right edge — that is
        // "voll abgeschnitten" expressed as a number.
        var worst = 0
        for (var i = 0; i < p.length; i++)
            worst = Math.max(worst, p[i].x + p[i].w)
        root.ok("nothing reaches past the box (max right edge " + worst.toFixed(3) + ")",
                worst <= 1.0005)

        // Three equal columns share the width equally, in the compositor's order.
        root.ok("the three columns are equal thirds",
                root.near(p[0].w, 1 / 3) && root.near(p[1].w, 1 / 3)
                && root.near(p[2].w, 1 / 3))
        root.ok("and they are placed left to right",
                root.near(p[0].x, 0) && root.near(p[1].x, 1 / 3)
                && root.near(p[2].x, 2 / 3))

        // ------------------------------- 2 · B53 survives: half is still half
        //
        // ⚠️ THIS IS THE CHECK THAT STOPS THE OBVIOUS WRONG FIX. Clamping each
        // tile to the box would also stop the overflow — and would make a
        // half-width window and a full-width one the same size, which is the
        // thing B53 was asked for.
        var half = [win(0, 0, 640, 800, 1), win(640, 0, 640, 800, 2)]
        var ph = page.layoutWindows(half, 1280, 800)
        root.ok("two half-width windows are half the box each",
                root.near(ph[0].w, 0.5) && root.near(ph[1].w, 0.5))

        var lone = page.layoutWindows([win(0, 0, 640, 800, 1)], 1280, 800)
        root.ok("a single half-width window stays HALF, not stretched",
                root.near(lone[0].w, 0.5))

        // -------------------------------- 2b · B82 · the gaps are the same size
        //
        // His report: "beim normalen supertab stimmen links und rechts die       // english-ok: the report, quoted
        // abstände nicht zwischen fenster und rand, der ist rechts zu groß".     // english-ok: the report, quoted
        //
        // ⚠️ AND THE ANSWER IS A PHOTOGRAPH, NOT A PREFERENCE. `grim -o
        // Virtual-1` on the lab VM with one window: the compositor leaves about 24 px of
        // wallpaper on the LEFT and about 24 px on the RIGHT of a 1232-wide
        // window on a 1280 screen. It centres. The thumbnail used to start every
        // row at x = 0, so all of the slack collected on one side and the picture
        // showed a layout the compositor never produces.
        //
        // ⚠️ THE MECHANISM CHANGED AND THE PROPERTY DID NOT. The old geometry
        // code CENTRED the row itself, because the previous compositor reported
        // no position and the slack had to be shared by hand. Hyprland reports
        // where the window actually is, gaps included — so the fixture now says
        // "1232 wide at x = 24 on a 1280 screen", which is what `hyprctl -j
        // clients` returns for the photographed case, and the check is that the
        // thumbnail reproduces it rather than invents it.
        var narrow = page.layoutWindows([win(24, 24, 1232, 734, 1)], 1280, 800)
        var gapL = narrow[0].x
        var gapR = 1 - (narrow[0].x + narrow[0].w)
        root.ok("a window narrower than the screen is centred, not packed left",
                root.near(gapL, gapR) && gapL > 0.01)

        // ⚠️ AND IT MAY NOT COST B77. When the workspace scrolls past its screen
        // the denominator is the content itself, so there is no slack to share
        // and the row still fills the box edge to edge.
        var over = page.layoutWindows(
            [win(0, 0, 1232, 734, 1), win(1232, 0, 1232, 734, 2),
             win(2464, 0, 1232, 734, 3)],
            1280, 800)
        root.ok("an overflowing workspace still fills the box, with no gap added",
                root.near(over[0].x, 0)
                && root.near(over[2].x + over[2].w, 1))

        // ------------------- 3 · B78 · a small window is drawn small, in place
        //
        // His example: the settings window, open, "nur in der Mitte des Screens  // english-ok: the report, quoted
        // aber halt nur so groß wie das settings menu". A narrow middle column   // english-ok: the report, quoted
        // between two wide ones.
        var mid = [win(0, 0, 480, 800, 1), win(480, 0, 320, 400, 2), win(800, 0, 480, 800, 3)]
        var pm = page.layoutWindows(mid, 1280, 800)
        root.ok("a middle window narrower than its neighbours is drawn narrower "
                + "(" + pm[1].w.toFixed(3) + " vs " + pm[0].w.toFixed(3) + ")",
                pm[1].w < pm[0].w)
        root.ok("the small window is half the box's height, not all of it",
                root.near(pm[1].h, 0.5))
        root.ok("it starts after the first column",
                root.near(pm[1].x, 480 / 1280))
        // ⚠️ AND THE THREE TOGETHER FIT THE SCREEN — 480+320+480 = 1280 — so the
        // denominator is the screen here, not the content. That is the other
        // half of the rule, and without this case a version that always divided
        // by the content total would pass everything above.
        root.ok("a workspace that fits its screen fills the box exactly",
                root.near(pm[2].x + pm[2].w, 1))

        // ------------------------------------------- 4 · rows stack downwards
        var stacked = [win(0, 0, 1280, 400, 1), win(0, 400, 1280, 400, 2)]
        var ps = page.layoutWindows(stacked, 1280, 800)
        root.ok("two rows in one column share the column's width",
                root.near(ps[0].w, 1) && root.near(ps[1].w, 1))
        root.ok("the second row sits below the first",
                root.near(ps[0].y, 0) && root.near(ps[1].y, 0.5))

        // ------------------------------------------------- 5 · the empty cases
        root.ok("no windows produces no rectangles",
                page.layoutWindows([], 1280, 800).length === 0)
        // ⚠️ A zero-sized output must not divide by zero and hand back NaN — a
        // NaN width is an invisible tile, which reads as a missing window.
        var zero = page.layoutWindows(three, 0, 0)
        root.ok("a zero-sized output still yields finite numbers",
                zero.length === 3 && isFinite(zero[0].w) && zero[0].w > 0)

        page.destroy()
        root.finish()
    }

    function finish() {
        if (root.failures > 0)
            root.note("ABORT: " + root.failures + " failed")
        else
            root.note("done")
        Qt.callLater(Qt.quit)
    }
}
