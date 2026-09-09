// "Reset everything" asks first, in words, on a surface of its own.
//
// ⚠️ HIS CHOICE, MADE AFTER BEING ASKED: a real confirmation rather than the
// two-stage press the rest of this window uses. The reasoning he took: the page
// reset is small and its first stage now prints a line beside itself, while this
// one throws away every setting there is. The two-stage form is also what
// produced "die reset taste geht nicht" — stage one was four words under the    // english-ok: his report, quoted
// finger that pressed them.
//
// ⚠️⚠️ AND IT IS NOT A PopupWindow. That is B25, and the measurement is in the
// handover: a popup with `grabFocus` is an xdg-popup with a grab, the compositor
// dismisses it on a click beside it, and quickshell then WRITES `visible =
// false`. A written value replaces the binding rather than being stopped by it,
// so the flag says open, the surface is gone, and it never opens again.
//
// So this is an Item inside the settings window, its own visibility IS the
// state (`open` is an alias, not a flag with a binding beside it), and the
// catcher underneath is a plain MouseArea. No compositor, no grab, nothing to
// destroy a binding.
import QtQuick
import QtQuick.Layouts
import "../common"
import "../../config"
import "../../theme"

Item {
    id: root

    // ⚠️ AN ALIAS. See above: a `property bool open` with `visible: root.open`
    // is the exact shape that died, because whoever writes `visible` wins and
    // the binding does not come back.
    property alias open: sheet.visible

    visible: sheet.visible

    // Everything behind it is dimmed and unclickable. The dim is what says "the
    // rest of the window is waiting for an answer" — without it a sheet reads as
    // a card that happens to be on top.
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: sheet.visible ? 1 : 0
        Behavior on opacity {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }
        // Swallows the click. Clicking beside the sheet cancels — the same
        // answer as the button, because a dismissal must never be the
        // destructive branch.
        MouseArea {
            anchors.fill: parent
            onClicked: root.open = false
        }
    }

    Rectangle {
        id: sheet
        visible: false
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.space6 * 2, Theme.space6 * 13)
        implicitHeight: body.implicitHeight + Theme.space5 * 2
        height: implicitHeight
        radius: Theme.radiusLg
        color: Theme.surfaceHigh

        // motion-ok: the sheet arrives by scale and opacity, which the
        // compositor never hears about. Its HEIGHT is set from its content and
        // never animated — rule 7, and the reason the settings window used to
        // twitch.
        scale: sheet.visible ? 1 : 0.96
        Behavior on scale {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }

        // Nothing behind it answers a click that lands on the sheet.
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: body
            anchors {
                left: parent.left; right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: Theme.space5; rightMargin: Theme.space5
            }
            spacing: Theme.space4

            BarText {
                Layout.fillWidth: true
                text: "Reset everything?"
                font.pixelSize: Theme.fontSizeLg
                font.weight: Theme.weightSemibold
                wrapMode: Text.Wrap
            }

            // ⚠️ IT SAYS WHAT GOES, ITEM BY ITEM. "Are you sure?" is a question
            // nobody can answer, because it does not say what about. He asked
            // for "deutlichem hinweis was der button macht" in as many words.   // english-ok: his request, quoted
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.space2

                Repeater {
                    model: [
                        "Every setting on all pages goes back to the way it ships.",
                        "The wallpaper and the colour scheme go back to the ones that come with the desktop.",
                        "Your keyboard shortcuts and window rules go with them.",
                        "The file you have now is kept as shell.json.bak, so this is recoverable by hand."
                    ]

                    RowLayout {
                        required property string modelData
                        Layout.fillWidth: true
                        spacing: Theme.space2

                        Icon {
                            Layout.alignment: Qt.AlignTop
                            text: "chevron_right"
                            size: Theme.fontSizeSm
                            color: Theme.fgMuted
                        }
                        BarText {
                            Layout.fillWidth: true
                            text: parent.modelData
                            color: Theme.fgMuted
                            font.pixelSize: Theme.fontSizeSm
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space3

                Item { Layout.fillWidth: true }

                // ⚠️ CANCEL FIRST AND ON THE LEFT, which is where the eye lands
                // and the pointer already is. The destructive one is never the
                // default and never where a reflex click goes.
                Pill {
                    interactive: true
                    BarText { text: "Cancel" }
                    onClicked: root.open = false
                }

                Rectangle {
                    implicitWidth: goText.implicitWidth + Theme.space4 * 2
                    implicitHeight: goText.implicitHeight + Theme.space2 * 2
                    radius: Theme.radiusPill
                    color: goHover.hovered ? Theme.error : Theme.surfaceHigher

                    Behavior on color {
                        enabled: Theme.animate
                        ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                    }

                    // motion-ok: press feedback is a transform, never a size.
                    scale: goTap.pressed ? 0.96 : 1
                    Behavior on scale {
                        enabled: Theme.animate
                        NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                    }

                    HoverHandler { id: goHover }
                    TapHandler {
                        id: goTap
                        onTapped: {
                            root.open = false
                            Backup.resetSettings()
                        }
                    }

                    BarText {
                        id: goText
                        anchors.centerIn: parent
                        text: "Reset everything"
                        color: goHover.hovered ? Theme.errorFg : Theme.fg
                    }
                }
            }
        }
    }

    // Escape is the same answer as Cancel, for the same reason: a way out must
    // never be the destructive branch.
    Keys.onEscapePressed: root.open = false
    focus: sheet.visible
}
