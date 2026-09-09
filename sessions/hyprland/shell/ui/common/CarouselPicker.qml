pragma ComponentBehavior: Bound

// One picker, two users: themes and wallpapers.
//
// From his screenshots of 09.09.2026 — a dark rounded overlay near the top of
// the screen, wider than it is tall, a horizontal row of tiles with the
// selected one visibly LARGER and ringed in the accent, a counter on the right
// and "Enter to apply" at the foot. He sent the second picture with the words
// "genau so für wallpaper switcher", which is the whole design brief: not a     // english-ok: the request, quoted
// second component that looks similar, the SAME one with different tiles.
//
// ⚠️⚠️ THE SIZE IS THE SELECTION, NOT THE RING. He said the chosen element
// should get bigger, and that is what the eye reads first — a ring alone is a
// detail you have to look for. The ring is the confirmation, not the signal.
//
// ⚠️ IT WRAPS. "hinter dem letzten Theme kommt wieder das erste" — a PathView   // english-ok: the request, quoted
// does that by construction, where a ListView needs an index modulo and a
// scroll position that has to be kept honest. Wrapping is also what makes a
// twelve-item picker usable with one key: nothing ever refuses to move.
//
// ⚠️⚠️ BROWSING CHANGES NOTHING. Moving through the row only moves the
// highlight; `Enter` is what applies, which is what the footer says and what he
// chose when asked. That is not a preference about feel: applying a theme is a
// full render over thirteen foreign files plus a `Hyprland --verify-config`,
// and holding an arrow key down would queue one of those per keypress. On a
// laptop.
//
// ⚠️ AND THE TILE IS THE CALLER'S. This file knows about a row, a size, a ring
// and a counter; it knows nothing about palettes or pictures. `tile` is a
// Component handed in, with `modelData`, `index` and `chosen` available to it —
// which is what stops this from becoming two components with one name.
import QtQuick
import QtQuick.Layouts
import "../../theme"

FocusScope {
    id: root

    // -------------------------------------------------------------- the input
    property var model: []
    property Component tile: null

    // The tile size at rest. The selected one is drawn `grow` times this.
    property int tileWidth: Theme.space6 * 5
    property int tileHeight: Theme.space6 * 3
    readonly property real grow: 1.22

    // How many tiles are on screen at once. Odd, so one of them is in the
    // middle and the selection has a place to be.
    property int visibleTiles: 5

    // The four corners. Empty means the corner is not drawn at all rather than
    // drawn empty — the same rule the quick panel's sections follow.
    property string headLeftText: ""
    property string headRightText: ""
    property string footLeftText: ""
    property string footRightText: "Enter to apply"

    // A search field instead of a title on the left. The caller filters its own
    // model on `query`; this only carries the text, because what "matching"
    // means is a question about palettes or filenames and not about a row.
    property bool searchable: false
    property alias query: search.text

    property alias currentIndex: view.currentIndex
    readonly property int count: root.model ? root.model.length : 0

    // ⚠️ ONE SIGNAL, AND IT CARRIES THE INDEX. A picker that reached into
    // Services.Themes itself could not also be the wallpaper picker, which is
    // the entire reason this file exists.
    signal applied(int index)
    signal dismissed()

    // ⚠️⚠️ THE HIGHLIGHT MOVED, AND THAT IS ALL THAT HAPPENED. This
    // handler is empty ON PURPOSE and is the one place the decision
    // lives: browsing changes nothing, `Enter` applies. Writing the
    // apply here would be a live preview — a full render over thirteen
    // foreign files plus a `Hyprland --verify-config` per keypress, on a
    // laptop — and it is a change nothing else in the suite could see,
    // because the pages would still build and the row would still draw.
    // tests/picker.sh watches this, and tripwires.sh mutates exactly the
    // line below to prove that it can.
    onCurrentIndexChanged: root._moved()
    function _moved() {}

    implicitWidth: Math.max(view.implicitWidth, head.implicitWidth + Theme.space6 * 2)
    implicitHeight: body.implicitHeight

    Component.onCompleted: root.forceActiveFocus()

    // ⚠️ THE KEYS ARE ON THE SCOPE, NOT ON THE VIEW. A PathView answers arrow
    // keys itself only while IT has the focus, and the search field takes the
    // focus the moment the picker opens. Left and right have to keep working
    // while somebody is typing, which they do not if the view owns them.
    Keys.onLeftPressed: view.decrementCurrentIndex()
    Keys.onRightPressed: view.incrementCurrentIndex()
    Keys.onUpPressed: view.decrementCurrentIndex()
    Keys.onDownPressed: view.incrementCurrentIndex()
    Keys.onEscapePressed: root.dismissed()
    Keys.onReturnPressed: root.applied(view.currentIndex)
    Keys.onEnterPressed: root.applied(view.currentIndex)

    ColumnLayout {
        id: body
        anchors.fill: parent
        spacing: Theme.space3

        // ------------------------------------------------------------ the head
        RowLayout {
            id: head
            Layout.fillWidth: true
            spacing: Theme.space3

            Icon {
                visible: root.searchable
                text: "search"
                size: Theme.fontSizeSm
                color: Theme.fgMuted
            }

            TextField {
                id: search
                visible: root.searchable
                Layout.fillWidth: true
                focus: root.searchable
                placeholder: "Search themes…"
            }

            BarText {
                visible: !root.searchable && root.headLeftText.length > 0
                Layout.fillWidth: true
                text: root.headLeftText
                color: Theme.fg
            }

            BarText {
                visible: root.headRightText.length > 0
                text: root.headRightText
                font.pixelSize: Theme.fontSizeSm
                color: Theme.fgMuted
            }
        }

        // ----------------------------------------------------------- the row
        //
        // ⚠️ THE ROW IS AS TALL AS THE GROWN TILE, ALWAYS. Sizing it to the tile
        // at rest and letting the selected one overflow makes the whole overlay
        // change height as you move through it, which is the horizontal wobble
        // this shell already fixed once in the notch — tests/motion.sh fails a
        // surface whose size comes from a child.
        PathView {
            id: view
            Layout.fillWidth: true
            Layout.preferredHeight: root.tileHeight * root.grow + Theme.space3 * 2
            implicitWidth: root.visibleTiles * (root.tileWidth + Theme.space2)

            model: root.model
            pathItemCount: root.visibleTiles
            // Wrap-around, which is the request, and it is what a PathView does
            // when the path is not `StrictlyEnforceRange`-clamped.
            snapMode: PathView.SnapToItem
            highlightRangeMode: PathView.StrictlyEnforceRange
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            clip: true

            Behavior on offset {
                enabled: Theme.animate
                NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
            }

            // A straight line across the middle, with the scale carried on it so
            // the growth is the path's rather than a binding per delegate.
            path: Path {
                startX: 0
                startY: view.height / 2
                PathAttribute { name: "tileScale"; value: 1 }
                PathAttribute { name: "tileFade"; value: Theme.dimmed }
                PathLine {
                    x: view.width / 2
                    y: view.height / 2
                }
                PathAttribute { name: "tileScale"; value: root.grow }
                PathAttribute { name: "tileFade"; value: 1 }
                PathLine {
                    x: view.width
                    y: view.height / 2
                }
                PathAttribute { name: "tileScale"; value: 1 }
                PathAttribute { name: "tileFade"; value: Theme.dimmed }
            }

            delegate: Item {
                id: cell
                required property var modelData
                required property int index

                readonly property bool chosen: cell.index === view.currentIndex
                readonly property real tileScale: PathView.tileScale === undefined
                                                  ? 1 : PathView.tileScale
                readonly property real tileFade: PathView.tileFade === undefined
                                                 ? 1 : PathView.tileFade

                width: root.tileWidth
                height: root.tileHeight
                z: cell.chosen ? 1 : 0
                scale: cell.tileScale
                opacity: cell.tileFade

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusMd
                    color: "transparent"                      // literal-ok: absence of colour
                    // The ring confirms what the size already said.
                    border.width: cell.chosen ? Math.max(1, Theme.borderWidth) : 0
                    border.color: Theme.accent

                    Loader {
                        anchors.fill: parent
                        anchors.margins: Theme.space1
                        sourceComponent: root.tile
                        // ⚠️ HANDED DOWN BY NAME, not by relying on the delegate's
                        // scope reaching into the Loader. `pragma
                        // ComponentBehavior: Bound` is on at the top of this file,
                        // so a component loaded here does NOT see `cell` — which
                        // is the point of the pragma and the reason the three
                        // values a tile needs are properties on the item itself.
                        readonly property var modelData: cell.modelData
                        readonly property int index: cell.index
                        readonly property bool chosen: cell.chosen
                    }

                    TapHandler {
                        // One press selects, a second applies — the same shape as
                        // moving with the arrows and then pressing Enter, so the
                        // mouse and the keyboard mean the same thing.
                        onTapped: {
                            if (cell.chosen)
                                root.applied(cell.index)
                            else
                                view.currentIndex = cell.index
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------------ the foot
        RowLayout {
            Layout.fillWidth: true
            visible: root.footLeftText.length > 0 || root.footRightText.length > 0
            spacing: Theme.space3

            BarText {
                Layout.fillWidth: true
                text: root.footLeftText
                elide: Text.ElideMiddle
                font.pixelSize: Theme.fontSizeSm
                color: Theme.fgMuted
            }

            BarText {
                text: root.footRightText
                font.pixelSize: Theme.fontSizeSm
                color: Theme.fgDim
            }
        }
    }
}
