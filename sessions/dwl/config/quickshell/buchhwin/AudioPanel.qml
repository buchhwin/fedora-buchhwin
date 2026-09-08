import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Native audio routing and per-application volume on top of buchhwin-audioctl,
// replacing pavucontrol.
PanelWindow {
    id: root
    Theme { id: theme }

    property bool opened: false
    required property var audioState
    property int tab: 0
    property var sinks: []
    property var sources: []
    property var streams: []
    property var pendingAction: null

    readonly property var tabs: ["Outputs", "Inputs", "Applications"]

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
    WlrLayershell.namespace: "buchhwin-audio"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    function parseDevices(text) {
        const found = []
        const lines = text.split("\n")
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim()
            if (line.length === 0) continue
            const f = line.split("|")
            if (f.length < 5) continue
            found.push({
                name: f[0], description: f[1], volume: f[2],
                muted: f[3] === "yes", isDefault: f[4] === "yes"
            })
        }
        return found
    }

    function refresh() {
        if (!sinkProc.running) sinkProc.running = true
        if (!sourceProc.running) sourceProc.running = true
        if (!streamProc.running) streamProc.running = true
    }

    function run(args) {
        pendingAction = args
        actionDelay.restart()
    }

    function flushAction() {
        if (actionProc.running) { actionDelay.restart(); return }
        if (!pendingAction) return
        actionProc.command = pendingAction
        pendingAction = null
        actionProc.running = true
    }

    onOpenedChanged: if (opened) refresh()
    Shortcut { sequence: "Escape"; enabled: root.opened; onActivated: root.opened = false }

    Process {
        id: sinkProc
        command: ["buchhwin-audioctl", "sinks"]
        stdout: StdioCollector { onStreamFinished: root.sinks = root.parseDevices(text) }
    }

    Process {
        id: sourceProc
        command: ["buchhwin-audioctl", "sources"]
        stdout: StdioCollector { onStreamFinished: root.sources = root.parseDevices(text) }
    }

    Process {
        id: streamProc
        command: ["buchhwin-audioctl", "streams"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = []
                const lines = text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim()
                    if (line.length === 0) continue
                    const f = line.split("|")
                    if (f.length < 4) continue
                    found.push({ id: f[0], name: f[1], volume: f[2], muted: f[3] === "yes" })
                }
                root.streams = found
            }
        }
    }

    Process { id: actionProc; onExited: { root.refresh(); root.audioState.refresh(); if (root.pendingAction) actionDelay.restart() } }
    Timer { id: actionDelay; interval: 70; onTriggered: root.flushAction() }

    Timer { interval: 2500; running: root.opened; repeat: true; onTriggered: root.refresh() }

    MouseArea { anchors.fill: parent; onClicked: root.opened = false }

    Rectangle {
        anchors { top: parent.top; right: parent.right }
        anchors.topMargin: theme.barPosition === "top" ? theme.barSize : 12
        anchors.rightMargin: 12
        width: Math.min(520, parent.width - 24)
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
                Text { font.family: theme.font; text: "󰕾  Sound"; color: theme.text; font.pixelSize: 19; font.bold: true }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 30; height: 30
                    color: audioCloseMouse.containsMouse ? theme.surface3 : theme.surface2
                    Behavior on color { ColorAnimation { duration: theme.durationFast } }
                    Text { font.family: theme.font; anchors.centerIn: parent; text: "󰅖"; color: theme.subtext }
                    MouseArea { id: audioCloseMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.opened = false }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: root.tabs
                    delegate: Rectangle {
                        required property string modelData
                        required property int index
                        Layout.fillWidth: true
                        height: 30
                        color: root.tab === index ? theme.surface3 : theme.surface2
                        border.width: 1
                        border.color: root.tab === index ? theme.blue : theme.border
                        Text {
                            font.family: theme.font
                            anchors.centerIn: parent
                            text: modelData
                            color: root.tab === index ? theme.blue : theme.subtext
                            font.pixelSize: 11
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.tab = index }
                    }
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 5
                model: root.tab === 0 ? root.sinks : (root.tab === 1 ? root.sources : root.streams)

                delegate: Rectangle {
                    required property var modelData
                    // Applications have no default device to select, so the
                    // row is inert apart from its volume controls.
                    readonly property bool isDevice: root.tab !== 2
                    readonly property string label: isDevice ? modelData.description : modelData.name
                    readonly property string target: isDevice ? modelData.name : modelData.id
                    readonly property string kind: root.tab === 0 ? "sink" : (root.tab === 1 ? "source" : "stream")
                    readonly property int volumeValue: Math.max(0, parseInt(modelData.volume) || 0)
                    property int dragVolume: volumeValue
                    property bool volumeDragging: false
                    Timer { interval: 600; running: volumeDragging; onTriggered: volumeDragging = false }

                    width: ListView.view.width
                    height: 76
                    color: theme.surface2
                    border.width: 1
                    border.color: isDevice && modelData.isDefault ? theme.blue : theme.border

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        spacing: 5

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                font.family: theme.font
                                Layout.fillWidth: true
                                text: label
                                color: isDevice && modelData.isDefault ? theme.blue : theme.text
                                font.bold: isDevice && modelData.isDefault
                                elide: Text.ElideRight
                                font.pixelSize: 12
                            }
                            Text {
                                font.family: theme.font
                                text: modelData.muted ? "muted" : modelData.volume
                                color: modelData.muted ? theme.subtext : theme.blue
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle {
                                visible: isDevice
                                width: 92; height: 24
                                color: modelData.isDefault ? theme.surface3 : theme.bg
                                border.width: 1
                                border.color: modelData.isDefault ? theme.blue : theme.border
                                Text {
                                    font.family: theme.font
                                    anchors.centerIn: parent
                                    text: modelData.isDefault ? "Default" : "Set default"
                                    color: modelData.isDefault ? theme.blue : theme.subtext
                                    font.pixelSize: 9
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    z: 20
                                    preventStealing: true
                                    enabled: isDevice && !modelData.isDefault
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.run(["buchhwin-audioctl", "default-" + kind, target])
                                }
                            }

                            ValueSlider {
                                id: deviceVolume
                                Layout.fillWidth: true
                                from: 0; to: 150
                                value: volumeDragging ? dragVolume : volumeValue
                                accent: theme.blue
                                onValueEdited: newValue => {
                                    dragVolume = newValue
                                    volumeDragging = true
                                    root.run(["buchhwin-audioctl", kind + "-volume", target, dragVolume + "%"])
                                }
                            }
                            Text {
                                font.family: theme.font; text: modelData.muted ? "󰝟" : "󰕾"
                                color: modelData.muted ? theme.red : theme.subtext; font.pixelSize: 15
                                MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: root.run(["buchhwin-audioctl", kind + "-mute", target]) }
                            }
                        }
                    }
                }
            }

            Text {
                font.family: theme.font
                Layout.fillWidth: true
                visible: (root.tab === 2 && root.streams.length === 0)
                text: "No application is playing audio."
                color: theme.subtext
                font.pixelSize: 10
            }
        }
    }
}
