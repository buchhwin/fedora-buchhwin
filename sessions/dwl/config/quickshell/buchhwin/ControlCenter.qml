import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PanelWindow {
    id: root
    Theme { id: theme }

    property bool opened: false
    required property var audioState
    required property var mediaState
    property string wifiText: "offline"
    property bool wifiEnabled: false
    property bool wifiConnected: false
    property string bluetoothText: "off"
    property bool bluetoothEnabled: false
    property string brightnessText: "--"
    property int pendingBrightness: 50
    property int pendingMasterVolume: 0
    property bool volumeDragging: false
    property bool brightnessDragging: false
    property var player: mediaState.player

    function batteryStatus() {
        const device = UPower.displayDevice
        const charging = device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.PendingCharge
        const seconds = charging ? device.timeToFull : device.timeToEmpty
        let label = charging ? "Charging" : device.state === UPowerDeviceState.FullyCharged ? "Fully charged" : "On battery"
        if (seconds > 60) {
            const hours = Math.floor(seconds / 3600)
            const minutes = Math.round((seconds % 3600) / 60)
            label += "  ·  " + (hours > 0 ? hours + " h " : "") + minutes + " min " + (charging ? "until full" : "remaining")
        }
        return label
    }

    // Full management lives in dedicated panels rather than in external
    // programs; shell.qml wires these up.
    property var networkPanel: null
    property var bluetoothPanel: null
    property var audioPanel: null

    function openPanel(panel) {
        if (!panel) return
        root.opened = false
        if (networkPanel && panel !== networkPanel) networkPanel.opened = false
        if (bluetoothPanel && panel !== bluetoothPanel) bluetoothPanel.opened = false
        if (audioPanel && panel !== audioPanel) audioPanel.opened = false
        panel.opened = true
    }

    // The Control Center slides in from the edge it is anchored to. `visible`
    // has to outlive `opened` so the closing animation can finish playing.
    property real reveal: opened ? 1.0 : 0.0
    Behavior on reveal {
        NumberAnimation {
            duration: theme.durationMedium
            easing.type: root.opened ? theme.easingEnter : theme.easingExit
        }
    }

    visible: opened || reveal > 0.001
    focusable: opened
    color: Qt.rgba(0, 0, 0, 0.33 * reveal)
    exclusiveZone: 0
    aboveWindows: true
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.namespace: "buchhwin-control-center"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    function run(args) {
        if (args.length > 0 && args[0] === "wpctl") root.audioState.run(args)
        else Quickshell.execDetached(args)
        refreshTimer.restart()
    }

    function refresh() {
        root.audioState.refresh()
        if (!wifiProc.running) wifiProc.running = true
        if (!bluetoothProc.running) bluetoothProc.running = true
        if (!brightnessProc.running) brightnessProc.running = true
    }

    onOpenedChanged: if (opened) refresh()
    Shortcut { sequence: "Escape"; enabled: root.opened; onActivated: root.opened = false }

    Process {
        id: wifiProc
        command: ["sh", "-c", "export LC_ALL=C; radio=$(nmcli -g WIFI general 2>/dev/null | head -n1); dev=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | awk -F: '$2==\"wifi\" && $3==\"connected\" {print $1; exit}'); if [ -n \"$dev\" ]; then ssid=$(nmcli -t -f IN-USE,SSID device wifi list ifname \"$dev\" --rescan no 2>/dev/null | sed -n 's/^\\*://p' | head -n1); [ -n \"$ssid\" ] || ssid=$(nmcli -g GENERAL.CONNECTION device show \"$dev\" 2>/dev/null | head -n1); connected=yes; else ssid=; connected=no; fi; printf '%s|%s|%s\\n' \"$radio\" \"$connected\" \"$ssid\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split("|")
                root.wifiEnabled = p[0] === "enabled"
                root.wifiConnected = p.length > 1 && p[1] === "yes"
                root.wifiText = !root.wifiEnabled ? "Wi-Fi off" : root.wifiConnected && p.length > 2 && p[2].length ? p.slice(2).join("|").replace("\\:", ":") : "Not connected"
            }
        }
    }

    Process {
        id: bluetoothProc
        command: ["sh", "-c", "p=$(bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2; exit}'); c=$(bluetoothctl devices Connected 2>/dev/null | sed 's/^Device [^ ]* //' | paste -sd ', ' -); printf '%s|%s\\n' \"$p\" \"$c\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split("|")
                root.bluetoothEnabled = p[0] === "yes"
                root.bluetoothText = p.length > 1 && p[1].length ? p[1] : (root.bluetoothEnabled ? "on" : "off")
            }
        }
    }

    Process {
        id: brightnessProc
        command: ["sh", "-c", "brightnessctl -m 2>/dev/null | awk -F, 'NR==1 {print $4}'"]
        stdout: StdioCollector { onStreamFinished: { const v = text.trim(); root.brightnessText = v.length ? v : "--" } }
    }

    Timer {
        id: refreshTimer
        interval: 800
        repeat: false
        onTriggered: {
            root.volumeDragging = false
            root.brightnessDragging = false
            root.refresh()
        }
    }
    Timer {
        id: volumeDelay
        interval: 60
        onTriggered: {
            root.audioState.run(["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", root.pendingMasterVolume + "%"])
            refreshTimer.restart()
        }
    }
    Timer {
        id: brightnessDelay
        interval: 80
        onTriggered: {
            Quickshell.execDetached(["brightnessctl", "set", root.pendingBrightness + "%"])
            refreshTimer.restart()
        }
    }
    Timer { interval: 4000; running: root.opened; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

    MouseArea {
        anchors.fill: parent
        onClicked: root.opened = false
    }

    Rectangle {
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        anchors.topMargin: theme.barPosition === "top" ? theme.barSize : 12
        anchors.rightMargin: 0
        anchors.bottomMargin: 0
        width: Math.min(430, parent.width - 20)
        radius: 0
        opacity: root.reveal
        transform: Translate { x: (1 - root.reveal) * theme.slide }
        color: theme.surface
        border.width: 1
        border.color: theme.border

        MouseArea {
            anchors.fill: parent
            // Keep clicks on empty panel space from closing it.
            onClicked: mouse => mouse.accepted = true
        }

        Flickable {
            z: 1
            anchors.fill: parent
            anchors.margins: 18
            contentWidth: width
            contentHeight: content.implicitHeight
            clip: true

            ColumnLayout {
                id: content
                width: parent.width
                spacing: 13

                RowLayout {
                    Layout.fillWidth: true
                    Text { font.family: theme.font; text: "Control Center"; color: theme.text; font.pixelSize: 21; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { font.family: theme.font; text: "SUPER + SHIFT + C"; color: theme.subtext; font.pixelSize: 10 }
                    Rectangle {
                        width: 30; height: 30; radius: 9
                        color: closeMouse.containsMouse ? theme.surface3 : theme.surface2
                        Behavior on color { ColorAnimation { duration: theme.durationFast } }
                        Text { font.family: theme.font; anchors.centerIn: parent; text: "󰅖"; color: theme.subtext;  }
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.opened = false
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 10
                    rowSpacing: 10

                    Rectangle {
                        Layout.fillWidth: true; height: 86; radius: 14
                        color: root.wifiConnected ? theme.surface3 : theme.surface2
                        border.width: 1; border.color: root.wifiConnected ? theme.blue : theme.border
                        Column {
                            anchors.left: parent.left; anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter; spacing: 5
                            Text { font.family: theme.font; text: (root.wifiConnected ? "󰤨" : root.wifiEnabled ? "󰤭" : "󰤮") + "  Wi-Fi"; color: root.wifiConnected ? theme.blue : theme.text; font.bold: true }
                            Text { font.family: theme.font; width: 160; text: root.wifiText; color: theme.subtext; elide: Text.ElideRight }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openPanel(root.networkPanel) }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 86; radius: 14
                        color: root.bluetoothEnabled ? theme.surface3 : theme.surface2
                        border.width: 1; border.color: root.bluetoothEnabled ? theme.blue : theme.border
                        Column {
                            anchors.left: parent.left; anchors.leftMargin: 14
                            anchors.right: parent.right; anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter; spacing: 5
                            Text { font.family: theme.font; text: "󰂯  Bluetooth"; color: root.bluetoothEnabled ? theme.blue : theme.text; font.bold: true }
                            Text { font.family: theme.font; width: parent.width; text: root.bluetoothText; color: theme.subtext; elide: Text.ElideRight }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openPanel(root.bluetoothPanel) }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; height: 98; radius: 14; color: theme.surface2
                    border.width: 1; border.color: theme.border
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 13; spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Text { font.family: theme.font; text: "󰕾  Volume"; color: theme.text; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                width: 66; height: 22; radius: 7
                                color: devicesMouse.containsMouse ? theme.surface3 : theme.bg
                                Behavior on color { ColorAnimation { duration: theme.durationFast } }
                                Text { font.family: theme.font; anchors.centerIn: parent; text: "Devices"; color: theme.subtext; font.pixelSize: 9 }
                                MouseArea { id: devicesMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openPanel(root.audioPanel) }
                            }
                            Text { font.family: theme.font; text: root.audioState.volumeText; color: theme.blue; font.bold: true }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 10
                            ValueSlider {
                                id: masterVolume
                                Layout.fillWidth: true
                                from: 0; to: 150
                                value: root.volumeDragging ? root.pendingMasterVolume : root.audioState.volumePercent
                                accent: theme.blue
                                onValueEdited: newValue => {
                                    root.pendingMasterVolume = newValue
                                    root.volumeDragging = true
                                    volumeDelay.restart()
                                }
                            }
                            Text {
                                font.family: theme.font; text: root.audioState.muted ? "󰝟" : "󰕾"
                                color: root.audioState.muted ? theme.red : theme.subtext; font.pixelSize: 16
                                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.audioState.run(["wpctl","set-mute","@DEFAULT_AUDIO_SINK@","toggle"]) }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; height: 98; radius: 14; color: theme.surface2
                    border.width: 1; border.color: theme.border
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 13; spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Text { font.family: theme.font; text: "󰃠  Brightness"; color: theme.text; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text { font.family: theme.font; text: root.brightnessText; color: theme.yellow; font.bold: true }
                        }
                        ValueSlider {
                            id: brightnessSlider
                            Layout.fillWidth: true
                            from: 1; to: 100
                            value: root.brightnessDragging ? root.pendingBrightness : (parseInt(root.brightnessText) || 50)
                            accent: theme.yellow
                            onValueEdited: newValue => {
                                root.pendingBrightness = newValue
                                root.brightnessDragging = true
                                root.brightnessText = root.pendingBrightness + "%"
                                brightnessDelay.restart()
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; height: root.player ? 132 : 62; radius: 14; color: theme.surface2
                    border.width: 1; border.color: theme.border
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 13; spacing: 8
                        Text { font.family: theme.font; Layout.fillWidth: true; text: root.player ? (root.player.identity || "Media") : "No media player"; color: theme.text; font.bold: true; elide: Text.ElideRight }
                        Text { font.family: theme.font; visible: root.player !== null; Layout.fillWidth: true; text: root.player ? ((root.player.trackTitle || "Unknown track") + "  ·  " + (root.player.trackArtist || "")) : ""; color: theme.subtext; elide: Text.ElideRight }
                        RowLayout {
                            visible: root.player !== null; Layout.fillWidth: true; spacing: 8
                            Repeater {
                                model: ["󰒮", "󰐊", "󰒭"]
                                delegate: Rectangle {
                                    required property string modelData
                                    required property int index
                                    Layout.fillWidth: true; height: 36; radius: 9; color: mediaMouse.containsMouse ? theme.surface3 : theme.bg
                                    Text { font.family: theme.font; anchors.centerIn: parent; text: modelData; color: theme.text;  }
                                    MouseArea {
                                        id: mediaMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (!root.player) return
                                            if (index === 0 && root.player.canGoPrevious) root.player.previous()
                                            else if (index === 1 && root.player.canTogglePlaying) root.player.togglePlaying()
                                            else if (index === 2 && root.player.canGoNext) root.player.next()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: UPower.displayDevice.ready && UPower.displayDevice.isLaptopBattery
                    Layout.fillWidth: true; height: 98; radius: 14; color: theme.surface2
                    border.width: 1
                    border.color: UPower.displayDevice.percentage < 0.20 ? theme.red : theme.border
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 14; spacing: 7
                        RowLayout {
                            Layout.fillWidth: true
                            Text { font.family: theme.font; text: "󰁹  Battery"; color: theme.text; font.bold: true; font.pixelSize: 12 }
                            Item { Layout.fillWidth: true }
                            Text {
                                font.family: theme.font
                                text: Math.round(UPower.displayDevice.percentage * 100) + "%"
                                color: UPower.displayDevice.percentage < 0.20 ? theme.red : theme.blue
                                font.bold: true; font.pixelSize: 16
                            }
                        }
                        Text { Layout.fillWidth: true; text: root.batteryStatus(); color: theme.subtext; font.family: theme.font; font.pixelSize: 9; elide: Text.ElideRight }
                        Rectangle {
                            Layout.fillWidth: true; height: 6; radius: 3; color: theme.bg
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, UPower.displayDevice.percentage))
                                height: parent.height; radius: 3
                                color: UPower.displayDevice.percentage < 0.20 ? theme.red : theme.blue
                                Behavior on width { NumberAnimation { duration: theme.durationMedium; easing.type: theme.easingEnter } }
                            }
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true; columns: 2; columnSpacing: 10; rowSpacing: 10
                    Repeater {
                        model: [
                            ["󰹑", "Screenshot", ["buchhwin-screenshot","region"]],
                            ["󰅍", "Clipboard", ["buchhwin-clipboard","toggle"]],
                            ["󰒓", "All settings", ["buchhwin-settings"]]
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true; height: 48; radius: 11; color: quickMouse.containsMouse ? theme.surface3 : theme.surface2
                            border.width: 1; border.color: theme.border
                            Row {
                                anchors.centerIn: parent; spacing: 8
                                Text { font.family: theme.font; text: modelData[0]; color: theme.blue;  }
                                Text { font.family: theme.font; text: modelData[1]; color: theme.text; font.pixelSize: 11 }
                            }
                            MouseArea {
                                id: quickMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.opened = false
                                    Quickshell.execDetached(modelData[2])
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
