pragma ComponentBehavior: Bound

// One rounded track, N segments, exactly one of them true.
//
// ⚠️ THIS GEOMETRY EXISTED ONCE ALREADY, inside ThemingRow, and it is here
// because he asked for it in the other place too: "das mit den bubbles auch      // english-ok: the report, quoted
// das alles ist null meins". Free-standing pills for a two-way or three-way      // english-ok: the report, quoted
// choice do not say that the choices belong together, and nothing about them
// says which one is currently true except a fill colour that could be a hover.
//
// A track says both at once: these belong together, and exactly one is filled.
//
// ⚠️ IT IS NOT A `SettingRow` KIND AND IT WRITES NOTHING. The caller sets
// `options` and `current` and answers `chosen`. That keeps SettingRow's one
// rule — a row reads and writes ONE dotted path — with the control unable to
// break it, and it is what lets ThemingRow (thirteen programs, one table) and a
// choice row (one setting) share the same object without sharing a schema.
//
// ⚠️ EVERY SEGMENT THE SAME WIDTH, taken from the widest label. Otherwise "Off"
// is half the size of "Neutral", the boundaries land somewhere different on
// every row, and a column of tracks reads as a heap of tracks. `segmentWidth`
// can be pinned from outside so a whole table shares one measurement rather
// than each row measuring its own.
import QtQuick
import "../common"
import "../../theme"

Rectangle {
    id: root

    // [{ value: "dark", label: "Always dark" }, …] — a bare string is allowed
    // and means both at once.
    property var options: []
    property var current: undefined
    property bool usable: true

    // Pinned from outside when several tracks have to agree; 0 means "measure
    // my own widest label".
    property int segmentWidth: 0

    signal chosen(var value)

    function _value(o) {
        return (o !== null && typeof o === "object" && o.value !== undefined)
            ? o.value : o
    }
    function _label(o) {
        if (o !== null && typeof o === "object")
            return String(o.label !== undefined ? o.label : o.value)
        return String(o)
    }

    implicitWidth: segments.implicitWidth + Theme.hairline * 4
    implicitHeight: segments.implicitHeight + Theme.hairline * 4
    radius: Theme.radiusPill
    color: Theme.surfaceHigh
    opacity: root.usable ? 1 : Theme.dimmed

    readonly property int _widest: Math.ceil(ruler.advanceWidth)

    Row {
        id: segments
        anchors.centerIn: parent
        spacing: 0      // literal-ok: the segments meet — the track is the separation

        Repeater {
            model: root.options

            Rectangle {
                id: seg
                required property var modelData

                readonly property bool chosen:
                    String(root.current) === String(root._value(seg.modelData))

                implicitWidth: Math.max(segText.implicitWidth,
                                        root.segmentWidth > 0 ? root.segmentWidth
                                                              : root._widest)
                               + Theme.space3 * 2
                implicitHeight: segText.implicitHeight + Theme.space1 * 2
                radius: Theme.radiusPill
                color: seg.chosen ? Theme.accent
                     : segHover.hovered && root.usable ? Theme.pillHover
                     : "transparent"        // literal-ok: absence of colour

                Behavior on color {
                    enabled: Theme.animate
                    ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                }

                HoverHandler { id: segHover; enabled: root.usable }
                TapHandler {
                    enabled: root.usable
                    onTapped: root.chosen(root._value(seg.modelData))
                }

                BarText {
                    id: segText
                    anchors.centerIn: parent
                    text: root._label(seg.modelData)
                    font.pixelSize: Theme.fontSizeSm
                    color: seg.chosen ? Theme.accentFg : Theme.fg

                    Behavior on color {
                        enabled: Theme.animate
                        ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                    }
                }
            }
        }
    }

    // The widest label, measured rather than counted in characters — the font is
    // the user's choice and "Neutral" is not eight times the width of a letter
    // in all of them.
    TextMetrics {
        id: ruler
        font.pixelSize: Theme.fontSizeSm
        font.family: Theme.fontUi
        text: {
            var longest = ""
            for (var i = 0; i < root.options.length; i++) {
                var t = root._label(root.options[i])
                if (t.length > longest.length)
                    longest = t
            }
            return longest
        }
    }
}
