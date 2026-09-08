pragma Singleton

// The one place the time is turned into text.
//
// ⚠️ IT EXISTS BECAUSE THERE WERE FOUR. The collapsed island, the widened
// island, the bar and the lock screen each built the time by hand, each with its
// own copy of the same two-line pad helper:
//
//     function p(n) { return n < 10 ? "0" + n : "" + n }
//     return p(clock.hours) + ":" + p(clock.minutes)
//
// Four copies of one format is how three of them get a setting and the fourth
// does not — and the fourth is the island, which is the clock you actually look
// at. So `clock.format` and `clock.showSeconds` have exactly one reader, and
// that reader is here.
//
// ⚠️ AND `precision` IS PART OF THE SAME ANSWER. Every SystemClock in the shell
// asks for MINUTE precision, which means it wakes on the minute boundary and
// sleeps in between; showing seconds means a redraw every second, on a laptop,
// with the lid possibly shut. A call site that took the format from here and
// kept its own precision would show a seconds digit that changed once a minute —
// worse than not offering it. One property, read by all four.
import QtQuick
import Quickshell
import "../config"

Singleton {
    id: root

    // ⚠️ Guarded, like every other reader of a config block. During shell
    // construction `Config.clock` is briefly NULL — not "still the defaults",
    // null — and dereferencing it there is the crash this project knows by
    // heart. Three small guards at the reading end beat one clever one at the
    // announcing end; see the long note on `settled` in config/Config.qml.
    readonly property bool twelveHour: Config.clock ? Config.clock.format === "12h" : false
    readonly property bool seconds: Config.clock ? Config.clock.showSeconds === true : false

    // What every SystemClock in the shell should ask for.
    readonly property int precision: root.seconds ? SystemClock.Seconds : SystemClock.Minutes

    function pad(n) { return n < 10 ? "0" + n : "" + n }

    // A Date in, the time out. Anything that is not "12h" reads as 24-hour
    // rather than failing: a clock is not a thing to refuse to draw.
    function time(d) {
        if (!d)
            return ""
        var h = d.getHours()
        var suffix = ""
        if (root.twelveHour) {
            suffix = h < 12 ? " AM" : " PM"
            h = h % 12
            if (h === 0)
                h = 12
        }
        // ⚠️ No leading zero on a 12-hour clock — "09:05 AM" is not how anyone
        // writes it — and always one on a 24-hour clock, or the island's width
        // jumps at ten o'clock.
        var s = (root.twelveHour ? String(h) : root.pad(h)) + ":" + root.pad(d.getMinutes())
        if (root.seconds)
            s += ":" + root.pad(d.getSeconds())
        return s + suffix
    }

    // Qt's own formatter, not JS. Quickshell's JS engine has no `Intl`, so
    // anything through toLocaleDateString comes back in a format nobody asked
    // for. An explicit pattern rather than a format enum, because those were
    // renamed between Qt 5 and 6 and a wrong one fails silently to an empty
    // string. The day and month NAMES still come from the system locale.
    function date(d) {
        return root._formatted(d, Config.clock ? Config.clock.dateFormat : "", "dddd, d MMMM")
    }

    // The short form, for the widened island — a pill rather than a screen.
    function dateShort(d) {
        return root._formatted(d, Config.clock ? Config.clock.dateFormatShort : "", "ddd, d MMM")
    }

    // An empty pattern falls back rather than drawing nothing: a date field
    // cleared by accident should look wrong, not look absent.
    function _formatted(d, pattern, fallback) {
        if (!d)
            return ""
        var f = String(pattern === undefined || pattern === null ? "" : pattern)
        return Qt.formatDate(d, f.length > 0 ? f : fallback)
    }

    // Whether the week starts on Monday. ⚠️ Its one reader moves the column
    // headings AND the blank cells before the 1st together — they are one
    // decision, and changing either alone puts every date on the wrong weekday.
    readonly property bool mondayFirst:
        Config.clock ? Config.clock.weekStart !== "sunday" : true
}
