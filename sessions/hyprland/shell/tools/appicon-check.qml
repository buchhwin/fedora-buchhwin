// Does a window's app_id actually resolve to an icon?
//
// ⚠️ THIS IS tests/icons.sh's PROBLEM ONE FLOOR DOWN. That check exists because
// a glyph name the font does not have renders as a silent box; this is the same
// failure for PROGRAM icons, and it sat on screen for weeks as "Super+Tab shows
// circles with letters instead of icons".
//
// The cause was one line: AppIcon asked `Quickshell.hasThemeIcon(app_id)` — it
// treated the compositor's app_id AS an icon name. Those agree for a minority
// of programs. The icon name lives in the .desktop entry, and the entry is
// found from an app_id by its `StartupWMClass` — which Quickshell exposes as
// `DesktopEntry.startupClass`, read out of the qmltypes rather than guessed.
//
// This prints which of the routes answers for every program this desktop ships.
import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

Item {
    id: root

    // ⚠️⚠️ A BINDING, NOT A READ INSIDE A FUNCTION, and the first version of
    // this tool got it wrong and reported a clean lie: "entries seen: 0", so
    // every program came back `none` and it looked like the .desktop route did
    // not work at all. It works; the list simply is not there yet when a
    // function asks for it. services/Apps.qml carries the same warning, and
    // Two earlier probes reported "0 entries"
    // for exactly this reason.
    readonly property var entries:
        DesktopEntries.applications ? DesktopEntries.applications.values : []

    readonly property string out: "/tmp/buchhwin-appicon-check.txt"
    property string report: ""
    function say(s) { report += s + "\n"; log.setText(report) }

    FileView { id: log; path: root.out }

    readonly property var ids: [
        "kitty", "org.quickshell", "brave-browser", "code", "Code",
        "nautilus", "org.gnome.Nautilus", "alacritty", "Alacritty",
        "vlc", "loupe", "org.gnome.Loupe", "keepassxc",
        "org.keepassxc.KeePassXC", "com.spotify.Client", "spotify",
        "dev.vencord.Vesktop", "remmina", "org.gnome.Calendar", "btop"
    ]

    // The chain, in the order AppIcon will use it.
    function resolve(appId) {
        var list = root.entries
        var lower = String(appId).toLowerCase()
        var i, e

        // 1. The desktop id, exactly as given.
        for (i = 0; i < list.length; i++)
            if (list[i] && String(list[i].id) === String(appId) && list[i].icon)
                return { icon: String(list[i].icon), via: "id" }

        // 2. StartupWMClass — the key that exists for exactly this question.
        for (i = 0; i < list.length; i++) {
            e = list[i]
            if (e && e.startupClass && String(e.startupClass).toLowerCase() === lower
                && e.icon)
                return { icon: String(e.icon), via: "wmclass" }
        }

        // 3. The desktop id, ignoring case. "Alacritty" and "alacritty" are the
        //    same program to everybody except a string compare.
        for (i = 0; i < list.length; i++)
            if (list[i] && String(list[i].id).toLowerCase() === lower && list[i].icon)
                return { icon: String(list[i].icon), via: "id/nocase" }

        // 4. The old route: the app_id as an icon name.
        if (Quickshell.hasThemeIcon(appId))
            return { icon: String(appId), via: "themename" }

        return { icon: "", via: "none" }
    }

    // ⚠️⚠️ AND IT WAITS FOR THE LIST TO STOP GROWING, not merely to be
    // non-empty — the second version of this tool made exactly that mistake and
    // reported "entries seen: 14" on a machine with 39 .desktop files. A
    // condition of `length > 0` is true on the FIRST entry that arrives, and
    // everything measured after it is measured against a list that is still
    // filling. Two consecutive samples that agree is the same control as two
    // identical idle screenshots.
    property int lastSeen: -1
    property int stable: 0

    Timer {
        id: settle
        running: true
        interval: 150
        repeat: true
        property int ticks: 0
        onTriggered: {
            ticks++
            var n = root.entries.length
            if (n > 0 && n === root.lastSeen) {
                if (++root.stable >= 2) { settle.stop(); root.run() }
            } else {
                root.stable = 0
            }
            root.lastSeen = n
            if (ticks > 60) {          // 9 s
                settle.stop()
                root.say("  FAIL the entry list never settled (last: " + n + ")")
                Qt.callLater(Qt.quit)
            }
        }
    }

    function run() {
        var count = ({})
        for (var i = 0; i < root.ids.length; i++) {
            var id = root.ids[i]
            var r = root.resolve(id)
            count[r.via] = (count[r.via] || 0) + 1
            root.say("  " + (r.via + "         ").substring(0, 10) + id
                     + (r.icon.length ? "  ->  " + r.icon : ""))
        }
        root.say("")
        var keys = Object.keys(count)
        var line = ""
        for (var k = 0; k < keys.length; k++)
            line += keys[k] + "=" + count[keys[k]] + "  "
        root.say("  " + line)
        root.say("  entries seen: "
                 + (DesktopEntries.applications
                    ? DesktopEntries.applications.values.length : 0))
        Qt.callLater(Qt.quit)
    }
}
