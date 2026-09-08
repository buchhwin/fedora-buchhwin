pragma ComponentBehavior: Bound

// A settings row's slider: the quick panel's track, with the number in a box you
// can type in.
//
//     Notch flare      ████████░░░░░░  [14] px
//
// ⚠️⚠️ IT IS `common/LevelRow` NOW, AND THAT REVERSES A CHOICE OF HIS. On 08.08
// he asked for a settings slider with a "dünne Spur, sichtbarer runder Griff"    // english-ok: the request, quoted
// — and this file was built as its own control for exactly that, deliberately
// unlike the volume and brightness rows. He has since asked for the opposite:
// "kannst du die slider im settingsmenu so machen wie die im quickpanel evtl     // english-ok: the request, quoted
// nicht so groß aber vom style das es einheitlich ist".                          // english-ok: the request, quoted
//
// ⚠️ SO IT USES LevelRow RATHER THAN COPYING ITS LOOK. That is the whole point:
// two controls that are supposed to be indistinguishable and are built
// separately are two controls that drift, and this repo has paid for that with
// two sidebars, two calendars and two theme grids. Everything about the track —
// the thickness token, the fill that IS the handle, the grow-while-held that
// goes through `height` inside a slot of constant size — comes from there and
// stays correct here for free.
//
// ⚠️ AND THE BOX STAYS, which he chose when it was put to him. The values in
// this window are exact — 14 px of flare, 619 px of collapsed width, a scroll
// factor of 1.00 — and those are not numbers you hit by dragging. The quick
// panel has no box because a volume is not a number anybody sets precisely.
//
// ⚠️ NO WHEEL. LevelRow's wheel handler covers the whole row and accepts the
// event, so a settings page stopped scrolling the moment the pointer crossed a
// slider — and every notch it swallowed wrote a value into the setting it was
// merely passing over. `wheel: false` is that switch, and it exists because of
// this file.
import QtQuick
import QtQuick.Layouts
import "../common"
import "../../theme"

Item {
    id: root

    property real value: 0          // the real value, in the setting's own units
    property real from: 0
    property real to: 100
    property real step: 1
    property bool usable: true
    // How many decimals the box shows. 0 for pixels, 2 for a scroll factor.
    property int decimals: 0
    // "px", "ms", "%". Stays OUTSIDE the box, because the box is what you type
    // into and a unit inside it would have to be parsed back out again.
    property string unit: ""

    // Live while dragging, so the number keeps up with the handle.
    signal moved(real v)
    // The end of a drag, or a typed value committed. Config.set only schedules a
    // write; a caller flushes on this.
    signal decided(real v)

    implicitHeight: Math.max(track.implicitHeight, box.implicitHeight)

    readonly property real _span: root.to - root.from
    readonly property real fraction:
        root._span <= 0 ? 0
                        : Math.max(0, Math.min(1, (root.value - root.from) / root._span))

    function _snap(v) {
        var s = root.step > 0 ? root.step : 1
        var n = root.from + Math.round((v - root.from) / s) * s
        return Math.max(root.from, Math.min(root.to, n))
    }

    // ⚠️ A fraction back into the setting's own units, snapped. LevelRow speaks
    // 0..1 and knows nothing about pixels or milliseconds — which is why it can
    // be shared at all.
    function _fromFraction(f) {
        return root._snap(root.from + Math.max(0, Math.min(1, f)) * root._span)
    }

    opacity: root.usable ? 1 : Theme.dimmed

    RowLayout {
        anchors.fill: parent
        spacing: Theme.space3

        LevelRow {
            id: track
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            // ⚠️ `enabled`, not `live`. `live: false` is LevelRow's "muted or no
            // hardware" state and draws the fill grey AT ZERO — on a row that is
            // merely not applicable that would show an empty track and lie about
            // the value. `enabled: false` stops the handlers and leaves the
            // reading alone; the dimming is the root's opacity above.
            enabled: root.usable

            value: root.fraction
            // No symbol and no percentage: the label is the row's, and the exact
            // number lives in the box where it can be typed.
            icon: ""
            showValue: false
            wheel: false

            onMoved: function (f) { root.moved(root._fromFraction(f)) }
            onReleased: function (f) { root.decided(root._fromFraction(f)) }
        }

        // ----------------------------------------------------------- the box
        // ⚠️ IT SHOWS THE VALUE UNTIL YOU TOUCH IT. A box that is always an edit
        // field is a box whose contents you have to trust; this one is the
        // reading, and typing in it is the other way to set the same thing.
        // Escape puts the reading back, which is what makes it safe to click.
        Rectangle {
            id: box
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Math.max(field.implicitWidth + Theme.space2 * 2,
                                    numberRuler.advanceWidth + Theme.space3 * 2)
            implicitHeight: field.implicitHeight + Theme.space1 * 2
            radius: Theme.radiusSm
            color: field.activeFocus ? Theme.surfaceHigher
                 : boxHover.hovered && root.usable ? Theme.pillHover
                 : Theme.surfaceHigh

            Behavior on color {
                enabled: Theme.animate
                ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
            }

            HoverHandler { id: boxHover; enabled: root.usable }

            TextInput {
                id: field
                anchors.centerIn: parent
                width: parent.width - Theme.space2 * 2
                enabled: root.usable
                horizontalAlignment: TextInput.AlignHCenter
                color: Theme.fg
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontSizeSm
                selectByMouse: true
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentFg
                inputMethodHints: Qt.ImhFormattedNumbersOnly

                // ⚠️ NOT BOUND WHILE IT HAS FOCUS. A binding that keeps writing
                // the current value into the box would delete what is being
                // typed on every keystroke that lands out of range.
                text: field.activeFocus ? field.text
                                        : root.value.toFixed(root.decimals)

                function commit() {
                    var n = parseFloat(field.text.replace(",", "."))
                    if (!isNaN(n))
                        root.decided(root._snap(n))
                    field.text = Qt.binding(function () {
                        return field.activeFocus ? field.text
                                                 : root.value.toFixed(root.decimals)
                    })
                    field.focus = false
                }

                onAccepted: field.commit()
                Keys.onEscapePressed: {
                    field.text = root.value.toFixed(root.decimals)
                    field.focus = false
                }
                onActiveFocusChanged: {
                    if (field.activeFocus)
                        field.selectAll()
                    else
                        field.commit()
                }
            }
        }

        BarText {
            Layout.alignment: Qt.AlignVCenter
            visible: root.unit.length > 0
            text: root.unit
            font.pixelSize: Theme.fontSizeSm
            color: Theme.fgMuted
        }
    }

    // The widest number the range can produce, so the box does not resize as the
    // value grows — a box that changes width while you drag drags the rail with
    // it, which is the content-drives-layout fault one level down.
    TextMetrics {
        id: numberRuler
        font.pixelSize: Theme.fontSizeSm
        font.family: Theme.fontUi
        text: {
            var lo = root.from.toFixed(root.decimals)
            var hi = root.to.toFixed(root.decimals)
            return lo.length >= hi.length ? lo : hi
        }
    }
}
