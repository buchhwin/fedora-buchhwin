// A word beside something, after you have waited a moment.
//
// The icon rail is symbols only — his choice — and a symbol without a word is
// "übersichtlicher" only in the sense that it explains less. This is the word.  english-ok: quoted brief
//
// ⚠️ A CHILD OF THE SURFACE, NEVER ITS OWN WINDOW. A second layer surface for a
// tooltip would mean a second namespace, a second shadow and a second blur pass
// for four words — and niri draws both behind the WHOLE surface, invisible
// margins included, so it would also come with the coloured halo this project
// spent a round removing from the notch. It overflows into the panel it lives
// in instead, which is where there is room anyway.
//
// ⚠️ AND IT WAITS. A label that appears the instant the pointer crosses an icon
// turns a row of buttons into a flickering wall of text. The delay is what makes
// it an answer to a question rather than an interruption.
import QtQuick
import "../../theme"

Item {
    id: root

    // What to say, and what to say it about. `target` is the item the tooltip
    // points at; the tooltip places itself to its right.
    property string text: ""
    property Item target: null
    property bool active: false

    visible: opacity > 0
    // Above whatever it overlaps. A tooltip that appears BEHIND the content it
    // is explaining is worse than none.
    z: 100

    implicitWidth: pane.implicitWidth
    implicitHeight: pane.implicitHeight

    x: root.target
        ? root.target.mapToItem(root.parent, root.target.width, 0).x + Theme.space2
        : 0
    y: root.target
        ? root.target.mapToItem(root.parent, 0, 0).y
          + (root.target.height - implicitHeight) / 2
        : 0

    opacity: dwell.running || !root.active ? 0 : 1
    Behavior on opacity {
        enabled: Theme.animate
        NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
    }

    // Restarted by the caller through `active`. Stopping it on the way out is
    // what stops a tooltip appearing after you have already moved on.
    Timer {
        id: dwell
        interval: Theme.durSlow
        running: root.active
    }

    // ⚠️ OPAQUE, and therefore NOT a GlassPane. The first version used one and
    // the calendar's month arrow read straight through the word — measured on
    // screen. Glass is right for a surface you look AT; a tooltip is a label you
    // look THROUGH nothing to read. `bgDeep` is a palette colour with no alpha,
    // unlike `panelBg`, which is `bgDeep` at 0.84.
    Rectangle {
        id: pane
        anchors.fill: parent
        radius: Theme.radiusSm
        color: Theme.bgDeep
        implicitWidth: label.implicitWidth + Theme.space3 * 2
        implicitHeight: label.implicitHeight + Theme.space2 * 2
    }

    BarText {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fg
    }
}
