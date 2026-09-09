pragma Singleton

// The network: are we online, over what, how well, and what else is in range.
//
// ⚠️ WHAT THIS MODULE CANNOT DO, IN ITS OWN WORDS. From quickshell's
// src/network/wifi.hpp:113, read out of the source rpm rather than assumed:
// "Quickshell does not yet provide a NetworkManager authentication agent,
// meaning another agent will need to be active to enter passwords for unsaved
// networks." So `connect()` works for a network NetworkManager already holds a
// password for, and fails with NoSecrets for one it does not. Joining a new
// secured network therefore goes through `nmcli`, which is its own agent for
// the length of the call — see connectWithPassword() below. That is the honest
// division rather than a button that silently does nothing every time.
//
// ⚠️ THE SCANNER DOES NOT RUN IN THE BACKGROUND. `scannerEnabled` goes on while
// a list of networks is on screen and off again the moment it closes. A radio
// scan costs power on a machine that runs on a battery, and nothing reads the
// list when it is not being looked at.
//
// ⚠️ THE MODULE IS WIFI-ONLY, AND FINDING THAT OUT IS WHY THIS FILE HAS AN
// nmcli IN IT. `Networking.devices` reported zero devices on a machine nmcli
// showed as `ens18:ethernet:connected`. The reason is in the backend, not in
// the configuration: src/network/nm/backend.cpp:113-117 is
//
//     switch (type) {
//     case NMDeviceType::Wifi: dev = new NMWirelessDevice(path); break;
//     default: break;
//     }
//
// — so anything that is not wifi is dropped before a device object exists, and
// `DeviceType` accordingly has only None and Wifi (src/network/device.hpp:36).
// Believing the module would have meant a desktop that says "offline" while it
// is downloading over a cable, which is the exact class of silent wrongness
// this project keeps finding. So: wifi comes from the module, and whether the
// machine is on a network at all comes from NetworkManager itself.
//
// ⚠️ AND IT IS AN EVENT STREAM, NOT A POLL. `nmcli monitor` is one small
// long-lived process that says nothing until something changes — the same shape
// as `hyprctl event-stream` in Hyprland.qml, and for the same reason: a timer
// asking every few seconds whether the network changed is a timer that wakes a
// laptop up all day to be told no.
//
// The test VM has no radio at all — one ethernet device, no /sys/class/bluetooth,
// no rfkill — so everything below the ethernet case is checked on real hardware
// or through BUCHHWIN_SHELL_FAKE, and never by looking at a VM and believing it.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Singleton {
    id: root

    // Invented data for layout work, because the VM has no wifi and no
    // bluetooth and never will. Actions in this mode change nothing and say so
    // — a fake that claims to have connected is worse than no fake.
    readonly property bool fake: !!Quickshell.env("BUCHHWIN_SHELL_FAKE")

    readonly property bool available:
        root.fake || Networking.backend !== NetworkBackendType.None

    // ------------------------------------------------------------- the devices
    // ⚠️ Guarded on `fake` first so the module is never even constructed in
    // fake mode: the whole point of that mode is that it works on a machine
    // where NetworkManager has nothing to say.
    readonly property var devices:
        root.fake || !Networking.devices ? [] : Networking.devices.values

    readonly property var wifiDevice: {
        var d = root.devices
        for (var i = 0; i < d.length; i++)
            if (d[i].type === DeviceType.Wifi)
                return d[i]
        return null
    }

    // Filled in from nmcli, because the module cannot see it — see the header.
    // "wired" is anything NetworkManager has connected that is not wifi and not
    // loopback: ethernet normally, a phone tethered over USB sometimes.
    property bool wiredConnected: false
    property string wiredName: ""

    readonly property bool wifiPresent: root.fake || root.wifiDevice !== null
    readonly property bool wifiEnabled: root.fake ? root._fakeWifiOn : Networking.wifiEnabled
    // A hardware switch or a flight-mode key beats every setting there is; if it
    // is off, the toggle in the panel has to be dead rather than lying.
    readonly property bool wifiBlocked: !root.fake && !Networking.wifiHardwareEnabled

    // ------------------------------------------------------------ the summary
    readonly property var connectedNetwork: {
        var n = root.networks
        for (var i = 0; i < n.length; i++)
            if (n[i].connected)
                return n[i]
        return null
    }

    readonly property bool online:
        root.wiredConnected || root.connectedNetwork !== null

    // "wifi", "wired" or "none". See the note above on what `wired` can be.
    // Wired wins when both are up: it is the one carrying the traffic, and it
    // is the one whose loss you want to see.
    readonly property string kind:
        root.wiredConnected ? "wired"
      : root.connectedNetwork !== null ? "wifi"
      : "none"

    readonly property string ssid:
        root.connectedNetwork !== null ? root.connectedNetwork.name : ""

    // ⚠️ FOUR STEPS, NOT A PERCENTAGE, and `signalStrength` is 0…1 — quickshell's
    // own example renders it as `Math.round(signalStrength * 100)`
    // (src/network/test/manual/network.qml:121). Stepping it is not decoration:
    // the raw value moves constantly, and an indicator bound to it redraws
    // several times a second while sitting still, which is exactly the idle
    // repainting this desktop is not allowed to do.
    function levelOf(strength) {
        return Math.max(0, Math.min(4, Math.ceil(strength * 4)))
    }
    readonly property int level:
        root.connectedNetwork !== null ? root.levelOf(root.connectedNetwork.strength) : 0

    // Every icon name this service can produce, in one place so tests/icons.sh
    // can measure them against the real font. ⚠️ Material Icons Round has NO
    // graded wifi glyphs — signal_wifi_1_bar through _3_bar do not exist in it,
    // measured — which is why strength is drawn as bars by ui/common/SignalBars
    // instead of picked from a family of icons that only looks like it is there.
    //
    // ⚠️ `settings_ethernet` IS GONE FROM THIS LIST and must not come back. It
    // is in the font and it measures like a real glyph — so tests/icons.sh was
    // green over it from the first day — and it draws `‹···›`, which says
    // nothing to anybody. He had to be the one to report it: "wenn man auf die  // english-ok: his report, quoted
    // notch hovert ist da recht auch ein komisches symol". Wired is drawn now,  // english-ok: his report, quoted
    // by ui/common/WiredIcon.qml, exactly as signal strength already was.
    readonly property var iconNames: ["wifi", "wifi_off", "signal_wifi_off",
                                      "wifi_lock", "router"]

    // ⚠️ `@wired` IS NOT A LIGATURE AND NO FONT HAS IT, which is the point: the
    // one caller that draws icons by name (ui/quick/Tile.qml) switches on it,
    // the same way ui/Shell.qml switches on `@primary`. One state, rather than a
    // name plus a second flag saying how to read it.
    readonly property string icon:
        root.kind === "wired" ? "@wired"
      : !root.wifiEnabled ? "wifi_off"
      : root.kind === "wifi" ? "wifi"
      : "signal_wifi_off"

    // ------------------------------------------------------------- the list
    //
    // Connected first, then the ones already known, then by strength. That order
    // is the answer to three different questions in the order people ask them:
    // what am I on, what can I get back onto, what else is here.
    readonly property var networks: {
        if (root.fake)
            return root._fakeNetworks
        var dev = root.wifiDevice
        var raw = dev && dev.networks ? dev.networks.values : []
        var out = []
        for (var i = 0; i < raw.length; i++) {
            var n = raw[i]
            out.push({
                name: n.name,
                strength: n.signalStrength,
                level: root.levelOf(n.signalStrength),
                known: n.known,
                secured: n.security !== WifiSecurityType.Open,
                security: WifiSecurityType.toString(n.security),
                connected: n.connected,
                busy: n.stateChanging,
                obj: n
            })
        }
        out.sort(function (a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1
            if (a.known !== b.known) return a.known ? -1 : 1
            return b.strength - a.strength
        })
        return out
    }

    readonly property bool scanning:
        !root.fake && root.wifiDevice !== null && root.wifiDevice.scannerEnabled

    // What went wrong, in a sentence, for the panel to show. Cleared by the next
    // successful action — a stale error reads as a current one.
    property string status: ""

    // -------------------------------------------------------------- watching
    //
    // Called with true while a list of networks is visible and false when it
    // goes away. Nothing else switches the scanner on.
    function watch(on) {
        if (root.fake || !root.wifiDevice)
            return
        root.wifiDevice.scannerEnabled = on
    }

    // --------------------------------------------------------------- actions
    function setWifi(on) {
        if (root.fake) {
            root._fakeWifiOn = on
            root.status = "fake mode — nothing was switched"
            return
        }
        if (root.wifiBlocked) {
            root.status = "Wifi is blocked in hardware"
            return
        }
        root.status = ""
        // ⚠️ THE PROPERTY, NOT `requestSetWifiEnabled`. That name is a SIGNAL
        // (src/network/network.hpp:86) which the backend connects to its own
        // slot; calling it would emit into the void on a machine with no
        // backend and look like a working switch. The writable property is the
        // public door: network.cpp:53 sets the value and emits the signal.
        Networking.wifiEnabled = on
        verify.want = on
        verify.restart()
    }

    function connect(entry) {
        if (root.fake) {
            root.status = "fake mode — nothing was connected"
            return
        }
        root.status = ""
        entry.obj.connect()
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

    // Does this network need a password typed, rather than one NetworkManager
    // already has? `known` answers it before the attempt; NoSecrets answers it
    // after one, and is the exact reason code the module hands back when the
    // missing authentication agent bites.
    function needsPassword(entry) {
        return entry.secured && !entry.known
    }

    // ⚠️ THE ONE PLACE THIS SHELL SHELLS OUT FOR THE NETWORK, and the reason is
    // in the header: there is no authentication agent in quickshell 0.2.1, so a
    // network with no stored password cannot be joined through the module at
    // all. `nmcli` acts as its own agent for the length of one call.
    //
    // The password is passed as an argument to a process we start ourselves and
    // is never written to shell.json, never logged, and never kept after the
    // call. It is visible in that process's own command line for as long as it
    // runs, which is a second or two and is how every other tool on the machine
    // does it — worth saying rather than leaving for somebody to discover.
    function connectWithPassword(entry, password) {
        if (root.fake) {
            root.status = "fake mode — nothing was connected"
            return
        }
        root.status = "connecting …"
        join.command = ["nmcli", "device", "wifi", "connect", entry.name,
                        "password", password]
        join.running = true
    }

    // --------------------------------------- NetworkManager's own view of "online"
    //
    // ⚠️ NO `stdbuf`, and that was measured rather than assumed both ways. The
    // first attempt to check whether `nmcli monitor` line-buffers through a pipe
    // proved nothing, because the events it was supposed to report never
    // happened — `nmcli connection add` had failed with "Insufficient
    // privileges" and the check read the silence as buffering. With a real
    // event (`ip link add … type dummy` as root) the line arrives immediately,
    // with or without stdbuf.
    Process {
        id: monitor
        command: ["nmcli", "monitor"]
        running: !root.fake
        stdout: SplitParser {
            splitMarker: "\n"
            // Several lines arrive for one change — the device, the connection,
            // the connectivity. One read after they stop beats three reads
            // during, so the answer is a short settle rather than a line count.
            onRead: function (line) { settle.restart() }
        }
        onExited: function () { relight.start() }
    }
    Timer {
        id: relight
        interval: 2000
        onTriggered: if (!root.fake) monitor.running = true
    }
    Timer { id: settle; interval: 250; onTriggered: deviceRead.running = true }

    // ⚠️ NOT `id: devices`. There is already a property called `devices` on this
    // singleton, and an id that collides with one resolves to the property —
    // so `devices.running = true` silently assigned to an array and the wired
    // state stayed false on a machine that was plainly on a cable.
    Process {
        id: deviceRead
        command: ["nmcli", "-t", "-f", "TYPE,DEVICE,STATE", "device"]
        stdout: StdioCollector {
            onStreamFinished: {
                // ⚠️ AN ALLOWLIST, NOT "ANYTHING THAT IS NOT LOOPBACK". A
                // wireguard tunnel, a bridge or a tun device can all sit at
                // "connected" while the machine has no way out; only a real
                // uplink counts as being on a network. Wifi is excluded here
                // because the module above answers for it in more detail.
                var uplinks = ["ethernet", "gsm", "cdma", "wwan", "adsl", "infiniband"]
                var lines = String(text).split("\n")
                var found = false
                var name = ""
                for (var i = 0; i < lines.length; i++) {
                    var f = lines[i].split(":")
                    if (f.length < 3) continue
                    if (uplinks.indexOf(f[0]) < 0) continue
                    // "connected (externally)" counts; "disconnected" and
                    // "connecting" must not, which is why this is a prefix test
                    // on the whole field rather than a search for the word.
                    if (f[2].indexOf("connected") !== 0) continue
                    found = true
                    name = f[1]
                    break
                }
                root.wiredConnected = found
                root.wiredName = name
            }
        }
    }

    Component.onCompleted: if (!root.fake) deviceRead.running = true

    // ⚠️ DID THE SWITCH ACTUALLY DO ANYTHING? Changing the wifi radio goes
    // through NetworkManager's D-Bus interface and is subject to polkit, so the
    // call can be refused and nothing happens at all. Measured over ssh, where a
    // session is never active: "Not authorized to perform this operation".
    //
    // ⚠️ THE OLD NOTE HERE WAS OUT OF DATE and said the plan had an agent "built
    // on Quickshell.Services.Polkit". There is no such module — a polkit agent
    // has to REGISTER with org.freedesktop.PolicyKit1.Authority over D-Bus, and
    // quickshell cannot. `mate-polkit` is installed and started with the session
    // instead; see packages/dnf-desktop.txt for why a foreign program is there.
    //
    // The check stays regardless, and that is deliberate: an agent can be
    // missing, dead, or the policy can simply say no. Rather than ship a switch
    // that might quietly do nothing, the switch looks.
    Timer {
        id: verify
        interval: 1000
        property bool want: false
        onTriggered: {
            if (Networking.wifiEnabled !== verify.want)
                // Says what happened, not what we guess the cause is: with
                // an agent installed, a refusal now means the policy said no or
                // the agent is not running — and "no agent" would be a lie.
                root.status = "The radio would not change — the request was refused"
        }
    }

    Process {
        id: join
        stdout: StdioCollector {}
        stderr: StdioCollector { id: joinErr }
        onExited: function (code) {
            if (code === 0) {
                root.status = ""
            } else {
                var msg = String(joinErr.text).trim()
                // nmcli says "Error: ..." on its own line; the rest is noise
                // for somebody standing in front of a panel.
                var m = msg.match(/Error:\s*(.+)/)
                root.status = m ? m[1] : "Could not connect"
            }
        }
    }

    // ------------------------------------------------------------ fake data
    property bool _fakeWifiOn: true
    readonly property var _fakeNetworks: root._fakeWifiOn ? [
        { name: "FRITZ!Box 7590", strength: 0.92, level: 4, known: true,
          secured: true, security: "WPA2", connected: true, busy: false, obj: null },
        { name: "Neighbour 2.4G", strength: 0.55, level: 3, known: false,
          secured: true, security: "WPA2", connected: false, busy: false, obj: null },
        { name: "Guest", strength: 0.21, level: 1, known: false,
          secured: false, security: "Open", connected: false, busy: false, obj: null }
    ] : []
}
