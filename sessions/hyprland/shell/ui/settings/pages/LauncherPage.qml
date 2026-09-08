// Launcher — the program list, and the one surface that opens in the MIDDLE of
// the screen rather than at the island.
//
// That is why it has a fixed size while the island's pages are as big as their
// contents: those are short, a program list is not, and a launcher that changes
// shape while you type is a moving target.
import QtQuick
import QtQuick.Layouts
import ".."
import "../../../config"
import "../../../services" as Services
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    SettingGroup {
        Layout.fillWidth: true
        title: "Launcher"

        SettingRow {
            Layout.fillWidth: true
            key: "launcher.enabled"
            label: "Launcher"
            // Why it is this way: a machine with the island switched off still
            // has to be able to start a program.
            hint: "Mod+D or Mod+Space. It does not depend on the island being on."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "launcher.width"
            label: "Width"
            kind: "slider"
            from: 400; to: 1400; step: 1; unit: "px"
            usable: Config.launcher.enabled
        }
        SettingRow {
            Layout.fillWidth: true
            key: "launcher.height"
            label: "Height"
            kind: "slider"
            from: 240; to: 900; step: 1; unit: "px"
            usable: Config.launcher.enabled
        }
        SettingRow {
            Layout.fillWidth: true
            key: "launcher.monitors"
            label: "Screens"
            kind: "picks"
            options: Services.Suggest.monitors
            placeholder: "Every screen"
            usable: Config.launcher.enabled
        }
    }
}
