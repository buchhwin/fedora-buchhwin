// A settings row that picks one of the machine's audio devices.
//
// ⚠️ IT LOOKS LIKE A SettingRow AND IS NOT ONE, on purpose. Every other row in
// this window owns a key in shell.json; the default sink is Pipewire's state,
// and storing our own copy of it would be a second opinion that goes stale the
// moment anything else — pavucontrol, a headset being plugged in, the quick
// panel — changes it. So this reads the service and calls it, and there is no
// key for tests/setting-rows.sh to look for.
//
// ⚠️⚠️ AND THE LIST ITSELF IS `common/Dropdown`, NOT A SECOND ONE. The first
// draft of this file grew its own PopupWindow with its own rows and its own
// hover colours — about eighty lines that would have had to be kept in step
// with the real dropdown for ever. Rule 6 says a control two places need lives
// in one place, and the settings window is full of dropdowns already. What is
// left here is the part that is genuinely about audio: turning devices into
// options and a choice back into a service call.
//
// ⚠️ AND IT ANSWERS B40's RULE, which is the general one behind it: "das soll   // english-ok: the request, quoted
// nicht nur bei den zeigern angezeigt werden sondern in jedem drop down menu".  // english-ok: the request, quoted
// A device name is the clearest case of a value nobody can type from memory.
import QtQuick
import QtQuick.Layouts
import "../common"
import "../../theme"

RowLayout {
    id: root

    property string label: ""
    property string hint: ""
    // Entries as the audio service hands them out: { id, name, isDefault, icon }
    property var devices: []

    signal picked(var entry)

    // ⚠️ THE VALUE IS THE NAME, not the id. Dropdown speaks strings, the service
    // speaks objects, and the name is what both agree on — ids are Pipewire's
    // and change when a device is re-plugged.
    readonly property var _options: {
        var out = []
        for (var i = 0; i < root.devices.length; i++) {
            var d = root.devices[i]
            if (d)
                out.push({ value: String(d.name), label: String(d.name) })
        }
        return out
    }

    readonly property string _current: {
        for (var i = 0; i < root.devices.length; i++)
            if (root.devices[i] && root.devices[i].isDefault)
                return String(root.devices[i].name)
        return ""
    }

    spacing: Theme.space4

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.space1

        BarText { text: root.label }

        BarText {
            Layout.fillWidth: true
            visible: root.hint.length > 0
            text: root.hint
            wrapMode: Text.WordWrap
            color: Theme.fgMuted
            font.pixelSize: Theme.fontSizeSm
        }
    }

    // ⚠️ AN EMPTY LIST SAYS SO rather than showing a dropdown with nothing in
    // it. "No devices" and "the control is broken" must not look alike — the
    // VPN tile cost a round on exactly that, and it is rule 5 in one line.
    BarText {
        visible: root.devices.length === 0
        text: "None found"
        color: Theme.fgMuted
        font.pixelSize: Theme.fontSizeSm
    }

    // One device is not a choice — it is a fact, and a dropdown over it is a
    // control that cannot do anything.
    BarText {
        visible: root.devices.length === 1
        Layout.maximumWidth: Theme.space6 * 8
        text: root._current
        elide: Text.ElideRight
        color: Theme.fgMuted
        font.pixelSize: Theme.fontSizeSm
    }

    Dropdown {
        Layout.preferredWidth: Theme.space6 * 9
        visible: root.devices.length > 1
        options: root._options
        current: root._current
        onPicked: function (value) {
            for (var i = 0; i < root.devices.length; i++) {
                var d = root.devices[i]
                if (d && String(d.name) === String(value)) {
                    root.picked(d)
                    return
                }
            }
        }
    }
}
