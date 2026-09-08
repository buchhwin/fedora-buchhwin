pragma Singleton

// The weather, from Open-Meteo.
//
// Chosen because it needs no API key. That is not a convenience — a key would
// have to live either in this public repository, where it would be revoked, or
// in a setup step nobody would complete. A service that works the moment you
// type a town name is the only kind that gets used.
//
// Two requests, both plain HTTPS:
//
//   geocoding-api.open-meteo.com/v1/search?name=…   town  → coordinates
//   api.open-meteo.com/v1/forecast?latitude=…       coords → weather
//
// ⚠️ IT DOES NOT OWN THE PLACE. That lives in services/Location.qml, because a
// location is a property of the machine and three things want it — this, the
// sunrise/sunset that will drive automatic light/dark, and gammastep's night
// light. Set the place once, anywhere, and this follows: it is a binding, so
// choosing "Berlin" in the settings window changes what the quick panel shows
// in the same instant, with nothing to keep in step.
//
// Fetched hourly, and only when a place is set. Weather does not change faster
// than that, and this runs on a battery: a service that polls because polling
// is easy is exactly what the desktop is not allowed to do.

import QtQuick
import Quickshell
import "." as Services

Singleton {
    id: root

    readonly property bool configured: Services.Location.known

    readonly property bool available: root.configured && root.temperature !== null

    readonly property string place: Services.Location.name
    property var temperature: null        // °C, or null while unknown
    property int code: -1                 // WMO weather code
    property string status: ""            // why there is nothing, in one line
    property bool busy: false

    // --------------------------------------------------------------- forecast
    function refresh() {
        if (!root.configured || root.busy)
            return
        root.busy = true
        var x = new XMLHttpRequest()
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return
            root.busy = false
            if (x.status < 200 || x.status >= 300) {
                root.status = "Weather could not be fetched"
                return
            }
            try {
                var j = JSON.parse(x.responseText)
                var c = j.current
                if (!c) { root.status = "The answer contained no weather"; return }
                root.temperature = c.temperature_2m
                root.code = c.weather_code !== undefined ? c.weather_code : -1
                root.status = ""
            } catch (e) {
                root.status = "The weather service returned nonsense"
            }
        }
        x.open("GET", "https://api.open-meteo.com/v1/forecast"
                      + "?latitude=" + Services.Location.lat
                      + "&longitude=" + Services.Location.lon
                      + "&current=temperature_2m,weather_code&timezone=auto")
        x.send()
    }

    // ⚠️ THE FIRST FETCH IS DELAYED, AND THAT IS NOT POLITENESS.
    //
    // This timer had `triggeredOnStart: true`, which fires while the object is
    // being constructed. Once the shell started this service at startup rather
    // than when a panel first opened, that meant an XMLHttpRequest — and so a
    // DNS lookup — during shell construction. Measured: SIGSEGV, in
    // getaddrinfo loading an NSS module, 32 restarts in a crash loop.
    //
    // So the first reading happens a few seconds in, once everything is up. It
    // is weather; nobody is waiting on the second.
    Timer {
        id: firstFetch
        interval: 4000
        repeat: false
        running: root.configured
        onTriggered: root.refresh()
    }

    // Hourly after that. Weather does not change faster, and this runs on a
    // battery: a service that polls because polling is easy is exactly what
    // this desktop is not allowed to do.
    Timer {
        interval: 3600000
        repeat: true
        running: root.configured
        onTriggered: root.refresh()
    }

    // ⚠️ A BOUND PROPERTY, NOT `Connections`.
    //
    // This was `Connections { target: Services.Location; onNameChanged: … }`,
    // and it segfaulted the shell in a restart loop — isolated by removing that
    // one block and nothing else. Both singletons are created by the same
    // binding when the shell starts, so the Connections attached itself to a
    // Location that was still being constructed, and the crash landed inside
    // `JsonAdapter::deserializeRec` when the config first arrived.
    //
    // Watching our own bound property has neither problem: the binding is
    // evaluated when Location is ready, and the reaction is deferred out of
    // whatever handler set it off, so nothing re-enters the adapter mid-parse.
    readonly property string watchedPlace: Services.Location.name

    onWatchedPlaceChanged: {
        // A stale temperature under a new town name is worse than none.
        root.temperature = null
        again.restart()
    }

    Timer {
        id: again
        interval: 200
        repeat: false
        onTriggered: root.refresh()
    }

    // ----------------------------------------------------------- description
    // WMO weather codes, in the words a person would use. Grouped rather than
    // enumerated: the difference between "slight" and "moderate" drizzle is not
    // something anybody needs from a panel they glance at.
    function describe(c) {
        if (c === 0) return "clear"
        if (c <= 2) return "mainly clear"
        if (c === 3) return "overcast"
        if (c <= 48) return "fog"
        if (c <= 57) return "drizzle"
        if (c <= 67) return "rain"
        if (c <= 77) return "snow"
        if (c <= 82) return "showers"
        if (c <= 86) return "snow showers"
        if (c <= 99) return "thunderstorm"
        return ""
    }

    // Every icon this service can return, in one place so tests/icons.sh can
    // find them. ⚠️ Without this the names would live only inside the function
    // below, where nothing checks them — the test scans for `icon…:` properties,
    // and a `return "wb_sunny"` is invisible to it. Half a tripwire is worse
    // than none, because it reads as full coverage.
    readonly property var iconNames: ["wb_sunny", "cloud", "grain", "ac_unit", "flash_on"]

    // An icon name that exists in Material Icons Round — checked by
    // tests/icons.sh, which measures them in the real font rather than trusting
    // that a plausible name is a real one.
    function icon(c) {
        if (c === 0) return "wb_sunny"
        if (c <= 3) return "cloud"
        if (c <= 48) return "cloud"
        if (c <= 67) return "grain"
        if (c <= 77) return "ac_unit"
        if (c <= 86) return "grain"
        return "flash_on"
    }

    readonly property string description: root.describe(root.code)
    readonly property string iconName: root.icon(root.code)
}
