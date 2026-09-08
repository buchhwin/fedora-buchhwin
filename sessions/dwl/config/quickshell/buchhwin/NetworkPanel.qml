import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Native Wi-Fi management on top of nmcli, replacing nm-connection-editor.
//
// Enterprise networks (eduroam and friends) are deliberately not editable
// here: creating an 802.1X profile needs certificate and identity handling
// that belongs in a full editor. Such profiles are created once in Plasma's
// session and then appear below under "Saved connections", where bringing
// them up is a single click.
PanelWindow {
    id: root
    Theme { id: theme }

    property bool opened: false
    property bool radioOn: false
    property bool connected: false
    property bool scanning: false
    property string activeSsid: ""
    property string status: ""
    property string pendingSsid: ""
    property var networks: []
    property var saved: []

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
    WlrLayershell.namespace: "buchhwin-network"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // nmcli -t escapes literal colons inside values as "\:", so splitting on
    // ":" alone would tear an SSID containing a colon apart.
    function splitFields(line) {
        const parts = []
        let current = ""
        for (let i = 0; i < line.length; i++) {
            const ch = line.charAt(i)
            if (ch === "\\" && i + 1 < line.length) {
                current += line.charAt(i + 1)
                i++
            } else if (ch === ":") {
                parts.push(current)
                current = ""
            } else {
                current += ch
            }
        }
        parts.push(current)
        return parts
    }

    function refresh() {
        if (!radioProc.running) radioProc.running = true
        if (!connectionProc.running) connectionProc.running = true
        if (!listProc.running) listProc.running = true
        if (!savedProc.running) savedProc.running = true
    }

    function connectTo(ssid, security) {
        root.status = ""
        if (security && security.length > 0 && !root.isSaved(ssid)) {
            root.pendingSsid = ssid
            passwordField.text = ""
            passwordField.forceActiveFocus()
            return
        }
        root.status = "Connecting to " + ssid + "..."
        connectProc.command = ["nmcli", "device", "wifi", "connect", ssid]
        connectProc.running = true
    }

    function connectWithPassword() {
        if (root.pendingSsid.length === 0) return
        root.status = "Connecting to " + root.pendingSsid + "..."
        connectProc.command = ["nmcli", "device", "wifi", "connect",
                               root.pendingSsid, "password", passwordField.text]
        root.pendingSsid = ""
        passwordField.text = ""
        connectProc.running = true
    }

    function isSaved(ssid) {
        for (let i = 0; i < root.saved.length; i++)
            if (root.saved[i].name === ssid) return true
        return false
    }

    onOpenedChanged: {
        if (opened) {
            root.status = ""
            root.pendingSsid = ""
            refresh()
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.opened
        onActivated: {
            if (root.pendingSsid.length > 0) root.pendingSsid = ""
            else root.opened = false
        }
    }

    Process {
        id: radioProc
        command: ["nmcli", "-t", "-f", "WIFI", "general"]
        stdout: StdioCollector { onStreamFinished: root.radioOn = text.trim() === "enabled" }
    }

    Process {
        id: connectionProc
        command: ["sh", "-c", "export LC_ALL=C; dev=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | awk -F: '$2==\"wifi\" && $3==\"connected\" {print $1; exit}'); if [ -n \"$dev\" ]; then ssid=$(nmcli -t -f IN-USE,SSID device wifi list ifname \"$dev\" --rescan no 2>/dev/null | sed -n 's/^\\*://p' | head -n1); [ -n \"$ssid\" ] && printf '%s\\n' \"$ssid\" || nmcli -g GENERAL.CONNECTION device show \"$dev\" 2>/dev/null | head -n1; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.activeSsid = text.trim().replace("\\:", ":")
                root.connected = root.activeSsid.length > 0
                const changed = []
                for (let i = 0; i < root.networks.length; i++) {
                    const item = Object.assign({}, root.networks[i])
                    item.active = root.connected && item.ssid === root.activeSsid
                    changed.push(item)
                }
                root.networks = changed
            }
        }
    }

    Process {
        id: listProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = ({})
                const found = []
                const lines = text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim()
                    if (line.length === 0) continue
                    const f = root.splitFields(line)
                    if (f.length < 4) continue
                    const ssid = f[1]
                    if (ssid.length === 0) continue
                    const inUse = f[0] === "*"
                    // nmcli lists one row per access point; keep the strongest.
                    const signal = parseInt(f[2]) || 0
                    if (seen[ssid] !== undefined) {
                        if (found[seen[ssid]].signal < signal) found[seen[ssid]].signal = signal
                        continue
                    }
                    seen[ssid] = found.length
                    found.push({ ssid: ssid, signal: signal, security: f[3], active: root.connected && ssid === root.activeSsid })
                }
                found.sort((a, b) => b.signal - a.signal)
                root.networks = found
                root.scanning = false
            }
        }
    }

    Process {
        id: savedProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = []
                const lines = text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim()
                    if (line.length === 0) continue
                    const f = root.splitFields(line)
                    if (f.length < 2) continue
                    if (f[1].indexOf("wireless") < 0 && f[1].indexOf("ethernet") < 0) continue
                    found.push({ name: f[0], type: f[1] })
                }
                root.saved = found
            }
        }
    }

    Process {
        id: connectProc
        stdout: StdioCollector { onStreamFinished: {} }
        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim()
                if (message.length > 0) root.status = message
            }
        }
        onExited: exitCode => {
            if (exitCode === 0) root.status = "Connected"
            else if (root.status.indexOf("Connecting") === 0) root.status = "Connection failed"
            root.refresh()
        }
    }

    Process { id: actionProc; onExited: root.refresh() }

    function run(args) {
        actionProc.command = args
        actionProc.running = true
    }

    Timer { interval: 5000; running: root.opened; repeat: true; onTriggered: root.refresh() }

    MouseArea { anchors.fill: parent; onClicked: root.opened = false }

    Rectangle {
        anchors { top: parent.top; right: parent.right }
        anchors.topMargin: theme.barPosition === "top" ? theme.barSize : 12
        anchors.rightMargin: 12
        width: Math.min(500, parent.width - 24)
        height: Math.min(620, parent.height - 58)
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
                Text { font.family: theme.font; text: "󰤨  Network"; color: theme.text; font.pixelSize: 19; font.bold: true }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 96; height: 30
                    color: root.radioOn ? theme.surface3 : theme.surface2
                    border.width: 1; border.color: root.radioOn ? theme.blue : theme.border
                    Text { font.family: theme.font; anchors.centerIn: parent; text: root.radioOn ? "Wi-Fi on" : "Wi-Fi off"; color: root.radioOn ? theme.blue : theme.subtext; font.pixelSize: 11 }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.run(["nmcli", "radio", "wifi", root.radioOn ? "off" : "on"])
                    }
                }
                Rectangle {
                    width: 30; height: 30
                    color: netCloseMouse.containsMouse ? theme.surface3 : theme.surface2
                    Behavior on color { ColorAnimation { duration: theme.durationFast } }
                    Text { font.family: theme.font; anchors.centerIn: parent; text: "󰅖"; color: theme.subtext }
                    MouseArea { id: netCloseMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.opened = false }
                }
            }

            Text {
                font.family: theme.font
                Layout.fillWidth: true
                text: root.status.length > 0 ? root.status : !root.radioOn ? "Wi-Fi is switched off" : root.connected ? "Connected to " + root.activeSsid : "Not connected"
                color: root.connected && root.status.length === 0 ? theme.green : theme.subtext
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            // Inline password entry, shown only for a secured network that has
            // no saved profile yet.
            Rectangle {
                Layout.fillWidth: true
                visible: root.pendingSsid.length > 0
                height: 66
                color: theme.surface2
                border.width: 1; border.color: theme.blue
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 10; spacing: 6
                    Text { font.family: theme.font; text: "Password for " + root.pendingSsid; color: theme.text; font.pixelSize: 11 }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Rectangle {
                            Layout.fillWidth: true; height: 26; color: theme.bg
                            border.width: 1; border.color: theme.border
                            TextInput {
                                id: passwordField
                                font.family: theme.font
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                color: theme.text
                                echoMode: TextInput.Password
                                clip: true
                                onAccepted: root.connectWithPassword()
                            }
                        }
                        Rectangle {
                            width: 84; height: 26; color: theme.surface3
                            border.width: 1; border.color: theme.border
                            Text { font.family: theme.font; anchors.centerIn: parent; text: "Connect"; color: theme.text; font.pixelSize: 11 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.connectWithPassword() }
                        }
                    }
                }
            }

            Text { font.family: theme.font; Layout.fillWidth: true; text: "Available networks"; color: theme.subtext; font.pixelSize: 11 }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: root.networks
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: 44
                    color: netMouse.containsMouse ? theme.surface3 : theme.surface2
                    Behavior on color { ColorAnimation { duration: theme.durationFast } }
                    border.width: 1
                    border.color: modelData.active ? theme.blue : theme.border
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10
                        Text {
                            font.family: theme.font
                            text: modelData.security && modelData.security.length > 0 ? "󰤪" : "󰤨"
                            color: modelData.active ? theme.blue : theme.subtext
                        }
                        Text {
                            font.family: theme.font
                            Layout.fillWidth: true
                            text: modelData.ssid
                            color: modelData.active ? theme.blue : theme.text
                            font.bold: modelData.active
                            elide: Text.ElideRight
                            font.pixelSize: 12
                        }
                        Text { font.family: theme.font; text: modelData.signal + "%"; color: theme.subtext; font.pixelSize: 10 }
                    }
                    MouseArea {
                        id: netMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.active) root.run(["nmcli", "connection", "down", "id", modelData.ssid])
                            else root.connectTo(modelData.ssid, modelData.security)
                        }
                    }
                }
            }

            Text { font.family: theme.font; Layout.fillWidth: true; text: "Saved connections"; color: theme.subtext; font.pixelSize: 11 }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(112, contentHeight)
                clip: true
                spacing: 4
                model: root.saved
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: 34
                    color: savedMouse.containsMouse ? theme.surface3 : theme.surface2
                    Behavior on color { ColorAnimation { duration: theme.durationFast } }
                    border.width: 1; border.color: theme.border
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                        Text { font.family: theme.font; Layout.fillWidth: true; text: modelData.name; color: theme.text; elide: Text.ElideRight; font.pixelSize: 11 }
                        Text { font.family: theme.font; text: "Connect"; color: theme.subtext; font.pixelSize: 10 }
                    }
                    MouseArea {
                        id: savedMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.status = "Connecting to " + modelData.name + "..."
                            connectProc.command = ["nmcli", "connection", "up", "id", modelData.name]
                            connectProc.running = true
                        }
                    }
                }
            }

            Text {
                font.family: theme.font
                Layout.fillWidth: true
                text: "Enterprise networks such as eduroam are set up once in the Plasma session and appear above under saved connections."
                color: theme.subtext
                wrapMode: Text.WordWrap
                font.pixelSize: 9
            }
        }
    }
}
