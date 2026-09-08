// Derive the palette from the current wallpaper, on demand.
//
//   BUCHHWIN_TOOL=wallpaper-palette QT_QPA_PLATFORM=offscreen qs -p shell
//
// The shell does this by itself whenever the wallpaper changes — see
// Scheme.qml, which owns both the derivation and the file. This tool exists for
// the two moments there is no shell running: the installer's first pass, and a
// repair from `bhctl` after somebody has deleted the generated file.
//
// It therefore contains no colour logic of its own. It selects the derived
// palette, waits for Scheme to finish, and reports what happened. A second copy
// of the derivation here is exactly how the old project ended up with six
// colour vocabularies that disagreed.

import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
import "../config"
import "../services" as Services
import "../common"

Scope {
    id: root

    property string report: ""
    function note(s) { report += s + "\n"; log.setText(report) }

    FileView { id: log; path: "/tmp/buchhwin-wallpaper-palette.log" }

    // Scheme only derives for the palette it is actually showing, so asking it
    // to work means selecting that palette. Assigning breaks the binding to the
    // config, which is the documented escape hatch for exactly this.
    Component.onCompleted: {
        Scheme.name = "wallpaper"
        // ⚠️ Touching the folder HERE, not where it is reported. QML builds a
        // singleton on first access, so reading `count` in the report would be
        // the line that starts the directory listing — and it would answer 0
        // every time. This project has paid for that lesson twice already.
        void Services.Wallpaper.count
    }

    WaitFor {
        // Done means: the loaded file describes the wallpaper that is set.
        // Failure is also done — a refused wallpaper is an answer, not a hang.
        condition: Config.settled &&
                   ((Scheme.ready && Scheme.loadedSource === Scheme.wantedSource) ||
                    Scheme.failure.length > 0)

        // Reading an image, not a file. See render.qml for the same number.
        timeoutMs: 12000

        onTimedOut: {
            note("ABORT: the palette was not derived in time")
            note("  wallpaper: " + Scheme.wantedSource)
            Qt.callLater(Qt.quit)
        }

        onReady: {
            if (Scheme.failure.length) {
                // The previous scheme is left in place on purpose.
                note("REFUSED: " + Scheme.failure)
                note("  the current palette is left alone")
                Qt.callLater(Qt.quit)
                return
            }

            note("buchhwin wallpaper-palette — " + Scheme.loadedSource)
            note("  seed #" + Scheme.colors.blue +
                 "  surface #" + Scheme.colors.base +
                 "  text #" + Scheme.colors.text)
            // Reported, and checked by tests/wallpaper.sh, because it is the
            // one thing nothing else exercises headlessly: the picker reads the
            // folder through pathAt(), and pathAt() asking for the wrong role
            // name returned an empty string for EVERY image without an error.
            // A folder with images that lists no paths is the whole picker
            // quietly doing nothing.
            note("  folder: " + Services.Wallpaper.count + " images" +
                 (Services.Wallpaper.count > 0
                  ? ", first " + Services.Wallpaper.pathAt(0)
                  : ""))
            note("done — set theme.palette to \"wallpaper\" to use it")
            Qt.callLater(Qt.quit)
        }
    }
}
