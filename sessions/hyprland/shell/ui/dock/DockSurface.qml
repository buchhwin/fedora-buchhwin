pragma ComponentBehavior: Bound

// The dock: pinned programs, what is running, and one strip that can be three
// different things.
//
// His brief, 05.08.: "floating an/aus, full sized über den ganzen bildschirm    // english-ok: the brief, quoted
// unten als taskbar an/aus, oder halt nur 'dock' wie jetzt — und viel zum       // english-ok: the brief, quoted
// einstellen". 09.08., the default: floating, centred at the bottom, autohide   // english-ok: the brief, quoted
// off.
//
// ⚠️⚠️ THE SURFACE IS THE FULL LENGTH OF ITS EDGE, ALWAYS — AND THAT IS THE ONE
// THING IN THIS FILE THAT IS NOT NEGOTIABLE.
//
// The obvious build is a window as wide as the icons in it. ShellSurface.qml
// carries what that costs, measured, because the notch was built that way and
// he reported it: "alles wackelt ganz schnell von links nach rechts". The       // english-ok: the report, quoted
// content sets the window width, the content is centred IN the window, so every
// time the content changed — a window opening, an icon resolving — the Wayland
// surface was re-measured and the contents slid sideways to stay centred.
//
// A dock's content changes every time you open or close a program. So: the
// surface spans the whole edge and never changes size, and the strip is placed
// INSIDE it. tests/motion.sh enforces exactly this — it fails a PanelWindow
// whose size comes from a child.
//
// ⚠️ AND THEREFORE NO COMPOSITOR BLUR. niri blurs and shadows the WHOLE layer
// surface, invisible margins included; a full-width surface with blur on would
// blur a band across the bottom of the screen and shadow it too. The notch has
// both switched off for the same reason and paints its own shape. So does this:
// one rounded rectangle in Theme.panelBg, exactly where the dock is drawn.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../common"
import "../../config"
import "../../services" as Services
import "../../theme"

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    // config.kdl attaches rules to this namespace. Renaming it here without
    // renaming it there loses them silently.
    WlrLayershell.namespace: "buchhwin-dock"
    WlrLayershell.layer: WlrLayer.Top

    readonly property bool vertical: Config.dock.position === "left"
                                  || Config.dock.position === "right"
    readonly property bool taskbar: Config.dock.mode === "taskbar"
    readonly property int gap: Config.dock.floating ? Theme.space3 : 0

    // ── the surface ──────────────────────────────────────────────────────────
    //
    // Anchored along the whole edge it sits on, and to that edge itself. The
    // thickness is a SETTING plus the margin; nothing here reads a child.
    anchors {
        bottom: Config.dock.position === "bottom"
        left: root.vertical ? Config.dock.position === "left" : true
        right: root.vertical ? Config.dock.position === "right" : true
        top: root.vertical
    }

    implicitWidth: root.vertical ? Config.dock.size + root.gap * 2 : 0
    implicitHeight: root.vertical ? 0 : Config.dock.size + root.gap * 2

    // ⚠️ SPACE IS RESERVED ONLY BY THE TASKBAR, and that is the difference
    // between the two modes rather than a detail of them. A dock floats over
    // what is behind it — that is what makes it a dock. A taskbar is furniture:
    // windows tile up to it, which means an exclusive zone.
    //
    // ⚠️ An autohiding taskbar reserves NOTHING, because a strip that is not
    // there cannot hold space open. Otherwise hiding it would leave a band of
    // desktop nothing can use.
    exclusiveZone: (root.taskbar && !Config.dock.autohide)
                 ? Config.dock.size + root.gap * 2
                 : 0

    color: "transparent"                        // literal-ok: absence of colour

    // ⚠️ THE INPUT REGION FOLLOWS THE DRAWN SHAPE, not the surface. The surface
    // is the full width of the screen; without this, the invisible half of it
    // would swallow every click meant for the desktop or a window underneath.
    mask: Region { item: strip }

    // ── hiding ───────────────────────────────────────────────────────────────
    //
    // ⚠️ MOVED, NOT RESIZED. `y` is a GPU transform; changing the surface's
    // height would be a Wayland round trip per frame, which is the fault this
    // whole file is arranged around.
    readonly property bool shown: !Config.dock.autohide || reveal.hovered

    // A strip along the edge that is there even when the dock is not — without
    // it, an autohidden dock has nothing to hover.
    HoverHandler { id: reveal }

    // ── the dock itself ──────────────────────────────────────────────────────
    Rectangle {
        id: strip

        // Centred in the surface along its long axis; against its edge across
        // the short one.
        anchors.horizontalCenter: root.vertical ? undefined : parent.horizontalCenter
        anchors.verticalCenter: root.vertical ? parent.verticalCenter : undefined

        // ⚠️ A taskbar is the full length of the edge; a dock is as long as its
        // contents. This is a CHILD's size, which is allowed — what may not
        // follow the content is the WINDOW, and that is fixed above.
        implicitWidth: root.vertical
            ? Config.dock.size
            : (root.taskbar ? root.width - root.gap * 2
                            : items.implicitWidth + Theme.space2 * 2)
        implicitHeight: root.vertical
            ? (root.taskbar ? root.height - root.gap * 2
                            : items.implicitHeight + Theme.space2 * 2)
            : Config.dock.size

        // Floating: a margin all round and rounded corners. Flush: it meets the
        // edge, so the two corners against the edge are square.
        radius: Config.dock.floating ? Theme.radiusLg : Theme.radiusMd
        color: Theme.panelBg

        x: root.vertical ? (Config.dock.position === "right" ? root.width - width - root.gap
                                                             : root.gap)
                         : (root.width - width) / 2
        y: root.vertical ? (root.height - height) / 2
                         : root.height - height - root.gap

        // The hide: slides out along its own short axis, and comes back the
        // same way.
        transform: Translate {
            x: root.vertical && !root.shown
             ? (Config.dock.position === "right" ? strip.width + root.gap
                                                 : -(strip.width + root.gap))
             : 0
            y: !root.vertical && !root.shown ? strip.height + root.gap : 0

            Behavior on x {
                enabled: Theme.animate
                NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
            }
            Behavior on y {
                enabled: Theme.animate
                NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
            }
        }

        // ── what is in it ────────────────────────────────────────────────────
        GridLayout {
            id: items
            anchors.centerIn: parent
            columns: root.vertical ? 1 : root.model.length
            rows: root.vertical ? root.model.length : 1
            columnSpacing: Theme.space1
            rowSpacing: Theme.space1

            Repeater {
                model: root.model

                DockItem {
                    required property var modelData
                    entry: modelData.entry
                    windows: modelData.windows
                    active: modelData.active
                    iconSize: Config.dock.iconSize
                    vertical: root.vertical
                    onActivated: root.activate(modelData)
                }
            }
        }
    }

    // ── the list ─────────────────────────────────────────────────────────────
    //
    // Pinned first, in the order they are pinned, then anything running that is
    // not pinned. One entry per program, not per window: the dots say how many.
    readonly property var model: {
        var out = []
        var seen = ({})
        var wins = Services.Compositor.windows || []
        var focused = Services.Compositor.focusedWindow

        function key(s) {
            // ⚠️ An app_id and a desktop id are not the same string. Lower-case
            // and take the last dotted component, so `org.gnome.Nautilus` and
            // `nautilus` meet in the middle.
            return String(s || "").toLowerCase().split(".").pop()
        }

        function countFor(k) {
            var n = 0
            for (var i = 0; i < wins.length; i++)
                if (key(wins[i].app_id) === k)
                    n++
            return n
        }
        function activeFor(k) {
            return focused ? key(focused.app_id) === k : false
        }

        var pinned = Config.dock.pinned || []
        for (var i = 0; i < pinned.length; i++) {
            var id = String(pinned[i])
            var k = key(id)
            if (seen[k])
                continue
            seen[k] = true
            var e = null
            var apps = Services.Apps.apps
            for (var j = 0; j < apps.length; j++)
                if (apps[j].id === id || key(apps[j].id) === k) {
                    e = apps[j]
                    break
                }
            // ⚠️ A PIN FOR SOMETHING NOT INSTALLED STAYS VISIBLE. Dropping it
            // would mean a dock that quietly loses entries when a package is
            // removed, and the config would still say it is pinned.
            out.push({
                entry: e ? e : { id: id, name: id, icon: "" },
                windows: countFor(k),
                active: activeFor(k),
                pinned: true
            })
        }

        if (Config.dock.showRunning)
            for (var w = 0; w < wins.length; w++) {
                var wk = key(wins[w].app_id)
                if (!wk.length || seen[wk])
                    continue
                seen[wk] = true
                var re = null
                var all = Services.Apps.apps
                for (var m = 0; m < all.length; m++)
                    if (key(all[m].id) === wk) {
                        re = all[m]
                        break
                    }
                out.push({
                    entry: re ? re : { id: wins[w].app_id, name: wins[w].app_id, icon: "" },
                    windows: countFor(wk),
                    active: activeFor(wk),
                    pinned: false
                })
            }
        return out
    }

    // ⚠️ FOCUS WHAT IS OPEN, START WHAT IS NOT — and never both. Clicking a
    // running program's icon and getting a SECOND copy is the dock fault every
    // desktop has shipped at least once.
    function activate(item) {
        if (item.windows > 0) {
            var wins = Services.Compositor.windows || []
            var k = String(item.entry.id || "").toLowerCase().split(".").pop()
            for (var i = 0; i < wins.length; i++)
                if (String(wins[i].app_id || "").toLowerCase().split(".").pop() === k) {
                    Services.Compositor.focusWindow(wins[i].id)
                    return
                }
        }
        Services.Apps.launch(item.entry.id)
    }
}
