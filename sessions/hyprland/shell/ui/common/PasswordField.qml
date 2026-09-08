// The password field on the lock screen and the greeter — one component, used
// by both.
//
// ⚠️⚠️ IT IS SHARED BECAUSE B24 SAYS THEY ARE ONE FACE. "beides gilt für beide  // english-ok: the brief, quoted
// flächen — sperrbildschirm UND greeter". It was built twice, near enough       // english-ok: the brief, quoted
// identically that a diff of the two files showed the same pill, the same
// arrow, the same margins and the same glyph — which is the shape this project
// has paid for four times under "a list must not exist twice". The two would
// have drifted the first time one of them was adjusted.
//
// ⚠️ TRANSPARENT AND SMALLER, WHICH IS THE REQUEST: "wenn man in der zweiten    // english-ok: his request, quoted
// stage ist, also beim passwort eingeben, ist aktuell die eingabe einfach nur   // english-ok: same quote, second line
// grau, das ist nicht so schön. kannst du die auch transparent und kleiner      // english-ok: same quote, third line
// machen wie bei mac".                                                          // english-ok: same quote, fourth line
//
// The grey was not a colour choice — it was `Theme.pillBg`, which is opaque
// whenever the "our surfaces are black" switch is on. The lock screen and the
// greeter are explicitly not on that list, so they get `Theme.lockFieldBg`; the
// note beside that token spells the trap out.
//
// ⚠️⚠️ AND THE WRONG PASSWORD SHAKES INSTEAD OF SAYING SO: "und wenn man das    // english-ok: his request, quoted
// passwort falsch eingibt nicht 'wrong password' sondern ne animation so wie    // english-ok: same quote, second line
// bei mac".                                                                     // english-ok: same quote, third line
//
// ⚠️ ONLY "wrong password" IS REPLACED. PAM has things to say that no movement
// can carry — "Account expired", "Password change required" — and a field that
// shakes and never opens, with nothing on screen explaining why, is worse than
// the sentence it replaced. The caller decides which is which; this component
// only knows how to shake.
//
// ⚠️ THE SHAKE IS A TRANSLATION, NEVER A SIZE. Rule 7, and tests/motion.sh
// refuses the `motion-ok:` escape hatch for anything that animates a layout
// dimension. `x` through a Translate is a transform the compositor never hears
// about; animating width would re-measure this item, its column, and on the
// lock screen the layer surface itself, once per frame.
import QtQuick
import "../../theme"

GlassPane {
    id: root

    // What was typed. An alias so the caller reads and clears the real thing
    // rather than a copy that can disagree with it.
    property alias text: input.text

    // Whether the characters are hidden. The greeter needs this: greetd can ask
    // a question that is not a secret, and echoing a one-time code back as dots
    // is a field nobody can check before pressing enter.
    property bool echo: false

    // Refuses typing while the conversation is busy. ⚠️ `readOnly`, never
    // `enabled: false` — that also makes the item unfocusable, and this project
    // has already lost a round to `forceActiveFocus()` silently doing nothing.
    property bool locked: false

    signal accepted

    // ⚠️ SMALLER, AND BOTH AXES. Eight grid units rather than ten, and the
    // padding drops a step. His word was "kleiner" without a number, so this is
    // one visible step down rather than a redesign — and it is a token in both
    // cases, which is what keeps it following the rounding setting.
    implicitWidth: Theme.space6 * 8
    implicitHeight: input.implicitHeight + Theme.space2 * 2
    radius: Theme.radiusPill
    fill: Theme.lockFieldBg

    // ⚠️ A Translate, NOT `x` DIRECTLY. Writing `x` on an item inside a layout
    // is a value the layout writes back on its next pass, so the shake would
    // fight whoever positions this — and on the lock screen that is a column
    // that re-lays out when the status line appears.
    transform: Translate { id: nudge }

    // The movement, and every number in it is a token. Four crossings, each
    // shorter than the last, so it reads as a head-shake rather than a wobble
    // that has to be waited out.
    // motion-ok: this animates a TRANSFORM, which is what rule 7 asks for. It is
    // marked because the checker cannot tell a Translate's `x` from an item's.
    SequentialAnimation {
        id: shakeRun
        NumberAnimation { target: nudge; property: "x"; to:  Theme.space3; duration: Theme.durFast / 2; easing.type: Theme.easing }
        NumberAnimation { target: nudge; property: "x"; to: -Theme.space3; duration: Theme.durFast;     easing.type: Theme.easing }
        NumberAnimation { target: nudge; property: "x"; to:  Theme.space2; duration: Theme.durFast;     easing.type: Theme.easing }
        NumberAnimation { target: nudge; property: "x"; to: -Theme.space1; duration: Theme.durFast;     easing.type: Theme.easing }
        NumberAnimation { target: nudge; property: "x"; to:  0;            duration: Theme.durFast / 2; easing.type: Theme.easing }
    }

    // ⚠️ IT CLEARS THE FIELD ITSELF. A shake over the password you just typed
    // invites you to press enter again on the same wrong thing; macOS empties it
    // for the same reason. And restarting a running animation is deliberate:
    // two refusals in a row must look like two, not like one that never ended.
    function shake() {
        input.text = ""
        // ⚠️ Put the field back at rest first. A restart from mid-swing leaves
        // the resting position wherever the last frame was — one of the ways an
        // animation "drifts" without anything being wrong with the numbers.
        shakeRun.stop()
        nudge.x = 0
        shakeRun.start()
        input.forceActiveFocus()
    }

    function clear() { input.text = "" }
    function focusField() { input.forceActiveFocus() }

    // ⚠️ THE ARROW IS A REAL BUTTON, not a decoration that leaves Enter as the
    // only way in. Rule 5: a control without an answer is the same debt as a key
    // without a reader. It sits inside the pill on the right, where his
    // reference puts it.
    Rectangle {
        id: go
        anchors.right: parent.right
        anchors.rightMargin: Theme.space1
        anchors.verticalCenter: parent.verticalCenter
        width: parent.height - Theme.space1 * 2
        height: width
        radius: width / 2   // literal-ok: a circle is half its width
        color: goHover.hovered ? Theme.accent : Theme.surfaceHigh
        opacity: input.text.length > 0 ? 1 : Theme.dimmed

        Behavior on color {
            enabled: Theme.animate
            ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }
        Behavior on opacity {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }

        HoverHandler { id: goHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.accepted() }

        Icon {
            anchors.centerIn: parent
            // ⚠️ Measured, not guessed: Fedora ships "Material Icons Round",
            // where the name for this shape is `arrow_forward_ios`.
            // tests/icons.sh is what catches a name that is not in the font — a
            // missing glyph draws as a box several hundred pixels wide.
            text: "arrow_forward_ios"
            size: Theme.fontSizeSm
            color: goHover.hovered ? Theme.accentFg : Theme.fgMuted
        }
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: Theme.space3
        // Room for the arrow, so long input does not run underneath it.
        anchors.rightMargin: go.width + Theme.space3
        anchors.topMargin: Theme.space2
        anchors.bottomMargin: Theme.space2
        horizontalAlignment: TextInput.AlignHCenter
        verticalAlignment: TextInput.AlignVCenter
        echoMode: root.echo ? TextInput.Normal : TextInput.Password
        readOnly: root.locked
        color: Theme.fg
        font.family: Theme.fontUi
        font.pixelSize: Theme.fontSize
        onAccepted: root.accepted()
    }
}
