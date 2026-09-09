pragma ComponentBehavior: Bound

// Every workspace and what is on it, small, on top of the desktop you are using.
//
// His words: "eine übersicht über alle workspaces … eine miniatur ansicht an     english-ok: the request, quoted
// allen workspaces und ich kann programme mit der maus von einem in den anderen  english-ok: the request, quoted
// workspace verschieben" — and, on being asked, a small panel on the running     english-ok: the request, quoted
// desktop rather than a full-screen overview.
//
// ⚠️ THERE ARE NO PICTURES IN HERE, AND THAT IS NOT LAZINESS. A Wayland client
// may not read another window's contents. The only capture protocol available,
// wlr-screencopy, records the OUTPUT that is currently on screen — not the other
// workspaces, which the compositor is not drawing at all. A thumbnail grid built
// from it would show one real picture and empty boxes for everything else.
//
// So this draws what the compositor DOES tell us, and it turns out to be enough
// to recognise a workspace at a glance:
//
//   hyprctl -j clients      app_id · title · id · workspace_id · is_focused
//                            · is_floating · layout
//   hyprctl -j workspaces   id · idx · name · is_active · output
//
// ⚠️ AND `layout` IS WHY THE BOXES ARE IN THE RIGHT PLACES. It carries
// `pos_in_scrolling_layout: [column, row]` and `tile_size`, measured on the
// machine rather than assumed — so a column that is half as wide is drawn half
// as wide, and three windows side by side look like three windows side by side.
//
// ⚠️ Everything comes from `Services.Compositor`, which is fed by the compositor's
// event-stream. No polling: a map that costs CPU while nobody is looking at it
// is the kind of idle work this desktop is not allowed to do.

import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../config"
import "../../../ipc"
import "../../../services" as Services
// ⚠️ THREE dots, not two: `shell/common` (the shared singletons) is a different
// folder from `shell/ui/common` (the widgets), and both are imported here.
import "../../../common"
import "../../common"

ColumnLayout {
    id: root

    spacing: Theme.space3

    // How tall one workspace box is. The width follows from the columns in it,
    // so a busy workspace is a wider box — which is itself information.
    //
    // ⚠️ IT WAS `space6 * 3` AND THAT WAS TOO SMALL TO USE — reported exactly
    // that way about the switcher. `space6` is 32, so a workspace was a 64×96
    // box holding 24 px window tiles with 13 px icons on them. At that size the
    // tiles are colour, not information: you cannot tell a terminal from a
    // browser, which is the one question this surface exists to answer.
    //
    // Doubled, and the tiles and icons with it — see the tile below. It stays
    // derived from the spacing scale rather than becoming a key of its own, so
    // the `look.uiScale` slider still moves it along with everything else.
    readonly property int boxHeight: Theme.space6 * 6

    // The shape of the screen these boxes stand for, so a workspace looks like
    // a workspace rather than like a phone.
    //
    // ⚠️ `logical`, NOT THE MODE SIZE, and the Displays page has the same note
    // for the same reason: a 3840x2160 screen at scale 2 is logically 1920x1080,
    // and the compositor counts in logical pixels. Both give 16:9 here, but on a
    // rotated or fractionally scaled output only one of them is the shape you
    // are looking at.
    //
    // ⚠️ AND IT IS GUARDED AT EVERY STEP. `activeOutput` is empty for a moment
    // during startup, an output can be missing from the map while it is being
    // reconfigured, and a height of zero would make this Infinity — a box
    // several thousand pixels wide inside a Flickable, which is the sort of
    // thing that reads as "the switcher is broken" rather than as a divide.
    readonly property real screenRatio: {
        var o = Services.Compositor.outputs || ({})
        var here = o[String(Services.Compositor.activeOutput || "")]
        var lg = here && here.logical
        if (lg && lg.width > 0 && lg.height > 0)
            return lg.width / lg.height
        return 16 / 9   // literal-ok: the stated fallback ratio, not a measurement
    }

    // ⚠️⚠️ B77 · B78 · THE SCALE DRAWING, AS ONE PURE FUNCTION. It takes the
    // windows of a workspace and the output's logical size, and answers with a
    // rectangle per window in 0..1 of the box. Everything the delegate below
    // draws comes from here — and it lives in `common/WorkspaceGeometry.qml`
    // rather than in this file.
    //
    // ⚠️ IT MOVED WHEN B33 ARRIVED, and moving beat copying: `Shift+Alt+Tab`
    // draws the same picture with one column per MONITOR instead of one per
    // workspace, and rule 6 says a list may not exist twice. A second copy would
    // have been the worse kind of duplicate — the arithmetic is measured against
    // the compositor's own numbers, and a copy would have drifted from those
    // quietly.
    //
    // The origin is passed straight through: these thumbnails are all of the
    // ACTIVE monitor, so its position in the global layout has to come off the
    // window coordinates before they mean anything inside a box.
    function layoutWindows(wins, outW, outH, outX, outY) {
        return WorkspaceGeometry.layoutWindows(wins, outW, outH, outX, outY)
    }

    // The workspaces, each with its own windows already gathered. Done once
    // here rather than filtered again inside every delegate: with n workspaces
    // and m windows the naive way is n×m passes on every single event.
    readonly property var groups: {
        var byWs = ({})
        var all = Services.Compositor.windows || []
        for (var i = 0; i < all.length; i++) {
            var w = all[i]
            var k = String(w.workspace_id)
            if (!byWs[k])
                byWs[k] = []
            byWs[k].push(w)
        }
        // Real order: column first, then row. `pos_in_scrolling_layout` is
        // [column, row], both 1-based.
        for (var k2 in byWs) {
            byWs[k2].sort(function (a, b) {
                var pa = (a.layout && a.layout.pos_in_scrolling_layout) || [0, 0]
                var pb = (b.layout && b.layout.pos_in_scrolling_layout) || [0, 0]
                return pa[0] !== pb[0] ? pa[0] - pb[0] : pa[1] - pb[1]
            })
        }
        // ⚠️⚠️ ONLY THIS MONITOR'S WORKSPACES, on his instruction: "wenn ich aufm  // english-ok: the request, quoted
        // linken monitor alt tab mache sollen nur die workspaces vom linken      // english-ok: the request, quoted
        // monitor angezeigt werden und nicht die vom rechten".                   // english-ok: the request, quoted
        //
        // It listed every workspace on every screen, so on three monitors the
        // switcher was three desktops wide and two thirds of it was somewhere
        // he was not looking. `hyprctl -j workspaces` carries `output` on each
        // entry — the filter costs nothing and the information was already here.
        //
        // ⚠️ `activeOutput` RATHER THAN THE SURFACE'S OWN SCREEN, and the two
        // agree by construction: a surface opens on the output it was opened
        // from (B1), and with focus-follows-mouse on, that output is the one the
        // pointer is over. Reading the screen here would mean this page knowing
        // which window it lives in, which is the coupling B1 removed.
        //
        // ⚠️ AN EMPTY `activeOutput` SHOWS EVERYTHING rather than nothing. It is
        // empty for a moment during startup, and a switcher that is briefly
        // blank reads as broken — where a switcher that is briefly too full
        // reads as a switcher.
        var out = []
        var ws = Services.Compositor.workspaces || []
        var here = String(Services.Compositor.activeOutput || "")
        for (var j = 0; j < ws.length; j++) {
            if (here.length > 0 && String(ws[j].output || "") !== here)
                continue
            out.push({ ws: ws[j], windows: byWs[String(ws[j].id)] || [] })
        }
        return out
    }

    // Which box the pointer is over while dragging, so it can light up. -1 is
    // "none" rather than 0, which is a real index.
    property int dropTarget: -1

    BarText {
        text: "Workspaces"
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
    }

    RowLayout {
        id: row
        spacing: Theme.space3

        Repeater {
            model: root.groups

            // ------------------------------------------------ one workspace
            Rectangle {
                id: box
                required property var modelData
                required property int index

                // ⚠️⚠️ THE WIDTH COMES FROM THE SCREEN'S SHAPE, NOT FROM WHAT IS
                // IN THE BOX — and the old line was wrong twice over. He found
                // the first half: "die workspaces sind vertikal, was keinen      // english-ok: the report, quoted
                // sinn macht, weil die fenster ja horizontal sind … also müsste  // english-ok: the report, quoted
                // jedes fenster, was einen workspace darstellt, eigentlich das   // english-ok: the report, quoted
                // verhältnis 16:9 haben". Measured: 128 wide by 192 tall — a     // english-ok: the report, quoted
                // portrait box standing for a landscape screen.
                //
                // The second half he could not have seen from one screenshot:
                // the width came from `tiles.implicitWidth`, so a workspace with
                // more windows in it was WIDER THAN ITS NEIGHBOUR. That is
                // rule 7's own example — a surface sized by its contents — and
                // it means the row reflows every time a window opens.
                //
                // ⚠️ THE REAL OUTPUT'S RATIO, NOT A CONSTANT 16:9. `logical` is
                // in the compositor's answer and services/Hyprland.qml already parses it; the
                // Displays page reads exactly the same field. On a 16:9 screen
                // this is his number, and on the 16:10 laptop it is the more
                // honest one. 16:9 is the fallback for the moment during startup
                // when `activeOutput` is still empty.
                implicitWidth: Math.round(root.boxHeight * root.screenRatio)
                implicitHeight: root.boxHeight
                radius: Theme.radiusSm
                // The workspace you are on is the accent one. A drop target
                // outranks it while a drag is happening — during a drag the
                // question is "where will it land", not "where am I".
                color: root.dropTarget === box.index ? Theme.accent
                     : box.modelData.ws.is_active ? Theme.surfaceHigh
                     : Theme.surface
                border.width: Theme.hairline
                border.color: box.modelData.ws.is_focused ? Theme.accent
                                                          : Theme.outline

                Behavior on color {
                    enabled: Theme.animate
                    ColorAnimation { duration: Theme.durFast }
                }

                // Clicking the box goes to that workspace — the map is also a
                // switcher, which is what you want nine times out of ten.
                TapHandler {
                    onTapped: {
                        Services.Compositor.focusWorkspace(box.modelData.ws.idx)
                        Ipc.collapse()
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.space1
                    spacing: 0   // literal-ok: absence of a gap

                    // ⚠️ THE INDEX, ALWAYS — never the name. THE SAME FAULT AS
                    // THE BAR, REPORTED TWICE, FIXED ONCE.
                    //
                    // `Config.workspaces` names the first workspace "scratch",
                    // because `Super+Ö` focuses it by name. So this map read
                    // "scratch 2 3" while the bar underneath read "1 2 3" —
                    // reported the first time as "das erste ist gar keine zahl  english-ok: the report, quoted
                    // sondern irgend ein wort", and now a second time as "bei   english-ok: the report, quoted
                    // alt tab ist 1 nicht eins sondern irgenein wort mit s".    english-ok: the report, quoted
                    //
                    // BarContent.qml was corrected in August and carries the
                    // reasoning; this file was not, because the rule lived in a
                    // comment in one file instead of in a check over both. It
                    // does now: tests/workspace-labels.sh.
                    //
                    // A map of workspaces is a POSITION indicator — "you are on
                    // the second of three" — and a word in the first slot
                    // destroys that at a glance, because the eye can no longer
                    // count. The name still exists and `focus-workspace scratch`
                    // still works; it is just not what the label is for.
                    //
                    // ⚠️ Measured before it was changed rather than assumed:
                    // `hyprctl -j workspaces` on the VM answers
                    // `{"idx":1,"name":"scratch"}` and `{"idx":2,"name":null}`.
                    // The first guess — that Rust's `None` was arriving as a
                    // truthy STRING — was wrong, and the machine said so in one
                    // command.
                    BarText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: String(box.modelData.ws.idx)
                        font.pixelSize: Theme.fontSizeSm
                        color: root.dropTarget === box.index ? Theme.accentFg
                                                             : Theme.fgMuted
                    }

                    // ------------------------------------- the windows in it
                    //
                    // ⚠️⚠️ B77 · B78 · A MAP OF THE WORKSPACE, NOT A ROW OF TILES.
                    // This was a `RowLayout` where each window asked for a SHARE
                    // of the box as its width. Two of his reports come straight
                    // out of that one decision:
                    //
                    //   "wenn ich mehr als 2 Fenster in einem Workspace offen    // english-ok: the report, quoted
                    //   hab buggt super tab rum das ist dann voll abgeschnitten" // english-ok: the report, quoted
                    //
                    //   "die Apps werden nicht richtig groß angezeigt … wenn ich // english-ok: the report, quoted
                    //   super tab drücke und dort 3 Fenster … das settings menu  // english-ok: the report, quoted
                    //   … ist halt nur in der Mitte des Screens aber halt nur so // english-ok: the report, quoted
                    //   groß wie das settings menu … dann soll das auch          // english-ok: the report, quoted
                    //   angezeigt werden … also die richtige größe der Fenster"  // english-ok: the report, quoted
                    //
                    // ⚠️ MEASURED, and the numbers say why it overflowed. Three
                    // windows on the lab VM, `hyprctl -j clients`:
                    //
                    //   kitty      col/row [1,1]   tile 1232x734
                    //   Alacritty  col/row [2,1]   tile 1232x734
                    //   kitty      col/row [3,1]   tile 1232x734
                    //   output Virtual-1           logical 1280x800
                    //
                    // Each window is 96% of the screen — the compositor is a SCROLLING
                    // compositor, so a workspace is legitimately wider than its
                    // output. As shares in a RowLayout that is 2.9x the box, and
                    // the row ran off the end. Clamping each tile would have
                    // destroyed the very thing B53 added: comparable widths.
                    //
                    // So the box is a scale drawing of the workspace instead.
                    // Columns are laid out in the compositor's own order and every tile is
                    // placed and sized against the SAME denominator, so relative
                    // sizes survive and nothing can leave the box.
                    Item {
                        id: tiles
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        // The whole geometry, from the one function on root.
                        readonly property real outW: {
                            var o = Services.Compositor.outputs
                                    ? Services.Compositor.outputs[String(box.modelData.ws.output || "")]
                                    : null
                            return (o && o.logical && o.logical.width > 0) ? o.logical.width : 0
                        }
                        readonly property real outH: {
                            var o = Services.Compositor.outputs
                                    ? Services.Compositor.outputs[String(box.modelData.ws.output || "")]
                                    : null
                            return (o && o.logical && o.logical.height > 0) ? o.logical.height : 0
                        }
                        // The origin of the monitor this workspace lives on.
                        // Hyprland positions windows in the GLOBAL layout, so
                        // without it everything on a second screen lands past
                        // the right edge of its own box.
                        readonly property real outX: {
                            var o = Services.Compositor.outputs
                                    ? Services.Compositor.outputs[String(box.modelData.ws.output || "")]
                                    : null
                            return (o && o.logical) ? (o.logical.x || 0) : 0
                        }
                        readonly property real outY: {
                            var o = Services.Compositor.outputs
                                    ? Services.Compositor.outputs[String(box.modelData.ws.output || "")]
                                    : null
                            return (o && o.logical) ? (o.logical.y || 0) : 0
                        }
                        readonly property var placed:
                            root.layoutWindows(box.modelData.windows, tiles.outW, tiles.outH,
                                               tiles.outX, tiles.outY)

                        BarText {
                            anchors.centerIn: parent
                            visible: box.modelData.windows.length === 0
                            // An empty workspace says so. A blank box reads as
                            // something that failed to load.
                            text: "empty"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.fgDim
                        }

                        Repeater {
                            // ⚠️ THE MODEL IS THE PLACED RECTANGLES, not the raw
                            // window list. Each entry carries the window plus its
                            // x/y/w/h as a fraction of the box, worked out once by
                            // `root.layoutWindows`. The delegate multiplies and
                            // draws; it does no geometry of its own, which is why
                            // the arithmetic can be checked without a screen.
                            model: tiles.placed

                            Rectangle {
                                id: tile
                                required property var modelData
                                readonly property var win: tile.modelData.win

                                // ⚠️⚠️ B53 STILL HOLDS, AND THIS IS HOW. His
                                // request was "ob das fenster den halben screen    // english-ok: the request, quoted
                                // hat oder voll" — a SHARE, never a pile of      // english-ok: the request, quoted
                                // pixels, so a full-screen window looks the same
                                // on a 1920 output and a 2560 one. The fraction
                                // now comes from `layoutWindows`, against a
                                // denominator shared by every tile in the box, so
                                // the comparison survives B77's fix instead of
                                // being clamped away by it.
                                //
                                // ⚠️ A FLOOR ON THE DRAWN SIZE, NOT ON THE SHARE.
                                // A very narrow window must not become an
                                // invisible hairline; the proportion above is
                                // untouched, so half-versus-full stays readable.
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

                                // ⚠️⚠️ THE COMMENT THAT USED TO BE HERE WAS THE
                                // BUG, WRITTEN DOWN AS A REASON. It claimed
                                // "the compositor's app_id IS the freedesktop icon name
                                // in nearly every case, and where it is not,
                                // the fallback catches it". Measured on
                                // 10.08.2026 over the twenty programs this
                                // desktop ships: the app_id answered as an icon
                                // name for NINE, and the letter tile — the
                                // "fallback" — was what he actually saw, which
                                // is what he reported.
                                //
                                // AppIcon goes through the .desktop entry now
                                // (Services.Apps.iconFor), which answers for
                                // fifteen. `appName` stays as the last resort
                                // for a window whose program is not installed
                                // as a desktop entry at all.
                                AppIcon {
                                    anchors.centerIn: parent
                                    source: tile.win.app_id || ""
                                    appName: tile.win.app_id || ""
                                    // ⚠️ Was `fontSizeLg`, which is 13 px — an
                                    // icon that small is a coloured smudge, and
                                    // telling one window from another is the
                                    // whole job here. Never wider than the tile
                                    // it sits on, so a narrow column still gets
                                    // an icon that fits rather than one that
                                    // overhangs.
                                    size: Math.min(Theme.space5,
                                                   tile.width - Theme.space1 * 2)
                                }

                                // Click focuses that window, wherever it is.
                                TapHandler {
                                    onTapped: {
                                        Services.Compositor.focusWindow(tile.win.id)
                                        Ipc.collapse()
                                    }
                                }

                                // ⚠️ THE DRAG, and it deliberately does NOT
                                // reparent or animate the tile anywhere. Moving
                                // a QML item between two Repeater delegates
                                // while the model underneath is being rewritten
                                // by a compositor event is a fight nobody wins.
                                // The tile fades, the target box lights up, and
                                // the actual move is the compositor's job.
                                DragHandler {
                                    id: drag
                                    onActiveChanged: {
                                        if (drag.active) {
                                            root.dropTarget = -1
                                            return
                                        }
                                        var t = root.dropTarget
                                        root.dropTarget = -1
                                        if (t < 0 || t >= root.groups.length)
                                            return
                                        var target = root.groups[t].ws
                                        if (target.id === tile.win.workspace_id)
                                            return
                                        // ⚠️ `idx`, not `id` — the compositor's reference
                                        // is the INDEX. They differ: here the
                                        // workspaces are idx 1/2/3 with ids
                                        // 1/3/4.
                                        Services.Compositor.moveWindowToWorkspace(
                                            tile.win.id, target.idx)
                                    }
                                    onCentroidChanged: {
                                        if (!drag.active)
                                            return
                                        // ⚠️ INTO `row`, NOT INTO `root` — the
                                        // rectangles compared against below are
                                        // `row`'s children, so their x and y are
                                        // in `row`'s coordinates. Mapping the
                                        // pointer into `root` put it a header's
                                        // height too low: the bottom of every box
                                        // stopped answering and the strip under it
                                        // started to.
                                        var p = tile.mapToItem(row, drag.centroid.position.x,
                                                               drag.centroid.position.y)
                                        root.dropTarget = root.boxAt(p.x, p.y)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Which workspace box a point is over. Plain geometry rather than
    // DropArea: a DropArea per box would need the drag to carry MIME data,
    // which is a lot of ceremony for "is the pointer inside this rectangle".
    //
    // ⚠️ THE REPEATER IS IN `row.children` TOO, and it was worth measuring
    // rather than assuming which way round. Asked of QML itself with a three-item
    // Repeater in a RowLayout:
    //
    //     children=4
    //       0: QQuickRectangle  w=10 x=0
    //       1: QQuickRectangle  w=10 x=15
    //       2: QQuickRectangle  w=10 x=30
    //       3: QQuickRepeater   w=0  x=0
    //
    // So the delegates come FIRST and the index returned here lines up with
    // `groups` — there is no off-by-one, which is what a plausible reading of
    // this loop suggests and the machine denies. The Repeater itself is zero
    // wide, so it can never win the test either.
    function boxAt(x, y) {
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
