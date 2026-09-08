import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    required property var service
    property bool opened: false
    Theme { id: theme }

    // The notification centre slides in from the right. `visible` has to
    // outlive `opened` so the closing animation can finish playing.
    property real reveal: opened ? 1.0 : 0.0
    Behavior on reveal {
        NumberAnimation {
            duration: theme.durationMedium
            easing.type: root.opened ? theme.easingEnter : theme.easingExit
        }
    }

    visible: opened || reveal > 0.001
    color: "transparent"
    focusable: opened
    exclusiveZone: 0
    implicitWidth: 430
    anchors { top: true; bottom: true; right: true }
    margins { top: theme.barPosition === "top" ? theme.barSize : 0; right: theme.barPosition === "right" ? theme.barSize : 0; bottom: theme.barPosition === "bottom" ? theme.barSize : 0 }
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "buchhwin-notifications"
    Shortcut { sequence: "Escape"; enabled: root.opened; onActivated: root.opened = false }

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: theme.surface
        border.width: 1
        border.color: theme.border
        opacity: root.reveal
        transform: Translate { x: (1 - root.reveal) * theme.slide }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text { font.family: theme.font; text: "Notifications"; color: theme.text; font.pixelSize: 20; font.bold: true }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 118; height: 30; radius: 9; color: service.doNotDisturb ? theme.blue : theme.surface2
                    Text { anchors.centerIn: parent; text: service.doNotDisturb ? "󰂛  DND on" : "󰂚  DND off"; color: service.doNotDisturb ? theme.bg : theme.subtext; font.family: theme.font; font.pixelSize: 10 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: service.doNotDisturb = !service.doNotDisturb }
                }
                Rectangle {
                    width: 88; height: 30; radius: 9; color: theme.surface2
                    Text { font.family: theme.font; anchors.centerIn: parent; text: "Clear all"; color: theme.subtext; font.pixelSize: 11 }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            const values = service.server.trackedNotifications.values
                            for (let i = values.length - 1; i >= 0; --i) values[i].dismiss()
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

            Text { font.family: theme.font;
                visible: service.server.trackedNotifications.values.length === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "No notifications"
                color: theme.subtext
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: service.server.trackedNotifications.values.length > 0
                clip: true
                spacing: 8
                model: service.server.trackedNotifications
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: Math.max(82, bodyText.implicitHeight + 54)
                    radius: 13
                    color: theme.surface2
                    border.width: 1
                    border.color: theme.border

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 5
                        RowLayout {
                            Layout.fillWidth: true
                            Text { font.family: theme.font; Layout.fillWidth: true; text: modelData.summary || modelData.appName || "Notification"; color: theme.text; font.bold: true; font.pixelSize: 13; elide: Text.ElideRight }
                            Text { font.family: theme.font; text: "󰅖"; color: theme.subtext; font.pixelSize: 14 }
                        }
                        Text { font.family: theme.font;
                            id: bodyText
                            Layout.fillWidth: true
                            text: modelData.body || ""
                            color: theme.subtext
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        onClicked: modelData.dismiss()
                    }
                }
            }
        }
    }
}
