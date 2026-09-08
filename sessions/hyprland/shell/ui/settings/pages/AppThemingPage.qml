// Other programs — one state each for the programs we colour.
//
// Three states per program was the brief — follow the scheme, a neutral grey, or
// leave the program alone — and "Follow" makes four: take whatever the default
// above is set to.
//
// ⚠️ IT IS A TABLE NOW, AND THAT WAS HIS CHOICE. As thirteen SettingRows this
// page was a label, an explaining line and a full-width dropdown per program —
// about ninety pixels each, so four of the thirteen fitted on screen and
// "what is kitty set to" was three scrolls away. Every row looked like every
// other row and none of them could be compared with its neighbour, which is
// precisely what a table is for.
//
// ⚠️ THE THIRTEEN ROWS ARE STILL WRITTEN OUT, and the reason has not changed
// with the layout. tools/render.qml reads these names with an explicit switch,
// on purpose; a Repeater here would be the same shortcut on the other side, and
// the moment a name is added in one place and not the other, one program stops
// being themed and nothing says so. They are also one `key:` per line because
// tests/setting-rows.sh anchors on `^ *key:` to count them.
import QtQuick
import QtQuick.Layouts
import ".."
import "../../common"
import "../../../config"
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    readonly property var states: [
        { value: "inherit", label: "Follow" },
        { value: "colour",  label: "Colour" },
        { value: "neutral", label: "Neutral" },
        { value: "off",     label: "Off" }
    ]

    // ⚠️ PINNED, NOT PREFERRED. `Layout.preferredWidth` is a wish, and a
    // neighbour with `fillWidth` takes the space straight back — the settings
    // sidebar was 312/282/243/208 px on four pages for exactly this reason
    // before it was pinned. Taken from the longest name so the column is as
    // narrow as it can be and still hold "fastfetch".
    readonly property int nameWidth: Math.ceil(nameRuler.advanceWidth) + Theme.space2
    TextMetrics {
        id: nameRuler
        font.pixelSize: Theme.fontSize
        font.family: Theme.fontUi
        text: "fastfetch"
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Other programs"

        SettingRow {
            Layout.fillWidth: true
            key: "theming.enabled"
            label: "Theme other programs"
            hint: "Off leaves every foreign config alone and removes the files we wrote."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theming.mode"
            label: "Default state"
            // Why it is this way: Neutral is a grey scheme — themed but
            // colourless; the semantic colours stay coloured.
            hint: "What a program set to \"Follow\" does."
            kind: "choice"
            choices: [
                { value: "colour",  label: "Colour" },
                { value: "neutral", label: "Neutral" },
                { value: "off",     label: "Off" }
            ]
            usable: Config.theming.enabled
        }
    }

    SettingGroup {
        id: table
        Layout.fillWidth: true
        title: "Each program"

        // ⚠️⚠️ "SET ALL" READS THE ROWS, IT DOES NOT KEEP ITS OWN LIST. A second
        // list of the thirteen names is a second thing to forget: add a
        // fourteenth program, miss it here, and "all to Neutral" quietly leaves
        // one program coloured — the same one-sided drift the explicit switch in
        // render.qml exists to prevent. This sets the key of every row that is
        // actually on the page, so the two cannot disagree.
        //
        // ⚠️ IT WALKS THE TREE RATHER THAN THE GROUP'S OWN CHILDREN, measured
        // rather than assumed: a SettingGroup's default property is an alias
        // into the card's inner layout, so `group.children` holds 2 items — the
        // heading and the card — while the fourteen rows are one level further
        // in. A walk does not have to know that.
        //
        // ⚠️ AND IT MATCHES ON `programRow`, which ThemingRow declares for this
        // one purpose. The two obvious discriminators are both wrong: `states`
        // is a property of EVERY QML Item, so it separates nothing, and the
        // "theming." prefix also catches `theming.enabled` and `theming.mode` —
        // a switch and the default state. Today those two live in another group
        // and would be out of reach anyway, which is exactly the kind of safety
        // that disappears the day somebody rearranges the page.
        //
        // ⚠️ The walk is a plain JS closure rather than a QML method calling
        // itself through its own id: written that way, `table.collect` resolved
        // to the SettingGroup instead of to the method and the call threw. A
        // throw inside a QML function abandons the rest of it in silence — the
        // thirteen writes would simply not happen, and nothing would say so.
        function setAll(value) {
            var keys = []
            var walk = function (obj) {
                if (!obj)
                    return
                if (obj.programRow === true && obj.key !== undefined)
                    keys.push(String(obj.key))
                var kids = obj.children === undefined ? [] : obj.children
                for (var i = 0; i < kids.length; i++)
                    walk(kids[i])
                var d = obj.data === undefined ? [] : obj.data
                for (var j = 0; j < d.length; j++)
                    if (d[j] !== undefined && kids.indexOf(d[j]) < 0)
                        walk(d[j])
            }
            walk(table)
            for (var k = 0; k < keys.length; k++)
                Config.set(keys[k], value)
            Config.flush()
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.space2
            spacing: Theme.space2

            BarText {
                text: "Set all to"
                color: Theme.fgMuted
                font.pixelSize: Theme.fontSizeSm
            }
            Item { Layout.fillWidth: true }

            Repeater {
                model: root.states

                Pill {
                    id: bulk
                    required property var modelData
                    interactive: Config.theming.enabled
                    BarText {
                        text: bulk.modelData.label
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.fg
                    }
                    onClicked: table.setAll(bulk.modelData.value)
                }
            }
        }

        ThemingRow {
            Layout.fillWidth: true
            key: "theming.gtk"
            label: "GTK"
            // Why it is this way: A running program keeps its colours until
            // you restart it — light/dark and the icon theme do change live,
            // because those go through gsettings.
            hint: "GTK reads our file once, at start."
            states: root.states
            labelWidth: root.nameWidth
            usable: Config.theming.enabled
        }
        ThemingRow {
            Layout.fillWidth: true
            key: "theming.qt"
            label: "Qt"
            states: root.states
            labelWidth: root.nameWidth
            usable: Config.theming.enabled
        }
        ThemingRow {
            Layout.fillWidth: true
            key: "theming.kitty"
            label: "kitty"
            states: root.states
            labelWidth: root.nameWidth
            usable: Config.theming.enabled
        }
        ThemingRow {
            Layout.fillWidth: true
            key: "theming.alacritty"
            label: "Alacritty"
            states: root.states
            labelWidth: root.nameWidth
            usable: Config.theming.enabled
        }
        ThemingRow {
            Layout.fillWidth: true
            key: "theming.btop"
            label: "btop"
            hint: "Ctrl+Shift+Escape opens it."
            states: root.states
            labelWidth: root.nameWidth
            usable: Config.theming.enabled
        }
        ThemingRow {
            Layout.fillWidth: true
            key: "theming.bat"
            label: "bat"
            states: root.states
            labelWidth: root.nameWidth
            usable: Config.theming.enabled
        }
        ThemingRow {
            Layout.fillWidth: true
            key: "theming.fastfetch"
            label: "fastfetch"
            states: root.states
            labelWidth: root.nameWidth
            usable: Config.theming.enabled
        }
        ThemingRow {
            Layout.fillWidth: true
            key: "theming.delta"
            label: "git-delta"
            states: root.states
            labelWidth: root.nameWidth
            usable: Config.theming.enabled
        }
        ThemingRow {
            Layout.fillWidth: true
            key: "theming.tmux"
            label: "tmux"
            states: root.states
            labelWidth: root.nameWidth
            usable: Config.theming.enabled
        }
        ThemingRow {
            Layout.fillWidth: true
            key: "theming.starship"
            label: "starship"
            states: root.states
            labelWidth: root.nameWidth
            usable: Config.theming.enabled
        }
        ThemingRow {
            Layout.fillWidth: true
            key: "theming.lazygit"
            label: "lazygit"
            states: root.states
            labelWidth: root.nameWidth
            usable: Config.theming.enabled
        }
        ThemingRow {
            Layout.fillWidth: true
            key: "theming.vscode"
            label: "VS Code"
            states: root.states
            labelWidth: root.nameWidth
            usable: Config.theming.enabled
        }
        ThemingRow {
            Layout.fillWidth: true
            key: "theming.brave"
            label: "Brave"
            states: root.states
            labelWidth: root.nameWidth
            usable: Config.theming.enabled
        }
        // ⚠️ THE LAST TWO COST SOMETHING THE OTHER THIRTEEN DO NOT, and the
        // rows say so rather than the docs alone: these colour a program whose
        // files we do not own, so an update of THAT program can throw the
        // theming off. He chose them on 06.08. with that on the table.
        ThemingRow {
            Layout.fillWidth: true
            key: "theming.vesktop"
            label: "Discord"
            hint: "Tick the buchhwin theme once under Settings, Themes — Vencord remembers it."
            states: root.states
            labelWidth: root.nameWidth
            usable: Config.theming.enabled
        }
        ThemingRow {
            Layout.fillWidth: true
            key: "theming.spicetify"
            label: "Spotify"
            hint: "Run bhctl theme spotify after a Spotify update to put it back."
            states: root.states
            labelWidth: root.nameWidth
            usable: Config.theming.enabled
        }
    }
}
