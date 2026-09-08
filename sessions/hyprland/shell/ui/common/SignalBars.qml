// Signal strength, drawn rather than lettered.
//
// ⚠️ THIS EXISTS BECAUSE THE FONT DOES NOT HAVE IT. Material Icons Round has
// `signal_wifi_4_bar` and nothing below it: signal_wifi_0_bar through _3_bar,
// network_wifi_1_bar through _3_bar and wifi_1_bar/_2_bar were all measured
// against the installed font and all render as their own letters. A family of
// icons that only looks like it is there is worse than no family, so the four
// bars are four rectangles from the same tokens as everything else.
//
// Four steps, not a percentage — see Net.levelOf() for why the raw value is not
// bound to anything that draws.
import QtQuick
import "../../theme"

Row {
    id: root

    // 0 means "nothing", which is drawn as four empty bars rather than as
    // nothing at all: an absent indicator and a weak signal must not look alike.
    property int level: 0
    property int size: Theme.fontSizeLg
    property color activeColour: Theme.fg
    property color idleColour: Theme.fgDisabled

    spacing: Theme.hairline * 2
    height: root.size

    Repeater {
        model: 4

        Rectangle {
            required property int index
            width: Math.max(Theme.hairline * 2, Math.round(root.size / 5))
            // A quarter tall at the shortest, full height at the tallest, so
            // the shape reads as a ramp at a glance and not as a bar chart.
            height: Math.round(root.size * (0.4 + 0.2 * index))
            anchors.verticalCenter: parent.verticalCenter
            radius: Theme.radiusXs
            color: index < root.level ? root.activeColour : root.idleColour

            Behavior on color {
                enabled: Theme.animate
                ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
            }
        }
    }
}
