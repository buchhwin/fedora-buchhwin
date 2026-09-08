import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: root
    Theme { id: theme }
    property bool opened: false
    property string wallpaperPath: ""
    property string wallpaperMessage: ""
    property string slideshowFolder: ""
    property int slideshowMinutes: 5
    property bool slideshowEnabled: false
    property int currentTab: 0
    property var displays: []
    property int selectedDisplay: 0
    property string displayMode: ""
    property real displayScale: 1.0
    property string displayTransform: "normal"
    property int displayX: 0
    property int displayY: 0
    property string displayMessage: ""
    property var iconPacks: []
    property var cursorPacks: []
    property var fontPacks: []
    property var appearanceState: ({"icons":"breeze-dark", "cursor":"breeze_cursors", "cursorSize":24, "gaps":8, "border":1, "font":"MesloLGS Nerd Font Mono", "theme":"graphite", "accent":"#d0d0d0", "background":"#181818", "bar":"#242424", "text":"#eeeeee", "barPosition":"top", "barSize":38})
    property string appearanceMessage: ""

    // Network, Bluetooth and sound are handled by the shell's own panels
    // instead of external programs; shell.qml wires these up.
    property var networkPanel: null
    property var bluetoothPanel: null
    property var audioPanel: null
    required property var audioState

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
    WlrLayershell.namespace: "buchhwin-settings"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // An entry either starts a program (array) or opens one of the shell's
    // own panels (string key).
    function launch(action) {
        opened = false
        if (typeof action === "string") {
            const panel = action === "network" ? root.networkPanel
                        : action === "bluetooth" ? root.bluetoothPanel
                        : action === "audio" ? root.audioPanel : null
            if (panel) panel.opened = true
            return
        }
        Quickshell.execDetached(action)
    }

    function refreshWallpaper() {
        if (!wallpaperRead.running) wallpaperRead.running = true
        if (!folderRead.running) folderRead.running = true
        if (!intervalRead.running) intervalRead.running = true
        if (!modeRead.running) modeRead.running = true
    }

    function refreshDisplays() {
        if (!displayRead.running) displayRead.running = true
    }
    function refreshAppearance() { if (!appearanceRead.running) appearanceRead.running = true }
    function setAppearance(key, value) {
        appearanceWrite.command = ["buchhwin-appearance", "set", key, String(value)]
        if (!appearanceWrite.running) appearanceWrite.running = true
    }

    function chooseDisplay(index) {
        if (index < 0 || index >= displays.length) return
        selectedDisplay = index
        const output = displays[index]
        displayMode = output.mode
        displayScale = output.scale
        displayTransform = output.transform
        displayX = output.x
        displayY = output.y
    }

    function applyDisplay() {
        if (!displays.length || displayApply.running) return
        const output = displays[selectedDisplay]
        displayMessage = "Applying display settings…"
        displayApply.command = ["buchhwin-displayctl", "set", output.name,
                                displayMode, String(displayScale), displayTransform,
                                String(displayX), String(displayY)]
        displayApply.running = true
    }

    function minDisplayX() {
        let value = 0
        for (let i = 0; i < displays.length; i++) value = Math.min(value, displays[i].x)
        return value
    }
    function minDisplayY() {
        let value = 0
        for (let i = 0; i < displays.length; i++) value = Math.min(value, displays[i].y)
        return value
    }
    function modeWidth(output) { return Number((output.mode || "1920x1080").split("x")[0]) / output.scale }
    function modeHeight(output) { return Number((output.mode || "1920x1080").split("x")[1]) / output.scale }
    function moveDisplay(index, wantedX, wantedY) {
        const changed = []
        for (let i = 0; i < displays.length; i++) changed.push(Object.assign({}, displays[i]))
        const moving = changed[index]
        const width = modeWidth(moving), height = modeHeight(moving)
        let x = Math.round(wantedX), y = Math.round(wantedY)
        const snap = 120
        for (let i = 0; i < changed.length; i++) {
            if (i === index) continue
            const other = changed[i], ow = modeWidth(other), oh = modeHeight(other)
            if (Math.abs(x - (other.x + ow)) < snap) x = Math.round(other.x + ow)
            if (Math.abs(x + width - other.x) < snap) x = Math.round(other.x - width)
            if (Math.abs(y - (other.y + oh)) < snap) y = Math.round(other.y + oh)
            if (Math.abs(y + height - other.y) < snap) y = Math.round(other.y - height)
            if (Math.abs(y - other.y) < snap) y = other.y
            if (Math.abs(x - other.x) < snap) x = other.x
        }
        moving.x = x; moving.y = y
        displays = changed
        chooseDisplay(index)
    }

    function setWallpaper(path) {
        if (!path || !path.length || wallpaperWrite.running) return
        wallpaperMessage = "Applying wallpaper…"
        wallpaperWrite.command = ["buchhwin-wallpaper", "set", path]
        wallpaperWrite.running = true
    }

    onOpenedChanged: if (opened) { refreshWallpaper(); refreshDisplays(); refreshAppearance() }
    Shortcut { sequence: "Escape"; enabled: root.opened; onActivated: root.opened = false }
    MouseArea { anchors.fill: parent; onClicked: root.opened = false }

    Process {
        id: wallpaperRead
        command: ["buchhwin-wallpaper", "get"]
        stdout: StdioCollector { onStreamFinished: root.wallpaperPath = text.trim() }
    }
    Process { id: folderRead; command: ["buchhwin-wallpaper", "get-folder"]; stdout: StdioCollector { onStreamFinished: root.slideshowFolder = text.trim() } }
    Process { id: intervalRead; command: ["buchhwin-wallpaper", "get-interval"]; stdout: StdioCollector { onStreamFinished: root.slideshowMinutes = Math.max(1, Math.round(Number(text.trim()) / 60)) } }
    Process { id: modeRead; command: ["buchhwin-wallpaper", "get-mode"]; stdout: StdioCollector { onStreamFinished: root.slideshowEnabled = text.trim() === "slideshow" } }

    Process {
        id: wallpaperWrite
        stdout: StdioCollector { onStreamFinished: if (text.trim().length) root.wallpaperPath = text.trim() }
        stderr: StdioCollector { onStreamFinished: root.wallpaperMessage = text.trim() }
        onExited: code => {
            root.wallpaperMessage = code === 0 ? "Wallpaper applied for dwl" : (root.wallpaperMessage || "Could not apply wallpaper")
            root.refreshWallpaper()
        }
    }

    Process {
        id: wallpaperChooser
        command: ["zenity", "--file-selection", "--title=Choose a wallpaper for dwl", "--file-filter=Images | *.png *.jpg *.jpeg *.webp *.bmp", "--file-filter=All files | *"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim()
                if (path.length) root.setWallpaper(path)
            }
        }
    }
    Process {
        id: folderChooser
        command: ["zenity", "--file-selection", "--directory", "--title=Choose a wallpaper folder"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim()
                if (path.length) {
                    slideshowAction.command = ["buchhwin-wallpaper", "set-folder", path]
                    slideshowAction.running = true
                }
            }
        }
    }
    Process {
        id: slideshowAction
        onExited: code => {
            root.wallpaperMessage = code === 0 ? "Slideshow updated" : "Could not update slideshow"
            root.refreshWallpaper()
        }
    }
    Process {
        id: displayRead
        command: ["buchhwin-displayctl", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.displays = JSON.parse(text)
                    root.chooseDisplay(Math.min(root.selectedDisplay, root.displays.length - 1))
                } catch (error) {
                    root.displayMessage = "Could not read displays"
                }
            }
        }
    }
    Process {
        id: displayApply
        stderr: StdioCollector { onStreamFinished: if (text.trim().length) root.displayMessage = text.trim() }
        onExited: code => {
            root.displayMessage = code === 0 ? "Display profile applied and saved" : (root.displayMessage || "Could not apply display settings")
            root.refreshDisplays()
        }
    }
    Process {
        id: appearanceRead
        command: ["buchhwin-appearance", "list"]
        stdout: StdioCollector { onStreamFinished: { try { const data = JSON.parse(text); root.appearanceState = data.state; root.iconPacks = data.icons; root.cursorPacks = data.cursors; root.fontPacks = data.fonts } catch (error) {} } }
    }
    Process {
        id: appearanceWrite
        stdout: StdioCollector { onStreamFinished: root.appearanceMessage = text.trim() }
        stderr: StdioCollector { onStreamFinished: if (text.trim().length) root.appearanceMessage = text.trim() }
        onExited: root.refreshAppearance()
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(1320, parent.width - 32)
        height: Math.min(900, parent.height - 48)
        opacity: root.reveal
        transform: Translate { y: (1 - root.reveal) * theme.lift }
        color: theme.surface
        border.width: 1
        border.color: theme.border
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.preferredWidth: 220
                Layout.fillHeight: true
                color: theme.surface2
                border.width: 0

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 9
                    Text { font.family: theme.font; text: "Settings"; color: theme.text; font.pixelSize: 26; font.bold: true; Layout.bottomMargin: 13 }
                    Repeater {
                        model: [["󰏘", "Appearance"], ["󰖩", "Connections"], ["󰍹", "Hardware"], ["󰒓", "Tools"], ["󰀻", "Apps"], ["󰌌", "Keybinds"], ["󰆍", "Terminal"]]
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true; height: 52
                            color: root.currentTab === index ? theme.surface3 : tabMouse.containsMouse ? theme.bg : "transparent"
                            border.width: root.currentTab === index ? 1 : 0
                            border.color: theme.border
                            Behavior on color { ColorAnimation { duration: theme.durationFast } }
                            Row {
                                anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                                Text { font.family: theme.font; text: modelData[0]; color: root.currentTab === index ? theme.blue : theme.subtext; font.pixelSize: 19 }
                                Text { font.family: theme.font; text: modelData[1]; color: theme.text; font.pixelSize: 15; font.bold: root.currentTab === index }
                            }
                            MouseArea { id: tabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.currentTab = index }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Text { font.family: theme.font; text: "SUPER + SHIFT + S"; color: theme.subtext; font.pixelSize: 9 }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 24
                spacing: 14
                Text {
                    font.family: theme.font
                    text: ["Appearance", "Connections", "Hardware", "Tools", "Applications", "Keybinds", "Terminal prompt"][root.currentTab]
                    color: theme.text; font.pixelSize: 26; font.bold: true
                }
                Text {
                    font.family: theme.font
                    text: ["Personalize the dwl session", "Network, Bluetooth and sound", "Displays, files and credentials", "Configuration and diagnostics", "Installed and default applications", "View and safely edit dwl shortcuts", "Starship with a live preview"][root.currentTab]
                    color: theme.subtext; font.pixelSize: 14
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.currentTab

                    Flickable {
                        contentWidth: width
                        contentHeight: appearanceContent.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        ColumnLayout {
                        id: appearanceContent
                        width: parent.width
                        spacing: 12
                        FastfetchSettings {
                            Layout.fillWidth: true
                            onChooseStarted: root.opened = false
                            onChooseFinished: root.opened = true
                        }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 165
                            color: theme.surface2; border.width: 1; border.color: theme.border
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 12; spacing: 14
                                Rectangle {
                                    Layout.preferredWidth: 190; Layout.fillHeight: true
                                    color: theme.bg; border.width: 1; border.color: theme.border; clip: true
                                    Image { anchors.fill: parent; source: root.wallpaperPath.length ? "file://" + root.wallpaperPath : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 7
                                    Text { font.family: theme.font; text: "Wallpaper"; color: theme.text; font.bold: true; font.pixelSize: 14 }
                                    Text { font.family: theme.font; Layout.fillWidth: true; text: root.wallpaperPath.length ? root.wallpaperPath.split("/").pop() : "No wallpaper selected"; color: theme.subtext; elide: Text.ElideMiddle; font.pixelSize: 9 }
                                    Text { font.family: theme.font; Layout.fillWidth: true; visible: root.wallpaperMessage.length > 0; text: root.wallpaperMessage; color: theme.blue; elide: Text.ElideRight; font.pixelSize: 9 }
                                    Item { Layout.fillHeight: true }
                                    Rectangle {
                                        Layout.preferredWidth: 130; Layout.preferredHeight: 36
                                        color: wallpaperMouse.containsMouse ? theme.surface3 : theme.bg; border.width: 1; border.color: theme.border
                                        Text { font.family: theme.font; anchors.centerIn: parent; text: "Choose image"; color: theme.text; font.pixelSize: 10 }
                                        MouseArea {
                                            id: wallpaperMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.opened = false
                                                if (!wallpaperChooser.running) wallpaperChooser.running = true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 130
                            color: theme.surface2; border.width: 1; border.color: theme.border
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 12; spacing: 8
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { font.family: theme.font; text: "Slideshow"; color: theme.text; font.bold: true; font.pixelSize: 13 }
                                    Text { font.family: theme.font; text: root.slideshowEnabled ? "active" : "off"; color: root.slideshowEnabled ? theme.green : theme.subtext; font.pixelSize: 10 }
                                    Item { Layout.fillWidth: true }
                                    Rectangle {
                                        width: 120; height: 32; color: folderMouse.containsMouse ? theme.surface3 : theme.bg; border.width: 1; border.color: theme.border
                                        Text { font.family: theme.font; anchors.centerIn: parent; text: "Choose folder"; color: theme.text; font.pixelSize: 10 }
                                        MouseArea {
                                            id: folderMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.opened = false
                                                if (!folderChooser.running) folderChooser.running = true
                                            }
                                        }
                                    }
                                }
                                Text { font.family: theme.font; Layout.fillWidth: true; text: root.slideshowFolder || "No folder selected"; color: theme.subtext; elide: Text.ElideMiddle; font.pixelSize: 9 }
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 6
                                    Text { font.family: theme.font; text: "Change every"; color: theme.subtext; font.pixelSize: 10 }
                                    Repeater {
                                        model: [1, 5, 15, 30, 60]
                                        delegate: Rectangle {
                                            required property int modelData
                                            width: 42; height: 26
                                            color: root.slideshowMinutes === modelData ? theme.blue : intervalMouse.containsMouse ? theme.surface3 : theme.bg
                                            border.width: 1; border.color: theme.border
                                            Text { font.family: theme.font; anchors.centerIn: parent; text: modelData + "m"; color: root.slideshowMinutes === modelData ? theme.bg : theme.text; font.pixelSize: 9 }
                                            MouseArea {
                                                id: intervalMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    slideshowAction.command = ["buchhwin-wallpaper", "set-interval", String(modelData * 60)]
                                                    slideshowAction.running = true
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 405
                            AppearanceStyleSettings {
                                anchors.fill: parent
                                state: root.appearanceState
                                fonts: root.fontPacks
                                onSetValue: (key, value) => root.setAppearance(key, value)
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 270
                            Layout.minimumHeight: 270
                            color: theme.surface2; border.width: 1; border.color: theme.border
                            ColumnLayout { anchors.fill: parent; anchors.margins: 14; spacing: 9
                                Text { text: "Icon pack"; color: theme.text; font.family: theme.font; font.pixelSize: 14; font.bold: true }
                                Flickable { Layout.fillWidth: true; height: 38; contentWidth: iconRow.implicitWidth; clip: true
                                    Row { id: iconRow; spacing: 7; Repeater { model: root.iconPacks; delegate: Rectangle {
                                        required property string modelData; width: Math.min(165, iconName.implicitWidth + 22); height: 36; radius: 7
                                        color: root.appearanceState.icons === modelData ? theme.blue : theme.bg
                                        Text { id: iconName; anchors.centerIn: parent; text: modelData; color: root.appearanceState.icons === modelData ? theme.bg : theme.text; font.family: theme.font; font.pixelSize: 11 }
                                        MouseArea { anchors.fill: parent; onClicked: root.setAppearance("icons", modelData) }
                                    } } }
                                }
                                Text { text: "Cursor pack"; color: theme.text; font.family: theme.font; font.pixelSize: 12; font.bold: true }
                                Flickable { Layout.fillWidth: true; height: 38; contentWidth: cursorRow.implicitWidth; clip: true
                                    Row { id: cursorRow; spacing: 7; Repeater { model: root.cursorPacks; delegate: Rectangle {
                                        required property string modelData; width: Math.min(165, cursorName.implicitWidth + 22); height: 36; radius: 7
                                        color: root.appearanceState.cursor === modelData ? theme.blue : theme.bg
                                        Text { id: cursorName; anchors.centerIn: parent; text: modelData; color: root.appearanceState.cursor === modelData ? theme.bg : theme.text; font.family: theme.font; font.pixelSize: 11 }
                                        MouseArea { anchors.fill: parent; onClicked: root.setAppearance("cursor", modelData) }
                                    } } }
                                }
                                RowLayout { Layout.fillWidth: true; spacing: 8
                                    Text { text: "Cursor size"; color: theme.subtext; font.family: theme.font; font.pixelSize: 9 }
                                    ValueSlider { Layout.fillWidth: true; from: 16; to: 64; value: root.appearanceState.cursorSize; onValueEdited: value => root.setAppearance("cursorSize", value) }
                                }
                                RowLayout { Layout.fillWidth: true
                                    Text { text: "Gaps"; color: theme.subtext; font.family: theme.font; font.pixelSize: 9 }
                                    ValueSlider { Layout.fillWidth: true; from: 0; to: 40; value: root.appearanceState.gaps; onValueEdited: value => root.setAppearance("gaps", value) }
                                    Text { text: "Border"; color: theme.subtext; font.family: theme.font; font.pixelSize: 9 }
                                    ValueSlider { Layout.fillWidth: true; from: 0; to: 8; value: root.appearanceState.border; onValueEdited: value => root.setAppearance("border", value) }
                                }
                                Text { Layout.fillWidth: true; text: root.appearanceMessage; color: theme.blue; font.family: theme.font; font.pixelSize: 10; elide: Text.ElideRight }
                            }
                        }
                        Item { Layout.preferredHeight: 4 }
                        }
                    }

                    ConnectionsSettings { audioState: root.audioState; active: root.opened && root.currentTab === 1 }

                    Flickable {
                        contentWidth: width
                        contentHeight: hardwareContent.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        ColumnLayout {
                            id: hardwareContent
                            width: parent.width
                            spacing: 10
                            Text { font.family: theme.font; text: "Displays"; color: theme.text; font.bold: true; font.pixelSize: 14 }
                            RowLayout {
                                Layout.fillWidth: true; spacing: 6
                                Repeater {
                                    model: root.displays
                                    delegate: Rectangle {
                                        required property var modelData
                                        required property int index
                                        Layout.preferredWidth: 150; Layout.preferredHeight: 34
                                        color: root.selectedDisplay === index ? theme.surface3 : theme.surface2
                                        border.width: 1; border.color: root.selectedDisplay === index ? theme.blue : theme.border
                                        Text { anchors.centerIn: parent; font.family: theme.font; text: modelData.name; color: theme.text; font.pixelSize: 10 }
                                        MouseArea { anchors.fill: parent; onClicked: root.chooseDisplay(index) }
                                    }
                                }
                            }
                            Rectangle {
                                id: displayCanvas
                                Layout.fillWidth: true; Layout.preferredHeight: 160
                                color: theme.bg; border.width: 1; border.color: theme.border; clip: true
                                Text { anchors.centerIn: parent; visible: root.displays.length === 0; text: "No active display"; color: theme.subtext; font.family: theme.font }
                                Repeater {
                                    model: root.displays
                                    delegate: Rectangle {
                                        id: monitorPreview
                                        required property var modelData
                                        required property int index
                                        readonly property real previewScale: 0.10
                                        x: 12 + (modelData.x - root.minDisplayX()) * previewScale
                                        y: 12 + (modelData.y - root.minDisplayY()) * previewScale
                                        width: Math.max(80, root.modeWidth(modelData) * previewScale)
                                        height: Math.max(50, root.modeHeight(modelData) * previewScale)
                                        radius: 8; color: root.selectedDisplay === index ? theme.surface3 : theme.surface2
                                        border.width: 2; border.color: root.selectedDisplay === index ? theme.blue : theme.border
                                        Text { anchors.centerIn: parent; text: modelData.name + "\n" + modelData.mode; horizontalAlignment: Text.AlignHCenter; color: theme.text; font.family: theme.font; font.pixelSize: 9 }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.OpenHandCursor
                                            drag.target: monitorPreview; drag.axis: Drag.XAndYAxis
                                            preventStealing: true
                                            onPressed: { root.selectedDisplay = index; cursorShape = Qt.ClosedHandCursor }
                                            onReleased: {
                                                cursorShape = Qt.OpenHandCursor
                                                root.moveDisplay(index,
                                                    (monitorPreview.x - 12) / monitorPreview.previewScale + root.minDisplayX(),
                                                    (monitorPreview.y - 12) / monitorPreview.previewScale + root.minDisplayY())
                                            }
                                        }
                                    }
                                }
                                Text { anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 6; text: "Drag displays – edges snap automatically"; color: theme.subtext; font.family: theme.font; font.pixelSize: 8 }
                            }
                            Text { font.family: theme.font; text: "Resolution"; color: theme.subtext; font.pixelSize: 10 }
                            Flow {
                                Layout.fillWidth: true; spacing: 6
                                Repeater {
                                    model: root.displays.length ? root.displays[root.selectedDisplay].modes : []
                                    delegate: Rectangle {
                                        required property string modelData
                                        width: 92; height: 28
                                        color: root.displayMode === modelData ? theme.blue : theme.surface2
                                        border.width: 1; border.color: theme.border
                                        Text { anchors.centerIn: parent; font.family: theme.font; text: modelData; color: root.displayMode === modelData ? theme.bg : theme.text; font.pixelSize: 9 }
                                        MouseArea { anchors.fill: parent; onClicked: root.displayMode = modelData }
                                    }
                                }
                            }
                            Text { font.family: theme.font; text: "Scale"; color: theme.subtext; font.pixelSize: 10 }
                            RowLayout {
                                Layout.fillWidth: true; spacing: 6
                                Repeater {
                                    model: [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
                                    delegate: Rectangle {
                                        required property real modelData
                                        width: 52; height: 28
                                        color: Math.abs(root.displayScale - modelData) < 0.01 ? theme.blue : theme.surface2
                                        border.width: 1; border.color: theme.border
                                        Text { anchors.centerIn: parent; font.family: theme.font; text: Math.round(modelData * 100) + "%"; color: Math.abs(root.displayScale - modelData) < 0.01 ? theme.bg : theme.text; font.pixelSize: 9 }
                                        MouseArea { anchors.fill: parent; onClicked: root.displayScale = modelData }
                                    }
                                }
                            }
                            Text { font.family: theme.font; text: "Rotation"; color: theme.subtext; font.pixelSize: 10 }
                            RowLayout {
                                Layout.fillWidth: true; spacing: 6
                                Repeater {
                                    model: [["Normal", "normal"], ["90°", "90"], ["180°", "180"], ["270°", "270"]]
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: 70; height: 28
                                        color: root.displayTransform === modelData[1] ? theme.blue : theme.surface2
                                        border.width: 1; border.color: theme.border
                                        Text { anchors.centerIn: parent; font.family: theme.font; text: modelData[0]; color: root.displayTransform === modelData[1] ? theme.bg : theme.text; font.pixelSize: 9 }
                                        MouseArea { anchors.fill: parent; onClicked: root.displayTransform = modelData[1] }
                                    }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                Text { font.family: theme.font; text: "Position  X " + root.displayX + "  Y " + root.displayY; color: theme.subtext; font.pixelSize: 10 }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    width: 100; height: 34; color: applyDisplayMouse.containsMouse ? theme.surface3 : theme.blue
                                    Text { anchors.centerIn: parent; font.family: theme.font; text: "Apply"; color: theme.bg; font.pixelSize: 10; font.bold: true }
                                    MouseArea { id: applyDisplayMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.applyDisplay() }
                                }
                            }
                            Text { Layout.fillWidth: true; font.family: theme.font; text: root.displayMessage; color: theme.blue; font.pixelSize: 9; wrapMode: Text.WordWrap }
                            PowerSettings { Layout.fillWidth: true }
                            RowLayout {
                                Layout.fillWidth: true; spacing: 10
                                Repeater {
                                    model: [["Files", "Open Dolphin", ["dolphin"]], ["Passwords", "Open KWallet Manager", ["kwalletmanager5"]], ["Online accounts", "Google and cloud accounts", ["systemsettings", "kcm_kaccounts"]]]
                                    delegate: Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true; height: 62; color: hardwareMouse.containsMouse ? theme.surface3 : theme.surface2
                                        border.width: 1; border.color: theme.border
                                        Column { anchors.fill: parent; anchors.margins: 10; spacing: 4
                                            Text { font.family: theme.font; text: modelData[0]; color: theme.text; font.bold: true; font.pixelSize: 11 }
                                            Text { font.family: theme.font; text: modelData[1]; color: theme.subtext; font.pixelSize: 9 }
                                        }
                                        MouseArea { id: hardwareMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.launch(modelData[2]) }
                                    }
                                }
                            }
                        }
                    }

                    GridLayout {
                        columns: 2; columnSpacing: 10; rowSpacing: 10
                        Repeater {
                            model: [["Desktop config", "Edit advanced session values", ["buchhwin-edit-settings"]], ["System check", "Run the buchhwin doctor", ["buchhwin-terminal", "buchhwin-doctor"]], ["Create backup", "Save settings and shell configuration", ["buchhwin-backup", "create"]], ["Restore backup", "Choose and restore a saved configuration", ["buchhwin-backup", "restore"]], ["Open backups", "Browse installer and manual backups", ["buchhwin-backup", "open"]], ["Export theme", "Save colors, fonts and shell appearance", ["buchhwin-theme", "export"]], ["Import theme", "Load a previously exported theme", ["buchhwin-theme", "import"]]]
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true; Layout.preferredHeight: 92
                                color: toolMouse.containsMouse ? theme.surface3 : theme.surface2; border.width: 1; border.color: theme.border
                                Column { anchors.fill: parent; anchors.margins: 14; spacing: 6
                                    Text { font.family: theme.font; text: modelData[0]; color: theme.text; font.bold: true; font.pixelSize: 14 }
                                    Text { font.family: theme.font; width: parent.width; text: modelData[1]; color: theme.subtext; wrapMode: Text.WordWrap; font.pixelSize: 10 }
                                }
                                MouseArea { id: toolMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.launch(modelData[2]) }
                            }
                        }
                    }

                    AppsSettings { Layout.fillWidth: true; Layout.fillHeight: true }
                    KeybindSettings { Layout.fillWidth: true; Layout.fillHeight: true }
                    StarshipSettings { Layout.fillWidth: true; Layout.fillHeight: true }
                }

                Text {
                    font.family: theme.font; Layout.fillWidth: true
                    text: root.currentTab === 4 ? "Default-app choices are account-wide; all other desktop settings remain isolated to the dwl session." : "Changes are stored in ~/.config/buchhwin-dwl and apply to this dwl session."
                    color: theme.subtext; wrapMode: Text.WordWrap; font.pixelSize: 9
                }
            }
        }
    }
}
