import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    Theme { id: theme }
    property bool opened: false

    // Panels fade and lift instead of appearing instantly. `visible` has to
    // outlive `opened` so the closing animation can finish playing.
    property real reveal: opened ? 1.0 : 0.0
    Behavior on reveal {
        NumberAnimation {
            duration: theme.durationMedium
            easing.type: root.opened ? theme.easingEnter : theme.easingExit
        }
    }

    visible: opened || reveal > 0.001
    focusable: opened
    color: Qt.rgba(0, 0, 0, 0.53 * reveal)
    exclusiveZone: 0
    aboveWindows: true
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.namespace: "buchhwin-power-menu"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function run(command) {
        opened = false
        Quickshell.execDetached(command)
    }

    Shortcut { sequence: "Escape"; enabled: root.opened; onActivated: root.opened = false }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        MouseArea { anchors.fill: parent; onClicked: root.opened = false }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(680, parent.width - 80)
        height: 200
        opacity: root.reveal
        transform: Translate { y: (1 - root.reveal) * theme.lift }
        radius: 20
        color: theme.surface
        border.width: 1
        border.color: theme.border
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 16
            RowLayout {
                Layout.fillWidth: true
                Text { font.family: theme.font; text: "buchhwin"; color: theme.text; font.pixelSize: 22; font.bold: true }
                Item { Layout.fillWidth: true }
                Text { font.family: theme.font; text: "SUPER + M"; color: theme.subtext; font.pixelSize: 10 }
            }
            RowLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
                Repeater {
                    model: [
                        ["󰌾", "Lock", ["swaylock","-f","-c","11111b"]],
                        ["󰤄", "Suspend", ["systemctl","suspend"]],
                        ["󰍃", "Logout", ["pkill","-TERM","-x","dwl-buchhwin"]],
                        ["󰜉", "Reboot", ["systemctl","reboot"]],
                        ["󰐥", "Shutdown", ["systemctl","poweroff"]]
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; Layout.fillHeight: true; radius: 13
                        color: powerMouse.containsMouse ? theme.surface3 : theme.surface2
                        Behavior on color { ColorAnimation { duration: theme.durationFast } }
                        border.width: 1; border.color: powerMouse.containsMouse ? theme.blue : theme.border
                        Column {
                            anchors.centerIn: parent; spacing: 7
                            Text { font.family: theme.font; anchors.horizontalCenter: parent.horizontalCenter; text: modelData[0]; color: theme.blue; font.pixelSize: 24 }
                            Text { font.family: theme.font; anchors.horizontalCenter: parent.horizontalCenter; text: modelData[1]; color: theme.text; font.pixelSize: 11 }
                        }
                        MouseArea { id: powerMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.run(modelData[2]) }
                    }
                }
            }
        }
    }
}
