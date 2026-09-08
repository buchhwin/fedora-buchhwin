pragma Singleton

// The process list behind the task manager.
//
// ⚠️ /proc IS READ DIRECTLY, NOT THROUGH `ps`. A `ps` every second is a process
// start every second, for ever, on a laptop — named as one of the three traps
// in the handover before a line of this was written. And not a process per row
// either, which is the same trap in a costume: ONE awk reads every file it
// needs in a single pass.
//
// ⚠️ AND IT ONLY RUNS WHILE THE PAGE IS VISIBLE. `active` is set by the surface
// and nothing polls when it is false — the same double gate the media page has,
// and the rule that got the brightness poll deleted.
//
// ⚠️ CPU IS A DIFFERENCE, NOT A NUMBER YOU CAN READ. /proc/<pid>/stat counts
// jiffies since the process STARTED, so one reading is the average over its
// whole life: a browser open since breakfast looks idle, a program that just
// spun up looks like it is on fire. Two readings and the delta is the only
// honest answer, which is why the first refresh shows a dash rather than a
// number it cannot justify.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool active: false
    property var procs: []
    property string status: ""
    property bool settled: false

    // Who we are. ⚠️ Read from /proc/self rather than from $UID, which is a
    // bash-ism that systemd user services do not export — the same shape of
    // hole as `USER` being absent in a container, which CI found on the lock
    // screen.
    property int uid: -1

    property var prev: ({})
    property real prevAt: 0
    property real hz: 100

    function refresh() { if (root.active) read.running = true }

    onActiveChanged: {
        if (!root.active)
            return
        root.settled = false
        root.prev = ({})
        root.prevAt = 0
        once.running = true
        read.running = true
    }

    // Read once per opening: the clock tick and our own uid. Neither changes
    // while the desktop is running, so asking for them every second would be
    // two answers a second that are always the same.
    Process {
        id: once
        command: ["sh", "-c", "getconf CLK_TCK; awk '/^Uid:/ {print $2; exit}' /proc/self/status"]
        stdout: StdioCollector {
            onStreamFinished: {
                var v = String(this.text).trim().split("\n")
                var h = parseInt(v[0], 10); if (h > 0) root.hz = h
                var u = parseInt(v[1], 10); if (!isNaN(u)) root.uid = u
            }
        }
    }

    // ⚠️ ONE awk OVER TWO GLOBS. `stat` carries the times and the resident
    // pages, `status` carries the owner, and awk can walk both in one pass with
    // FILENAME telling it which is which. Two processes would have been simpler
    // to write and twice the cost, every second, on battery.
    //
    // ⚠️ THE COMMAND NAME IS CUT AT THE LAST ')' AND NOT THE FIRST. A process
    // may be called `(sd-pam)` or `foo) bar`, and the first-bracket version of
    // this parser is the classic /proc bug: every field after it shifts, and
    // the CPU column quietly shows the memory.
    //
    // Field numbers are counted AFTER the command name is removed, so they are
    // the documented ones minus two: utime 14→12, stime 15→13, rss 24→22.
    readonly property string script:
        "awk '\n"
      + "  FILENAME ~ /\\/stat$/ {\n"
      + "    split(FILENAME, p, \"/\"); pid = p[3]\n"
      + "    b = index($0, \"(\"); e = 0\n"
      + "    for (i = length($0); i > 0; i--) if (substr($0, i, 1) == \")\") { e = i; break }\n"
      + "    if (b == 0 || e == 0) next\n"
      + "    cm = substr($0, b + 1, e - b - 1)\n"
      + "    n = split(substr($0, e + 2), a, \" \")\n"
      + "    if (n < 22) next\n"
      + "    comm[pid] = cm; jif[pid] = a[12] + a[13]; rss[pid] = a[22]\n"
      + "  }\n"
      + "  FILENAME ~ /\\/status$/ && /^Uid:/ {\n"
      + "    split(FILENAME, p, \"/\"); uid[p[3]] = $2\n"
      + "  }\n"
      + "  END { for (k in jif) printf \"%s\\t%s\\t%s\\t%s\\t%s\\n\","
      + " k, comm[k], jif[k], rss[k], (k in uid ? uid[k] : -1) }\n"
      + "' /proc/[0-9]*/stat /proc/[0-9]*/status 2>/dev/null"

    Process {
        id: read
        command: ["sh", "-c", root.script]
        stdout: StdioCollector { onStreamFinished: root.take(String(this.text)) }
    }

    function take(text) {
        // ⚠️ THE ELAPSED TIME IS MEASURED, NOT ASSUMED TO BE THE INTERVAL. The
        // timer says one second; a machine under load delivers 1.4, and
        // dividing by 1.0 would report every process as using 40 % more CPU
        // than it does — a task manager that lies upward is worse than none.
        var now = Date.now() / 1000
        var dt = root.prevAt > 0 ? (now - root.prevAt) : 0
        var next = {}, out = []
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            if (lines[i].length === 0)
                continue
            var f = lines[i].split("\t")
            if (f.length < 5)
                continue
            var pid = parseInt(f[0], 10)
            var jif = parseInt(f[2], 10) || 0
            next[pid] = jif
            var cpu = -1
            if (dt > 0.05 && root.prev[pid] !== undefined)
                cpu = Math.max(0, ((jif - root.prev[pid]) / root.hz) / dt * 100)
            out.push({
                pid: pid,
                name: f[1],
                cpu: cpu,
                // rss is in pages of 4 kB on every architecture this runs on.
                mem: (parseInt(f[3], 10) || 0) * 4 / 1024,
                // ⚠️ THE OWNER DECIDES WHETHER THERE IS A BUTTON. His choice was
                // "only my own", and that is not cosmetic: a stop button on a
                // root process asks for a password this surface cannot show,
                // and hangs.
                mine: parseInt(f[4], 10) === root.uid
            })
        }
        out.sort(function (a, b) { return (b.cpu - a.cpu) || (b.mem - a.mem) })
        root.prev = next
        root.prevAt = now
        root.settled = dt > 0.05
        root.procs = out
    }

    // ⚠️ TERM, AND NOTHING ELSE FROM HERE. SIGTERM lets a program save and
    // leave; -9 does not, and a task manager that reaches for it by default is
    // how work gets lost. If it does not go, the person presses the button
    // again — the second press is theirs to decide.
    function stop(pid, mine) {
        if (!mine) {
            root.status = "That process belongs to another user"
            return
        }
        root.status = ""
        kill.command = ["kill", "-TERM", String(pid)]
        kill.running = true
    }

    Process {
        id: kill
        onExited: function (code) {
            if (code !== 0)
                root.status = "kill refused (" + code + ")"
            root.refresh()
        }
    }
}
