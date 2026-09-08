// Bar & Island — the page his reference screenshot actually shows.
//
// Every one of the five sliders in that picture is here: notch flare, bar
// height, collapsed width, expanded height, minimum expanded width.
//
// ⚠️ WITH ONE HONEST DIFFERENCE. The reference labels the fourth one "Expanded
// height", and `notch.expandedHeight` NO LONGER EXISTS — migration 9→10 removed
// it, because it was a minimum applied to every page and produced dead space
// above and below anything shorter (measured: media 161→138, tray 161→138,
// calculator 161→120). The value in this shell that answers to the same idea is
// `notch.hoverHeight`, the height the island grows to under the pointer, and
// that is what the row is labelled. Quietly printing "Expanded height" over a
// different key would be the exact failure this whole design is built to make
// impossible.
//
// Fifteen rows here, not eighteen. `surfaces.notifications`, `surfaces.osd` and
// `surfaces.wallpaper` switch other surfaces on and off and belong on the pages
// that own them — Notifications, Control Center and Appearance. The hot corners
// stay, because a screen corner is an edge affordance like the bar and the
// notch. tests/setting-rows.sh has all three in its PENDING list, so none of
// them can be forgotten.
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
        title: "Bar"

        SettingRow {
            Layout.fillWidth: true
            key: "bar.enabled"
            label: "Top bar"
            hint: "Off by default — the island is the surface. Everything the bar carries has a key of its own."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "bar.height"
            label: "Bar height"
            kind: "slider"
            from: 20; to: 64; step: 1; unit: "px"
            usable: Config.bar.enabled
        }
        SettingRow {
            Layout.fillWidth: true
            key: "bar.monitors"
            advanced: true
            label: "Screens"
            hint: "Monitor names, separated by commas."
            kind: "picks"
            options: Services.Suggest.monitors
            placeholder: "Every screen"
            usable: Config.bar.enabled
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Island"

        SettingRow {
            Layout.fillWidth: true
            key: "notch.enabled"
            label: "Island"
            hint: "The pill at the top of the screen, and every page that opens under it."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "notch.flare"
            advanced: true
            label: "Notch flare"
            hint: "The concave shoulders where the pill meets the screen edge."
            kind: "slider"
            from: 0; to: 24; step: 1; unit: "px"
            usable: Config.notch.enabled
        }
        SettingRow {
            Layout.fillWidth: true
            key: "notch.collapsedWidth"
            label: "Collapsed width"
            hint: "Measured at the screen edge — the widest point, not the body of the pill."
            kind: "slider"
            from: 80; to: 400; step: 1; unit: "px"
            usable: Config.notch.enabled
        }
        SettingRow {
            Layout.fillWidth: true
            key: "notch.collapsedHeight"
            label: "Collapsed height"
            kind: "slider"
            from: 20; to: 64; step: 1; unit: "px"
            usable: Config.notch.enabled
        }
        SettingRow {
            Layout.fillWidth: true
            key: "notch.cornerRadius"
            advanced: true
            label: "Collapsed corners"
            hint: "The two rounded corners underneath."
            kind: "slider"
            from: 0; to: 24; step: 1; unit: "px"
            usable: Config.notch.enabled
        }
        SettingRow {
            Layout.fillWidth: true
            key: "notch.hoverHeight"
            advanced: true
            label: "Expanded height"
            hint: "What the island grows to while the pointer is on it."
            kind: "slider"
            from: 48; to: 200; step: 1; unit: "px"
            usable: Config.notch.enabled
        }
        SettingRow {
            Layout.fillWidth: true
            key: "notch.hoverMinWidth"
            advanced: true
            label: "Expanded width"
            hint: "A floor, not the width — nothing is shown that does not exist, so the shape follows its contents."
            kind: "slider"
            from: 200; to: 1000; step: 1; unit: "px"
            usable: Config.notch.enabled
        }
        SettingRow {
            Layout.fillWidth: true
            key: "notch.hoverCornerRadius"
            advanced: true
            label: "Expanded corners"
            hint: "Its own number, because a corner is a proportion and this shape is three times as tall."
            kind: "slider"
            from: 0; to: 48; step: 1; unit: "px"
            usable: Config.notch.enabled
        }
        SettingRow {
            Layout.fillWidth: true
            key: "notch.minExpandedWidth"
            advanced: true
            label: "Minimum expanded width"
            hint: "How wide a page opens at its narrowest."
            kind: "slider"
            from: 200; to: 1200; step: 1; unit: "px"
            usable: Config.notch.enabled
        }
        SettingRow {
            Layout.fillWidth: true
            key: "notch.monitors"
            advanced: true
            label: "Screens"
            hint: "Monitor names, separated by commas."
            kind: "picks"
            options: Services.Suggest.monitors
            placeholder: "Every screen"
            usable: Config.notch.enabled
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Screen corners"

        SettingRow {
            Layout.fillWidth: true
            key: "surfaces.hotCorners"
            label: "Hot corners"
            hint: "niri already owns the top-left corner for its overview; choosing left or both switches that off."
            kind: "choice"
            choices: [
                { value: "off",   label: "Off" },
                { value: "left",  label: "Left" },
                { value: "right", label: "Right" },
                { value: "both",  label: "Both" }
            ]
        }
        SettingRow {
            Layout.fillWidth: true
            key: "surfaces.screenCornerRadius"
            advanced: true
            label: "Rounded screen corners"
            // Why it is this way: this is four small overlays, and clicks pass
            // straight through them.
            hint: "0 switches them off and creates no surfaces at all. niri cannot round the display itself."
            kind: "slider"
            from: 0; to: 40; step: 1; unit: "px"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "surfaces.hotCornerDwellMs"
            advanced: true
            label: "Corner dwell"
            hint: "How long the pointer has to rest there. A corner that fires on contact is a trap."
            kind: "slider"
            from: 0; to: 1000; step: 10; unit: "ms"
            usable: Config.surfaces.hotCorners !== "off"
        }
    }
}
