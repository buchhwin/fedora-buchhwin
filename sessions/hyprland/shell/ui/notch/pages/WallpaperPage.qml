pragma ComponentBehavior: Bound

// Choosing a wallpaper, as a page of the island.
//
// It was a full-screen window first. It is not one any more, and the reason is
// the rule the whole shell is built on: the island does not summon a second
// window, it BECOMES the thing you asked for. A grid that darkens the screen
// and floats in the middle is a different program wearing our colours.
//
// ⚠️ THREE COLUMNS, AND IT USED TO BE ONE SIDEWAYS ROW. The old header argued
// for the row — "the island is wide and short, and a shape that grows sideways
// from a shape that is already wide reads as one movement" — and the reference
// (2026-08-06/vorlage-wallpaper-raster.png) says otherwise, for a reason the
// argument missed: a row shows four covers and hides the rest behind a scroll
// nobody can see the end of. Twelve wallpapers in a row is eight you have to go
// looking for. The grid shows nine at once with the tenth peeking, which is what
// tells you there are more without a scrollbar having to say so.
//
// ⚠️ THE SAME SHAPE AS ThemePage, deliberately. They are the two pages that
// answer "how should everything look", they sit under adjacent keys
// (Mod+Shift+W and Mod+Shift+A), and two grids that scrolled differently would
// be two things to learn instead of one.
//
// Keyboard first — arrows move, Enter chooses, Escape closes — because a picker
// you have to aim at is a picker you stop using.
import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../config"
import "../../../ipc"
import "../../../services" as Services
import "../../common"

ColumnLayout {
    id: root
    spacing: Theme.space3

    readonly property int columns: 3
    readonly property int coverW: Theme.space6 * 5
    // 16:9, because wallpapers are.
    readonly property int coverH: Math.round(coverW * 9 / 16)

    implicitWidth: root.columns * root.coverW
                   + (root.columns - 1) * Theme.space2

    // ------------------------------------------------------------- the header
    // "Wallpaper" left, the palette in force small and grey on the right — from
    // the reference, and it earns its place: the two are bound together. Choosing
    // an image while the theme is set to "wallpaper" recalculates every colour on
    // the desktop, and choosing one while it is set to "gruvbox" changes only the
    // picture. This line is the difference, on screen, before you click.
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space3

        BarText {
            text: "Wallpaper"
            font.pixelSize: Theme.fontSizeSm
            color: Theme.fgMuted
        }

        Item { Layout.fillWidth: true }

        BarText {
            text: Config.theme ? Config.theme.palette : ""
            font.pixelSize: Theme.fontSizeSm
            color: Theme.fgDim
            elide: Text.ElideRight
            Layout.maximumWidth: Theme.space6 * 4
        }
    }

    // An empty state is one sentence that says what to do about it, never an
    // empty box or a spinner.
    BarText {
        Layout.fillWidth: true
        visible: !Services.Wallpaper.available
        color: Theme.fgMuted
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: Config.wallpaper.folder.length === 0
              ? "No picture folder set — wallpaper.folder in shell.json"
              : "No supported images in that folder"
    }

    GridView {
        id: grid
        visible: Services.Wallpaper.available
        Layout.fillWidth: true
        // Two and a half rows: the half row is what says "there is more".
        Layout.preferredHeight: root.coverH * 2.5 + Theme.space2 * 2
        cellWidth: root.coverW + Theme.space2
        cellHeight: root.coverH + Theme.space2
        clip: true
        focus: true
        model: Services.Wallpaper.model

        // ⚠️ A `Binding`, not `Component.onCompleted` — the same trap ThemePage
        // fell into and for the same reason. FolderListModel lists the directory
        // asynchronously, so a one-shot at construction searches an EMPTY model,
        // finds nothing, and leaves the cursor on the first cover while the
        // desktop is wearing the ninth.
        //
        // RestoreNone because this only sets a starting point: a binding that
        // kept re-asserting would fight the arrow keys.
        Binding on currentIndex {
            value: Services.Wallpaper.indexOf(Services.Wallpaper.current)
            restoreMode: Binding.RestoreNone
        }

        Component.onCompleted: grid.forceActiveFocus()

        Keys.onEscapePressed: Ipc.collapse()
        Keys.onReturnPressed: grid.choose(grid.currentIndex)
        Keys.onEnterPressed: grid.choose(grid.currentIndex)

        function choose(i) {
            if (i < 0 || i >= Services.Wallpaper.count)
                return
            // Writes one key in shell.json. Everything else — the image on
            // screen, the derived palette, GTK, Qt, kitty, niri — follows from
            // that, and follows again after a restart. See theme/Scheme.qml.
            Services.Wallpaper.choose(Services.Wallpaper.pathAt(i))
        }

        delegate: Item {
            id: cell
            required property int index
            required property url fileUrl

            width: root.coverW
            height: root.coverH

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMd
                color: Theme.surface
                clip: true

                // The cursor, marked with the accent — the one thing accent is
                // for. Kept separate from the tick below on purpose: "which one
                // is under the cursor" and "which one am I using" are different
                // questions and must not share a mark.
                border.width: cell.index === grid.currentIndex ? Theme.space1 / 2 : 0
                border.color: Theme.accent

                Image {
                    anchors.fill: parent
                    anchors.margins: parent.border.width
                    source: cell.fileUrl
                    fillMode: Image.PreserveAspectCrop
                    // ⚠️ Without sourceSize a folder of 6000x3750 PNGs decodes
                    // hundreds of megabytes to draw thumbnails. This is the
                    // difference between a page that opens and one that stalls
                    // the compositor. Measured on twelve 4-6 MB files: opening
                    // the page costs 2.3 MB of RSS (182 516 -> 184 796 kB).
                    sourceSize.width: root.coverW
                    sourceSize.height: root.coverH
                    asynchronous: true
                    cache: true
                }

                Pill {
                    anchors { bottom: parent.bottom; right: parent.right
                              margins: Theme.space1 }
                    visible: String(cell.fileUrl) === Services.Wallpaper.current
                    active: true
                    Icon { text: "check"; size: Theme.fontSize; color: Theme.accentFg }
                }

                TapHandler {
                    onTapped: {
                        grid.currentIndex = cell.index
                        grid.choose(cell.index)
                    }
                }
            }
        }
    }
}
