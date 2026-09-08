pragma ComponentBehavior: Bound

// One row about one monitor.
//
// ⚠️ WHY THIS EXISTS BESIDE SettingRow, WHICH IS THE OBVIOUS QUESTION. SettingRow
// is built around a single dotted path — "the `key` is the whole design" — and
// that is what lets tests/setting-rows.sh count the promise "every setting has a
// row". `outputs` is a LIST OF OBJECTS, one per monitor, so there is no path
// that names "the refresh rate of DP-2", and setting-rows.sh names `outputs` in
// its exemption list rather than letting a pattern excuse it.
//
// ⚠️ SO THIS DOES NOT COPY SettingRow, IT COMPOSES THE SAME PARTS. Toggle,
// Dropdown, SettingSlider and BarText are the same components the rest of the
// window uses, in the same arrangement: label left, control right, slider full
// width underneath, hint elided to one line. A second row implementation with
// its own idea of a switch is how the old project ended up with six colour
// vocabularies — the drift starts with "close enough".
//
// ⚠️ AND IT CARRIES `advanced` FOR THE SAME REASON EVERY OTHER ROW DOES.
// SettingGroup counts its advanced children to label the "show more" door; a
// row without the property is counted as simple and the door says the wrong
// number.
import QtQuick
import QtQuick.Layouts
import "../common"
import "../../theme"

ColumnLayout {
    id: root

    property string label: ""
    property string hint: ""
    property bool advanced: false
    property bool usable: true

    // "switch" | "choice" | "slider"
    property string kind: "switch"

    property bool checked: false
    // [{ value: …, label: … }] — the same shape Dropdown takes.
    property var choices: []
    property var current: undefined

    property real from: 0
    property real to: 100
    property real step: 1
    property int decimals: 0
    property string unit: ""

    // ⚠️ ONE SIGNAL, NOT ONE PER KIND. The page connects `changed` and writes
    // through config/Outputs.qml; a per-kind signal would put the decision
    // "which writer does this row use" in two places.
    signal changed(var value)

    // ⚠️ SAME `parent` CONTRACT AS SettingRow: rows are direct children of
    // SettingGroup's holder, which publishes `showAdvanced`. A row with no such
    // parent shows itself, so a check harness that builds one in isolation
    // still sees it.
    visible: !root.advanced
             || parent === null
             || parent.showAdvanced === undefined
             || parent.showAdvanced

    spacing: Theme.space1
    opacity: root.usable ? 1 : Theme.dimmed

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space3

        // The whole row is the target for a switch, as everywhere else in this
        // window — this shell has already paid once for a hit area smaller than
        // the thing it looked like.
        TapHandler {
            enabled: root.kind === "switch" && root.usable
            onTapped: root.changed(!root.checked)
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0      // literal-ok: absence of a gap — label and hint are one block

            BarText {
                Layout.fillWidth: true
                text: root.label
                color: Theme.fg
            }
            BarText {
                Layout.fillWidth: true
                visible: root.hint.length > 0
                text: root.hint
                font.pixelSize: Theme.fontSizeSm
                color: Theme.fgMuted
                // Elided rather than wrapped, and rather than shown on hover:
                // a row that changes height under the pointer moves the page
                // while you are reading it.
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // ⚠️ THE SAME DOUBLE WRITE WAS HERE, WORD FOR WORD. The row's TapHandler
        // above and the switch's own both answered one press, and the second
        // computed from state the first had changed. It was found on
        // settings/SettingRow.qml and this file had it too — which is why the
        // fault reads as "manche switches", not "the bar switch". The row is the  // english-ok: the report, quoted
        // only writer now; the switch draws.
        Toggle {
            visible: root.kind === "switch"
            usable: root.usable
            checked: root.checked
        }

        Dropdown {
            visible: root.kind === "choice"
            usable: root.usable
            options: root.choices
            current: root.current === undefined ? "" : String(root.current)
            onPicked: function (v) { root.changed(v) }
        }
    }

    // ⚠️ `visible: active`. A Loader with `active: false` is zero pixels tall
    // and STILL VISIBLE, and QtQuick.Layouts gives every visible child its row
    // spacing — the ghost-gap measured at 48 px where 16 was meant.
    Loader {
        Layout.fillWidth: true
        active: root.kind === "slider"
        visible: active
        sourceComponent: SettingSlider {
            usable: root.usable
            value: Number(root.current)
            from: root.from
            to: root.to
            step: root.step
            decimals: root.decimals
            unit: root.unit
            // ⚠️ BOTH, AND THEY MEAN DIFFERENT THINGS. `moved` is every frame of
            // a drag and goes through the debounced writer; `decided` is the end
            // of the gesture and is what flushes. The page decides which is
            // which — see config/Outputs.qml's `flush` argument.
            onMoved: function (v) { root.changed({ value: v, settled: false }) }
            onDecided: function (v) { root.changed({ value: v, settled: true }) }
        }
    }
}
