// A value between nothing and everything: icon, track, percentage.
//
// Volume and brightness are the same object with different words, and writing
// them twice is how two things that should move identically start to drift —
// one gets a thinner track, the other keeps the old step size, and nobody
// notices until they are side by side in the quick settings.
//
// ⚠️ THE TRACK USED TO BE FOUR PIXELS TALL in everything except the control
// centre, and it was reported as "die Regler sind extrem blöd gemacht". Four     // english-ok: quoted brief
// pixels at scale 1 is a hairline: you cannot see where the value is without
// looking for it, and you cannot grab it at all — the handlers had already been
// moved onto a taller invisible item precisely because the visible thing was
// unusable. That is the shape of a control that has given up.
//
// The reference for the new one is One UI 8, asked for by name: a thick rounded
// track where THE FILL ITSELF IS THE HANDLE. There is no knob, because a knob
// is a small target inside a large one — the same fault this repo fixed in Pill
// — and because a bar that is entirely filled reads as "all the way" far more
// directly than a dot at the right-hand end.
//
// It grows while you hold it. That is not decoration: it is the only feedback a
// control without a knob can give that it has you, and One UI does exactly this.
import QtQuick
import QtQuick.Layouts
import "../../theme"

RowLayout {
    id: root

    property string icon: ""
    property real value: 0            // 0..1
    property bool live: true          // false = muted, or no hardware
    property int steps: 20            // 20 → 5 % a notch, as the hardware keys use

    // ⚠️ TWO SHAPES, ONE COMPONENT. The reference
    // (2026-08-06/vorlage-control-center.png) draws the control-centre levels
    // as tall rounded bars with the symbol INSIDE them and no percentage at
    // all; the settings rows are the same control at a calmer size. Building the
    // fat one separately is how volume and brightness drift apart, which is the
    // thing the head of this file exists to prevent, so it is a property.
    property bool fat: false

    // Whether the percentage is written at the end. Off for the track position
    // in the media card, where two clocks say it better — and off implicitly on
    // the fat shape, which the reference draws without one.
    property bool showValue: true

    signal moved(real fraction)       // absolute, from a tap or drag
    signal nudged(int direction)      // +1 / -1, from the wheel

    // The end of a drag, with the value it ended on. Volume and the laptop
    // panel have no use for it — they are fast enough to follow the finger —
    // but an external monitor over DDC/CI is not, and a caller that can only
    // afford to send once needs to know WHEN once is. Emitted after the last
    // `moved`, and after a tap too: a tap is a drag with no middle.
    signal released(real fraction)

    // The icon beside the track, where the caller wants it to do something —
    // muting, on the volume row. Off by default: see the note beside the Icon.
    property bool iconClickable: false
    signal iconTapped

    spacing: Theme.space3

    // Held: by a finger on the track, or by a drag in progress. Both, because a
    // tap that never becomes a drag still deserves the same acknowledgement.
    readonly property bool held: press.pressed || drag.active

    // ⚠️ EVERY NUMBER HERE IS A TOKEN, including the ones that only exist as a
    // sum. tests/no-literals.sh would catch a bare radius; it would NOT catch a
    // bare height, and a hand-typed 48 is how one of these two shapes ends up
    // scaling with uiScale and the other not.
    readonly property int thickness: root.fat ? Theme.space6 + Theme.space4
                                              : Theme.space4

    // ⚠️ THE WHEEL IS OFF INSIDE A SCROLLING PAGE, and this was reported as
    // "die slider gehen nicht mit sondern sind freeze" — scrolling the settings   // english-ok: quoted brief
    // stopped dead whenever the pointer crossed a slider.
    //
    // It is worse than it sounds. The handler covers the WHOLE ROW and answers
    // `ev.accepted = true`, so the wheel never reaches the Flickable — and every
    // notch it swallowed CHANGED THE SETTING it was passing over. Scrolling
    // through a page silently rewrote it.
    //
    // It stays on where it was designed for: the quick panel and the notch
    // readouts, which do not scroll and where nudging is the whole point.
    // SettingRow turns it off.
    property bool wheel: true

    WheelHandler {
        // The whole row, not just the track. Aiming is the thing being removed
        // here; a hit area the size of a 4 px slider would defeat the point.
        target: null
        enabled: root.wheel
        onWheel: function (ev) {
            root.nudged(ev.angleDelta.y > 0 ? 1 : -1)
            ev.accepted = true
        }
    }

    // Beside the track when thin, inside it when fat — so it is the same Icon
    // either way rather than one of two that could drift.
    Icon {
        // An empty name would still reserve a glyph's width, so the check is on
        // the content rather than only on the shape.
        visible: !root.fat && root.icon.length > 0
        text: root.icon
        size: Theme.fontSizeLg
        color: root.live ? Theme.fg : Theme.fgDim

        // ⚠️ ONLY WHERE SOMEBODY LISTENS. A tappable icon over a row nobody
        // wired would be a dead patch on the track — press it and the volume
        // does not move either, because the handler below swallowed the press.
        // Rule 5 in miniature: no target without an answer. So the caller says
        // so, and the notch's read-outs stay plain.
        HoverHandler { enabled: root.iconClickable; cursorShape: Qt.PointingHandCursor }
        // ⚠️⚠️ `WithinBounds`, for the reason spelled out in ui/quick/Tile.qml:
        // the row itself answers a tap by SETTING THE VALUE at that spot, and a
        // TapHandler's default grab is passive — so muting would also jump the
        // volume to wherever the icon happens to sit.
        TapHandler {
            enabled: root.iconClickable
            gesturePolicy: TapHandler.WithinBounds
            onTapped: root.iconTapped()
        }
    }

    // ⚠️ A SLOT OF CONSTANT HEIGHT, and the track grows INSIDE it. This was
    // reported as the sliders jittering while dragged: the track's growth went
    // through `implicitHeight`, which is a LAYOUT size, so every press relaid
    // out the row — and with it the whole page below. The feedback was real and
    // it moved everything else to deliver it.
    //
    // The slot is as tall as the track can ever get, so nothing outside the row
    // can move; `height` inside it is not a layout property and animates freely.
    Item {
        id: slot
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        implicitHeight: root.thickness + Theme.space1

        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: root.thickness + (root.held ? Theme.space1 : 0)
            radius: Theme.radiusPill
            color: Theme.surfaceHigh

            // The grow, and the shrink back. Short, because this is an answer to
            // a touch rather than a movement of its own — anything slower reads
            // as the control being late.
            //
            // motion-ok: the track is anchored (left/right/verticalCenter), so
            // its height is its own and does not size the row around it. It used
            // to be `implicitHeight`, which IS a layout size, and that relaid out
            // the whole page on every press — reported as sliders jittering while
            // dragged.
            Behavior on height {
                enabled: Theme.animate
                NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
            }

            Rectangle {
                id: fill
                // ⚠️ NEVER NARROWER THAN IT IS TALL. Below that the pill radius has
                // no room to round and the fill degenerates into a lozenge that
                // looks like a rendering fault — and in fat mode the symbol inside
                // would be sitting on bare grey. At a true zero the control still
                // has to look like a control set to zero.
                width: Math.max(track.height,
                                track.width * Math.max(0, Math.min(1, root.live ? root.value : 0)))
                height: parent.height
                radius: parent.radius
                color: root.live ? Theme.accent : Theme.surfaceHigher

                // The fill follows the value rather than jumping to it, which is
                // what makes a key held down feel continuous instead of stepped.
                //
                // motion-ok: this width IS the reading. It is the level itself,
                // drawn inside a track of fixed width, and nothing lays out
                // around it.
                Behavior on width {
                    enabled: Theme.animate
                    NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                }
                Behavior on color {
                    enabled: Theme.animate
                    ColorAnimation { duration: Theme.durBase; easing.type: Theme.easing }
                }
            }

            // ⚠️ SITS ON THE TRACK, NOT ON THE FILL, and it is the fill that moves
            // under it. Anchored into the fill it would slide off the left end as
            // the level dropped; anchored here it stays where the symbol belongs
            // and simply stops being on the accent when the fill retreats past it.
            // That is what the fill's minimum width above is protecting.
            Icon {
                visible: root.fat
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Theme.space3
                text: root.icon
                size: Theme.fontSizeLg
                color: root.live ? Theme.accentFg : Theme.fgDim
            }

        }

        // ⚠️ OUTSIDE THE TRACK NOW, filling the slot. It used to be the track's
        // child, so it inherited the very size change it was supposed to be
        // insulated from — and the fraction under the finger shifted as the
        // track grew. The slot never changes, so neither does this.
        Item {
            id: grab
            anchors.fill: parent

            // Pressed-state only. The tap itself is below, because a HoverHandler
            // and a TapHandler answer different questions and sharing one would
            // make "held" true for a pointer that is merely passing over.
            TapHandler {
                id: press
                onTapped: function (p) {
                    var f = p.position.x / grab.width
                    root.moved(f)
                    root.released(f)
                }
            }
            DragHandler {
                id: drag
                target: null
                property real last: 0
                onCentroidChanged: if (active) {
                    last = centroid.position.x / grab.width
                    root.moved(last)
                }
                // ⚠️ `onActiveChanged`, not a handler on the release itself. A
                // DragHandler has no "let go" signal; it has an `active` that
                // goes false — and it also goes false when the drag is
                // CANCELLED, which is the same thing for our purposes: the
                // finger is gone and the last value it named is the one that
                // counts.
                onActiveChanged: if (!active) root.released(last)
            }
        }
    }

    // No number on the fat one — the reference has none, and it is right: a bar
    // that fills most of the panel already says how far along it is, and "62 %"
    // is a precision nobody sets a volume to.
    BarText {
        visible: !root.fat && root.showValue
        text: Math.round(root.value * 100) + "%"
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
        // Fixed width, or the track jumps sideways every time the number goes
        // from two digits to three.
        Layout.minimumWidth: Theme.space6 + Theme.space2
        horizontalAlignment: Text.AlignRight
    }
}
