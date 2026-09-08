pragma ComponentBehavior: Bound

// The theme menu: every palette on offer, each card drawn in the palette it
// offers.
//
// Reference: 2026-08-06/vorlage-theme-menue.png — three columns, a short bar in
// that palette's accent across the top of each card, the name under it, the
// active one ringed in the accent, the next row cut off so it reads as
// scrollable, and a header that says only "Theme".
//
// ⚠️ THE COLOURS ARE READ OUT OF THE FILES. Eleven hex values typed into this
// page would be exactly the mistake the menu is selling against: the palettes
// would drift from their own preview, and the twelfth palette somebody drops
// into theme/palettes/ would appear as a grey box. Each card owns a FileView on
// its own JSON and paints itself from it.
//
// ⚠️ AND THAT IS ALSO WHY THE LOADING LIVES HERE RATHER THAN IN THE SERVICE.
// Services.Themes lists names; holding all eleven palettes' 26 colours would
// keep eleven files' worth of state alive for the whole session so that a menu
// could look right for the four seconds it is open. A card exists only while
// the page does, and its FileView goes with it.
//
// ⚠️ A CARD IS NOT `Pill` OR `Tile`. Both of those paint themselves from the
// ACTIVE theme's tokens, which is right everywhere else and wrong here: the
// entire point is that a card does not look like the rest of the shell. This is
// the one file in ui/ allowed to take colours from somewhere other than Theme,
// and tests/no-literals.sh is untroubled by it because there are still no
// literals — the values come from a file at run time.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../theme"
import "../../../config"
import "../../../ipc"
import "../../../services" as Services
import "../../common"

ColumnLayout {
    id: root
    spacing: Theme.space3

    // Three columns, and the width follows from them rather than the other way
    // round — the reference's grid is what sets the size of this page.
    readonly property int columns: 3
    readonly property int cardW: Theme.space6 * 5
    readonly property int cardH: Theme.space6 * 3
    implicitWidth: root.columns * root.cardW
                   + (root.columns - 1) * Theme.space2

    BarText {
        Layout.fillWidth: true
        text: "Theme"
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
    }

    BarText {
        Layout.fillWidth: true
        visible: !Services.Themes.available
        text: "No palettes found"
        color: Theme.fgMuted
        horizontalAlignment: Text.AlignHCenter
    }

    GridView {
        id: grid
        visible: Services.Themes.available
        Layout.fillWidth: true
        // ⚠️ TWO AND A HALF ROWS, and the half is the point. The reference cuts
        // the next row off, which is what tells you there is more without a
        // scrollbar having to say so. A whole number of rows looks like the
        // whole list.
        Layout.preferredHeight: root.cardH * 2.5 + Theme.space2 * 2
        cellWidth: root.cardW + Theme.space2
        cellHeight: root.cardH + Theme.space2
        clip: true
        focus: true
        // A plain array of { name, path, derived } — the menu shows more than
        // the folder, so it cannot be the FolderListModel itself. See
        // services/Themes.qml.
        model: Services.Themes.entries

        // Where the cursor starts: on the palette in force, not on the first
        // one alphabetically. Arrow keys then move from where you already are.
        //
        // ⚠️ A `Binding` WITH `restoreMode: NotRestoreBinding`, not
        // `Component.onCompleted`. It was onCompleted, and it ran before the
        // FolderListModel had finished listing the directory — so the search
        // walked an empty list, found nothing, and left the cursor on index 0
        // while the shell was on a completely different palette. A one-shot at
        // startup cannot wait for something asynchronous.
        //
        // NotRestoreBinding because this only ever SETS a starting point:
        // without it the arrow keys would be fighting a binding that keeps
        // pulling the cursor back to the current palette.
        Binding on currentIndex {
            value: Services.Themes.currentIndex
            restoreMode: Binding.RestoreNone
        }

        Keys.onEscapePressed: Ipc.collapse()
        Keys.onReturnPressed: grid.pick(grid.currentIndex)
        Keys.onEnterPressed: grid.pick(grid.currentIndex)

        function pick(i) {
            var e = Services.Themes.entries[i]
            if (!e) return
            Services.Themes.choose(e.name)
        }

        delegate: Item {
            id: cell
            required property int index
            required property var modelData

            width: root.cardW
            height: root.cardH

            readonly property string paletteName: cell.modelData.name
            readonly property bool isCurrent:
                cell.paletteName === Services.Themes.current

            // The palette's own 26 colours, or an empty object until the file
            // has been read. `printErrors: false` because a malformed JSON
            // somebody dropped in the folder must not fill the journal — it
            // shows as a card with no colours, which is the honest answer.
            //
            // ⚠️ `hues`, NOT `palette`. `Item` already has a `palette` — it is
            // QQuickItem's, for Qt's own control colours — and shadowing it made
            // Qt warn on every single start: "Member palette of the object
            // QQuickItem_QML_132 overrides a member of the base object." The
            // same trap ui/quick/Tile.qml names about `enabled`, walked into
            // from the other side a week later. Found by an audit axis whose
            // whole rule is that a clean start prints nothing.
            property var hues: ({})

            FileView {
                // ⚠️ A derived palette that has never been calculated has no
                // file yet — choose "custom" for the first time and it is
                // written on the way in. Until then this finds nothing, `hue()`
                // falls back, and the card is drawn in the ACTIVE theme rather
                // than in its own. That is the honest answer: there is no
                // "custom" to preview until there is one.
                path: cell.modelData.path
                printErrors: false
                onLoaded: {
                    try {
                        var d = JSON.parse(text())
                        cell.hues = d.colors || ({})
                    } catch (e) {
                        cell.hues = ({})
                    }
                }
            }

            // ⚠️ Every read goes through here, and every one has a fallback. A
            // palette missing a name would otherwise paint `undefined`, which
            // QML renders as transparent black — a card that looks like a hole.
            function hue(name, fallback) {
                var v = cell.hues[name]
                return v ? "#" + v : fallback
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMd
                // `base` is the palette's window background — the colour the
                // desktop would actually be. `mantle` and `crust` are the two
                // steps darker, used for panels and shadows.
                color: cell.hue("base", Theme.surface)

                // The cursor and the choice are different marks, deliberately:
                // "which one am I on" and "which one am I using" are different
                // questions, and one border cannot answer both. The ring is the
                // choice; the cursor is the lighter outline underneath it.
                border.width: cell.isCurrent ? Theme.space1 / 2
                            : cell.index === grid.currentIndex ? Theme.space1 / 4
                            : 0
                border.color: cell.isCurrent ? Theme.accent : Theme.outline

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.space2
                    spacing: Theme.space2

                    // The short bar of that palette's accent, from the
                    // reference. It is drawn in the accent the USER has chosen
                    // — `Config.theme.accent` is a colour NAME ("green"), and
                    // every palette has all of them, so the same choice reads
                    // across every card.
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Theme.space2
                        radius: Theme.radiusPill
                        color: cell.hue(Config.theme ? Config.theme.accent : "green",
                                        Theme.accent)
                    }

                    Item { Layout.fillHeight: true }

                    Text {
                        Layout.fillWidth: true
                        text: cell.paletteName
                        // ⚠️ `Text`, not `BarText`, and the palette's own `text`
                        // colour rather than Theme.fg — this is the one place a
                        // light palette has to look light. `e-ink` sitting pale
                        // among ten dark cards is the reference's own example
                        // of the menu working.
                        color: cell.hue("text", Theme.fg)
                        // `fontUi` — there is no `fontFamily` token, and QML
                        // answers an unknown one with `undefined` rather than an
                        // error, so this drew in whatever font Qt felt like and
                        // logged "Unable to assign [undefined] to QString" once
                        // per card. Same shape of mistake as `root.quickSettings`
                        // in the IPC handler, one day earlier.
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fontSizeSm
                        font.weight: Theme.weightMedium
                        elide: Text.ElideRight
                    }
                }

                TapHandler {
                    onTapped: {
                        grid.currentIndex = cell.index
                        grid.pick(cell.index)
                    }
                }
            }
        }
    }
}
