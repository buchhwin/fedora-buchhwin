// The wallpaper, drawn by us rather than by swaybg.
//
// One less program, and it means the image lives in the same process as the
// palette that is derived from it. It sits on the `background` layer, which
// The compositor zooms along with the overview — that is the correct behaviour, not a
// side effect: the wallpaper belongs to the workspace you are looking at.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../services" as Services

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "buchhwin-wallpaper"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore

    // Shows through wherever the image does not reach, and while it loads.
    color: Theme.bg

    Image {
        anchors.fill: parent
        // ⚠️ B75 · ASKED PER SCREEN. There is one of these windows per output, so
        // this is the place where "a different picture on each monitor" either
        // happens or does not. `forScreen` answers `current` when nothing is
        // assigned, which is the ordinary case and costs a single array check.
        source: Services.Wallpaper.forScreen(root.modelData
                                             ? root.modelData.name : "")
        fillMode: Image.PreserveAspectCrop
        // Decoded at screen size, not at whatever the file happens to be.
        sourceSize.width: root.width
        sourceSize.height: root.height
        asynchronous: true
        cache: true
        visible: status === Image.Ready

        // A wallpaper that snaps in is jarring; one that fades in is not
        // noticed at all, which is the point.
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durSlow; easing.type: Theme.easing }
        }
    }
}
