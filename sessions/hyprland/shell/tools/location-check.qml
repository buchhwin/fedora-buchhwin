// Checks for the location layer: the coordinate format, and the migration.
//
//   BUCHHWIN_TOOL=location-check QT_QPA_PLATFORM=offscreen qs -p shell
//
// ⚠️ ISO 6709 is where this goes wrong quietly. The fields have FIXED WIDTH and
// longitude carries THREE degree digits, not two. Read "+5230+01322" by
// splitting on the sign and parsing, and Berlin lands at 1°32' east — in the
// English Channel — with every downstream number still looking plausible.
import QtQuick
import Quickshell
import Quickshell.Io
import "../services" as Services
import "../config"

Scope {
    id: root

    property string report: ""
    property int failures: 0

    FileView { id: out; path: "/tmp/buchhwin-location-check.txt" }
    function note(s) { report += s + "\n"; out.setText(report) }
    function near(what, got, want) {
        if (got !== null && Math.abs(got - want) < 0.02) note("  ok    " + what)
        else { failures++; note("  FAIL  " + what + "\n          got:  " + got +
                                "\n          want: " + want) }
    }
    function eq(what, got, want) {
        if (String(got) === String(want)) note("  ok    " + what)
        else { failures++; note("  FAIL  " + what + "\n          got:  " + got +
                                "\n          want: " + want) }
    }

    Timer {
        running: true
        interval: 200
        onTriggered: {
            note("buchhwin location-check")

            // ------------------------------------------------- ISO 6709
            var b = Services.Location.parseIso6709("+5230+01322")     // Europe/Berlin
            root.near("Berlin: Breite 52,50", b ? b.lat : null, 52.5)
            root.near("Berlin: longitude 13.37 (NOT 1.53)", b ? b.lon : null, 13.3667)

            var n = Services.Location.parseIso6709("+404251-0740023") // America/New_York
            root.near("New York: latitude with seconds", n ? n.lat : null, 40.7142)
            root.near("New York: longitude is negative", n ? n.lon : null, -74.0064)

            var s = Services.Location.parseIso6709("-3352+01825")     // Africa/Johannesburg
            root.near("southern hemisphere: latitude is negative", s ? s.lat : null, -33.8667)

            root.eq("nonsense is refused",
                    Services.Location.parseIso6709("not-coordinates"), null)

            // ------------------------------------------------- Stadtname
            root.eq("Europe/Berlin → Berlin",
                    Services.Location.cityOf("Europe/Berlin"), "Berlin")
            root.eq("America/New_York → New York",
                    Services.Location.cityOf("America/New_York"), "New York")
            root.eq("Argentina/Buenos_Aires (drei Ebenen)",
                    Services.Location.cityOf("America/Argentina/Buenos_Aires"),
                    "Buenos Aires")

            // ------------------------------------------------- Migration 2→3
            var old = { version: 2, weather: { name: "Berlin, Deutschland",
                                               lat: 52.5000, lon: 13.3667 } }
            var r = Migrations.migrate(old)
            root.eq("the migration runs through", r.ok, true)
            root.eq("… weather is gone", r.config.weather === undefined, true)
            root.eq("… the place was carried over", r.config.location.name, "Berlin, Deutschland")
            root.near("… with its coordinates", r.config.location.lat, 52.5000)
            root.eq("… without a source field (a guess is never written)",
                    r.config.location.source === undefined, true)
            // Against Migrations.current rather than a number typed here: a
            // migration added later must not turn this into a failing test
            // about a step it has nothing to do with.
            root.eq("… version is Migrations.current",
                    r.config.version, Migrations.current)

            // An existing location block wins.
            var both = { version: 2,
                         weather: { name: "Alt", lat: 1, lon: 2 },
                         location: { name: "New", lat: 3, lon: 4 } }
            var r2 = Migrations.migrate(both)
            root.eq("an existing location block is not overwritten",
                    r2.config.location.name, "New")

            // No place set: none is invented.
            var empty = Migrations.migrate({ version: 2 })
            root.eq("without weather, no place is invented",
                    empty.config.location === undefined, true)

            note(root.failures === 0 ? "all good"
                                     : root.failures + " check(s) failed")
            Qt.callLater(Qt.quit)
        }
    }
}
