// A row that DOES something, rather than one that holds a value.
//
// ⚠️ NOT A `SettingRow` WITH A NEW `kind`, and the reason is a tripwire rather
// than taste. Every SettingRow carries a dotted path into shell.json, and
// tests/setting-rows.sh checks that each of those paths is a real key with a
// real reader — that is what stops a slider labelled one thing from writing
// another. "Export settings" has no key, so it would have had to be an
// exception in that check, and an exception is exactly how the next row with a
// wrong key gets in.
//
// It reads like a SettingRow on purpose: same label, same one-line elided hint,
// same spacing. Only the control on the right differs.
import QtQuick
import QtQuick.Layouts
import "../common"
import "../../theme"

ColumnLayout {
    id: root

    property string label: ""
    property string hint: ""
    property string button: ""

    // ⚠️ SPELLED OUT, not derived from the label. A destructive action is drawn
    // in the warning colour, and "does this replace something" is not a thing
    // to infer from a word.
    property bool destructive: false

    // Whether the action can do anything right now. Dimmed and inert rather
    // than hidden, the same way SettingRow handles it and for the same reason:
    // a button you cannot find is worse than one that is visibly unavailable,
    // and hiding it would make the reason disappear along with it.
    property bool usable: true

    // What happened, shown under the row until the next action. Empty means the
    // button has not been pressed yet — an action that reports nothing is an
    // action you have to take on faith.
    property string status: ""
    property bool failed: false

    signal triggered

    spacing: 0      // literal-ok: absence of a gap — the row and its result are one block
    opacity: root.usable ? 1 : Theme.dimmed

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space3

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0  // literal-ok: absence of a gap — label and hint are one block

            BarText {
                Layout.fillWidth: true
                text: root.label
            }

            BarText {
                Layout.fillWidth: true
                visible: root.hint.length > 0
                text: root.hint
                font.pixelSize: Theme.fontSizeSm
                color: Theme.fgMuted
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        Rectangle {
            id: press
            // ⚠️ THE PRESSABLE PART HAS ITS OWN NAME, because the row's name is
            // not enough to aim at. A SettingRow answers a click anywhere along
            // it; an ActionRow does not — only this button does, and it sits at
            // the right-hand end. Aiming at the middle of the row lands on the
            // label and nothing happens, which is indistinguishable from a dead
            // button. Derived from the row's name so there is still one name to
            // remember: "reset-page" -> "reset-page-press".
            objectName: root.objectName.length ? root.objectName + "-press" : ""
            // A row may carry only a statement and no action — the update group
            // opens with one. An empty `button` is that row, and it must take no
            // width at all: a zero-width Rectangle still gets its layout spacing
            // and would push the text off centre by a gap nobody can see.
            visible: root.button.length > 0
            implicitWidth: buttonText.implicitWidth + Theme.space4 * 2
            implicitHeight: buttonText.implicitHeight + Theme.space2 * 2
            radius: Theme.radiusPill
            color: root.destructive
                       ? (hover.hovered ? Theme.error : Theme.surfaceHigher)
                       : (hover.hovered ? Theme.surfaceHigher : Theme.surfaceHigh)

            Behavior on color {
                enabled: Theme.animate
                ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
            }

            // motion-ok: the press feedback is a transform, not a size. Growing
            // implicitHeight instead is what made the sliders jitter — it is a
            // layout size, so the whole page re-laid out on every press.
            scale: tap.pressed ? 0.96 : 1
            Behavior on scale {
                enabled: Theme.animate
                NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
            }

            HoverHandler { id: hover; enabled: root.usable }
            TapHandler {
                id: tap
                enabled: root.usable
                onTapped: root.triggered()
            }

            BarText {
                id: buttonText
                anchors.centerIn: parent
                text: root.button
                color: (root.destructive && hover.hovered) ? Theme.errorFg : Theme.fg
            }
        }
    }

    BarText {
        Layout.fillWidth: true
        Layout.topMargin: root.status.length > 0 ? Theme.space1 : 0
        visible: root.status.length > 0
        text: root.status
        font.pixelSize: Theme.fontSizeSm
        color: root.failed ? Theme.error : Theme.fgMuted
        // ⚠️ WRAPPED, unlike the hint above it. A hint is mine and can be cut to
        // one line with the rest in a tooltip; a result carries a PATH, and half
        // a path is worse than none.
        wrapMode: Text.Wrap
    }
}
