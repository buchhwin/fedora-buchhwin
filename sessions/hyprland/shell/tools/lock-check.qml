// Build the lock screen's face, headless, and say whether it survived.
//
//   BUCHHWIN_TOOL=lock-check QT_QPA_PLATFORM=offscreen qs -p shell
//
// ⚠️ NOTHING ELSE BUILDS THIS FILE. `tests/smoke.sh` starts the SHELL, and the
// lock screen is a different process entirely (`BUCHHWIN_MODE=lock`), so every
// suite could be green with a lock screen that does not come up at all. Two
// faults lived there for four rounds behind exactly that gap: a handler writing
// to `field` when the field is called `input`, and an avatar ring still
// pointing at `Theme.glassRimTop` after the rim token was deleted. `qmllint-qt6`
// was run against both and had nothing to say.
//
// ⚠️ IT BUILDS LockFace, NOT LockScreen. LockScreen owns a `WlrSessionLock`,
// and creating one of those does not check a lock screen — it LOCKS THE
// SESSION, on whatever machine happens to be running the test. The face is
// where all the content and all the bindings are; the shell around it is
// fifteen lines.
//
// ⚠️ AND CREATION IS ONLY HALF THE ANSWER. A binding that names something that
// does not exist throws when it is EVALUATED and leaves the property at its
// default — the object is built, the check is happy, and the ring is invisible.
// That is precisely how the second fault survived. So this tool reports what it
// built, and tests/lock.sh reads the process's stderr for QML warnings out of
// ui/lock/ as the other half of the same check. Neither is sufficient alone.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property string report: ""
    property int failures: 0

    FileView { id: out; path: "/tmp/buchhwin-lock-check.txt" }
    function note(s) { root.report += s + "\n"; out.setText(root.report) }
    function ok(what, good) {
        if (good) root.note("  ok    " + what)
        else { root.failures++; root.note("  FAIL  " + what) }
    }

    // One frame, so singletons (Theme, Config, Scheme) exist before the face
    // asks them anything. Not a guess at how long something takes: the
    // component is created FROM the timer, so there is nothing to race with.
    Timer {
        running: true
        interval: 250
        onTriggered: root.run()
    }

    function run() {
        root.note("buchhwin lock-check")

        var comp = Qt.createComponent("../ui/lock/LockFace.qml")
        if (comp.status === Component.Error) {
            root.failures++
            root.note("  FAIL  LockFace does not compile:\n" +
                      String(comp.errorString()).replace(/^/gm, "          "))
            root.finish()
            return
        }
        root.ok("LockFace compiles", comp.status === Component.Ready)

        var face = comp.createObject(root)
        root.ok("LockFace builds", face !== null)
        if (face === null) {
            root.note("          " + String(comp.errorString()))
            root.finish()
            return
        }

        // The parts the brief names, asked for by the properties that drive
        // them rather than by walking the tree: a name that has been renamed
        // answers `undefined` here, which is the whole point.
        root.ok("it knows who is logged in", String(face.user).length > 0)
        root.ok("it starts closed, before any key",
                face.asking === false)
        root.ok("`ask` exists and is callable",
                typeof face.ask === "function")
        root.ok("`submit` exists and is callable",
                typeof face.submit === "function")
        root.ok("it can report that it unlocked",
                typeof face.unlocked === "function")

        // ⚠️ `ask()` IS NOT CALLED. It starts PAM, and a tool that starts an
        // authentication conversation on a build machine is a tool that will
        // one day hang in CI waiting for a password prompt nobody can see.
        // What `ask()` reaches — the identifiers inside the key handler — is
        // covered by tests/lock-idents.sh, which reads rather than runs.

        face.destroy()
        root.finish()
    }

    function finish() {
        root.note(root.failures === 0
                  ? "lock-check: all good"
                  : "lock-check: " + root.failures + " check(s) failed")
        Qt.callLater(Qt.quit)
    }
}
