import QtQuick
import QtQuick.Layouts

Rectangle {
    id: panel
    property var state: ({})
    property var fonts: []
    signal setValue(string key, var value)
    implicitHeight: 405
    color: theme.surface2
    border.width: 1
    border.color: theme.border
    Theme { id: theme }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 14; spacing: 9
        Text { text: "dwl theme"; color: theme.text; font.family: theme.font; font.pixelSize: 14; font.bold: true }
        Text { text: "These settings affect only the buchhwin dwl session."; color: theme.subtext; font.family: theme.font; font.pixelSize: 9 }

        Rectangle {
            Layout.fillWidth: true; height: 42; radius: 7
            color: panel.state.background || theme.bg; border.width: 1; border.color: theme.border
            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 18; color: panel.state.bar || theme.surface
                Text { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: "1  2  3    Theme preview"; color: panel.state.text || theme.text; font.family: panel.state.font || theme.font; font.pixelSize: 8 }
                Rectangle { anchors.right: parent.right; anchors.rightMargin: 7; anchors.verticalCenter: parent.verticalCenter; width: 7; height: 7; radius: 4; color: panel.state.accent || theme.blue }
            }
        }

        Text { text: "Preset"; color: theme.subtext; font.family: theme.font; font.pixelSize: 9 }
        RowLayout {
            Layout.fillWidth: true; spacing: 7
            Repeater {
                model: [["Graphite", "graphite"], ["Blue", "blue"], ["Purple", "purple"], ["Green", "green"]]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true; height: 34; radius: 5
                    color: panel.state.theme === modelData[1] ? theme.blue : theme.bg
                    Text { anchors.centerIn: parent; text: modelData[0]; color: panel.state.theme === modelData[1] ? theme.bg : theme.text; font.family: theme.font; font.pixelSize: 10 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: panel.setValue("theme", modelData[1]) }
                }
            }
        }

        Text { text: "Font (Nerd Fonts keep all bar icons available)"; color: theme.subtext; font.family: theme.font; font.pixelSize: 9 }
        Flickable {
            Layout.fillWidth: true; height: 38; contentWidth: fontRow.implicitWidth; clip: true
            Row {
                id: fontRow; spacing: 7
                Repeater {
                    model: panel.fonts
                    delegate: Rectangle {
                        required property string modelData
                        width: Math.min(220, fontName.implicitWidth + 22); height: 36; radius: 5
                        color: panel.state.font === modelData ? theme.blue : theme.bg
                        Text { id: fontName; anchors.centerIn: parent; text: modelData; color: panel.state.font === modelData ? theme.bg : theme.text; font.family: modelData; font.pixelSize: 10 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: panel.setValue("font", modelData) }
                    }
                }
            }
        }

        Text { text: "Bar position"; color: theme.subtext; font.family: theme.font; font.pixelSize: 9 }
        RowLayout {
            Layout.fillWidth: true; spacing: 7
            Repeater {
                model: ["top", "bottom", "left", "right"]
                delegate: Rectangle {
                    required property string modelData
                    Layout.fillWidth: true; height: 32; radius: 5
                    color: panel.state.barPosition === modelData ? theme.blue : theme.bg
                    Text { anchors.centerIn: parent; text: modelData; color: panel.state.barPosition === modelData ? theme.bg : theme.text; font.family: theme.font; font.pixelSize: 10 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: panel.setValue("barPosition", modelData) }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text { text: "Bar size"; color: theme.subtext; font.family: theme.font; font.pixelSize: 9 }
            ValueSlider { Layout.fillWidth: true; from: 34; to: 64; value: panel.state.barSize || 38; onValueEdited: value => panel.setValue("barSize", Math.round(value)) }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 7
            Repeater {
                model: [["Accent", "accent"], ["Desktop", "background"], ["Bar", "bar"], ["Text", "text"]]
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true; spacing: 3
                    Text { text: modelData[0]; color: theme.subtext; font.family: theme.font; font.pixelSize: 9 }
                    Rectangle {
                        Layout.fillWidth: true; height: 32; color: theme.bg; border.width: 1; border.color: theme.border
                        Rectangle { anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; radius: 3; color: panel.state[modelData[1]] || "#000000" }
                        TextInput {
                            anchors.left: parent.left; anchors.leftMargin: 26; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            text: panel.state[modelData[1]] || ""; color: theme.text; font.family: theme.font; font.pixelSize: 10
                            selectByMouse: true
                            onEditingFinished: panel.setValue(modelData[1], text)
                        }
                    }
                }
            }
        }
    }
}
