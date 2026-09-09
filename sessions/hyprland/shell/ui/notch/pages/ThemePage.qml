pragma ComponentBehavior: Bound

// The theme picker: every palette on offer, each tile drawn in its own colours.
//
// From his screenshot of 09.09.2026 — a search field and a counter on one line,
// a horizontal row of tiles below it, each showing a handful of that palette's
// colours as dots with the name under them, the selected one visibly larger and
// ringed in the accent, and "Enter to apply" at the foot. The row wraps.
//
// ⚠️ THE ROW ITSELF IS common/CarouselPicker.qml, and that is the point rather
// than a convenience. He sent the wallpaper picture with the words "genau so    // english-ok: the request, quoted
// für wallpaper switcher", so the two are one component with different tiles —  // english-ok: same
// a near-copy would drift the first time either was adjusted, which is rule 6.
// This file owns the tile, the filtering and what "apply" means for a palette.
//
// ⚠️ THE COLOURS ARE READ OUT OF THE FILES. Hex values typed into this page
// would be exactly the mistake the picker is selling against: the palettes
// would drift from their own preview, and the next palette dropped into
// theme/palettes/ would appear as a grey box. Each tile owns a FileView on its
// own JSON and paints itself from it.
//
// ⚠️ AND THAT IS ALSO WHY THE LOADING LIVES HERE RATHER THAN IN THE SERVICE.
// Services.Themes lists names; holding every palette's 26 colours would keep
// that much state alive for the whole session so a menu could look right for
// the four seconds it is open. A tile exists only while the page does, and its
// FileView goes with it.
//
// ⚠️ A TILE IS NOT `Pill` OR `Tile`. Both paint themselves from the ACTIVE
// theme's tokens, which is right everywhere else and wrong here: the entire
// point is that a tile does not look like the rest of the shell. This is one of
// the two files in ui/ allowed to take colours from somewhere other than Theme,
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

    // ⚠️ THE FILTER IS THIS FILE'S, NOT THE PICKER'S. What "matching" means is a
    // question about palette names; the row only carries the text somebody
    // typed. Matched on the display name as well as the file name, because
    // "Tokyo" is what you would type and `tokyo-night` is what the file is
    // called.
    readonly property var shown: {
        var all = Services.Themes.entries
        var q = picker.query.trim().toLowerCase()
        if (!q.length)
            return all
        var out = []
        for (var i = 0; i < all.length; i++) {
            var e = all[i]
            var hay = (String(e.name) + " " + String(e.displayName || "")).toLowerCase()
            if (hay.indexOf(q) >= 0)
                out.push(e)
        }
        return out
    }

    BarText {
        Layout.fillWidth: true
        visible: !Services.Themes.available
        text: "No palettes found"
        color: Theme.fgMuted
        horizontalAlignment: Text.AlignHCenter
    }

    // ⚠️ IT SAYS SO WHEN THE SEARCH MATCHED NOTHING, rather than showing an
    // empty row. A picker with no tiles and no sentence reads as a picker that
    // failed to load, which is the same fault the quick panel's sections were
    // given words for.
    BarText {
        Layout.fillWidth: true
        visible: Services.Themes.available && root.shown.length === 0
        text: "Nothing matches what you typed"
        color: Theme.fgMuted
        horizontalAlignment: Text.AlignHCenter
    }

    CarouselPicker {
        id: picker
        Layout.fillWidth: true
        Layout.preferredHeight: picker.implicitHeight
        visible: root.shown.length > 0
        focus: true

        model: root.shown
        searchable: true
        headRightText: root.shown.length > 0
                       ? (picker.currentIndex + 1) + "/" + root.shown.length : ""
        footRightText: "Enter to apply"

        onDismissed: Ipc.collapse()
        onApplied: function (i) {
            var e = root.shown[i]
            if (!e) return
            Services.Themes.choose(e.name)
            Ipc.collapse()
        }

        tile: Rectangle {
            id: cell
            // Handed down by name from the picker's delegate — see the note
            // there about `pragma ComponentBehavior: Bound`.
            required property var modelData
            required property int index
            required property bool chosen

            readonly property string paletteName: cell.modelData.name
            readonly property bool isCurrent:
                cell.paletteName === Services.Themes.current

            // ⚠️ `hues`, NOT `palette`. `Item` already has a `palette` — it is
            // QQuickItem's, for Qt's own control colours — and shadowing it made
            // Qt warn on every single start: "Member palette of the object
            // QQuickItem_QML_132 overrides a member of the base object." The
            // same trap ui/quick/Tile.qml names about `enabled`, walked into
            // from the other side a week later.
            property var hues: ({})

            radius: Theme.radiusMd
            // `base` is the palette's window background — the colour the desktop
            // would actually be.
            color: cell.hue("base", Theme.surface)

            FileView {
                // ⚠️ A derived palette that has never been calculated has no
                // file yet — choose "custom" for the first time and it is
                // written on the way in. Until then this finds nothing, `hue()`
                // falls back, and the tile is drawn in the ACTIVE theme rather
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
            // QML renders as transparent black — a tile that looks like a hole.
            function hue(name, fallback) {
                var v = cell.hues[name]
                return v ? "#" + v : fallback
            }

            // ⚠️ THE ONE MARK LEFT ON THE TILE ITSELF IS "IN USE", and it is not
            // the same question as "selected". The picker's ring says where the
            // cursor is; this says which palette the desktop is actually
            // wearing, and a picker where those two cannot be told apart is one
            // you have to apply something in to find out.
            border.width: cell.isCurrent ? Math.max(1, Theme.borderWidth) : 0
            border.color: cell.hue("green", Theme.accent)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.space2
                spacing: Theme.space2

                // The palette as a row of dots, from his screenshot. Seven of
                // the fourteen accent names, spread across the spectrum rather
                // than taken in file order — a preview of six neighbouring reds
                // says nothing about a palette.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space1

                    Repeater {
                        model: ["red", "peach", "yellow", "green",
                                "teal", "blue", "mauve"]

                        Rectangle {
                            required property var modelData
                            implicitWidth: Theme.space3
                            implicitHeight: Theme.space3
                            radius: width / 2   // literal-ok: a circle is half its width
                            color: cell.hue(modelData, Theme.fgDim)
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Item { Layout.fillHeight: true }

                Text {
                    Layout.fillWidth: true
                    text: cell.modelData.displayName || cell.paletteName
                    // ⚠️ `Text`, not `BarText`, and the palette's own `text`
                    // colour rather than Theme.fg — this is the one place a
                    // light palette has to look light. A pale tile sitting among
                    // dark ones is the picker working.
                    color: cell.hue("text", Theme.fg)
                    // `fontUi` — there is no `fontFamily` token, and QML answers
                    // an unknown one with `undefined` rather than an error, so
                    // this drew in whatever font Qt felt like and logged "Unable
                    // to assign [undefined] to QString" once per card.
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fontSizeSm
                    font.weight: Theme.weightMedium
                    elide: Text.ElideRight
                }
            }
        }
    }
}
