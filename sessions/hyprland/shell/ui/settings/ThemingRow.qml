pragma ComponentBehavior: Bound

// One program, one line, four states side by side.
//
// ⚠️ THIRTEEN NEARLY IDENTICAL ROWS WERE THE WALL HE MEANT. As SettingRows they
// were a label, an explaining line and a full-width dropdown each — about
// ninety pixels a program, so four of the thirteen fitted on screen and the
// answer to "what is kitty set to" was three scrolls away. He chose the compact
// table over pills, and the reason is the same one that made the dropdown
// exist: a page where every row looks alike has to be scannable down a column,
// not readable line by line.
//
// ⚠️ IT IS NOT A `SettingRow` KIND, and that is deliberate. A `kind` is how a
// value is edited; this is how thirteen rows are laid out NEXT TO each other,
// which is a property of the group rather than of any one row. Making it a kind
// would have put table geometry — the label column width, the shared segment
// widths — inside a component that knows nothing about its neighbours.
//
// ⚠️ BUT IT KEEPS SettingRow'S ONE RULE, and everything depends on that: it
// reads and writes through ONE dotted `key` and nothing else. tests/
// setting-rows.sh anchors on `^ *key:` to count rows, so these thirteen still
// answer for their thirteen settings; and the failure that rule exists to
// prevent — a line labelled "kitty" that writes `theming.qt` — is still
// impossible here, because there is no second place for the two to drift.
import QtQuick
import QtQuick.Layouts
import "../common"
import "../../config"
import "../../theme"

RowLayout {
    id: root

    // The dotted path, written out at the call site as a literal — see above.
    property string key: ""
    property string label: ""
    // One line, elided, with the rest in a tooltip. Same rule as SettingRow: a
    // hint that wraps would make the table rows different heights, and a table
    // whose rows are different heights is a list again.
    property string hint: ""

    // ⚠️ A MARKER, AND IT IS NOT CEREMONY. "Set all to …" has to find the
    // program rows and only those, and every candidate for telling them apart by
    // accident turned out to be wrong: `states` is a property of EVERY QML Item
    // (the list of State objects), so it says nothing at all, and the
    // "theming." prefix also matches `theming.enabled` and `theming.mode` —
    // a switch and the default state, neither of which is a program. Setting
    // those two to "neutral" would switch the whole feature off from a button
    // that promised to colour things. One property that means what it says.
    readonly property bool programRow: true

    // [{ value: "inherit", label: "Follow" }, …]
    property var states: []
    property bool usable: true

    // How wide the name column is. Pinned by the page from its longest label,
    // for the reason OutputScales learned the hard way: `Layout.preferredWidth`
    // is a WISH, and a neighbour with `fillWidth` takes the space back.
    property int labelWidth: 0

    readonly property var current: root.key.length > 0 ? Config.get(root.key) : undefined

    // ⚠️ The same objectName SettingRow uses, because the search reaches rows by
    // it after navigating to a page — without this the thirteen would become
    // unfindable the moment they stopped being SettingRows.
    objectName: root.key

    property bool found: false
    function flash() {
        root.found = true
        forget.restart()
    }
    Timer {
        id: forget
        interval: Theme.durSlow * 6
        onTriggered: root.found = false
    }

    spacing: Theme.space3
    opacity: root.usable ? 1 : Theme.dimmed

    HoverHandler { id: rowHover }

    BarText {
        id: name
        Layout.preferredWidth: root.labelWidth
        Layout.minimumWidth: root.labelWidth
        Layout.maximumWidth: root.labelWidth
        text: root.label
        color: root.found ? Theme.accent : Theme.fg
        font.weight: root.found ? Theme.weightSemibold : Theme.weightNormal
        elide: Text.ElideRight

        Behavior on color {
            enabled: Theme.animate
            ColorAnimation { duration: Theme.durSlow; easing.type: Theme.easing }
        }
    }

    // ⚠️ A WARNING SIGN RATHER THAN THE SENTENCE. GTK's row carries a real
    // caveat — a running program keeps its colours until it restarts — and in a
    // table there is no line to put it on. The sign is in the row, the sentence
    // is under the pointer, and the geometry does not move.
    Icon {
        visible: root.hint.length > 0
        text: "info"
        size: Theme.fontSizeSm
        color: Theme.fgMuted
    }

    Item { Layout.fillWidth: true }

    // ----------------------------------------------------- the four segments
    //
    // ⚠️ THE GEOMETRY MOVED OUT, to ui/settings/Segmented.qml, and this file is
    // the reason it is worth having: he asked for the same track on ordinary
    // choice rows ("das mit den bubbles auch"), and a second copy of "one       // english-ok: the report, quoted
    // rounded track, equal segments measured off the widest word" is exactly
    // the shape that drifts — one gets a new radius, the other keeps the old
    // padding, and nobody notices until they are on screen together.
    //
    // What stays here is what belongs to the TABLE rather than to the control:
    // `segmentWidth` is pinned from the page so all thirteen tracks agree, and
    // the write goes through this row's one dotted `key`.
    Segmented {
        options: root.states
        current: root.current
        usable: root.usable
        segmentWidth: root.segmentWidth
        onChosen: function (v) {
            Config.set(root.key, v)
            Config.flush()
        }
    }

    // The widest state word, so every segment on every row is the same size.
    // Measured off a hidden copy rather than guessed at a character count — the
    // font is the user's choice and "Neutral" is not eight times the width of a
    // letter in all of them.
    property int segmentWidth: Math.ceil(ruler.advanceWidth)
    TextMetrics {
        id: ruler
        font.pixelSize: Theme.fontSizeSm
        font.family: Theme.fontUi
        text: {
            var longest = ""
            for (var i = 0; i < root.states.length; i++) {
                var t = String(root.states[i].label !== undefined
                               ? root.states[i].label : root.states[i].value)
                if (t.length > longest.length)
                    longest = t
            }
            return longest
        }
    }

    Tooltip {
        target: name
        active: rowHover.hovered && root.hint.length > 0
        text: root.hint
    }
}
