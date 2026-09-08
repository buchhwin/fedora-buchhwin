// The work timer: pick a length, and the notch counts it down.
//
// The presets are the ones a working day is actually made of rather than a row
// of round numbers — a short break, a long one, a focused stretch, and an hour.
// They come from the configuration like everything else, so anybody who works
// in different lengths says so once.
//
// ⚠️ THE PAGE IS NOT WHERE THE TIMER LIVES. Everything here calls into
// services/Countdown, and the notch reads the same singleton — so closing this
// does not stop anything, and the remaining time is on screen without it.
import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../config"
import "../../../services" as Services
import "../../common"

ColumnLayout {
    id: root

    implicitWidth: Theme.space6 * 15
    spacing: Theme.space3

    // ------------------------------------------------------------ the reading
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space3

        BarText {
            text: Services.Countdown.rang ? "Time is up"
                : Services.Countdown.active ? Services.Countdown.label
                : "No timer"
            font.family: Services.Countdown.active ? Theme.fontMono : Theme.fontUi
            font.pixelSize: Theme.fontSizeDisplay
            font.weight: Theme.weightSemibold
            color: Services.Countdown.rang ? Theme.warn
                 : Services.Countdown.active ? Theme.accent
                 : Theme.fgDim
        }

        Item { Layout.fillWidth: true }

        Pill {
            visible: Services.Countdown.rang
            interactive: true
            active: true
            BarText { text: "got it"; font.pixelSize: Theme.fontSizeSm; color: Theme.accentFg }
            onClicked: Services.Countdown.acknowledge()
        }

        Pill {
            visible: Services.Countdown.active && !Services.Countdown.rang
            interactive: true
            Icon {
                text: Services.Countdown.paused ? "play_arrow" : "pause"
                size: Theme.fontSizeLg
            }
            onClicked: {
                if (Services.Countdown.paused) Services.Countdown.resume()
                else Services.Countdown.pause()
            }
        }

        Pill {
            visible: Services.Countdown.active
            interactive: true
            Icon { text: "close"; size: Theme.fontSizeLg }
            onClicked: Services.Countdown.stop()
        }
    }

    // A bar rather than a ring: it is read sideways at a glance, and a ring
    // would need a shader or an arc to say the same thing more slowly.
    Rectangle {
        Layout.fillWidth: true
        visible: Services.Countdown.active && Services.Countdown.total > 0
        implicitHeight: Theme.space1
        radius: Theme.radiusXs
        color: Theme.surfaceHigh

        Rectangle {
            height: parent.height
            radius: parent.radius
            color: Theme.accent
            width: parent.width * Math.max(0, Math.min(1,
                Services.Countdown.remaining / Math.max(1, Services.Countdown.total)))

            // motion-ok: this width IS the progress. It is drawn inside a bar of
            // fixed width and nothing lays out around it.
            Behavior on width {
                enabled: Theme.animate
                NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
            }
        }
    }

    // ------------------------------------------------------------ the presets
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space2

        Repeater {
            model: Config.timer.presets

            Pill {
                id: preset
                // ⚠️ `string`, and converted here. The config stores these as
                // strings because that is the only list type JsonAdapter can
                // read back — see config/Config.qml, where the measurement is.
                // Declaring it `int` here would silently coerce and then a
                // stray "20 min" in the file would become 0.
                required property string modelData
                readonly property int minutes: parseInt(preset.modelData) || 0
                interactive: true
                visible: preset.minutes > 0
                BarText {
                    text: preset.minutes + " min"
                    font.pixelSize: Theme.fontSizeSm
                }
                onClicked: Services.Countdown.start(preset.minutes * 60)
            }
        }

        Item { Layout.fillWidth: true }

        // Stretching a running timer is the commonest thing anybody wants from
        // one, and it is two taps rather than starting again from the top.
        Pill {
            visible: Services.Countdown.active
            interactive: true
            BarText { text: "+5"; font.pixelSize: Theme.fontSizeSm }
            onClicked: Services.Countdown.add(300)
        }
    }
}
