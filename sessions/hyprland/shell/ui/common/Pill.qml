// The one rounded container everything in the shell sits in.
//
// It exists so that "a thing on the bar" has exactly one definition of its
// corner radius, padding and hover behaviour. Every value comes from Theme; a
// literal here would be caught by tests/no-literals.sh, which is the point —
// the tripwire is not bureaucracy, it is what keeps a palette switch total.
//
// ⚠️ THE TAP TARGET IS THE PILL, WHICH IS WHY `clicked` EXISTS. Children handed
// to a Pill land in `inner`, an Item sized to `childrenRect` — so a TapHandler
// written inside a Pill used to attach to THAT rather than to the pill. Measured
// on a tab reading "Media": pill 68 x 29, tap target 44 x 21, leaving 1050 px²
// — more than half the pill — highlighted on hover and dead to the click. That
// is exactly the "I click it and nothing happens" it was reported as. The
// handler therefore lives here, once, and no call site declares its own.
import QtQuick
import "../../theme"

Rectangle {
    id: root

    property bool interactive: false
    property bool active: false
    default property alias content: inner.data

    // Whether the pointer is on it. Exposed because a caller that wants to react
    // to hover — a tooltip, for one — would otherwise add a SECOND HoverHandler
    // at the call site, and a handler written inside a Pill lands in `inner`,
    // which is sized to its contents. That is the "every pill was half dead"
    // bug, and this is how it is not reopened.
    readonly property alias hovered: hover.hovered

    signal clicked
    // Only the tray has a use for it so far, but a second handler at the call
    // site would land back in `inner` and reopen the hole this closes.
    signal rightClicked

    implicitWidth: inner.implicitWidth + Theme.space3 * 2
    implicitHeight: inner.implicitHeight + Theme.space1 * 2

    radius: Theme.radiusPill
    color: root.active ? Theme.accent
         : hover.hovered && root.interactive ? Theme.pillHover
         : Theme.pillBg

    Behavior on color {
        enabled: Theme.animate
        ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
    }

    HoverHandler { id: hover; enabled: root.interactive }

    // Same condition as the hover highlight, so what lights up is what answers.
    TapHandler {
        enabled: root.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onTapped: function (point, button) {
            if (button === Qt.RightButton)
                root.rightClicked()
            else
                root.clicked()
        }
    }

    Item {
        id: inner
        anchors.centerIn: parent
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }
}
