// Do the two new controls write what they say?
//
// ⚠️ EVERYTHING ELSE ABOUT THESE ROWS IS CHECKED BY READING, and reading cannot
// see this. tests/setting-rows.sh proves every row names a real key;
// tests/suggestions.sh proves every suggesting row has a source and that the
// source answers. Neither touches the part that actually changes the file:
// clicking a chip, clicking a suggestion, typing an argument.
//
// ⚠️ AND ONE OF THOSE THREE CARRIES A PROMISE THAT IS EASY TO BREAK AND SILENT
// WHEN IT IS. `programs.terminal` is ["kitty", "-e", "btop"] — a program and its
// arguments, in order. Picking a different terminal from the suggestions must
// keep the arguments. Lose them and the key binding still works, still spawns a
// terminal, and simply stops opening btop; nothing anywhere says why.
//
// ⚠️ IT CALLS THE CONTROL RATHER THAN CLICKING IT, and the earlier version of
// this note said clicking was impossible on the test machine. That was wrong —
// measured afterwards: a real click on the settings window works, and the three
// things that had made it look broken were a locked session, ydotool's
// `--absolute` on a device with no ABS axes, and the compositor's overview standing open
// because a pointer move had crossed the top-left corner. The recipe that works
// is in <screenshot-archive>/INDEX.md.
//
// Calling the control is still the right choice HERE, for a plainer reason: a
// check that drives the window has to know where every control is on screen, so
// it breaks whenever the page is rearranged — and it cannot run at all without
// a session. This one runs headless, in the CI, against a throwaway config.
//
// Runs against a throwaway XDG_CONFIG_HOME; tests/row-writes.sh sets it.
import QtQuick
import Quickshell
import Quickshell.Io
import "../common"
import "../config"
import "../ui/settings"

Item {
    id: root

    readonly property string out:
        Quickshell.env("BUCHHWIN_ROWS_OUT") || "/tmp/buchhwin-row-write-check.txt"
    property string report: ""

    FileView { id: log; path: root.out }
    FileView { id: probe; blockLoading: true; printErrors: false }

    function say(s) { root.report += s + "\n"; log.setText(root.report) }
    function check(name, good, detail) {
        root.say((good ? "  ok   " : "  FAIL ") + name + (detail ? "   " + detail : ""))
    }

    // Read the settings file from disk rather than from Config, because "the
    // control changed a property in memory" is not the claim being tested.
    // ⚠️ A FileView hands back what it already holds for a path it already has,
    // so the path is cleared first — config/Backup.qml pays for that lesson in
    // full and this is the same trap.
    function fileList(path, dotted) {
        probe.path = ""
        probe.path = Quickshell.env("XDG_CONFIG_HOME") + "/buchhwin/shell.json"
        var text = probe.text()
        if (!text || !text.length)
            return null
        try {
            var node = JSON.parse(text)
            var parts = dotted.split(".")
            for (var i = 0; i < parts.length; i++) {
                if (node === null || node === undefined)
                    return null
                node = node[parts[i]]
            }
            return node
        } catch (e) {
            return null
        }
    }

    // ⚠️ WALKS TO THE CONTROL BY WHAT IT CAN DO, not by its type. The control
    // lives inside SettingRow's Loader, and matching on a component name would
    // go blind the day one of them is renamed — the same reasoning
    // tools/pages-check.qml gives for harvesting rows by their properties.
    function findFn(obj, fname, depth) {
        if (!obj || depth > 8)
            return null
        if (typeof obj[fname] === "function")
            return obj
        var kids = obj.children === undefined ? [] : obj.children
        for (var i = 0; i < kids.length; i++) {
            var hit = root.findFn(kids[i], fname, depth + 1)
            if (hit)
                return hit
        }
        var d = obj.data === undefined ? [] : obj.data
        for (var j = 0; j < d.length; j++) {
            if (d[j] !== undefined && kids.indexOf(d[j]) < 0) {
                var hit2 = root.findFn(d[j], fname, depth + 1)
                if (hit2)
                    return hit2
            }
        }
        // A Loader keeps its content in `item`, which is neither a child nor in
        // `data` — and every one of these controls is behind one.
        if (obj.item !== undefined && obj.item !== null)
            return root.findFn(obj.item, fname, depth + 1)
        return null
    }

    function same(a, b) {
        if (a === null || a === undefined || a.length !== b.length)
            return false
        for (var i = 0; i < b.length; i++)
            if (String(a[i]) !== String(b[i]))
                return false
        return true
    }

    Component {
        id: rowComp
        SettingRow {}
    }

    property var picksRow: null
    property var cmdRow: null
    property var colourRow: null
    property var timeRow: null
    property var themingPage: null
    property int step: 0

    Timer {
        id: steps
        interval: 300
        repeat: true
        onTriggered: root.advance()
    }

    WaitFor {
        condition: Config.settled
        onReady: steps.start()
        onTimedOut: {
            root.say("  FAIL config never settled")
            Qt.callLater(Qt.quit)
        }
    }

    function advance() {
        root.step++
        switch (root.step) {

        // ── picks: a suggestion goes in ─────────────────────────────────────
        case 1:
            root.picksRow = rowComp.createObject(root, {
                key: "windows.blurred",
                kind: "picks",
                options: ["probe-one", "probe-two"]
            })
            break

        case 2:
            var addTo = root.findFn(root.picksRow, "add", 0)
            if (!addTo) {
                root.check("picks: the control is reachable", false)
                root.step = 90
                break
            }
            root.check("picks: the control is reachable", true)
            addTo.add("probe-one")
            addTo.add("probe-two")
            break

        case 3:
            var got = root.fileList("", "windows.blurred")
            root.check("picks: both suggestions land in the file",
                       root.same(got, ["probe-one", "probe-two"]),
                       "windows.blurred = " + JSON.stringify(got))
            break

        case 4:
            // ⚠️ ADDING THE SAME THING TWICE MUST DO NOTHING. It is a set; a
            // duplicate app-id in a window rule is a rule written twice, and
            // the chip for it would have no single thing to remove.
            root.findFn(root.picksRow, "add", 0).add("probe-one")
            break

        case 5:
            var dup = root.fileList("", "windows.blurred")
            root.check("picks: a duplicate is refused",
                       root.same(dup, ["probe-one", "probe-two"]),
                       JSON.stringify(dup))
            break

        case 6:
            root.findFn(root.picksRow, "drop", 0).drop("probe-one")
            break

        case 7:
            var left = root.fileList("", "windows.blurred")
            root.check("picks: a chip removes exactly itself",
                       root.same(left, ["probe-two"]),
                       JSON.stringify(left))
            root.picksRow.destroy()
            break

        // ── command: the arguments survive ──────────────────────────────────
        case 8:
            Config.set("programs.terminal", ["kitty", "-e", "btop"])
            Config.flush()
            break

        case 9:
            root.cmdRow = rowComp.createObject(root, {
                key: "programs.terminal",
                kind: "command",
                options: ["alacritty", "foot"]
            })
            break

        case 10:
            var w = root.findFn(root.cmdRow, "write", 0)
            if (!w) {
                root.check("command: the control is reachable", false)
                root.step = 90
                break
            }
            root.check("command: the control is reachable", true)
            // Exactly what clicking the "alacritty" suggestion does: the new
            // program, the arguments box untouched.
            w.write("alacritty", "-e, btop")
            break

        case 11:
            var argv = root.fileList("", "programs.terminal")
            root.check("command: picking a program keeps its arguments",
                       root.same(argv, ["alacritty", "-e", "btop"]),
                       JSON.stringify(argv))
            break

        case 12:
            // ⚠️ ARGUMENTS WITH NO PROGRAM ARE DROPPED. A list starting with
            // "-e" makes the compositor look for a binary called "-e", and the key that
            // uses it fails at the moment it is pressed — long after the box
            // was emptied.
            root.findFn(root.cmdRow, "write", 0).write("", "-e, btop")
            break

        case 13:
            var empty = root.fileList("", "programs.terminal")
            root.check("command: no program means no argv at all",
                       root.same(empty, []),
                       JSON.stringify(empty))
            root.cmdRow.destroy()
            break

        // ── colour: the hex survives the round trip ─────────────────────────
        //
        // ⚠️ THIS IS THE ONE THAT COULD ROUND. The picker holds hue, saturation
        // and value as reals and writes back an 8-bit hex, so a colour typed in
        // goes #rrggbb → hsv → #rrggbb. If that drifts by a step, every visit
        // to this page would nudge the seed of the whole scheme — quietly, and
        // in one direction. Measured rather than reasoned about.
        case 14:
            Config.set("theme.customColor", "#7fbbb3")   // literal-ok: a fixture — the colour is what is being measured, not what is drawn
            Config.flush()
            break

        case 15:
            root.colourRow = rowComp.createObject(root, {
                key: "theme.customColor",
                kind: "colour"
            })
            break

        case 16:
            var picker = root.findFn(root.colourRow, "_adopt", 0)
            if (!picker) {
                root.check("colour: the picker is reachable", false)
                root.step = 90
                break
            }
            root.check("colour: the picker is reachable", true)
            root.check("colour: it reads the value it was given",
                       picker._adopt("#7fbbb3"), "")   // literal-ok: a fixture — the colour is what is being measured, not what is drawn
            picker._emit()
            break

        case 17:
            probe.path = ""
            probe.path = Quickshell.env("XDG_CONFIG_HOME") + "/buchhwin/shell.json"
            var back = JSON.parse(probe.text()).theme.customColor
            root.check("colour: #7fbbb3 comes back as itself",
                       String(back).toLowerCase() === "#7fbbb3", String(back))   // literal-ok: a fixture — the colour is what is being measured, not what is drawn
            break

        case 18:
            // A second colour, chosen through the square rather than typed —
            // the path a finger takes. It only has to land somewhere sensible
            // and stay there; the exact value depends on the geometry.
            var pk = root.findFn(root.colourRow, "_adopt", 0)
            pk._adopt("#ff0000")   // literal-ok: a fixture — the colour is what is being measured, not what is drawn
            pk._emit()
            break

        case 19:
            probe.path = ""
            probe.path = Quickshell.env("XDG_CONFIG_HOME") + "/buchhwin/shell.json"
            var red = JSON.parse(probe.text()).theme.customColor
            root.check("colour: a full-saturation red survives too",
                       String(red).toLowerCase() === "#ff0000", String(red))   // literal-ok: a fixture — the colour is what is being measured, not what is drawn
            root.colourRow.destroy()
            break

        // ── time: an unreadable value is refused, not stored ────────────────
        //
        // ⚠️ THE READER DOES NOT COMPLAIN, WHICH IS WHY THE ROW HAS TO.
        // Scheme.qml splits these on ":" and calls Number(); "7pm" gives NaN,
        // both comparisons are then false, and the light palette simply never
        // arrives. Nothing logs it.
        case 20:
            Config.set("theme.lightFrom", "07:00")
            Config.flush()
            break

        case 21:
            root.timeRow = rowComp.createObject(root, {
                key: "theme.lightFrom",
                kind: "time"
            })
            break

        case 22:
            var tf = root.findFn(root.timeRow, "valid", 0)
            if (!tf) {
                root.check("time: the control is reachable", false)
                root.step = 90
                break
            }
            root.check("time: the control is reachable", true)
            root.check("time: 07:00 and 7:00 and 23:59 are accepted",
                       tf.valid("07:00") && tf.valid("7:00") && tf.valid("23:59"), "")
            root.check("time: 24:00, 7pm, 07-00 and half past are refused",
                       !tf.valid("24:00") && !tf.valid("7pm")
                       && !tf.valid("07-00") && !tf.valid("half past"), "")
            break

        // ── "set all to" reaches every program, without a second list ──────
        //
        // ⚠️ THE WHOLE POINT OF THE BUTTON IS THAT IT CANNOT DRIFT. It walks the
        // rows that are on the page and sets each one's own key, rather than
        // keeping its own copy of the thirteen names — because a second list is
        // a second thing to forget, and forgetting it means "all to Neutral"
        // quietly leaves one program coloured. That is the same one-sided drift
        // the explicit switch in tools/render.qml exists to prevent, and it is
        // only true while something checks it.
        case 23:
            var comp = Qt.createComponent("../ui/settings/pages/AppThemingPage.qml")
            if (comp.status === Component.Error) {
                root.check("theming table: the page compiles", false,
                           String(comp.errorString()))
                root.step = 90
                break
            }
            root.themingPage = comp.createObject(root)
            root.check("theming table: the page builds", root.themingPage !== null)
            break

        case 24:
            // ⚠️ findFn RETURNS THE OWNER, NOT THE FUNCTION — and calling the
            // owner is how this check spent three rounds blaming the page.
            // `setAll("neutral")` called a SettingGroup, threw
            // "SettingGroup(0x…) is not a function", and the throw was silent,
            // so the page looked like it was doing nothing. Two "fixes" went
            // into the page for a fault that was in here.
            var group = root.findFn(root.themingPage, "setAll", 0)
            if (!group) {
                root.check("theming table: \"set all\" is reachable", false)
                root.step = 90
                break
            }
            root.check("theming table: \"set all\" is reachable", true)
            try {
                group.setAll("neutral")
            } catch (e) {
                // ⚠️ A THROW IN A QML FUNCTION IS SILENT and abandons the rest
                // of it. This button was written three times before it worked,
                // and the second version threw here — thirteen writes skipped,
                // no error anywhere, a button that simply did nothing. Reported
                // rather than swallowed, or the next version fails the same way.
                root.check("theming table: \"set all\" runs without throwing",
                           false, String(e) + " | " + String(e.stack).split("\n").slice(0,3).join(" << "))
            }
            break

        case 25:
            probe.path = ""
            probe.path = Quickshell.env("XDG_CONFIG_HOME") + "/buchhwin/shell.json"
            var th = JSON.parse(probe.text()).theming
            // The thirteen names, written out here on purpose: this is the one
            // place a SECOND list is right, because its whole job is to disagree
            // with the page if the page ever loses one.
            var want = ["gtk", "qt", "kitty", "alacritty", "hypr", "btop", "bat",
                        "fastfetch", "delta", "tmux", "starship", "lazygit", "brave"]
            var missed = []
            for (var i = 0; i < want.length; i++)
                if (String(th[want[i]]) !== "neutral")
                    missed.push(want[i] + "=" + th[want[i]])
            root.check("theming table: every theming target was set",
                       missed.length === 0,
                       missed.length ? missed.join(" ") : "13 of 13")
            // ⚠️ AND IT MUST NOT HAVE TOUCHED THE TWO THAT ARE NOT PROGRAMS.
            // `theming.enabled` is a switch and `theming.mode` is the default
            // state; a walk that matched on the "theming." prefix alone would
            // have set both to "neutral" and turned the whole feature off.
            root.check("theming table: it left enabled and mode alone",
                       th.enabled === true && String(th.mode) !== "neutral",
                       "enabled=" + th.enabled + " mode=" + th.mode)
            root.themingPage.destroy()
            break

        default:
            steps.stop()
            Qt.callLater(Qt.quit)
        }
    }
}
