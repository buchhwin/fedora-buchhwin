pragma Singleton

// Removable drives: what is plugged in, what is mounted, and getting them out
// safely.
//
// ⚠️ THIS WAS "DELIBERATELY OPEN" AND HE ASKED FOR IT ANYWAY, so the reason it
// was open is worth keeping rather than deleting. The usual client for this is
// `udiskie`, and udiskie is Python — buchhwin-desktop's own rules forbid Python
// in anything that runs, which is not a style preference: the predecessor died
// of five languages, and a daemon in a sixth would be the first crack.
//
// So it is not an exception, it is a different road. `udisks2` is already
// installed and its service already runs (lib/70-services.sh enables it, with a
// comment saying automounting is the one step deliberately not taken). What was
// missing is a client, and `udisksctl` — which ships in the same package — is
// one. No Python, no daemon of ours, and no second thing to keep alive.
//
// ⚠️ QUICKSHELL HAS NO DBus MODULE (services/Calendar.qml says so at the top and
// works around it with `busctl`), so a CLI is not a shortcut here — it is the
// only road that does not involve writing a helper in C.
//
// ⚠️⚠️ AND IT DOES NOT POLL. A service that asks "any new disks?" every second
// is exactly the battery drain M10 is about. `udisksctl monitor` is a process
// that sits quiet and prints a line when something changes; that line is the
// trigger, and the actual reading is `lsblk -J`, which is JSON rather than
// prose to be scraped. Nothing runs while nothing is happening.
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Singleton {
    id: root

    // [{ path, name, label, size, fstype, mounted, mountpoint, parent }]
    readonly property alias drives: root._drives
    property var _drives: []

    readonly property int mountedCount: {
        var n = 0
        for (var i = 0; i < root._drives.length; i++)
            if (root._drives[i].mounted)
                n += 1
        return n
    }

    readonly property bool available: root._drives.length > 0
    property string lastError: ""
    property bool busy: false

    // ------------------------------------------------------------- the reading
    function refresh() { reader.running = true }

    Process {
        id: reader
        // ⚠️ `-J`, and the fields spelled out. Parsing the aligned columns of a
        // bare `lsblk` is a scrape that breaks the day a label contains two
        // spaces — which is a thing people call a USB stick.
        //
        // `-o RM` is the removable flag, and it is the whole filter: this
        // service is about the stick you just plugged in, never about the disk
        // the system is running from. Mounting or ejecting THAT from a panel
        // tile is a way to lose an afternoon.
        command: ["lsblk", "-J", "-b", "-o",
                  "NAME,PATH,LABEL,FSTYPE,SIZE,MOUNTPOINT,RM,TYPE,HOTPLUG"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                try {
                    var tree = JSON.parse(text).blockdevices || []
                    for (var i = 0; i < tree.length; i++) {
                        var disk = tree[i]
                        // ⚠️ `hotplug` OR `rm`. A USB stick reports rm=true; a
                        // USB SSD in an enclosure reports rm=false and
                        // hotplug=true, and the second one is the case where
                        // ejecting properly actually matters.
                        if (!disk.hotplug && !disk.rm)
                            continue
                        var kids = disk.children || []
                        // A stick with no partition table is its own filesystem.
                        var parts = kids.length ? kids : [disk]
                        for (var j = 0; j < parts.length; j++) {
                            var p = parts[j]
                            if (!p.fstype)
                                continue
                            out.push({
                                path: String(p.path),
                                parent: String(disk.path),
                                name: String(p.name),
                                label: p.label ? String(p.label) : String(p.name),
                                fstype: String(p.fstype),
                                size: Number(p.size) || 0,
                                mounted: !!p.mountpoint,
                                mountpoint: p.mountpoint ? String(p.mountpoint) : ""
                            })
                        }
                    }
                } catch (e) {
                    root.lastError = "lsblk: " + e
                    return
                }

                var appeared = root._newSince(out)
                root._drives = out
                if (Config.disks.automount)
                    for (var k = 0; k < appeared.length; k++)
                        root.mount(appeared[k])
            }
        }
    }

    // Which paths are unmounted now and were not in the list before. The list is
    // compared rather than the count: swapping one stick for another is two
    // events that leave the count where it was.
    property var _seen: ({})
    function _newSince(next) {
        var fresh = []
        var now = {}
        for (var i = 0; i < next.length; i++) {
            now[next[i].path] = true
            if (!root._seen[next[i].path] && !next[i].mounted)
                fresh.push(next[i].path)
        }
        root._seen = now
        return fresh
    }

    // ------------------------------------------------------------ the watching
    Process {
        id: watcher
        running: true
        command: ["udisksctl", "monitor"]
        stdout: SplitParser {
            splitMarker: "\n"
            // Plugging one stick in prints several lines — the drive, the block
            // device, the filesystem. One reading after they stop beats three
            // during, which is the same settle Net.qml uses for the same reason.
            onRead: function (line) { settle.restart() }
        }
        // ⚠️ If the monitor dies the service goes blind SILENTLY — no error, no
        // empty list, just a tile that never changes again. Restarting it is
        // cheap; noticing it had stopped would not be.
        onExited: function () { relight.start() }
    }

    Timer { id: settle; interval: 400; onTriggered: root.refresh() }
    Timer { id: relight; interval: 2000; onTriggered: watcher.running = true }

    Component.onCompleted: root.refresh()

    // ------------------------------------------------------------- the actions
    // ⚠️ `--no-user-interaction`, on all three. Without it udisksctl will sit
    // waiting for a polkit password on a terminal nobody is looking at, and a
    // tile that has silently blocked on an invisible prompt is the exact failure
    // the update button was redesigned to avoid.
    function mount(path) {
        act.command = ["udisksctl", "mount", "--no-user-interaction", "-b", path]
        act.running = true
    }

    function unmount(path) {
        act.command = ["udisksctl", "unmount", "--no-user-interaction", "-b", path]
        act.running = true
    }

    // ⚠️ TWO STEPS, AND THE SECOND ONE IS THE POINT. Unmounting flushes the
    // filesystem; the drive keeps spinning and stays powered, and pulling it out
    // then is the thing everybody has been told not to do. `power-off` is what
    // makes the light go out, and it goes to the PARENT device — a partition
    // cannot be switched off on its own.
    function eject(path, parent) {
        ejectPath = parent
        act.command = ["udisksctl", "unmount", "--no-user-interaction", "-b", path]
        act.running = true
    }
    property string ejectPath: ""

    Process {
        id: act
        stderr: StdioCollector { id: actErr }
        onExited: function (code) {
            root.busy = false
            root.lastError = code === 0 ? "" : String(actErr.text).trim()
            if (code === 0 && root.ejectPath.length > 0) {
                var p = root.ejectPath
                root.ejectPath = ""
                power.command = ["udisksctl", "power-off",
                                 "--no-user-interaction", "-b", p]
                power.running = true
                return
            }
            root.ejectPath = ""
            root.refresh()
        }
    }

    Process {
        id: power
        stderr: StdioCollector { id: powerErr }
        onExited: function (code) {
            // ⚠️ NOT A FAILURE WORTH SHOUTING ABOUT. Plenty of enclosures refuse
            // to power down, and the unmount — the part that protects the data —
            // has already succeeded by the time this runs. Saying "eject failed"
            // here would teach people to ignore the message that matters.
            if (code !== 0)
                root.lastError = ""
            root.refresh()
        }
    }
}
