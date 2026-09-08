// Does a written setting SURVIVE, or does something write it back?
//
// ⚠️⚠️ THIS IS THE MEASUREMENT tools/switch-write-check.qml DELIBERATELY DOES NOT
// MAKE, and its own header says why: "WHY IN-MEMORY READBACK IS THE RIGHT
// MEASUREMENT, not the file on disk". For the fault it was written against — a
// write that is REFUSED — that reasoning is exactly right. For the one he
// reports now it is exactly wrong:
//
//     "wenn ich die top bar aktivieren will geht das nicht er springt sofort     // english-ok: the report, quoted
//      wieder zurück, also die bar ist nur minimal kurz da"                      // english-ok: the report, quoted
//
// The bar APPEARS. The write landed, every binding reacted, and 191 of 191 rows
// pass the in-memory check. Then it goes away again. An immediate read-back
// cannot see that, by construction: it reads before the thing that undoes it has
// happened.
//
// So this tool waits. It sets a key through the same `Config.set` a row uses,
// flushes, and then reads back TWICE — once at once, once after the file has had
// time to go around: `writeAdapter()` → the FileView's own `watchChanges` fires
// `onFileChanged` → `reload()` → `onLoaded` → the JsonAdapter is deserialised
// from disk again.
//
// Three outcomes, and they name three different bugs:
//
//   set ok, still ok later     nothing is wrong with this key
//   set ok, REVERTED later     something writes the old value back — the round
//                              trip, a migration, or the scrub in `_migrate`
//   set refused                the fault switch-write-check already covers
//
//   BUCHHWIN_KEY=bar.enabled BUCHHWIN_REVERT_OUT=/tmp/out qs -p shell
//
// ⚠️ THE VALUE IS PUT BACK at the end. This runs against a real shell.json.
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Scope {
    id: root

    readonly property string key: Quickshell.env("BUCHHWIN_KEY") || "bar.enabled"
    readonly property string outPath:
        Quickshell.env("BUCHHWIN_REVERT_OUT") || "/tmp/buchhwin-revert.txt"

    // ⚠️ How long to wait for the round trip. Not a guess at the machine's
    // speed: it is long enough that the debounced write (250 ms) and at least
    // one file-change notification have both had their turn, and the tool says
    // what it waited so a longer run can be compared with a shorter one.
    readonly property int settleMs: 2500

    property string report: ""
    property var original: null

    function say(line) {
        root.report += line + "\n"
        console.log("revert-check: " + line)
    }

    FileView { id: out; path: root.outPath }

    // The raw file, read independently of Config's own view — the question is
    // whether the two agree, so asking Config for both halves would be asking
    // the suspect to describe the crime.
    FileView {
        id: raw
        path: Quickshell.env("XDG_CONFIG_HOME")
              ? Quickshell.env("XDG_CONFIG_HOME") + "/buchhwin/shell.json"
              : Quickshell.env("HOME") + "/.config/buchhwin/shell.json"
        blockLoading: true
    }

    function fileSays(key) {
        try {
            var cfg = JSON.parse(raw.text())
            var parts = String(key).split(".")
            var node = cfg
            for (var i = 0; i < parts.length; i++) {
                if (node === null || node === undefined)
                    return "(missing)"
                node = node[parts[i]]
            }
            return String(node)
        } catch (e) {
            return "(unreadable: " + e + ")"
        }
    }

    Timer {
        id: settle
        interval: root.settleMs
        onTriggered: {
            var now = Config.get(root.key)
            raw.reload()
            var onDisk = root.fileSays(root.key)

            root.say("after " + root.settleMs + " ms")
            root.say("  adapter  " + String(now))
            root.say("  file     " + onDisk)

            var wanted = !root.original
            if (String(now) === String(wanted))
                root.say("VERDICT   the value survived")
            else
                root.say("VERDICT   REVERTED — set to " + wanted
                         + ", reads back " + now)

            // Put it back, and read the restore back rather than assuming it.
            Config.set(root.key, root.original)
            Config.flush()
            restore.start()
        }
    }

    Timer {
        id: restore
        interval: 800
        onTriggered: {
            root.say("restored  " + String(Config.get(root.key))
                     + " (was " + String(root.original) + ")")
            out.setText(root.report)
            Qt.exit(0)
        }
    }

    // ⚠️ WAIT FOR THE CONFIG TO BE READY. `Config.settled` is the same gate
    // dump-tokens uses; without it this reads defaults and reports a fault that
    // is only the tool being early.
    Timer {
        running: true
        interval: 200
        repeat: true
        onTriggered: {
            if (!Config.settled)
                return
            stop()

            root.original = Config.get(root.key)
            root.say("key       " + root.key)
            root.say("before    adapter " + String(root.original)
                     + "   file " + root.fileSays(root.key))

            var ok = Config.set(root.key, !root.original)
            Config.flush()

            root.say("set       " + (ok ? "accepted" : "REFUSED by Config.set"))
            root.say("immediate adapter " + String(Config.get(root.key)))
            settle.start()
        }
    }
}
