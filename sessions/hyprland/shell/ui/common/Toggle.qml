// A switch: two states, said by position rather than by a word.
//
// The shell had none. What stood in for one was `Tile` — a whole card that
// happens to light up — which is right for the quick panel, where a setting IS
// the tile, and wrong for a settings page, where a row is a label with its
// control at the far end. His reference draws exactly that: "Notch mode" on the
// left, a switch hard against the right edge.
//
// ⚠️⚠️ IT DOES NOT ANSWER THE PRESS, AND THAT IS THE WHOLE FIX FOR B20/B10.
// It used to own a TapHandler, on the reasoning that "a switch's shape IS its
// value, so the thing you press and the thing that changes have to be the same
// rectangle". That reasoning was borrowed from the Pill bug — a hit area
// SMALLER than the lit shape — and it does not apply here, because the row that
// contains this switch carries a TapHandler over its whole width. The row's
// target is LARGER than the switch, never smaller.
//
// What it did instead was fire TWICE. Both handlers wrote, and the second
// computed its new value from state the first had already changed:
//
//     press the row's label     row-handler current=false     -> writes true
//     press the SWITCH          toggle-handler v=false        -> writes false
//                               row-handler   current=false   -> writes true
//
// Read out of the running shell on the lab VM, in that order. The value flipped
// and flipped back inside one press: on screen the bar vanished for a single
// frame and came back, and the file was rewritten with the value it already had.
// That is his report exactly — "der schalter springt sofort wieder zurück",     // english-ok: the report, quoted
// "die bar ist nur minimal kurz da" — and it is why it looked like SOME         // english-ok: the report, quoted
// switches worked: pressing the label works, pressing the switch does not.
//
// ⚠️ AND IT IS WHY EVERY CHECK WAS GREEN. tests/switch-writes.sh calls
// `Config.set` once per row and all 191 land; tools/revert-check.qml proves the
// value survives the file round trip headlessly. Neither has a second handler,
// because neither has a pointer. Nothing that does not click can see this.
//
// So: the row writes, this draws. `tests/switch-one-writer.sh` holds it.
import QtQuick
import "../../theme"
Rectangle {
    id: root

    property bool checked: false

    // ⚠️ `usable`, NOT `enabled` — Item already has `enabled` and shadowing it
    // makes the whole subtree stop accepting input for reasons that look like a
    // layout bug. Same name as Tile.qml uses, for the same reason.
    property bool usable: true

    // ⚠️ THERE IS NO `toggled` SIGNAL ANY MORE, and removing it was as important
    // as removing the handler. A signal nothing emits is a handler that silently
    // never runs — and QML says NOTHING about a handler for a signal that does
    // not exist, which is the trap this project has already paid for once
    // (`options:` where `choices:` was meant: label, hint and an empty space).
    // Both call sites lost their `onToggled` in the same commit.
    //
    // The switch does not move itself either: the row writes the setting and the
    // setting moves the switch, so a refused write stays visible instead of
    // leaving the control saying something the file does not.

    implicitWidth: Theme.space6 + Theme.space3
    implicitHeight: Theme.space5
    radius: Theme.radiusPill

    color: root.checked ? Theme.accent : Theme.surfaceHigh
    opacity: root.usable ? 1 : Theme.dimmed

    Behavior on color {
        enabled: Theme.animate
        ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
    }

    // ⚠️ THE HOVER STAYS AND THE TAP DOES NOT. The pointing hand is a promise
    // that this is pressable, and it still is — the row underneath answers, over
    // a target several hundred pixels wide. A HoverHandler takes no grab, so it
    // cannot become a second writer the way the TapHandler did.
    HoverHandler {
        id: hover
        enabled: root.usable
        cursorShape: Qt.PointingHandCursor
    }

    Rectangle {
        id: knob
        // The inset is half a grid step. A knob flush with the track reads as a
        // filled pill rather than as something that travels.
        readonly property int inset: Theme.space1 / 2

        width: parent.height - inset * 2
        height: width
        radius: width / 2      // literal-ok: a circle is half its width
        y: inset
        x: root.checked ? parent.width - width - inset : inset

        color: root.checked ? Theme.accentFg : Theme.fgMuted

        // The one piece of motion here, and it is the whole point: the state
        // change is a journey between two ends, so seeing it travel is what
        // says which way it went. No overshoot — a switch that bounces reads as
        // uncertain about where it landed.
        Behavior on x {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }
        Behavior on color {
            enabled: Theme.animate
            ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }
    }
}
