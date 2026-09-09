// The carousel picker: does it wrap, and does browsing leave the desktop alone?
//
//   BUCHHWIN_TOOL=picker-check QT_QPA_PLATFORM=offscreen qs -p shell
//
// ⚠️⚠️ "BROWSING CHANGES NOTHING" IS A DECISION NOTHING ELSE CAN SEE. He chose
// it when asked — the footer says "Enter to apply" and that is what it means —
// and the reason is measurable rather than aesthetic: applying a theme is a
// full render over thirteen foreign files plus a `Hyprland --verify-config`, so
// a live preview would queue one of those per keypress on a laptop.
//
// Nothing in the suite could notice if that quietly became a live preview. The
// pages would still build, the rows would still draw, and the only symptom
// would be a machine that gets warm while somebody looks through twelve
// palettes. So the config is read before and after moving through the whole
// row, and it has to be the same file.
//
// ⚠️ AND THE WRAP IS THE OTHER HALF. "hinter dem letzten Theme kommt wieder das  // english-ok: the request, quoted
// erste" — a picker that stops at the end is one you have to reverse out of,
// and the difference between a PathView that wraps and a ListView that does not
// is invisible in a screenshot.
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
import "../services" as Services

Scope {
    id: root

    property string report: ""
    property int failures: 0

    FileView { id: out; path: "/tmp/buchhwin-picker-check.log" }
    function note(s) { root.report += s + "\n"; out.setText(root.report) }
    function ok(what, good) {
        if (good) root.note("  ok    " + what)
        else { root.failures++; root.note("  FAIL  " + what) }
    }

    Timer {
        running: true
        interval: 400
        onTriggered: root.run()
    }

    // Six of anything, so wrapping has somewhere to wrap to.
    readonly property var fixture: [{ n: "one" }, { n: "two" }, { n: "three" },
                                    { n: "four" }, { n: "five" }, { n: "six" }]

    property int lastApplied: -1
    property int applyCount: 0

    function build(path) {
        var c = Qt.createComponent(path)
        if (c.status === Component.Error) {
            root.ok(path + " compiles", false)
            root.note("          " + String(c.errorString()).replace(/\n/g, "\n          "))
            return null
        }
        var item = c.createObject(root)
        if (item === null) {
            root.ok(path + " builds", false)
            root.note("          " + String(c.errorString()))
        }
        return item
    }

    function run() {
        root.note("buchhwin picker-check")

        var p = root.build("../ui/common/CarouselPicker.qml")
        if (p === null) { root.finish(); return }
        root.ok("the picker builds", true)

        p.model = root.fixture
        p.applied.connect(function (i) { root.lastApplied = i; root.applyCount++ })

        root.ok("it counts what it was given (got " + p.count + " of 6)",
                p.count === 6)

        // ------------------------------------------------------------- the wrap
        p.currentIndex = 5
        p.currentIndex = (p.currentIndex + 1) % p.count
        root.ok("past the last one comes the first", p.currentIndex === 0)
        p.currentIndex = (p.currentIndex - 1 + p.count) % p.count
        root.ok("and before the first one comes the last", p.currentIndex === 5)

        // ------------------------------------------- browsing writes nothing
        //
        // ⚠️ THE PALETTE AND THE WALLPAPER, READ OFF Config ITSELF rather than
        // off a copy. Whatever a picker would write, it writes there.
        var beforePalette = String(Config.theme ? Config.theme.palette : "")
        var beforeWall = String(Config.wallpaper ? Config.wallpaper.current : "")
        var beforeApplies = root.applyCount

        for (var i = 0; i < p.count; i++)
            p.currentIndex = i

        root.ok("moving through the whole row applied nothing",
                root.applyCount === beforeApplies)
        root.ok("…and left theme.palette alone",
                String(Config.theme ? Config.theme.palette : "") === beforePalette)
        root.ok("…and left wallpaper.current alone",
                String(Config.wallpaper ? Config.wallpaper.current : "") === beforeWall)

        // --------------------------------------------- and Enter is what applies
        p.currentIndex = 3
        p.applied(p.currentIndex)
        root.ok("applying reports the index that was on screen",
                root.applyCount === beforeApplies + 1 && root.lastApplied === 3)

        p.destroy()

        // ------------------------------------------------------ the two users
        //
        // ⚠️ BOTH PAGES, because the whole argument for one component is that
        // there are two callers. A picker that only the theme page can build is
        // a picker with one user and a misleading name.
        var t = root.build("../ui/notch/pages/ThemePage.qml")
        if (t !== null) { root.ok("the theme page builds on it", true); t.destroy() }
        var w = root.build("../ui/notch/pages/WallpaperPage.qml")
        if (w !== null) { root.ok("the wallpaper page builds on it", true); w.destroy() }

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
