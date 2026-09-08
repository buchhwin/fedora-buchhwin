// The dock — which programs, which edge, and which of its three shapes.
//
// ⚠️ EVERY KEY HERE HAS A READER IN ui/dock/DockSurface.qml, and that sentence
// is the whole reason this page can exist. A `dock` block was in Config once
// before and migration 3 → 4 deleted it, because "not one key of it was ever
// read" — iconSize, pinned, monitors and an on/off switch describing a dock
// that had not been built. tests/key-readers.sh is what stops that happening
// twice.
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
        title: "Dock"

        SettingRow {
            Layout.fillWidth: true
            key: "dock.enabled"
            label: "Show the dock"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "dock.mode"
            label: "Shape"
            // Why it is this way: his three descriptions are two questions —
            // how wide is it, and is it detached from the edge. Floating is the
            // second question and is its own switch below, so that a full-width
            // bar with a margin round it stays possible.
            hint: "A taskbar reserves its space; a dock floats over what is behind it."
            kind: "choice"
            choices: [
                { value: "dock",    label: "Dock" },
                { value: "taskbar", label: "Taskbar" }
            ]
        }
        SettingRow {
            Layout.fillWidth: true
            key: "dock.position"
            label: "Edge"
            kind: "choice"
            choices: [
                { value: "bottom", label: "Bottom" },
                { value: "left",   label: "Left" },
                { value: "right",  label: "Right" }
            ]
        }
        SettingRow {
            Layout.fillWidth: true
            key: "dock.floating"
            label: "Detached from the edge"
            hint: "A margin all round, and fully rounded corners."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "dock.pinned"
            label: "Pinned programs"
            // Why it is this way: desktop entry ids rather than names, because
            // `org.gnome.Nautilus` is stable and "Files" is a translation. A pin
            // for something that is not installed stays visible on purpose —
            // dropping it would lose the entry the moment a package is removed.
            hint: "In the order they are shown."
            kind: "picks"
            options: Services.Suggest.desktopIds
            placeholder: "Nothing pinned"
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Behaviour"

        SettingRow {
            Layout.fillWidth: true
            key: "dock.autohide"
            advanced: true
            // Why it is this way: off is what he asked for. A dock that hides is
            // a dock you go looking for, and the pointer trip costs more than
            // the pixels it saves.
            label: "Hide until the pointer reaches the edge"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "dock.showRunning"
            advanced: true
            label: "Also show what is running"
            hint: "Open programs that are not pinned appear after the pinned ones."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "dock.size"
            advanced: true
            label: "Thickness"
            // Why it is this way: one key rather than two — it is the same
            // measurement seen from a different edge, height at the bottom and
            // width at the sides.
            hint: "Height at the bottom, width at the sides."
            kind: "slider"
            from: 36; to: 96; step: 2; unit: "px"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "dock.iconSize"
            advanced: true
            label: "Icon size"
            kind: "slider"
            from: 16; to: 64; step: 2; unit: "px"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "dock.monitors"
            advanced: true
            label: "Screens"
            hint: "Empty means every screen."
            kind: "picks"
            options: Services.Suggest.monitors
            placeholder: "Every screen"
        }
    }
}
