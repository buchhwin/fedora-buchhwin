// A titled block of rows — a CARD, since today.
//
// ⚠️ THIS CHANGED HIS OWN REFERENCE, ON HIS INSTRUCTION. The screenshot from
// 04.08. draws rows floating free on the panel, and that is what shipped. After
// using it he said the window was hard to scan and told me to look at how macOS
// and Windows lay theirs out. Both do the same thing, and it is the one thing
// this was missing: rows live INSIDE a rounded surface, and the surfaces are
// separated by space. Fifty-five rows on one flat background give the eye no
// edges to hold on to.
//
// It stays inside the brief rather than breaking it. The rule there is
// "separation by space and SURFACE, never by lines" — a card is surface. No
// dividing line is added anywhere, and the rows inside are still separated by
// space alone.
//
// ⚠️ AND IT FOLDS. Appearance is eight groups; folded, it is eight lines and you
// can see the whole page at once. The state is not written to shell.json on
// purpose: it is where you are looking, not what you have set, and a settings
// file that records which drawer you left open is a settings file with opinions
// about your afternoon.
import QtQuick
import QtQuick.Layouts
import "../common"
import "../../theme"

ColumnLayout {
    id: root

    property string title: ""
    property bool collapsed: false

    // ⚠️ NOT WRITTEN TO shell.json, the same rule as `collapsed` above: it is
    // where you are looking, not what you have set, and a settings file that
    // records which drawer you left open is a settings file with opinions about
    // your afternoon.
    property bool showAdvanced: false

    // How many rows are on the second level. Counted from the rows themselves
    // rather than declared here, because a number written twice is a number
    // that goes stale — add a row, forget the count, and the door says "3" over
    // four things.
    property int advancedCount: 0
    function _recount() {
        var n = 0
        for (var i = 0; i < holder.children.length; i++) {
            var c = holder.children[i]
            if (c !== null && c.advanced === true)
                n += 1
        }
        root.advancedCount = n
    }

    // ⚠️ `.data`, not `.children`. Anything that is not an Item — a Connections,
    // a Timer a group might one day carry — has no place in `children` and
    // would be dropped without a word.
    default property alias content: holder.data

    spacing: Theme.space2

    // ------------------------------------------------------------- the header
    // Outside the card, as both references do it: the heading labels the card
    // rather than sitting in it.
    Item {
        Layout.fillWidth: true
        implicitHeight: head.implicitHeight
        visible: root.title.length > 0

        HoverHandler { id: headHover }
        TapHandler { onTapped: root.collapsed = !root.collapsed }

        RowLayout {
            id: head
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Theme.space1

            Icon {
                text: root.collapsed ? "chevron_right" : "expand_more"
                size: Theme.fontSizeSm
                color: headHover.hovered ? Theme.fg : Theme.fgMuted
            }
            BarText {
                Layout.fillWidth: true
                text: root.title
                // ⚠️ Was fontSizeSm and muted — a heading quieter than the rows
                // it heads, which is why the long pages read as one undivided
                // list. One UI puts real weight on the section name; the colour
                // stays calm so it groups rather than shouts.
                font.pixelSize: Theme.fontSize
                font.weight: Theme.weightSemibold
                color: headHover.hovered ? Theme.fg : Theme.fgMuted

                Behavior on color {
                    enabled: Theme.animate
                    ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                }
            }
        }
    }

    // --------------------------------------------------------------- the card
    // ⚠️ IT USED TO VANISH RATHER THAN CLOSE. `visible: !collapsed` is a card
    // that is simply not there on the next frame, and everything below it jumps
    // up the page — which reads as a glitch rather than as a group closing, and
    // loses you the place you were reading.
    //
    // Height and opacity, clipped, so the rows slide out of a shrinking card
    // instead of being cut off mid-air. This is the standing rule for everything
    // in this shell now: nothing appears or disappears without moving.
    Rectangle {
        id: card
        Layout.fillWidth: true
        clip: true

        readonly property int full: stack.implicitHeight + Theme.space5 * 2

        // ⚠️⚠️ THE FOLD ANIMATES. THE HEIGHT DOES NOT.
        //
        // This used to be `Behavior on implicitHeight`, gated on a `settled`
        // flag set one Qt.callLater after the build. That gate was right about
        // the build and wrong about everything after it, and the difference
        // shipped as "auf einmal wird alles größer und dann sofort wieder      // english-ok: the report, quoted
        // kleiner".                                                            // english-ok: the report, quoted
        //
        // The suggestion lists added on 08.08. do not arrive with the build.
        // `Installed.scan()` starts a process and answers about 100 ms later,
        // and `Apps.apps` fills in two stages. By then the card is `settled`,
        // so the pills appearing made `full` grow and the Behavior ANIMATED it
        // — then animated it back when a list got shorter. Before those lists
        // the same rows were text fields with a fixed height, so nothing ever
        // moved and the flaw could not be seen.
        //
        // A Behavior cannot tell the two apart, because it only sees a number
        // change. So the number it watches is no longer a height: `fold` is 0
        // shut and 1 open and changes ONLY when someone clicks the header. A
        // height that comes from the CONTENT lands instantly; a height that
        // comes from the GESTURE is the gesture. Same rule the notch cost us:
        //
        //     what the layout decides is SET, what moves is ANIMATED —
        //     and "decides" includes "comes from the content".
        property real fold: root.collapsed ? 0 : 1
        implicitHeight: Math.round(card.full * card.fold)
        opacity: root.collapsed ? 0 : 1

        // One UI's cards are large-radius, flat and opaque. `radiusLg` existed
        // and nothing used it.
        radius: Theme.radiusLg
        color: Theme.cardBg

        // Still gated on one laid-out frame. `fold` cannot be moved by content
        // any more, but a parent that sets `collapsed` declaratively while the
        // page is still assembling would otherwise unfold in front of you.
        property bool settled: false
        Component.onCompleted: Qt.callLater(function () { card.settled = true })

        // motion-ok: folding the card IS a height change — the cards below have
        // to move up, so there is no transform that says the same thing. It is
        // inside the settings window, which is a floating window of its own and
        // is not re-sized by it, so this costs a local relayout and no compositor
        // traffic.
        Behavior on fold {
            enabled: Theme.animate && card.settled
            NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
        }
        Behavior on opacity {
            enabled: Theme.animate && card.settled
            NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }

        ColumnLayout {
            id: stack
            anchors.left: parent.left
            anchors.right: parent.right
            // ⚠️ TOP, NOT verticalCenter. Centring is invisible at full height
            // and wrong at every height in between: while the card animates
            // shut, centred content crawls upward at half the speed of the card
            // and the rows appear to slide out of the wrong edge.
            anchors.top: parent.top
            anchors.topMargin: Theme.space5
            anchors.leftMargin: Theme.space5
            anchors.rightMargin: Theme.space5
            spacing: Theme.space4

            ColumnLayout {
                id: holder
                Layout.fillWidth: true
                // Wider than the gap inside a row, so a row reads as one thing
                // and the gap between two rows reads as the join.
                spacing: Theme.space4

                // ⚠️ THE ROWS READ THIS THROUGH `parent`. They are direct
                // children of this layout, which is the whole reason the level
                // needs no attached property, no singleton and no second list.
                property bool showAdvanced: root.showAdvanced

                // Rows are declared inline on every page today, so one count at
                // the end of the build would do — but a page that ever grows a
                // Repeater would silently under-count, and an under-counted door
                // hides rows with no way to reach them.
                onChildrenChanged: Qt.callLater(root._recount)
                Component.onCompleted: Qt.callLater(root._recount)
            }

            // ------------------------------------------------- the second level
            // ⚠️ IT SAYS HOW MANY. "Show more" alone is a door with nothing
            // written on it — you have to open it to find out whether it was
            // worth opening, every time. The count is what makes it skippable.
            Item {
                Layout.fillWidth: true
                implicitHeight: moreLine.implicitHeight
                visible: root.advancedCount > 0

                HoverHandler { id: moreHover }
                TapHandler { onTapped: root.showAdvanced = !root.showAdvanced }

                RowLayout {
                    id: moreLine
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Theme.space1

                    Icon {
                        text: root.showAdvanced ? "expand_less" : "expand_more"
                        size: Theme.fontSizeSm
                        color: moreHover.hovered ? Theme.fg : Theme.fgMuted
                    }
                    BarText {
                        Layout.fillWidth: true
                        text: root.showAdvanced
                            ? "Show less"
                            : "Show more (" + root.advancedCount + ")"
                        font.pixelSize: Theme.fontSizeSm
                        color: moreHover.hovered ? Theme.fg : Theme.fgMuted

                        Behavior on color {
                            enabled: Theme.animate
                            ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                        }
                    }
                }
            }
        }
    }
}
