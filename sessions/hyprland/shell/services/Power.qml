pragma Singleton

// Battery, or the honest absence of one.
//
// `available` is false on a desktop, in a VM, and on any machine UPower does
// not know about — and the bar draws nothing rather than a battery symbol
// showing a number it invented. The test VM has zero UPower devices, so this
// service spends most of its life in exactly that state; that is the case
// worth getting right first, not an edge case.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../config"

Singleton {
    id: root

    readonly property var device: UPower.displayDevice

    // ------------------------------------------------------- the power profile
    //
    // ⚠️⚠️ READ FROM THE RUNNING SYSTEM, NOT FROM shell.json — and this project
    // has a scar for exactly this. `getent passwd` said zsh while the session
    // ran bash, and it was reported as done: reading a configuration is not a
    // measurement. `Config.power.profile` is what we WANT; this is what the
    // machine is actually on, and a tile that shows the wish while the machine
    // sits somewhere else is the same fault in a smaller box.
    //
    // ⚠️ Fedora 41+ ships tuned-ppd, which serves the same
    // net.hadess.PowerProfiles interface power-profiles-daemon did — so busctl
    // is the reader either way and no branch is needed. On a machine with
    // neither, `available` below stays false and the tile is not drawn.
    property string activeProfile: ""
    readonly property bool profilesAvailable: root.activeProfile.length > 0

    // balanced is always there; the other two depend on the machine. Read
    // rather than assumed — a desktop without a battery often has no
    // power-saver at all, and offering one that cannot be set is a control
    // that lies.
    property var profiles: []

    Process {
        id: profileRead
        // ⚠️ NO --user FLAG AT ALL. The first version passed
        // `--user=false`, which busctl rejects outright: "option '--user'
        // doesn't allow an argument". It is a switch, not a setting, and the
        // system bus is the default anyway — so the whole property silently
        // stayed empty and the tile would never have appeared. Found by running
        // the exact command on the machine rather than by reading it back.
        command: ["busctl", "get-property",
                  "org.freedesktop.UPower.PowerProfiles",
                  "/org/freedesktop/UPower/PowerProfiles",
                  "org.freedesktop.UPower.PowerProfiles", "ActiveProfile"]
        stdout: StdioCollector {
            onStreamFinished: {
                // busctl answers  s "balanced"
                var m = String(text).match(/"([^"]+)"/)
                root.activeProfile = m ? m[1] : ""
            }
        }
    }

    Process {
        id: profileList
        // The whole answer, parsed here. ⚠️ The first version piped busctl
        // through grep and sed inside `sh -c`, and the sed was wrong — it
        // returned `Profile" s "power-saver"` rather than `power-saver`. Three
        // levels of quoting to do what one regex does, in a language that can
        // see the result.
        command: ["busctl", "get-property",
                  "org.freedesktop.UPower.PowerProfiles",
                  "/org/freedesktop/UPower/PowerProfiles",
                  "org.freedesktop.UPower.PowerProfiles", "Profiles"]
        stdout: StdioCollector {
            onStreamFinished: {
                // busctl prints an array of dicts; each profile appears as
                //   "Profile" s "balanced"
                var out = []
                var re = /"Profile"\s+s\s+"([a-z-]+)"/g
                var m
                while ((m = re.exec(String(text))) !== null)
                    out.push(m[1])
                root.profiles = out
            }
        }
    }

    // ⚠️ ON DEMAND, NOT ON A TIMER. A poll every few seconds for a value that
    // changes when somebody presses something is exactly the idle drain M10 is
    // about — and this service is the one that would be hypocritical about it.
    // The quick panel calls this when it opens.
    function refreshProfile() {
        profileRead.running = true
        if (root.profiles.length === 0)
            profileList.running = true
    }

    function setProfile(name) {
        if (!String(name).length)
            return
        Config.set("power.profile", String(name))
        Config.flush()
        // services/Idle.qml owns the write to DBus — one writer, not two. Read
        // back shortly after so the tile shows what happened rather than what
        // was asked for.
        profileEcho.restart()
    }

    Timer {
        id: profileEcho
        interval: 400
        onTriggered: root.refreshProfile()
    }


    readonly property bool available:
        device !== null && device.ready && device.isPresent && device.isLaptopBattery

    readonly property real percent: available ? device.percentage * 100 : 0
    readonly property bool charging:
        available && (device.state === UPowerDeviceState.Charging
                      || device.state === UPowerDeviceState.FullyCharged)

    // Seconds, or 0 when UPower has not worked it out yet — which it often has
    // not for the first minute after a state change.
    readonly property real secondsLeft:
        !available ? 0 : (charging ? device.timeToFull : device.timeToEmpty)

    // ⚠️ 15 AND 5 WERE HARD-CODED HERE while the settings named the same
    // two numbers as the thresholds — so the documentation and the code agreed
    // by luck rather than by reading. They are settings now, and this is their
    // reader.
    readonly property int warnAt: Config.power ? Config.power.warnAt : 15
    readonly property int criticalAt: Config.power ? Config.power.criticalAt : 5

    readonly property bool low: available && !charging && percent <= warnAt
    readonly property bool critical: available && !charging && percent <= criticalAt

    // ------------------------------------------------------------- the warning
    // ⚠️ ONCE PER THRESHOLD PER DISCHARGE. UPower reports a new percentage every
    // few seconds, so "notify while below 15" is a notification every few
    // seconds — noise that trains you to ignore the one at 5. The flags latch on
    // the way down and are cleared by plugging in, which is the only event that
    // means "this discharge is over".
    //
    // ⚠️ AND THEY ARE CLEARED ON `charging`, NOT ON RISING PERCENTAGE. A battery
    // reading that wobbles 14 → 16 → 14 would otherwise re-arm and warn twice
    // for one crossing.
    property bool _warned: false
    property bool _warnedCritical: false

    onChargingChanged: {
        if (charging) {
            root._warned = false
            root._warnedCritical = false
        }
    }

    // ------------------------------------------------------ charge thresholds
    //
    // ⚠️ THE FILES DECIDE WHETHER THE ROW EXISTS, not the model name and not a
    // list of vendors. ThinkPads, most modern Dells and a good share of ASUS
    // machines expose charge_control_*_threshold; plenty of others do not, and
    // there is no way to know from here except to look.
    property bool thresholdsPresent: false

    Process {
        id: probeThresholds
        command: ["sh", "-c",
                  "ls /sys/class/power_supply/BAT*/charge_control_end_threshold 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: root.thresholdsPresent = String(this.text).trim().length > 0
        }
    }

    // ⚠️ IT READS BACK RATHER THAN TRUSTING THE WRITE. Firmware clamps these:
    // ask for 75/80 and some machines answer 70/80, some refuse a start value
    // above the current end, and some accept the write and ignore it. The tile
    // shows what the battery says, which is the same rule the power profile
    // tile was rebuilt around.
    property int chargeStartNow: 0
    property int chargeEndNow: 0

    Process {
        id: readThresholds
        command: ["sh", "-c",
                  "cat /sys/class/power_supply/BAT*/charge_control_start_threshold 2>/dev/null | head -1;"
                  + " cat /sys/class/power_supply/BAT*/charge_control_end_threshold 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var v = String(this.text).trim().split("\n")
                root.chargeStartNow = parseInt(v[0], 10) || 0
                root.chargeEndNow = parseInt(v[1], 10) || 0
            }
        }
    }

    property string chargeStatus: ""

    // ⚠️ THE WISH IS APPLIED, DEBOUNCED, AND ONLY WHEN IT IS A REAL PAIR. A
    // slider fires per frame; each firing here would be a pkexec, which is a
    // process and an authorisation check. 600 ms is long for a keystroke and
    // short for a decision.
    //
    // ⚠️ AND BOTH ZERO IS NOT A SETTING, IT IS "LEAVE IT ALONE". Applying 0/0
    // would tell the firmware to stop charging at zero percent, which on a
    // machine that honours it is a laptop that never charges again until
    // somebody finds this line.
    readonly property int chargeStartWanted: Config.power ? Config.power.chargeStart : 0
    readonly property int chargeEndWanted: Config.power ? Config.power.chargeEnd : 0

    onChargeStartWantedChanged: chargeDebounce.restart()
    onChargeEndWantedChanged: chargeDebounce.restart()

    Timer {
        id: chargeDebounce
        interval: 600
        onTriggered: {
            if (root.chargeStartWanted === 0 && root.chargeEndWanted === 0)
                return
            root.applyCharge(root.chargeStartWanted, root.chargeEndWanted)
        }
    }


    // ⚠️ pkexec NAMES A PROGRAM, NOT A COMMAND LINE. The polkit action installed
    // by lib/70-services.sh is bound to /usr/libexec/buchhwin-charge, which
    // takes two integers and can write nowhere else. Passing a shell line here
    // would hand a root shell to whatever could reach this function.
    function applyCharge(start, end) {
        if (!root.thresholdsPresent) {
            root.chargeStatus = "This machine exposes no charge thresholds"
            return
        }
        if (!(start >= 0 && end > start && end <= 100)) {
            root.chargeStatus = "Start has to be below end"
            return
        }
        root.chargeStatus = ""
        applyCh.command = ["pkexec", "/usr/libexec/buchhwin-charge",
                           String(start), String(end)]
        applyCh.running = true
    }

    Process {
        id: applyCh
        onExited: function (code) {
            if (code === 3)
                root.chargeStatus = "This machine exposes no charge thresholds"
            else if (code !== 0)
                root.chargeStatus = "Refused (" + code + ") — firmware may clamp these"
            readThresholds.running = true
        }
    }

    Process { id: announce }

    function _say(urgency, icon, title, body) {
        announce.command = ["notify-send", "--urgency=" + urgency,
                            "--app-name=buchhwin", "--icon=" + icon,
                            title, body]
        announce.running = true
    }

    function _remaining() {
        // UPower says 0 until it has an estimate, and "0 minutes left" on a
        // battery that has hours in it is worse than saying nothing.
        if (root.secondsLeft <= 0)
            return ""
        var m = Math.round(root.secondsLeft / 60)
        if (m < 60)
            return " — about " + m + " min left"
        return " — about " + Math.floor(m / 60) + " h " + (m % 60) + " min left"
    }

    onLowChanged: {
        if (!low || _warned)
            return
        root._warned = true
        root._say("normal", "battery-caution", "Battery low",
                  Math.round(root.percent) + "%" + root._remaining())
    }

    onCriticalChanged: {
        if (!critical || _warnedCritical)
            return
        root._warnedCritical = true
        // ⚠️ Also latches the low flag. Coming back from a suspend below 5 %
        // would otherwise cross 15 % on the way to the charger and warn about
        // "low" after having warned about "critical", in that order.
        root._warned = true
        root._say("critical", "battery-empty", "Battery critically low",
                  Math.round(root.percent) + "%" + root._remaining()
                  + ". Plug in now.")
    }

    // Once, at startup: whether the files exist and what they currently say.
    // Not a timer — thresholds change when somebody changes them, and that
    // somebody is this desktop.
    Component.onCompleted: {
        probeThresholds.running = true
        readThresholds.running = true
    }
}
