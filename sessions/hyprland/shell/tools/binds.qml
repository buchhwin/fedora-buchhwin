// Count or remove the frozen `binds` array in shell.json.
//
//   BUCHHWIN_TOOL=binds BUCHHWIN_BINDS_MODE=count qs -p shell
//   BUCHHWIN_TOOL=binds BUCHHWIN_BINDS_MODE=reset qs -p shell
//
// This is the rescue behind `bhctl binds reset`, and the report `bhctl doctor`
// reads to say whether the machine is still listening to the built-in keys.
//
// ⚠️⚠️ IT DELIBERATELY DOES NOT `import "../config"`, AND THAT IS THE ENTIRE
// DESIGN. This tool is what somebody runs when shell.json is the problem, and
// the most expensive single finding in this project is a SEGFAULT WHILE READING
// shell.json — inside `JsonAdapter::deserializeRec`, on ~60% of starts, with a
// crash reached by the adapter and not by the parser. A rescue that instantiates
// Config would depend on precisely the thing it is rescuing, and would fail on
// the one machine that needs it.
//
// A QML singleton is built on FIRST ACCESS. Not importing config/ and never
// touching Config means the adapter is never constructed, so shell.json is read
// here by `FileView` + `JSON.parse` and by nothing else. shell.qml itself does
// not reference Config either — checked, not assumed — so nothing upstream
// builds it for us.
//
// ⚠️ WHY THERE IS NO python3 HERE ANY MORE. This replaces two embedded python3
// scripts in bin/bhctl. Rule 2 is "no Python in operation, bash only for the
// installer and without any configuration logic", and rewriting a settings file
// is configuration logic by any reading.
//
// ⚠️ WHY `binds` HAS TO BE REMOVABLE AT ALL: a `binds` array in shell.json
// FREEZES the key bindings for ever. It got there when `keys.binds` was a `var`
// in a nested JsonObject carrying the defaults as its own default value, so the
// file was written with all 63 entries. "The file wins as soon as it says
// anything" then means every binding added later never appears.

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property string mode: Quickshell.env("BUCHHWIN_BINDS_MODE") || "count"

    // The path is passed in rather than derived, because `bhctl` already knows
    // it and a second derivation of $XDG_CONFIG_HOME is a second thing that can
    // be wrong. Falling back to the normal location keeps the tool usable by
    // hand.
    readonly property string cfgPath: Quickshell.env("BUCHHWIN_BINDS_FILE")
        || ((Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config"))
            + "/buchhwin/shell.json")

    property string report: ""
    function note(s) { report += s + "\n"; log.setText(report) }

    // ⚠️ THE FIRST LINE IS FOR A MACHINE, the rest for a person. `bhctl` reads
    // one word and a number; a report whose shape depends on which branch ran
    // is a report the caller has to parse, and that is how a rescue starts
    // guessing. The vocabulary is fixed:
    //
    //   count <n>     the file is readable and holds n entries (0 is fine)
    //   removed <n>   n entries were taken out and the file rewritten
    //   none          there was nothing to remove
    //   missing       no shell.json at all
    //   unreadable    it is there and it is not JSON
    // ⚠️ `.log`, NOT `.txt`, and that is the house shape rather than taste:
    // run_tool in bin/bhctl looks for /tmp/buchhwin-<tool>.log to decide whether
    // a tool ABORTed. A report written anywhere else is a report the runner
    // cannot see, and the refusal path would come back as success.
    FileView { id: log; path: "/tmp/buchhwin-binds.log" }

    // blockLoading so the read below is synchronous — without it `text()`
    // returns "" because the load has only just been queued, and an empty
    // string parses as "no file" rather than "not read yet". printErrors off:
    // a missing file is an answer here, not a fault to shout about.
    FileView { id: cfg; blockLoading: true; printErrors: false }

    Component.onCompleted: {
        // ⚠️ CLEAR THE PATH FIRST — a FileView hands back what it already holds
        // for a path it already has. Fourth time this trap has been sprung in
        // this project; tests/fileview-reuse.sh is the tripwire, and it reads
        // this file too.
        cfg.path = ""
        cfg.path = root.cfgPath

        var raw = cfg.text()
        if (!raw || !raw.length) {
            root.note("missing")
            root.note("no shell.json at " + root.cfgPath)
            Qt.callLater(Qt.quit)
            return
        }

        var data
        try {
            data = JSON.parse(raw)
        } catch (err) {
            // ⚠️ SAID, NOT SWALLOWED. An unreadable settings file is the state
            // this whole rescue exists for, and reporting it as "0 bindings"
            // would send the reader away satisfied.
            root.note("unreadable")
            root.note("shell.json is not valid JSON: " + err)
            Qt.callLater(Qt.quit)
            return
        }

        var n = (data && data.binds && data.binds.length) ? data.binds.length : 0

        if (root.mode !== "reset") {
            root.note("count " + n)
            root.note(n === 0 ? "the built-in set applies"
                              : n + " frozen entries in shell.json")
            Qt.callLater(Qt.quit)
            return
        }

        if (n === 0) {
            root.note("none")
            root.note("already the built-in set — nothing to do")
            Qt.callLater(Qt.quit)
            return
        }

        delete data.binds
        // Two spaces, matching what the adapter writes, so a rescue does not
        // reformat the whole file and turn the next diff into noise.
        cfg.setText(JSON.stringify(data, null, 2) + "\n")

        root.note("removed " + n)
        root.note("removed " + n + " frozen entries — the built-in set applies again")
        Qt.callLater(Qt.quit)
    }
}
