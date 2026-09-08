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
    color: Qt.rgba(0, 0, 0, 0.47 * reveal)
    exclusiveZone: 0
    aboveWindows: true
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.namespace: "buchhwin-keybinds"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property var bindings: [
        ["SUPER + ENTER", "Terminal"],
        ["SUPER + D", "Application launcher"],
        ["SUPER + B", "Brave browser"],
        ["SUPER + E", "Files (Dolphin)"],
        ["SUPER + C", "Visual Studio Code"],
        ["SUPER + SHIFT + C", "Control Center"],
        ["SUPER + S", "Region screenshot"],
        ["SUPER + SHIFT + S", "System settings"],
        ["SUPER + V", "Clipboard history"],
        ["SUPER + N", "Notifications"],
        ["SUPER + M", "Power menu"],
        ["SUPER + L", "Lock screen"],
        ["SUPER + F1", "Keybind viewer"],
        ["SUPER + Q", "Close focused window"],
        ["SUPER + J / K", "Focus next / previous window"],
        ["SUPER + LEFT / RIGHT", "Master area smaller / larger"],
        ["SUPER + UP / DOWN", "Top/bottom layout and resize"],
        ["SUPER + I", "Increase master window count"],
        ["SUPER + SHIFT + I", "Decrease master window count"],
        ["SUPER + SHIFT + ENTER", "Promote focused window to master"],
        ["SUPER + T", "Tiled layout"],
        ["SUPER + F", "Floating layout"],
        ["SUPER + SHIFT + M", "Monocle layout"],
        ["SUPER + SPACE", "Cycle layout"],
        ["SUPER + ALT + SPACE", "Switch side-by-side / top-and-bottom"],
        ["SUPER + SHIFT + SPACE", "Toggle focused window floating"],
        ["SUPER + SHIFT + F", "Fullscreen"],
        ["SUPER + 1..9", "Switch tag"],
        ["SUPER + SHIFT + 1..9", "Move window to tag"],
        ["SUPER + CTRL + 1..9", "Toggle tag"],
        ["SUPER + , / .", "Focus left / right monitor"],
        ["SUPER + SHIFT + , / .", "Move window to left / right monitor"],
        ["SUPER + PRINT", "Region screenshot"],
        ["SUPER + SHIFT + PRINT", "Fullscreen screenshot"],
        ["SUPER + CTRL + PRINT", "Screenshot editor"],
        ["SUPER + SHIFT + Q", "Quit dwl-buchhwin"]
    ]

    Shortcut { sequence: "Escape"; enabled: root.opened; onActivated: root.opened = false }

    Rectangle {
        anchors.fill: parent; color: "transparent"
        MouseArea { anchors.fill: parent; onClicked: root.opened = false }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(800, parent.width - 70)
        height: Math.min(740, parent.height - 90)
        opacity: root.reveal
        transform: Translate { y: (1 - root.reveal) * theme.lift }
        radius: 20
        color: theme.surface
        border.width: 1
        border.color: theme.border
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton }

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 20; spacing: 12
            RowLayout {
                Layout.fillWidth: true
                Text { font.family: theme.font; text: "Keyboard shortcuts"; color: theme.text; font.pixelSize: 22; font.bold: true }
                Item { Layout.fillWidth: true }
                Text { font.family: theme.font; text: "buchhwin"; color: theme.blue; font.bold: true }
            }
            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true; model: root.bindings; spacing: 5; clip: true
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width; height: 42; radius: 9
                    color: hover.containsMouse ? theme.surface3 : "transparent"
                    Behavior on color { ColorAnimation { duration: theme.durationFast } }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 14
                        Rectangle {
                            Layout.preferredWidth: 250; height: 28; radius: 7; color: theme.surface2
                            border.width: 1; border.color: theme.border
                            Text { font.family: theme.font; anchors.centerIn: parent; text: modelData[0]; color: theme.mauve; font.pixelSize: 11; font.bold: true }
                        }
                        Text { font.family: theme.font; Layout.fillWidth: true; text: modelData[1]; color: theme.text; font.pixelSize: 13 }
                    }
                    MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true }
                }
            }
            Text { font.family: theme.font; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: "Esc or click outside to close"; color: theme.subtext; font.pixelSize: 10 }
        }
    }
}
