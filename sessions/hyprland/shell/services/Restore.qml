// Open the same programs again after a restart — the macOS tick box.
//
// ⚠️ THE LIST IS KEPT WHILE YOU WORK, NOT WRITTEN AT SHUTDOWN. A list written on
// the way out is missing on exactly the days you wanted it: a machine that lost
// power, a compositor that died, a battery that ran out. Watching the window
// list costs one debounced write when the set of programs changes, which is a
// handful of times an hour rather than continuously.
//
// ⚠️ AND IT RESTORES ONCE PER SESSION, NOT ONCE PER SHELL START. The shell is
// restarted often — by `bhctl`, by a rescue key, by an update — and every one of
// those would otherwise open a second copy of everything. The marker lives in
// XDG_RUNTIME_DIR, which is a tmpfs that goes away with the session, so "have we
// already done this" answers correctly for a login and for a reboot without
// anybody having to reason about which is which.
//
// ⚠️ WHAT IT CANNOT DO, said here as well as in the settings row: the programs
// come back, their contents do not. Brave and VS Code restore their own tabs;
// kitty does not, and nothing outside a program can know what was in it.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "." as Services
import "../config"

Singleton {
    id: root

    // ⚠️ Not $HOME. This has to disappear when the session does, or a reboot
    // would look like a shell restart and nothing would ever be restored again.
    readonly property string markerPath:
        (Quickshell.env("XDG_RUNTIME_DIR")
            ? Quickshell.env("XDG_RUNTIME_DIR")
            : "/tmp") + "/buchhwin-restored"

    // Until this is true the list is not written. Restoring is what fills the
    // screen; recording before it has happened would save an empty desktop over
    // the list we are about to read — and it would do it silently, so the
    // feature would simply stop working one day with nothing to point at.
    property bool settled: false

    property int opened: 0
    property string lastNote: ""

    // The programs on screen now, without duplicates. A window per tab or per
    // project is normal, and starting a second kitty because two were open is
    // not what "the same programs" means.
    readonly property var openApps: {
        var seen = ({})
        var out = []
        var w = Services.Compositor.windows || []
        for (var i = 0; i < w.length; i++) {
            var id = w[i] ? String(w[i].app_id || "") : ""
            if (!id.length || seen[id]) continue
            seen[id] = true
            out.push(id)
        }
        out.sort()
        return out
    }

    FileView { id: marker; blockLoading: true; printErrors: false }

    function _markerSet() {
        marker.path = ""
        marker.path = root.markerPath
        return String(marker.text() || "").length > 0
    }

    function _setMarker() {
        marker.path = root.markerPath
        marker.setText("1\n")
    }

    // ------------------------------------------------------------- restoring
    function restoreNow() {
        var wanted = Config.session.apps || []
        var missed = []
        root.opened = 0

        for (var i = 0; i < wanted.length; i++) {
            var id = String(wanted[i])
            if (!id.length) continue
            // Already there — a program that survived, or one the compositor
            // started itself. Opening a second copy would be the one thing
            // worse than opening none.
            if (root.openApps.indexOf(id) >= 0) continue
            if (Services.Apps.launch(id))
                root.opened++
            else
                missed.push(id)
        }

        root.lastNote = missed.length
            ? ("restored " + root.opened + ", could not place " + missed.join(", "))
            : ("restored " + root.opened)
        console.log("buchhwin restore: " + root.lastNote)
    }

    // ⚠️ NOT Component.onCompleted. The window list and the desktop entries are
    // both still arriving at that point — DesktopEntries read imperatively too
    // early answers with an empty list, which this project has already been
    // caught by twice. One short timer, once, and then the service is idle.
    Timer {
        running: true
        interval: 2500
        onTriggered: {
            if (!Config.session.restore) {
                root.settled = true
                return
            }
            if (root._markerSet()) {
                root.lastNote = "already restored in this session"
                root.settled = true
                return
            }
            root._setMarker()
            root.restoreNow()
            // ⚠️ Only now may the list be written. Everything the restore just
            // opened has to be on screen first, or the next write would record
            // a half-filled desktop.
            settle.restart()
        }
    }

    Timer { id: settle; interval: 4000; onTriggered: root.settled = true }

    // ------------------------------------------------------------- recording
    //
    // Debounced, because a workspace switch or a window closing arrives as a
    // burst and each one would otherwise be a full write of shell.json.
    onOpenAppsChanged: if (root.settled) record.restart()

    Timer {
        id: record
        interval: 3000
        onTriggered: {
            if (!Config.session.restore || !root.settled)
                return
            var now = root.openApps
            var was = Config.session.apps || []
            if (JSON.stringify(now) === JSON.stringify(was))
                return
            Config.session.apps = now
            Config.save()
        }
    }
}
