pragma ComponentBehavior: Bound

// Choosing a wallpaper, as a page of the island.
//
// It was a full-screen window first. It is not one any more, and the reason is
// the rule the whole shell is built on: the island does not summon a second
// window, it BECOMES the thing you asked for. A grid that darkens the screen
// and floats in the middle is a different program wearing our colours.
//
// ⚠️⚠️ THIS IS THE SAME COMPONENT AS THE THEME PICKER, and that is his own
// instruction rather than a tidy-up. He sent the theme picker's screenshot,
// then the wallpaper one with the words "genau so für wallpaper switcher" —     // english-ok: the request, quoted
// "exactly like that". So it is one common/CarouselPicker.qml with a different
// tile, not a second grid that happens to look similar. Two pickers that
// scrolled differently would be two things to learn instead of one, and they
// would drift the first time either was adjusted.
//
// What changed with it: a three-column grid became one wrapping row. The
// argument for the grid was that a row "shows four covers and hides the rest
// behind a scroll nobody can see the end of" — which is true of a row that
// STOPS. This one wraps, so there is no end to fall off, and the counter at the
// foot says how many there are instead of a scrollbar implying it.
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

    // 16:9, because wallpapers are.
    readonly property int coverW: Theme.space6 * 5
    readonly property int coverH: Math.round(coverW * 9 / 16)

    // ⚠️ A PLAIN ARRAY, NOT THE FolderListModel ITSELF. The picker hands its
    // tile a `modelData`, which is what a JS array gives; a FolderListModel
    // gives named ROLES instead, and a tile written against `modelData` would
    // silently receive undefined and draw nothing. Built here because this is
    // the file that knows the list is pictures.
    readonly property var shots: {
        var out = []
        for (var i = 0; i < Services.Wallpaper.count; i++)
            out.push({ url: Services.Wallpaper.pathAt(i),
                       name: Services.Wallpaper.nameAt(i) })
        return out
    }

    BarText {
        Layout.fillWidth: true
        visible: !Services.Wallpaper.available
        text: "No pictures in the wallpaper folder"
        color: Theme.fgMuted
        horizontalAlignment: Text.AlignHCenter
    }

    CarouselPicker {
        id: picker
        Layout.fillWidth: true
        Layout.preferredHeight: picker.implicitHeight
        visible: Services.Wallpaper.available
        focus: true

        model: root.shots
        tileWidth: root.coverW
        tileHeight: root.coverH

        // The head is a title and the theme in force, from his screenshot —
        // where the theme picker has a search field and a counter instead.
        headLeftText: "Wallpaper"
        headRightText: Services.Themes.current

        // ⚠️ THE FILE NAME IS AT THE FOOT, not on the tile. A caption across a
        // photograph is a caption you cannot read on half the photographs, and
        // the one being pointed at is the only one whose name is a question.
        footLeftText: {
            var e = root.shots[picker.currentIndex]
            return e ? String(e.name) : ""
        }
        footRightText: root.shots.length > 0
                       ? (picker.currentIndex + 1) + "/" + root.shots.length
                         + " · Enter to apply"
                       : "Enter to apply"

        onDismissed: Ipc.collapse()
        onApplied: function (i) {
            var e = root.shots[i]
            if (!e) return
            Services.Wallpaper.choose(e.url)
            Ipc.collapse()
        }

        tile: Rectangle {
            id: cell
            required property var modelData
            required property int index
            required property bool chosen

            radius: Theme.radiusMd
            color: Theme.surface
            clip: true

            Image {
                anchors.fill: parent
                source: cell.modelData.url
                fillMode: Image.PreserveAspectCrop
                // ⚠️ Without sourceSize a folder of 6000x3750 PNGs decodes
                // hundreds of megabytes to draw thumbnails. This is the
                // difference between a page that opens and one that stalls the
                // compositor. Measured on twelve 4-6 MB files: opening the page
                // costs 2.3 MB of RSS (182 516 -> 184 796 kB).
                //
                // ⚠️ THE GROWN SIZE, not the resting one. The selected tile is
                // drawn larger than the source it was decoded at would allow,
                // and a thumbnail scaled up past its own pixels is the one place
                // in this shell where "it looks slightly wrong" has no other
                // explanation.
                sourceSize.width: Math.round(cell.width * 1.3)
                sourceSize.height: Math.round(cell.height * 1.3)
                asynchronous: true
                cache: true
            }

            // ⚠️ THE TICK IS "IN USE", WHICH IS NOT "SELECTED". The picker's ring
            // says where the cursor is; this says which picture is on the
            // desktop. One mark for both questions is a picker you have to apply
            // something in to find out what you already had.
            Pill {
                anchors { bottom: parent.bottom; right: parent.right
                          margins: Theme.space1 }
                visible: String(cell.modelData.url) === Services.Wallpaper.current
                active: true
                Icon { text: "check"; size: Theme.fontSize; color: Theme.accentFg }
            }
        }
    }
}
