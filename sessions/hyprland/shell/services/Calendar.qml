pragma Singleton

// Google Calendar, over CalDAV, using the account you already added.
//
// The route here is not the obvious one, and the reason is measured rather than
// preferred. The obvious route is evolution-data-server, which is what GNOME
// uses. It cannot work from this shell:
//
//   $ busctl call … CalendarFactory OpenCalendar s "system-calendar"
//   ss "/org/gnome/evolution/dataserver/Subprocess/2505/2" …
//   $ busctl call … "/org/gnome/evolution/dataserver/Subprocess/2505/2" … GetObjectList
//   Call failed: Object does not exist at path "…/Subprocess/2505/2"
//
// EDS ties an opened calendar to the CALLING D-BUS CONNECTION. Every `busctl`
// invocation is a new connection, so the object is gone before it can be
// queried — and busctl is the only door available, because Quickshell 0.2.1
// ships no DBus module. Using EDS would mean a permanently running helper in C,
// with a build step, in a project that has none.
//
// So: gnome-online-accounts holds the account and hands out an OAuth token
// (ONE short call, nothing that can die under us), and this talks CalDAV to
// Google directly.
//
// ⚠️⚠️ THERE WERE TWO WALLS, both measured on 08.08.2026, and only ONE of them
// is down. Either alone is fatal, which is why "the calendar does not work"
// survived four handovers: fixing one changed nothing visible.
//
//   1. ⚠️ STILL STANDING — THE TOKEN CARRIES NO CALENDAR SCOPE. `bhctl calendar`
//      asks Google's tokeninfo endpoint and gets back exactly: email, profile,
//      userinfo.email, userinfo.profile, openid. So Google answers 403, which is
//      the correct answer to the question being asked. evolution-data-server is
//      not installed, and EDS is what GOA hands calendars to — with nothing to
//      hand them to, nothing ever requests the scope.
//
//      ⚠️ ONLY HE CAN TAKE THIS DOWN: the account has to be removed and added
//      again in Online Accounts with Calendar ticked. Nothing in this file can.
//      Until then every request here ends in the 403 branch, and every one of
//      those branches SAYS SO on screen rather than leaving a blank month.
//
//   2. ✅ DOWN — QML's XMLHttpRequest had no `REPORT` method. PROPFIND was
//      accepted; REPORT, the one CalDAV uses to ask for events, threw
//      "Unsupported HTTP method type". The transport is `curl` now — see the
//      note above `_curlConfig`, and the measurement that a real server answers
//      a REPORT sent that way.
//
// ⚠️ THIS ORDER WAS DELIBERATE AND IT IS WORTH KNOWING WHY, because it breaks
// this project's own rule about measuring before building. Replacing a
// transport before proving it was the broken part is how you fix the wrong
// thing. It was built anyway, on his instruction — wall 2 is fatal
// INDEPENDENTLY of the token, so removing it costs nothing even if it turns out
// wall 1 was hiding something else. What it does NOT do is make appointments
// appear. That needs him.
//
// ⚠️ The note above about EDS being unusable was about DRIVING it over `busctl`,
// and that measurement still stands. It is not an argument against installing
// it so that GOA has somewhere to put a calendar.
//
// The token is held in memory only. It is a bearer credential with about an
// hour of life; writing it to disk would be writing a password to disk — and it
// never reaches a command line either, for the same reason.

import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Singleton {
    id: root

    // ------------------------------------------------------------- interface
    readonly property bool available: root.accountPath.length > 0 && root.collection.length > 0

    // What to say when `available` is false. A calendar page that is simply
    // empty cannot be told apart from a calendar with nothing in it.
    property string status: "No account set up"

    property string accountName: ""      // the address, for display
    property string accountPath: ""      // GOA object path
    property string collection: ""       // CalDAV URL of the calendar
    property bool busy: false

    // Instances for the window that was last requested, already expanded.
    property var events: []

    // The day a new appointment should default to. Set by the calendar page
    // before it hands over, so "new appointment" means the day you were looking
    // at rather than today — which is almost never the day you meant.
    property date draftDate: new Date()

    readonly property string endpoint: "https://apidata.googleusercontent.com/caldav/v2/"

    signal changed()                     // something was written; reload

    // ---------------------------------------------------------------- token
    property string _token: ""
    property double _tokenUntil: 0       // epoch ms

    function _tokenValid() {
        return root._token.length > 0 && new Date().getTime() < root._tokenUntil
    }

    // Everything that needs the network goes through here, so there is exactly
    // one place that knows how a token is obtained and when it has gone stale.
    property var _pending: null
    function _withToken(fn) {
        if (root._tokenValid()) { fn(root._token); return }
        root._pending = fn
        tokenProc.command = ["busctl", "--user", "--json=short", "call",
                             "org.gnome.OnlineAccounts", root.accountPath,
                             "org.gnome.OnlineAccounts.OAuth2Based", "GetAccessToken"]
        tokenProc.running = true
    }

    Process {
        id: tokenProc
        stdout: StdioCollector {
            onStreamFinished: {
                var fn = root._pending
                root._pending = null
                try {
                    var j = JSON.parse(text)
                    root._token = String(j.data[0])
                    // Renew a minute early. A request that starts valid and
                    // finishes expired fails in a way that looks like a bug in
                    // the calendar rather than in the clock.
                    var secs = Number(j.data[1]) || 3600
                    root._tokenUntil = new Date().getTime() + (secs - 60) * 1000
                } catch (e) {
                    root._token = ""
                    root.status = "Online Accounts returned no access token"
                    return
                }
                if (fn) fn(root._token)
            }
        }
    }

    // ------------------------------------------------------------ transport
    //
    // ⚠️⚠️ `curl`, NOT QML's XMLHttpRequest, AND IT IS NOT A PREFERENCE. Qt's
    // HTTP client has no `REPORT`: `open("REPORT", …)` throws "Unsupported HTTP
    // method type", and REPORT is the one method CalDAV uses to ask for events.
    // The previous version of this file could not have fetched a single
    // appointment with a perfect token. Measured against a real server on
    // 10.08.2026 — curl sends `REPORT /probe HTTP/2` and a status comes back.
    //
    // ⚠️⚠️ AND THE TOKEN NEVER TOUCHES THE COMMAND LINE. It is a bearer
    // credential — whoever holds it is the account for the next hour — and
    // /proc/<pid>/cmdline is readable by EVERY process on the machine, not only
    // by this user. So the entire request, headers and body included, goes in
    // over stdin through `curl --config -`.
    //
    // Measured with a control that can fail, because a scan that finds nothing
    // either way is not a measurement: the same token passed as `-H` was found
    // in argv (1 hit), passed through --config it was not (0). ⚠️ The first
    // attempt at that control counted its own `grep` and reported a hit for
    // both — the same trap tests/xwayland.sh fell into.
    //
    // ⚠️ ONE REQUEST AT A TIME, through a queue. A single Process cannot run
    // two, and discovery, a month load and a save can overlap — a second
    // `running = true` on a busy process is a request that silently never
    // happens.

    // Quote for curl's config format. The escapes are the ones curl documents
    // for a quoted value, and the CR/LF pair matters: an iCalendar body is
    // CRLF-separated and would otherwise end the line mid-request.
    function _q(s) {
        return '"' + String(s).replace(/\\/g, "\\\\")
                              .replace(/"/g, '\\"')
                              .replace(/\r/g, "\\r")
                              .replace(/\n/g, "\\n")
                              .replace(/\t/g, "\\t") + '"'
    }

    // ⚠️ AN UNLIKELY MARKER, appended by curl itself after the body, because
    // the status code has to arrive out of band. A plain "%{http_code}" would
    // be indistinguishable from three digits at the end of a response.
    readonly property string _mark: "buchhwin-caldav-status"

    function _curlConfig(req) {
        var c = "url = " + root._q(req.url) + "\n"
        c += "request = " + root._q(req.method) + "\n"
        c += "header = " + root._q("Authorization: Bearer " + req.token) + "\n"
        var h = req.headers || []
        for (var i = 0; i < h.length; i++)
            c += "header = " + root._q(h[i]) + "\n"
        if (req.body !== undefined && req.body !== null && String(req.body).length)
            c += "data-binary = " + root._q(req.body) + "\n"
        // A hung request must not leave the panel saying "loading" for ever.
        c += "max-time = 25\n"
        c += "silent\nshow-error\n"
        c += "write-out = " + root._q("\n<<<" + root._mark + " %{http_code}>>>") + "\n"
        return c
    }

    property var _queue: []
    property var _job: null

    function _http(req, done) {
        var q = root._queue.slice()
        q.push({ req: req, done: done })
        root._queue = q
        root._pump()
    }

    function _pump() {
        if (root._job !== null || http.running || !root._queue.length)
            return
        var q = root._queue.slice()
        root._job = q.shift()
        root._queue = q
        http.stdinEnabled = true
        http.running = true
    }

    Process {
        id: http
        command: ["curl", "--config", "-"]
        stdinEnabled: true

        onStarted: {
            if (root._job === null)
                return
            http.write(root._curlConfig(root._job.req))
            // ⚠️ CLOSING STDIN IS NOT OPTIONAL. `--config -` reads until EOF;
            // leave it open and curl waits for a request that has already been
            // written in full, `max-time` never starts, and the calendar simply
            // never answers.
            http.stdinEnabled = false
        }

        stdout: StdioCollector { id: httpOut }
        stderr: StdioCollector { id: httpErr }

        onExited: function (code) {
            var job = root._job
            root._job = null
            if (job && job.done) {
                var body = String(httpOut.text)
                var status = 0
                var m = new RegExp("<<<" + root._mark + " (\\d+)>>>\\s*$").exec(body)
                if (m) {
                    status = Number(m[1])
                    body = body.substring(0, m.index)
                }
                job.done({ ok: code === 0, exit: code, status: status,
                           body: body, error: String(httpErr.text).trim() })
            }
            root._pump()
        }
    }

    // What to say when curl itself could not run the request — no network, DNS
    // down, the 25 s cap. ⚠️ Distinct from an HTTP status on purpose: "no
    // answer" and "answered no" send you to look in different places.
    function _reachFail(r) {
        return "Could not reach Google: "
             + (r.error.length ? r.error : "curl exited " + r.exit)
    }

    // -------------------------------------------------------------- account
    // Find a Google account that has the calendar switched on.
    function refreshAccount() {
        accounts.running = true
    }

    Process {
        id: accounts
        command: ["busctl", "--user", "--json=short", "call",
                  "org.gnome.OnlineAccounts", "/org/gnome/OnlineAccounts",
                  "org.freedesktop.DBus.ObjectManager", "GetManagedObjects"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.accountPath = ""
                root.accountName = ""
                root.collection = ""

                var objs
                try {
                    objs = JSON.parse(text).data[0]
                } catch (e) {
                    root.status = "Online Accounts is not answering"
                    return
                }

                for (var path in objs) {
                    var ifaces = objs[path]
                    var acc = ifaces["org.gnome.OnlineAccounts.Account"]
                    if (!acc) continue
                    if (!ifaces["org.gnome.OnlineAccounts.OAuth2Based"]) continue

                    var provider = acc.ProviderType ? String(acc.ProviderType.data) : ""
                    if (provider !== "google") continue

                    // GOA states this as a NEGATIVE, and reading it as "is the
                    // calendar on" would enable exactly the accounts that have
                    // it switched off.
                    var off = acc.CalendarDisabled ? acc.CalendarDisabled.data : true
                    if (off === true) continue

                    root.accountPath = path
                    root.accountName = acc.PresentationIdentity
                                       ? String(acc.PresentationIdentity.data) : ""
                    break
                }

                if (!root.accountPath.length) {
                    root.status = "No Google account with the calendar switched on"
                    return
                }
                root.status = "Looking for the calendar …"
                root._findCalendar()
            }
        }
    }

    // ------------------------------------------------------------ discovery
    // Google exposes the primary calendar of an account at
    // <endpoint><address>/events/. The principal is asked first anyway, because
    // an address that differs from the account id (an alias, a Workspace
    // domain) makes the guessed URL wrong — and the failure would be a calendar
    // that is simply always empty.
    function _findCalendar() {
        if (!root.accountName.length) {
            root.status = "The account has no address"
            return
        }
        var guess = root.endpoint + encodeURIComponent(root.accountName) + "/events/"
        root._withToken(function (tok) {
            root._http({
                method: "PROPFIND", url: guess, token: tok,
                headers: ["Depth: 0", "Content-Type: application/xml; charset=utf-8"],
                body: '<?xml version="1.0" encoding="utf-8"?>' +
                      '<d:propfind xmlns:d="DAV:"><d:prop><d:displayname/></d:prop></d:propfind>'
            }, function (r) {
                if (!r.ok) {
                    root.status = root._reachFail(r)
                    return
                }
                if (r.status >= 200 && r.status < 300) {
                    root.collection = guess
                    root.status = ""
                    root.changed()
                } else if (r.status === 401) {
                    // The token was refused: drop it so the next attempt gets
                    // a fresh one instead of retrying with the same bad value.
                    root._token = ""
                    root.status = "Sign-in refused — reconnect the account"
                } else if (r.status === 403) {
                    // ⚠️ 403 IS NOT 401 AND THE DIFFERENCE IS THE WHOLE
                    // DIAGNOSIS. This fell into "Calendar not found", which is
                    // wrong in the most expensive way: the account is there, the
                    // token is valid, and Google is refusing this particular
                    // request. Measured with `bhctl calendar` on his machine —
                    // the token's scopes are email, profile, userinfo.* and
                    // openid, with NO calendar scope at all.
                    //
                    // Online Accounts reports the calendar as enabled for the
                    // account, so nothing in the UI contradicts it; the grant
                    // Google actually issued simply does not cover a calendar.
                    // Retrying, re-signing in, or refreshing the token cannot
                    // change that — only consenting again with Calendar ticked.
                    //
                    // ⚠️ THE TOKEN IS NOT DROPPED HERE, unlike on 401. It is a
                    // perfectly good token; throwing it away would start a
                    // refresh loop against a wall.
                    root.status = "Google refused the calendar (403) — the "
                                + "account is connected but was never granted "
                                + "calendar access. Add it again in Online "
                                + "Accounts with Calendar ticked, or run "
                                + "`bhctl calendar` to see the scopes."
                } else {
                    root.status = "Calendar not found (HTTP " + r.status + ")"
                }
            })
        })
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
        // step would mean four round trips whose first three results are thrown
        // away — paid for in radio time, which on a laptop is paid for twice.
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

    function _load(from, to) {
        root.busy = true
        root._withToken(function (tok) {
            // ⚠️ `REPORT` IS THE WHOLE REASON THIS FILE STOPPED USING QML's
            // XMLHttpRequest. Qt refused the method outright — "Unsupported HTTP
            // method type", thrown into the journal on every refresh, where
            // nobody reads it — so this call could never have returned an
            // appointment no matter what the token carried.
            root._http({
                method: "REPORT", url: root.collection, token: tok,
                headers: ["Depth: 1", "Content-Type: application/xml; charset=utf-8"],
                body: '<?xml version="1.0" encoding="utf-8"?>' +
                      '<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">' +
                      '<d:prop><d:getetag/><c:calendar-data/></d:prop>' +
                      '<c:filter><c:comp-filter name="VCALENDAR">' +
                      '<c:comp-filter name="VEVENT">' +
                      '<c:time-range start="' + root._utcStamp(from) +
                      '" end="' + root._utcStamp(to) + '"/>' +
                      '</c:comp-filter></c:comp-filter></c:filter>' +
                      '</c:calendar-query>'
            }, function (r) {
                root.busy = false
                if (!r.ok) {
                    root.status = root._reachFail(r)
                    return
                }
                if (r.status === 401) {
                    root._token = ""
                    root.status = "Sign-in refused"
                    return
                }
                if (r.status === 403) {
                    // The same wall as in discovery, and it has to say the same
                    // thing here: a month view that is merely empty cannot be
                    // told apart from a month with nothing in it.
                    root.status = "Google refused the calendar (403) — the "
                                + "account is connected but was never granted "
                                + "calendar access. Add it again in Online "
                                + "Accounts with Calendar ticked, or run "
                                + "`bhctl calendar` to see the scopes."
                    return
                }
                if (r.status < 200 || r.status >= 300) {
                    root.status = "Events could not be fetched (HTTP " + r.status + ")"
                    return
                }
                root.status = ""
                root.events = root._readMultistatus(r.body, from, to)
            })
        })
    }

    function _utcStamp(d) {
        function p(n) { return n < 10 ? "0" + n : "" + n }
        return d.getUTCFullYear() + p(d.getUTCMonth() + 1) + p(d.getUTCDate()) +
               "T" + p(d.getUTCHours()) + p(d.getUTCMinutes()) + p(d.getUTCSeconds()) + "Z"
    }

    // The multistatus response, one <response> per event resource.
    //
    // Read with regular expressions rather than responseXML on purpose: the
    // document is namespaced three ways (DAV:, caldav, sometimes Google's own),
    // and QML's DOM makes namespace-aware traversal far more code than the two
    // things actually needed here — the href, the etag, and the iCalendar text.
    // The iCalendar itself is parsed properly, by services/Ical.qml.
    function _readMultistatus(xml, from, to) {
        var out = []
        var blocks = String(xml).split(/<[a-zA-Z0-9]*:?response[\s>]/)
        for (var i = 1; i < blocks.length; i++) {
            var b = blocks[i]
            var href = /<[a-zA-Z0-9]*:?href[^>]*>([\s\S]*?)<\/[a-zA-Z0-9]*:?href>/.exec(b)
            var etag = /<[a-zA-Z0-9]*:?getetag[^>]*>([\s\S]*?)<\/[a-zA-Z0-9]*:?getetag>/.exec(b)
            var data = /<[a-zA-Z0-9]*:?calendar-data[^>]*>([\s\S]*?)<\/[a-zA-Z0-9]*:?calendar-data>/.exec(b)
            if (!data)
                continue

            var ical = root._unescapeXml(data[1])
            var parsed = Ical.parse(ical)
            var instances = Ical.expand(parsed, from, to)
            for (var k = 0; k < instances.length; k++) {
                instances[k].href = href ? root._unescapeXml(href[1]).trim() : ""
                instances[k].etag = etag ? root._unescapeXml(etag[1]).trim() : ""
                out.push(instances[k])
            }
        }
        out.sort(function (a, b) { return a.start.getTime() - b.start.getTime() })
        return out
    }

    function _unescapeXml(s) {
        return String(s).replace(/&lt;/g, "<").replace(/&gt;/g, ">")
                        .replace(/&quot;/g, '"').replace(/&#39;/g, "'")
                        .replace(/&amp;/g, "&")
    }

    // --------------------------------------------------------------- writing
    // Create an appointment. This is the call that ends up on the phone.
    function create(ev, done) {
        if (!root.available) { if (done) done(false, "No calendar connected"); return }

        var uid = Ical.newUid()
        var body = Ical.build({ uid: uid, summary: ev.summary, location: ev.location,
                                start: ev.start, end: ev.end, allDay: ev.allDay,
                                stamp: new Date() })
        var url = root.collection + encodeURIComponent(uid) + ".ics"

        root._withToken(function (tok) {
            root._http({
                method: "PUT", url: url, token: tok,
                headers: ["Content-Type: text/calendar; charset=utf-8",
                          // Create, never overwrite. Without this a repeated
                          // press could silently replace an appointment that
                          // happened to share a URL.
                          "If-None-Match: *"],
                body: body
            }, function (r) {
                if (!r.ok) {
                    if (done) done(false, root._reachFail(r))
                    return
                }
                if (r.status >= 200 && r.status < 300) {
                    root.changed()
                    if (done) done(true, "")
                } else if (r.status === 412) {
                    // If-None-Match refused it: something is already there.
                    if (done) done(false, "That event already exists")
                } else {
                    if (r.status === 401) root._token = ""
                    if (done) done(false, "Not saved (HTTP " + r.status + ")")
                }
            })
        })
    }

    // Delete one instance's resource. Guarded by the etag, so a resource that
    // changed on the phone since it was displayed is NOT deleted blind.
    function remove(ev, done) {
        if (!root.available || !ev.href || !ev.href.length) {
            if (done) done(false, "No event selected")
            return
        }
        var url = /^https?:/.test(ev.href)
                  ? ev.href : "https://apidata.googleusercontent.com" + ev.href

        root._withToken(function (tok) {
            var heads = []
            if (ev.etag && ev.etag.length)
                heads.push("If-Match: " + ev.etag)
            root._http({
                method: "DELETE", url: url, token: tok, headers: heads
            }, function (r) {
                if (!r.ok) {
                    if (done) done(false, root._reachFail(r))
                    return
                }
                if (r.status >= 200 && r.status < 300) {
                    root.changed()
                    if (done) done(true, "")
                } else if (r.status === 412) {
                    if (done) done(false, "The event changed elsewhere — reload")
                } else {
                    if (r.status === 401) root._token = ""
                    if (done) done(false, "Not deleted (HTTP " + r.status + ")")
                }
            })
        })
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
            // An all-day event's DTEND is exclusive, so one ending exactly at
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
            // An all-day event's DTEND is exclusive: one ending exactly at
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
