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
            key: "notch.shape"
            label: "Shape"
            hint: "A notch hangs from the top edge; a pill floats below it with a gap of its own."
            kind: "choice"
            choices: [
                { value: "notch", label: "Notch" },
                { value: "pill",  label: "Pill" }
            ]
        }

        SettingRow {
            Layout.fillWidth: true
            key: "notch.enabled"
            advanced: true
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
            advanced: true
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
            hint: "the compositor already owns the top-left corner for its overview; choosing left or both switches that off."
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
            hint: "0 switches them off and creates no surfaces at all. The compositor cannot round the display itself."
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

    // ⚠️ TWO ROWS ARRIVED FROM THE DELETED CONTROL CENTER PAGE. Both are about
    // OUR OWN surfaces, which is what the rest of this page is about — the
    // readouts that slide in over the desktop, and how much the quick panel
    // shows before you ask it for more. The page they came from was cut because
    // everything else on it was tuning for machinery that has one sensible
    // setting; these two are choices about what you see.
    SettingGroup {
        Layout.fillWidth: true
        title: "Panels and readouts"

        SettingRow {
            Layout.fillWidth: true
            // ⚠️ ADVANCED, and not because it is obscure. The panel carries its
            // own fold — this row is the same switch reached the long way round,
            // and on the simple level it pushed this page to seven open rows.
            // A "Show more" in front of a wall is still a wall.
            //
            // ⚠️ AND THE MARK GOES DIRECTLY UNDER THE KEY, with nothing between
            // them. tests/setting-rows.sh insists on that and it is right: the
            // level belongs to the ROW, and anywhere else it is a property of
            // nothing. It caught this comment sitting in the gap.
            // ⚠️ B74 · THE WORDING CHANGED WITH THE MEANING. The key used to BE
            // the fold, so "Show every tile" described what you would see. It is
            // now the fold's STARTING position — the panel's own button moves a
            // runtime value and the setting is only consulted when the panel is
            // built. A label that still promised "show every tile" would be a
            // switch that appears not to work the moment he folds the panel by
            // hand, which is the class of report this whole round is made of.
            key: "quick.showMore"
            advanced: true
            label: "Start with every tile shown"
            hint: "Off opens the panel folded. The panel's own Show more button is not remembered."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "surfaces.osd"
            label: "Show volume and brightness"
            // Why it is this way: It hides the island while it is up and gives
            // it back afterwards — that is the macOS behaviour asked for, not
            // a bug.
            hint: "The pill that appears under the island when a hardware key is pressed."
        }
    }
}
