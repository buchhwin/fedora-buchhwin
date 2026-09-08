import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Flickable {
    id: root
    Theme { id: theme }
    contentWidth: width; contentHeight: body.implicitHeight; clip: true
    boundsBehavior: Flickable.StopAtBounds
    property var state: ({})
    property string preview: ""
    property string message: ""
    function refresh() { if (!stateRead.running) stateRead.running = true; if (!previewRead.running) previewRead.running = true }
    function setValue(key, value) {
        if (setter.running) return
        message = "Updating preview…"
        setter.command = ["buchhwin-settings-backend", "starship-set", key, String(value)]
        setter.running = true
    }
    Component.onCompleted: refresh()
    Process { id: stateRead; command: ["buchhwin-settings-backend", "starship"]; stdout: StdioCollector { onStreamFinished: { try { root.state = JSON.parse(text) } catch(error) { root.message = "Could not read settings" } } } }
    Process { id: previewRead; command: ["buchhwin-settings-backend", "starship-preview"]; stdout: StdioCollector { onStreamFinished: root.preview = text.trim() } stderr: StdioCollector { onStreamFinished: if (text.trim()) root.message = text.trim() } }
    Process { id: setter; stderr: StdioCollector { onStreamFinished: if (text.trim()) root.message = text.trim() } onExited: code => { root.message = code === 0 ? "Preview updated" : (root.message || "Invalid setting"); root.refresh() } }

    ColumnLayout {
        id: body; width: root.width; spacing: 13
        Text { text: "Live prompt preview"; color: theme.text; font.family: theme.font; font.pixelSize: 17; font.bold: true }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 112; color: "#111318"; border.width: 1; border.color: theme.border; radius: 7
            Text { anchors.fill: parent; anchors.margins: 16; text: root.preview || "~/Projects/fedora-dwl  󰊢 main  ❯"; color: root.state.color || theme.text; font.family: theme.font; font.pixelSize: 16; verticalAlignment: Text.AlignVCenter; wrapMode: Text.WrapAnywhere }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 46; color: theme.surface2; border.width: 1; border.color: theme.border; radius: 7
            RowLayout { anchors.fill: parent; anchors.margins: 10
                ColumnLayout { Layout.fillWidth: true; spacing: 1
                    Text { text: "Show Git example in preview"; color: theme.text; font.family: theme.font; font.pixelSize: 11 }
                    Text { text: "Preview only — does not disable Git in your real prompt"; color: theme.subtext; font.family: theme.font; font.pixelSize: 9 }
                }
                Rectangle { width: 46; height: 25; radius: 13; color: root.state.previewGit ? theme.blue : theme.bg
                    Rectangle { width: 19; height: 19; radius: 10; y: 3; x: root.state.previewGit ? 24 : 3; color: theme.text }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setValue("previewGit", !root.state.previewGit) }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 54; color: theme.surface2; border.width: 1; border.color: theme.border; radius: 7
            RowLayout { anchors.fill: parent; anchors.margins: 10
                ColumnLayout { Layout.fillWidth: true; spacing: 1
                    Text { text: "Show Fastfetch when terminal opens"; color: theme.text; font.family: theme.font; font.pixelSize: 11 }
                    Text { text: "Manual fastfetch and ff commands always remain available"; color: theme.subtext; font.family: theme.font; font.pixelSize: 9 }
                }
                Rectangle { width: 46; height: 25; radius: 13; color: root.state.startupFastfetch ? theme.blue : theme.bg
                    Rectangle { width: 19; height: 19; radius: 10; y: 3; x: root.state.startupFastfetch ? 24 : 3; color: theme.text; Behavior on x { NumberAnimation { duration: theme.durationFast } } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setValue("startupFastfetch", !root.state.startupFastfetch) }
                }
            }
        }
        Text { text: root.message; color: theme.blue; font.family: theme.font; font.pixelSize: 10 }

        Text { text: "Colors"; color: theme.text; font.family: theme.font; font.pixelSize: 14; font.bold: true }
        RowLayout { spacing: 8
            Text { text: "Accent"; color: theme.subtext; font.family: theme.font; font.pixelSize: 11 }
            Repeater { model: ["#d0d0d0", "#89b4fa", "#a6e3a1", "#f9e2af", "#cba6f7", "#f38ba8"]; delegate: Rectangle { required property string modelData; width: 38; height: 30; radius: 7; color: modelData; border.width: root.state.color === modelData ? 3 : 1; border.color: theme.text; MouseArea { anchors.fill: parent; onClicked: root.setValue("color", modelData) } } }
        }
        RowLayout { spacing: 8
            Text { text: "Error"; color: theme.subtext; font.family: theme.font; font.pixelSize: 11 }
            Repeater { model: ["#f38ba8", "#fab387", "#f9e2af", "#cba6f7"]; delegate: Rectangle { required property string modelData; width: 38; height: 30; radius: 7; color: modelData; border.width: root.state.errorColor === modelData ? 3 : 1; border.color: theme.text; MouseArea { anchors.fill: parent; onClicked: root.setValue("errorColor", modelData) } } }
        }

        Text { text: "Symbols"; color: theme.text; font.family: theme.font; font.pixelSize: 14; font.bold: true }
        RowLayout { spacing: 8
            Repeater { model: [["symbol", "Prompt", root.state.symbol || "❯"], ["errorSymbol", "Error", root.state.errorSymbol || "❯"], ["gitSymbol", "Git", root.state.gitSymbol || "󰊢 "]]; delegate: ColumnLayout { required property var modelData
                Text { text: modelData[1]; color: theme.subtext; font.family: theme.font; font.pixelSize: 10 }
                RowLayout { Rectangle { width: 105; height: 36; color: theme.surface2; border.width: 1; border.color: theme.border; TextInput { id: valueInput; anchors.fill: parent; anchors.margins: 8; text: modelData[2]; color: theme.text; font.family: theme.font; font.pixelSize: 12; selectByMouse: true } }
                    Rectangle { width: 58; height: 36; color: applyMouse.containsMouse ? theme.surface3 : theme.blue; Text { anchors.centerIn: parent; text: "Apply"; color: theme.bg; font.family: theme.font; font.pixelSize: 9 } MouseArea { id: applyMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.setValue(modelData[0], valueInput.text) } }
                }
            } }
        }

        Text { text: "Modules"; color: theme.text; font.family: theme.font; font.pixelSize: 14; font.bold: true }
        GridLayout { Layout.fillWidth: true; columns: 2; columnSpacing: 9; rowSpacing: 9
            Repeater { model: [["directory","Directory"],["git","Git branch"],["gitStatus","Git status"],["username","Username"],["hostname","Hostname"],["python","Python"],["nodejs","Node.js"],["docker","Docker context"],["commandDuration","Command duration"],["jobs","Background jobs"],["time","Clock"],["twoLine","Two-line prompt"],["newline","Blank line between prompts"]]
                delegate: Rectangle { required property var modelData; Layout.fillWidth: true; height: 46; color: theme.surface2; border.width: 1; border.color: theme.border
                    RowLayout { anchors.fill: parent; anchors.margins: 10; Text { Layout.fillWidth: true; text: modelData[1]; color: theme.text; font.family: theme.font; font.pixelSize: 11 }
                        Rectangle { width: 46; height: 25; radius: 13; color: root.state[modelData[0]] ? theme.blue : theme.bg; Rectangle { width: 19; height: 19; radius: 10; y: 3; x: root.state[modelData[0]] ? 24 : 3; color: theme.text } MouseArea { anchors.fill: parent; onClicked: root.setValue(modelData[0], !root.state[modelData[0]]) } }
                    }
                }
            }
        }

        Text { text: "Detail settings"; color: theme.text; font.family: theme.font; font.pixelSize: 14; font.bold: true }
        RowLayout { Layout.fillWidth: true; spacing: 12
            ColumnLayout { Layout.fillWidth: true; Text { text: "Directory depth: " + (root.state.directoryTruncation || 3); color: theme.subtext; font.family: theme.font; font.pixelSize: 10 } ValueSlider { Layout.fillWidth: true; from: 1; to: 10; suffix: ""; value: root.state.directoryTruncation || 3; onValueEdited: value => root.setValue("directoryTruncation", Math.round(value)) } }
            ColumnLayout { Layout.fillWidth: true; Text { text: "Duration threshold: " + (root.state.durationMin || 1500) + " ms"; color: theme.subtext; font.family: theme.font; font.pixelSize: 10 } ValueSlider { Layout.fillWidth: true; from: 100; to: 10000; suffix: "ms"; value: root.state.durationMin || 1500; onValueEdited: value => root.setValue("durationMin", Math.round(value / 100) * 100) } }
        }
        Text { text: "Clock format"; color: theme.subtext; font.family: theme.font; font.pixelSize: 10 }
        GridLayout {
            Layout.fillWidth: true; columns: 4; columnSpacing: 8; rowSpacing: 8
            Repeater {
                model: [["21:45", "%H:%M"], ["9:45 PM", "%I:%M %p"], ["21:45:30", "%H:%M:%S"], ["07.09 21:45", "%d.%m %H:%M"]]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true; height: 38; radius: 6
                    color: root.state.timeFormat === modelData[1] ? theme.blue : theme.surface2
                    border.width: 1; border.color: theme.border
                    Text { anchors.centerIn: parent; text: modelData[0]; color: root.state.timeFormat === modelData[1] ? theme.bg : theme.text; font.family: theme.font; font.pixelSize: 10 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setValue("timeFormat", modelData[1]) }
                }
            }
        }
        RowLayout {
            Text { text: "Custom"; color: theme.subtext; font.family: theme.font; font.pixelSize: 10 }
            Rectangle { width: 160; height: 36; color: theme.surface2; border.width: 1; border.color: theme.border
                TextInput { id: timeFormatInput; anchors.fill: parent; anchors.margins: 8; text: root.state.timeFormat || "%H:%M"; color: theme.text; font.family: theme.font; selectByMouse: true }
            }
            Rectangle { width: 62; height: 36; color: theme.blue
                Text { anchors.centerIn: parent; text: "Apply"; color: theme.bg; font.family: theme.font; font.pixelSize: 9 }
                MouseArea { anchors.fill: parent; onClicked: root.setValue("timeFormat", timeFormatInput.text) }
            }
            Text { text: "%H hour  %M minute  %S second  %p AM/PM"; color: theme.subtext; font.family: theme.font; font.pixelSize: 9 }
        }
        Text { Layout.fillWidth: true; text: "Stored in ~/.config/buchhwin-dwl/starship.toml and used only by terminals launched inside this dwl session."; color: theme.subtext; font.family: theme.font; font.pixelSize: 10; wrapMode: Text.WordWrap }
        Item { Layout.preferredHeight: 8 }
    }
}
