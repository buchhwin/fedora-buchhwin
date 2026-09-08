pragma Singleton

// What this machine IS: the processor, the memory, the graphics, the disk, and
// the versions of the four things the desktop is built out of.
//
// ⚠️ IT EXISTS BECAUSE HE ASKED FOR A PLACE TO LOOK: "es soll ganz unten in     // english-ok: his request, quoted
// einem evtl nueen tab mit systeninfos so die wichtigesten systeminfos          // english-ok: same quote, second line
// angezeigt werden". Which facts is his choice too — the machine (processor,    // english-ok: same quote, third line
// memory, graphics, disk) and the system (Fedora, kernel, niri, quickshell, and
// this desktop). Session, monitors and battery he explicitly did NOT pick, so
// they are not here.
//
// ⚠️⚠️ NOTHING PRIVATE, AND THIS IS THE ONE PAGE WHERE THAT MATTERS MOST. An
// info page is exactly what gets screenshotted into a bug report: no hostname,
// no IP, no user name, no serial. The GPU's device path is a fact about the
// hardware; its serial number is not, and neither is the machine's name.
//
// ⚠️ NOTHING RUNS UNTIL SOMETHING ASKS, and then only once — the same shape as
// Installed.qml. An info page is the classic place for a timer nobody needs:
// polling `df` in the background is precisely the idle work rule 8 forbids, and
// the numbers here do not move while you read them.
//
// ⚠️ ONE PROCESS, NOT NINE. Every line below is a one-line shell command;
// spawning one per row is the shape this project keeps finding in its own code.
// The answers are separated by markers, as in Installed.qml.
//
// ⚠️ AND CPU LOAD IS DELIBERATELY ABSENT. /proc counts jiffies since boot, so a
// single reading is the lifetime average rather than "now" — the measurement is
// written down in the handover. A number that is quietly wrong is worse than no
// number, and a page that reports what the machine IS does not need one.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool available: root._done
    property bool _done: false
    property bool _running: false

    // The machine.
    property string cpuModel: ""
    property int cpuCores: 0
    property int memTotalKb: 0
    property int memAvailableKb: 0
    property string graphics: ""
    property string diskTotal: ""
    property string diskFree: ""

    // The system it runs.
    property string osName: ""
    property string kernel: ""
    property string hyprlandVersion: ""
    property string quickshellVersion: ""
    // ⚠️ FROM WHAT THE INSTALLER LEAVES BEHIND, never from a literal in here. A
    // version baked into the source is a key with no writer: it is right on the
    // day it is typed and wrong every day after. Empty means the stamp is not
    // there, and the row says THAT rather than inventing a number.
    property string desktopVersion: ""

    function scan() {
        if (root._done || root._running)
            return
        root._running = true
        proc.running = true
    }

    Process {
        id: proc
        command: ["sh", "-c", `
            echo "--cpu"
            sed -n 's/^model name[[:space:]]*: //p' /proc/cpuinfo 2>/dev/null | head -1
            echo "--cores"
            grep -c '^processor' /proc/cpuinfo 2>/dev/null
            echo "--mem"
            sed -n 's/^MemTotal:[[:space:]]*\\([0-9]*\\).*/\\1/p' /proc/meminfo 2>/dev/null
            sed -n 's/^MemAvailable:[[:space:]]*\\([0-9]*\\).*/\\1/p' /proc/meminfo 2>/dev/null
            echo "--gpu"
            # ⚠️ The DEVICE, not the machine. lspci names the card; it says
            # nothing about who owns it. Cut at the first colon so the PCI
            # address does not ride along — it is not private, but it is not an
            # answer to "which graphics do I have" either.
            lspci 2>/dev/null | sed -n 's/^[^ ]* VGA compatible controller: //p' | head -2
            lspci 2>/dev/null | sed -n 's/^[^ ]* 3D controller: //p' | head -1
            echo "--disk"
            df -h --output=size,avail / 2>/dev/null | tail -1
            echo "--os"
            sed -n 's/^PRETTY_NAME="\\(.*\\)"$/\\1/p' /etc/os-release 2>/dev/null | head -1
            echo "--kernel"
            uname -r
            echo "--hyprland"
            Hyprland --version 2>/dev/null | head -1
            echo "--qs"
            qs --version 2>/dev/null | cut -d, -f1
            echo "--desktop"
            cat "\${XDG_STATE_HOME:-$HOME/.local/state}/buchhwin/version" 2>/dev/null | head -1
            echo "--end"
        `]
        stdout: StdioCollector { id: collected }

        onExited: function (code) {
            root._running = false
            var buckets = {}
            var cur = ""
            var lines = String(collected.text || "").split("\n")
            for (var i = 0; i < lines.length; i++) {
                var ln = lines[i]
                if (ln.indexOf("--") === 0) {
                    cur = ln.substring(2)
                    buckets[cur] = []
                    continue
                }
                if (cur.length > 0 && ln.length > 0)
                    buckets[cur].push(ln)
            }
            function one(k) {
                return (buckets[k] && buckets[k].length > 0) ? String(buckets[k][0]) : ""
            }

            root.cpuModel = one("cpu")
            root.cpuCores = parseInt(one("cores"), 10) || 0
            var mem = buckets["mem"] || []
            root.memTotalKb = parseInt(mem[0], 10) || 0
            root.memAvailableKb = parseInt(mem[1], 10) || 0
            root.graphics = (buckets["gpu"] || []).join(" · ")

            // `df -h` answers "40G 27G" on one line; two fields, in that order.
            var disk = one("disk").split(/\s+/).filter(function (s) { return s.length > 0 })
            root.diskTotal = disk.length > 0 ? disk[0] : ""
            root.diskFree = disk.length > 1 ? disk[1] : ""

            root.osName = one("os")
            root.kernel = one("kernel")
            root.hyprlandVersion = one("hyprland")
            root.quickshellVersion = one("qs")
            root.desktopVersion = one("desktop")

            // ⚠️ `_done` even on a non-zero exit and even on empty answers, for
            // the reason Installed.qml gives: a machine that cannot answer is a
            // machine where retrying forever is a process that never stops. The
            // rows say "unknown" instead, which is a fact rather than a blank.
            root._done = true
        }
    }
}
