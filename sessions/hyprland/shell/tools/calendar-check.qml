// Does the calendar read what konsolekalendar writes?
//
//   BUCHHWIN_TOOL=calendar-check QT_QPA_PLATFORM=offscreen qs -p shell
//
// ⚠️⚠️ THE PARSER IS THE WHOLE RISK HERE, and it is the half a live calendar
// cannot check. A machine with no Akonadi store answers "no calendars found"
// and every line below it would be green over nothing — which is the shape
// tests/displays.sh and tests/netpanel.sh were both written against. So the CSV
// is a fixture, measured against what `konsolekalendar --export-type CSV`
// really emits, and the parsing functions are pure and asked directly.
//
// The samples are the four that have actually gone wrong in calendar code:
//
//   a comma inside a quoted summary   every field after it shifts by one
//   a doubled quote inside a field    CSV's own escape for a quotation mark
//   "float" in the time column        an all-day event, NOT a broken time
//   a short line                      a header or a message, not an event
import QtQuick
import Quickshell
import Quickshell.Io
import "../services" as Services

Scope {
    id: root

    property string report: ""
    property int failures: 0

    FileView { id: out; path: "/tmp/buchhwin-calendar-check.log" }
    function note(s) { root.report += s + "\n"; out.setText(root.report) }
    function ok(what, good) {
        if (good) root.note("  ok    " + what)
        else { root.failures++; root.note("  FAIL  " + what) }
    }

    Timer {
        running: true
        interval: 250
        onTriggered: root.run()
    }

    readonly property string sample:
        '2026-03-02,09:30,2026-03-02,10:15,Standup,Room 2,,uid-1\n'
      + '2026-03-03,float,2026-03-04,float,Public holiday,,,uid-2\n'
      + '2026-03-05,14:00,2026-03-05,15:00,"Lunch, then the dentist",,,uid-3\n'
      + '2026-03-06,08:00,2026-03-06,08:30,"He said ""yes""",,,uid-4\n'
      + 'not,an,event\n'

    function run() {
        var C = Services.Calendar
        root.note("buchhwin calendar-check")

        // ------------------------------------------------------- the splitter
        var f = C._splitCsv('a,"b,c",d')
        root.ok("a comma inside quotes stays in its field",
                f.length === 3 && f[1] === "b,c")
        var q = C._splitCsv('a,"He said ""yes""",b')
        root.ok("a doubled quote becomes one",
                q.length === 3 && q[1] === 'He said "yes"')

        // ------------------------------------------------------ the timestamps
        var d = C._stamp("2026-03-02", "09:30")
        root.ok("a date and time read as local time",
                d !== null && d.getFullYear() === 2026 && d.getMonth() === 2
                && d.getDate() === 2 && d.getHours() === 9 && d.getMinutes() === 30)
        var fl = C._stamp("2026-03-03", "float")
        root.ok("\"float\" is midnight, not NaN",
                fl !== null && fl.getHours() === 0 && !isNaN(fl.getTime()))
        root.ok("and it is recognised as an all-day event",
                C._isAllDay("float") && C._isAllDay("") && !C._isAllDay("09:30"))
        // ⚠️ THE LOCALE TRAP, as a check rather than a comment. Under a German
        // locale konsolekalendar writes "Montag, 2. März 2026"; the service
        // passes LC_ALL=C.UTF-8 so it never sees one. If that env ever goes
        // missing the parser must refuse the line rather than invent a date.
        root.ok("a localised date is refused rather than guessed at",
                C._stamp("Montag, 2. März 2026", "09:30") === null)

        // ------------------------------------------------------------ the rows
        var evs = C._parseCsv(root.sample)
        root.ok("four events out of five lines (got " + evs.length + ")",
                evs.length === 4)
        if (evs.length === 4) {
            root.ok("sorted by start", evs[0].id === "uid-1" && evs[3].id === "uid-4")
            root.ok("the summary with a comma survived whole",
                    evs[2].summary === "Lunch, then the dentist")
            root.ok("the quoted summary survived whole",
                    evs[3].summary === 'He said "yes"')
            root.ok("the holiday is all-day and the standup is not",
                    evs[1].allDay === true && evs[0].allDay === false)
            root.ok("the location came through", evs[0].location === "Room 2")
        }

        // --------------------------------------------------------- the index
        //
        // The month grid asks `anyOn` for all 42 cells, so this is the part that
        // has to be a lookup rather than a scan — and the multi-day holiday is
        // the case that gets it wrong: its end is EXCLUSIVE.
        var idx = C._indexDays(evs)
        root.ok("the standup lights its day", C.anyOn(idx, 2026, 2, 2))
        root.ok("a two-day holiday lights the first day", C.anyOn(idx, 2026, 2, 3))
        root.ok("…and an empty day stays dark", !C.anyOn(idx, 2026, 2, 10))

        // ⚠️ pickDay TAKES THE LIST AS AN ARGUMENT, which is the one thing about
        // this API that looks wrong and is not — see the note on it. Checked
        // here so the shape cannot be "tidied" without something failing.
        var onDay = C.pickDay(evs, 2026, 2, 5)
        root.ok("one event on the fifth", onDay.length === 1
                && onDay[0].summary === "Lunch, then the dentist")

        // -------------------------------------------------------- the dates out
        root.ok("a local date is written yyyy-MM-dd",
                C._ymd(new Date(2026, 0, 5)) === "2026-01-05")
        root.ok("a clock time is written HH:mm",
                C._hm(new Date(2026, 0, 5, 7, 4)) === "07:04")

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
