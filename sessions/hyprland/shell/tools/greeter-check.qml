// Build the login screen's face, headless, and say whether it survived.
//
//   BUCHHWIN_TOOL=greeter-check QT_QPA_PLATFORM=offscreen qs -p shell
//
// ⚠️ THE SAME GAP AS THE LOCK SCREEN, ONE STEP WORSE. `tests/smoke.sh` starts
// the SHELL; the greeter is a different process (`BUCHHWIN_MODE=greeter`) run by
// a different USER from a different copy of this tree. Every suite in the
// project could be green with a login screen that does not come up — and a lock
// screen that does not come up is an inconvenience, while a login screen that
// does not come up is a machine you cannot get into. tests/lock.sh exists
// because two faults lived behind exactly this gap for four rounds.
//
// ⚠️ IT BUILDS GreeterFace, NOT GreeterScreen. GreeterScreen creates layer
// surfaces on every monitor, which on a machine running a desktop means
// covering it with a login prompt. The face is where all the content and all
// the bindings are.
//
// ⚠️ AND IT NEVER CALLS `begin()`. That opens a greetd session, and a tool that
// starts an authentication conversation on a build machine is a tool that hangs
// in CI waiting for a password nobody can see. The identifiers inside the key
// handler are covered by tests/greeter-idents.sh, which reads rather than runs.
//
// ⚠️ greetd IS NOT EXPECTED TO BE THERE. `Greetd.available` is false anywhere
// that is not an actual greeter session — including CI, including a normal
// desktop. That is not a failure and must not be reported as one; what IS
// checked is that the face says so out loud instead of showing an empty box.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property string report: ""
    property int failures: 0

    FileView { id: out; path: "/tmp/buchhwin-greeter-check.txt" }
    function note(s) { root.report += s + "\n"; out.setText(root.report) }
    function ok(what, good) {
        if (good) root.note("  ok    " + what)
        else { root.failures++; root.note("  FAIL  " + what) }
    }

    // One frame, so the singletons exist before the face asks them anything.
    // The component is created FROM the timer, so there is nothing to race.
    Timer {
        running: true
        interval: 250
        onTriggered: root.run()
    }

    function run() {
        root.note("buchhwin greeter-check")

        var comp = Qt.createComponent("../ui/greeter/GreeterFace.qml")
        if (comp.status === Component.Error) {
            root.failures++
            root.note("  FAIL  GreeterFace does not compile:\n" +
                      String(comp.errorString()).replace(/^/gm, "          "))
            root.finish()
            return
        }
        root.ok("GreeterFace compiles", comp.status === Component.Ready)

        var face = comp.createObject(root)
        root.ok("GreeterFace builds", face !== null)
        if (face === null) {
            root.note("          " + String(comp.errorString()))
            root.finish()
            return
        }

        // ⚠️⚠️ AGAINST A FIXTURE, NOT AGAINST THIS MACHINE — and the previous
        // version of this block is why. It read the real /etc/passwd and asked
        // only "is there at least one human", on the stated grounds that the
        // file "is readable in every environment this runs in, including a bare
        // container". Readable, yes. Containing a PERSON, no: the `qml` lane
        // runs in `container: fedora:44`, which has no account at UID >= 1000,
        // so the face correctly reported "No users found" and three checks went
        // red over the machine instead of over the code.
        //
        // ⚠️ AND THE WEAK QUESTION WAS THE OTHER HALF OF THE FAULT. "At least
        // one" passes on any developer laptop no matter what the filter does —
        // it would have passed with the UID test deleted, and with the nologin
        // test deleted, because a laptop has a human either way. A fixture can
        // ask what the filter is actually for: who is KEPT OUT.
        var seam = Quickshell.env("BUCHHWIN_PASSWD_FAKE") || ""
        root.ok("it was pointed at a passwd fixture, not at this machine",
                seam.length > 0)

        var names = []
        if (Array.isArray(face.users))
            for (var i = 0; i < face.users.length; i++)
                names.push(String(face.users[i].name))

        // The fixture is tests/fixtures/passwd — three lines, each one a
        // mistake this filter can make.
        root.ok("it found exactly the one human in the fixture",
                names.length === 1 && names[0] === "tester")
        root.ok("the system account below UID 1000 is left out",
                names.indexOf("sysacct") < 0)
        root.ok("the account with /sbin/nologin is left out",
                names.indexOf("noshell") < 0)
        root.ok("it has a user selected",
                String(face.user) === "tester")
        // GECOS is comma-separated and only the first field is the name. A
        // filter that hands back the whole field puts "Test Person,,,," on the
        // login screen, which looks like a corrupt file and is not.
        root.ok("the display name comes from GECOS, first field only",
                String(face.realName) === "Test Person")

        root.ok("it starts closed, before any key", face.asking === false)
        root.ok("`ask` exists and is callable", typeof face.ask === "function")
        root.ok("`begin` exists and is callable", typeof face.begin === "function")
        root.ok("`submit` exists and is callable", typeof face.submit === "function")
        root.ok("`selectUser` exists and is callable",
                typeof face.selectUser === "function")

        // The session scan is asynchronous — FolderListModel populates after
        // this frame — so what is checked here is the MECHANISM, not the
        // result. tests/greeter.sh reads the log for the scan's own complaint.
        root.ok("`sessions` is a list", Array.isArray(face.sessions))

        // ⚠️ THE FALLBACK IS A CHECK, NOT A COMFORT. If nothing can be read
        // from /usr/share/wayland-sessions the face must still offer something
        // to launch AND say that it is guessing — an empty picker with no
        // message is the failure mode that looks like a working greeter.
        face.sessions = []
        face.finishSessionScan()
        root.ok("with no session files it falls back to one",
                face.sessions.length === 1)
        root.ok("and it says so rather than pretending",
                face.statusIsError === true && String(face.status).length > 0)

        face.destroy()
        root.finish()
    }

    function finish() {
        root.note(root.failures === 0
                  ? "greeter-check: all good"
                  : "greeter-check: " + root.failures + " check(s) failed")
        Qt.callLater(Qt.quit)
    }
}
