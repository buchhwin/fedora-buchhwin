pragma Singleton

// The five things you can do to a session, in one place.
//
// ⚠️ THIS EXISTS BECAUSE THE LIST WAS ABOUT TO BE WRITTEN A SECOND TIME. He
// asked for the session buttons in the quick panel — "im quick menu gibt es      // english-ok: the request, quoted
// aktuell noch keine power shutdown lock butten … die sollen am besten ins       // english-ok: the request, quoted
// rechte obere eck vom quickpanel kommen" — and the five actions already         // english-ok: the request, quoted
// existed, spelled out inside ui/notch/pages/SessionPage.qml.
//
// Copying them would have been the fault this project has paid for four times: a
// name changed in one place and not the other, and the copy keeps working until
// the day it matters. `restart_alt` and `logout` are already in the history here
// — Symbols names that Fedora's "Material Icons Round" does not have, which
// shipped as one missing icon and one wrong one. A second copy of that table is
// a second chance to get it wrong.
//
// ⚠️ IT IMPORTS NO `Ipc`, AND THAT IS A RULE RATHER THAN AN OVERSIGHT.
// services/qmldir forbids ui imports, and no other service does it. Closing the
// panel is the caller's business: the notch page collapses itself, the quick
// panel corner closes itself, and neither has to agree with the other about
// what "run" means.
//
// ⚠️ AND NOTHING HERE ASKS. `ask` is a fact ABOUT the action — logging out,
// restarting and shutting down throw away unsaved work, locking and suspending
// do not — and every caller has to honour it, but the arming and the second
// press are the surface's job. A service that owned the question would have to
// own a timeout, a cancel and a focus policy with it.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ⚠️ Icon names are LIGATURES, and Fedora ships "Material Icons Round", not
    // the newer "Material Symbols". `logout` and `restart_alt` are Symbols
    // names: they do not resolve here and render as the literal letters —
    // measured at 500 px and 700 px wide against a 100 px font, where a real
    // glyph is about 70. tests/icons.sh measures every name the shell uses.
    //
    // ⚠️⚠️ AND EXISTING IS NOT THE SAME AS RIGHT, which is the half tests/
    // icons.sh cannot check. He said "schau dir alle icons im quick panel an,   // english-ok: the request, quoted
    // einige sind falsch oder buggy", and the offender resolved perfectly:      // english-ok: the request, quoted
    // `exit_to_app` in Material Icons Round is an arrow pointing INTO a
    // bracket. Enlarged from a real screenshot it reads as LOG IN, on the
    // button that logs you out. `logout`, the glyph that points the other way,
    // is a Symbols name and is not in this font.
    //
    // Chosen by rendering the candidates and looking at them, not from their
    // names:
    //
    //   Log out   meeting_room   an open door — you are leaving through it
    //   Restart   autorenew      TWO arrows closing a circle: round again.
    //                            `refresh` is ONE arrow, which every browser
    //                            in the world uses to mean "load this again"
    //
    // Rejected after rendering: `sensor_door` (a shut door), `eject` (a disc
    // being ejected), `power` (a plug), `settings_backup_restore` and `history`
    // (both a clock winding back), `rotate_right` (a dashed circle).
    readonly property var actions: [
        { id: "lock",     icon: "lock",              label: "Lock",      ask: false,
          cmd: ["loginctl", "lock-session"] },
        { id: "suspend",  icon: "bedtime",           label: "Suspend",   ask: false,
          cmd: ["systemctl", "suspend"] },
        { id: "logout",   icon: "meeting_room",      label: "Log out",   ask: true,
          cmd: ["hyprctl", "dispatch", "exit"] },
        { id: "reboot",   icon: "autorenew",         label: "Restart",   ask: true,
          cmd: ["systemctl", "reboot"] },
        { id: "poweroff", icon: "power_settings_new", label: "Power off", ask: true,
          cmd: ["systemctl", "poweroff"] }
    ]

    function byId(id) {
        for (var i = 0; i < root.actions.length; i++)
            if (root.actions[i].id === id)
                return root.actions[i]
        return null
    }

    function indexOf(id) {
        for (var i = 0; i < root.actions.length; i++)
            if (root.actions[i].id === id)
                return i
        return -1
    }

    // ⚠️ ONE PROCESS, REPLACED EACH TIME. Two of these could overlap — a
    // suspend and a reboot arriving together is a machine deciding between them
    // — and none of the five is a thing you want twice.
    function run(id) {
        var a = root.byId(id)
        if (a === null)
            return false
        proc.command = a.cmd
        proc.running = true
        return true
    }

    Process { id: proc }
}
