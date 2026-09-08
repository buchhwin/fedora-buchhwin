// Does every row in the settings window actually write?
//
// ⚠️ WRITTEN AGAINST A REPORT, AND THE REPORT NAMED A CLASS RATHER THAN A ROW:
// "manche switches gehen nicht wie z.b. der dock switch", and on being asked,   // english-ok: his report, quoted
// "das ist nicht nur beim dock schalter so sondern bei mehreren". So the        // english-ok: same, second line
// question is not "is the dock switch broken" but "which rows are", and the
// answer has to be a LIST or it is not an answer.
//
// ⚠️ WHY IN-MEMORY READBACK IS THE RIGHT MEASUREMENT, not the file on disk.
// ui/settings/SettingRow.qml does not move itself: a switch shows
// `Config.get(key)` and asks `Config.set` for the change. If the write is
// refused the row keeps showing the stored value — which from the outside is a
// switch that springs back, which is exactly what he described. So what has to
// be checked is whether `Config.get` reports the new value immediately after
// `Config.set`, in the same way the row would see it.
//
// ⚠️ AND Config.set HAS A SILENT REFUSAL. Two of its three exits log a warning
// (`no such section`, `no such key`) — the journal on the machine has neither.
// The third returns false without a word when `node[leaf] === value`, and a
// fourth is not counted at all: assigning into a JsonAdapter WRAPPER can be
// accepted without reaching the adapter. Only a read-back can tell those apart
// from success.
//
// The key list comes from outside rather than from walking the pages: the rows
// live in 23 files and instantiating them all here would test my ability to
// build pages, not the config. tests/switch-writes.sh extracts them with the
// same grep tests/setting-rows.sh uses, and hands them over in a file.
//
//   BUCHHWIN_KEYS=/tmp/keys BUCHHWIN_ROWS_OUT=/tmp/out qs -p shell
//
// ⚠️ EVERY VALUE IS PUT BACK. This runs against a real shell.json, and a tool
// that leaves a machine with 160 changed settings is worse than the bug.

import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Scope {
    id: root

    readonly property string keysPath: Quickshell.env("BUCHHWIN_KEYS") || ""
    readonly property string outPath:
        Quickshell.env("BUCHHWIN_ROWS_OUT") || "/tmp/buchhwin-switch-writes.txt"

    property string report: ""
    property var keys: []
    property int at: -1
    property int lands: 0
    property int refuses: 0

    function note(s) { root.report += s + "\n" }

    FileView { id: keyFile; blockLoading: true; printErrors: false }
    FileView { id: outFile }

    // A value the key certainly does not hold, derived from what it does hold.
    //
    // ⚠️ IT MUST DIFFER, or `Config.set`'s unchanged-exit fires and a perfectly
    // healthy key is reported as refused. That exit is the one with no warning,
    // so getting this wrong would produce a list of false accusations — the
    // worst possible output for a check whose whole product is a list.
    function otherValue(v) {
        if (typeof v === "boolean") return !v
        if (typeof v === "number")  return v === 0 ? 1 : 0
        if (typeof v === "string")  return v === "zz-probe" ? "zz-probe2" : "zz-probe"
        if (root.isList(v)) {
            var a = root.toArray(v)
            return (a.length === 1 && a[0] === "zz-probe")
                   ? ["zz-probe2"] : ["zz-probe"]
        }
        return undefined
    }

    // ⚠️⚠️ `Array.isArray()` SAYS FALSE FOR A JsonAdapter LIST, and the first
    // version of this file believed it. Nineteen rows came back
    // "SKIP (type object)" — and they were exactly the list-valued ones:
    // dock.monitors, windows.blurred, autostart, every programs.*. Those are
    // the rows most likely to be broken, because assigning into a wrapper is
    // the one refusal Config.set does not even count. A sweep that skipped them
    // was blind in precisely the place it had been pointed at.
    //
    // ui/settings/SettingRow.qml already knew: "Array.isArray() says false for
    // it, which is why Config.program() walks it."
    function isList(v) {
        return v !== null && typeof v === "object" && typeof v.length === "number"
    }

    function toArray(v) {
        var out = []
        for (var i = 0; i < v.length; i++)
            out.push(v[i])
        return out
    }

    function same(a, b) {
        var la = root.isList(a), lb = root.isList(b)
        if (la || lb) {
            if (!la || !lb)
                return false
            var x = root.toArray(a), y = root.toArray(b)
            return x.length === y.length && x.join("") === y.join("")
        }
        return a === b
    }


    function step() {
        root.at++
        if (root.at >= root.keys.length) {
            note("")
            note("landed " + root.lands + ", refused " + root.refuses
                 + ", of " + root.keys.length)
            outFile.path = root.outPath
            outFile.setText(root.report)
            Qt.quit()
            return
        }

        var k = root.keys[root.at]
        var before = Config.get(k)

        // A key the schema does not have at all is a different fault, and
        // tests/setting-rows.sh already owns it. Saying so beats calling it a
        // refused write.
        if (before === undefined) {
            note("MISSING  " + k)
            root.refuses++
            Qt.callLater(root.step)
            return
        }

        var probe = root.otherValue(before)
        if (probe === undefined) {
            note("SKIP     " + k + "  (type " + (typeof before) + ")")
            Qt.callLater(root.step)
            return
        }

        Config.set(k, probe)
        var after = Config.get(k)

        if (root.same(after, probe)) {
            root.lands++
            note("ok       " + k)
        } else {
            root.refuses++
            note("REFUSED  " + k + "  wanted " + JSON.stringify(probe)
                 + " got " + JSON.stringify(after))
        }

        // ⚠️ Put it back whatever happened, and do not trust that it worked
        // either — a restore that is itself refused would leave the machine
        // changed while the report says nothing.
        Config.set(k, before)
        if (!root.same(Config.get(k), before))
            note("         ⚠️ could not restore " + k)

        Qt.callLater(root.step)
    }

    Timer {
        running: true
        interval: 1200        // let Config finish loading and migrating first
        onTriggered: {
            if (root.keysPath.length === 0) {
                root.report = "no BUCHHWIN_KEYS given\n"
                outFile.path = root.outPath
                outFile.setText(root.report)
                Qt.quit()
                return
            }
            // Cleared first, per tests/fileview-reuse.sh — which caught this
            // file on its first run. Read once, so harmless today; the rule
            // exists because "harmless today" is what the four sites before it
            // all were.
            keyFile.path = ""
            keyFile.path = root.keysPath
            var raw = String(keyFile.text()).split("\n")
            var list = []
            for (var i = 0; i < raw.length; i++) {
                var t = raw[i].trim()
                if (t.length > 0)
                    list.push(t)
            }
            root.keys = list
            root.step()
        }
    }
}
