import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

GridLayout {
    id: root
    required property var hostWindow
    property bool vertical: false
    Theme { id: theme }
    columns: vertical ? 1 : 99
    rowSpacing: 2; columnSpacing: 2

    Repeater {
        model: SystemTray.items
        delegate: Rectangle {
            required property var modelData
            width: 30; height: 30; radius: 4
            color: trayMouse.containsMouse ? theme.surface3 : "transparent"
            visible: modelData.status !== Status.Passive
            Behavior on color { ColorAnimation { duration: theme.durationFast } }

            Image {
                anchors.centerIn: parent; width: 18; height: 18
                source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                sourceSize.width: 18; sourceSize.height: 18
                smooth: true
            }
            MouseArea {
                id: trayMouse; anchors.fill: parent; hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton) modelData.secondaryActivate()
                    else if (mouse.button === Qt.RightButton || modelData.onlyMenu)
                        modelData.display(root.hostWindow, mouse.x, mouse.y)
                    else modelData.activate()
                }
                onWheel: wheel => modelData.scroll(wheel.angleDelta.y, false)
            }
        }
    }
}
