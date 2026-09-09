pragma ComponentBehavior: Bound

// Where the monitors are, as a picture you can drag.
//
// ⚠️⚠️ THE ONE THING THAT MAKES THIS HARD, AND IT IS NOT THE DRAGGING. From
// the compositor's own wiki (Configuration:-Outputs.md, "position"):
//
//     If the position is unset or results in an OVERLAP, the output is instead
//     placed automatically.
//
// So a canvas that lets two tiles overlap is a control that lies: it shows the
// arrangement you drew, writes it, and the compositor quietly puts the monitor somewhere
// else entirely. Overlap is therefore PREVENTED here rather than reported — a
// dragged tile snaps to a free edge of its neighbours, and there is no state in
// which this writes a position the compositor will refuse.
//
// ⚠️ AND THE UNITS ARE LOGICAL PIXELS, NOT MODE PIXELS. Same page of the wiki:
// "a 3840x2160 output with scale 2.0 will have a logical size of 1920x1080, so
// to put another output directly adjacent to it on the right, set its x to
// 1920." Sizing tiles by the mode would be wrong by exactly the scale factor,
// and wrong in the direction that looks plausible. `logical` comes straight from
// `hyprctl -j monitors` and already carries the scaled size.
//
// ⚠️ AND the compositor RE-PLACES EVERY OUTPUT FROM SCRATCH on any change, sorted by name:
// first all the ones with an explicit position, then the rest to the right of
// those. That is why dropping one tile writes positions for ALL of them — a
// half-positioned set moves the screens you never touched.
//
// ⚠️ MOTION: the tile moves `x`/`y` on an Item inside a canvas of FIXED size.
// Nothing here animates an implicit size, and the canvas never changes its own —
// which is what rule 7 is about, and what tests/motion.sh refuses to excuse.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../common"
import "../../config"
import "../../services" as Services
import "../../theme"

Item {
    id: root

    // [{ name, w, h, x, y }] in logical pixels, built by the page from the
    // compositor's answer. Passed in rather than read here, because a picture
    // has no business deciding what a monitor is.
    property var screens: []

    signal moved(var placements)

    // ⚠️⚠️ THIS LINE SAID `Theme.space10 * 4`, AND THERE IS NO `space10`. The
    // grid stops at `space6`; the name was invented. QML says nothing about a
    // property that does not exist, so the multiplication produced NaN, the
    // canvas got no height at all, and every tile inside it had nowhere to be
    // drawn. The description beside it is a sibling and kept rendering — which
    // is exactly how it was reported: "eine beschreibung ist da aber ich sehe   // english-ok: the report, quoted
    // die monitore nicht als rechteck".                                         // english-ok: the report, quoted
    //
    // ⚠️ FOUR CHECKERS WERE GREEN OVER IT AT ONCE, and the reason is worth
    // keeping: `pages.sh` builds this page EMPTY under offscreen (no Wayland
    // outputs, so the repeater walks nothing), `displays.sh` measures the
    // ARITHMETIC against a fake fixture rather than the geometry,
    // `no-literals.sh` is what pushed a bare number into being a token name in
    // the first place and never asks whether the name exists — and `qmllint-qt6`
    // was measured on this very class once before (`Theme.glassRimTop`, after
    // the token was deleted) and had nothing to say. tests/theme-tokens.sh is
    // the tripwire that closes it.
    //
    // 160 px at scale 1: three 16:9 screens side by side are an aspect of about
    // 5.3:1, so on a settings page this wide they fit with room to spare, and a
    // stacked arrangement simply scales down inside it.
    //
    // ⚠️ FIXED, and the header says why: the tiles move `x`/`y` inside a canvas
    // that never changes its own size. A height that followed the content would
    // re-lay-out the page on every drag.
    implicitHeight: Theme.space6 * 5

    // ⚠️ ONE SCALE FOR THE WHOLE PICTURE, computed from the bounding box of
    // every screen. Fitting each tile separately would draw a 1080p and a 4K
    // monitor the same size, which is the one thing this picture exists to show.
    readonly property real _pad: Theme.space4
    readonly property var _bounds: {
        if (!root.screens || !root.screens.length)
            return { x: 0, y: 0, w: 1, h: 1 }
        var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
        for (var i = 0; i < root.screens.length; i++) {
            var s = root.screens[i]
            minX = Math.min(minX, s.x)
            minY = Math.min(minY, s.y)
            maxX = Math.max(maxX, s.x + s.w)
            maxY = Math.max(maxY, s.y + s.h)
        }
        return { x: minX, y: minY, w: Math.max(1, maxX - minX), h: Math.max(1, maxY - minY) }
    }
    readonly property real _k: {
        var availW = Math.max(1, root.width - root._pad * 2)
        var availH = Math.max(1, root.height - root._pad * 2)
        return Math.min(availW / root._bounds.w, availH / root._bounds.h)
    }
    // Centre the drawing rather than pinning it to a corner, so a single screen
    // does not sit in the top left of an empty box looking like a mistake.
    readonly property real _ox: (root.width - root._bounds.w * root._k) / 2
    readonly property real _oy: (root.height - root._bounds.h * root._k) / 2

    function _toPixels(v) { return v * root._k }
    function _toLogical(v) { return v / root._k }

    // Does rect a overlap rect b? Touching edges is not overlap — that is the
    // arrangement everybody actually wants, and the compositor accepts it.
    function _overlaps(a, b) {
        return a.x < b.x + b.w && b.x < a.x + a.w
            && a.y < b.y + b.h && b.y < a.y + a.h
    }

    // ⚠️⚠️ B71 · DO THE TWO RECTANGLES SHARE A USABLE EDGE? Touching at a single
    // corner is not enough, and that distinction is the whole bug.
    //
    // His report: "ich hab den rechten zu weit nach rechts geschoben dann war   // english-ok: the report, quoted
    // da ne Lücke zwischen den linken und rechten und ich konnte nicht mehr auf // english-ok: the report, quoted
    // den anderen Monitor wegen der Lücke". The pointer crosses between outputs // english-ok: the report, quoted
    // along a SHARED EDGE; two screens that only meet at a corner, or that sit
    // apart diagonally, have no edge to cross and the far one is unreachable.
    //
    // The arrangement could produce exactly that: `_settle` pins one axis to a
    // neighbour's edge and leaves the other at wherever the finger was, so a
    // screen could land flush on the right while sliding far enough down to
    // clear its neighbour entirely. Legal for the compositor, and a dead end for a mouse.
    //
    // `_minTouch` keeps a corner-kiss from counting as contact: a shared edge
    // has to be worth aiming at, not one logical pixel tall.
    readonly property int _minTouch: 80

    function _sharesEdge(a, b) {
        var xTouch = (a.x + a.w === b.x) || (b.x + b.w === a.x)
        var yTouch = (a.y + a.h === b.y) || (b.y + b.h === a.y)
        var xSpan = Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x)
        var ySpan = Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y)
        if (xTouch)
            return ySpan >= Math.min(root._minTouch, Math.min(a.h, b.h))
        if (yTouch)
            return xSpan >= Math.min(root._minTouch, Math.min(a.w, b.w))
        return false
    }

    // ⚠️ AND ONE SHARED EDGE IS NOT ENOUGH EITHER — the set has to be CONNECTED.
    // Moving screen B can leave C attached to nothing, and checking only the
    // screen under the finger would miss it. A flood fill from the first screen
    // has to reach all of them.
    function _allReachable(rects) {
        if (rects.length < 2)
            return true
        var seen = [rects[0]]
        var grew = true
        while (grew) {
            grew = false
            for (var i = 0; i < rects.length; i++) {
                if (seen.indexOf(rects[i]) >= 0)
                    continue
                for (var j = 0; j < seen.length; j++) {
                    if (root._sharesEdge(rects[i], seen[j])) {
                        seen.push(rects[i]); grew = true; break
                    }
                }
            }
        }
        return seen.length === rects.length
    }

    // The nearest position for `name` that touches at least one neighbour and
    // overlaps none.
    //
    // ⚠️ CANDIDATES, NOT A SEARCH. Every legal resting place for a rectangle
    // against a set of rectangles is one of its four sides — so the candidates
    // are enumerable, and the nearest one to where the finger let go wins. A
    // gradient walk would find the same answers slowly and would have a state
    // where it finds none.
    function _settle(name, wantX, wantY) {
        var me = null
        var others = []
        for (var i = 0; i < root.screens.length; i++) {
            var s = root.screens[i]
            if (String(s.name) === String(name))
                me = { name: s.name, w: s.w, h: s.h, x: wantX, y: wantY }
            else
                others.push({ name: s.name, w: s.w, h: s.h, x: s.x, y: s.y })
        }
        if (me === null)
            return null
        // Nothing to bump into: the only screen there is sits at the origin,
        // because a lone monitor at x=4000 is a position with no meaning.
        if (!others.length)
            return [{ name: me.name, x: 0, y: 0 }]

        // ⚠️ B71 · THE FREE AXIS IS CLAMPED, and that one line is the fix. Each
        // candidate pins ONE axis to a neighbour's edge and used to leave the
        // other at `wantX`/`wantY` — so "flush on the right" could still be
        // dragged far enough down to clear the neighbour completely, which is a
        // legal arrangement with no shared edge and therefore no way across.
        // Clamping keeps the slide, and stops it exactly where the overlap
        // would run out.
        function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
        var yLo = 0, yHi = 0, xLo = 0, xHi = 0

        var best = null, bestD = Infinity
        for (var j = 0; j < others.length; j++) {
            var o = others[j]
            // Slide along the shared edge, but never past the point where the
            // two stop overlapping by `_minTouch`.
            var reach = Math.min(root._minTouch, Math.min(me.h, o.h))
            yLo = o.y - me.h + reach
            yHi = o.y + o.h - reach
            var reachX = Math.min(root._minTouch, Math.min(me.w, o.w))
            xLo = o.x - me.w + reachX
            xHi = o.x + o.w - reachX
            var cands = [
                { x: o.x + o.w,  y: clamp(wantY, yLo, yHi) },   // to the right of o
                { x: o.x - me.w, y: clamp(wantY, yLo, yHi) },   // to the left
                { x: clamp(wantX, xLo, xHi), y: o.y + o.h },    // below
                { x: clamp(wantX, xLo, xHi), y: o.y - me.h }    // above
            ]
            for (var c = 0; c < cands.length; c++) {
                var trial = { x: cands[c].x, y: cands[c].y, w: me.w, h: me.h }
                var clash = false
                for (var k = 0; k < others.length; k++) {
                    if (root._overlaps(trial, others[k])) { clash = true; break }
                }
                if (clash)
                    continue
                // ⚠️ AND THE WHOLE SET HAS TO STAY CONNECTED, not just this pair.
                // Dragging B away can strand C even though B itself landed
                // against A — checked here rather than after the write, because
                // after the write the only way back is to drag it again.
                var withMe = [trial]
                for (var r = 0; r < others.length; r++)
                    withMe.push(others[r])
                if (!root._allReachable(withMe))
                    continue
                var d = (trial.x - wantX) * (trial.x - wantX)
                      + (trial.y - wantY) * (trial.y - wantY)
                if (d < bestD) { bestD = d; best = trial }
            }
        }
        // ⚠️ NO LEGAL PLACE MEANS DO NOT MOVE, and it is a real case: drag a
        // screen into a pocket enclosed by three others. Refusing is the honest
        // answer — writing the overlap would hand the decision to the compositor, which
        // is exactly what this whole file is avoiding.
        if (best === null)
            return null

        // ⚠️ EVERY SCREEN IS WRITTEN, not just the dragged one — see the note at
        // the top about the compositor re-placing from scratch. And the set is normalised
        // so the top-left corner is (0,0): the arrangement is what matters, and
        // letting the origin wander means a drag to the left slowly walks every
        // coordinate negative.
        var out = [{ name: me.name, x: best.x, y: best.y }]
        for (var m = 0; m < others.length; m++)
            out.push({ name: others[m].name, x: others[m].x, y: others[m].y })
        var minX = Infinity, minY = Infinity
        for (var n = 0; n < out.length; n++) {
            minX = Math.min(minX, out[n].x)
            minY = Math.min(minY, out[n].y)
        }
        for (var p = 0; p < out.length; p++) {
            out[p].x -= minX
            out[p].y -= minY
        }
        return out
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSm
        color: Theme.pillBg
    }

    BarText {
        anchors.centerIn: parent
        visible: !root.screens || root.screens.length <= 1
        // ⚠️ IT SAYS WHY, rather than showing an empty box. One screen has no
        // arrangement, and a picture with nothing to drag reads as broken.
        text: (!root.screens || !root.screens.length)
              ? "No screens to arrange yet"
              : "One screen — nothing to arrange"
        color: Theme.fgMuted
        font.pixelSize: Theme.fontSizeSm
    }

    Repeater {
        model: (root.screens && root.screens.length > 1) ? root.screens : []

        Rectangle {
            id: tile
            required property var modelData

            // Where the tile sits while nobody is dragging it: straight from the
            // arrangement. During a drag the handler owns x/y, and this binding
            // is broken by the assignment — which is the documented way, and it
            // is restored on release by `screens` changing underneath.
            x: root._ox + root._toPixels(tile.modelData.x - root._bounds.x)
            y: root._oy + root._toPixels(tile.modelData.y - root._bounds.y)
            width: root._toPixels(tile.modelData.w)
            height: root._toPixels(tile.modelData.h)

            radius: Theme.radiusSm
            color: drag.active ? Theme.accent : Theme.surface
            border.width: 1     // literal-ok: a hairline, the thinnest a border can be
            border.color: Theme.fgMuted

            Behavior on color {
                enabled: Theme.animate
                ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
            }

            BarText {
                anchors.centerIn: parent
                width: parent.width - Theme.space2
                horizontalAlignment: Text.AlignHCenter
                text: String(tile.modelData.name)
                font.pixelSize: Theme.fontSizeSm
                color: drag.active ? Theme.bg : Theme.fg
                elide: Text.ElideMiddle
            }

            DragHandler {
                id: drag
                // ⚠️ THE WRITE IS ON RELEASE, NOT PER FRAME. Config.save()
                // serialises the whole of shell.json; a drag produces a value
                // per frame, and rule 8 calls debounced writing a duty rather
                // than polish. What moves during the gesture is `x`/`y` on this
                // Item, which the compositor never hears about at all.
                onActiveChanged: {
                    if (drag.active)
                        return
                    var lx = root._bounds.x + root._toLogical(tile.x - root._ox)
                    var ly = root._bounds.y + root._toLogical(tile.y - root._oy)
                    var placements = root._settle(String(tile.modelData.name),
                                                  Math.round(lx), Math.round(ly))
                    if (placements === null) {
                        // Nowhere legal to land: snap back by restoring the
                        // bindings the drag broke.
                        tile.x = Qt.binding(function () {
                            return root._ox + root._toPixels(tile.modelData.x - root._bounds.x)
                        })
                        tile.y = Qt.binding(function () {
                            return root._oy + root._toPixels(tile.modelData.y - root._bounds.y)
                        })
                        return
                    }
                    root.moved(placements)
                }
            }
        }
    }
}
