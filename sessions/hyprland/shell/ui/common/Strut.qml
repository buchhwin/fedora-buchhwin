// An invisible window whose only job is to reserve space.
//
// Why this is a separate window from the thing you can see: the notch (M4) is
// a 135 px tall surface that must only reserve the height of the bar under it.
// A layer surface can either reserve its own size or reserve nothing, so the
// two jobs are split across two windows — one visible and excluded from
// layout, one invisible and doing the reserving.
//
// ⚠️ `ExclusionMode.Auto` reserves the FULL implicitHeight. On the notch that
// would push every window 135 px down. And `exclusiveZone: -1` does not mean
// "reserve nothing" — it additionally means "do not move me".
//
// In notch-only mode this window simply does not exist, which is why it is
// created through a LazyLoader rather than hidden.

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var modelData
    property int reserve: 0
    property string edge: "top"     // top | bottom | left | right

    screen: modelData
    // Named so the generated layer-rule can find it. The buchhwin-* namespaces
    // are a public interface: config.kdl matches on them, so renaming one here
    // silently drops whatever that rule did.
    WlrLayershell.namespace: "buchhwin-strut"
    WlrLayershell.layer: WlrLayer.Top

    color: "transparent"            // literal-ok: absence of colour, not a colour

    anchors {
        top: root.edge === "top"
        bottom: root.edge === "bottom"
        left: root.edge !== "right"
        right: root.edge !== "left"
    }

    implicitHeight: root.reserve
    implicitWidth: root.reserve

    exclusionMode: ExclusionMode.Normal
    exclusiveZone: root.reserve

    // Nothing is drawn. An empty input region follows from having no items,
    // so clicks fall through to whatever is underneath.
    mask: Region {}
}
