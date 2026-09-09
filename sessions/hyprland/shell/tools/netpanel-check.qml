// Do the network and Bluetooth panels actually draw the machine's answer?
//
//   BUCHHWIN_SHELL_FAKE=1 BUCHHWIN_TOOL=netpanel-check QT_QPA_PLATFORM=offscreen qs -p shell
//
// ⚠️⚠️ THIS IS THE CHECK THE LAST TWO PANELS DID NOT HAVE, and their absence is
// the whole reason they were needed. services/Net.qml and services/Bt.qml were
// written complete — connect, disconnect, forget, the password path, the adapter
// switch — and then NOTHING CALLED ANY OF IT for months. Every structural check
// in the suite stayed green over it, because a service with no caller is not a
// broken service: it is a service nobody looks at.
//
// So the panels are asked to build, against the fixtures the two services carry
// for exactly this purpose, and to produce one row per thing in them.
//
// ⚠️ BUILDING IS NOT ENOUGH, and tests/pages.sh learnt that the hard way. A
// Repeater over an empty model builds perfectly and draws nothing. The counts
// below are what separate "the file compiles" from "the list has the networks
// in it" — the fixtures hold three of each, deliberately: one connected, one
// known-but-not, one stranger.
//
// ⚠️ AND THE FAKE MODE IS THE SERVICES' OWN. `BUCHHWIN_SHELL_FAKE` is read by
// Net, Bt, Audio, Drive and Nightlight already; this tool invents no fixture of
// its own, so the shape it checks cannot drift away from the shape the real
// path produces.
import QtQuick
import Quickshell
import Quickshell.Io
import "../services" as Services

Scope {
    id: root

    property string report: ""
    property int failures: 0

    FileView { id: out; path: "/tmp/buchhwin-netpanel-check.log" }
    function note(s) { root.report += s + "\n"; out.setText(root.report) }
    function ok(what, good) {
        if (good) root.note("  ok    " + what)
        else { root.failures++; root.note("  FAIL  " + what) }
    }

    // Deferred for the reason tools/monitors-check.qml pays for on the other
    // side: run at Component.onCompleted and the FileView is not ready, so the
    // first lines of the report are lost.
    Timer {
        running: true
        interval: 250
        onTriggered: root.run()
    }

    function rowsOf(item, kind) {
        // Every descendant that carries a `modelData` — which is what the
        // Repeater delegates in both panels declare as `required property var`.
        var n = 0
        function walk(o) {
            if (o === null || o === undefined)
                return
            var kids = o.children || []
            for (var i = 0; i < kids.length; i++) {
                if (kids[i].modelData !== undefined && kids[i].modelData !== null)
                    n++
                walk(kids[i])
            }
        }
        walk(item)
        return n
    }

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
        root.note("buchhwin netpanel-check")

        // ----------------------------------------------------- the fixtures
        root.ok("the network service is in fake mode", Services.Net.fake)
        root.ok("the bluetooth service is in fake mode", Services.Bt.fake)
        root.ok("three networks in the fixture (got "
                + Services.Net.networks.length + ")",
                Services.Net.networks.length === 3)
        root.ok("three devices in the fixture (got "
                + Services.Bt.devices.length + ")",
                Services.Bt.devices.length === 3)

        // ⚠️ CONNECTED FIRST, and it is not cosmetic. Both services sort that
        // way on purpose — "what am I on" is the first question anybody opening
        // either panel has, and a list that answers it fourth is a list you read
        // instead of glance at.
        root.ok("the connected network is first",
                Services.Net.networks.length > 0 && Services.Net.networks[0].connected)
        root.ok("the connected device is first",
                Services.Bt.devices.length > 0 && Services.Bt.devices[0].connected)

        // -------------------------------------------------------- the panels
        var net = root.build("../ui/quick/NetworkList.qml")
        if (net !== null) {
            root.ok("the network panel builds", true)
            var netRows = root.rowsOf(net, "network")
            root.ok("it draws a row per network (got " + netRows + " of 3)",
                    netRows === 3)
            // ⚠️ NO PASSWORD FIELD UNTIL ONE IS ASKED FOR. `asking` is "" on a
            // fresh panel, and a field standing open under a network nobody
            // pressed is a prompt for a password nobody was asked for.
            root.ok("no password field is open to begin with", net.asking === "")
            net.destroy()
        }

        var bt = root.build("../ui/quick/BluetoothList.qml")
        if (bt !== null) {
            root.ok("the bluetooth panel builds", true)
            var btRows = root.rowsOf(bt, "device")
            root.ok("it draws a row per device (got " + btRows + " of 3)",
                    btRows === 3)
            bt.destroy()
        }

        // ⚠️ AND THE THING THAT STARTED ALL THIS: the panel may not send anybody
        // to another application. A jump back to System Settings would make the
        // whole of Net.qml and Bt.qml dead code again, silently, and the only
        // thing that would notice is this line and the repository check.
        root.ok("no jump to KDE System Settings is left",
                String(Services.Net.status).indexOf("systemsettings") < 0)

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
