import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Native Bluetooth management on top of buchhwin-btctl, replacing blueman.
PanelWindow {
    id: root
    Theme { id: theme }

    property bool opened: false
    property bool powered: false
    property bool discovering: false
    property string status: ""
    property var devices: []

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
    WlrLayershell.namespace: "buchhwin-bluetooth"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    function refresh() {
        if (!statusProc.running) statusProc.running = true
        if (!listProc.running) listProc.running = true
    }

    function run(args, message) {
        root.status = message
        actionProc.command = args
        actionProc.running = true
    }

    onOpenedChanged: {
        if (opened) {
            root.status = ""
            refresh()
        }
    }

    Shortcut { sequence: "Escape"; enabled: root.opened; onActivated: root.opened = false }

    Process {
        id: statusProc
        command: ["buchhwin-btctl", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("|")
                root.powered = parts[0] === "yes"
                root.discovering = parts.length > 1 && parts[1] === "yes"
            }
        }
    }

    Process {
        id: listProc
        command: ["buchhwin-btctl", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = []
                const lines = text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim()
                    if (line.length === 0) continue
                    const f = line.split("|")
                    if (f.length < 4) continue
                    found.push({
                        mac: f[0], name: f[1],
                        paired: f[2] === "yes", connected: f[3] === "yes"
                    })
                }
                // Connected first, then paired, then the rest.
                found.sort((a, b) => {
                    const rank = d => d.connected ? 0 : (d.paired ? 1 : 2)
                    const diff = rank(a) - rank(b)
                    return diff !== 0 ? diff : a.name.localeCompare(b.name)
                })
                root.devices = found
            }
        }
    }

    Process {
        id: actionProc
        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim()
                if (message.length > 0) root.status = message
            }
        }
        onExited: exitCode => {
            if (exitCode === 0 && root.status.indexOf("...") > 0) root.status = "Done"
            root.refresh()
        }
    }

    // Discovery runs for a bounded time and exits by itself, so closing the
    // panel never leaves a scan running in the background.
    Process { id: scanProc; command: ["buchhwin-btctl", "scan", "12"]; onExited: root.refresh() }

    Timer { interval: 4000; running: root.opened; repeat: true; onTriggered: root.refresh() }

    MouseArea { anchors.fill: parent; onClicked: root.opened = false }

    Rectangle {
        anchors { top: parent.top; right: parent.right }
        anchors.topMargin: theme.barPosition === "top" ? theme.barSize : 12
        anchors.rightMargin: 12
        width: Math.min(500, parent.width - 24)
        height: Math.min(560, parent.height - 58)
        radius: 14
        opacity: root.reveal
        transform: Translate { y: -(1 - root.reveal) * theme.lift }
        color: theme.surface
        border.width: 1
        border.color: theme.border
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text { font.family: theme.font; text: "󰂯  Bluetooth"; color: theme.text; font.pixelSize: 19; font.bold: true }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 76; height: 30
                    color: root.powered ? theme.surface3 : theme.surface2
                    border.width: 1; border.color: root.powered ? theme.blue : theme.border
                    Text { font.family: theme.font; anchors.centerIn: parent; text: root.powered ? "On" : "Off"; color: root.powered ? theme.blue : theme.subtext; font.pixelSize: 11 }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.run(["buchhwin-btctl", "power", root.powered ? "off" : "on"], "")
                    }
                }
                Rectangle {
                    width: 76; height: 30
                    enabled: root.powered
                    opacity: root.powered ? 1.0 : 0.4
                    color: root.discovering ? theme.surface3 : theme.surface2
                    border.width: 1; border.color: theme.border
                    Text { font.family: theme.font; anchors.centerIn: parent; text: root.discovering ? "Scanning" : "Scan"; color: theme.text; font.pixelSize: 11 }
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.powered && !scanProc.running
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.status = "Scanning for devices..."; scanProc.running = true }
                    }
                }
                Rectangle {
                    width: 30; height: 30
                    color: btCloseMouse.containsMouse ? theme.surface3 : theme.surface2
                    Behavior on color { ColorAnimation { duration: theme.durationFast } }
                    Text { font.family: theme.font; anchors.centerIn: parent; text: "󰅖"; color: theme.subtext }
                    MouseArea { id: btCloseMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.opened = false }
                }
            }

            Text {
                font.family: theme.font
                Layout.fillWidth: true
                visible: root.status.length > 0
                text: root.status
                color: theme.subtext
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: root.devices
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: 52
                    color: theme.surface2
                    border.width: 1
                    border.color: modelData.connected ? theme.blue : theme.border

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 10

                        Text {
                            font.family: theme.font
                            text: modelData.connected ? "󰂱" : (modelData.paired ? "󰂯" : "󰂲")
                            color: modelData.connected ? theme.blue : theme.subtext
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { font.family: theme.font; Layout.fillWidth: true; text: modelData.name; color: theme.text; elide: Text.ElideRight; font.pixelSize: 12; font.bold: modelData.connected }
                            Text { font.family: theme.font; Layout.fillWidth: true; text: modelData.mac + (modelData.paired ? "  ·  paired" : ""); color: theme.subtext; font.pixelSize: 9 }
                        }

                        Rectangle {
                            width: 84; height: 28
                            color: primaryMouse.containsMouse ? theme.surface3 : theme.bg
                            Behavior on color { ColorAnimation { duration: theme.durationFast } }
                            border.width: 1; border.color: theme.border
                            Text {
                                font.family: theme.font
                                anchors.centerIn: parent
                                text: modelData.connected ? "Disconnect" : (modelData.paired ? "Connect" : "Pair")
                                color: theme.text
                                font.pixelSize: 9
                            }
                            MouseArea {
                                id: primaryMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.connected)
                                        root.run(["buchhwin-btctl", "disconnect", modelData.mac], "Disconnecting " + modelData.name + "...")
                                    else if (modelData.paired)
                                        root.run(["buchhwin-btctl", "connect", modelData.mac], "Connecting " + modelData.name + "...")
                                    else
                                        root.run(["buchhwin-btctl", "pair", modelData.mac], "Pairing " + modelData.name + "...")
                                }
                            }
                        }

                        Rectangle {
                            width: 28; height: 28
                            visible: modelData.paired
                            color: forgetMouse.containsMouse ? theme.surface3 : theme.bg
                            Behavior on color { ColorAnimation { duration: theme.durationFast } }
                            border.width: 1; border.color: theme.border
                            Text { font.family: theme.font; anchors.centerIn: parent; text: "󰩹"; color: theme.subtext; font.pixelSize: 12 }
                            MouseArea {
                                id: forgetMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.run(["buchhwin-btctl", "remove", modelData.mac], "Forgetting " + modelData.name + "...")
                            }
                        }
                    }
                }
            }

            Text {
                font.family: theme.font
                Layout.fillWidth: true
                visible: root.devices.length === 0
                text: root.powered ? "No devices yet. Press Scan and put the device into pairing mode."
                                   : "Bluetooth is switched off."
                color: theme.subtext
                wrapMode: Text.WordWrap
                font.pixelSize: 10
            }
        }
    }
}
