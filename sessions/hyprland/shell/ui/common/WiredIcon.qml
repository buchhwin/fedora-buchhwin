// A wired connection, drawn rather than lettered.
//
// ⚠️ THIS EXISTS BECAUSE THE FONT DOES NOT HAVE IT — the same reason SignalBars
// next door exists, and measured the same way. Material Icons Round has no
// ethernet glyph anybody would recognise:
//
//   lan                  not in the font (200 px, a real glyph is ~70)
//   cable                not in the font (400 px)
//   hub                  not in the font (200 px)
//   dns                  IS in the font — and draws a stack of servers, which
//                        says "server", not "network cable"
//   settings_ethernet    IS in the font — and draws `‹···›`
//
// `settings_ethernet` is what shipped, and it is what he asked to have removed:
// "wenn man auf die notch hovert ist da recht auch ein komisches symol bitt      // english-ok: his report, quoted
// eauch wegmachen". It is Material's own ethernet icon, so tests/icons.sh was    // english-ok: his report, quoted
// right about it all along — the name exists and it measures like a glyph. It
// simply does not look like anything. That is the gap a check cannot close and
// only a screenshot can, and it is now written down in the handouts as such.
//
// ⚠️ ONE SHAPE IN ONE FILE, so the notch and the quick panel cannot drift into
// two different ideas of "wired" — the same rule that put the signal bars here
// rather than in each surface that shows them.
//
// The shape is a plug: a body, two pins above it, and a lead below. Two
// rectangles and a line, from the same tokens as everything else, so it follows
// a palette change for free — which is the whole reason icons are text here in
// the first place.
import QtQuick
import "../../theme"

Item {
    id: root

    property int size: Theme.fontSizeLg
    property color colour: Theme.fg

    implicitWidth: root.size
    implicitHeight: root.size

    // The two pins. Above the body, inset from its edges, so the silhouette
    // reads as a plug rather than as a bar with dots on it.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.size * 0.12)
        spacing: Math.round(root.size * 0.22)

        Repeater {
            model: 2
            Rectangle {
                width: Math.max(Theme.hairline * 2, Math.round(root.size * 0.11))
                height: Math.round(root.size * 0.2)
                radius: Theme.radiusXs
                color: root.colour
            }
        }
    }

    // The body.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.size * 0.32)
        width: Math.round(root.size * 0.66)
        height: Math.round(root.size * 0.34)
        radius: Theme.radiusXs
        color: root.colour
    }

    // The lead. Narrower than the pins so the eye reads it as cable rather than
    // as a third pin.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.size * 0.66)
        width: Math.max(Theme.hairline * 2, Math.round(root.size * 0.13))
        height: Math.round(root.size * 0.22)
        radius: Theme.radiusXs
        color: root.colour
    }
}
