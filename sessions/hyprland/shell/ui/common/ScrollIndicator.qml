// The narrow bar down the side of a Flickable that says where you are.
//
// ⚠️⚠️ IT IS A SIBLING OF THE FLICKABLE, NEVER A CHILD, AND THAT IS THE WHOLE
// REASON THIS FILE EXISTS. A direct child of a Flickable is handed to its
// `contentItem` — the thing that MOVES. A bar written in there has an on-screen
// position of `y - contentY`, so with the usual `y: contentY * (h/contentH)` it
// travels at `contentY * (ratio - 1)`: negative, and away from the viewport. It
// does not indicate the scroll, it slides out of the top of it.
//
// That shipped in the settings window and he reported it as "der strich da     // english-ok: the report, quoted
// bewegt sich nicht der geht noch nicht".                                      // english-ok: the report, quoted
//
// So a caller wraps its Flickable in an Item and puts this beside it:
//
//     Item {
//         Flickable { id: scroller; anchors.fill: parent; … }
//         ScrollIndicator { flickable: scroller }
//     }
//
// ⚠️ AND IT IS ONE COMPONENT FOR BOTH SIDES. The content pane had a bar and the
// page sidebar had none, although the sidebar has had to scroll ever since the
// pages were split under headings — twenty-one rows do not fit. Two bars built
// separately is the drift this repo has paid for with two sidebars, two
// calendars and two theme grids; there is no third reason needed.
import QtQuick
import "../../theme"

Rectangle {
    id: root

    // The Flickable this reports on. Declared as the type rather than as `var`
    // so a caller cannot hand it something that merely has a `contentY`.
    property Flickable flickable: null

    // Which edge it sits on. The content pane wants the right; a caller that
    // puts it on the left says so rather than reaching in and re-anchoring.
    property bool onLeft: false

    readonly property real _viewport: root.flickable ? root.flickable.height : 0
    readonly property real _content: root.flickable
                                   ? Math.max(1, root.flickable.contentHeight) : 1
    readonly property real _ratio: Math.min(1, root._viewport / root._content)

    // ⚠️ HIDDEN WHEN EVERYTHING FITS. A bar that is always the full height of
    // its track says nothing and takes up room — and worse, it says "there is
    // more" on a page where there is not.
    visible: root.flickable !== null && root._content > root._viewport

    width: Theme.space1
    radius: Theme.radiusPill
    color: Theme.outlineStrong

    anchors.right: root.onLeft ? undefined : parent.right
    anchors.left: root.onLeft ? parent.left : undefined

    // ⚠️ A FLOOR ON THE THUMB. On a very long page the proportional height goes
    // below a few pixels, and a bar you cannot see is the same as no bar — the
    // fault one level up, arrived at by arithmetic instead of by parenting.
    // The floor is taken out of the travel below so the bottom still means the
    // bottom.
    readonly property real _minLength: Theme.space5
    height: Math.max(root._minLength, root._viewport * root._ratio)

    // ⚠️ CLAMPED, because `contentY` overshoots. Even with StopAtBounds a
    // flick can put it briefly out of range, and an unclamped bar leaves the
    // track — which reads as a rendering fault rather than as a bounce.
    y: {
        if (!root.flickable)
            return 0
        var travel = Math.max(0, root._viewport - root.height)
        var scrollable = Math.max(1, root._content - root._viewport)
        var progress = Math.max(0, Math.min(1, root.flickable.contentY / scrollable))
        return progress * travel
    }
}
