// The CalDAV transport: does it send what it says, and does the token stay out
// of sight?
//
// ⚠️ TWO THINGS ARE BEING GUARDED, and they fail differently.
//
//   1. THE METHOD. Qt's XMLHttpRequest cannot send `REPORT`, which is the only
//      way CalDAV asks for events — that is why this transport is curl at all.
//      A regression here is silent: the calendar just stays empty, exactly as
//      it did for four handovers.
//
//   2. THE TOKEN. It is a bearer credential, and /proc/<pid>/cmdline is
//      world-readable. Somebody adding a header the obvious way — a `-H` in the
//      command list — would publish the account to every process on the machine
//      and nothing on screen would change. tests/caldav-transport.sh measures
//      the argv side, with a control that can fail; this measures the config we
//      hand curl.
//
// The port of a throwaway HTTP server is passed in by the script, so the status
// parsing is checked against a server that really answers rather than against a
// string we made up.
import QtQuick
import Quickshell
import Quickshell.Io
import "../services" as Services

Item {
    id: root

    readonly property string out: "/tmp/buchhwin-caldav-check.txt"
    property string report: ""

    function say(s) { report += s + "\n"; log.setText(report) }
    function check(name, ok, detail) {
        say((ok ? "  ok   " : "  FAIL ") + name + (detail ? "   " + detail : ""))
    }

    FileView { id: log; path: root.out }

    readonly property string port: Quickshell.env("BUCHHWIN_CALDAV_PORT") || ""
    readonly property string token: "TOKEN-THAT-MUST-NOT-LEAK-9f3a"

    // A body with real CRLF in it, because an iCalendar one has them and a
    // config line that ends early is a request that arrives truncated.
    readonly property string body:
        "BEGIN:VCALENDAR\r\nX-TEST:one \"quoted\" and a \\ backslash\r\nEND:VCALENDAR\r\n"

    Component.onCompleted: root.checkConfig()

    function checkConfig() {
        var cfg = Services.Calendar._curlConfig({
            method: "REPORT",
            url: "https://example.invalid/cal/",
            token: root.token,
            headers: ["Depth: 1", "Content-Type: application/xml; charset=utf-8"],
            body: root.body
        })

        var lines = cfg.split("\n")

        check("the method is sent as `request`, not guessed",
              lines.indexOf('request = "REPORT"') >= 0)

        var auth = lines.filter(function (l) {
            return l.indexOf("Authorization: Bearer") >= 0
        })
        check("the token travels as exactly one header line", auth.length === 1,
              auth.length + " lines")
        check("and that line is a `header =`, which curl reads from stdin",
              auth.length === 1 && auth[0].indexOf("header = ") === 0)

        // ⚠️ THE POINT OF THE WHOLE DESIGN. Anywhere else in the config is fine;
        // what must never happen is the token reaching the argument list, and
        // the config is the only thing this transport hands curl besides
        // `--config -`.
        var elsewhere = lines.filter(function (l) {
            return l.indexOf(root.token) >= 0 && l.indexOf("header = ") !== 0
        })
        check("the token appears nowhere else in the config",
              elsewhere.length === 0, elsewhere.join(" | "))

        // The body has to survive as ONE line with escapes, or curl stops
        // reading the value at the first newline and sends a truncated request.
        var data = lines.filter(function (l) { return l.indexOf("data-binary = ") === 0 })
        check("the body is one config line", data.length === 1, data.length + " lines")
        check("its CRLFs are escaped rather than literal",
              data.length === 1 && data[0].indexOf("\\r\\n") > 0)
        check("its quotes and backslashes are escaped",
              data.length === 1 && data[0].indexOf('\\"quoted\\"') > 0
              && data[0].indexOf("\\\\ backslash") > 0)

        check("a timeout is set, so a hung request cannot wedge the panel",
              cfg.indexOf("max-time = ") >= 0)
        check("the status is asked for out of band",
              cfg.indexOf("write-out = ") >= 0 && cfg.indexOf("%{http_code}") >= 0)

        root.checkLive()
    }

    // ------------------------------------------------------------------ live
    property int done: 0

    function checkLive() {
        if (!root.port.length) {
            root.say("  FAIL no port given — the live half did not run")
            Qt.callLater(Qt.quit)
            return
        }

        var base = "http://127.0.0.1:" + root.port + "/"

        // ⚠️ A REAL SERVER ANSWERING A REAL REPORT. python3's http.server does
        // not implement it and says 501 — which is the proof that matters: the
        // method left this machine. Qt would have thrown before the socket.
        Services.Calendar._http({
            method: "REPORT", url: base, token: root.token,
            headers: ["Depth: 1"], body: root.body
        }, function (r) {
            root.check("curl runs and the transport reads a status back",
                       r.ok, "exit " + r.exit + " " + r.error)
            root.check("a REPORT reaches a real server and is answered",
                       r.status === 501, "HTTP " + r.status)
            root.finish()
        })

        // Queued behind the first. Two overlapping requests are the normal case
        // — discovery, a month load and a save can all be in the air — and a
        // second `running = true` on a busy Process is a request that silently
        // never happens.
        Services.Calendar._http({
            method: "PROPFIND", url: base, token: root.token,
            headers: ["Depth: 0"], body: "<x/>"
        }, function (r) {
            root.check("a second request queued behind the first also answers",
                       r.ok && r.status > 0, "HTTP " + r.status)
            root.finish()
        })
    }

    function finish() {
        root.done++
        if (root.done >= 2)
            Qt.callLater(Qt.quit)
    }

    // If a callback never arrives the process would sit in its event loop until
    // the outer timeout kills it with no output, which reads as a hang rather
    // than as a failure.
    Timer {
        running: true
        interval: 30000
        onTriggered: {
            if (root.done < 2)
                root.say("  FAIL only " + root.done + " of 2 requests came back")
            Qt.quit()
        }
    }
}
