pragma Singleton

// The VPN switch, next to Wi-Fi and Bluetooth.
//
// ⚠️ NOT `wg-quick`, AND THE HANDOVER THAT SAID SO WAS OUT OF DATE. It named
// wireguard-tools as the way in, which would have meant a root helper of our
// own for something the system already does: NetworkManager 1.56 knows
// `wireguard` as a connection type, so a tunnel is a connection like any other
// and `nmcli connection up` is the whole of it. Measured on the machine —
// `nmcli --version` 1.56.0, and the polkit action
// org.freedesktop.NetworkManager.network-control exists in NM's own policy file.
// One privilege that already exists beats one we invent.
//
// ⚠️ AND IT LISTS RATHER THAN GUESSES. There is no "the VPN": there are however
// many connections of type `wireguard` and `vpn` this machine has, which on a
// fresh one is none. A switch for a tunnel that does not exist is a switch that
// lies, so with no connections the tile says there are none instead of sitting
// there switched off.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool fake: !!Quickshell.env("BUCHHWIN_SHELL_FAKE")

    // Every VPN-ish connection this machine has, as
    // { name, uuid, type, active }.
    property var tunnels: []
    property string status: ""

    readonly property bool available: root.tunnels.length > 0
    readonly property var activeTunnel: {
        for (var i = 0; i < root.tunnels.length; i++)
            if (root.tunnels[i].active)
                return root.tunnels[i]
        return null
    }
    readonly property bool connected: root.activeTunnel !== null
    readonly property string name: root.connected ? root.activeTunnel.name : ""

    // ⚠️ `vpn` AND `wireguard` ARE TWO DIFFERENT TYPES IN NetworkManager, and a
    // check for one of them silently ignores the other. `vpn` covers OpenVPN,
    // WireGuard imported through the plugin, and the rest; `wireguard` is the
    // native kernel type NM grew separately. Both are a VPN to the person
    // looking at the switch.
    function isVpn(t) { return t === "vpn" || t === "wireguard" }

    // nmcli -t fields: colons separate, `\:` is a literal colon, `\\` a
    // literal backslash. Twelve lines that do exactly that, rather than a
    // pattern that the engine reads differently than it looks.
    function splitFields(line) {
        var out = [], cur = "", i = 0
        while (i < line.length) {
            var c = line.charAt(i)
            if (c === "\\" && i + 1 < line.length) { cur += line.charAt(i + 1); i += 2; continue }
            if (c === ":") { out.push(cur); cur = ""; i++; continue }
            cur += c; i++
        }
        out.push(cur)
        return out
    }

    function toggle() {
        if (root.fake) {
            root.status = "fake mode — nothing was switched"
            return
        }
        if (!root.available) {
            // Nothing to do, and it says so rather than doing nothing quietly.
            root.status = "No VPN connection is configured"
            return
        }
        root.status = ""
        var a = root.activeTunnel
        // ⚠️ ONE AT A TIME. Two tunnels up at once is a routing table nobody
        // asked for, so switching one on takes the other down first — which is
        // what `nmcli connection up` does anyway for the default route, but
        // saying it here means the list on screen matches the machine.
        act.command = a !== null
            ? ["nmcli", "connection", "down", "uuid", a.uuid]
            : ["nmcli", "connection", "up", "uuid", root.tunnels[0].uuid]
        act.running = true
    }

    function connectTo(uuid) {
        if (root.fake) { root.status = "fake mode — nothing was switched"; return }
        root.status = ""
        act.command = ["nmcli", "connection", "up", "uuid", uuid]
        act.running = true
    }

    function disconnect() {
        if (root.fake) { root.status = "fake mode — nothing was switched"; return }
        var a = root.activeTunnel
        if (a === null)
            return
        root.status = ""
        act.command = ["nmcli", "connection", "down", "uuid", a.uuid]
        act.running = true
    }

    // ⚠️ THE READ IS THE ONLY SOURCE OF TRUTH, and the switch does not set its
    // own state. The same rule the power profile tile was rebuilt around on
    // 09.08.: it showed the wish out of shell.json instead of what the machine
    // was doing. A tunnel can go down because the network went away, because a
    // key expired, or because something else took it down — none of which we
    // would hear about if the switch remembered its own position.
    Process {
        id: read
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,ACTIVE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var lines = String(this.text).split("\n")
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].length === 0)
                        continue
                    // ⚠️ SPLIT ON UNESCAPED COLONS, BY HAND, AND NOT WITH A
                    // LOOKBEHIND. nmcli -t escapes a colon inside a field as
                    // `\:` — a connection called "work:vpn" is legal — so a
                    // naive split shifts every field one to the right and the
                    // UUID ends up being a fragment of the name.
                    //
                    // ⚠️⚠️ `split(/(?<!\\):/)` LOOKED RIGHT AND IS SILENTLY
                    // WRONG IN QML. Measured, because the service reported zero
                    // tunnels on a machine where nmcli listed one: QV4 does not
                    // throw on the lookbehind, it accepts the pattern and then
                    // does not split at all — `"a:b".split(/(?<!\\):/)`
                    // returns ONE element. A regex that quietly returns the
                    // wrong answer is worse than one that fails, and no test
                    // would have caught it because the parse "succeeded".
                    var f = root.splitFields(lines[i])
                    if (f.length < 4)
                        continue
                    if (!root.isVpn(f[2]))
                        continue
                    out.push({
                        name: f[0],
                        uuid: f[1],
                        type: f[2],
                        active: f[3] === "yes"
                    })
                }
                root.tunnels = out
            }
        }
    }

    Process {
        id: act
        onExited: function (code) {
            if (code !== 0)
                root.status = "nmcli refused (" + code + ") — is the connection complete?"
            // Read back either way: a refusal leaves the machine in whatever
            // state it was already in, and the switch has to show that state
            // rather than the one that was asked for.
            settle.restart()
        }
    }

    // ⚠️ AN EVENT STREAM, NOT A POLL — the same shape as services/Net.qml, and
    // for the same reason written there: `nmcli monitor` is one small process
    // that says nothing until something changes, and a timer that asks every
    // few seconds is a wake-up every few seconds on a laptop.
    Process {
        id: monitor
        command: ["nmcli", "monitor"]
        running: !root.fake
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (line) { settle.restart() }
        }
        onExited: function () { relight.start() }
    }
    Timer { id: relight; interval: 2000; onTriggered: if (!root.fake) monitor.running = true }
    Timer { id: settle;  interval: 250;  onTriggered: read.running = true }

    Component.onCompleted: if (!root.fake) read.running = true
}
