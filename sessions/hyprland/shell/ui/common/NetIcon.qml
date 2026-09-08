// The network symbol — wired, wifi at four strengths, or off — in ONE place.
//
// ⚠️⚠️ IT EXISTS BECAUSE THE SAME QUESTION HAD TWO ANSWERS ON ONE DESKTOP. B37
// settled it for the island: Microsoft's open Fluent set for WLAN, Ethernet and
// battery, in his words "nimm bitte die windows symbole her, das ist echt      // english-ok: the request, quoted
// kacke". The quick panel's tile never got the message and kept drawing
// Material Icons Round's `wifi` — which is what he reported next: "das wifi    // english-ok: the report, quoted
// icon ist voll komisch das soll da typische icon sein das jeder kennt".       // english-ok: the report, quoted
//
// Two symbol sets for one state is exactly the drift this project spends most
// of its checks preventing, so the fix is not a third glyph in the tile: it is
// this component, and both callers draw it.
//
// ⚠️⚠️ THE WIFI GRADES ARE NUMBERED THE OTHER WAY ROUND, and it is measured
// rather than inferred from the names: `wifi_1` is the FULL symbol and `wifi_4`
// is a single dot. Reading "level 1 is one bar" would show a strong signal as
// almost nothing on every machine, and look like a driver fault rather than an
// off-by-one.
//
// ⚠️ IT READS THE SERVICE ITSELF rather than taking a name from its caller. The
// alternative was a string like "@wifi3" travelling through a generic tile,
// which is a second encoding of a state that already exists — the same reason
// `outputs` holds `@primary` instead of a name plus a flag.
import QtQuick
import "../../theme"
import "../../services" as Services

Item {
    id: root

    property int size: Theme.fontSizeLg
    property color colour: Theme.fg

    implicitWidth: size
    implicitHeight: size

    // Anything that is neither wired nor wifi — a mobile connection, a bridge —
    // keeps the Material glyph the service names. Fluent covers the three he
    // asked for and nothing was invented for the rest.
    readonly property bool known:
        Services.Net.kind === "wired" || Services.Net.kind === "wifi"

    FluentIcon {
        anchors.centerIn: parent
        visible: Services.Net.kind === "wired"
        text: "\uE99A"          // literal-ok: plug_connected, the glyph point itself
        size: root.size
        color: root.colour
    }

    FluentIcon {
        anchors.centerIn: parent
        visible: Services.Net.kind === "wifi"
        // Four grades and an off state. `level` is 0..100 from services/Net.qml;
        // the bands are even quarters, and 0 is the crossed-out symbol rather
        // than an empty one — "no signal" and "not connected" look the same
        // otherwise.
        text: {
            if (!Services.Net.wifiEnabled) return "\uEE5A"   // literal-ok: wifi_off
            var l = Services.Net.level
            if (l <= 0)  return "\uEE5A"   // literal-ok: wifi_off
            if (l >= 75) return "\uF8AD"   // literal-ok: wifi_1, the FULL one
            if (l >= 50) return "\uF8AF"   // literal-ok: wifi_2
            if (l >= 25) return "\uF8B1"   // literal-ok: wifi_3
            return "\uF8B3"                // literal-ok: wifi_4, the weakest
        }
        size: root.size
        color: root.colour
    }

    Icon {
        anchors.centerIn: parent
        visible: !root.known
        text: Services.Net.icon
        size: root.size
        color: root.colour
    }
}
