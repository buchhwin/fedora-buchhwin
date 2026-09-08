// A text field, drawn rather than imported.
//
// ⚠️ `QtQuick.Controls` STAYS OUT. It would bring a second styling vocabulary
// into a shell whose whole point is having one — its own palette, its own
// radii, its own idea of a focus ring — and none of it follows Theme. That
// sentence was first written in EventPage.qml, which is where this component
// comes from.
//
// ⚠️ AND THAT IS WHY IT IS HERE RATHER THAN THERE. The shell had FIVE
// hand-drawn text fields — the calendar's event form, the clipboard search, the
// launcher search, the location picker, the wifi password box — each with its
// own focus ring and its own idea of where the placeholder sits. The settings
// window needs a sixth, and a sixth copy is how the predecessor ended up with
// six colour vocabularies. Anything that belongs to one caller — what Return
// means, what the field is for — comes in from outside.
import QtQuick
import "../../theme"

Rectangle {
    id: root

    property alias text: input.text
    // The TextInput itself, for callers that need to aim focus at it or hang
    // KeyNavigation off it. Exposed rather than re-declared: a wrapper that
    // forwards six properties one by one is five chances to forget the seventh.
    property alias input: input
    property alias echoMode: input.echoMode
    property string placeholder: ""

    // The value in it is not acceptable — a date that is not a date. Says so
    // with the focus ring rather than with a second line of text, because the
    // field is where you are already looking.
    property bool bad: false

    // Keys this field should hand on rather than swallow. The launcher's search
    // box is typed into while the arrow keys drive the list underneath it; a
    // field that ate them would make the list unreachable without the mouse.
    //
    // ⚠️ A PLAIN PROPERTY, NOT AN ALIAS. `property alias forwardTo:
    // input.Keys.forwardTo` looks right and is not: an alias cannot target an
    // attached property, and QML says so at load time with "Invalid alias
    // target location: Keys" — which makes the whole type unavailable, and with
    // it every type that uses it. The window did not fail to draw; it failed to
    // exist, three files up.
    property var forwardTo: []

    signal accepted            // Return or Enter
    signal cancelled           // Escape

    implicitHeight: Theme.space6
    radius: Theme.radiusSm
    color: Theme.surface
    // ⚠️ Width, not colour, is what says "focused". A ring that is always drawn
    // and merely changes colour makes every unfocused field look like a control
    // that is switched off.
    border.width: input.activeFocus ? Theme.space1 / 2 : 0
    border.color: root.bad ? Theme.error : Theme.accent

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: Theme.space2
        anchors.rightMargin: Theme.space2
        verticalAlignment: TextInput.AlignVCenter
        font.family: Theme.fontUi
        font.pixelSize: Theme.fontSize
        color: Theme.fg
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentFg
        selectByMouse: true
        clip: true

        Keys.forwardTo: root.forwardTo
        Keys.onEscapePressed: root.cancelled()
        Keys.onReturnPressed: root.accepted()
        Keys.onEnterPressed: root.accepted()
    }

    // Overlaid rather than set as the TextInput's own text: a placeholder that
    // lives in `text` is a value, and the first thing it does is get saved.
    BarText {
        anchors { left: parent.left; leftMargin: Theme.space2
                  verticalCenter: parent.verticalCenter }
        visible: input.text.length === 0
        text: root.placeholder
        color: Theme.fgDim
    }
}
