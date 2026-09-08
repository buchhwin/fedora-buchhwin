// Where the sound goes, where it comes from, and a level for each programme.
//
// This is the part that makes pavucontrol unnecessary, which the plan names as
// a goal rather than a side effect. Three sections, and each is absent rather
// than empty when there is nothing in it: a heading over no rows is furniture.
//
// ⚠️ Nodes are only bound while this exists — Audio.watch(true/false). Without
// that the sliders would show whatever the values were when the nodes appeared.
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services" as Services
import "../common"

ColumnLayout {
    id: root

    spacing: Theme.space2

    // ⚠️ B73 · THE SAME LIST, TURNED AROUND — not a second one. He asked for a
    // chevron on the microphone that picks the input "wie bei Sound", and the   // english-ok: the request, quoted
    // honest reading of that is the same control, not a near-copy of it. A
    // second list would be two places for one idea to drift apart, which rule 6
    // spends a paragraph on and this project has paid for more than once.
    //
    // In this mode the output section and the per-programme levels are absent
    // (not empty — absent, as the header of this file already insists) and the
    // input devices take their place.
    property bool inputsOnly: false

    Component.onCompleted: Services.Audio.watch(true)
    Component.onDestruction: Services.Audio.watch(false)

    // -------------------------------------------------------------- inputs
    BarText {
        Layout.fillWidth: true
        visible: root.inputsOnly && Services.Audio.inputs.length > 0
        text: "Input"
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
    }

    // ⚠️ IT SAYS SO WHEN THERE IS NOTHING, rather than drawing an empty band.
    // A machine with no capture device is the lab VM's normal state, and
    // "nothing installed" must not look like "the feature is broken" — that is
    // the VPN tile mistake, written down in rule 5 after it cost a round.
    BarText {
        Layout.fillWidth: true
        visible: root.inputsOnly && Services.Audio.inputs.length === 0
        text: "No microphone detected"
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
    }

    Repeater {
        model: root.inputsOnly ? Services.Audio.inputs : []

        Rectangle {
            id: inRow
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: inLine.implicitHeight + Theme.space2 * 2
            radius: Theme.radiusSm
            color: inRow.modelData.isDefault ? Theme.surfaceHigh
                 : inHover.hovered ? Theme.pillHover
                 : "transparent"                              // literal-ok: absence of colour

            HoverHandler { id: inHover }
            TapHandler { onTapped: Services.Audio.useInput(inRow.modelData) }

            RowLayout {
                id: inLine
                anchors.fill: parent
                anchors.margins: Theme.space2
                spacing: Theme.space3

                Icon {
                    text: inRow.modelData.icon
                    size: Theme.fontSizeLg
                    color: inRow.modelData.isDefault ? Theme.accent : Theme.fg
                }

                BarText {
                    Layout.fillWidth: true
                    text: inRow.modelData.name
                    elide: Text.ElideRight
                }

                Icon {
                    visible: inRow.modelData.isDefault
                    text: "check"
                    size: Theme.fontSize
                    color: Theme.accent
                }
            }
        }
    }

    // ------------------------------------------------------------- outputs
    BarText {
        Layout.fillWidth: true
        visible: !root.inputsOnly && Services.Audio.outputs.length > 1
        text: "Output"
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
    }

    Repeater {
        // One output is not a choice, and a list of one is a list that only
        // takes up room.
        model: (!root.inputsOnly && Services.Audio.outputs.length > 1)
               ? Services.Audio.outputs : []

        Rectangle {
            id: outRow
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: outLine.implicitHeight + Theme.space2 * 2
            radius: Theme.radiusSm
            color: outRow.modelData.isDefault ? Theme.surfaceHigh
                 : outHover.hovered ? Theme.pillHover
                 : "transparent"                              // literal-ok: absence of colour

            HoverHandler { id: outHover }
            TapHandler { onTapped: Services.Audio.useOutput(outRow.modelData) }

            RowLayout {
                id: outLine
                anchors.fill: parent
                anchors.margins: Theme.space2
                spacing: Theme.space3

                Icon {
                    text: outRow.modelData.icon
                    size: Theme.fontSizeLg
                    color: outRow.modelData.isDefault ? Theme.accent : Theme.fg
                }

                BarText {
                    Layout.fillWidth: true
                    text: outRow.modelData.name
                    elide: Text.ElideRight
                }

                Icon {
                    visible: outRow.modelData.isDefault
                    text: "check"
                    size: Theme.fontSize
                    color: Theme.accent
                }
            }
        }
    }

    // ------------------------------------------------------------ programmes
    BarText {
        Layout.fillWidth: true
        visible: !root.inputsOnly && Services.Audio.streams.length > 0
        text: "Programs"
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
    }

    Repeater {
        model: root.inputsOnly ? [] : Services.Audio.streams

        RowLayout {
            id: streamRow
            required property var modelData
            Layout.fillWidth: true
            spacing: Theme.space3

            BarText {
                Layout.preferredWidth: Theme.space6 * 4
                text: streamRow.modelData.name
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSizeSm
            }

            LevelRow {
                Layout.fillWidth: true
                icon: streamRow.modelData.muted ? "volume_off" : "graphic_eq"
                value: streamRow.modelData.volume
                live: !streamRow.modelData.muted
                onMoved: function (f) { Services.Audio.setNodeVolume(streamRow.modelData, f) }
                onNudged: function (d) {
                    Services.Audio.setNodeVolume(streamRow.modelData,
                        streamRow.modelData.volume + d / steps)
                }
            }
        }
    }

    BarText {
        Layout.fillWidth: true
        // ⚠️ NOT IN INPUT MODE. "Nothing is playing" under a list of microphones
        // is an answer to a question nobody asked, and the input side has its
        // own empty line above.
        visible: !root.inputsOnly && Services.Audio.streams.length === 0
        text: "Nothing is playing"
        color: Theme.fgMuted
        font.pixelSize: Theme.fontSizeSm
    }
}
