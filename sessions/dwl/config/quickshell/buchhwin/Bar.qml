import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

Scope {
    id: root
    required property var dwlState
    required property var audioState
    required property var mediaState
    Theme { id: theme }

    property string networkText: "offline"
    property bool bluetoothEnabled: false
    property var weather: ({ "temperature": null, "location": "", "description": "", "icon": "󰖪" })

    function stateFor(name) {
        if (!root.dwlState || !root.dwlState.outputs) return {}
        return root.dwlState.outputs[name] || {}
    }

    function volumeIcon() {
        if (audioState.muted) return "󰝟"
        const level = audioState.volumePercent
        if (isNaN(level) || level === 0) return "󰕿"
        if (level < 50) return "󰖀"
        return "󰕾"
    }

    function batteryIcon() {
        const state = UPower.displayDevice.state
        if (state === UPowerDeviceState.Charging || state === UPowerDeviceState.PendingCharge)
            return "󰂄"
        const level = UPower.displayDevice.percentage
        if (level < 0.10) return "󰂎"
        if (level < 0.20) return "󰁺"
        if (level < 0.30) return "󰁻"
        if (level < 0.40) return "󰁼"
        if (level < 0.50) return "󰁽"
        if (level < 0.60) return "󰁾"
        if (level < 0.70) return "󰁿"
        if (level < 0.80) return "󰂀"
        if (level < 0.90) return "󰂁"
        if (level < 0.98) return "󰂂"
        return "󰁹"
    }

    Process {
        id: networkProc
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | awk -F: '$2==\"802-11-wireless\"{print $1; exit} $2==\"802-3-ethernet\"{wired=$1} END{if(wired) print wired}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim()
                root.networkText = out.length ? out : "offline"
            }
        }
    }

    Process {
        id: bluetoothProc
        command: ["sh", "-c", "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && printf on || printf off"]
        stdout: StdioCollector {
            onStreamFinished: root.bluetoothEnabled = text.trim() === "on"
        }
    }

    Process {
        id: weatherProc
        command: ["buchhwin-weather"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.weather = JSON.parse(text) }
                catch (error) { /* Keep the last valid reading. */ }
            }
        }
    }

    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!weatherProc.running) weatherProc.running = true
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!networkProc.running) networkProc.running = true
            if (!bluetoothProc.running) bluetoothProc.running = true
        }
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData
            color: "transparent"
            property bool vertical: theme.barPosition === "left" || theme.barPosition === "right"
            implicitHeight: vertical ? 0 : theme.barSize
            implicitWidth: vertical ? theme.barSize : 0
            exclusiveZone: theme.barSize
            anchors {
                top: theme.barPosition === "top" || vertical
                bottom: theme.barPosition === "bottom" || vertical
                left: theme.barPosition === "left" || !vertical
                right: theme.barPosition === "right" || !vertical
            }

            property var outputState: root.stateFor(modelData.name)
            property int occupiedMask: Number(outputState.occupied || 0)
            property int selectedMask: Number(outputState.selectedTags || 0)
            property int urgentMask: Number(outputState.urgent || 0)
            property var player: root.mediaState.player

            Rectangle {
                anchors.fill: parent
                radius: 0
                color: theme.surface
                border.width: 0

                Rectangle {
                    z: 2
                    visible: panel.width > 1100
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: centeredClock.implicitWidth + 22
                    height: parent.height
                    color: theme.surface
                    Text { font.family: theme.font;
                        id: centeredClock
                        anchors.centerIn: parent
                        text: Qt.formatDateTime(clock.date, "ddd dd MMM  HH:mm")
                        color: theme.text
                        font.bold: true
                        font.pixelSize: 11
                    }
                    MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["buchhwin-calendar"]) }
                }

                RowLayout {
                    visible: !panel.vertical
                    anchors.fill: parent
                    anchors.leftMargin: 7
                    anchors.rightMargin: 7
                    spacing: 5

                    Rectangle {
                        width: 30; height: 30; radius: 0
                        color: brandMouse.containsMouse ? theme.surface3 : "transparent"
                        Behavior on color { ColorAnimation { duration: theme.durationFast } }
                        Text { font.family: theme.font;
                            anchors.centerIn: parent
                            text: ""
                            color: theme.blue
                            font.pixelSize: 19
                        }
                        MouseArea {
                            id: brandMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["buchhwin-launcher"])
                        }
                    }

                    Rectangle {
                        implicitWidth: tags.implicitWidth + 4
                        height: 30; radius: 0
                        color: "transparent"
                        Row {
                            id: tags
                            anchors.centerIn: parent
                            spacing: 2
                            Repeater {
                                model: 9
                                delegate: Rectangle {
                                    required property int index
                                    property int bit: 1 << index
                                    property bool selected: (panel.selectedMask & bit) !== 0
                                    property bool occupied: (panel.occupiedMask & bit) !== 0
                                    property bool urgent: (panel.urgentMask & bit) !== 0
                                    width: 25; height: 25; radius: 3
                                    color: selected ? theme.surface3 : urgent ? theme.red : "transparent"
                                    border.width: selected ? 1 : 0
                                    border.color: theme.subtext
                                    scale: selected ? 1.07 : 1.0
                                    Behavior on color { ColorAnimation { duration: theme.durationFast } }
                                    Behavior on scale { NumberAnimation { duration: theme.durationFast; easing.type: theme.easingEnter } }
                                    Behavior on border.width { NumberAnimation { duration: theme.durationFast } }
                                    Text { font.family: theme.font;
                                        anchors.centerIn: parent
                                        text: index + 1
                                        color: parent.selected || parent.occupied ? theme.text : theme.subtext
                                        font.bold: parent.selected
                                        font.pixelSize: 12
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 500
                        height: 30; radius: 0; color: "transparent"
                        Text { font.family: theme.font;
                            anchors.fill: parent
                            anchors.leftMargin: 12; anchors.rightMargin: 12
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            text: {
                                const title = panel.outputState.title || ""
                                const app = panel.outputState.appid || ""
                                if (!title.length) return "buchhwin"
                                return app.length ? app + "  ·  " + title : title
                            }
                            color: theme.text
                            font.pixelSize: 12
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        visible: root.weather.temperature !== null
                        width: weatherMouse.containsMouse ? Math.min(180, weatherLocation.implicitWidth + 52) : 66
                        Layout.preferredWidth: width
                        Layout.fillHeight: true
                        color: weatherMouse.containsMouse ? theme.surface3 : "transparent"
                        clip: true
                        Behavior on width { NumberAnimation { duration: theme.durationFast; easing.type: theme.easingEnter } }
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                font.family: theme.font
                                text: root.weather.icon || "󰖪"
                                color: root.weather.iconColor || theme.yellow
                                font.pixelSize: 19
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                id: weatherLocation
                                font.family: theme.font
                                text: weatherMouse.containsMouse
                                      ? (root.weather.precise ? root.weather.location : "≈ " + root.weather.location)
                                      : root.weather.temperature + "°C"
                                color: theme.text
                                font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                width: weatherMouse.containsMouse ? Math.min(112, implicitWidth) : implicitWidth
                            }
                        }
                        MouseArea {
                            id: weatherMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (!weatherProc.running) weatherProc.running = true
                        }
                    }

                    Rectangle {
                        visible: panel.player !== null
                        implicitWidth: Math.min(250, mediaRow.implicitWidth + 12)
                        Layout.preferredWidth: implicitWidth
                        Layout.maximumWidth: 250
                        Layout.fillHeight: true; radius: 0; color: mediaOpenMouse.containsMouse ? theme.surface3 : "transparent"; clip: true
                        MouseArea { id: mediaOpenMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["buchhwin-media"]) }
                        Row {
                            id: mediaRow
                            anchors.centerIn: parent
                            spacing: 6
                            Rectangle {
                                width: 24; height: 24; radius: 3
                                color: theme.surface3
                                clip: true
                                Image {
                                    id: cover
                                    anchors.fill: parent
                                    source: panel.player ? panel.player.trackArtUrl : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                                Text {
                                    font.family: theme.font
                                    anchors.centerIn: parent
                                    visible: cover.status !== Image.Ready
                                    text: "󰎈"
                                    color: theme.subtext
                                    font.pixelSize: 12
                                }
                            }
                            Text { font.family: theme.font;
                                id: mediaText
                                width: Math.min(100, implicitWidth)
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: panel.player ? (panel.player.trackTitle || panel.player.identity || "Media") : ""
                                color: theme.text
                                font.pixelSize: 11
                            }
                            Repeater {
                                model: ["󰒮", panel.player && panel.player.isPlaying ? "󰏤" : "󰐊", "󰒭"]
                                Rectangle {
                                    required property string modelData
                                    required property int index
                                    width: 26; height: 26; radius: 3
                                    color: mediaMouse.containsMouse ? theme.surface3 : "transparent"
                                    Behavior on color { ColorAnimation { duration: theme.durationFast } }
                                    Text {
                                        anchors.centerIn: parent
                                        font.family: theme.font
                                        text: modelData
                                        color: mediaMouse.containsMouse ? theme.text : theme.subtext
                                        font.pixelSize: 14
                                    }
                                    MouseArea {
                                        id: mediaMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (!panel.player) return
                                            if (index === 0 && panel.player.canGoPrevious) panel.player.previous()
                                            else if (index === 1 && panel.player.canTogglePlaying) panel.player.togglePlaying()
                                            else if (index === 2 && panel.player.canGoNext) panel.player.next()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    SystemTray { hostWindow: panel }

                    Rectangle {
                        width: 30
                        height: 30; radius: 0; color: netMouse.containsMouse ? theme.surface3 : "transparent"
                        Behavior on color { ColorAnimation { duration: theme.durationFast } }
                        Text { font.family: theme.font;
                            anchors.centerIn: parent
                            text: root.networkText === "offline" ? "󰤭" : "󰤨"
                            color: root.networkText === "offline" ? theme.red : theme.green
                            Behavior on color { ColorAnimation { duration: theme.durationFast } }
                            font.pixelSize: 15
                        }
                        MouseArea { id: netMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["buchhwin-network"]) }
                    }

                    Rectangle {
                        width: 30
                        height: 30; radius: 0; color: btMouse.containsMouse ? theme.surface3 : "transparent"
                        Behavior on color { ColorAnimation { duration: theme.durationFast } }
                        Text { font.family: theme.font;
                            anchors.centerIn: parent
                            text: root.bluetoothEnabled ? "󰂯" : "󰂲"
                            color: root.bluetoothEnabled ? theme.blue : theme.subtext
                            Behavior on color { ColorAnimation { duration: theme.durationFast } }
                            font.pixelSize: 15
                        }
                        MouseArea { id: btMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["buchhwin-bluetooth"]) }
                    }

                    Rectangle {
                        width: 30
                        height: 30; radius: 0; color: volMouse.containsMouse ? theme.surface3 : "transparent"
                        Behavior on color { ColorAnimation { duration: theme.durationFast } }
                        Text { font.family: theme.font;
                            anchors.centerIn: parent
                            text: root.volumeIcon()
                            color: theme.text
                            font.pixelSize: 15
                        }
                        MouseArea { id: volMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["buchhwin-sound"]) }
                    }

                    Rectangle {
                        visible: UPower.displayDevice.ready && UPower.displayDevice.isLaptopBattery
                        implicitWidth: batMouse.containsMouse ? 88 : 34
                        Layout.preferredWidth: implicitWidth
                        Behavior on implicitWidth { NumberAnimation { duration: theme.durationFast; easing.type: theme.easingEnter } }
                        height: 30; radius: 0; color: batMouse.containsMouse ? theme.surface3 : "transparent"
                        Behavior on color { ColorAnimation { duration: theme.durationFast } }
                        Row {
                            anchors.centerIn: parent; spacing: 6
                            Text { font.family: theme.font;
                                text: root.batteryIcon()
                                color: (UPower.displayDevice.state === UPowerDeviceState.Charging
                                        || UPower.displayDevice.state === UPowerDeviceState.PendingCharge)
                                       ? theme.blue : UPower.displayDevice.percentage < 0.20 ? theme.red : theme.text
                                font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                visible: batMouse.containsMouse
                                text: Math.round(UPower.displayDevice.percentage * 100) + "%"
                                font.family: theme.font; font.pixelSize: 11; font.bold: true
                                color: theme.text; anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea { id: batMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["buchhwin-control-center"]) }
                    }

                    Rectangle {
                        visible: panel.width <= 1100
                        width: clockLabel.implicitWidth + 22
                        Layout.fillHeight: true; radius: 0; color: clockMouse.containsMouse ? theme.surface3 : "transparent"
                        Behavior on color { ColorAnimation { duration: theme.durationFast } }
                        Text { font.family: theme.font;
                            id: clockLabel
                            anchors.centerIn: parent
                            text: Qt.formatDateTime(clock.date, "ddd dd MMM  HH:mm")
                            color: theme.text
                            font.bold: true
                            font.pixelSize: 11
                        }
                        MouseArea { id: clockMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["buchhwin-calendar"]) }
                    }

                    Rectangle {
                        width: 30; height: 30; radius: 0
                        color: settingsMouse.containsMouse ? theme.surface3 : "transparent"
                        Behavior on color { ColorAnimation { duration: theme.durationFast } }
                        Text { font.family: theme.font;
                            anchors.centerIn: parent
                            text: "󰒓"
                            color: theme.text
                            font.pixelSize: 15
                        }
                        MouseArea {
                            id: settingsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["buchhwin-settings"])
                        }
                    }
                }

                // Vertical positions use a compact icon-first layout so text
                // and workspace controls remain readable on narrow panels.
                Column {
                    visible: panel.vertical
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top; anchors.topMargin: 6
                    spacing: 5
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: ""; color: theme.blue; font.family: theme.font; font.pixelSize: 19 }
                    Repeater {
                        model: 9
                        delegate: Rectangle {
                            required property int index
                            property int bit: 1 << index
                            width: 30; height: 27; radius: 4
                            color: (panel.selectedMask & bit) !== 0 ? theme.surface3 : (panel.urgentMask & bit) !== 0 ? theme.red : "transparent"
                            Text { anchors.centerIn: parent; text: index + 1; color: (panel.occupiedMask & parent.bit) !== 0 ? theme.text : theme.subtext; font.family: theme.font; font.pixelSize: 11 }
                        }
                    }
                    Rectangle { width: 30; height: 1; color: theme.border }
                    SystemTray { hostWindow: panel; vertical: true; anchors.horizontalCenter: parent.horizontalCenter }
                    Repeater {
                        model: [
                            [root.weather.icon || "󰖪", "weather"],
                            [root.networkText === "offline" ? "󰤭" : "󰤨", "network"],
                            [root.bluetoothEnabled ? "󰂯" : "󰂲", "bluetooth"],
                            [root.volumeIcon(), "sound"],
                            [root.batteryIcon(), "battery"],
                            ["󰒓", "settings"]
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            width: 30; height: 30; color: verticalMouse.containsMouse ? theme.surface3 : "transparent"
                            Text { anchors.centerIn: parent; text: modelData[0]; color: theme.text; font.family: theme.font; font.pixelSize: 15 }
                            MouseArea {
                                id: verticalMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const action = modelData[1]
                                    if (action === "weather") { if (!weatherProc.running) weatherProc.running = true }
                                    else if (action === "battery") Quickshell.execDetached(["buchhwin-control-center"])
                                    else Quickshell.execDetached(["buchhwin-" + action])
                                }
                            }
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "HH\nmm")
                        horizontalAlignment: Text.AlignHCenter
                        color: theme.text; font.family: theme.font; font.bold: true; font.pixelSize: 10
                    }
                }
            }
        }
    }
}
