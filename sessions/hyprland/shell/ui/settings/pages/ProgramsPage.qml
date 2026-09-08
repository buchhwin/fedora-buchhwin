// Programs — which terminal, browser and editor the keys and the shell reach
// for, and how the terminal itself behaves.
//
// ⚠️ THESE ARE ARGUMENT LISTS, NOT COMMAND LINES. `@terminal` in a keybinding
// resolves through them, so an entry is a program followed by its arguments —
// which is why they are comma-separated rather than a single string.
import QtQuick
import QtQuick.Layouts
import ".."
import "../../../config"
import "../../../services" as Services
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    // These six were free text boxes, on a page whose entire subject is "which
    // installed program". `Services.Suggest.programs()` puts the ones that fit
    // the job first and keeps the rest — see the note there for why it orders
    // rather than filters.
    Component.onCompleted: Services.Installed.scan()

    SettingGroup {
        Layout.fillWidth: true
        title: "Programs"

        // ⚠️ ARGUMENT LISTS, NOT COMMAND LINES. niri's `spawn` takes one string
        // per argument, so a whole command line in one string makes it look for
        // a binary with spaces in its name — and it fails with a message that
        // does not mention the real cause. A comma is the separator here for
        // exactly that reason.
        SettingRow {
            Layout.fillWidth: true
            key: "programs.terminal"
            label: "Terminal"
            // Why it is this way: One argument per comma — niri's spawn takes
            // them apart, so a whole command line in one box would look for a
            // binary with spaces in its name.
            hint: "The program, and its arguments underneath."
            kind: "command"
            options: Services.Suggest.programs(["System", "Utility"])
            placeholder: "kitty"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "programs.browser"
            label: "Browser"
            kind: "command"
            options: Services.Suggest.programs(["Network"])
            placeholder: "brave-browser"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "programs.fileManager"
            label: "File manager"
            kind: "command"
            options: Services.Suggest.programs(["System", "Utility"])
            placeholder: "dolphin"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "programs.editor"
            label: "Editor"
            kind: "command"
            options: Services.Suggest.programs(["Development", "Utility", "Office"])
            placeholder: "code"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "programs.imageViewer"
            label: "Image viewer"
            kind: "command"
            options: Services.Suggest.programs(["Graphics"])
            placeholder: "gwenview"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "programs.video"
            label: "Video player"
            kind: "command"
            options: Services.Suggest.programs(["AudioVideo", "Video"])
            placeholder: "vlc"
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Terminal"

        // ⚠️ These four are BEHAVIOUR, not colour, and they are the first of
        // their kind — see the note on `terminal` in config/Config.qml. They
        // are written into the file kitty already includes, so they arrive with
        // the palette rather than needing a second include.
        SettingRow {
            Layout.fillWidth: true
            key: "terminal.cursorShape"
            advanced: true
            label: "Cursor shape"
            kind: "choice"
            choices: [
                { value: "beam",      label: "Beam" },
                { value: "block",     label: "Block" },
                { value: "underline", label: "Underline" }
            ]
        }
        SettingRow {
            Layout.fillWidth: true
            key: "terminal.cursorBlinkInterval"
            advanced: true
            label: "Cursor blink"
            hint: "Seconds. 0 stops it blinking."
            kind: "slider"
            from: 0; to: 2.0; step: 0.1; decimals: 1; unit: "s"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "terminal.cursorTrail"
            advanced: true
            label: "Cursor trail"
            // Why it is this way: this is the animation, and it needs kitty
            // 0.36 or newer.
            hint: "How many cells the cursor may fall behind before it catches up in one sweep. 0 is off."
            kind: "slider"
            from: 0; to: 10; step: 1
        }
        SettingRow {
            Layout.fillWidth: true
            key: "terminal.scrollbackLines"
            advanced: true
            label: "Scrollback"
            hint: "Lines kept above the top of the window."
            kind: "slider"
            from: 1000; to: 100000; step: 1000
        }
        SettingRow {
            Layout.fillWidth: true
            key: "terminal.shellIntegration"
            advanced: true
            label: "Shell integration"
            // Why it is this way: that is what makes jump-to-prompt work and
            // what opens the scrollback pager at the right line instead of at
            // the top.
            hint: "Lets kitty see where each command starts and ends."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "terminal.remoteControl"
            advanced: true
            label: "Remote control"
            // Why it is this way: the predecessor called it the single biggest
            // quality-of-life win when you live in SSH sessions. Either line
            // alone does nothing.
            hint: "Turns on allow_remote_control AND listen_on together, which is what the ssh kitten needs."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "terminal.scrollbackPager"
            advanced: true
            label: "Scrollback in a pager"
            hint: "Ctrl+Shift+H hands the scrollback to less rather than scrolling it in place."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "terminal.audibleBell"
            advanced: true
            label: "Audible bell"
            hint: "Off. A terminal that beeps in an office is somebody else's problem."
        }
    }
}
