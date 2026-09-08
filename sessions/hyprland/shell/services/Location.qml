pragma Singleton

// Where this machine is. Once, for everything that needs it.
//
// It started inside the weather, which was the wrong home: a location is a
// property of the computer, not of one feature. Three things want it already —
// the weather, the sunrise/sunset that will drive automatic light/dark
// (theme.lightPalette has been waiting for exactly that since M1), and
// gammastep's night light, which takes latitude and longitude as arguments.
//
// ⚠️ AND USUALLY IT NEEDS NO INPUT AT ALL. The system already knows roughly
// where it is: /usr/share/zoneinfo/zone1970.tab maps every timezone to
// coordinates, offline and always present. Europe/Berlin is +5230+01322.
//
// That guess is OFFERED, never asserted. A timezone names its REFERENCE city,
// not yours — somebody in Stuttgart would silently get Berlin's weather, which
// is the worst kind of wrong: plausible. So `source` records where the answer
// came from, the panel says "guessed from the timezone" while it is only a
// guess, and a timezone change may update a guess but must never overwrite
// something you confirmed.
//
// Automatic geolocation was measured and rejected. geoclue is installed, but
// its whitelist in /etc/geoclue/geoclue.conf admits only gnome-shell, phosh and
// friends — a system file would have to be edited before our user program could
// even ask — and it locates by IP through the Mozilla database whose service
// was discontinued. City accuracy at best: exactly what the timezone gives, but
// needing the network, and wrong behind a VPN.

import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
import "." as Services

Singleton {
    id: root

    // ⚠️ A GUESS IS NOT A SETTING, SO IT IS NEVER WRITTEN DOWN.
    //
    // The timezone guess used to be saved to shell.json on first run. Two
    // things were wrong with that, and the second one cost a debugging round:
    //
    //   * A file should record decisions, not assumptions. Writing the guess
    //     made it indistinguishable from an answer, one `source` field away.
    //   * Writing the config DURING STARTUP crashes quickshell. Measured, not
    //     guessed: a config already holding a guessed location rewrote it on
    //     every start and crashed eight times in three restarts; skipping the
    //     rewrite left exactly one crash — the single start that did write.
    //
    // So the guess lives in memory and is recomputed each start. It costs one
    // `timedatectl` and one file read, offline, and it is always current: a
    // laptop that crosses a border guesses the new place rather than carrying
    // last month's around. Only a DECISION is written, and decisions happen
    // when you click, long after the shell has finished starting.
    readonly property string name:
        Config.location.name.length ? Config.location.name
      : (root._ipName.length ? root._ipName : root._guessName)
    readonly property real lat:
        Config.location.name.length ? Config.location.lat
      : (root._ipName.length ? root._ipLat : root._guessLat)
    readonly property real lon:
        Config.location.name.length ? Config.location.lon
      : (root._ipName.length ? root._ipLon : root._guessLon)

    // "" = nothing known · "timezone" = guessed from the clock · "ip" = asked
    // the network · "manual" = you said so
    //
    // ⚠️ THE ORDER IS THE ANSWER TO HIS QUESTION, and it is a ranking rather
    // than a preference: what you typed beats what the network says, and what
    // the network says beats a constant per country. The timezone guess cannot
    // tell his office from his flat — zone1970.tab has one line for all of
    // Germany — so it is the floor, not the answer.
    //
    // ⚠️ AND IT IS SHOWN, WHICH IS HIS EXPLICIT REQUIREMENT: the weather panel
    // says which of these four it is. A place that came from an IP lookup and a
    // place somebody typed must not look the same.
    readonly property string source:
        Config.location.name.length ? "manual"
      : (root._ipName.length ? "ip"
      : (root._guessName.length ? "timezone" : ""))

    property string _guessName: ""
    property real _guessLat: NaN
    property real _guessLon: NaN

    property string _ipName: ""
    property real _ipLat: NaN
    property real _ipLon: NaN

    readonly property bool known: root.name.length > 0 && !isNaN(root.lat)
    readonly property bool guessed: root.known && root.source !== "manual"

    // ⚠️ Every service carries `available`, and this one did not. The rule
    // exists so the ui can ASK rather than assume, and a service without it is
    // used as though it were always there — here that would mean the weather
    // and the sunrise schedule quietly working from a place of `NaN`. Missed
    // for a whole milestone because nothing checked; tests/smoke.sh does now.
    //
    // "Available" for a place means we have one at all, however we got it —
    // whether it was guessed or confirmed is a separate question, and that is
    // what `guessed` is for.
    readonly property bool available: root.known

    // The system's timezone, read rather than stored. A copy in our config
    // would drift, and then the clock and the weather would disagree about
    // which country this is.
    property string timezone: ""

    // --------------------------------------------------------------- guessing
    Process {
        id: tz
        command: ["timedatectl", "show", "-p", "Timezone", "--value"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.timezone = text.trim()
                zones.reload()
            }
        }
    }

    FileView {
        id: zones
        path: "/usr/share/zoneinfo/zone1970.tab"
        printErrors: false
        onLoaded: root._guessFromTimezone()
    }

    // ⚠️ ISO 6709, and this is where it is easy to be wrong: the fields have
    // FIXED WIDTH and longitude carries THREE degree digits, not two.
    //
    //   +5230+01322        52°30'      13°22'
    //   +404251-0740023    40°42'51"  -74°00'23"
    //
    // Reading it as "split on the sign and parse" gives Berlin a longitude of
    // 1°32', which is in the Channel.
    function parseIso6709(s) {
        var m = /^([+-])(\d{2})(\d{2})(\d{2})?([+-])(\d{3})(\d{2})(\d{2})?$/.exec(String(s).trim())
        if (!m)
            return null
        function deg(sign, d, mi, se) {
            var v = (+d) + (+mi) / 60 + (se ? (+se) / 3600 : 0)
            return sign === "-" ? -v : v
        }
        return { lat: deg(m[1], m[2], m[3], m[4]),
                 lon: deg(m[5], m[6], m[7], m[8]) }
    }

    // "Europe/Berlin" → "Berlin", "America/New_York" → "New York".
    function cityOf(zone) {
        var parts = String(zone).split("/")
        return parts[parts.length - 1].replace(/_/g, " ")
    }

    function _guessFromTimezone() {
        if (!root.timezone.length)
            return
        // Never override an answer the user gave. A laptop that crosses a
        // border must not silently relocate a place you typed in yourself.
        if (Config.location.name.length)
            return

        var lines = zones.text().split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (!line.length || line.charAt(0) === "#")
                continue
            // country-codes <TAB> coordinates <TAB> zone <TAB> comment
            var f = line.split("\t")
            if (f.length < 3 || f[2] !== root.timezone)
                continue
            var c = root.parseIso6709(f[1])
            if (!c)
                return
            // In memory only — nothing is written until you decide something.
            root._guessName = root.cityOf(root.timezone)
            root._guessLat = c.lat
            root._guessLon = c.lon
            return
        }
    }

    // ------------------------------------------------------------- by IP
    //
    // ⚠️⚠️ THE ONLY REQUEST THIS DESKTOP MAKES ABOUT HIM, and every part of it
    // is deliberate. See Config.qml's `location.fromIp` for what the service
    // learns and why he chose to switch it on.
    //
    // ⚠️⚠️ geojs.io, AND ip-api.com WAS THE FIRST CHOICE AND IS WRONG. Measured
    // rather than assumed, and it would have failed silently for ever:
    //
    //   https://ip-api.com/json/?fields=…   -> {"status":"fail"}
    //   http://ip-api.com/json/?fields=…    -> a real answer
    //
    // Its free tier is HTTP-ONLY; https is a paid feature and the refusal comes
    // back as a 200 with `status: fail`, so curl exits 0 and nothing looks
    // broken. Falling back to http was the obvious repair and is the wrong one:
    // the request and the answer would cross the network in clear, which is a
    // strange thing to do while asking where somebody lives — and his standing
    // rule is that nothing private leaves the machine in a form anybody can
    // read.
    //
    // get.geojs.io answers over HTTPS, needs no account and no key, and carries
    // `city`, `latitude` and `longitude`.
    //
    // ⚠️ ITS ANSWER IS WIDER THAN WHAT WE ASK OF IT — it also returns the IP, the
    // ASN and the organisation. We read three fields and keep three; the rest is
    // not stored, not logged and not shown. Said out loud because "we only use
    // three" and "only three arrive" are different sentences, and the first one
    // is the true one here.
    //
    // ⚠️ AND latitude/longitude COME BACK AS STRINGS, quoted. `Number()` is what
    // makes them numbers; using them as they arrive gives a location that
    // compares as text and a sunrise that never fires.
    //
    // ⚠️ NOT WHILE SOMETHING IS SET BY HAND. Asking the network about a place
    // that has already been decided is a request that can only produce a value
    // nobody will read.
    //
    // ⚠️ NO POLLING, AND NO TIMER. It runs once when the shell settles, and
    // again when the network changes — which is exactly when the answer can
    // have changed. A laptop that suspends in one city and wakes in another
    // gets a new network before it gets new weather.
    //
    // ⚠️ AND IT IS NEVER WRITTEN TO shell.json. Like the timezone guess, it
    // lives in memory: a file records decisions, and this is not one. Confirming
    // it is a click, and the click goes through `_write` below like any other.
    readonly property bool wantIp:
        Config.settled && Config.location.fromIp === true
        && !Config.location.name.length

    function refreshFromIp() {
        if (!root.wantIp || ipQuery.running)
            return
        ipQuery.running = true
    }

    Process {
        id: ipQuery
        command: ["curl", "-fsS", "--max-time", "8",
                  "https://get.geojs.io/v1/ip/geo.json"]
        stdout: StdioCollector { id: ipText }

        onExited: function (code) {
            if (code !== 0)
                return
            var d
            try {
                d = JSON.parse(String(ipText.text || "{}"))
            } catch (e) {
                return
            }
            // ⚠️ A SUCCESSFUL REQUEST IS NOT A SUCCESSFUL ANSWER, which is the
            // lesson ip-api taught above: it returned HTTP 200 and a refusal in
            // the body, so curl exited 0. Everything used is checked for being
            // there and for being a number, and anything short of that leaves
            // the timezone guess in place rather than writing NaN over it.
            var lat = Number(d && d.latitude)
            var lon = Number(d && d.longitude)
            if (!d || !d.city || isNaN(lat) || isNaN(lon))
                return
            root._ipName = String(d.city)
            root._ipLat = lat
            root._ipLon = lon
        }
    }

    // The two moments it can have changed, and nothing else.
    // ⚠️ Bound to the STATE, not to a start-up moment: `wantIp` goes true when
    // Config settles, and false again the moment a place is set by hand.
    onWantIpChanged: root.refreshFromIp()
    Connections {
        target: Services.Net
        function onConnectedNetworkChanged() { root.refreshFromIp() }
    }

    // The one place the config is written, and it only ever runs from a click.
    // Deferred a step regardless: a write that lands inside the handler which
    // triggered it re-enters the config adapter, and that is not survivable.
    property var _pendingWrite: null

    function _write(name, lat, lon) {
        root._pendingWrite = { name: name, lat: lat, lon: lon }
        Qt.callLater(root._flush)
    }

    function _flush() {
        var w = root._pendingWrite
        if (!w)
            return
        root._pendingWrite = null
        Config.location.name = w.name
        Config.location.lat = w.lat
        Config.location.lon = w.lon
        Config.save()
    }

    // ---------------------------------------------------------------- search
    // Open-Meteo's geocoder: no API key, which is the only reason this can work
    // out of the box. A key would have to live either in this public repository
    // or in a setup step nobody completes.
    property var matches: []
    property bool searching: false
    property string status: ""

    property string _query: ""

    function search(text) {
        var q = String(text).trim()
        matches = []
        if (q.length < 3) {          // below three letters everything matches
            searching = false
            debounce.stop()
            return
        }
        root._query = q
        debounce.restart()
    }

    Timer {
        id: debounce
        // Typing "Frankfurt" is nine keystrokes and must not be nine requests.
        interval: 400
        onTriggered: {
            root.searching = true
            var x = new XMLHttpRequest()
            x.onreadystatechange = function () {
                if (x.readyState !== XMLHttpRequest.DONE) return
                root.searching = false
                if (x.status < 200 || x.status >= 300) {
                    root.status = "Place search is not reachable"
                    return
                }
                try {
                    var j = JSON.parse(x.responseText)
                    var out = []
                    var r = j.results || []
                    for (var i = 0; i < r.length && i < 5; i++)
                        out.push({ name: r[i].name,
                                   country: r[i].country || "",
                                   admin: r[i].admin1 || "",
                                   lat: r[i].latitude, lon: r[i].longitude })
                    root.matches = out
                    root.status = out.length ? "" : "No place found"
                } catch (e) {
                    root.status = "Place search returned nonsense"
                }
            }
            x.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=5&language=de&format=json&name="
                          + encodeURIComponent(root._query))
            x.send()
        }
    }

    // One write, and everything downstream follows — this start and the next.
    function choose(m) {
        root._write(m.name + (m.country && m.country.length ? ", " + m.country : ""),
                    m.lat, m.lon)
        root.matches = []
        root.status = ""
        root.confirmed()
    }

    // Confirm the guess as it stands: same effect as picking it from a list,
    // and it is the single click the whole design is built around.
    function confirm() {
        if (!root.known)
            return
        root._write(root.name, root.lat, root.lon)
        root.confirmed()
    }

    signal confirmed()
}
