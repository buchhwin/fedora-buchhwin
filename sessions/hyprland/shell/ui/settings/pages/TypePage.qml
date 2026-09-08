// Type and pointer — the fonts, their size, and the mouse cursor.
//
// ⚠️ THE LISTS HERE COME FROM THE MACHINE. `Services.Installed.scan()` is what
// fills them; without it every one of these rows is a text field you have to
// know the answer to type into. It found 109 fonts and 4 cursor themes on his
// laptop while the window was showing none of them.
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
        title: "Type"

        SettingRow {
            Layout.fillWidth: true
            key: "look.fontUi"
            label: "Interface font"
            kind: "pick"
            options: Services.Installed.fonts
            placeholder: "Inter"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.fontMono"
            label: "Monospace font"
            hint: "Only the fixed-width families, asked of fontconfig rather than kept in a list here."
            kind: "pick"
            options: Services.Installed.monoFonts
            placeholder: "JetBrainsMono Nerd Font"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.fontIcon"
            advanced: true
            label: "Icon font"
            hint: "\"Material Icons Round\", not the Symbols name — the wrong one renders every icon as a box."
            kind: "pick"
            options: Services.Installed.fonts
            placeholder: "Material Icons Round"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.fontSize"
            label: "Font size"
            kind: "slider"
            from: 7; to: 18; step: 1; unit: "pt"
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Pointer"

        SettingRow {
            Layout.fillWidth: true
            key: "cursor.theme"
            label: "Cursor theme"
            hint: "The themes on this machine — a directory under /usr/share/icons or ~/.icons that actually contains cursors."
            kind: "pick"
            options: Services.Installed.cursorThemes
            placeholder: "Adwaita"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "cursor.size"
            advanced: true
            label: "Cursor size"
            kind: "slider"
            from: 12; to: 64; step: 1; unit: "px"
        }
    }
}
