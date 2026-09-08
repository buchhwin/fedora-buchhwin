// Windows — how focus follows the pointer, and which windows float.
import QtQuick
import QtQuick.Layouts
import ".."
import "../../../services" as Services
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    SettingGroup {
        Layout.fillWidth: true
        title: "Focus"

        SettingRow {
            Layout.fillWidth: true
            key: "input.focusFollowsMouse"
            label: "Focus follows the pointer"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.warpMouseToFocus"
            advanced: true
            label: "Pointer jumps to the focused window"
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Windows"

        SettingRow {
            Layout.fillWidth: true
            key: "windows.noCsd"
            label: "No title bars"
            // Why it is this way: and niri draws none. libadwaita header bars
            // stay: they are program content, not decoration.
            hint: "Asks every program to let the compositor draw the frame."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "windows.defaultWidth"
            label: "How wide a window opens"
            // Why it is this way: niri opens new windows at half the screen and
            // this setting did not exist, so half looked like somebody's
            // decision. It is "simple" rather than advanced because it is the
            // first thing you notice on a fresh machine — he reported it twice.
            hint: "Share of the screen a new window takes. All the way down lets the program choose."
            kind: "slider"
            from: 0; to: 1.0; step: 0.05; decimals: 2
        }
        SettingRow {
            Layout.fillWidth: true
            key: "windows.blurred"
            advanced: true
            label: "Blur behind"
            hint: "App ids, separated by commas. Only worth it for windows transparent enough to show it."
            kind: "picks"
            options: Services.Suggest.appIds
            placeholder: "kitty, org.kde.dolphin"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "windows.floating"
            advanced: true
            label: "Open floating"
            kind: "picks"
            options: Services.Suggest.appIds
            placeholder: "None"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "windows.blockFromScreencast"
            advanced: true
            label: "Hide from screen sharing"
            kind: "picks"
            options: Services.Suggest.appIds
            placeholder: "None"
        }
    }
}
