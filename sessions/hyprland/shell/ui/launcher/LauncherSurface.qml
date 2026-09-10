// The launcher's window: a pane in the middle of the screen.
//
// ⚠️ THE MIDDLE, AND THAT IS A DECISION RATHER THAN A LAYOUT DETAIL. Everything
// else this shell opens hangs from the notch, and the notch steps aside while
// it is up. The brief names this surface as the exception: a launcher in the
// centre leaves the notch where it is, so the clock and the media pill stay
// readable while you look for a program.
//
// It is therefore not a notch page and does not touch `Ipc.page` — see the note
// on `Ipc.launcher`.
//
// ⚠️ Exactly as big as what it draws, like every other surface here. From
// the compositor's own layer-rule documentation: it "has no way of knowing about
// invisible margins, and will draw the shadow behind the entire surface". A
// full-screen window with a centred card would get a screen-sized shadow and a
// screen-sized blur, which is what the notch's coloured halo was.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../config"
import "../../ipc"
import "../common"

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    // Public interface: the blur, shadow and corner rules in buchhwin/rules.lua match
    // on this name. Renaming it here without renaming it there loses all three
    // without a word.
    WlrLayershell.namespace: "buchhwin-launcher"
    WlrLayershell.layer: WlrLayer.Top

    // ⚠️ Exclusive, not OnDemand. This surface exists to be typed into, and
    // OnDemand hands the keyboard over only once something is clicked — so the
    // first three letters would go to whatever was focused before, which is
    // usually an editor.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // No anchors at all: unanchored is centred, and centred is where the brief
    // puts it.
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"                    // literal-ok: absence of colour

    // motion-ok: the chain ends in a CONSTANT, not in content. LauncherContent
    // declares `implicitWidth: 720` and `implicitHeight: 460`, so this surface
    // is a fixed size that happens to be expressed through the card. Typing
    // filters the list inside a box that does not change — which is what the
    // check cannot see from the text, and why it is said here.
    //
    // They were `launcher.width` and `launcher.height` until the Launcher page
    // was cut on 09.09.2026. Fixed numbers make this note MORE true, not less.
    implicitWidth: Math.max(1, card.implicitWidth)    // motion-ok: ends in a constant
    implicitHeight: Math.max(1, card.implicitHeight)  // motion-ok: ends in a constant

    mask: Region { item: card }

    Item {
        id: card
        anchors.centerIn: parent

        implicitWidth: content.implicitWidth
        implicitHeight: content.implicitHeight

        GlassPane {
            anchors.fill: parent
            radius: Theme.radiusLg
            fill: Theme.panelBg
        }

        // Settles into place rather than appearing, and from its own centre —
        // it grows out of nothing where it stands, not out of the notch above,
        // because it does not come from the notch.
        scale: Ipc.launcher ? 1 : 0.96
        opacity: Ipc.launcher ? 1 : 0
        transformOrigin: Item.Center

        Behavior on scale {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durBase; easing.type: Theme.easingMove
            easing.overshoot: Theme.overshootMove }
        }
        Behavior on opacity {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }

        LauncherContent {
            id: content
            anchors.centerIn: parent
            focus: true
        }
    }

    // ⚠️ The surface is CREATED when the launcher opens and destroyed when it
    // closes — ui/Shell.qml loads it on `Ipc.launcher`, the same way the pages
    // are loaded on `Ipc.expanded`. So the cursor goes into the search field
    // here, on construction, and there is nothing to reset on the way out:
    // the next open builds a new one.
    Component.onCompleted: content.reset()
}
