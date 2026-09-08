import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property var custom: ({})
    readonly property color bg: custom.background || "#181818"
    readonly property color surface: custom.bar || "#242424"
    readonly property color surface2: Qt.lighter(surface, 1.18)
    readonly property color surface3: Qt.lighter(surface, 1.38)
    readonly property color border: Qt.lighter(surface, 1.65)
    readonly property color text: custom.text || "#eeeeee"
    readonly property color subtext: "#aaaaaa"
    readonly property color blue: custom.accent || "#d0d0d0"
    readonly property color mauve: custom.accent || "#c4c4c4"
    readonly property color green: custom.accent || "#d8d8d8"
    readonly property color red: "#f38ba8"
    readonly property color yellow: "#bcbcbc"
    readonly property string font: custom.font || "MesloLGS Nerd Font Mono"
    readonly property string barPosition: custom.barPosition || "top"
    readonly property int barSize: Math.max(34, Math.min(64, Number(custom.barSize || 38)))
    property string appearancePath: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/buchhwin-dwl/appearance.json"
    property FileView appearanceFile: FileView {
        path: root.appearancePath
        watchChanges: true
        printErrors: false
        onLoaded: root.loadAppearance()
        onFileChanged: reload()
        onTextChanged: root.loadAppearance()
    }
    function loadAppearance() {
        try { custom = JSON.parse(appearanceFile.text()) }
        catch (error) { custom = ({}) }
    }

    // Motion.
    //
    // One vocabulary for the whole shell: every panel uses the same durations
    // and curves, so nothing feels like it was borrowed from another program.
    // Opening decelerates into place, closing accelerates away.
    readonly property int durationFast: 110    // hover and colour changes
    readonly property int durationMedium: 170  // panels opening and closing
    readonly property int durationSlow: 240    // notification popups
    readonly property int durationRecord: 12000 // one calm album-cover rotation
    readonly property int easingEnter: Easing.OutCubic
    readonly property int easingExit: Easing.InCubic

    // How far a panel travels while it fades, in pixels. Small on purpose:
    // the grayscale look stays calm, the movement only signals direction.
    readonly property real lift: 10
    readonly property real slide: 26
}
