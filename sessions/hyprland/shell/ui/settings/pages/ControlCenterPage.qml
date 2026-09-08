// Control Center — the things the quick panel reaches for while you work:
// brightness, night light, the work timer, the on-screen readouts, and the
// clipboard.
//
// The panel itself keeps the switches you press every day. This page is where
// the numbers behind them live — how warm the night light goes, how many
// clipboard entries are listed, whether an external monitor is followed live.
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
        title: "Quick panel"

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
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "On-screen readouts"

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

    SettingGroup {
        Layout.fillWidth: true
        title: "Brightness"

        SettingRow {
            Layout.fillWidth: true
            key: "brightness.external"
            label: "External monitors over DDC/CI"
            // Why it is this way: The package brings its own udev rule with
            // TAG+=uaccess, so this needs no group and no permission change.
            hint: "Talks to the monitor over the graphics cable."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "brightness.externalLive"
            advanced: true
            label: "Follow the slider live"
            // Why it is this way: DDC/CI is slow, and a value per frame queues
            // up behind itself — this has never been measured on a real
            // monitor, so off is the honest default.
            hint: "Off sends one value when you let go."
            usable: Config.brightness.external
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Night light"

        SettingRow {
            Layout.fillWidth: true
            key: "nightlight.on"
            label: "Night light"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "nightlight.temperature"
            advanced: true
            label: "Colour temperature"
            hint: "Lower is warmer. 6500 K is daylight; below about 3000 K everything goes orange."
            kind: "slider"
            from: 1000; to: 6500; step: 100; unit: "K"
            usable: Config.nightlight.on
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Work timer"

        SettingRow {
            Layout.fillWidth: true
            key: "timer.presets"
            label: "Preset lengths"
            // Why it is this way: They are stored as text on purpose —
            // JsonAdapter does not deserialise a list of numbers at all, and
            // does it silently.
            hint: "Minutes, separated by commas."
            kind: "picks"
            options: Services.Suggest.durations
            placeholder: "5, 15, 25, 60"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "timer.sound"
            label: "Sound when it ends"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "timer.soundFile"
            advanced: true
            label: "Sound file"
            kind: "pick"
            options: Services.Suggest.sounds
            placeholder: "/usr/share/sounds/…"
            usable: Config.timer.sound
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Clipboard"

        SettingRow {
            Layout.fillWidth: true
            key: "clipboard.visibleRows"
            advanced: true
            label: "Entries shown"
            hint: "How many rows the clipboard history opens at. Everything is kept either way."
            kind: "slider"
            from: 3; to: 20; step: 1
        }

        SettingRow {
            Layout.fillWidth: true
            key: "disks.automount"
            label: "Mount removable drives automatically"
            // Why it is this way: this only decides whether it asks.
            hint: "Off means the drive appears in the panel and waits. udisks2 does the mounting either way."
            kind: "switch"
        }
    }
}
