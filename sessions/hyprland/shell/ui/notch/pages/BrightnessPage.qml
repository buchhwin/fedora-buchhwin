// The brightness page. The volume page's twin, and deliberately built from the
// same component so the two cannot drift apart.
//
// It appears when the brightness keys are pressed. Those keys run brightnessctl
// FIRST and then tell the shell — see the bindings in config/Config.qml. That
// order matters: the screen still brightens when the shell is dead, which is
// the one situation where being unable to see the screen is worst.
import QtQuick
import "../../../theme"
import "../../../ipc"
import "../../../services" as Services
import "../../common"

LevelRow {
    id: root

    property bool compact: true

    implicitWidth: Theme.space6 * 8

    icon: Services.Brightness.fraction > 0.5 ? "brightness_7" : "brightness_5"
    value: Services.Brightness.fraction
    live: Services.Brightness.available

    onMoved: function (f) { Services.Brightness.set(f) }

    onNudged: function (dir) {
        if (!Services.Brightness.available)
            return
        Services.Brightness.set(Math.max(0.01, Math.min(1, Services.Brightness.fraction + dir / root.steps)))
        Ipc.show("brightness")
    }
}
