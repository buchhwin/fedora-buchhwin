// The calculator: one line to type in, the answer underneath as you type.
//
// ⚠️ NO KEYPAD. A grid of buttons is for a machine with no keyboard; this one
// opens on a key, in front of a keyboard, and the fastest way to work out
// 0x2000 - 4096 is to type it. What the buttons would have been is a row of
// bases instead — the answer in decimal, hex and binary at once, which is the
// question this actually gets asked on a machine like his.
//
// It is a page like any other rather than a separate window, so it is themed by
// construction: there is nothing here that could disagree with the palette,
// which was the whole point of building it instead of installing one.
import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../ipc"
import "../../../services" as Services
import "../../common"

ColumnLayout {
    id: root

    implicitWidth: Theme.space6 * 15
    spacing: Theme.space2

    readonly property var result: Services.Calculator.evaluate(input.text)
    readonly property bool whole: root.result.ok
        && Services.Calculator.isWhole(root.result.v)

    // ------------------------------------------------------------- the input
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: input.implicitHeight + Theme.space3 * 2
        radius: Theme.radiusSm
        color: Theme.surfaceHigh

        TextInput {
            id: input
            anchors.fill: parent
            anchors.margins: Theme.space3
            verticalAlignment: Text.AlignVCenter
            color: Theme.fg
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeLg
            selectByMouse: true
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentFg

            // Enter keeps the answer as `ans` and selects what you typed, so
            // the next expression either builds on it or replaces it without a
            // keystroke in between.
            onAccepted: {
                if (root.result.ok) {
                    Services.Calculator.remember(root.result.v)
                    input.selectAll()
                }
            }

            Keys.onEscapePressed: Ipc.collapse()
            Component.onCompleted: input.forceActiveFocus()
        }

        // The brief's rule for an empty state is one sentence, not an empty box.
        BarText {
            anchors.left: parent.left
            anchors.leftMargin: Theme.space3
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text.length === 0
            text: "12 * 4,  0xff + 1,  sqrt(2)"
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeLg
            color: Theme.fgDim
        }
    }

    // ------------------------------------------------------------ the answer
    BarText {
        Layout.fillWidth: true
        visible: root.result.ok
        text: root.result.ok ? Services.Calculator.format(root.result.v) : ""
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeDisplay
        font.weight: Theme.weightSemibold
        color: Theme.accent
        elide: Text.ElideRight
    }

    // Hex and binary, for whole numbers only — a base is a fact about an
    // integer, and 0x1.8 would be a fact about nothing.
    RowLayout {
        Layout.fillWidth: true
        visible: root.whole
        spacing: Theme.space4

        BarText {
            text: Services.Calculator.hexOf(root.result.v)
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSm
            color: Theme.fgMuted
        }

        BarText {
            Layout.fillWidth: true
            visible: text.length > 0
            text: Services.Calculator.binOf(root.result.v)
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSm
            color: Theme.fgMuted
            elide: Text.ElideRight
        }
    }

    // Errors are shown quietly and only once there is something to be wrong
    // about: half a typed expression is not a mistake, it is a half-typed
    // expression, so an empty message stays empty.
    BarText {
        Layout.fillWidth: true
        visible: !root.result.ok && root.result.error.length > 0
        text: root.result.error
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgDim
        wrapMode: Text.WordWrap
    }

    BarText {
        Layout.fillWidth: true
        visible: Services.Calculator.hasAnswer
        text: "ans = " + Services.Calculator.format(Services.Calculator.answer)
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgDim
    }
}
