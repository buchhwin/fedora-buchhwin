import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

PanelWindow {
    id: root
    Theme { id: theme }
    required property var mediaState
    property bool opened: false
    property var player: mediaState.player
    property real reveal: opened ? 1 : 0
    property real recordAngle: 0
    Behavior on reveal { NumberAnimation { duration: theme.durationMedium } }
    visible: opened || reveal > 0.001
    focusable: opened; exclusiveZone: 0; aboveWindows: true
    color: Qt.rgba(0, 0, 0, 0.30 * reveal)
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.namespace: "buchhwin-media"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    Shortcut { sequence: "Escape"; enabled: opened; onActivated: opened = false }
    MouseArea { anchors.fill: parent; onClicked: root.opened = false }

    Rectangle {
        anchors.top: parent.top; anchors.right: parent.right
        anchors.topMargin: theme.barPosition === "top" ? theme.barSize : 12; anchors.rightMargin: theme.barPosition === "right" ? theme.barSize + 12 : 12
        width: Math.min(560, parent.width - 24); height: 286; radius: 16
        color: theme.surface; border.width: 1; border.color: theme.border; opacity: root.reveal
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton }
        RowLayout {
            anchors.fill: parent; anchors.margins: 18; spacing: 20
            Rectangle {
                Layout.preferredWidth: 174; Layout.preferredHeight: 174; radius: 87
                color: theme.bg; clip: true; border.width: 3; border.color: theme.surface3
                Image {
                    id: coverSource; anchors.fill: parent; anchors.margins: 7; fillMode: Image.PreserveAspectCrop
                    source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""; asynchronous: true
                }
                Rectangle { id: coverMask; anchors.fill: parent; anchors.margins: 7; radius: width / 2; color: "white" }
                ShaderEffectSource { id: coverTexture; sourceItem: coverSource; hideSource: true; live: true }
                ShaderEffectSource { id: maskTexture; sourceItem: coverMask; hideSource: true; live: true }
                MultiEffect {
                    id: recordCover; anchors.fill: parent; anchors.margins: 7
                    source: coverTexture; maskEnabled: true; maskSource: maskTexture
                    rotation: root.recordAngle
                }
                Timer {
                    interval: 16; repeat: true
                    running: root.opened && root.player && root.player.isPlaying
                    onTriggered: root.recordAngle = (root.recordAngle + 360 * interval / theme.durationRecord) % 360
                }
                Rectangle { anchors.centerIn: parent; width: 30; height: 30; radius: 15; color: theme.surface; border.width: 2; border.color: theme.border }
                Text { anchors.centerIn: parent; visible: coverSource.status !== Image.Ready; text: "󰎈"; color: theme.subtext; font.family: theme.font; font.pixelSize: 40 }
            }
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
                RowLayout { Layout.fillWidth: true; spacing: 5
                    Flickable { Layout.fillWidth: true; height: 32; contentWidth: playerChoices.implicitWidth; clip: true
                        Row { id: playerChoices; spacing: 5
                            Repeater { model: root.mediaState.players; delegate: Rectangle { required property var modelData
                                width: Math.min(140, playerName.implicitWidth + 20); height: 30; radius: 7
                                color: root.player === modelData ? theme.blue : playerMouse.containsMouse ? theme.surface3 : theme.bg
                                Text { id: playerName; anchors.centerIn: parent; text: modelData.identity || "Player"; color: root.player === modelData ? theme.bg : theme.text; font.family: theme.font; font.pixelSize: 9; elide: Text.ElideRight }
                                MouseArea { id: playerMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.mediaState.select(modelData.identity) }
                            } }
                        }
                    }
                    Rectangle { width: 34; height: 30; radius: 7; color: openAppMouse.containsMouse ? theme.surface3 : theme.bg; border.width: 1; border.color: theme.border
                        Text { anchors.centerIn: parent; text: "󰏌"; color: theme.text; font.family: theme.font; font.pixelSize: 15 }
                        MouseArea { id: openAppMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player) Quickshell.execDetached(["buchhwin-media-player", "open", root.player.identity]) }
                    }
                }
                Item { Layout.fillHeight: true }
                Text { Layout.fillWidth: true; text: root.player ? (root.player.trackTitle || "Unknown title") : "Nothing playing"; color: theme.text; font.family: theme.font; font.pixelSize: 15; font.bold: true; elide: Text.ElideRight; maximumLineCount: 1 }
                Text { Layout.fillWidth: true; text: root.player ? (root.player.trackArtist || root.player.identity || "") : ""; color: theme.subtext; font.family: theme.font; font.pixelSize: 10; elide: Text.ElideRight }
                RowLayout {
                    Layout.fillWidth: true; spacing: 9
                    Repeater {
                        model: [["󰒮", "previous"], ["󰓛", "stop"], [root.player && root.player.isPlaying ? "󰏤" : "󰐊", "play"], ["󰒭", "next"]]
                        delegate: Rectangle {
                            required property var modelData; width: modelData[1] === "play" ? 48 : 40; height: width; radius: width / 2
                            color: transportMouse.containsMouse ? theme.surface3 : theme.surface2; border.width: 1; border.color: theme.border
                            Text { anchors.centerIn: parent; text: modelData[0]; color: theme.text; font.family: theme.font; font.pixelSize: modelData[1] === "play" ? 20 : 16 }
                            MouseArea { id: transportMouse; anchors.fill: parent; hoverEnabled: true; onClicked: {
                                if (!root.player) return
                                if (modelData[1] === "previous" && root.player.canGoPrevious) root.player.previous()
                                else if (modelData[1] === "next" && root.player.canGoNext) root.player.next()
                                else if (modelData[1] === "play" && root.player.canTogglePlaying) root.player.togglePlaying()
                                else if (modelData[1] === "stop") root.player.stop()
                            } }
                        }
                    }
                }
                Text { text: root.player ? root.player.identity : ""; color: theme.subtext; font.family: theme.font; font.pixelSize: 9 }
                Item { Layout.fillHeight: true }
            }
        }
    }
}
