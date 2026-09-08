// What unit is IdleMonitor.timeout in, and does it arrive at all?
//
//   BUCHHWIN_TOOL=idle-probe qs -p shell
//
// ⚠️ IT MUST RUN AGAINST A REAL COMPOSITOR. ext-idle-notify is a Wayland
// protocol, so QT_QPA_PLATFORM=offscreen answers nothing here — this is the one
// probe in the toolbox that needs the session it is asking about.
//
// The question is not rhetorical. The type registration says `timeout` is a
// double and says nothing else; the Wayland protocol underneath counts
// MILLISECONDS, and Quickshell may or may not pass them through. Getting it
// wrong by a factor of a thousand is the difference between "lock after five
// minutes" and "lock after three tenths of a second", and it is not the kind of
// thing to find out on his machine at the wrong moment.
//
// So: ask for 3, and see when it answers.
//   fires after about 3 s     -> seconds
//   fires immediately         -> milliseconds
//   never fires               -> the protocol is not reaching us at all
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../services" as Services

Scope {
    id: root

    property double started: 0
    property string report: ""

    FileView { id: out; path: "/tmp/buchhwin-idle-probe.txt" }
    function note(s) { root.report += s + "\n"; out.setText(root.report) }

    IdleMonitor {
        id: monitor
        enabled: true
        timeout: 3
        // ⚠️ Off for the probe, on in the real service. An inhibitor held by a
        // video player would otherwise make "it never fired" ambiguous between
        // "the unit is wrong" and "something asked us not to".
        respectInhibitors: false

        onIsIdleChanged: {
            var dt = (Date.now() - root.started) / 1000
            root.note("  isIdle = " + monitor.isIdle
                      + "   after " + dt.toFixed(2) + " s")
            if (monitor.isIdle) {
                root.note(dt < 0.5  ? "  VERDICT  milliseconds — 3 fired at once"
                        : dt < 10   ? "  VERDICT  seconds — 3 fired at about 3 s"
                                    : "  VERDICT  neither; something else is going on")
                Qt.callLater(Qt.quit)
            }
        }
    }

    // ⚠️ AND THE SECOND QUESTION, which is the one that fails silently. Every
    // delay in Idle.qml is guarded against `Config.power` being null during
    // shell construction, and the guard returns 0 — which also means "never".
    // So a group that never resolves does not throw, does not warn, and simply
    // switches the whole page off. Printing the numbers is how that is caught.
    Component.onCompleted: {
        root.started = Date.now()
        root.note("buchhwin idle-probe: asked for timeout = 3")
        root.note("  on battery:      " + Services.Idle.onBattery)
        root.note("  dim after:       " + Services.Idle.dimAfter + " s")
        root.note("  screen off after " + Services.Idle.screenOffAfter + " s")
        root.note("  lock after:      " + Services.Idle.lockAfter + " s")
        root.note("  suspend after:   " + Services.Idle.suspendAfter + " s")
        root.note(Services.Idle.screenOffAfter > 0
                  ? "  -> the delays resolved"
                  : "  -> ALL ZERO: Config.power never resolved, everything is off")
    }

    // A backstop, so the probe cannot sit there forever if nothing arrives.
    Timer {
        running: true
        interval: 12000
        onTriggered: {
            root.note("  isIdle never became true within 12 s")
            root.note("  VERDICT  the idle protocol did not reach us")
            Qt.quit()
        }
    }
}
