import Quickshell
import QtQuick
import QtQuick.Layouts

Scope {
    id: root
    required property var service
    Theme { id: theme }
    property var current: service.latest
    property int seenGeneration: -1
    property bool showing: false

    // Popups slide in from the screen edge rather than blinking into place.
    // The window stays mapped until the closing animation has finished.
    property real reveal: (showing && current !== null) ? 1.0 : 0.0
    Behavior on reveal {
        NumberAnimation {
            duration: theme.durationSlow
            easing.type: root.showing ? theme.easingEnter : theme.easingExit
        }
    }

    Connections {
        target: service
        function onGenerationChanged() {
            root.current = service.latest
            root.seenGeneration = service.generation
            root.showing = root.current !== null && !service.doNotDisturb
            dismissTimer.restart()
        }
    }

    Timer {
        id: dismissTimer
        interval: 5500
        repeat: false
        onTriggered: root.showing = false
    }

    PanelWindow {
        visible: root.reveal > 0.001 && root.current !== null
        color: "transparent"
        implicitWidth: 390
        implicitHeight: 112
        exclusiveZone: 0
        anchors { top: true; right: true }
        margins { top: 42; right: 8 }

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: theme.surface
            border.width: 1
            border.color: theme.border
            opacity: root.reveal
            transform: Translate { x: (1 - root.reveal) * theme.slide }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12
                Image {
                    visible: root.current && (root.current.appIcon || "").length > 0
                    Layout.preferredWidth: 38; Layout.preferredHeight: 38
                    source: root.current ? Quickshell.iconPath(root.current.appIcon, root.current.appIcon) : ""
                    sourceSize.width: 38; sourceSize.height: 38
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Text { font.family: theme.font; Layout.fillWidth: true; text: root.current ? (root.current.summary || root.current.appName || "Notification") : ""; color: theme.text; font.bold: true; font.pixelSize: 14; elide: Text.ElideRight }
                    Text { font.family: theme.font; Layout.fillWidth: true; Layout.fillHeight: true; text: root.current ? (root.current.body || "") : ""; color: theme.subtext; font.pixelSize: 11; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight; textFormat: Text.PlainText }
                }
                Text { font.family: theme.font; text: "󰅖"; color: theme.subtext; font.pixelSize: 15 }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: root.showing = false
            }
        }
    }
}
