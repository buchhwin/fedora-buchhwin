pragma Singleton

// Screen backlight, or the honest absence of one.
//
// There is no Wayland protocol for this, so it goes through brightnessctl —
// one of the few places where the desktop shells out, and it is listed in the
// package notes for exactly that reason.
//
// `available` is false on a desktop and in the VM (no backlight device at all),
// and the quick settings page leaves the row out rather than showing a slider
// that moves nothing.
//
// ─────────────────────────────────────────────────────────────────────────────
// TWO SCREENS, TWO ENTIRELY DIFFERENT MECHANISMS.
//
// The laptop panel is a file in /sys — reading it is free and writing it is
// instant. An external monitor is a device on the graphics card's I²C bus,
// spoken to in DDC/CI through `ddcutil`, and it is slow, per-model odd, and
// sometimes absent even when the monitor is plugged in. Pretending they are the
// same thing behind one number would mean the slow one setting the pace for
// both, so they stay apart: `available`/`value`/`set()` for the panel,
// `externalAvailable`/`externalValue`/`setExternal()` for the monitor.
//
// ⚠️ WHY THERE IS NO PERMISSION SETUP ANYWHERE — measured, because the earlier
// note in the plan said the opposite. `ddcutil` ships
// /lib/udev/rules.d/60-ddcutil-i2c.rules itself:
//
//     SUBSYSTEM=="i2c-dev", KERNEL=="i2c-[0-9]*", ATTRS{class}=="0x030000",
//     TAG+="uaccess"
//
// `uaccess` hands the logged-in user an ACL on the device. No group to join, no
// rule to write, no privilege change to ask anybody for — installing the
// package IS the setup, and it is already in packages/dnf-desktop.txt. The
// `class == 0x030000` clause limits it to display controllers, which is why
// /dev/i2c-0 on the test VM stays root-only: that one is the mainboard's SMBus,
// and it is right that nobody may poke it.
//
// ⚠️ AND THE PROBE IS FREE WHEN THERE IS NOTHING TO FIND. Measured three times
// on a machine with no DDC monitor: 0.01 s, and the same 0.01 s as root — so
// the quick answer was not the permission check bailing out. ddcutil decides
// from /sys/bus/i2c before it opens any device: "No display adapters with i2c
// buses appear to exist." That is what makes running it once at startup
// acceptable on a laptop that usually has no monitor attached.
//
// ⚠️ WHAT IS NOT MEASURED, said plainly: how long a `getvcp`/`setvcp` takes on
// a real monitor. No external screen exists on the test VM, and there is no way
// to fake one. The design assumes it is slow — one write in flight, coalesced,
// on release by default — which is the right assumption to be wrong about.
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Singleton {
    id: root

    property int max: 0
    property int value: 0
    readonly property bool available: max > 0
    readonly property real fraction: available ? value / max : 0

    // ⚠️ `-c backlight` is not optional. Without a class, brightnessctl picks
    // the FIRST device it finds — on the test VM that is `input1::numlock`, the
    // keyboard's numlock LED, class `leds`, max 1. The service then reported a
    // working backlight, the quick settings page drew a brightness slider, and
    // dragging it would have toggled a keyboard light. Measured, not imagined.
    function set(f) {
        if (!available) return
        var pct = Math.round(Math.max(0.01, Math.min(1, f)) * 100)
        apply.command = ["brightnessctl", "-c", "backlight", "-q", "set", pct + "%"]
        apply.running = true
        // Optimistic: the readback takes a moment and a slider that lags
        // behind the finger feels broken.
        root.value = Math.round(root.max * f)
    }

    Process { id: apply }

    Process {
        id: probe
        command: ["brightnessctl", "-c", "backlight", "-m", "info"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                // machine-readable: device,class,current,percent,max
                // No backlight device means brightnessctl prints nothing and
                // exits with an error — exactly the answer we want: `max`
                // stays 0 and `available` is false.
                var parts = text.trim().split(",")
                if (parts.length >= 5 && parts[1] === "backlight") {
                    root._device = parts[0]
                    root.value = parseInt(parts[2]) || 0
                    root.max = parseInt(parts[4]) || 0
                } else {
                    root._device = ""
                    root.max = 0
                }
            }
        }
    }

    // ⚠️ THERE IS NO POLL TIMER HERE, and that is deliberate.
    //
    // There was one: every four seconds, forever, it ran `brightnessctl` — a
    // process spawn, 21 600 of them a day, to re-read a number that changes
    // when somebody presses a key. On the laptop this is built for that is
    // battery and heat spent on nothing, and "the shell does nothing while
    // nothing is happening" is the standard the whole project is held to.
    //
    // Instead the value is read when there is a reason to believe it changed:
    //
    //   * we changed it        — `set()` knows the new value already
    //   * a key changed it     — the binding runs brightnessctl and THEN tells
    //                            the shell, which calls refresh() (see
    //                            config/Config.qml; that order also means the
    //                            screen still brightens when the shell is dead)
    //   * the file changed     — the watch below, where the kernel offers one
    //
    // `sysfs` does not reliably deliver inotify events for attribute writes, so
    // the watch is a bonus rather than the mechanism. refresh() is the contract.
    function refresh() {
        if (root._device.length)
            level.reload()
        else
            probe.running = true
    }

    property string _device: ""

    FileView {
        id: level
        path: root._device.length
              ? "/sys/class/backlight/" + root._device + "/brightness" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            var v = parseInt(text().trim())
            if (!isNaN(v)) root.value = v
        }
    }

    // ───────────────────────────────────────────────── the external monitor
    property bool externalAvailable: false
    property int externalValue: 0
    property int externalMax: 100
    readonly property real externalFraction:
        externalAvailable && externalMax > 0 ? externalValue / externalMax : 0

    // Which I²C bus the monitor sits on, as a bare number. Kept, rather than
    // letting ddcutil find the display again on every call, because finding it
    // is the expensive half: `--bus N` goes straight to the device, while a
    // bare `getvcp` walks every bus first.
    property int _bus: -1

    // ⚠️ ONE WRITE IN FLIGHT, AND THE NEWEST VALUE WINS. A drag produces
    // dozens of values a second; a DDC write may take a tenth of a second or
    // worse. Firing one process per value would leave a queue draining long
    // after the finger stopped, and the monitor would still be marching to a
    // brightness chosen half a second ago. So a write that arrives while
    // another is running does not spawn anything — it replaces `_pending`, and
    // the running one sends it when it finishes. Bounded by construction: at
    // most one process, at most one waiting number.
    property int _pending: -1
    // The last value actually handed to the monitor, so `commitExternal()` can
    // tell "the drag ended somewhere new" from "the drag ended where the live
    // updates already put it" and skip a pointless round trip over I²C.
    property int _sent: -1

    // ⚠️ THE SLIDER ALWAYS MOVES; only the SENDING is conditional. Whether a
    // value goes out while the finger is still down is a property of the
    // hardware, not of the widget, so the decision lives here rather than in
    // three call sites that would each have to remember it. The caller's
    // contract is simple: `setExternal` on every change, `commitExternal` when
    // the gesture ends.
    function setExternal(f) {
        if (!externalAvailable) return
        var pct = Math.round(Math.max(0, Math.min(1, f)) * root.externalMax)
        root.externalValue = pct        // optimistic, as with the panel
        if (Config.brightness.externalLive) root._queue(pct)
    }

    function commitExternal() {
        if (!externalAvailable) return
        if (root.externalValue !== root._sent) root._queue(root.externalValue)
    }

    function _queue(pct) {
        if (ddcSet.running) { root._pending = pct; return }
        root._send(pct)
    }

    function _send(pct) {
        root._sent = pct
        ddcSet.command = ["timeout", "5", "ddcutil", "--bus", String(root._bus),
                          "setvcp", "10", String(pct)]
        ddcSet.running = true
    }

    Process {
        id: ddcSet
        onExited: {
            if (root._pending >= 0) {
                var p = root._pending
                root._pending = -1
                root._send(p)
            }
        }
    }

    // ⚠️ RUN ONCE, NEVER ON A TIMER — the same rule the panel above follows,
    // and it matters more here: this one spawns a process that talks to
    // hardware. It runs when the shell starts and when something says a
    // monitor arrived, and at no other time.
    Process {
        id: ddcDetect
        running: Config.brightness.external
        // ⚠️ `timeout` IN FRONT OF IT, and it is not belt-and-braces. ddcutil
        // retries a bus that does not answer — measured on his laptop, three
        // tries a second apart per bus, and the journal filled with
        // "Checking EDID failed after 3 tries". Nothing in a desktop shell may
        // block for that long; five seconds is far more than a healthy probe
        // needs (0.1 s here) and far less than a person waits.
        command: ["timeout", "5", "ddcutil", "detect", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: {
                // ⚠️⚠️ THE OLD PARSER TOOK THE FIRST /dev/i2c-N IT COULD FIND,
                // ANYWHERE IN THE OUTPUT, and that is what he reported as "the
                // quick panel sometimes hangs everything". Measured on his
                // laptop, where `ddcutil detect --brief` says:
                //
                //     Invalid display
                //        I2C bus:          /dev/i2c-1
                //        DRM connector:    card1-eDP-1
                //     Invalid display
                //        I2C bus:          /dev/i2c-7
                //        DRM connector:    card1-eDP-1
                //
                // Both blocks are INVALID and both are the built-in panel. The
                // regex matched i2c-1 out of a block ddcutil had just refused,
                // and the getvcp that followed spent four to five seconds
                // retrying a bus with nothing on it.
                //
                // Two conditions now, and each one alone would have been enough:
                //
                //   1. the block must be a real display. `Invalid display` is
                //      ddcutil saying so in as many words.
                //   2. the connector must not be internal. eDP, LVDS and DSI are
                //      the built-in panel, and that one belongs to
                //      brightnessctl through /sys/class/backlight — talking DDC
                //      to it is asking the wrong interface for an answer the
                //      right one already has. It would also have drawn a second
                //      slider for the same screen.
                root.externalAvailable = false
                root._bus = -1

                var lines = String(text).split("\n")
                var bus = -1, conn = "", valid = false
                for (var i = 0; i <= lines.length; i++) {
                    var ln = i < lines.length ? lines[i] : ""
                    var isHeader = i === lines.length || /^\S/.test(ln)
                    if (isHeader) {
                        // A block just ended — judge it before starting the next.
                        if (valid && bus >= 0 && !/-(eDP|LVDS|DSI)/i.test(conn)) {
                            root._bus = bus
                            break
                        }
                        valid = /^Display\s/.test(ln)
                        bus = -1
                        conn = ""
                        continue
                    }
                    var mb = /\/dev\/i2c-(\d+)/.exec(ln)
                    if (mb) bus = parseInt(mb[1])
                    var mc = /DRM connector:\s*(\S+)/.exec(ln)
                    if (mc) conn = mc[1]
                }

                if (root._bus < 0)
                    return
                ddcGet.command = ["timeout", "5", "ddcutil", "--bus", String(root._bus),
                                  "getvcp", "10", "--brief"]
                ddcGet.running = true
            }
        }
    }

    Process {
        id: ddcGet
        stdout: StdioCollector {
            onStreamFinished: {
                // --brief answers `VCP 10 C 45 100`: feature, type, current,
                // max. A monitor that does not implement feature 10 prints
                // something else entirely, and then there is nothing to show.
                var p = text.trim().split(/\s+/)
                if (p.length < 5 || p[0] !== "VCP") {
                    root.externalAvailable = false
                    return
                }
                var cur = parseInt(p[3]), mx = parseInt(p[4])
                if (isNaN(cur) || isNaN(mx) || mx <= 0) {
                    root.externalAvailable = false
                    return
                }
                root.externalValue = cur
                root.externalMax = mx
                root.externalAvailable = true
            }
        }
    }

    // For whoever learns that a monitor was plugged in. Nothing calls it yet —
    // niri's output events are the obvious source and that is a separate piece
    // of work — but the alternative to having it is a poll timer, and this
    // project does not get to have one of those.
    function refreshExternal() {
        if (Config.brightness.external) ddcDetect.running = true
    }
}
