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
            // Why it is this way: and the compositor draws none. libadwaita header bars
            // stay: they are program content, not decoration.
            hint: "Asks every program to let the compositor draw the frame."
        }
        // ⚠️ A ROW FOR `windows.defaultWidth` STOOD HERE, and it said the same
        // thing as the layout split. In Hyprland's master layout the fraction
        // a new window takes IS master.mfact, which Size & Shape already
        // drives. Two controls for one number is how they end up disagreeing.
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
