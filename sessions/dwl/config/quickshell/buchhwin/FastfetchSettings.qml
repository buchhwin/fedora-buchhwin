import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Rectangle {
    id: panel
    signal chooseStarted()
    signal chooseFinished()
    property string imagePath: ""
    property string imageUrl: ""
    property string message: ""
    implicitHeight: 165
    color: theme.surface2
    border.width: 1
    border.color: theme.border
    Theme { id: theme }
    function refresh() { if (!reader.running) reader.running = true }
    function readState(text) {
        try {
            const state = JSON.parse(text)
            imagePath = state.path
            imageUrl = state.url
        } catch (error) { message = "Could not read Fastfetch image" }
    }
    Component.onCompleted: refresh()
    Process {
        id: reader
        command: ["buchhwin-fastfetch-image", "get"]
        stdout: StdioCollector { onStreamFinished: panel.readState(text) }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) panel.message = text.trim() }
    }
    Process {
        id: chooser
        property string selectedPath: ""
        command: ["zenity", "--file-selection", "--title=Choose a Fastfetch image", "--file-filter=Images | *.png *.jpg *.jpeg *.webp *.bmp"]
        stdout: StdioCollector { onStreamFinished: chooser.selectedPath = text.trim() }
        onExited: (code, status) => {
            if (code === 0 && selectedPath.length) {
                writer.command = ["buchhwin-fastfetch-image", "set", selectedPath]
                writer.running = true
            }
            panel.chooseFinished()
        }
    }
    Process {
        id: writer
        stderr: StdioCollector { onStreamFinished: if (text.trim()) panel.message = text.trim() }
        onExited: (code, status) => {
            if (code === 0) panel.message = "Saved — open a new terminal to see it"
            else if (!panel.message.length) panel.message = "Could not save image"
            panel.refresh()
        }
    }
    RowLayout {
        anchors.fill: parent; anchors.margins: 12; spacing: 14
        Rectangle {
            Layout.preferredWidth: 190; Layout.fillHeight: true
            color: theme.bg; clip: true
            Image { anchors.fill: parent; source: panel.imageUrl; fillMode: Image.PreserveAspectFit; asynchronous: true }
        }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 7
            Text { text: "Fastfetch image"; font.family: theme.font; font.pixelSize: 14; font.bold: true; color: theme.text }
            Text { Layout.fillWidth: true; text: panel.imagePath.length ? panel.imagePath.split("/").pop() : "No image selected"; elide: Text.ElideMiddle; font.family: theme.font; font.pixelSize: 9; color: theme.subtext }
            Text { Layout.fillWidth: true; text: panel.message; wrapMode: Text.WordWrap; font.family: theme.font; font.pixelSize: 9; color: theme.blue }
            Item { Layout.fillHeight: true }
            Rectangle {
                Layout.preferredWidth: 130; Layout.preferredHeight: 36
                color: mouse.containsMouse ? theme.surface3 : theme.bg
                border.width: 1; border.color: theme.border
                Text { anchors.centerIn: parent; text: "Choose image"; font.family: theme.font; font.pixelSize: 10; color: theme.text }
                MouseArea {
                    id: mouse; anchors.fill: parent; hoverEnabled: true
                    enabled: !chooser.running && !writer.running
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        panel.message = ""
                        chooser.selectedPath = ""
                        panel.chooseStarted()
                        chooser.running = true
                    }
                }
            }
        }
    }
}
