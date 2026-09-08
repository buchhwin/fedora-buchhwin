// Bar and island are ONE drawn shape.
//
// Straight from the plan: "Bar-an und Bar-aus sind dieselbe gezeichnete  english-ok: quoted brief
// Silhouette mit barH = 34 bzw. barH = 0." Building them as two windows was a
// mistake — with the bar on, the island simply disappeared behind it, and the
// concave shoulder had nothing to blend into.
//
// The path, in screen coordinates with y pointing down:
//
//     (0,0) ────────────────────────────────────────────── (W,0)
//       │                                                    │
//     (0,barH) ─────╮                          ╭───── (W,barH)
//                   ╰──╮                    ╭──╯      ← flare, concave
//                      │     island        │
//                      ╰────────────────────╯          ← rounded corners
//
// With barH = 0 the top strip collapses and only the island is left, its
// shoulders flaring straight off the screen edge. One shape, two modes, no
// second code path — which is the only reason a palette or a size change can
// be trusted to affect both the same way.
//
// ⚠️ THE SHOULDERS CURVE INWARDS, and this is the whole point rather than a
// detail. `islandWidth` is the span at `shoulderTop` — the widest place — and
// the straight sides sit `flare` px inside it. Drawing them the other way
// round, outside `islandWidth`, is what was here before: ShellSurface makes the
// window exactly `islandWidth` wide, so the arcs landed outside the surface and
// were clipped away entirely. Measured on the running VM: the pill came out
// 150×34 with perfectly vertical sides and no shoulder anywhere, which is not a
// wrong radius but a missing curve.
//
// Widening the window instead is not the fix. niri "has no way of knowing about
// invisible margins, and will draw the shadow behind the entire surface" — blur
// likewise — so a window wider than its shape brings back the coloured halo.
// The shape has to fit the window, not the other way round.
//
// It also matches the brief, which says the shoulders run "zum Bildschirmrand  english-ok: quoted brief
// hin": the material widens as it approaches the top edge.

import QtQuick
import QtQuick.Shapes
import "../../theme"

Item {
    id: root

    property real barHeight: 0
    property real islandWidth: 0
    property real islandHeight: 0
    property real flare: 0
    property real cornerRadius: Theme.radiusLg
    property color fill: Theme.panelBg

    readonly property real cx: width / 2
    readonly property real halfW: islandWidth / 2

    // A shoulder deeper than the island is tall, or wider than half of it, makes
    // the two arcs cross — which renders as a knot rather than as a curve.
    readonly property real f: Math.max(0, Math.min(flare, halfW,
                                                   islandHeight - barHeight))

    // Where the straight side runs: `flare` inside the widest span.
    readonly property real bodyHalfW: Math.max(0, halfW - f)

    // The island's own corner radius, clamped so it cannot exceed the shape.
    // Against `bodyHalfW`, not `halfW`, because the corners belong to the body.
    readonly property real r: Math.max(0, Math.min(cornerRadius, bodyHalfW,
                                                   (islandHeight - barHeight - f) / 2))

    // Not "bottom": Item already has a final member of that name, and overriding
    // it fails the whole type with "Cannot override FINAL property".
    readonly property real islandBottom: islandHeight

    // How far down the shoulders start. With the bar on they start at its
    // lower edge, so bar and island read as one piece of material.
    readonly property real shoulderTop: barHeight

    Shape {
        anchors.fill: parent
        // Antialiased curves without a multisample buffer — what keeps an
        // animated shape affordable.
        preferredRendererType: Shape.CurveRenderer
        asynchronous: true
        // ⚠️ NOT layer.enabled. For a static screen corner that is the right
        // way to get a crisp edge; for a shape whose size animates every frame
        // it re-rasterises a full-screen texture continuously.

        ShapePath {
            fillColor: root.fill
            strokeWidth: -1          // literal-ok: "no stroke", not a measurement

            startX: 0
            startY: 0

            // Top edge, all the way across.
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.shoulderTop }
            PathLine { x: root.cx + root.halfW; y: root.shoulderTop }

            // Right shoulder: CONCAVE — the screen edge curves down into the
            // notch, it does not bulge out around it.
            //
            // There is no negative radius, so this is an arc whose centre lies
            // OUTSIDE the filled area. For the same start point, end point and
            // radius there are two possible centres; the direction is what
            // picks between them. Clockwise here produced little ears sticking
            // out at the top — measured on screen, not reasoned about.
            PathArc {
                x: root.cx + root.bodyHalfW
                y: root.shoulderTop + root.f
                radiusX: root.f
                radiusY: root.f
                direction: PathArc.Counterclockwise
            }

            PathLine { x: root.cx + root.bodyHalfW; y: root.islandBottom - root.r }

            // Bottom-right corner: ordinary convex rounding.
            PathArc {
                x: root.cx + root.bodyHalfW - root.r
                y: root.islandBottom
                radiusX: root.r
                radiusY: root.r
                direction: PathArc.Clockwise
            }

            PathLine { x: root.cx - root.bodyHalfW + root.r; y: root.islandBottom }

            PathArc {
                x: root.cx - root.bodyHalfW
                y: root.islandBottom - root.r
                radiusX: root.r
                radiusY: root.r
                direction: PathArc.Clockwise
            }

            PathLine { x: root.cx - root.bodyHalfW; y: root.shoulderTop + root.f }

            // Left shoulder, mirrored.
            PathArc {
                x: root.cx - root.halfW
                y: root.shoulderTop
                radiusX: root.f
                radiusY: root.f
                direction: PathArc.Counterclockwise
            }

            PathLine { x: 0; y: root.shoulderTop }
            PathLine { x: 0; y: 0 }
        }
    }
}
