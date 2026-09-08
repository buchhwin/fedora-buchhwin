import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    Theme { id: theme }

    property bool opened: false
    property string query: ""
    property var entries: []
    property var filteredEntries: entries.filter(entry => entry.toLowerCase().includes(query.toLowerCase()))

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
    WlrLayershell.namespace: "buchhwin-clipboard"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function reload() {
        if (!listProc.running) listProc.running = true
    }
    function close() {
        opened = false
        query = ""
    }
    function copy(entry) {
        Quickshell.execDetached(["buchhwin-clipboard", "copy", entry])
        close()
    }

    onOpenedChanged: if (opened) {
        query = ""
        reload()
        search.forceActiveFocus()
    }
    Shortcut { sequence: "Escape"; enabled: root.opened; onActivated: root.close() }

    Process {
        id: listProc
        command: ["buchhwin-clipboard", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.entries = text.trim().length ? text.trim().split("\n") : []
        }
    }

    MouseArea { anchors.fill: parent; onClicked: root.close() }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(620, parent.width - 48)
        height: Math.min(520, parent.height - 96)
        opacity: root.reveal
        transform: Translate { y: (1 - root.reveal) * theme.lift }
        color: theme.surface
        border.width: 1
        border.color: theme.border

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Text { font.family: theme.font; text: "Clipboard history"; color: theme.text; font.pixelSize: 18; font.bold: true }
                Item { Layout.fillWidth: true }
                Text { font.family: theme.font; text: "SUPER + V"; color: theme.subtext; font.pixelSize: 10 }
            }

            Rectangle {
                Layout.fillWidth: true; height: 42
                color: theme.surface2; border.width: 1; border.color: search.activeFocus ? theme.text : theme.border
                TextInput { font.family: theme.font;
                    id: search
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: theme.text; selectionColor: theme.text; selectedTextColor: theme.bg
                    font.pixelSize: 14
                    onTextChanged: root.query = text
                    Keys.onEscapePressed: root.close()
                    Keys.onReturnPressed: if (root.filteredEntries.length) root.copy(root.filteredEntries[0])
                }
                Text { font.family: theme.font; anchors.fill: search; verticalAlignment: Text.AlignVCenter; text: "Search copied text…"; color: theme.subtext; visible: !search.text.length }
            }

            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true
                model: root.filteredEntries
                spacing: 5; clip: true
                delegate: Rectangle {
                    required property string modelData
                    width: ListView.view.width; height: 46
                    color: entryMouse.containsMouse ? theme.surface3 : theme.surface2
                    Behavior on color { ColorAnimation { duration: theme.durationFast } }
                    Text { font.family: theme.font;
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                        verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                        text: modelData.includes("\t") ? modelData.split("\t").slice(1).join("\t") : modelData
                        color: theme.text; font.pixelSize: 12
                    }
                    MouseArea { id: entryMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.copy(modelData) }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { font.family: theme.font; text: root.entries.length + " saved items"; color: theme.subtext; font.pixelSize: 11 }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 105; height: 34; color: clearMouse.containsMouse ? theme.surface3 : theme.surface2
                    Text { font.family: theme.font; anchors.centerIn: parent; text: "Clear history"; color: theme.text; font.pixelSize: 11 }
                    MouseArea { id: clearMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { Quickshell.execDetached(["buchhwin-clipboard", "wipe"]); root.entries = [] } }
                }
            }
        }
    }
}
