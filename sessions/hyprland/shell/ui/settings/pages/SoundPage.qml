// Sound — where it comes out, where it goes in, and how loud.
//
// B70, on his request: "es muss ein sounds tab in den settings wo man default    // english-ok: the request, quoted
// output in put festlegen kann und generell wichtige Sound settings bitte auch   // english-ok: the request, quoted
// noch als neuen tab bauen". Asked how much should be on it, he chose two        // english-ok: the request, quoted
// levels — the same shape he picked for the rest of the settings window.
//
// ⚠️ THE DEVICES ARE NOT SETTINGS, and that is why this page is not simply a
// list of SettingRows. Which sink is default is Pipewire's state, not a key in
// shell.json: writing it to a file would give us a second opinion that goes
// stale the moment anything else changes it. So those rows read the service and
// call it, and only the genuinely stored preferences carry a `key`.
//
// ⚠️ AND IT HAS TO SAY SO WHEN THERE IS NO SOUND CARD. The lab VM has none —
// Pipewire reports zero nodes there — and a page that simply came up empty would
// read as broken. Rule 5, and the same mistake the brightness slider made.
import QtQuick
import QtQuick.Layouts
import ".."
import "../../common"
import "../../../config"
import "../../../services" as Services
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    // ------------------------------------------------------------- devices
    SettingGroup {
        Layout.fillWidth: true
        title: "Devices"

        BarText {
            Layout.fillWidth: true
            visible: !Services.Audio.available
            text: "No sound card detected on this machine."
            wrapMode: Text.WordWrap
            color: Theme.fgMuted
            font.pixelSize: Theme.fontSizeSm
        }

        // ⚠️ A DROPDOWN OF WHAT THE MACHINE HAS, never a typed name. That is
        // B40's rule — "das soll nicht nur bei den zeigern angezeigt werden       // english-ok: the request, quoted
        // sondern in jedem drop down menu" — and a device name is the clearest    // english-ok: the request, quoted
        // case of it: nobody knows what their sink is called.
        DevicePicker {
            Layout.fillWidth: true
            visible: Services.Audio.available
            label: "Output"
            hint: "Where sound comes out."
            devices: Services.Audio.outputs
            onPicked: function (entry) { Services.Audio.useOutput(entry) }
        }

        DevicePicker {
            Layout.fillWidth: true
            visible: Services.Audio.micAvailable
            label: "Input"
            hint: "Which microphone is used."
            devices: Services.Audio.inputs
            onPicked: function (entry) { Services.Audio.useInput(entry) }
        }

        BarText {
            Layout.fillWidth: true
            visible: Services.Audio.available && !Services.Audio.micAvailable
            text: "No microphone detected."
            wrapMode: Text.WordWrap
            color: Theme.fgMuted
            font.pixelSize: Theme.fontSizeSm
        }
    }

    // -------------------------------------------------------------- levels
    SettingGroup {
        Layout.fillWidth: true
        title: "Levels"
        visible: Services.Audio.available

        // ⚠️ SettingSlider IS THE TRACK, NOT A ROW — it carries no label of its
        // own, which is why these are composed here instead of configured. The
        // rest of the window gets its labels from SettingRow, and SettingRow
        // needs a `key`; a level that lives in Pipewire has none.
        //
        // ⚠️ PERCENT, NOT 0..1. The service speaks fractions and a person reads
        // percent, so the conversion sits here rather than in either of them.
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space4

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.space1
                BarText { text: "Volume" }
                BarText {
                    Layout.fillWidth: true
                    text: "The same level the quick panel shows."
                    wrapMode: Text.WordWrap
                    color: Theme.fgMuted
                    font.pixelSize: Theme.fontSizeSm
                }
            }

            SettingSlider {
                Layout.preferredWidth: Theme.space6 * 9
                from: 0
                to: 100
                step: 1
                unit: "%"
                value: Math.round(Services.Audio.volume * 100)
                onMoved: function (v) { Services.Audio.setVolume(v / 100) }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: Services.Audio.micAvailable
            spacing: Theme.space4

            BarText { Layout.fillWidth: true; text: "Input level" }

            SettingSlider {
                Layout.preferredWidth: Theme.space6 * 9
                from: 0
                to: 100
                step: 1
                unit: "%"
                value: Math.round(Services.Audio.micVolume * 100)
                onMoved: function (v) { Services.Audio.setMicVolume(v / 100) }
            }
        }

        ActionRow {
            Layout.fillWidth: true
            label: "Mute"
            hint: Services.Audio.muted ? "Output is muted." : "Output is audible."
            button: Services.Audio.muted ? "Unmute" : "Mute"
            onTriggered: Services.Audio.toggleMute()
        }

        ActionRow {
            Layout.fillWidth: true
            visible: Services.Audio.micAvailable
            label: "Mute the microphone"
            hint: Services.Audio.micMuted ? "The microphone is muted."
                                          : "The microphone is live."
            button: Services.Audio.micMuted ? "Unmute" : "Mute"
            onTriggered: Services.Audio.toggleMicMute()
        }
    }

    // -------------------------------------------------- per programme (level 2)
    //
    // ⚠️ BEHIND "SHOW MORE", because it is a list whose length is not ours to
    // choose — a browser with six tabs playing makes six rows. His two-level
    // rule exists for exactly this kind of section.
    SettingGroup {
        Layout.fillWidth: true
        title: "Per programme"
        visible: Services.Audio.available

        BarText {
            Layout.fillWidth: true
            visible: Services.Audio.streams.length === 0
            text: "Nothing is playing."
            color: Theme.fgMuted
            font.pixelSize: Theme.fontSizeSm
        }

        Repeater {
            model: Services.Audio.streams

            RowLayout {
                id: streamRow
                required property var modelData
                Layout.fillWidth: true
                spacing: Theme.space4

                BarText {
                    Layout.fillWidth: true
                    text: String(streamRow.modelData.name || "")
                    elide: Text.ElideRight
                }

                SettingSlider {
                    Layout.preferredWidth: Theme.space6 * 9
                    from: 0
                    to: 100
                    step: 1
                    unit: "%"
                    value: Math.round(streamRow.modelData.volume * 100)
                    onMoved: function (v) {
                        Services.Audio.setNodeVolume(streamRow.modelData, v / 100)
                    }
                }
            }
        }
    }
}
