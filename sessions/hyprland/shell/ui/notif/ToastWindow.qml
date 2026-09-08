// One layer surface holding exactly one toast.
//
// ⚠️ THE SURFACE IS EXACTLY AS BIG AS WHAT IT DRAWS. niri draws shadow and blur
// behind the whole layer surface, invisible margins included — see the note in
// ToastSurface.qml for the band of shadow that appeared between two cards when
// they shared one window.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../config"

PanelWindow {
    id: root

    required property var notification
    required property int index

    WlrLayershell.namespace: "buchhwin-toast"
    // `top`, like the notch: above ordinary windows, below a fullscreen one.
    // A message is not important enough to sit over a video, and the ones that
    // are stay on screen until dismissed anyway.
    WlrLayershell.layer: WlrLayer.Top

    // ⚠️ THE CORNER IS A SETTING — see `notifications.corner`. Two anchors, not
    // four positions: a layer surface anchored to two edges sits in that corner,
    // and the stacking direction follows from which vertical edge it is.
    //
    // ⚠️ GUARDED against a null block while shell.json is being read, the same
    // way every other surface here is. `Config.<block>` is NULL during the read
    // — not "still the defaults" — and a binding that throws keeps its last
    // value for ever.
    readonly property string corner:
        Config.notifications ? String(Config.notifications.corner) : "topRight"
    readonly property bool atTop: root.corner.indexOf("top") === 0
    readonly property bool atRight: root.corner.indexOf("Right") > 0

    anchors {
        top: root.atTop
        bottom: !root.atTop
        right: root.atRight
        left: !root.atRight
    }
    margins {
        right: Theme.space4
        left: Theme.space4
        // Stacked away from the edge it is anchored to. Every card is the same
        // height, which is what lets a window know where it belongs without
        // waiting for its neighbours to be laid out.
        top: Theme.space4 + root.index * (card.implicitHeight + Theme.space2)
        bottom: Theme.space4 + root.index * (card.implicitHeight + Theme.space2)
    }

    // Sliding the WINDOW rather than the card inside it: the surface is the
    // size of the card, so there is no room to move within it.
    //
    // motion-ok: this re-configures the layer surface once per frame, the same
    // cost class that made the notch and the panels stutter — and it is kept,
    // deliberately, because the sums are different. Those two paid it on every
    // open and hover, several times a minute; this pays it for 150 ms when a
    // notification is dismissed and the cards close ranks. The alternative is
    // cards that jump, and the usual escape — oversize the surface and move the
    // card inside it — is closed here: toasts are blurred (`surface(
    // "buchhwin-toast", paneRadius, blurOn)`), so spare surface comes back as
    // the halo described at the top of ToastSurface.qml.
    Behavior on margins.top {
        enabled: Theme.animate
        NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
    }
    // motion-ok: the same margin, on the other edge, for the same reason and at
    // the same price — see the paragraph above `Behavior on margins.top`. Only
    // one of the two is ever the anchored edge, so this animates exactly when
    // that one does not.
    Behavior on margins.bottom {
        enabled: Theme.animate
        NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
    }

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"                    // literal-ok: absence of colour

    // motion-ok: a toast is measured ONCE, when its notification arrives, and
    // then does not change for as long as it is up. The fault this check exists
    // for is a surface that re-sizes while nobody asked — the notch followed a
    // ticking clock. This one follows an event that happens once per toast, and
    // the surface has to fit the text or the text is clipped.
    implicitWidth: Math.max(1, card.implicitWidth)    // motion-ok: measured once per toast
    implicitHeight: Math.max(1, card.implicitHeight)  // motion-ok: measured once per toast

    mask: Region { item: card }

    Toast {
        id: card
        anchors.fill: parent
        notification: root.notification
    }
}
