pragma Singleton

// What happens when the machine is left alone: the screen dims, then goes off,
// then the session locks, then it suspends.
//
// ⚠️ NONE OF THIS EXISTED, on a laptop. The desktop stayed awake and unlocked
// until the battery was flat. The last session concluded this needed technology
// that was not here — the handout said Quickshell has no idle service at all —
// and that was wrong on the first count. Quickshell 0.2.1 ships
// `IdleMonitor` in Quickshell.Wayland (re-exported from _IdleNotify), niri 26.04
// implements ext_idle_notifier_v1, and the lock screen has been in this repo
// since the beginning. Nothing was installed to make this work.
//
// ⚠️ `timeout` IS IN SECONDS, and that was measured rather than read: the type
// registration says "double" and stops there, while the Wayland protocol
// underneath counts milliseconds. shell/tools/idle-probe.qml asked for 3 against
// the real compositor and got `isIdle` at 3.00 s. Guessing that wrong is the
// difference between locking after five minutes and locking after three
// tenths of a second.
//
// ⚠️ FOUR INDEPENDENT MONITORS, NOT A CHAIN. Each delay counts from the start of
// idle, the way Windows counts: "screen off after 5, lock after 6" is two
// numbers a person can read back, not one number plus an offset that has to be
// re-derived whenever either moves. It also means a stage that is switched off
// cannot break the ones after it.
//
// ⚠️ AND EVERY MONITOR RESPECTS INHIBITORS. A video player holding an idle
// inhibitor stops all four, which is the entire reason the protocol has them.
// Without it this service is a thing that locks the screen during films.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "." as Services
import "../config"

Singleton {
    id: root

    // ⚠️ A MACHINE WITH NO BATTERY IS ON MAINS, not on battery. `available` is
    // false on a desktop and in a VM, and reading that as "on battery" would
    // give every desktop the aggressive timings.
    readonly property bool onBattery:
        Services.Power.available && !Services.Power.charging

    function _mins(v) {
        var n = Number(v)
        return (n > 0) ? Math.round(n * 60) : 0
    }
    function _pick(onBat, onAc) {
        // Config.power is null for the first frames of shell construction, like
        // every other group — see the guards elsewhere in this shell.
        if (!Config.power)
            return 0
        return root._mins(root.onBattery ? onBat : onAc)
    }

    readonly property int screenOffAfter: Config.power
        ? root._pick(Config.power.screenOffBattery, Config.power.screenOffAc) : 0
    readonly property int lockAfter: Config.power
        ? root._pick(Config.power.lockBattery, Config.power.lockAc) : 0
    readonly property int suspendAfter: Config.power
        ? root._pick(Config.power.suspendBattery, Config.power.suspendAc) : 0

    // Half a minute of warning before the screen goes, or a fifth of the delay
    // when the delay is short — a one-minute screen-off would otherwise dim
    // thirty seconds in, which is half the time spent dim.
    readonly property int dimAfter: {
        if (!Config.power || !Config.power.dimBeforeOff || root.screenOffAfter <= 0)
            return 0
        var lead = Math.min(30, Math.round(root.screenOffAfter * 0.2))
        return Math.max(1, root.screenOffAfter - lead)
    }

    // ------------------------------------------------------------------ dimming
    // ⚠️ THE LEVEL TO GO BACK TO IS REMEMBERED, NOT RECOMPUTED. Restoring to a
    // fixed number would silently overwrite whatever he had set; restoring to
    // "what it was" is the only version that is invisible when it works.
    property real _brightnessBefore: -1
    readonly property bool dimmed: root._brightnessBefore >= 0

    function dim() {
        if (root.dimmed || !Services.Brightness.available)
            return
        root._brightnessBefore = Services.Brightness.fraction
        Services.Brightness.set(Math.max(0.05, root._brightnessBefore * 0.3))
    }

    function undim() {
        if (!root.dimmed)
            return
        Services.Brightness.set(root._brightnessBefore)
        root._brightnessBefore = -1
    }

    // ------------------------------------------------------------------ actions
    Process {
        id: screenOff
        command: ["hyprctl", "dispatch", "dpms", "off"]
    }
    Process {
        id: screenOn
        // ⚠️ Called explicitly rather than trusting the compositor to undo it.
        // niri's own wiki drives power-off-monitors from swayidle and says
        // nothing about what turns them back on, and "it probably wakes on
        // input" is not something to find out with a dark screen. Turning on a
        // monitor that is already on costs nothing.
        command: ["hyprctl", "dispatch", "dpms", "on"]
    }

    // ⚠️⚠️ THE LOCK SCREEN IS NOT A CHILD OF THIS SHELL, AND THAT IS A LOCKOUT
    // FIX RATHER THAN TIDINESS.
    //
    // It used to be a plain `Process`, which put it inside
    // buchhwin-shell.service's control group — and that unit is
    // KillMode=control-group, so restarting the shell killed the lock screen.
    // Measured on a locked session, before and after:
    //
    //   locked                          3 qs processes   LockedHint=yes
    //   after restarting the shell      2 qs processes   LockedHint=yes
    //                                   …and typing the password does nothing
    //
    // niri keeps the session locked when the locking client dies. That is
    // correct and it is the whole security property of ext-session-lock — but
    // what is left behind is a machine nobody can get back into without a
    // second terminal. Every path that restarts this unit reaches it: the
    // rescue key, `bhctl update`, and `Restart=always` after a crash, which
    // this shell has had.
    //
    // A transient unit of its own is the fix — its own control group, out of
    // reach of anything done to the shell. Measured that killing the caller
    // leaves the unit running.
    //
    // ⚠️ AND THE UNIT NAME IS NOW THE "ONE AT A TIME" GUARD, which is stronger
    // than the flag it replaces. A `running` property resets to false when this
    // shell restarts, so the old guard would have started a SECOND lock screen
    // on top of the first — two processes holding PAM state for one screen.
    // systemd refuses a second start of a name that is taken, and goes on
    // refusing across a restart of this shell.
    //
    // `--collect` so a lock screen that fails does not leave its name held in a
    // failed state, which would be a lock screen that never comes up again; the
    // reset-failed in front of it covers a name left over from before this flag
    // was there.
    Process {
        id: locker
        command: ["sh", "-c",
            "systemctl --user reset-failed buchhwin-lock 2>/dev/null; "
            + "exec systemd-run --user --quiet --collect --unit=buchhwin-lock "
            + "--description='buchhwin lock screen' "
            + "sh -c 'BUCHHWIN_MODE=lock qs -c buchhwin'"]
    }

    // ⚠️ THERE IS NO `locked` PROPERTY ANY MORE, and removing it was the point
    // rather than a side effect. It read `locker.running`, which after the
    // change above is only "is systemd-run still going" — a tenth of a second,
    // and false for the whole time the screen is actually locked. Nothing read
    // it, so the choice was between a property that lies and no property; a
    // reader that needs the answer should ask systemd, which is the one place
    // that knows.
    function lock() {
        locker.running = true
    }



    // ------------------------------------------------------- someone else asks
    // ⚠️ WITHOUT THIS, "lid closes → lock only" IS A SETTING THAT DOES NOTHING.
    // logind's `lock` action does not lock anything itself: it emits a `Lock`
    // signal on the session and expects the session's own software to carry it
    // out. Nothing in this shell listened, so the option would have been a
    // choice in a menu with no machinery behind it — the exact fault this repo
    // has found five times under "a key with no reader".
    //
    // It is not only the lid. `loginctl lock-session` is the standard way for
    // anything else on the system to lock the screen, and it was equally dead.
    //
    // ⚠️ Quickshell 0.2.1 has no generic D-Bus binding, so this is `gdbus
    // monitor` and a line match rather than a signal subscription. Matching on
    // ".Session.Lock" and not on "Lock" is deliberate: the same stream carries
    // Unlock, and a substring match would treat one as the other.
    Process {
        id: lockSignal
        running: true
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (line) {
                if (String(line).indexOf(".Session.Lock ") >= 0)
                    root.lock()
            }
        }
    }

    function suspend() {
        // ⚠️ LOCK FIRST. Suspending without locking means opening the lid gives
        // back an unlocked desktop, which turns the whole page into decoration.
        // The lock screen comes up before the machine goes down; it is still
        // there on resume, because it is a process and processes survive a
        // suspend.
        root.lock()
        // ⚠️ NOT ITS OWN `systemctl suspend`. This held a second copy of a
        // session command, found by tests/session-actions.sh on its very first
        // run — which is what that check exists for. Idling into a suspend and
        // choosing "Suspend" in the panel are the same act, and a machine with
        // two spellings of it is a machine where one of them gets fixed.
        Services.Session.run("suspend")
    }

    // ---------------------------------------------------------------- monitors
    IdleMonitor {
        enabled: root.dimAfter > 0
        timeout: root.dimAfter
        respectInhibitors: true
        onIsIdleChanged: isIdle ? root.dim() : root.undim()
    }

    IdleMonitor {
        enabled: root.screenOffAfter > 0
        timeout: root.screenOffAfter
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle) {
                screenOff.running = true
            } else {
                screenOn.running = true
                // Waking the screen also undoes the dim, even if the dim
                // monitor's own edge is late: what he sees on the way back must
                // be the brightness he left, not a dark screen that brightens a
                // moment later.
                root.undim()
            }
        }
    }

    IdleMonitor {
        enabled: root.lockAfter > 0
        timeout: root.lockAfter
        respectInhibitors: true
        onIsIdleChanged: { if (isIdle) root.lock() }
    }

    IdleMonitor {
        enabled: root.suspendAfter > 0
        timeout: root.suspendAfter
        respectInhibitors: true
        onIsIdleChanged: { if (isIdle) root.suspend() }
    }

    // ----------------------------------------------------------- power profile
    // ⚠️ tuned-ppd, NOT power-profiles-daemon. Both answer on
    // net.hadess.PowerProfiles; only tuned-ppd is installed here, and the two
    // collide if both are (the same way tlp and tuned do). The three names below
    // are what this machine actually offers, read off the bus rather than
    // assumed.
    //
    // polkit's allow_active is `yes` for switch-profile, so the shell may do
    // this without a prompt while its session is the active one. It is NOT
    // allowed from an inactive session — which is exactly what happens over SSH,
    // and is why this cannot be checked from the other end of the tunnel.
    // ⚠️⚠️ B72 · THE COMMAND IS BUILT WHEN IT IS RUN, NOT BOUND — and the old
    // binding is the whole of "der Power Profile Button macht nix".              // english-ok: the report, quoted
    //
    // `command` used to end in `root.profileWanted` as a BINDING, and the
    // handler below starts the process the moment that property changes. QML
    // does not promise that a binding on another object has been re-evaluated
    // by the time a change handler runs — so busctl was launched carrying the
    // PREVIOUS profile. Measured on the VM, writing the key and reading the bus
    // back after each step:
    //
    //     shell.json -> performance    bus said "balanced"      (the old one)
    //     shell.json -> power-saver    bus said "performance"   (the previous)
    //     shell.json -> balanced       bus said "power-saver"   (the previous)
    //
    // One press behind, every time. And the tile reads ActiveProfile back 400 ms
    // later to show what happened — so it showed the unchanged value and looked
    // like a dead button, which is exactly how it was reported. Pressing twice
    // "worked", which is the shape that makes this kind of fault so confusing.
    //
    // Building the argv at call time removes the ordering question entirely:
    // there is no binding left to be stale.
    Process { id: profileSet }

    function applyProfile(name) {
        if (!String(name).length)
            return
        profileSet.command = ["busctl", "set-property",
                              "org.freedesktop.UPower.PowerProfiles",
                              "/org/freedesktop/UPower/PowerProfiles",
                              "org.freedesktop.UPower.PowerProfiles",
                              "ActiveProfile", "s", String(name)]
        profileSet.running = true
    }

    readonly property string profileWanted:
        Config.power ? String(Config.power.profile) : "balanced"

    onProfileWantedChanged: root.applyProfile(root.profileWanted)

    // ⚠️ `balanced` is skipped at STARTUP only, and deliberately: it is the
    // daemon's own default, so writing it on every login would be a DBus call
    // that changes nothing. A CHANGE to balanced still goes through the handler
    // above — that path was never the exception, and treating it as one would
    // make exactly one of the three tile positions dead.
    Component.onCompleted: {
        if (root.profileWanted.length && root.profileWanted !== "balanced")
            root.applyProfile(root.profileWanted)
    }
}
