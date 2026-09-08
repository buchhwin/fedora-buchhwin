pragma ComponentBehavior: Bound

// The two-stage face the lock screen and the greeter share: a large clock alone,
// and — once you touch a key — the clock lifted out of the way with who you are
// and what you have to type underneath it.
//
//     resting                    revealed
//     ┌──────────────┐           ┌──────────────┐
//     │              │           │  09:41  Mon  │   ← lifted, smaller
//     │    09:41     │           │              │
//     │  Monday, 11  │           │      ◍       │
//     │              │    →      │    Jakob     │
//     │              │           │  ╭────────╮  │
//     │ Press any key│           │  │••••••  │  │
//     └──────────────┘           │  ╰────────╯  │
//                                └──────────────┘
//
// ⚠️⚠️ IT IS ONE COMPONENT FOR BOTH, and that is the point rather than a
// convenience. His instruction was "mach beides gleich … also beides neues       // english-ok: the request, quoted
// design", and his older brief says why: the screen before logging in and the    // english-ok: the request, quoted
// one after locking must not look like two products. Two faces built separately
// is precisely the drift this repo has paid for with two sidebars, two calendars
// and two theme grids — and here it would be visible to him every single day.
//
// What differs between the two callers does NOT live here: the lock screen
// authenticates the user it already knows, the greeter also chooses WHO and
// WHICH SESSION. Those arrive as content.
//
// ⚠️ NOTHING IN HERE ANIMATES A LAYOUT SIZE. The clock moves on `y` and shrinks
// on `scale`; both are transforms the compositor never hears about. Animating
// the font size instead would change an implicit height every frame and relay
// out the screen — which is what rule 7 and tests/motion.sh forbid outright.
//
// ⚠️ IT SCALES DOWN, NEVER UP. The resting clock is the one you look at all day,
// so it is the one drawn at its true size; the lifted one is a fifth of a second
// of movement and a smaller reading. Rendering small and scaling up would put
// the softness on the state that matters.
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../config"
import "../../common"

Item {
    id: root

    // False: the clock alone. True: the clock lifted, identity underneath.
    property bool revealed: false

    // The moment to draw. Passed in so there is one SystemClock per surface.
    property var now: null

    // The line under the resting clock — "Press any key", or whatever the
    // caller has to say before anything is asked.
    property string hint: ""

    // Everything that appears once revealed: avatar, name, the field, whatever
    // else the caller needs. It is laid out as a centred column here so both
    // callers get the same rhythm without repeating the spacing.
    //
    // ⚠️ THE NAME IS PART OF IT AND NOT OPTIONAL, because it is half of what
    // this stage is FOR. His reference shows who you are about to log in as, and
    // the version he rejected had an avatar, a bar and nothing that said whose
    // machine this is.
    default property alias content: identity.data

    // How far the clock lifts. Derived rather than typed: the identity group has
    // to fit under it, and that height belongs to the caller's content.
    readonly property real lift: Math.round(identity.implicitHeight / 2 + Theme.space6)

    // ------------------------------------------------------------------ clock
    ColumnLayout {
        id: clockGroup
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 0   // literal-ok: absence of a gap — the time and its date are
                     // one label on two lines

        // Centred at rest, lifted when asked. `y` on an anchored item, so the
        // parent never re-measures.
        y: root.revealed
           ? (root.height - clockGroup.implicitHeight) / 2 - root.lift
           : (root.height - clockGroup.implicitHeight) / 2

        // motion-ok: `scale` is a transform, and the note at the head of this
        // file explains why it is this rather than the font size.
        scale: root.revealed ? 0.55 : 1
        transformOrigin: Item.Center

        Behavior on y {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
        }
        Behavior on scale {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
        }

        BarText {
            Layout.alignment: Qt.AlignHCenter
            text: root.now ? Clock.time(root.now) : ""
            font.pixelSize: Theme.fontSizeDisplay
            font.weight: Theme.weightNormal
        }

        BarText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -Theme.space4
            visible: Config.lock ? Config.lock.showDate : true
            text: root.now ? Clock.date(root.now) : ""
            color: Theme.fgMuted
            font.pixelSize: Theme.fontSizeLg
        }
    }

    // ------------------------------------------------------------------- hint
    // ⚠️ IT FADES, IT DOES NOT DISAPPEAR FROM A LAYOUT. `visible: false` on a
    // layout child takes its gap with it, so everything below would jump at the
    // moment of the key press — the one moment the eye is on the screen.
    BarText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: clockGroup.y + clockGroup.implicitHeight + Theme.space6
        text: root.hint
        color: Theme.fgDim
        opacity: root.revealed ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }
    }

    // --------------------------------------------------------------- identity
    // ⚠️⚠️ NO SHEET AT ALL, AND THAT IS HIS DECISION AFTER SEEING ONE. The first
    // version put this on a lighter card; what got built was a flat grey plate,
    // and a plate over a blurred wallpaper kills the blur it is standing on. He
    // saw it and said so — the resting screen was "super", this half was "mega  // english-ok: the reaction, quoted
    // hässlich". Asked how far to go, he chose macOS: GAR KEINE FLÄCHE. Avatar, // english-ok: the choice, quoted
    // name and a pill float directly over the wallpaper.
    //
    // ⚠️ SO THE GROUP IS THE THING THAT MOVES NOW, not a card containing it.
    // There is nothing left to size from `identity.implicitWidth`, which also
    // takes away a rule-7 trap the card had: its width came from its contents,
    // so it changed shape when the status line appeared.
    //
    // ⚠️ AND LEGIBILITY IS NOW THE CALLER'S PROBLEM, which is the honest place
    // for it: what is behind this is a photograph, and no colour token can
    // promise contrast against one. LockScreen.qml already darkens and blurs
    // what it draws over — the resting clock has always relied on exactly that
    // and he accepted it — so the same ground carries this.
    ColumnLayout {
        id: identity
        anchors.horizontalCenter: parent.horizontalCenter
        y: clockGroup.y + clockGroup.implicitHeight * clockGroup.scale + Theme.space6
        spacing: Theme.space4

        opacity: root.revealed ? 1 : 0
        visible: opacity > 0

        // It arrives with the movement rather than after it — the identity and
        // the clock are one gesture, not two.
        Behavior on opacity {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
        }
        Behavior on y {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
        }
    }
}
