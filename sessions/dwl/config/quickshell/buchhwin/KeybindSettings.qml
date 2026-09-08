import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Flickable { id: root; Theme { id: theme } contentWidth: width; contentHeight: body.implicitHeight; clip: true
    property var bindings: []; property string message: ""
    function refresh() { if (!reader.running) reader.running = true }
    Component.onCompleted: refresh()
    Process { id: reader; command: ["buchhwin-settings-backend", "keybinds"]; stdout: StdioCollector { onStreamFinished: { try { root.bindings = JSON.parse(text) } catch(e) { root.message = "Could not read keybinds" } } } }
    Process { id: writer; stdout: StdioCollector { onStreamFinished: root.message = text.trim() } stderr: StdioCollector { onStreamFinished: if (text.trim()) root.message = text.trim() } onExited: root.refresh() }
    ColumnLayout { id: body; width: root.width; spacing: 9
        Text { Layout.fillWidth: true; text: "All " + root.bindings.length + " shortcuts compiled into dwl are shown here. Desktop shortcuts with a Save button can be changed; generated workspace, hardware and safety shortcuts are marked Fixed."; color: theme.subtext; font.family: theme.font; font.pixelSize: 12; wrapMode: Text.WordWrap }
        Repeater { model: root.bindings; delegate: Rectangle { required property var modelData; Layout.fillWidth: true; height: 56; color: theme.surface2; border.width: 1; border.color: theme.border
            RowLayout { anchors.fill: parent; anchors.margins: 8; spacing: 7
                Text { Layout.fillWidth: true; text: modelData.label; color: theme.text; font.family: theme.font; font.pixelSize: 12 }
                Text { text: modelData.group || "Desktop"; color: theme.subtext; font.family: theme.font; font.pixelSize: 9; Layout.preferredWidth: 72 }
                Rectangle { width: 130; height: 30; color: theme.bg; border.width: 1; border.color: theme.border
                    TextInput { id: modifierInput; anchors.fill: parent; anchors.margins: 7; text: modelData.modifier; readOnly: !modelData.editable; color: modelData.editable ? theme.text : theme.subtext; font.family: theme.font; font.pixelSize: 9; verticalAlignment: TextInput.AlignVCenter; selectByMouse: modelData.editable }
                }
                Rectangle { width: 84; height: 30; color: theme.bg; border.width: 1; border.color: theme.border
                    TextInput { id: keyInput; anchors.fill: parent; anchors.margins: 7; text: modelData.key; readOnly: !modelData.editable; color: modelData.editable ? theme.text : theme.subtext; font.family: theme.font; font.pixelSize: 9; verticalAlignment: TextInput.AlignVCenter; selectByMouse: modelData.editable }
                }
                Rectangle { width: 60; height: 30; color: modelData.editable && saveMouse.containsMouse ? theme.blue : theme.bg; border.width: 1; border.color: theme.border; Text { anchors.centerIn: parent; text: modelData.editable ? "Save" : "Fixed"; color: modelData.editable ? theme.text : theme.subtext; font.family: theme.font; font.pixelSize: 9 }
                    MouseArea { id: saveMouse; anchors.fill: parent; enabled: modelData.editable; hoverEnabled: enabled; onClicked: { root.message = "Validating and rebuilding…"; writer.command = ["buchhwin-settings-backend", "keybind-set", modelData.id, modifierInput.text.trim(), keyInput.text.trim()]; writer.running = true } }
                }
            }
        } }
        Text { text: root.message; color: root.message.indexOf("Conflict") >= 0 ? theme.red : theme.blue; font.family: theme.font; font.pixelSize: 9; wrapMode: Text.WordWrap; Layout.fillWidth: true }
    }
}
