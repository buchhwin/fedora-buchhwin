pragma Singleton

// The answers this machine already knows, for the rows that used to be empty
// boxes.
//
// ⚠️ IT EXISTS BECAUSE THIRTY ROWS ASKED YOU TO TYPE SOMETHING THE MACHINE
// COULD HAVE SAID. His words: "überall wo es Vorschläge geben muss" — and the   // english-ok: the brief, quoted
// list is not a matter of taste. A screen name, an app-id, an installed
// program, an xkb option: every one of them is a fact about this computer, and
// every one of them was a text field where a typo produced no error anywhere.
// A mistyped app-id is not a warning, it is a window rule that never matches.
//
// ⚠️ ONE PLACE, NOT FIVE. `*.monitors` appears on four pages and `windows.*` on
// three; assembling the same list in each of them is how two of them end up
// disagreeing after somebody improves one. Everything here is a binding over
// services that already exist — no new process, no timer, nothing polled. The
// only cost is the scan Installed already does on demand.
//
// ⚠️ AND IT NEVER FILTERS, IT ORDERS. A filter tight enough to be useful is
// tight enough to be wrong: kitty carries no freedesktop category that says
// "terminal", and a browser installed by hand may carry none at all. Hiding
// such a program would put "Not installed here" under a program that is
// installed — a lie in the interface — whereas ordering only decides which
// eight are shown first, and typing narrows the rest.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "." as Services

Singleton {
    id: root

    // Nothing here can fail; the lists are empty on a machine that has none of
    // the thing, which is a real answer rather than a fault.
    readonly property bool available: true

    // ---------------------------------------------------------------- screens
    //
    // The value is the connector name, because that is what the compositor and our own
    // `monitors` keys match on. The label carries the size, because "Virtual-1"
    // and "DP-3" tell you nothing about which screen is which.
    readonly property var monitors: {
        var out = []
        var list = Quickshell.screens
        for (var i = 0; i < list.length; i++) {
            var s = list[i]
            if (!s || !s.name)
                continue
            out.push({
                value: String(s.name),
                label: String(s.name) + " · " + s.width + "×" + s.height
            })
        }
        return out
    }

    // -------------------------------------------------------------- app-ids
    //
    // ⚠️ WHAT IS RUNNING FIRST, THEN WHAT IS INSTALLED. The rows that use this
    // — blur, float, keep out of a screencast — are almost always set about a
    // window you are looking at, and the app-id of a running window is the one
    // fact that is certainly right. Installed programs follow because the
    // window you want to name may be closed at the moment you go looking.
    //
    // ⚠️ The .desktop id is stripped of its suffix rather than used whole:
    // Wayland app-ids are "org.gnome.Nautilus", desktop ids are
    // "org.gnome.Nautilus.desktop", and offering the second as a window rule is
    // offering a rule that cannot match.
    readonly property var appIds: {
        var out = []
        var seen = ({})
        var w = Services.Compositor.windows
        for (var i = 0; i < w.length; i++) {
            var id = w[i] && w[i].app_id ? String(w[i].app_id) : ""
            if (!id.length || seen[id])
                continue
            seen[id] = true
            out.push({ value: id, label: id + " · open now" })
        }
        var a = Services.Apps.apps
        for (var j = 0; j < a.length; j++) {
            var d = String(a[j].id || "").replace(/\.desktop$/, "")
            if (!d.length || seen[d])
                continue
            seen[d] = true
            out.push({ value: d, label: d + " · " + a[j].name })
        }
        return out
    }

    // ------------------------------------------------------------- programs
    //
    // Binaries rather than desktop ids: these feed `programs.*` and
    // `autostart`, both of which end up as something to execute.
    function programs(cats) {
        var fits = []
        var others = []
        var seen = ({})
        var a = Services.Apps.apps
        for (var i = 0; i < a.length; i++) {
            var bin = String(a[i].binary || "")
            if (!bin.length || seen[bin])
                continue
            seen[bin] = true
            var entry = { value: bin, label: a[i].name + " · " + bin }
            if (cats && cats.indexOf(a[i].category) >= 0)
                fits.push(entry)
            else
                others.push(entry)
        }
        return fits.concat(others)
    }

    readonly property var allPrograms: root.programs([])


    // ----------------------------------------------------------- workspaces
    //
    // Only the NAMED ones. The compositor numbers the rest, and a number is not a name
    // this key can hold — `workspaces` is the list of names to create.
    readonly property var workspaceNames: {
        var out = []
        var w = Services.Compositor.workspaces
        for (var i = 0; i < w.length; i++) {
            var n = w[i] && w[i].name ? String(w[i].name) : ""
            if (n.length && out.indexOf(n) < 0)
                out.push(n)
        }
        return out
    }

    // -------------------------------------------------------- rclone remotes
    //
    // ⚠️ THE MACHINE KNOWS THE ANSWER, SO THE BOX MUST NOT BE EMPTY.
    // tests/suggestions.sh refused `drive.remote` as "a plain text box with no
    // reason given" and was right to: rclone remotes are named by whoever made
    // them, and typing one from memory is how a switch ends up pointing at
    // nothing. `rclone listremotes` reads a config file and touches no network.
    readonly property var driveRemotes: {
        var out = []
        var list = Services.Drive.remotes
        for (var i = 0; i < list.length; i++)
            out.push(list[i])
        return out
    }

}
