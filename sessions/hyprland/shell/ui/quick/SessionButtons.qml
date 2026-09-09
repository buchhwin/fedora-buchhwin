pragma ComponentBehavior: Bound

// Lock, suspend, log out, restart, shut down — as five small pills in a corner.
//
// His request: "im quick menu gibt es aktuell noch keine power shutdown lock     // english-ok: the request, quoted
// butten etc … die sollen am besten ins rechte obere eck vom quickpanel          // english-ok: the request, quoted
// kommen".                                                                       // english-ok: the request, quoted
//
// ⚠️ THE LIST IS NOT HERE. It is services/Session.qml, which the notch's own
// session page reads as well. Two copies of "what shutting down means" is the
// fault this project has paid for four times, and this file's own icon names
// are in that history: `logout` and `restart_alt` are Material Symbols names
// that Fedora's "Material Icons Round" does not have, and they shipped as one
// missing glyph and one wrong one.
//
// ⚠️ AND THE QUESTION IS KEPT, in the smaller space rather than in spite of it.
// The session page exists because `Super+Shift+E` was once bound straight to
// the compositor's `quit`: one keystroke, no question, every unsaved thing gone. A row of
// five unlabelled icons is a MORE dangerous place for that, not less — the
// shutdown pill is a centimetre from the lock pill. So the three that throw work
// away arm on the first press and say so, in words, beside the row.
//
// Locking and suspending go at once, because both are reversible and asking
// about them is the kind of dialog people learn to dismiss without reading —
// which is exactly the habit that would make the shutdown question useless too.
//
// ⚠️⚠️ AN Item AROUND THE ROW, AND ONE TOOLTIP AT THIS LEVEL. The first version
// put a Tooltip inside each Pill and the whole quick panel stopped appearing:
// "QuickPage called polish() inside updatePolish()", forever. Pill sizes its
// inner Item from `childrenRect`, and a Tooltip is a child with an implicit
// size that positions itself FROM the pill it points at — so the pill's width
// depended on the tooltip and the tooltip's x depended on the pill. IconRail
// already solved this: hand the hovered pill up, and keep one tooltip outside
// the layout, where it can overflow instead of being measured.
import QtQuick
import QtQuick.Layouts
import "../common"
import "../../services" as Services
import "../../theme"

Item {
    id: root

    // Which action is armed. Empty = nothing pending.
    property string pending: ""

    // The caller closes itself; this component does not know what it is inside
    // of. Same reason services/Session.qml imports no Ipc.
    signal ran(string id)

    // ⚠️⚠️ THE ROW IS ANCHORED TO A CORNER, NOT FILLED, AND THAT IS THE FIX FOR
    // "der text von den shutdown reboot buttons der ist unter dem settings      // english-ok: the report, quoted
    // button was das unlesbar macht".                                           // english-ok: the report, quoted
    //
    // It used to be `implicitWidth: line.implicitWidth` over a row with
    // `anchors.fill: parent`. Read it in one direction: the Item asks the row
    // how wide it wants to be. Read it in the other: the row is exactly as wide
    // as the Item. That is a size defined in terms of itself, and QML resolves
    // it by settling on whatever came last rather than by complaining.
    //
    // It only shows when the width CHANGES, which is why it looked fine until he
    // armed something: the confirmation sentence appears, the row's natural
    // width jumps by a whole sentence, and the row is meanwhile pinned to the
    // Item that is supposed to be following it. It cannot grow into the space,
    // so it overflows — into the gear sitting immediately to its right.
    //
    // Anchored to the top left, the row's size is its own and the Item simply
    // reports it. Same shape IconRail uses, for the same reason.
    implicitWidth: line.implicitWidth
    implicitHeight: line.implicitHeight

    function cancel() { root.pending = "" }

    function press(id) {
        var a = Services.Session.byId(id)
        if (a === null)
            return
        if (a.ask && root.pending !== id) {
            root.pending = id
            return
        }
        root.pending = ""
        Services.Session.run(id)
        root.ran(id)
    }

    // ⚠️ TWO PROPERTIES, NOT ONE, and the type is why — the same trap IconRail
    // documents. `hoveredPill` has to be an `Item` for the tooltip to position
    // against it, and a property declared as `Item` exposes only Item's own
    // members, so reading `.modelData` back off it returns undefined and the
    // tooltip appears with no word in it.
    property Item hoveredPill: null
    property string hoveredLabel: ""

    RowLayout {
        id: line
        anchors.left: parent.left
        anchors.top: parent.top
        spacing: Theme.space1

        // ⚠️ THE QUESTION IN WORDS, and it takes the space it needs rather than
        // hiding under the pointer. An armed shutdown that shows only as a
        // colour is a colour you have to have learned.
        BarText {
            Layout.alignment: Qt.AlignVCenter
            visible: root.pending.length > 0
            text: {
                var a = Services.Session.byId(root.pending)
                return a === null ? "" : a.label + "? Again to confirm"
            }
            font.pixelSize: Theme.fontSizeSm
            color: Theme.accent
        }

        Repeater {
            model: Services.Session.actions

            Pill {
                id: button
                required property var modelData

                readonly property bool armed: root.pending === button.modelData.id

                Layout.alignment: Qt.AlignVCenter
                interactive: true
                active: button.armed

                Icon {
                    text: button.modelData.icon
                    size: Theme.fontSizeLg
                    color: button.armed ? Theme.accentFg : Theme.fg
                }

                onClicked: root.press(button.modelData.id)

                onHoveredChanged: {
                    if (hovered) {
                        root.hoveredPill = button
                        root.hoveredLabel = String(button.modelData.label)
                    } else if (root.hoveredPill === button) {
                        root.hoveredPill = null
                        root.hoveredLabel = ""
                    }
                }
            }
        }
    }

    // One for the whole row, outside the layout. Two tooltips on screen at once
    // is what a per-pill one does the moment the pointer crosses between them —
    // and a per-pill one here does not work at all, see the note at the top.
    Tooltip {
        target: root.hoveredPill
        active: root.hoveredPill !== null && root.pending.length === 0
                && root.hoveredLabel.length > 0
        text: root.hoveredLabel
    }
}
