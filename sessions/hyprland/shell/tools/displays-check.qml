// Build the Displays page against three monitors that are not there.
//
//   BUCHHWIN_TOOL=displays-check QT_QPA_PLATFORM=offscreen qs -p shell
//
// ⚠️⚠️ WHY A FIXTURE AND NOT THE REAL SCREENS. Under `QT_QPA_PLATFORM=offscreen`
// there are no Wayland outputs at all — this project has already spent a session
// on "the screen list is broken (monitors=0)", which was the platform and not a
// bug. So tests/pages.sh builds this page with ZERO screens, every card stays
// uninstantiated, and the suite reports green over code that has never run.
// That is precisely the shape rule 4 calls worse than no check at all.
//
// And the cases that matter cannot be produced by any machine here anyway:
// three screens, two of them sharing a resolution at different refresh rates,
// one at a scale that makes its logical size differ from its mode.
//
// The fixture is the JSON `niri msg -j outputs` really returns — measured on
// hardware, field for field — so the fixture and the real thing cannot drift
// into different shapes. See services/Hyprland.qml for the seam.
//
// ⚠️ WHAT THIS CHECKS IS ARITHMETIC AND WIRING, NOT LOOKS. Whether the page is
// pleasant to use is a screenshot and a person. Whether a 4K screen at scale 2
// is placed at x=1920 rather than x=3840 is a number, and a number is what has
// been getting this wrong.
import QtQuick
import Quickshell
import Quickshell.Io
import "../services" as Services

Scope {
    id: root

    property string report: ""
    property int failures: 0

    FileView { id: out; path: "/tmp/buchhwin-displays-check.log" }
    function note(s) { root.report += s + "\n"; out.setText(root.report) }
    function ok(what, good) {
        if (good) root.note("  ok    " + what)
        else { root.failures++; root.note("  FAIL  " + what) }
    }

    Timer {
        running: true
        interval: 250
        onTriggered: root.run()
    }

    function run() {
        root.note("buchhwin displays-check")

        // ------------------------------------------------- the fixture arrived
        Services.Compositor.refreshOutputs()
        var o = Services.Compositor.outputs
        var names = []
        for (var k in o)
            names.push(k)
        root.ok("the fixture is three screens (got " + names.length + ")",
                names.length === 3)
        if (names.length !== 3) {
            root.note("  --    is BUCHHWIN_OUTPUTS_FAKE set, and is it valid JSON?")
            root.finish()
            return
        }

        // ------------------------------------------------------- the mode maths
        //
        // ⚠️ MILLI-HERTZ, AND THREE DECIMALS EXACTLY. niri's wiki: the refresh
        // rate "must match exactly, down to the three decimal digits, to what
        // you see in niri msg outputs". 60000 has to become "60.000", not "60" —
        // and `bhctl doctor` printed 74994 as "75" for months because a `%.3g`
        // looked close enough.
        root.ok("60000 mHz reads as 60.000 Hz",
                Services.Compositor.modeString(1920, 1080, 60000) === "1920x1080@60.000")
        root.ok("74994 mHz reads as 74.994 Hz, not 75",
                Services.Compositor.modeString(1280, 800, 74994) === "1280x800@74.994")

        // ------------------------------------------------------------- the page
        var c = Qt.createComponent("../ui/settings/pages/DisplaysPage.qml")
        if (c.status === Component.Error) {
            root.ok("the page compiles", false)
            root.note("          " + String(c.errorString()).replace(/\n/g, "\n          "))
            root.finish()
            return
        }
        var page = c.createObject(root)
        if (page === null) {
            root.ok("the page builds", false)
            root.note("          " + String(c.errorString()))
            root.finish()
            return
        }
        root.ok("the page builds", true)

        // ⚠️ THE RESET DECLARATION. This page has no SettingRows at all, so
        // "reset this page" gathers nothing from it — without `resetKeys` the
        // button would report success having changed nothing. tests/reset-page.sh
        // checks the same thing from the other side.
        root.ok("it declares what reset has to remove",
                page.resetKeys !== undefined && page.resetKeys.length === 1
                && String(page.resetKeys[0]) === "outputs")

        // ------------------------------------------------------ resolution list
        //
        // The fixture gives DP-1 five modes at four distinct resolutions —
        // 3840x2160 appears three times, at 60.000, 59.940 and 50.000. A list
        // built straight from `modes` would offer the same line three times,
        // which is what the real hardware does too.
        var res = page._resolutions("DP-1")
        root.ok("duplicate resolutions collapse (4 of 6 modes)", res.length === 4)
        root.ok("the biggest is first", res.length > 0 && res[0].value === "3840x2160")

        var rates = page._rates("DP-1", "3840x2160")
        root.ok("that resolution offers three rates", rates.length === 3)
        root.ok("the fastest is first", rates.length > 0 && rates[0].value === "60.000")
        root.ok("a rate carries three decimals", rates.length > 1
                && rates[1].value === "59.940")

        // ⚠️ AND A RESOLUTION WITH ONE RATE STILL LISTS IT. An empty dropdown
        // beside a screen that is plainly working reads as broken.
        root.ok("a single-rate resolution lists one",
                page._rates("DP-1", "1280x720").length === 1)

        // --------------------------------------------------- what it is doing now
        //
        // `current_mode` is an INDEX into `modes`, not a description. Reading it
        // as a mode gives an integer where a resolution should be.
        root.ok("the current resolution comes off the index",
                page._currentRes("DP-1") === "3840x2160")
        root.ok("and so does the current rate",
                page._currentRate("DP-1") === "60.000")

        // ---------------------------------------------------------- arrangement
        //
        // ⚠️⚠️ LOGICAL PIXELS, NOT MODE PIXELS. HDMI-A-1 in the fixture is
        // 3840x2160 at scale 2.0, so its logical size is 1920x1080 and its
        // neighbour to the right belongs at x=1920. Sizing by the mode puts it
        // at 3840, which leaves a gap the width of a screen — and niri, finding
        // no overlap, accepts it silently.
        var placed = page.placed
        root.ok("every screen is placed (got " + placed.length + ")", placed.length === 3)
        var byName = {}
        for (var i = 0; i < placed.length; i++)
            byName[placed[i].name] = placed[i]
        root.ok("a 4K screen at scale 2 is 1920 logical pixels wide",
                byName["HDMI-A-1"] !== undefined && byName["HDMI-A-1"].w === 1920)
        root.ok("a 1:1 screen keeps its mode width",
                byName["DP-1"] !== undefined && byName["DP-1"].w === 3840)

        // ------------------------------------------------- B71 · no gap, ever
        //
        // "ich hab den rechten zu weit nach rechts geschoben dann war da ne     // english-ok: the report, quoted
        // Lücke … und ich konnte nicht mehr auf den anderen Monitor". A gap is  // english-ok: the report, quoted
        // a legal arrangement as far as niri is concerned, so nothing downstream
        // rejects it — the pointer simply has no shared edge to cross and the
        // far screen is unreachable from the near one.
        //
        // ⚠️ THESE ARE ARITHMETIC CHECKS ON THE REAL FUNCTIONS, not on a copy of
        // them. The lab VM has one screen, so dragging cannot be measured here
        // at all; what CAN be measured is that `_settle` never returns a set
        // that fails `_allReachable`. Dragging on real hardware stays his to
        // confirm, and that is written down rather than implied.
        var arr = page.arrangement
        if (!arr) {
            root.ok("the arrangement is reachable for checking", false)
        } else {
            // Straight sanity first: the fixture as it stands is connected.
            root.ok("the fixture's own layout is connected",
                    arr._allReachable(placed))

            // A corner kiss is NOT contact. Two 1920x1080 screens meeting only
            // at (1920,1080) share no edge to move a pointer along.
            var a = { name: "a", x: 0,    y: 0,    w: 1920, h: 1080 }
            var kiss = { name: "b", x: 1920, y: 1080, w: 1920, h: 1080 }
            root.ok("a corner touch does not count as a shared edge",
                    !arr._sharesEdge(a, kiss))

            var flush = { name: "b", x: 1920, y: 0, w: 1920, h: 1080 }
            root.ok("a flush neighbour does share an edge",
                    arr._sharesEdge(a, flush))

            var apart = { name: "b", x: 2400, y: 0, w: 1920, h: 1080 }
            root.ok("a screen with a gap beside it shares no edge",
                    !arr._sharesEdge(a, apart))

            // And the one that matters: drop a screen far away and the settle
            // has to pull it back against a neighbour rather than leave it out
            // there. Dragged to x=9000, y=9000 — nowhere near anything.
            var far = arr._settle(placed[1].name, 9000, 9000)
            root.ok("a screen dropped far away is pulled back", far !== null)
            if (far !== null) {
                var rects = []
                for (var f = 0; f < far.length; f++) {
                    var src = byName[far[f].name]
                    rects.push({ name: far[f].name, x: far[f].x, y: far[f].y,
                                 w: src ? src.w : 0, h: src ? src.h : 0 })
                }
                root.ok("and the result has no unreachable screen",
                        arr._allReachable(rects))
            }
        }

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
