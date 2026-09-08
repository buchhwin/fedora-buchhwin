// What does services/Installed actually find on THIS machine?
//
//   BUCHHWIN_TOOL=installed-check QT_QPA_PLATFORM=offscreen qs -p shell
//
// ⚠️ IT EXISTS BECAUSE THE ANSWER DIFFERED FROM THE SHELL COMMAND. Running the
// service's own `sh -c` by hand on his laptop returns four cursor themes, 109
// fonts and 99 keyboard layouts. In the settings window every one of those
// lists was empty. Two answers to the same question, and no way to tell which
// half was lying — the service builds its lists inside a running desktop, and
// there was no way to ask it what it got.
//
// ⚠️ `_done` IS SET EVEN ON AN EMPTY ANSWER, deliberately (see Installed.qml),
// so a single failed run sticks for the life of the shell and every page that
// opens afterwards shows nothing. That is exactly the state this reproduces.
import QtQuick
import Quickshell
import Quickshell.Io
import "../services" as Services

Scope {
    id: root

    // ⚠️ A FILE, NOT console.log — the same shape every other tool here uses.
    // A headless `qs` swallows console output where the caller cannot reliably
    // get at it; the first version of this tool printed six lines that never
    // appeared anywhere, which looks exactly like a tool that did not run.
    property string report: ""
    FileView { id: out; path: "/tmp/buchhwin-installed-check.txt" }
    function note(s) { root.report += s + "\n"; out.setText(root.report) }

    Component.onCompleted: Services.Installed.scan()

    // ⚠️ A TIMER, NOT `onReady`. The service sets `_done` from a Process's
    // onExited, and a tool that quits on the first tick never gives that
    // process a chance to be spawned at all. Three seconds is far more than a
    // fork needs and far less than a person waits.
    Timer {
        running: true
        interval: 3000
        onTriggered: {
            var I = Services.Installed
            note("available: " + I.available)
            note("cursorThemes: " + I.cursorThemes.length
                 + (I.cursorThemes.length ? "  [" + I.cursorThemes.join(", ") + "]" : ""))
            note("fonts: " + I.fonts.length)
            note("monoFonts: " + I.monoFonts.length)
            note("keyboardLayouts: " + I.keyboardLayouts.length)
            note("keyboardVariants: " + I.keyboardVariants.length)
            note("renderDevices: " + I.renderDevices.length
                 + (I.renderDevices.length
                    ? "  [" + I.renderDevices.map(function (d) { return d.path + " (" + d.driver + ")" }).join(", ") + "]"
                    : ""))
            note(I.available && I.fonts.length > 0 ? "ok" : "ABORT: the lists are empty")
            Qt.callLater(Qt.quit)
        }
    }
}
