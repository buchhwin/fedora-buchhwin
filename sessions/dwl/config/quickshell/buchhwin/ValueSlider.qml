import QtQuick

// Touchpad-friendly value control: clicking jumps to that position, dragging
// tracks continuously, and the value can also be entered numerically.
Item {
    id: root
    Theme { id: theme }

    property real from: 0
    property real to: 100
    property real value: 0
    property color accent: theme.blue
    property string suffix: "%"
    signal valueEdited(real newValue)

    implicitHeight: 32
    implicitWidth: 220

    function clamp(number) {
        return Math.max(from, Math.min(to, Math.round(number)))
    }

    function apply(number) {
        const next = clamp(number)
        valueEdited(next)
        if (!numberInput.activeFocus) numberInput.text = String(next)
    }

    onValueChanged: if (!numberInput.activeFocus) numberInput.text = String(clamp(value))
    Component.onCompleted: numberInput.text = String(clamp(value))

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: valueBox.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        radius: 3
        color: theme.bg

        Rectangle {
            width: Math.max(0, Math.min(parent.width, parent.width * (root.value - root.from) / (root.to - root.from)))
            height: parent.height
            radius: parent.radius
            color: root.accent
        }

        Rectangle {
            x: Math.max(-9, Math.min(parent.width - 9, parent.width * (root.value - root.from) / (root.to - root.from) - 9))
            anchors.verticalCenter: parent.verticalCenter
            width: 18; height: 18; radius: 9
            color: theme.text
            border.width: 2
            border.color: root.accent
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -12
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            function applyPointer(mouseX) {
                const localX = mapToItem(track, mouseX, 0).x
                root.apply(root.from + (root.to - root.from) * Math.max(0, Math.min(track.width, localX)) / track.width)
            }
            onPressed: mouse => applyPointer(mouse.x)
            onPositionChanged: mouse => { if (pressed) applyPointer(mouse.x) }
        }
    }

    Rectangle {
        id: valueBox
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 62; height: 28; radius: 7
        color: theme.bg
        border.width: numberInput.activeFocus ? 2 : 1
        border.color: numberInput.activeFocus ? root.accent : theme.border

        TextInput {
            id: numberInput
            anchors.left: parent.left; anchors.leftMargin: 7
            anchors.right: unit.left; anchors.rightMargin: root.suffix.length ? 2 : -2
            anchors.verticalCenter: parent.verticalCenter
            color: theme.text
            font.family: theme.font
            font.pixelSize: 11
            horizontalAlignment: TextInput.AlignRight
            selectByMouse: true
            inputMethodHints: Qt.ImhDigitsOnly
            validator: IntValidator { bottom: Math.round(root.from); top: Math.round(root.to) }
            onAccepted: { root.apply(Number(text)); focus = false }
            onActiveFocusChanged: if (!activeFocus) {
                if (acceptableInput) root.apply(Number(text))
                text = String(root.clamp(root.value))
            }
        }
        Text {
            id: unit
            anchors.right: parent.right; anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: root.suffix
            visible: root.suffix.length > 0
            color: theme.subtext
            font.family: theme.font
            font.pixelSize: 10
        }
    }
}
