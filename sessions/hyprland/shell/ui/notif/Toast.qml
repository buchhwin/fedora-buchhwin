// One arriving notification, as a card that shows up and goes away again.
//
// The card is a pane of glass like every other floating surface, so a palette
// change reaches it without it knowing anything about palettes.
//
// ⚠️ The timer lives HERE rather than in the service, and that is what keeps
// the shell idle when nothing is happening. A service-side timer would have to
// exist whether or not anything was on screen, or poll to find out; a timer
// inside the delegate exists exactly as long as the card does, which is
// seconds at a time.
//
// Hovering pauses it. A message you are in the middle of reading must not
// disappear from under your eyes — and hover is the only signal we have that
// you are reading it.
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../config"
import "../../services" as Services
import "../common"

Item {
    id: root

    required property var notification

    // 0 means "stays until dismissed" — critical messages, and senders that
    // asked for it explicitly.
    readonly property int duration: Services.Notifications.toastDuration(notification)

    implicitWidth: Theme.space6 * 11
    // ⚠️ A FIXED height, not the content's. Every card has to be the same size
    // for the stack to know where each window goes before its neighbours are
    // laid out — see ToastSurface.qml. It is also what every other desktop
    // does, and it means a card never jumps because the one above it grew.
    //
    // Sized for the TALLEST arrangement — summary, one body line and a row of
    // action buttons. At the first attempt it was sized for the shortest, and
    // the buttons were simply clipped away: the sender offered "Öffnen" and  english-ok: a real button label
    // "Verwerfen", the card said nothing, and it looked like actions were
    // unsupported rather than cut off. Cards without actions spend the room on
    // a second line of body text instead, so it is never empty space.
    implicitHeight: Theme.space6 * 3 + Theme.space2

    // Fades in where it stands. It cannot slide: the window is exactly the size
    // of the card, so there is nowhere inside it to slide from — and moving the
    // window instead would drag its shadow and blur along the screen edge.
    //
    // ⚠️ BUT IT CAN SCALE, and it did not, which is why a toast was the one
    // thing in this shell that simply blinked into existence while every panel
    // grew into place. `scale` is a transform inside the item's own bounds: it
    // never leaves the surface, so the objection above does not apply to it and
    // the compositor is never told anything. Same 0.94 the launcher and the
    // hovered notch content use, so all three arrive alike.
    property bool shown: false
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.94
    transformOrigin: Item.Center
    Component.onCompleted: shown = true

    Behavior on opacity {
        enabled: Theme.animate
        NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
    }
    Behavior on scale {
        enabled: Theme.animate
        NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
    }

    HoverHandler { id: hover }

    Timer {
        // `running` is the whole of the idle story: no card, no timer.
        running: root.duration > 0 && !hover.hovered
        interval: root.duration
        // ⚠️ Not `repeat`. It fires once and the card is gone.
        onTriggered: Services.Notifications.hideToast(root.notification)
    }

    GlassPane {
        anchors.fill: parent
        radius: Theme.radiusLg
        fill: Theme.panelBg
    }

    // Urgency is information, so it gets colour — a single bar down the leading
    // edge rather than a coloured card, because a red rectangle the size of a
    // notification is an alarm rather than a message.
    Rectangle {
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            margins: Theme.space3
        }
        width: Theme.hairline * 3
        radius: Theme.radiusXs
        visible: Services.Notifications.urgencyOf(root.notification) !== "low"
        color: Services.Notifications.urgencyOf(root.notification) === "critical"
               ? Theme.error : Theme.accent
    }

    ColumnLayout {
        id: layout
        anchors {
            fill: parent
            margins: Theme.space4
            leftMargin: Theme.space5
        }
        spacing: Theme.space1
        // The card is a fixed size, so anything that does not fit is cut off
        // rather than allowed to paint outside its own window.
        clip: true

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space2

            BarText {
                Layout.fillWidth: true
                text: root.notification.summary
                font.weight: Theme.weightSemibold
                elide: Text.ElideRight
            }

            // Who sent it, quietly. Without this a bare line of text gives no
            // clue which program is talking to you.
            BarText {
                visible: root.notification.appName.length > 0
                text: root.notification.appName
                color: Theme.fgDim
                font.pixelSize: Theme.fontSizeSm
            }
        }

        BarText {
            Layout.fillWidth: true
            visible: root.notification.body.length > 0
            text: root.notification.body
            color: Theme.fgMuted
            font.pixelSize: Theme.fontSizeSm
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            // Two lines. A notification is a headline, not a document — and
            // the card has a fixed height, so a third line would be clipped
            // mid-glyph rather than elided honestly with an ellipsis.
            maximumLineCount: root.notification.actions.length > 0 ? 1 : 2
        }

        // The actions the sender offered. The server has advertised
        // `actionsSupported` since M5 and nothing ever drew them, which meant
        // "Reply" and "Open" were announced and then silently dropped.
        RowLayout {
            Layout.topMargin: Theme.space1
            visible: root.notification.actions.length > 0
            spacing: Theme.space2

            Repeater {
                model: root.notification.actions

                Pill {
                    id: actionPill
                    required property var modelData
                    interactive: true

                    // ⚠️ NOT anchored. Pill sizes its inner Item from
                    // `childrenRect`, so a child that anchors to that same
                    // Item is a binding loop — the parent's size depends on the
                    // child and the child's position depends on the parent.
                    // QML logs it and carries on with whatever it computed
                    // first, which is why it survived until the smoke test read
                    // the log. Pill centres its content itself.
                    BarText {
                        text: actionPill.modelData.text
                        font.pixelSize: Theme.fontSizeSm
                    }

                    onClicked: {
                        actionPill.modelData.invoke()
                        Services.Notifications.hideToast(root.notification)
                    }
                }
            }
        }

        // Holds the content against the top of a fixed-height card. Without it
        // the layout spreads what it has over the whole height, and a one-line
        // message floats in the middle of a tall box.
        Item { Layout.fillHeight: true }
    }

    // Clicking the card itself puts it away. Dismissing rather than expiring,
    // because a click is you saying you have seen it — so it leaves the unread
    // list too, which merely running out of time does not.
    TapHandler {
        onTapped: Services.Notifications.dismiss(root.notification)
    }
}
