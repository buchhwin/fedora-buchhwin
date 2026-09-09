pragma ComponentBehavior: Bound

// One program in the dock: its icon, whether it is running, and what a click
// does about that.
//
// ⚠️ AN APP ID IS NOT A DESKTOP ID, and this is where that bites. The compositor reports
// `app_id` from the window; the dock's pinned list holds desktop entry ids. They
// agree often enough to look identical and then do not: the predecessor found
// `brave-browser` against `brave-origin`, and `org.gnome.Nautilus` against
// `nautilus`. So they are compared through `matches()` — lower-cased, and the
// last dotted component taken — rather than with `===`, and anything that
// cannot be matched keeps its own icon instead of being folded into someone
// else's. Nothing is silently swallowed.
import QtQuick
import QtQuick.Layouts
import "../common"
import "../../theme"

Item {
    id: root

    // { id, name, icon } — from Services.Apps for a pinned entry, or built
    // from a window's app_id for something running that is not pinned.
    required property var entry
    property int iconSize: 32
    property int windows: 0
    property bool active: false
    property bool vertical: false

    signal activated()

    readonly property bool running: root.windows > 0

    implicitWidth: root.iconSize + Theme.space3 * 2
    implicitHeight: root.iconSize + Theme.space3 * 2

    Rectangle {
        id: plate
        anchors.fill: parent
        radius: Theme.radiusMd
        color: hover.hovered ? Theme.pillHover
             : "transparent"                    // literal-ok: absence of colour

        Behavior on color {
            enabled: Theme.animate
            ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }

        HoverHandler { id: hover }
        TapHandler { onTapped: root.activated() }
    }

    // ⚠️ `scale`, NOT width/height. A hover that grows the icon by changing its
    // SIZE re-lays out the row, which moves every neighbour and — on a surface
    // whose width follows its content — would re-measure the Wayland surface
    // itself. scale is a GPU transform the compositor never hears about. This is
    // the rule this shell paid for twice: what decides layout is SET, what moves
    // is ANIMATED.
    AppIcon {
        id: icon
        anchors.centerIn: parent
        source: root.entry.icon || ""
        appName: root.entry.name || root.entry.id || ""
        size: root.iconSize
        scale: hover.hovered ? 1.12 : 1.0

        Behavior on scale {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }
    }

    // The running mark: a dot under the icon, two dots for more than one
    // window. Not a count — a number under every icon is a row of numbers to
    // read, and the question is "is it open", not "how many".
    Row {
        id: marks
        spacing: Theme.space1

        anchors.horizontalCenter: root.vertical ? undefined : parent.horizontalCenter
        anchors.verticalCenter: root.vertical ? parent.verticalCenter : undefined
        anchors.bottom: root.vertical ? undefined : parent.bottom
        anchors.right: root.vertical ? parent.right : undefined
        anchors.bottomMargin: root.vertical ? 0 : Theme.space1
        anchors.rightMargin: root.vertical ? Theme.space1 : 0

        opacity: root.running ? 1 : 0
        Behavior on opacity {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }

        Repeater {
            model: Math.min(root.windows, 2)

            Rectangle {
                width: Theme.space1
                height: Theme.space1
                radius: Theme.space1 / 2
                color: root.active ? Theme.accent : Theme.fgMuted
            }
        }
    }

    Tooltip {
        target: root
        active: hover.hovered
        text: root.entry.name || root.entry.id || ""
    }
}
