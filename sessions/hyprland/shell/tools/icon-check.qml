// Do the icon names the shell uses actually exist in the icon font?
//
//   BUCHHWIN_ICONS=/tmp/names.txt BUCHHWIN_TOOL=icon-check \
//   QT_QPA_PLATFORM=offscreen qs -p shell
//
// This is not a question a linter can answer: `text: "logout"` is valid QML,
// valid QString, and renders — as the letters l-o-g-o-u-t. Fedora ships
// "Material Icons Round", the older set, and half the names people reach for
// are from "Material Symbols". Measured cost of finding that out on screen:
// one missing icon and one wrong one shipped in the session menu.
//
// The measurement is the width. A resolved ligature is a single glyph, about
// 0.7 em wide; an unresolved name is rendered letter by letter and comes out
// several times wider. At a 100 px font the two are never close: 68–92 px
// against 500 px for `logout` and 700 px for `restart_alt`.
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

Scope {
    id: root

    FileView { id: out; path: "/tmp/buchhwin-icon-check.txt" }
    FileView {
        id: input
        path: Quickshell.env("BUCHHWIN_ICONS") || "/tmp/buchhwin-icon-names.txt"
        blockLoading: true
        printErrors: true
    }

    TextMetrics { id: m; font.family: Theme.fontIcon; font.pixelSize: 100 }

    // ⚠️⚠️ THE SECOND FONT, AND WITHOUT IT THIS TOOL IS BLIND TO A THIRD OF THE
    // NOTCH. Everything above measures Material Icons Round; the three status
    // symbols come from a subset of Microsoft's Fluent set instead (B37), and a
    // Fluent code point handed to the Material metrics is simply not there —
    // which would report every one of them as broken, or, if the threshold were
    // loosened to let them through, would stop catching Material names too.
    //
    // ⚠️ AND A MISSING GLYPH HERE FAILS DIFFERENTLY. Material names are
    // LIGATURES: the fallback is the word spelled out, several hundred pixels
    // wide. A Fluent name is a bare code point, and its fallback is tofu — one
    // box, roughly the width of a real glyph. So width alone cannot answer;
    // `inFont` is what says whether the family really has the character.
    FontMetrics { id: fluentFm; font.family: Theme.fontFluent }
    TextMetrics { id: fm; font.family: Theme.fontFluent; font.pixelSize: 100 }

    Timer {
        running: true
        interval: 400
        onTriggered: {
            var names = input.text().trim().split("\n").filter(function (n) {
                return n.trim().length > 0
            })
            var s = "icon font: " + Theme.fontIcon + "\n"
            var bad = 0
            for (var i = 0; i < names.length; i++) {
                var n = names[i].trim()
                m.text = n
                var w = m.width
                // 160 px is far above any real glyph and far below any
                // two-letter fallback, so the threshold never has to be tuned.
                if (w < 160) {
                    s += "  ok    " + n + "\n"
                } else {
                    s += "  FAIL  " + n + " — not in this font (" +
                         Math.round(w) + " px, a glyph is ~70)\n"
                    bad++
                }
            }
            s += (bad === 0 ? "all " + names.length + " icon names resolve\n"
                            : bad + " icon name(s) do not exist\n")

            // ------------------------------------------------ the Fluent side
            var pts = (Quickshell.env("BUCHHWIN_FLUENT") || "")
                      .split(",").filter(function (p) { return p.trim().length > 0 })
            if (pts.length > 0) {
                s += "\nfluent font: " + Theme.fontFluent + "\n"
                // ⚠️ IS THE FAMILY EVEN THERE? Without this the whole block
                // would report every point as missing on a machine where the
                // font simply is not installed — a true statement about the
                // wrong thing, and the sort of finding that sends somebody
                // looking at the code. Exit 2 territory, not exit 1.
                if (!fluentFm.font.family || fluentFm.font.family !== Theme.fontFluent) {
                    s += "  SKIP  " + Theme.fontFluent + " is not installed here\n"
                } else {
                    for (var j = 0; j < pts.length; j++) {
                        var hex = pts[j].trim()
                        var ch = String.fromCharCode(parseInt(hex, 16))
                        fm.text = ch
                        // ⚠️ `inFont` RATHER THAN A WIDTH. A missing Fluent glyph
                        // draws tofu, which is about the width of a real one —
                        // the width test that works for Material ligatures would
                        // pass every single missing point here.
                        if (fm.font.family === Theme.fontFluent && fm.width > 0
                            && fm.advanceWidth > 0 && fm.tightBoundingRect.width > 1) {
                            s += "  ok    U+" + hex + "\n"
                        } else {
                            s += "  FAIL  U+" + hex + " — not in " + Theme.fontFluent + "\n"
                            bad++
                        }
                    }
                    s += "  " + pts.length + " fluent glyph(s) checked\n"
                }
            }
            out.setText(s)
            Qt.callLater(Qt.quit)
        }
    }
}
