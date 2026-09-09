// The Bluetooth devices this machine knows about, and the way onto one.
//
// ⚠️ THE SAME STORY AS NetworkList.qml, and the same correction:
// tests/check-repo.sh forbade this file until 09.09.2026 on the reading that a
// panel here would be a second Bluetooth application. services/Bt.qml already
// had connect, disconnect, forget and setEnabled, and NOTHING CALLED ANY OF IT —
// the quick panel jumped to `systemsettings kcm_bluetooth`, which is the second
// application the rule was written against.
//
// ⚠️ DISCOVERY IS ONLY ON WHILE THIS IS OPEN, the same shape as the scanner in
// NetworkList and the nodes in SoundList. A radio that keeps looking for devices
// after the panel is shut is a battery cost for a list nobody is reading.
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services" as Services
import "../common"

ColumnLayout {
    id: root

    spacing: Theme.space2

    Component.onCompleted: Services.Bt.watch(true)
    Component.onDestruction: Services.Bt.watch(false)

    // ------------------------------------------------------------- the radio
    //
    // ⚠️ THE ROW ANSWERS THE PRESS, NOT THE SWITCH — see the same note in
    // NetworkList.qml. common/Toggle.qml has no `toggled` signal by design.
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: radioLine.implicitHeight + Theme.space2 * 2
        radius: Theme.radiusSm
        color: radioHover.hovered ? Theme.pillHover
                                  : "transparent"             // literal-ok: absence of colour

        HoverHandler { id: radioHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            enabled: Services.Bt.available
            onTapped: Services.Bt.setEnabled(!Services.Bt.enabled)
        }

        RowLayout {
            id: radioLine
            anchors.fill: parent
            anchors.margins: Theme.space2
            spacing: Theme.space3

            BarText {
                Layout.fillWidth: true
                text: !Services.Bt.available ? "No Bluetooth adapter"
                    : Services.Bt.enabled ? (Services.Bt.discovering ? "Looking for devices …"
                                                                     : "Bluetooth")
                    : "Bluetooth is off"
                font.pixelSize: Theme.fontSizeSm
                color: Theme.fgMuted
            }

            Toggle {
                visible: Services.Bt.available
                checked: Services.Bt.enabled
            }
        }
    }

    // Absent rather than empty — see the note in SoundList.qml. "Nothing paired
    // yet" and "the adapter is off" are different sentences and a blank space
    // says neither.
    BarText {
        Layout.fillWidth: true
        visible: Services.Bt.available && Services.Bt.enabled
                 && Services.Bt.devices.length === 0
        text: "Nothing found yet"
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
    }

    // ---------------------------------------------------------- the devices
    Repeater {
        model: Services.Bt.enabled ? Services.Bt.devices : []

        Rectangle {
            id: dev
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: line.implicitHeight + Theme.space2 * 2
            radius: Theme.radiusSm
            color: dev.modelData.connected ? Theme.surfaceHigh
                 : hover.hovered ? Theme.pillHover
                 : "transparent"                              // literal-ok: absence of colour

            HoverHandler { id: hover }

            // Connected means disconnect, anything else means connect. Pairing
            // is bluez's own business and it happens inside `connect()` for a
            // device that is not paired yet.
            TapHandler {
                onTapped: dev.modelData.connected
                          ? Services.Bt.disconnect(dev.modelData)
                          : Services.Bt.connect(dev.modelData)
            }

            RowLayout {
                id: line
                anchors.fill: parent
                anchors.margins: Theme.space2
                spacing: Theme.space3

                // The glyph comes from Bt.glyphFor, so the translation from
                // bluez's freedesktop icon names lives in one place and
                // tests/icons.sh can measure every name it can return.
                Icon {
                    text: dev.modelData.icon
                    size: Theme.fontSizeLg
                    color: dev.modelData.connected ? Theme.accent : Theme.fg
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0    // literal-ok: absence of a gap — a name and its state are one thing

                    BarText {
                        Layout.fillWidth: true
                        text: dev.modelData.name
                        elide: Text.ElideRight
                        color: dev.modelData.connected ? Theme.accent : Theme.fg
                    }

                    BarText {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        // ⚠️ THE BATTERY IS ONLY SHOWN WHERE THERE IS ONE. Bt.qml
                        // hands back -1 for a device that reports none, and
                        // "0 %" beside a working headset is worse than silence.
                        text: dev.modelData.pairing ? "pairing …"
                            : dev.modelData.connected
                              ? (dev.modelData.battery >= 0
                                 ? "connected · " + dev.modelData.battery + " %"
                                 : "connected")
                            : dev.modelData.paired ? "paired"
                            : ""
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.fgMuted
                        elide: Text.ElideRight
                    }
                }

                // Only for a device there is something to forget about, the same
                // reasoning as the network list: an unpairing by accident is a
                // pairing done again by hand.
                Icon {
                    visible: dev.modelData.paired
                    text: "close"
                    size: Theme.fontSizeSm
                    color: forget.hovered ? Theme.warn : Theme.fgDisabled
                    HoverHandler { id: forget }
                    // An exclusive grab, for the reason spelled out in
                    // NetworkList.qml and enforced by tests/nested-taps.sh:
                    // without it this press also reaches the row and would
                    // unpair AND connect in one go.
                    TapHandler {
                        gesturePolicy: TapHandler.WithinBounds
                        onTapped: Services.Bt.forget(dev.modelData)
                    }
                }
            }
        }
    }

    BarText {
        Layout.fillWidth: true
        visible: Services.Bt.status.length > 0
        text: Services.Bt.status
        font.pixelSize: Theme.fontSizeSm
        color: Theme.warn
        wrapMode: Text.WordWrap
    }
}
