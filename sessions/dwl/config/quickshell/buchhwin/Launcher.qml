import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    Theme { id: theme }

    property bool opened: false
    property string query: ""
    property int selectedIndex: 0
    property string category: "All"
    readonly property var categories: [["󰀻", "All"], ["󰆍", "Development"], ["󰉋", "Office"], ["󰎈", "Multimedia"], ["󰖟", "Internet"], ["󰒓", "System"]]

    function inCategory(app) {
        if (category === "All") return true
        const values = (app.categories || []).join(" ").toLowerCase()
        if (category === "Development") return values.includes("development")
        if (category === "Office") return values.includes("office")
        if (category === "Multimedia") return values.includes("audio") || values.includes("video") || values.includes("graphics")
        if (category === "Internet") return values.includes("network") || values.includes("webbrowser")
        return values.includes("system") || values.includes("settings") || values.includes("utility")
    }

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
    color: Qt.rgba(0, 0, 0, 0.47 * reveal)
    focusable: opened
    exclusiveZone: 0
    aboveWindows: true
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "buchhwin-launcher"

    property var filteredApps: DesktopEntries.applications.values.filter(app => {
        if (!app) return false
        if (!root.inCategory(app)) return false
        const q = root.query.trim().toLowerCase()
        if (!q.length) return true
        const haystack = ((app.name || "") + " " + (app.genericName || "") + " " + (app.keywords || []).join(" ")).toLowerCase()
        return haystack.includes(q)
    })

    function closeLauncher() {
        opened = false
        query = ""
        selectedIndex = 0
        category = "All"
    }

    function launchSelected() {
        if (!filteredApps.length) return
        const idx = Math.max(0, Math.min(selectedIndex, filteredApps.length - 1))
        const app = filteredApps[idx]
        if (app) {
            if (app.runInTerminal) {
                Quickshell.execDetached({
                    command: ["buchhwin-terminal", ...app.command],
                    workingDirectory: app.workingDirectory
                })
            } else {
                app.execute()
            }
            closeLauncher()
        }
    }

    onOpenedChanged: if (opened) {
        query = ""
        selectedIndex = 0
        search.forceActiveFocus()
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        MouseArea { anchors.fill: parent; onClicked: root.closeLauncher() }
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.max(90, parent.height * 0.15)
        width: Math.min(1060, parent.width - 64)
        height: Math.min(760, parent.height - 110)
        opacity: root.reveal
        transform: Translate { y: (1 - root.reveal) * theme.lift }
        radius: 0
        color: theme.surface
        border.width: 1
        border.color: theme.border

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                Text { font.family: theme.font; text: ""; color: theme.blue; font.pixelSize: 26 }
                Text { font.family: theme.font; text: "Applications"; color: theme.text; font.pixelSize: 24; font.bold: true }
                Item { Layout.fillWidth: true }
                Text { font.family: theme.font; text: "SUPER + D"; color: theme.subtext; font.pixelSize: 12 }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 56
                radius: 8
                color: theme.surface2
                border.width: search.activeFocus ? 2 : 1
                border.color: search.activeFocus ? theme.blue : theme.border

                Text { font.family: theme.font;
                    anchors.left: parent.left; anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color: theme.blue
                    font.pixelSize: 18
                }

                TextInput { font.family: theme.font;
                    id: search
                    anchors.fill: parent
                    anchors.leftMargin: 47; anchors.rightMargin: 15
                    verticalAlignment: TextInput.AlignVCenter
                    color: theme.text
                    selectionColor: theme.blue
                    selectedTextColor: theme.bg
                    font.pixelSize: 17
                    clip: true
                    text: root.query
                    onTextChanged: { root.query = text; root.selectedIndex = 0 }
                    Keys.onEscapePressed: root.closeLauncher()
                    Keys.onDownPressed: if (root.filteredApps.length) root.selectedIndex = Math.min(root.selectedIndex + 1, root.filteredApps.length - 1)
                    Keys.onUpPressed: root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
                    Keys.onReturnPressed: root.launchSelected()
                    Keys.onEnterPressed: root.launchSelected()
                }

                Text { font.family: theme.font;
                    anchors.left: parent.left; anchors.leftMargin: 47
                    anchors.verticalCenter: parent.verticalCenter
                    visible: search.text.length === 0
                    text: "Search applications"
                    color: theme.subtext
                    font.pixelSize: 17
                }
            }

            Text { font.family: theme.font;
                Layout.fillWidth: true
                Layout.leftMargin: 190
                text: root.filteredApps.length + " applications"
                color: theme.subtext
                font.pixelSize: 12
            }

            ListView {
                id: appList
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 190
                clip: true
                spacing: 7
                model: ScriptModel { values: root.filteredApps }
                currentIndex: root.selectedIndex
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: appList.width
                    height: 64
                    radius: 12
                    color: index === root.selectedIndex ? theme.surface3 : appMouse.containsMouse ? theme.surface2 : "transparent"
                    Behavior on color { ColorAnimation { duration: theme.durationFast } }
                    border.width: index === root.selectedIndex ? 1 : 0
                    border.color: theme.blue

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14; anchors.rightMargin: 14
                        spacing: 14
                        Image {
                            Layout.preferredWidth: 38; Layout.preferredHeight: 38
                            source: Quickshell.iconPath(modelData.icon || "application-x-executable", "application-x-executable")
                            sourceSize.width: 38; sourceSize.height: 38
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text { font.family: theme.font; Layout.fillWidth: true; text: modelData.name || modelData.id; color: theme.text; font.pixelSize: 16; font.bold: index === root.selectedIndex; elide: Text.ElideRight }
                            Text { font.family: theme.font; Layout.fillWidth: true; visible: (modelData.genericName || "").length > 0; text: modelData.genericName || ""; color: theme.subtext; font.pixelSize: 12; elide: Text.ElideRight }
                        }
                    }

                    MouseArea {
                        id: appMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = index
                        onClicked: { root.selectedIndex = index; root.launchSelected() }
                    }
                }
            }

            Text { font.family: theme.font; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: "↑ ↓  Select     Enter  Open     Esc  Close"; color: theme.subtext; font.pixelSize: 11 }
        }

        Rectangle {
            anchors.left: parent.left; anchors.leftMargin: 18
            anchors.top: parent.top; anchors.topMargin: 161
            anchors.bottom: parent.bottom; anchors.bottomMargin: 43
            width: 174; radius: 12; color: theme.surface2
            Column {
                anchors.fill: parent; anchors.margins: 9; spacing: 7
                Repeater {
                    model: root.categories
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width; height: 52; radius: 8
                        color: root.category === modelData[1] ? theme.surface3 : categoryMouse.containsMouse ? theme.bg : "transparent"
                        Row { anchors.left: parent.left; anchors.leftMargin: 11; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                            Text { text: modelData[0]; color: theme.blue; font.family: theme.font; font.pixelSize: 17 }
                            Text { text: modelData[1]; color: theme.text; font.family: theme.font; font.pixelSize: 13; font.bold: root.category === modelData[1] }
                        }
                        MouseArea { id: categoryMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { root.category = modelData[1]; root.selectedIndex = 0 } }
                    }
                }
            }
        }
    }
}
