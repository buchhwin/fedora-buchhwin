pragma Singleton

// Bluetooth: the adapter, what is paired, and what is in range.
//
// ⚠️ NAMED `Bt`, NOT `Bluetooth`, and that is not shortening for its own sake:
// the module's own singleton is called `Bluetooth`, and a service of the same
// name would shadow it inside this very file. The same reason the palette
// singleton is `Scheme` rather than `Palette` — see theme/qmldir.
//
// ⚠️ THE SEARCH DOES NOT RUN IN THE BACKGROUND. `discovering` goes on while the
// device list is on screen and off again when it closes. Discovery keeps the
// radio busy and drains a battery; it is also the only part of bluetooth a user
// ever waits for, so it belongs to the moment they are looking.
//
// ⚠️ NOT CHECKABLE ON THE VM. There is no /sys/class/bluetooth on it at all, so
// `available` is false there and the panel shows nothing — which is correct
// rather than broken. Everything here is verified on real hardware or through
// BUCHHWIN_SHELL_FAKE, and pairing in particular has never run.
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root

    readonly property bool fake: !!Quickshell.env("BUCHHWIN_SHELL_FAKE")

    readonly property var adapter: root.fake ? null : Bluetooth.defaultAdapter
    readonly property bool available: root.fake || root.adapter !== null

    readonly property bool enabled: root.fake ? root._fakeOn
                                  : root.adapter !== null && root.adapter.enabled
    readonly property bool discovering: !root.fake && root.adapter !== null
                                        && root.adapter.discovering

    // Connected first, then paired, then whatever else is in range: the same
    // order as the network list, and for the same reason.
    readonly property var devices: {
        if (root.fake)
            return root._fakeDevices
        var a = root.adapter
        var raw = a && a.devices ? a.devices.values : []
        var out = []
        for (var i = 0; i < raw.length; i++) {
            var d = raw[i]
            out.push({
                name: d.deviceName && d.deviceName.length ? d.deviceName : d.address,
                address: d.address,
                connected: d.connected,
                paired: d.paired,
                pairing: d.pairing,
                trusted: d.trusted,
                // Bluez hands over a freedesktop icon name (audio-headset,
                // input-mouse …). We show a glyph from one font instead, so it
                // is translated here rather than in four different delegates.
                icon: root.glyphFor(d.icon),
                battery: d.batteryAvailable ? d.battery : -1,
                obj: d
            })
        }
        out.sort(function (a2, b) {
            if (a2.connected !== b.connected) return a2.connected ? -1 : 1
            if (a2.paired !== b.paired) return a2.paired ? -1 : 1
            return a2.name.localeCompare(b.name)
        })
        return out
    }

    readonly property var connectedDevices:
        root.devices.filter(function (d) { return d.connected })

    // Every glyph this service can return, in one place so tests/icons.sh can
    // measure them against the real font — the same arrangement as Weather.
    // ⚠️ `headphones` is NOT in Material Icons Round, measured; `headset` is.
    readonly property var iconNames: ["bluetooth", "bluetooth_disabled",
                                      "bluetooth_connected", "bluetooth_searching",
                                      "headset", "speaker", "keyboard", "mouse",
                                      "smartphone", "watch", "devices_other"]

    // Bluez icon names come from the freedesktop icon naming spec; these are the
    // ones a laptop actually meets. Anything else gets the honest catch-all
    // rather than a guess at what the device might be.
    function glyphFor(bluezIcon) {
        var n = String(bluezIcon || "")
        if (n.indexOf("headset") >= 0 || n.indexOf("headphone") >= 0) return "headset"
        if (n.indexOf("audio") >= 0) return "speaker"
        if (n.indexOf("keyboard") >= 0) return "keyboard"
        if (n.indexOf("mouse") >= 0 || n.indexOf("pointing") >= 0) return "mouse"
        if (n.indexOf("phone") >= 0) return "smartphone"
        if (n.indexOf("watch") >= 0) return "watch"
        return "devices_other"
    }

    readonly property string icon:
        !root.enabled ? "bluetooth_disabled"
      : root.discovering ? "bluetooth_searching"
      : root.connectedDevices.length > 0 ? "bluetooth_connected"
      : "bluetooth"

    property string status: ""

    // -------------------------------------------------------------- watching
    function watch(on) {
        if (root.fake || !root.adapter || !root.adapter.enabled)
            return
        root.adapter.discovering = on
    }

    // --------------------------------------------------------------- actions
    function setEnabled(on) {
        if (root.fake) {
            root._fakeOn = on
            root.status = "fake mode — nothing was switched"
            return
        }
        if (!root.adapter) {
            root.status = "No bluetooth adapter"
            return
        }
        root.status = ""
        root.adapter.enabled = on
    }

    // Pairing first where it is needed: connecting to something that has never
    // been paired fails, and it fails without saying why.
    function connect(entry) {
        if (root.fake) {
            root.status = "fake mode — nothing was connected"
            return
        }
        root.status = ""
        if (!entry.paired) entry.obj.pair()
        else entry.obj.connect()
    }

    function disconnect(entry) {
        if (root.fake) {
            root.status = "fake mode — nothing was disconnected"
            return
        }
        root.status = ""
        entry.obj.disconnect()
    }

    function forget(entry) {
        if (root.fake) {
            root.status = "fake mode — nothing was forgotten"
            return
        }
        root.status = ""
        entry.obj.forget()
    }

    // ------------------------------------------------------------ fake data
    property bool _fakeOn: true
    readonly property var _fakeDevices: root._fakeOn ? [
        { name: "WH-1000XM4", address: "00:11:22:33:44:55", connected: true,
          paired: true, pairing: false, trusted: true, icon: "headset",
          battery: 0.72, obj: null },
        { name: "MX Master 3", address: "00:11:22:33:44:66", connected: false,
          paired: true, pairing: false, trusted: true, icon: "mouse",
          battery: -1, obj: null },
        { name: "Pixel 8", address: "00:11:22:33:44:77", connected: false,
          paired: false, pairing: false, trusted: false, icon: "smartphone",
          battery: -1, obj: null }
    ] : []
}
