import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Flickable {
    id: root
    Theme { id: theme }
    contentWidth: width; contentHeight: body.implicitHeight; clip: true
    property var apps: []; property var defaults: []
    property string expandedMime: ""
    property string pendingId: ""; property string pendingName: ""; property string pendingSource: ""
    property string message: ""
    function refresh() { if (!appsRead.running) appsRead.running = true; if (!defaultsRead.running) defaultsRead.running = true }
    Component.onCompleted: refresh()
    Process { id: appsRead; command: ["buchhwin-settings-backend", "apps"]; stdout: StdioCollector { onStreamFinished: { try { root.apps = JSON.parse(text) } catch(e) { root.message = "Could not read applications" } } } }
    Process { id: defaultsRead; command: ["buchhwin-settings-backend", "defaults"]; stdout: StdioCollector { onStreamFinished: { try { root.defaults = JSON.parse(text) } catch(e) {} } } }
    Process { id: action; stderr: StdioCollector { onStreamFinished: if (text.trim()) root.message = text.trim() } onExited: code => { if (code === 0) { root.message = "Default application changed"; root.expandedMime = "" }; root.pendingId = ""; root.refresh() } }
    ColumnLayout { id: body; width: root.width; spacing: 14
        Text { text: "Default applications"; color: theme.text; font.family: theme.font; font.pixelSize: 17; font.bold: true }
        Text { Layout.fillWidth: true; text: "These defaults are account-wide and also affect Plasma."; color: theme.yellow; font.family: theme.font; font.pixelSize: 12; wrapMode: Text.WordWrap }
        Repeater { model: root.defaults; delegate: Rectangle {
            id: defaultRow
            required property var modelData
            readonly property bool expanded: root.expandedMime === modelData.mime
            readonly property int candidateRows: Math.max(1, Math.ceil(modelData.candidates.length / 3))
            Layout.fillWidth: true
            Layout.preferredHeight: expanded ? 92 + candidateRows * 48 : 72
            color: theme.surface2; border.width: 1; border.color: expanded ? theme.blue : theme.border
            clip: true
            Behavior on Layout.preferredHeight { NumberAnimation { duration: theme.durationMedium; easing.type: theme.easingEnter } }
            ColumnLayout { anchors.fill: parent; anchors.margins: 10; spacing: 9
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 50; color: defaultMouse.containsMouse ? theme.surface3 : theme.bg; border.width: 1; border.color: theme.border; radius: 6
                    RowLayout { anchors.fill: parent; anchors.leftMargin: 13; anchors.rightMargin: 13; spacing: 12
                        ColumnLayout { Layout.fillWidth: true; spacing: 2
                            Text { text: defaultRow.modelData.label; color: theme.text; font.family: theme.font; font.bold: true; font.pixelSize: 13 }
                            Text { Layout.fillWidth: true; text: defaultRow.modelData.currentName; color: theme.blue; font.family: theme.font; font.pixelSize: 11; elide: Text.ElideRight }
                        }
                        Text { text: defaultRow.expanded ? "󰅀" : "󰅂"; color: theme.subtext; font.family: theme.font; font.pixelSize: 17 }
                    }
                    MouseArea { id: defaultMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.expandedMime = defaultRow.expanded ? "" : defaultRow.modelData.mime }
                }
                Text { visible: defaultRow.expanded; text: "Recommended apps for " + defaultRow.modelData.label.toLowerCase(); color: theme.subtext; font.family: theme.font; font.pixelSize: 10 }
                GridLayout { visible: defaultRow.expanded; Layout.fillWidth: true; columns: 3; columnSpacing: 7; rowSpacing: 7
                    Repeater { model: defaultRow.modelData.candidates; delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 6
                        color: modelData.id === defaultRow.modelData.current ? theme.blue : candidateMouse.containsMouse ? theme.surface3 : theme.bg
                        border.width: 1; border.color: modelData.id === defaultRow.modelData.current ? theme.text : theme.border
                        Text { anchors.fill: parent; anchors.leftMargin: 11; anchors.rightMargin: 11; verticalAlignment: Text.AlignVCenter; text: modelData.name; color: modelData.id === defaultRow.modelData.current ? theme.bg : theme.text; font.family: theme.font; font.pixelSize: 11; elide: Text.ElideRight }
                        MouseArea { id: candidateMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (modelData.id === defaultRow.modelData.current) { root.expandedMime = ""; return }; root.message = "Applying " + modelData.name + "…"; action.command = ["buchhwin-settings-backend", "default", defaultRow.modelData.mime, modelData.id]; action.running = true } }
                    } }
                }
            }
        } }
        Text { text: "Installed desktop applications"; color: theme.text; font.family: theme.font; font.pixelSize: 17; font.bold: true; Layout.topMargin: 8 }
        Repeater { model: root.apps; delegate: Rectangle { required property var modelData; Layout.fillWidth: true; height: 58; color: theme.surface2; border.width: 1; border.color: theme.border
            RowLayout { anchors.fill: parent; anchors.margins: 9
                ColumnLayout { Layout.fillWidth: true; spacing: 2; Text { text: modelData.name; color: theme.text; font.family: theme.font; font.pixelSize: 13; font.bold: true } Text { text: modelData.source + " · " + modelData.id; color: theme.subtext; font.family: theme.font; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true } }
                Text { visible: modelData.protected === true; text: "protected"; color: theme.green; font.family: theme.font; font.pixelSize: 9 }
                Rectangle { visible: modelData.protected !== true; width: 82; height: 30; color: removeMouse.containsMouse ? theme.red : theme.bg; border.width: 1; border.color: theme.border
                    Text { anchors.centerIn: parent; text: "Uninstall"; color: theme.text; font.family: theme.font; font.pixelSize: 9 }
                    MouseArea { id: removeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { root.pendingId = modelData.id; root.pendingName = modelData.name; root.pendingSource = modelData.source } }
                }
            }
        } }
        Rectangle { visible: root.pendingId.length > 0; Layout.fillWidth: true; height: 64; color: theme.surface3; border.width: 1; border.color: theme.red
            RowLayout { anchors.fill: parent; anchors.margins: 10; Text { Layout.fillWidth: true; text: "Really uninstall " + root.pendingName + "?"; color: theme.text; font.family: theme.font; font.pixelSize: 11 }
                Rectangle { width: 70; height: 30; color: theme.bg; Text { anchors.centerIn: parent; text: "Cancel"; color: theme.text; font.family: theme.font } MouseArea { anchors.fill: parent; onClicked: root.pendingId = "" } }
                Rectangle { width: 80; height: 30; color: theme.red; Text { anchors.centerIn: parent; text: "Remove"; color: theme.text; font.family: theme.font } MouseArea { anchors.fill: parent; onClicked: { action.command = ["buchhwin-settings-backend", root.pendingSource === "RPM" ? "uninstall-rpm" : "uninstall-flatpak", root.pendingId]; action.running = true } } }
            }
        }
        Text { text: root.message; color: theme.blue; font.family: theme.font; font.pixelSize: 9 }
    }
}
