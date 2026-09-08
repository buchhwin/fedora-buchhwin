pragma ComponentBehavior: Bound

// The clipboard history, as a page of the island.
//
// ⚠️ THIS DOES NOT CHANGE HOW COPY AND PASTE WORK. Ctrl+C and Ctrl+V belong to
// the application you are in; cliphist only listens, and nothing here binds
// either of them. Choosing an entry puts it ON the clipboard — you then paste
// it wherever you like, exactly as you always would. Pasting for you would mean
// injecting a keystroke into whatever has focus, which needs a tool this
// project does not ship and guesses at another program's key bindings.
//
// Keyboard first, like the wallpaper picker: type to narrow, arrows to move,
// Enter to take, Escape to close. A history you have to aim at with the mouse
// is slower than scrolling back through your own terminal.
import QtQuick
import "../../../theme"
import "../../../config"
import "../../../ipc"
import "../../../services" as Services
import "../../common"

Item {
    id: root

    implicitWidth: Config.notch.minExpandedWidth

    // ⚠️ THIS PAGE IS TALLER THAN THE REFERENCE GEOMETRY, on purpose. 619 × 135
    // describes a page you read at a glance; a history is a page you look
    // THROUGH, and at 135 px exactly one entry fitted — measured on screen, with
    // five in the database. The island grows to what a page asks for
    // (NotchContent takes the larger of the floor and the content), so a page
    // that needs more room only has to say so.
    // The row's LOOK comes from tokens, its COUNT from a setting: how tall a
    // line is belongs to the design system, how many you want to see at once is
    // a matter of taste and gets a key of its own.
    readonly property int rowHeight: Theme.fontSize + Theme.space2 * 2
    readonly property int visibleRows: Math.max(1, Config.clipboard.visibleRows)

    implicitHeight: field.implicitHeight + Theme.space2 * 2 + Theme.space2
                    + rowHeight * visibleRows
                    + Theme.space1 * (visibleRows - 1)

    // The page is created when the island opens, and that is the only moment
    // the history is read. See services/Clipboard.qml: nothing runs while
    // nobody is looking.
    Component.onCompleted: {
        Services.Clipboard.refresh()
        field.forceActiveFocus()
    }

    // Filtering happens here rather than in the service: it is a property of
    // this view, and `cliphist list` has already been read.
    readonly property var shown: {
        var q = field.text.toLowerCase()
        var all = Services.Clipboard.entries
        if (!q.length) return all
        var out = []
        for (var i = 0; i < all.length; i++)
            if (all[i].preview.toLowerCase().indexOf(q) >= 0)
                out.push(all[i])
        return out
    }

    function take() {
        var e = root.shown[list.currentIndex]
        if (!e) return
        Services.Clipboard.pick(e.id)
        Ipc.collapse()
    }

    Column {
        anchors.fill: parent
        spacing: Theme.space2

        // -------------------------------------------------------- search
        Item {
            id: searchRow
            width: parent.width
            height: field.implicitHeight + Theme.space2 * 2

            TextInput {
                id: field
                anchors.fill: parent
                anchors.leftMargin: Theme.space2
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.fg
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontSize
                // The list is the point; the field is where you happen to type.
                // So the arrows and Enter belong to the list even while the
                // cursor is here, which is why they are handled rather than
                // left to the TextInput.
                Keys.onDownPressed: list.incrementCurrentIndex()
                Keys.onUpPressed: list.decrementCurrentIndex()
                Keys.onReturnPressed: root.take()
                Keys.onEnterPressed: root.take()
                Keys.onEscapePressed: Ipc.collapse()
                // A new search starts at the top; leaving the cursor on line
                // nine of a list that now has three entries is how a picker
                // stops feeling predictable.
                onTextChanged: list.currentIndex = 0

                BarText {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: field.text.length === 0
                    color: Theme.fgDim
                    text: "Search the clipboard"
                }
            }
        }

        // -------------------------------------------------------- the list
        // One sentence for each empty state, and they are different states: a
        // missing binary is not the same as nothing copied yet, and telling
        // them apart is the difference between "install this" and "carry on".
        BarText {
            width: parent.width
            visible: !Services.Clipboard.available
            color: Theme.fgMuted
            horizontalAlignment: Text.AlignHCenter
            text: "cliphist is not installed — the history cannot be read"
        }

        BarText {
            width: parent.width
            visible: Services.Clipboard.available && root.shown.length === 0
            color: Theme.fgMuted
            horizontalAlignment: Text.AlignHCenter
            text: field.text.length > 0 ? "Nothing matches"
                                        : "Nothing copied yet"
        }

        ListView {
            id: list
            width: parent.width
            height: parent.height - searchRow.height - Theme.space2
            visible: Services.Clipboard.available && root.shown.length > 0
            clip: true
            spacing: Theme.space1
            model: root.shown
            highlightMoveDuration: Theme.durFast
            // Keeps the cursor line on screen while the arrows walk past the
            // bottom edge, which is the whole reason to have a cursor.
            keyNavigationEnabled: false

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                width: list.width
                height: root.rowHeight
                radius: Theme.radiusSm
                color: row.index === list.currentIndex ? Theme.pillHover
                     : hover.hovered ? Theme.pillBg
                     : "transparent"          // literal-ok: absence of colour

                Behavior on color {
                    enabled: Theme.animate
                    ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                }

                HoverHandler { id: hover }

                BarText {
                    id: line
                    anchors.fill: parent
                    anchors.margins: Theme.space2
                    verticalAlignment: Text.AlignVCenter
                    // cliphist truncates the preview itself, but a long line
                    // still has to end somewhere the island can hold.
                    elide: Text.ElideRight
                    text: row.modelData.preview
                }

                TapHandler {
                    onTapped: {
                        list.currentIndex = row.index
                        root.take()
                    }
                }
            }
        }
    }
}
