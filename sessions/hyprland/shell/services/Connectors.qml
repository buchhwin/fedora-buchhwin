pragma Singleton

// What the KERNEL thinks is plugged in, which is a different question from what
// The compositor is drawing on.
//
// ⚠️ IT EXISTS FOR ONE REPORT, in his words: "HDMI Monitore werden nicht        // english-ok: his report, quoted
// erkannt, DisplayPort schon".                                                  // english-ok: his report, quoted
//
// The obvious suspect was our config generator and it is innocent: tools/hypr.qml
// cannot switch an output off, and `outputs` is empty on his machine anyway. The
// next suspect was hybrid graphics, and that died too — the machine it happens
// on has no discrete GPU at all.
//
// So this does not guess. It puts the kernel's list beside the compositor's, because the
// GAP between them names the layer the fault is in:
//
//   in neither list       the cable, the port, or a dock that needs a driver —
//                         DisplayLink appears as no DRM connector at all
//   kernel: disconnected  the cable or the monitor, not this desktop
//   kernel yes, the compositor no   a compositor problem, addressable through `outputs`
//   both, wrong mode      HDMI 1.4b does 4K at 30 Hz and no faster
//
// ⚠️ THE SAME FOUR-WAY VERDICT `bhctl doctor` MAKES, and deliberately so: two
// answers to "is my monitor there" that can disagree is worse than one.
// bhctl keeps its copy because whoever needs it may have no desktop to open.
//
// ⚠️ NOTHING RUNS UNTIL SOMETHING ASKS, like services/Gpu.qml next door. The
// displays page calls `probe()` when it opens. Connectors change when a cable
// moves, which is not something a laptop should be polling for.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // "We have asked and can answer" — not "there are connectors". A service
    // reporting false for "none found" would be indistinguishable from one that
    // has not run yet, which is the shape services/qmldir forbids.
    readonly property bool available: root._done
    property bool _done: false
    property bool _running: false

    // [{ name: "HDMI-A-1", connected: true, mode: "1920x1080" }]
    property var entries: []

    function probe() {
        if (root._done || root._running)
            return
        root._running = true
        proc.running = true
    }

    Process {
        id: proc
        // ⚠️ ONE PROCESS, NOT ONE PER CONNECTOR — the rule Installed.qml states
        // and Gpu.qml follows. A machine with three screens has a dozen
        // connector directories, and a fork for each is a fork too many.
        //
        // ⚠️ sysfs RATHER THAN `drm_info` OR `lspci`: neither is in any of the
        // five package lists, and installing a package in order to read a file
        // is a loop. `status` is one word and `modes` is one per line — there is
        // no English here to parse and nothing that changes between versions.
        //
        // The directory is `card1-HDMI-A-1`; the connector name is what follows
        // the first dash after the card number, and that is what the compositor calls it.
        command: ["sh", "-c", `
            for d in /sys/class/drm/card*-*; do
                [ -r "$d/status" ] || continue
                n=\${d##*/}
                printf '%s\t%s\t%s\n' "\${n#*-}" "$(cat "$d/status")" \\
                    "$(head -1 "$d/modes" 2>/dev/null)"
            done
        `]
        stdout: StdioCollector { id: collected }

        onExited: function () {
            root._running = false
            var out = []
            var lines = String(collected.text || "").split("\n")
            for (var i = 0; i < lines.length; i++) {
                var f = lines[i].split("\t")
                if (f.length < 2 || !f[0].length)
                    continue
                out.push({
                    name: f[0],
                    connected: f[1] === "connected",
                    mode: f.length > 2 ? f[2] : ""
                })
            }
            root.entries = out
            // `_done` even on an empty answer, for the reason Gpu.qml gives:
            // an unanswerable question means the block stays away rather than
            // a probe that retries for ever on the machine least able to
            // afford one.
            root._done = true
        }
    }
}
