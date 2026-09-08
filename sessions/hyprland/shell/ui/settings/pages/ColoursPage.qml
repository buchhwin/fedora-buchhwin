// Colours — the palette, the accent, and when the light one takes over.
//
// Split out of the old Appearance page, which carried 55 rows across eight
// groups. Two pages held two thirds of every setting in the shell, and "I
// cannot find anything" was the whole complaint.
import QtQuick
import QtQuick.Layouts
import ".."
import "../../../config"
import "../../../services" as Services
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    readonly property var accents: [
        { value: "rosewater", label: "Rosewater" }, { value: "flamingo", label: "Flamingo" },
        { value: "pink",      label: "Pink" },      { value: "mauve",    label: "Mauve" },
        { value: "red",       label: "Red" },       { value: "maroon",   label: "Maroon" },
        { value: "peach",     label: "Peach" },     { value: "yellow",   label: "Yellow" },
        { value: "green",     label: "Green" },     { value: "teal",     label: "Teal" },
        { value: "sky",       label: "Sky" },       { value: "sapphire", label: "Sapphire" },
        { value: "blue",      label: "Blue" },      { value: "lavender", label: "Lavender" }
    ]

    readonly property var palettes: {
        var out = []
        for (var i = 0; i < Services.Themes.entries.length; i++)
            out.push({ value: Services.Themes.entries[i].name,
                       label: Services.Themes.entries[i].name })
        return out
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Colours"

        SettingRow {
            Layout.fillWidth: true
            key: "theme.palette"
            label: "Palette"
            hint: "The three at the front are calculated: from the wallpaper, from your own colour, and grey."
            kind: "choice"
            choices: root.palettes
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theme.accent"
            label: "Accent"
            hint: "A colour name, not a colour — every palette answers to all fourteen, so switching palette keeps your choice."
            kind: "choice"
            choices: root.accents
            // Fourteen colour NAMES in a dropdown would be fourteen words you
            // have to try one at a time. The colour is the label.
            swatch: true
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theme.customColor"
            label: "Your own colour"
            hint: "Used when the palette is set to \"custom\". A hex value like #7fbbb3."
            kind: "colour"
            // The example you TYPE, not a colour anything is drawn in — a Theme
            // token here would show whatever palette is loaded and teach the
            // wrong format.
            placeholder: "#7fbbb3"   // literal-ok: an example of the format, not a colour in use
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theme.autoLight"
            label: "Light and dark"
            // Why it is this way: Nothing is written when it switches — a
            // service that saved the palette every morning would destroy the
            // dark one.
            hint: "On a schedule, the light palette is used between the two times below."
            kind: "choice"
            choices: [
                { value: "off",      label: "Always dark" },
                { value: "schedule", label: "On a schedule" }
            ]
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theme.lightPalette"
            label: "Light palette"
            kind: "choice"
            choices: root.palettes
            usable: Config.theme.autoLight === "schedule"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theme.lightFrom"
            advanced: true
            label: "Light from"
            kind: "time"
            placeholder: "07:00"
            usable: Config.theme.autoLight === "schedule"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theme.lightUntil"
            advanced: true
            label: "Light until"
            kind: "time"
            placeholder: "19:00"
            usable: Config.theme.autoLight === "schedule"
        }
    }
}
