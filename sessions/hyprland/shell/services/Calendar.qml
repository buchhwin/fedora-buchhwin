pragma Singleton

// The calendar, read from KDE's own store.
//
// ⚠️⚠️ THIS FILE WAS 643 LINES OF GOOGLE CALDAV UNTIL 09.09.2026, and the
// replacement is not a simplification for its own sake — the old path was dead
// out of the box. It reached the calendar through GNOME Online Accounts: an
// OAuth token fetched over DBus from `org.gnome.OnlineAccounts`, a calendar
// discovered by PROPFIND against Google's CalDAV endpoint, events fetched as
// ICS and expanded by a 548-line RRULE parser of our own. Every one of those
// steps needs a package this profile does not install and never will, so on a
// fresh machine the panel said "No account set up" and there was no way from
// there to a calendar. A second account manager beside KDE's own is exactly
// the duplication the whole profile is built against.
//
// The desktop is Fedora KDE. Akonadi is already running, the seven KDE PIM
// packages are already installed, and `konsolekalendar` reads what Akonadi has
// — every calendar the user set up in KDE, Google included, through KDE's
// account manager rather than a second one. `sessions/dwl/` has read the store
// that way since it was written; this is the same source, reached the same way.
//
// ⚠️ NO PYTHON, WHICH IS WHY THIS DOES NOT SIMPLY CALL THE dwl SCRIPT.
// sessions/dwl/scripts/calendar_events.py does exactly this job in 62 lines,
// and tests/no-python.sh forbids it here: "kein Python, kein Lua im Betrieb".   // english-ok: the brief, quoted
// The CSV that konsolekalendar exports is four dates and a summary; parsing it
// in QML costs the function below and no extra process at all.
//
// ⚠️ AND THE ICS PARSER WENT WITH IT. services/Ical.qml existed to expand
// recurrence rules out of raw ICS, because CalDAV hands over the rule and not
// the occurrences. konsolekalendar expands them itself — it is asked for a date
// range and returns the instances — so keeping a second implementation of RRULE
// would be two answers to one question, which rule 6 forbids.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ⚠️ "IS THERE A CALENDAR" IS NOT "IS THE PROGRAM INSTALLED", and the two
    // are kept apart because the answers lead different places. Without
    // konsolekalendar there is nothing to ask; with it and no calendar there is
    // something to set up, in KDE's own settings. `status` says which.
    property bool available: false
    property bool probed: false
    property string status: "Looking for a calendar …"
    property bool busy: false

    // The instances in the window last asked for, sorted by start.
    property var events: []

    // The day the event page opens on, set by the month grid.
    property date draftDate: new Date()

    signal changed()

    // -------------------------------------------------------------- the probe
    Component.onCompleted: probe.running = true

    Process {
        id: probe
        command: ["sh", "-c", "command -v konsolekalendar >/dev/null"]
        onExited: function (code) {
            root.probed = true
            root.available = code === 0
            root.status = root.available
                ? ""
                : "konsolekalendar is not installed — it comes with kdepim-runtime"
        }
    }

    // --------------------------------------------------------------- reading
    // The events of one month, expanded.
    //
    // The window is padded by a week on each side: the grid shows the tail of
    // the previous month and the head of the next, and those cells have to
    // carry their dots too.
    property int _wantYear: 0
    property int _wantMonth: -1

    function loadMonth(year, month) {
        if (!root.available) return
        root._wantYear = year
        root._wantMonth = month
        // Coalesced on purpose. Stepping from August to December is four
        // property changes in as many milliseconds, and firing a request per
        // step would mean four processes whose first three results are thrown
        // away.
        coalesce.restart()
    }

    Timer {
        id: coalesce
        interval: 120
        onTriggered: {
            if (root._wantMonth < 0) return
            var from = new Date(root._wantYear, root._wantMonth, 1)
            from.setDate(from.getDate() - 7)
            var to = new Date(root._wantYear, root._wantMonth + 1, 1)
            to.setDate(to.getDate() + 7)
            root._load(from, to)
        }
    }

    // yyyy-MM-dd in LOCAL time, which is what konsolekalendar's --date wants.
    //
    // ⚠️ NOT toISOString(). That converts to UTC first, so a window starting at
    // midnight in Berlin begins on the previous day — the events of the first
    // of the month would be fetched for the last of the one before.
    function _ymd(d) {
        function p(n) { return n < 10 ? "0" + n : "" + n }
        return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate())
    }

    function _load(from, to) {
        if (!root.available || query.running)
            return
        root.busy = true
        root.status = ""
        // ⚠️ LC_ALL=C.UTF-8, and it is load-bearing rather than tidy.
        // konsolekalendar writes its dates through the locale: under a German
        // locale the CSV carries "Montag, 3. März 2026" and the parser below —
        // which reads yyyy-MM-dd — silently matches nothing. An empty calendar
        // and a calendar nobody could read look identical on screen.
        query.command = ["env", "LC_ALL=C.UTF-8", "konsolekalendar", "--view",
                         "--date", root._ymd(from), "--end-date", root._ymd(to),
                         "--time", "00:00", "--end-time", "23:59",
                         "--export-type", "CSV"]
        query.running = true
    }

    Process {
        id: query
        stdout: StdioCollector { id: queryOut }
        stderr: StdioCollector { id: queryErr }
        onExited: function (code) {
            root.busy = false
            if (code !== 0) {
                // ⚠️ THE PROGRAM'S OWN WORDS, not ours. konsolekalendar says
                // "No calendars found" or names the Akonadi problem, and either
                // is more use than a sentence invented over the top of it.
                var why = String(queryErr.text || "").split("\n")[0].trim()
                root.status = why.length > 0 ? why : "The calendar could not be read"
                root.events = []
                return
            }
            root.events = root._parseCsv(String(queryOut.text || ""))
            root.status = ""
        }
    }

    // ------------------------------------------------------------- the CSV
    //
    // konsolekalendar's CSV is one event per line:
    //
    //   startdate,starttime,enddate,endtime,summary,location,description,uid
    //
    // ⚠️ QUOTED FIELDS CAN CARRY COMMAS, and `split(",")` is the parser that
    // works until somebody writes "Lunch, then the dentist" in a summary — at
    // which point every field after it shifts by one and the uid becomes a
    // description. So the fields are walked character by character, which is
    // eleven lines and cannot drift.
    //
    // ⚠️ AND A DOUBLED QUOTE INSIDE A QUOTED FIELD IS ONE QUOTE. That is CSV's
    // own escape, it is what konsolekalendar emits for a title with a quotation
    // mark in it, and leaving it out puts stray marks in the list.
    function _splitCsv(line) {
        var out = []
        var cur = ""
        var inQuotes = false
        for (var i = 0; i < line.length; i++) {
            var c = line.charAt(i)
            if (inQuotes) {
                if (c === '"') {
                    if (line.charAt(i + 1) === '"') { cur += '"'; i++ }
                    else inQuotes = false
                } else {
                    cur += c
                }
            } else if (c === '"') {
                inQuotes = true
            } else if (c === ",") {
                out.push(cur); cur = ""
            } else {
                cur += c
            }
        }
        out.push(cur)
        return out
    }

    // A date and a time out of the CSV, in local time.
    //
    // ⚠️ "float" IS AN ALL-DAY EVENT, not a broken time. konsolekalendar writes
    // that word in the time column for an event with no clock time, and reading
    // it as a number gives NaN — an event that silently vanishes from the grid.
    function _stamp(dateText, timeText) {
        var d = String(dateText).trim()
        var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(d)
        if (!m)
            return null
        var t = String(timeText).trim().toLowerCase()
        var h = 0, min = 0, s = 0
        if (t.length > 0 && t !== "float") {
            var parts = t.split(":")
            h = Number(parts[0]) || 0
            min = Number(parts[1]) || 0
            s = Number(parts[2]) || 0
        }
        return new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]), h, min, s)
    }

    function _isAllDay(timeText) {
        var t = String(timeText).trim().toLowerCase()
        return t.length === 0 || t === "float"
    }

    function _parseCsv(text) {
        var out = []
        var lines = String(text).split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (line.trim().length === 0)
                continue
            var f = root._splitCsv(line)
            // Eight columns is the shape; anything shorter is a header line or
            // a message, and skipping it is more honest than guessing at it.
            if (f.length < 8)
                continue
            var start = root._stamp(f[0], f[1])
            var end = root._stamp(f[2], f[3])
            if (start === null)
                continue
            out.push({
                id: f[7],
                summary: f[4].length > 0 ? f[4] : "Untitled event",
                location: f[5],
                start: start,
                end: end === null ? start : end,
                allDay: root._isAllDay(f[1])
            })
        }
        out.sort(function (a, b) { return a.start.getTime() - b.start.getTime() })
        return out
    }

    // -------------------------------------------------------------- writing
    //
    // ⚠️ `konsolekalendar --add` TAKES A CLOCK TIME, AND AN ALL-DAY EVENT IS
    // `--float`. Passing a time for one and not the other is the difference
    // between an entry at the top of the day and one at 00:00, which reads as a
    // meeting nobody scheduled.
    function create(ev, done) {
        if (!root.available) {
            if (done) done(false, root.status.length > 0 ? root.status
                                                         : "No calendar available")
            return
        }
        if (add.running) {
            if (done) done(false, "Still saving the last one")
            return
        }
        root._addDone = done || null

        var argv = ["env", "LC_ALL=C.UTF-8", "konsolekalendar", "--add",
                    "--summary", String(ev.summary || "Untitled event"),
                    "--date", root._ymd(ev.start),
                    "--end-date", root._ymd(ev.end || ev.start)]
        if (ev.allDay) {
            argv.push("--float")
        } else {
            argv.push("--time"); argv.push(root._hm(ev.start))
            argv.push("--end-time"); argv.push(root._hm(ev.end || ev.start))
        }
        if (ev.location && String(ev.location).length > 0) {
            argv.push("--location"); argv.push(String(ev.location))
        }
        add.command = argv
        add.running = true
    }

    function _hm(d) {
        function p(n) { return n < 10 ? "0" + n : "" + n }
        return p(d.getHours()) + ":" + p(d.getMinutes())
    }

    property var _addDone: null

    Process {
        id: add
        stderr: StdioCollector { id: addErr }
        onExited: function (code) {
            var done = root._addDone
            root._addDone = null
            if (code === 0) {
                // The month reloads itself off this signal, so a new event
                // appears without the page asking for it.
                root.changed()
                if (done) done(true, "")
                return
            }
            var why = String(addErr.text || "").split("\n")[0].trim()
            if (done) done(false, why.length > 0 ? why : "Not saved")
        }
    }

    // ------------------------------------------------------------- helpers
    // The instances that fall on one day — what the page lists under the grid.
    //
    // The list is an ARGUMENT rather than read from `root.events` inside, so a
    // binding that calls this genuinely depends on the events and re-evaluates
    // when they arrive. Reading the property inside would have meant writing
    // `Calendar.events, Calendar.pickDay(…)` at every call site: a comma
    // expression whose only job is to create a dependency, which is a trick
    // that works until somebody tidies it away.
    function pickDay(list, year, month, day) {
        var dayStart = new Date(year, month, day, 0, 0, 0).getTime()
        var dayEnd = dayStart + 86400000
        var out = []
        if (!list) return out
        for (var i = 0; i < list.length; i++) {
            var e = list[i]
            if (!e || !e.start) continue
            var s = e.start.getTime()
            var t = e.end ? e.end.getTime() : s
            // An all-day event's end is exclusive, so one ending exactly at
            // midnight belongs to the previous day, not to this one.
            if (s < dayEnd && t > dayStart)
                out.push(e)
        }
        return out
    }

    // ⚠️ NOT `pickDay(...).length > 0`, which is what this was first.
    //
    // The month grid asks this for all 42 cells. With a linear scan inside,
    // drawing one month cost 42 × every event — every time the events changed,
    // on a machine whose whole point is running on a battery. The set below is
    // built ONCE per load; each cell is then a lookup.
    readonly property var dayIndex: root._indexDays(root.events)

    function _dayKey(y, m, d) { return y + "-" + m + "-" + d }

    function _indexDays(list) {
        var idx = ({})
        if (!list) return idx
        for (var i = 0; i < list.length; i++) {
            var e = list[i]
            if (!e || !e.start) continue
            var d = new Date(e.start.getFullYear(), e.start.getMonth(), e.start.getDate())
            var last = e.end ? e.end.getTime() : e.start.getTime()
            // An all-day event's end is exclusive: one ending exactly at
            // midnight must not light up the following day.
            var guard = 0
            while (d.getTime() < last || guard === 0) {
                idx[root._dayKey(d.getFullYear(), d.getMonth(), d.getDate())] = true
                d.setDate(d.getDate() + 1)
                // A malformed multi-year event must not turn this into a loop
                // that fills memory. 400 days is longer than any window shown.
                if (++guard > 400) break
            }
        }
        return idx
    }

    function anyOn(index, year, month, day) {
        return index ? index[root._dayKey(year, month, day)] === true : false
    }
}
