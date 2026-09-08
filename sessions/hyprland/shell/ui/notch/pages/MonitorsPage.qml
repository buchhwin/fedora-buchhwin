pragma ComponentBehavior: Bound

// B33 · One column per MONITOR, and windows dragged between them.
//
// His words: "wenn ich shift alt tab mache soll auch ein menü angezeigt werden   // english-ok: the request, quoted
// wie bei den workspaces aber dort ohne workspaces sondern nur … die monitore    // english-ok: the request, quoted
// und dann soll ich dort apps z.b in dem menü auf den anderen monitor ziehen     // english-ok: the request, quoted
// können … aber auf allen monitoren wird der aktuelle workspace genommen …       // english-ok: the request, quoted
// aber man muss auch irgendwie in dem menü zwischen den workspaces wechseln      // english-ok: the request, quoted
// können".                                                                       // english-ok: the request, quoted
//
// ⚠️ IT IS A SECOND SURFACE, NOT A REBUILD OF THE FIRST. `Mod+Tab` answers "what
// is on THIS monitor" and B32 narrowed it to exactly that on his instruction;
// this answers "what is on all of them". One surface trying to be both would be
// the wall he complained about in the settings window.
//
// ⚠️ THE GEOMETRY IS SHARED, NOT COPIED — `common/WorkspaceGeometry.qml`. Both
// surfaces draw a workspace to scale, and that arithmetic is measured against
// niri's own numbers; a second copy would drift away from those quietly.

import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../ipc"
import "../../../services" as Services
import "../../../common"
import "../../common"

ColumnLayout {
    id: root

    spacing: Theme.space3

    // Same box height as the workspace map, so the two surfaces read as one
    // family and `look.uiScale` moves both.
    readonly property int boxHeight: Theme.space6 * 6

    // Which workspace index every column starts on — his "auf allen monitoren    // english-ok: the request, quoted
    // wird der aktuelle workspace genommen".                                     // english-ok: the request, quoted
    //
    // ⚠️ IT IS STATE, NOT A BINDING, and that is the second half of his request:
    // "man muss auch irgendwie in dem menü zwischen den workspaces wechseln      // english-ok: the request, quoted
    // können". A binding to the focused workspace would snap back the moment
    // anything moved, so it is seeded once when the surface opens and then
    // belongs to the arrows.
    property int wanted: 1

    // ⚠️ THE MONITOR LIST HAS TO BE ASKED FOR. niri has no event for outputs
    // (measured — see Niri.qml), so `Compositor.outputs` stays EMPTY until
    // somebody calls `refreshOutputs()`. Until today only the Displays page ever
    // did, which is why the workspace map falls back to 16:9 for anybody who has
    // never opened settings. A surface about monitors cannot afford that.
    Component.onCompleted: {
        Services.Compositor.refreshOutputs()
        var f = Services.Compositor.focusedWorkspace
        root.wanted = (f && f.idx) ? f.idx : 1
    }

    // Every column, worked out by the shared pure function so it can be checked
    // without a compositor. See tests/monitors.sh.
    // ⚠️ PER COLUMN, AND KEPT ON ROOT. A delegate is destroyed and rebuilt
    // every time niri sends an event, so a column that remembered its own index
    // would forget it the moment a window moved — which is exactly when it
    // matters. Map of connector name → index; empty means "use `wanted`".
    property var perOutput: ({})

    readonly property var columns: WorkspaceGeometry.monitorColumns(
        Services.Compositor.outputs,
        Services.Compositor.workspaces,
        Services.Compositor.windows,
        root.wanted,
        root.perOutput)

    function showIdx(output, idx) {
        var o = ({})
        for (var k in root.perOutput)
            o[k] = root.perOutput[k]
        o[String(output)] = idx
        root.perOutput = o          // a new object, so the binding re-evaluates
    }

    // Which column the pointer is over during a drag; -1 for none.
    property int dropTarget: -1

    // ⚠️ ARROW KEYS PAGE EVERY COLUMN AT ONCE. The surface is in `wantsKeys`
    // (OverlaySurface.qml), so it really receives these — a page that is not on
    // that list gets no keyboard focus at all, which is what left the emoji
    // search box unable to take a single character.
    Keys.onLeftPressed: root.step(-1)
    Keys.onRightPressed: root.step(1)

    function step(by) {
        var next = root.wanted + by
        if (next < 1)
            return
        // Do not walk past the last workspace any monitor actually has: niri
        // creates them on demand, so an index nobody has is an empty screen.
        var most = 1
        for (var i = 0; i < root.columns.length; i++) {
            var ws = root.columns[i].workspaces
            if (ws.length && ws[ws.length - 1].idx > most)
                most = ws[ws.length - 1].idx
        }
        if (next > most)
            return
        root.wanted = next
        root.perOutput = ({})   // the arrows move every column together again
    }

    BarText {
        Layout.fillWidth: true
        text: "Monitors"
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgDim
    }

    RowLayout {
        id: row
        Layout.fillWidth: true
        spacing: Theme.space3

        Repeater {
            model: root.columns

            ColumnLayout {
                id: col
                required property int index
                required property var modelData
                spacing: Theme.space1

                // The connector name, so it is obvious which box is which
                // screen. niri's own name, not a made-up "Monitor 1" — that is
                // the name every other surface and `bhctl doctor` use.
                BarText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: col.modelData.output
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.fgMuted
                }

                Rectangle {
                    id: box
                    implicitWidth: Math.round(root.boxHeight * col.ratio)
                    implicitHeight: root.boxHeight
                    radius: Theme.radiusSm
                    color: root.dropTarget === col.index ? Theme.accent
                         : (col.modelData.ws && col.modelData.ws.is_focused) ? Theme.surfaceHigh
                         : Theme.surface
                    border.width: Theme.hairline
                    border.color: (col.modelData.ws && col.modelData.ws.is_focused)
                                  ? Theme.accent : Theme.outline

                    Behavior on color {
                        enabled: Theme.animate
                        ColorAnimation { duration: Theme.durFast }
                    }

                    // Clicking a column goes to that monitor's workspace — the
                    // map is a switcher too, exactly like the workspace one.
                    TapHandler {
                        onTapped: {
                            if (!col.modelData.ws)
                                return
                            Services.Compositor.focusMonitor(col.modelData.output)
                            Services.Compositor.focusWorkspace(col.modelData.ws.idx)
                            Ipc.collapse()
                        }
                    }

                    Item {
                        id: tiles
                        anchors.fill: parent
                        anchors.margins: Theme.space1

                        readonly property real outW:
                            (col.modelData.logical && col.modelData.logical.width > 0)
                            ? col.modelData.logical.width : 0
                        readonly property real outH:
                            (col.modelData.logical && col.modelData.logical.height > 0)
                            ? col.modelData.logical.height : 0

                        readonly property var placed: WorkspaceGeometry.layoutWindows(
                            col.modelData.windows, tiles.outW, tiles.outH)

                        BarText {
                            anchors.centerIn: parent
                            visible: col.modelData.windows.length === 0
                            // An empty monitor says so. A blank box reads as
                            // something that failed to load.
                            text: col.modelData.ws ? "empty" : "no workspace"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.fgDim
                        }

                        Repeater {
                            model: tiles.placed

                            Rectangle {
                                id: tile
                                required property var modelData
                                readonly property var win: tile.modelData.win

                                x: tiles.width * tile.modelData.x
                                y: tiles.height * tile.modelData.y
                                width: Math.max(Theme.space2,
                                                tiles.width * tile.modelData.w - Theme.space1)
                                height: Math.max(Theme.space2,
                                                 tiles.height * tile.modelData.h - Theme.space1)

                                radius: Theme.radiusXs
                                color: tile.win.is_focused ? Theme.accentAlt
                                                           : Theme.surfaceHigher
                                opacity: drag.active ? 0.5 : 1

                                AppIcon {
                                    anchors.centerIn: parent
                                    source: tile.win.app_id || ""
                                    appName: tile.win.app_id || ""
                                    size: Math.min(Theme.space5,
                                                   tile.width - Theme.space1 * 2)
                                }

                                TapHandler {
                                    onTapped: {
                                        Services.Compositor.focusWindow(tile.win.id)
                                        Ipc.collapse()
                                    }
                                }

                                // ⚠️⚠️ THE GESTURE, AND IT IS TWO CALLS BECAUSE
                                // NIRI'S INDICES COUNT PER OUTPUT. Measured on the
                                // lab VM with two heads:
                                //
                                //   idx=1 exists on Virtual-1 AND on Virtual-2
                                //   move-window-to-workspace <idx> resolves
                                //     against the WINDOW's output, not the
                                //     focused one — proved by focusing Virtual-1
                                //     while the window sat on Virtual-2 and
                                //     watching it stay there
                                //
                                // So the order is not a choice: put the window on
                                // the target monitor first, and only then can an
                                // index mean the workspace we meant. Both calls
                                // name the window by id, so nothing depends on
                                // what happens to be focused.
                                DragHandler {
                                    id: drag
                                    onActiveChanged: {
                                        if (drag.active) {
                                            root.dropTarget = -1
                                            return
                                        }
                                        var t = root.dropTarget
                                        root.dropTarget = -1
                                        if (t < 0 || t >= root.columns.length)
                                            return
                                        var target = root.columns[t]
                                        if (!target.ws)
                                            return
                                        if (target.ws.id === tile.win.workspace_id)
                                            return
                                        Services.Compositor.moveWindowToMonitor(
                                            tile.win.id, target.output, target.ws.idx)
                                    }
                                    onCentroidChanged: {
                                        if (!drag.active)
                                            return
                                        // Into `row`, because the rectangles
                                        // compared against are its children.
                                        var p = tile.mapToItem(
                                            row, drag.centroid.position.x,
                                            drag.centroid.position.y)
                                        root.dropTarget = root.columnAt(p.x, p.y)
                                    }
                                }
                            }
                        }
                    }
                }

                // ------------------------------------------- paging one column
                //
                // ⚠️ PER COLUMN, and that is his example rather than a nicety:
                // "wenn das fenster aufm 2. workspace ist aufm linken monitor,   // english-ok: the request, quoted
                // das ich den dann aufm 3ten workspace aufm rechten monitor      // english-ok: the request, quoted
                // ziehen kann". Two different indices at once is the whole point,  // english-ok: the request, quoted
                // and a single shared index could never express it.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space1

                    // ⚠️ OFFERED ONLY WHEN IT WOULD DO SOMETHING — the same rule
                    // the calendar's month arrows follow. A button that is
                    // already where it takes you is noise, and a dead one on a
                    // monitor with a single workspace reads as broken.
                    Pill {
                        interactive: true
                        visible: col.prevIdx > 0
                        Icon { text: "chevron_left"; size: Theme.fontSizeLg }
                        onClicked: root.showIdx(col.modelData.output, col.prevIdx)
                    }
                    BarText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: col.modelData.ws ? String(col.modelData.ws.idx) : "-"   // literal-ok: no workspace on this screen
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.fgMuted
                    }
                    Pill {
                        interactive: true
                        visible: col.nextIdx > 0
                        Icon { text: "chevron_right"; size: Theme.fontSizeLg }
                        onClicked: root.showIdx(col.modelData.output, col.nextIdx)
                    }
                }

                // The shape of this screen, so a monitor looks like itself
                // rather than like every other one. `logical`, never the mode
                // size — a 4K screen at scale 2 is logically 1920x1080.
                readonly property real ratio: {
                    var lg = col.modelData.logical
                    if (lg && lg.width > 0 && lg.height > 0)
                        return lg.width / lg.height
                    return 16 / 9   // literal-ok: the stated fallback ratio
                }

                // The neighbouring indices THIS monitor really has, so an arrow
                // is dead rather than lying when there is nothing next door.
                readonly property int prevIdx: col.neighbour(-1)
                readonly property int nextIdx: col.neighbour(1)
                function neighbour(by) {
                    var ws = col.modelData.workspaces || []
                    var cur = col.modelData.ws ? col.modelData.ws.idx : 0
                    var best = 0
                    for (var i = 0; i < ws.length; i++) {
                        var d = ws[i].idx - cur
                        if (by < 0 && d < 0 && (best === 0 || ws[i].idx > best))
                            best = ws[i].idx
                        if (by > 0 && d > 0 && (best === 0 || ws[i].idx < best))
                            best = ws[i].idx
                    }
                    return best
                }

            }
        }
    }

    // Which column a point is over. Plain geometry rather than a DropArea per
    // box — that would need the drag to carry MIME data, which is a lot of
    // ceremony for "is the pointer inside this rectangle".
    //
    // ⚠️ A zero-width child is skipped: `row.children` also holds the Repeater
    // itself, measured at the end of the list with width 0.
    function columnAt(x, y) {
        for (var i = 0; i < row.children.length; i++) {
            var c = row.children[i]
            if (c.width <= 0)
                continue
            if (c.x <= x && x <= c.x + c.width && c.y <= y && y <= c.y + c.height)
                return i
        }
        return -1
    }
}
