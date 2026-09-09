// Does "Reset this page" remove exactly the page's settings, and nothing else?
//
// ⚠️ THE FAILURE THIS EXISTS FOR IS NOT "the button does nothing". It is a
// button that resets a page and takes four other pages with it, or one that
// leaves the monitor scales standing and reports the page reset anyway. Both
// look like success on screen — the page you are looking at goes back to its
// defaults either way — and both are only visible by reading the file.
//
// So every case here asserts TWO things: what went, and what stayed.
//
// ⚠️ IT RUNS IN STEPS for the same reason backup-check.qml does: every
// replacement defers its write by one turn of the event loop (Backup._replace
// has to — see the note there), so a check written straight after the call
// reads the file as it was before. A test with that shape is green either way,
// which is the one thing worse than no test.
//
// It runs against a throwaway XDG_CONFIG_HOME and HOME — tests/reset-page.sh
// sets both — so nothing here can reach a real settings file.
import QtQuick
import Quickshell
import Quickshell.Io
import "../common"
import "../config"

Item {
    id: root

    readonly property string out: "/tmp/buchhwin-reset-page-check.txt"
    property string report: ""
    property int step: 0

    function say(s) { report += s + "\n"; log.setText(report) }
    function check(name, ok, detail) {
        say((ok ? "  ok   " : "  FAIL ") + name + (detail ? "   " + detail : ""))
    }

    FileView { id: log; path: root.out }
    // blockWrites for the reason spelled out in backup-check.qml: `setText`
    // posts a write, and a fixture that has not landed yet is read as the
    // previous one. Safe here — this view belongs to the test.
    FileView { id: probe; blockLoading: true; blockWrites: true; printErrors: false }

    function read(path) {
        probe.path = ""
        probe.path = path
        return probe.text()
    }
    // ⚠️ THE FRESH-PATH DANCE HERE TOO. A FileView hands back what it already
    // holds for a path it already holds, so `put` after a `read` of a DIFFERENT
    // path would set the path, load, and write — but `put` to the path it is
    // already on is a no-op load, and the first version of this tool restored
    // its fixture into a view that quietly kept the old text.
    function put(path, text) {
        probe.path = ""
        probe.path = path
        probe.setText(text)
        return probe.text() === text
    }

    // A file with keys in four blocks, so "only this page" is a question with a
    // real answer. `version` is in it because a reset that eats the version
    // would look perfect here and migrate the file from zero on the next start.
    readonly property string fixture: JSON.stringify({
        version: 14,
        theme: { palette: "dracula", accent: "red" },
        notch: { flare: 11 },
        bar: { height: 40 },
        // ⚠️ `lock.showDate`, NOT the `lock.blur` this fixture used to carry —
        // there is no such key. A hand-written file keeps whatever nonsense it
        // holds, so nothing noticed; a reset now goes through the adapter,
        // which drops every key it does not declare, and the undeclared one
        // vanished mid-check. A fixture has to be made of real keys or it tests
        // the fixture.
        lock: { showDate: false },
        outputs: [ { name: "Virtual-1", scale: 2 } ]
    }, null, 2) + "\n"

    // ⚠️ THE VERSION IS ALLOWED TO MOVE, and pinning it cost this tool a red run
    // the day the schema went from 14 to 15. Config MIGRATES the fixture the
    // moment it is written and writes it back carrying the new number — so a
    // byte-for-byte "unchanged" test measures the migration rather than the
    // reset. Every comparison here is made on the keys with `version` removed.
    function sameExceptVersion(a, b) {
        function strip(t) {
            try {
                var d = JSON.parse(t)
                delete d.version
                return JSON.stringify(d)
            } catch (e) {
                return "unparseable:" + t
            }
        }
        return strip(a) === strip(b)
    }

    // What a path actually holds in the written file, or `undefined`. The
    // checks below moved from "is the key gone" to "is the key the DEFAULT"
    // when the meaning of a reset changed, and asking for the value is the only
    // way to put that question.
    function valueAt(text, path) {
        var doc
        try { doc = JSON.parse(text) } catch (e) { return undefined }
        var parts = path.split(".")
        for (var i = 0; i < parts.length; i++) {
            if (doc === null || doc === undefined || typeof doc !== "object")
                return undefined
            doc = doc[parts[i]]
        }
        return doc
    }

    // Two values, compared the way a settings file compares them: lists are
    // values here, not containers.
    function same(a, b) { return JSON.stringify(a) === JSON.stringify(b) }

    function has(text, path) {
        var doc = JSON.parse(text)
        var parts = path.split(".")
        for (var i = 0; i < parts.length; i++) {
            if (doc === null || doc === undefined || typeof doc !== "object")
                return false
            if (!doc.hasOwnProperty(parts[i]))
                return false
            doc = doc[parts[i]]
        }
        return true
    }

    WaitFor {
        condition: Config.settled
        onTimedOut: {
            root.say("  FAIL config never settled")
            Qt.callLater(Qt.quit)
        }
        onReady: steps.start()
    }

    Timer {
        id: steps
        interval: 250
        repeat: true
        onTriggered: root.advance()
    }

    // ⚠️⚠️ WAIT FOR THE WRITE — DO NOT SLEEP FOR IT, and this tool went green on
    // a broken product before the difference was taken seriously.
    //
    // `Backup._report` runs inside `_replace`'s callback, which is AFTER
    // `dst.setText(text)` — and `setText` posts a write rather than performing
    // one. So the status line says "2 settings reset" while the bytes are still
    // in flight. A check one 250 ms step later usually sees the new file and
    // sometimes does not: the deliberately-broken run that PROVED this tool can
    // go red reported "a whole group is refused" as FAIL and "and nothing was
    // written" as ok, in the same run, about the same write.
    //
    // Raising the interval would be guessing at a duration to cover an
    // ordering, which is the shape of flake that comes back on a slower
    // machine. So: a step only happens once two consecutive reads agree — the
    // same control as two identical idle screenshots. Every action costs one
    // extra tick and nothing costs correctness.
    property string seen: ""
    property int waited: 0

    function advance() {
        var cfg = Backup.configPath

        var now = read(cfg)
        if (now !== root.seen) {
            root.seen = now
            root.waited++
            // A file that never stops changing is a finding, not a reason to
            // hang until the outer `timeout` kills the process with no output.
            if (root.waited < 40)
                return
            root.say("  FAIL the settings file never stopped changing")
            steps.stop()
            Qt.callLater(Qt.quit)
            return
        }
        root.waited = 0
        step++

        switch (step) {
        case 1:
            check("the fixture goes back in", put(cfg, root.fixture))
            break

        case 2:
            check("the fixture is in place", sameExceptVersion(read(cfg), root.fixture))
            // One page's worth: two keys out of a file that holds six.
            Backup.resetPaths(["theme.palette", "theme.accent"], "Colours")
            break

        case 3:
            var a = read(cfg)
            // ⚠️⚠️ THE CONTRACT CHANGED, AND THESE THREE LINES ARE WHERE IT
            // SHOWS. They used to read "the page's own keys are gone" and "the
            // emptied group is gone rather than left as {}" — correct
            // assertions about a reset that DELETED keys, which is what this
            // did until it turned out never to reach the running shell. A
            // JsonAdapter does not restore an absent key; it simply does not
            // write it, so every control kept its old value and the button read
            // as dead on every page. config/Backup.qml carries the measurement.
            //
            // A reset now WRITES the declared default, so the question is no
            // longer "is the key gone" but "is the key the default" — and that
            // is a stronger question: a delete could be checked without knowing
            // what the value should be.
            check("the page's own keys are back at their defaults",
                  same(valueAt(a, "theme.palette"), Config.defaultFor("theme.palette"))
                  && same(valueAt(a, "theme.accent"), Config.defaultFor("theme.accent")),
                  "palette=" + JSON.stringify(valueAt(a, "theme.palette"))
                  + " accent=" + JSON.stringify(valueAt(a, "theme.accent")))
            // ⚠️ AND THE FIXTURE HAS TO DISAGREE WITH THE DEFAULTS, or the line
            // above passes over a reset that did nothing at all. `dracula` and
            // `red` are chosen for exactly that.
            check("the fixture's values were not the defaults to begin with",
                  !same("dracula", Config.defaultFor("theme.palette"))
                  && !same("red", Config.defaultFor("theme.accent")))
            // ⚠️ THE HALF THAT MATTERS. Everything below is what a reset that
            // reached too far would have taken with it.
            check("another page's keys are untouched",
                  same(valueAt(a, "notch.flare"), 11)
                  && same(valueAt(a, "bar.height"), 40)
                  && same(valueAt(a, "lock.showDate"), false),
                  "flare=" + JSON.stringify(valueAt(a, "notch.flare"))
                  + " height=" + JSON.stringify(valueAt(a, "bar.height"))
                  + " showDate=" + JSON.stringify(valueAt(a, "lock.showDate")))
            check("the version survives", has(a, "version"))
            check("the previous file is kept as .bak",
                  sameExceptVersion(read(cfg + ".bak"), root.fixture))
            check("and it says how many it reset",
                  !Backup.failed && Backup.lastAction === "page", Backup.status)
            check("the fixture goes back in", put(cfg, root.fixture))
            break

        case 4:
            // ⚠️ THE CONTROL BEFORE THE MEASUREMENT. Every case below starts
            // from the fixture, and a restore that did not land would make all
            // of them measure a file nobody wrote. The first run of this tool
            // failed exactly here.
            check("the fixture can be put back",
                  sameExceptVersion(read(cfg), root.fixture),
                  read(cfg).length + " bytes")
            // ⚠️ THE CATASTROPHIC CASE. A whole block instead of a leaf would
            // delete every key under it, including four other pages' — and the
            // page in front of you would look correctly reset.
            Backup.resetPaths(["theme"], "Colours")
            break

        case 5:
            check("a whole group is refused rather than emptied",
                  Backup.failed && Backup.lastAction === "page", Backup.status)
            check("and nothing was written", sameExceptVersion(read(cfg), root.fixture), read(cfg).length + " vs fixture " + root.fixture.length)
            Backup.resetPaths([], "Nowhere")
            break

        case 6:
            check("an empty list is refused", Backup.failed, Backup.status)
            check("and nothing was written for that either", sameExceptVersion(read(cfg), root.fixture), read(cfg).length + " vs fixture " + root.fixture.length)
            // A key the file never had. Not a failure: it means the page is
            // already at its defaults, and saying "reset" would be a lie about
            // work that did not happen.
            // ⚠️ A KEY THE FIXTURE NEVER SET, and it has to be one the SCHEMA
            // still declares — the check below is "already at the defaults",
            // not "there is no such setting". This was `media.preferredPlayer`
            // until the Media page was cut on 09.09.2026 and the key went with
            // it, at which point the probe was asking about nothing and the
            // answer changed from "nothing to do" to "no default declared".
            Backup.resetPaths(["look.fontIcon"], "Appearance")
            break

        case 7:
            check("a page with nothing set says so instead of failing",
                  !Backup.failed, Backup.status)
            check("says 'already at the defaults'",
                  Backup.status.indexOf("already at the defaults") >= 0, Backup.status)
            check("and left the file alone", sameExceptVersion(read(cfg), root.fixture), read(cfg).length + " vs fixture " + root.fixture.length)
            // A list-valued key is a LEAF, not a group: one row owns all of it.
            Backup.resetPaths(["outputs"], "Size & Shape")
            break

        case 8:
            var b = read(cfg)
            check("a list-valued key resets like any other leaf",
                  same(valueAt(b, "outputs"), Config.defaultFor("outputs")),
                  JSON.stringify(valueAt(b, "outputs")))
            check("and the fixture's list was not the default either",
                  !same([ { name: "Virtual-1", scale: 2 } ], Config.defaultFor("outputs")))
            check("and took nothing else with it",
                  same(valueAt(b, "notch.flare"), 11) && has(b, "version"),
                  "flare=" + JSON.stringify(valueAt(b, "notch.flare")))

            // ⚠️⚠️ AND THE OTHER KIND OF LIST, WHICH IS THE ONE THAT WAS BROKEN.
            // `outputs` above is a `var` holding a real JS array, so it always
            // worked — and its passing case is exactly why nobody looked at the
            // twenty `property list<string>` declarations in Config.qml. A QML
            // list is NOT a JS array: `Array.isArray` says false, the snapshot
            // walked it as an object, an empty one has no properties, and the
            // key vanished from the schema.
            //
            // What that cost: Backup.resetPaths refuses a page as a WHOLE if one
            // path has no declared default — so a single `list<string>` killed
            // the reset button of every page carrying one, while every other
            // page worked. Reported as "manche reset buttons gehen und manche    // english-ok: his report, quoted
            // nicht", and found by pressing the button and reading the red line  // english-ok: the report, quoted
            // under it: "no default is declared for bar.monitors".
            //
            // ⚠️ THE CHECK IS ON THE SCHEMA, NOT ON A RESET, and deliberately so:
            // the fault was never in resetting, it was in what the schema knew.
            var def = Config.defaultFor("bar.monitors")
            check("a QML list<string> reaches the schema at all",
                  def !== undefined,
                  "bar.monitors -> " + JSON.stringify(def))
            check("and reaches it as a LIST, not as {\"0\": …}",
                  def !== undefined && typeof def === "object"
                  && typeof def.length === "number",
                  JSON.stringify(def))
            // A non-empty one, because empty and filled failed differently: the
            // empty list disappeared, the filled one arrived with the wrong shape.
            var pinned = Config.defaultFor("windows.blurred")
            check("a filled list<string> keeps its shape",
                  pinned !== undefined && typeof pinned.length === "number"
                  && pinned.length > 0 && typeof pinned[0] === "string",
                  JSON.stringify(pinned))

            steps.stop()
            Qt.callLater(Qt.quit)
            break
        }
    }
}
