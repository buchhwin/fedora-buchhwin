pragma Singleton

// iCalendar (RFC 5545), read and written.
//
// Pure JavaScript on purpose: no Quickshell type, no network, no clock. That is
// what makes it testable headlessly against fixed sample files, which matters
// more here than anywhere else in the project — every bug in this file is a
// meeting on the wrong day, and you find out about it by missing the meeting.
//
// ⚠️ THE CONSTRAINT THAT SHAPES THIS FILE: Quickshell's JS engine has NO `Intl`.
// Measured on the VM: `typeof Intl` is "undefined", so
// `new Intl.DateTimeFormat(…, {timeZone: "Europe/Berlin"})` throws a
// ReferenceError. There is therefore no way to ask the system what the offset
// of a named zone was on a given day.
//
// That is not a hole, because iCalendar does not need one. A VTIMEZONE
// component carries its own rules — TZOFFSETTO for STANDARD and DAYLIGHT, and
// an RRULE saying when each begins. So the offset is read out of the same file
// as the event, and the result does not depend on this machine's timezone
// database agreeing with Google's. Three cases, all exact:
//
//   DTSTART:…Z                     → UTC, offset 0
//   DTSTART;TZID=X:…               → the offset VTIMEZONE X gives for that date
//   DTSTART:… (no zone, "floating") → this machine's local time, by definition
//
// Everything downstream works in real Date instants and renders in system time,
// which is what a person looking at their own calendar expects to see.

import QtQuick
import Quickshell

Singleton {
    id: root

    // ⚠️ CONSTANT, and that is the honest answer rather than a formality.
    // `available` everywhere else in services/ means "the hardware or the daemon
    // this speaks to is there". This one speaks to neither: it is arithmetic and
    // string handling, and it works on a machine with no calendar, no network
    // and no clock set. So it is always true — but it is *present*, because
    // services/qmldir says every service carries the flag "without exception",
    // and a rule with one exception is a rule the next reader has to look up.
    readonly property bool available: true

    // ---------------------------------------------------------------- unfold
    // ⚠️ FIRST, always. iCalendar wraps long lines at 75 octets and continues
    // them with a leading space or tab. A parser that reads line by line
    // without unfolding first sees "SUMMARY:Team meeting about the" and a
    // separate junk line — and long summaries are exactly the ones that matter.
    function unfold(text) {
        return String(text).replace(/\r\n/g, "\n").replace(/\n[ \t]/g, "")
    }

    // ------------------------------------------------------------- one line
    // "DTSTART;TZID=Europe/Berlin:20260805T140000" →
    //   { name: "DTSTART", params: {TZID: "Europe/Berlin"}, value: "2026…" }
    //
    // The colon inside a parameter value has to survive: a quoted parameter may
    // contain one, and splitting on the first colon would cut the property in
    // the wrong place.
    function parseLine(line) {
        var i = 0, inQuote = false
        while (i < line.length) {
            var c = line.charAt(i)
            if (c === '"') inQuote = !inQuote
            else if (c === ":" && !inQuote) break
            i++
        }
        if (i >= line.length)
            return null

        var head = line.substring(0, i)
        var value = line.substring(i + 1)

        var parts = head.split(";")
        var out = { name: parts[0].toUpperCase(), params: {}, value: value }
        for (var p = 1; p < parts.length; p++) {
            var eq = parts[p].indexOf("=")
            if (eq < 0) continue
            var k = parts[p].substring(0, eq).toUpperCase()
            var v = parts[p].substring(eq + 1).replace(/^"|"$/g, "")
            out.params[k] = v
        }
        return out
    }

    // TEXT values escape these four. Order matters: unescaping the backslash
    // first would turn "\\n" (a literal backslash followed by n) into a newline.
    function unescapeText(s) {
        return String(s).replace(/\\([nN])/g, "\n")
                        .replace(/\\([,;\\])/g, "$1")
    }

    function escapeText(s) {
        return String(s).replace(/([\\,;])/g, "\\$1").replace(/\n/g, "\\n")
    }

    // ------------------------------------------------------------ date value
    // "20260805" or "20260805T140000" or "20260805T140000Z" → parts.
    function _parts(v) {
        var m = /^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$/.exec(String(v).trim())
        if (!m)
            return null
        return {
            y: +m[1], mo: +m[2] - 1, d: +m[3],
            h: m[4] ? +m[4] : 0, mi: m[5] ? +m[5] : 0, s: m[6] ? +m[6] : 0,
            utc: m[7] === "Z",
            dateOnly: !m[4]
        }
    }

    // A real instant from a value plus its parameters, using `zones` (from
    // VTIMEZONE) when the value names one.
    //
    // `zones` may be empty: an unknown TZID then falls back to local time. That
    // is wrong by at most an hour or two and is visibly a time, which beats
    // throwing away an event the user can see in Google.
    function toDate(value, params, zones) {
        var p = _parts(value)
        if (!p)
            return null

        if (p.dateOnly)
            // All-day: local midnight. It is a DAY, not an instant, and pinning
            // it to UTC would move it a day for anyone west of Greenwich.
            return new Date(p.y, p.mo, p.d, 0, 0, 0)

        if (p.utc)
            return new Date(Date.UTC(p.y, p.mo, p.d, p.h, p.mi, p.s))

        var tzid = params && params.TZID ? params.TZID : ""
        if (!tzid)
            return new Date(p.y, p.mo, p.d, p.h, p.mi, p.s)   // floating = local

        var offset = zoneOffset(zones, tzid, p)               // minutes east
        if (offset === null)
            return new Date(p.y, p.mo, p.d, p.h, p.mi, p.s)

        return new Date(Date.UTC(p.y, p.mo, p.d, p.h, p.mi, p.s) - offset * 60000)
    }

    // ------------------------------------------------------------- VTIMEZONE
    // Which offset a named zone was on at a given wall-clock date.
    //
    // A VTIMEZONE holds STANDARD and DAYLIGHT subcomponents, each with a
    // DTSTART and an RRULE for when it recurs. Rather than evaluate those rules
    // in general, this walks each subcomponent's occurrences for the year in
    // question and takes the one that started most recently — which is what the
    // rules mean, and is exact for the yearly switch every real zone uses.
    function zoneOffset(zones, tzid, p) {
        var z = zones ? zones[tzid] : null
        if (!z || !z.length)
            return null

        var want = Date.UTC(p.y, p.mo, p.d, p.h, p.mi, p.s)
        var best = null, bestAt = -Infinity

        for (var i = 0; i < z.length; i++) {
            var sub = z[i]
            var at = _zoneSwitchBefore(sub, p.y, want)
            if (at !== null && at <= want && at > bestAt) {
                bestAt = at
                best = sub
            }
        }
        // Before the first switch of that year, the other subcomponent is in
        // effect — that is December's rule, so take the latest of last year.
        if (!best) {
            for (var j = 0; j < z.length; j++) {
                var at2 = _zoneSwitchBefore(z[j], p.y - 1, want)
                if (at2 !== null && at2 > bestAt) { bestAt = at2; best = z[j] }
            }
        }
        return best ? best.offsetTo : null
    }

    // The most recent moment in `year` at which this subcomponent takes effect,
    // as a UTC-epoch number comparable with a wall-clock value.
    function _zoneSwitchBefore(sub, year, wantUtc) {
        var s = _parts(sub.start)
        if (!s)
            return null

        if (!sub.rrule) {
            var once = Date.UTC(s.y, s.mo, s.d, s.h, s.mi, s.s)
            return once <= wantUtc ? once : null
        }

        var r = parseRRule(sub.rrule)
        if (r.freq !== "YEARLY" || !r.byday || !r.byday.length)
            return null

        var bd = r.byday[0]
        var month = (r.bymonth && r.bymonth.length) ? r.bymonth[0] - 1 : s.mo
        var day = _nthWeekdayOfMonth(year, month, bd.day, bd.ordinal)
        if (day === null)
            return null

        var at = Date.UTC(year, month, day, s.h, s.mi, s.s)
        return at <= wantUtc ? at : null
    }

    // ---------------------------------------------------------------- RRULE
    // "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;UNTIL=20261231T235959Z" → an object.
    function parseRRule(text) {
        var out = { freq: "", interval: 1, count: 0, until: null,
                    byday: [], bymonth: [], bymonthday: [] }
        var bits = String(text).split(";")
        for (var i = 0; i < bits.length; i++) {
            var eq = bits[i].indexOf("=")
            if (eq < 0) continue
            var k = bits[i].substring(0, eq).toUpperCase()
            var v = bits[i].substring(eq + 1)
            if (k === "FREQ") out.freq = v.toUpperCase()
            else if (k === "INTERVAL") out.interval = Math.max(1, parseInt(v, 10) || 1)
            else if (k === "COUNT") out.count = parseInt(v, 10) || 0
            else if (k === "UNTIL") out.until = toDate(v, {}, null)
            else if (k === "BYMONTH") out.bymonth = v.split(",").map(function (x) { return parseInt(x, 10) })
            else if (k === "BYMONTHDAY") out.bymonthday = v.split(",").map(function (x) { return parseInt(x, 10) })
            else if (k === "BYDAY") {
                out.byday = v.split(",").map(function (x) {
                    var m = /^([+-]?\d+)?(SU|MO|TU|WE|TH|FR|SA)$/.exec(x.toUpperCase())
                    if (!m) return null
                    return { ordinal: m[1] ? parseInt(m[1], 10) : 0, day: _dayIndex(m[2]) }
                }).filter(function (x) { return x !== null })
            }
        }
        return out
    }

    function _dayIndex(code) {
        return ["SU", "MO", "TU", "WE", "TH", "FR", "SA"].indexOf(code)
    }

    // The date of the nth given weekday in a month. ordinal -1 means the LAST,
    // which is what every European DST rule uses and what a naive "5th Sunday"
    // implementation gets wrong in months that have only four.
    function _nthWeekdayOfMonth(year, month, weekday, ordinal) {
        if (ordinal > 0) {
            var first = new Date(year, month, 1).getDay()
            var offset = (weekday - first + 7) % 7
            var d = 1 + offset + (ordinal - 1) * 7
            return d <= new Date(year, month + 1, 0).getDate() ? d : null
        }
        if (ordinal < 0) {
            var lastDay = new Date(year, month + 1, 0).getDate()
            var lastWd = new Date(year, month, lastDay).getDay()
            var back = (lastWd - weekday + 7) % 7
            var d2 = lastDay - back + (ordinal + 1) * 7
            return d2 >= 1 ? d2 : null
        }
        return null
    }

    // --------------------------------------------------------------- parsing
    // The whole payload → { events: [...], zones: {...} }.
    //
    // Events keep their raw recurrence data; expanding it is a separate step,
    // because expansion needs a window and parsing does not.
    function parse(text) {
        var lines = root.unfold(text).split("\n")
        var events = [], zones = {}
        var ev = null, tz = null, sub = null

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (!line.length) continue
            var l = root.parseLine(line)
            if (!l) continue

            if (l.name === "BEGIN") {
                var what = l.value.toUpperCase()
                if (what === "VEVENT") ev = { uid: "", summary: "", location: "",
                                              start: null, end: null, allDay: false,
                                              rrule: "", exdates: [], recurrenceId: null,
                                              _startParams: {}, _endParams: {} }
                else if (what === "VTIMEZONE") tz = { id: "", subs: [] }
                else if (what === "STANDARD" || what === "DAYLIGHT")
                    sub = { start: "", rrule: "", offsetTo: 0 }
                continue
            }

            if (l.name === "END") {
                var w = l.value.toUpperCase()
                if (w === "VEVENT" && ev) { events.push(ev); ev = null }
                else if (w === "VTIMEZONE" && tz) {
                    if (tz.id) zones[tz.id] = tz.subs
                    tz = null
                } else if ((w === "STANDARD" || w === "DAYLIGHT") && sub && tz) {
                    tz.subs.push(sub); sub = null
                }
                continue
            }

            if (sub) {
                if (l.name === "DTSTART") sub.start = l.value
                else if (l.name === "RRULE") sub.rrule = l.value
                else if (l.name === "TZOFFSETTO") sub.offsetTo = _offsetMinutes(l.value)
                continue
            }
            if (tz) {
                if (l.name === "TZID") tz.id = l.value
                continue
            }
            if (!ev)
                continue

            switch (l.name) {
            case "UID":      ev.uid = l.value; break
            case "SUMMARY":  ev.summary = root.unescapeText(l.value); break
            case "LOCATION": ev.location = root.unescapeText(l.value); break
            case "RRULE":    ev.rrule = l.value; break
            case "DTSTART":
                ev._startRaw = l.value
                ev._startParams = l.params
                ev.allDay = l.params.VALUE === "DATE" || /^\d{8}$/.test(l.value.trim())
                break
            case "DTEND":
                ev._endRaw = l.value
                ev._endParams = l.params
                break
            case "EXDATE":
                var xs = l.value.split(",")
                for (var x = 0; x < xs.length; x++)
                    ev.exdates.push({ value: xs[x], params: l.params })
                break
            case "RECURRENCE-ID":
                ev.recurrenceId = { value: l.value, params: l.params }
                break
            }
        }

        // Resolve dates only now: the zones they may need are not known until
        // the whole payload has been read, and a VTIMEZONE is allowed to come
        // after the event that uses it.
        for (var e = 0; e < events.length; e++) {
            var v = events[e]
            v.start = v._startRaw ? root.toDate(v._startRaw, v._startParams, zones) : null
            v.end = v._endRaw ? root.toDate(v._endRaw, v._endParams, zones) : null
            if (!v.end && v.start)
                // No DTEND: an all-day event is one day, a timed one is a
                // moment. Both are what RFC 5545 says, and both matter for
                // deciding which day cell an event belongs in.
                v.end = v.allDay ? new Date(v.start.getTime() + 86400000)
                                 : new Date(v.start.getTime())
            for (var q = 0; q < v.exdates.length; q++)
                v.exdates[q].date = root.toDate(v.exdates[q].value, v.exdates[q].params, zones)
            if (v.recurrenceId)
                v.recurrenceId.date = root.toDate(v.recurrenceId.value,
                                                  v.recurrenceId.params, zones)
        }

        return { events: events, zones: zones }
    }

    function _offsetMinutes(s) {
        var m = /^([+-])(\d{2})(\d{2})$/.exec(String(s).trim())
        if (!m) return 0
        var v = (+m[2]) * 60 + (+m[3])
        return m[1] === "-" ? -v : v
    }

    // ------------------------------------------------------------- expansion
    // Events → the instances that fall inside [from, to).
    //
    // ⚠️ This is the part that decides whether a weekly meeting appears once or
    // every week. Google sends the master event plus separate VEVENTs carrying
    // RECURRENCE-ID for any instance that was moved or changed; those override
    // the generated one, and EXDATE removes it entirely.
    function expand(parsed, from, to) {
        var out = []
        var overrides = {}

        var i
        for (i = 0; i < parsed.events.length; i++) {
            var o = parsed.events[i]
            if (o.recurrenceId && o.recurrenceId.date)
                overrides[o.uid + "@" + o.recurrenceId.date.getTime()] = o
        }

        for (i = 0; i < parsed.events.length; i++) {
            var ev = parsed.events[i]
            if (!ev.start || ev.recurrenceId)
                continue

            if (!ev.rrule) {
                if (_overlaps(ev.start, ev.end, from, to))
                    out.push(_instance(ev, ev.start, ev.end))
                continue
            }

            var r = root.parseRRule(ev.rrule)
            var length = ev.end ? ev.end.getTime() - ev.start.getTime() : 0
            var cursor = new Date(ev.start.getTime())
            var made = 0
            // A hard stop, so a malformed rule cannot spin: no calendar view
            // needs more instances than this, and silently looping forever is
            // the worst possible failure for a shell.
            var guard = 0

            while (guard++ < 2000) {
                if (r.count && made >= r.count) break
                if (r.until && cursor.getTime() > r.until.getTime()) break
                if (cursor.getTime() >= to.getTime()) break

                var dates = _instancesAt(r, cursor, ev.start)
                for (var d = 0; d < dates.length; d++) {
                    var st = dates[d]
                    if (r.count && made >= r.count) break
                    if (r.until && st.getTime() > r.until.getTime()) break
                    made++
                    if (_excluded(ev, st)) continue
                    var over = overrides[ev.uid + "@" + st.getTime()]
                    if (over) {
                        if (_overlaps(over.start, over.end, from, to))
                            out.push(_instance(over, over.start, over.end))
                        continue
                    }
                    var en = new Date(st.getTime() + length)
                    if (_overlaps(st, en, from, to))
                        out.push(_instance(ev, st, en))
                }
                cursor = _advance(r, cursor)
                if (!cursor) break
            }
        }

        out.sort(function (a, b) { return a.start.getTime() - b.start.getTime() })
        return out
    }

    function _instance(ev, start, end) {
        return { uid: ev.uid, summary: ev.summary, location: ev.location,
                 start: start, end: end, allDay: ev.allDay, href: ev.href || "",
                 etag: ev.etag || "" }
    }

    // An event belongs to a window when it overlaps it at all — an all-day
    // event that started yesterday and ends tomorrow is on today's page.
    function _overlaps(start, end, from, to) {
        if (!start) return false
        var e = end ? end.getTime() : start.getTime()
        return e >= from.getTime() && start.getTime() < to.getTime()
    }

    function _excluded(ev, when) {
        for (var i = 0; i < ev.exdates.length; i++) {
            var x = ev.exdates[i].date
            if (x && x.getTime() === when.getTime())
                return true
        }
        return false
    }

    // The occurrences generated by one step of the rule. For WEEKLY with BYDAY
    // that is several dates in the same week; otherwise it is the cursor.
    function _instancesAt(r, cursor, first) {
        if (r.freq === "WEEKLY" && r.byday.length) {
            var out = []
            var monday = new Date(cursor.getTime())
            monday.setDate(monday.getDate() - ((monday.getDay() + 6) % 7))
            for (var i = 0; i < r.byday.length; i++) {
                var d = new Date(monday.getTime())
                d.setDate(d.getDate() + ((r.byday[i].day + 6) % 7))
                d.setHours(first.getHours(), first.getMinutes(), first.getSeconds(), 0)
                if (d.getTime() >= first.getTime())
                    out.push(d)
            }
            out.sort(function (a, b) { return a - b })
            return out
        }
        if (r.freq === "MONTHLY" && r.byday.length) {
            var res = []
            for (var j = 0; j < r.byday.length; j++) {
                var day = root._nthWeekdayOfMonth(cursor.getFullYear(), cursor.getMonth(),
                                                  r.byday[j].day, r.byday[j].ordinal)
                if (day === null) continue
                var m = new Date(cursor.getFullYear(), cursor.getMonth(), day,
                                 first.getHours(), first.getMinutes(), first.getSeconds())
                if (m.getTime() >= first.getTime())
                    res.push(m)
            }
            return res
        }
        return [new Date(cursor.getTime())]
    }

    function _advance(r, cursor) {
        var d = new Date(cursor.getTime())
        switch (r.freq) {
        case "DAILY":   d.setDate(d.getDate() + r.interval); break
        case "WEEKLY":  d.setDate(d.getDate() + 7 * r.interval); break
        case "MONTHLY": d.setMonth(d.getMonth() + r.interval); break
        case "YEARLY":  d.setFullYear(d.getFullYear() + r.interval); break
        default: return null
        }
        return d
    }

    // ---------------------------------------------------------------- writing
    // One VEVENT, ready to PUT. Times go out as UTC, which needs no VTIMEZONE
    // and cannot be misread; all-day events go out as DATE values, which is the
    // only way a birthday stays on its day everywhere.
    function build(ev) {
        function pad(n) { return n < 10 ? "0" + n : "" + n }
        function utc(d) {
            return d.getUTCFullYear() + pad(d.getUTCMonth() + 1) + pad(d.getUTCDate()) +
                   "T" + pad(d.getUTCHours()) + pad(d.getUTCMinutes()) +
                   pad(d.getUTCSeconds()) + "Z"
        }
        function dateOnly(d) {
            return d.getFullYear() + pad(d.getMonth() + 1) + pad(d.getDate())
        }

        var out = []
        out.push("BEGIN:VCALENDAR")
        out.push("VERSION:2.0")
        out.push("PRODID:-//buchhwin//desktop//DE")
        out.push("BEGIN:VEVENT")
        out.push("UID:" + ev.uid)
        out.push("DTSTAMP:" + utc(ev.stamp || ev.start))
        if (ev.allDay) {
            out.push("DTSTART;VALUE=DATE:" + dateOnly(ev.start))
            // DTEND is EXCLUSIVE for DATE values: a one-day event ends the
            // following day. Writing the same day makes a zero-length event
            // that some clients hide entirely.
            out.push("DTEND;VALUE=DATE:" + dateOnly(ev.end || new Date(ev.start.getTime() + 86400000)))
        } else {
            out.push("DTSTART:" + utc(ev.start))
            out.push("DTEND:" + utc(ev.end || ev.start))
        }
        out.push("SUMMARY:" + root.escapeText(ev.summary || ""))
        if (ev.location && ev.location.length)
            out.push("LOCATION:" + root.escapeText(ev.location))
        out.push("END:VEVENT")
        out.push("END:VCALENDAR")
        // CRLF: RFC 5545 says so, and some servers are strict about it.
        return out.join("\r\n") + "\r\n"
    }

    // A UID that is unique without a random source. Quickshell's JS has
    // Math.random, but a UID that collides is a silently overwritten event, so
    // this leans on the clock and a counter instead of hoping.
    property int _seq: 0
    function newUid() {
        root._seq++
        return "buchhwin-" + new Date().getTime() + "-" + root._seq + "@buchhwin"
    }
}
