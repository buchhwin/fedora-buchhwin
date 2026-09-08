// One rounded screen corner. Four of these make the display look like it has
// them.
//
// ⚠️ NIRI CANNOT DO THIS, ASKED RATHER THAN ASSUMED. Its wiki has
// `geometry-corner-radius` for windows and for layer surfaces and nothing for
// the output itself — the only screen-wide rounding it mentions is in its own
// design principles, as a shader it deliberately does not run. So this is ours,
// and being ours it has to be cheap.
//
// ⚠️ AS BIG AS THE RADIUS, NOT AS BIG AS THE SCREEN. A single fullscreen
// surface with four corners drawn on it would make niri blur and shadow the
// whole display — its own layer-rule documentation says it "has no way of
// knowing about invisible margins, and will draw the shadow behind the entire
// surface". That is the coloured halo this project has already chased once.
// Four surfaces of r × r pixels cost four small textures and nothing else.
//
// ⚠️ AND INPUT GOES STRAIGHT THROUGH. An empty mask region means the corner is
// drawn and not clickable. Without it the top-left corner would swallow niri's
// overview gesture and the top-right one our own hot corner — two features
// killed by a decoration.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../config"

PanelWindow {
    id: root

    required property var modelData
    // "top-left" | "top-right" | "bottom-left" | "bottom-right"
    required property string corner

    readonly property bool atTop: root.corner.indexOf("top") === 0
    readonly property bool atLeft: root.corner.indexOf("left") > 0
    readonly property int radius: Config.surfaces.screenCornerRadius

    screen: modelData

    WlrLayershell.namespace: "buchhwin-corner"
    // Above everything, including fullscreen windows — a screen corner that
    // disappears when a video is playing is not a screen corner.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"                    // literal-ok: absence of colour

    anchors.top: root.atTop
    anchors.bottom: !root.atTop
    anchors.left: root.atLeft
    anchors.right: !root.atLeft

    implicitWidth: Math.max(1, root.radius)
    implicitHeight: Math.max(1, root.radius)

    // Empty region: nothing here takes a click.
    mask: Region {}

    Canvas {
        id: cut
        anchors.fill: parent

        // Repainted when the shape changes and at no other time. A Canvas that
        // repaints per frame is exactly what niri's own design note warns about
        // for long-running effects.
        onWidthChanged: cut.requestPaint()
        onHeightChanged: cut.requestPaint()

        onPaint: {
            var ctx = cut.getContext("2d")
            var r = Math.max(1, Math.min(cut.width, cut.height))
            ctx.reset()
            ctx.clearRect(0, 0, cut.width, cut.height)

            // ⚠️ BLACK, ON EVERY PALETTE. This is not a surface of the desktop
            // that should follow the theme — it is the ABSENCE of screen, the
            // same thing the bezel of a laptop is. A palette-coloured wedge in
            // the corner reads as a bug; a black one reads as the display.
            ctx.fillStyle = "black"      // literal-ok: a screen corner is the absence of screen
            ctx.beginPath()

            // ⚠️ THE FOUR CASES ARE WRITTEN OUT, and the first attempt was one
            // expression of nested ternaries that got the arc DIRECTION wrong
            // in every corner — it filled a plain black square, which is what a
            // screenshot showed and no error would have. Canvas angles run
            // clockwise on screen because y points down, which is exactly the
            // sort of thing worth spelling out once rather than deriving four
            // times.
            //
            // Each corner: the screen's own corner, the centre of the quarter
            // circle, the two angles where that circle meets the edges, and
            // which way round to travel between them.
            var w = cut.width, h = cut.height
            var corner, cx, cy, a0, a1, ccw
            if (root.atTop && root.atLeft) {
                corner = [0, 0]; cx = r;  cy = r;  a0 = -Math.PI / 2; a1 = Math.PI;      ccw = true
            } else if (root.atTop) {
                corner = [w, 0]; cx = 0;  cy = r;  a0 = -Math.PI / 2; a1 = 0;            ccw = false
            } else if (root.atLeft) {
                corner = [0, h]; cx = r;  cy = 0;  a0 = Math.PI / 2;  a1 = Math.PI;      ccw = false
            } else {
                corner = [w, h]; cx = 0;  cy = 0;  a0 = Math.PI / 2;  a1 = 0;            ccw = true
            }

            ctx.moveTo(corner[0], corner[1])
            ctx.lineTo(cx + r * Math.cos(a0), cy + r * Math.sin(a0))
            ctx.arc(cx, cy, r, a0, a1, ccw)
            ctx.closePath()
            ctx.fill()
        }
    }

    Connections {
        target: Config.surfaces
        function onScreenCornerRadiusChanged() { cut.requestPaint() }
    }
}
