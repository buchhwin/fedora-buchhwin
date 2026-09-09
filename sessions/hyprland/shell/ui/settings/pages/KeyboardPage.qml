// Keyboard — layout, variant, options, and how fast a held key repeats.
//
// ⚠️ THE LAYOUT REACHES THE COMPOSITOR AND NOTHING ELSE. The login screen and the TTY are
// not the session, and the login screen is where the password is typed FIRST —
// the installer sets the system layout separately for exactly that reason.
import QtQuick
import QtQuick.Layouts
import ".."
import "../../../services" as Services
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    Component.onCompleted: Services.Installed.scan()

    SettingGroup {
        Layout.fillWidth: true
        title: "Keyboard"

        SettingRow {
            Layout.fillWidth: true
            key: "keys.mod"
            label: "Mod key"
            // Why the list is not longer: Ctrl is what programs use for their
            // own shortcuts and Shift is for typing, so either as the desktop's
            // modifier collides on every second key.
            hint: "Super is the one modifier no program claims for itself."
            kind: "choice"
            choices: [
                { value: "Super", label: "Super" },
                { value: "Alt",   label: "Alt" },
                { value: "Mod3",  label: "Mod3" },
                { value: "Mod5",  label: "Mod5" }
            ]
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.keyboard.layout"
            label: "Layout"
            hint: "The xkb layouts this machine knows, read from its own rules file."
            kind: "pick"
            options: Services.Installed.keyboardLayouts
            placeholder: "de"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.keyboard.variant"
            advanced: true
            label: "Variant"
            kind: "pick"
            options: Services.Installed.keyboardVariants
            placeholder: "none"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.keyboard.options"
            advanced: true
            label: "XKB options"
            hint: "Comma-separated, e.g. compose:ralt."
            kind: "pick"
            options: Services.Installed.keyboardOptions
            placeholder: "none"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.keyboard.repeatDelay"
            advanced: true
            label: "Repeat delay"
            hint: "How long a key is held before it starts repeating."
            kind: "slider"
            from: 100; to: 1000; step: 10; unit: "ms"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.keyboard.repeatRate"
            advanced: true
            label: "Repeat rate"
            kind: "slider"
            from: 5; to: 100; step: 1; unit: "/s"
        }
    }
}
