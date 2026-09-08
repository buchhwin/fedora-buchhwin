pragma Singleton

// A timer for working: start it, and the notch counts down instead of telling
// the time until it runs out.
//
// ⚠️ CALLED `Countdown`, NOT `Timer`. QtQuick has a `Timer` type, and a
// singleton of the same name would shadow it inside every file that imports
// services/ — including this one, which needs a real Timer to tick. Same reason
// the palette singleton is `Scheme` and not `Palette`.
//
// ⚠️ IT SURVIVES A RESTART OF THE SHELL, and that is the whole difference
// between a timer and a toy. `Restart=always` means a crash brings the shell
// back in two seconds; without the deadline written down, a twenty-five minute
// stretch would quietly become nothing. What is stored is the DEADLINE, not the
// remaining time — an absolute instant needs no clock running to stay true.
//
// ⚠️ AND IT TICKS ONLY WHILE IT RUNS. The Timer below is stopped when nothing is
// counting, so the idle desktop has no repeating work of its own — which is the
// rule this project measures itself against.
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Singleton {
    id: root

    readonly property bool available: true

    // Milliseconds since the epoch at which it ends. 0 means nothing is set.
    property real deadline: 0
    // While paused, what was left when it was paused.
    property real held: 0
    property real total: 0
    property bool paused: false
    // True from the moment it reaches zero until it is acknowledged, so the
    // notch can say so rather than silently going back to the time of day.
    property bool rang: false

    readonly property bool active: root.deadline > 0 || root.paused
    readonly property bool running: root.deadline > 0 && !root.paused

    property real remaining: 0

    signal finished

    // m:ss under an hour, h:mm:ss over it — the shortest form that is not
    // ambiguous, because this is read out of the corner of an eye.
    function clock(ms) {
        var s = Math.max(0, Math.ceil(ms / 1000))
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        var sec = s % 60
        function p(n) { return n < 10 ? "0" + n : "" + n }
        return h > 0 ? h + ":" + p(m) + ":" + p(sec) : m + ":" + p(sec)
    }

    readonly property string label: root.rang ? "0:00" : root.clock(root.remaining)

    // ------------------------------------------------------------- the controls
    function start(seconds) {
        root.total = seconds * 1000
        root.deadline = Date.now() + root.total
        root.held = 0
        root.paused = false
        root.rang = false
        root._save()
    }

    function add(seconds) {
        if (!root.active) return
        if (root.paused) root.held += seconds * 1000
        else root.deadline += seconds * 1000
        root.total += seconds * 1000
        root._save()
    }

    function pause() {
        if (!root.running) return
        root.held = Math.max(0, root.deadline - Date.now())
        root.deadline = 0
        root.paused = true
        root._save()
    }

    function resume() {
        if (!root.paused) return
        root.deadline = Date.now() + root.held
        root.held = 0
        root.paused = false
        root._save()
    }

    function stop() {
        root.deadline = 0
        root.held = 0
        root.total = 0
        root.paused = false
        root.rang = false
        root.remaining = 0
        root._save()
    }

    // Acknowledging is not stopping: it clears the alarm and leaves the timer
    // ready to be started again with the same length.
    function acknowledge() {
        root.rang = false
        root.remaining = 0
        // ⚠️ AND IT HAS TO BE WRITTEN DOWN, which it was not — this is the
        // second half of a fix that shipped as a half.
        //
        // `rang` is restored from disk on every start (`_restore` reads it
        // back), and clearing it only in memory left `rang: true` in the file
        // for ever. So the minute-timer below dutifully cleared it, the file
        // disagreed, and the next shell start put `0:00` back in the notch —
        // reported as "der timer ist immer noch sichtbar bei 0:00", after the   // english-ok: quoted brief
        // self-acknowledge had already been built and believed.
        //
        // Every other writer of `rang` in this file calls `_save()`. This one
        // was the exception, and an exception nobody noticed is how a fixed bug
        // comes back looking exactly the same.
        root._save()
    }

    // ⚠️ AND IT ACKNOWLEDGES ITSELF AFTER A MINUTE, because otherwise it never
    // does. `rang` was cleared by exactly one thing: the "got it" pill on the
    // timer page inside the notch. Somebody who hears the chime, reads the
    // notification and carries on has `0:00` sitting in their notch for the
    // rest of the session — which is what he reported, and it is worse than
    // useless: a badge that is always there is a badge nobody reads.
    //
    // ⚠️ NOT INSTANT, AND NOT NEVER. The whole point of `rang` is that the
    // notch does not quietly go back to the time of day the moment a timer
    // ends — you might have been in another room. A minute is long enough to
    // walk back to the machine and short enough that it is still news. The
    // chime and the notification have already fired by then, so this badge is
    // the third telling, not the first.
    //
    // It restarts on every transition into `rang`, so a second timer finishing
    // during the minute gets its own full minute.
    Timer {
        running: root.rang
        interval: 60000
        repeat: false
        onTriggered: root.acknowledge()
    }

    // ---------------------------------------------------------------- the tick
    //
    // A whole second is enough for a countdown read at a glance, and it is 60
    // times less work per minute than the smooth version nobody asked for.
    Timer {
        interval: 1000
        repeat: true
        running: root.running
        triggeredOnStart: true
        onTriggered: {
            var left = root.deadline - Date.now()
            if (left <= 0) {
                root.remaining = 0
                root.deadline = 0
                root.rang = true
                root._save()
                root.finished()
                return
            }
            root.remaining = left
        }
    }

    onPausedChanged: if (root.paused) root.remaining = root.held

    // -------------------------------------------------------------- the sound
    //
    // ⚠️ `pw-play`, NOT `canberra-gtk-play`. The canberra one is the obvious
    // choice and it is a GTK program: measured, it exits with "Cannot open
    // display" when it has no toolkit connection, which is a strange thing to
    // require of a beep. pw-play is part of PipeWire, which this desktop
    // already runs, and it played the file with no display at all.
    //
    // ⚠️ NOT VERIFIED AUDIBLE. The test VM has no sound hardware, so what is
    // proven is that the command runs and exits 0. Whether it is loud enough to
    // notice is his to say, on the laptop.
    Process { id: chime }

    // ⚠️ AND IT HAS TO SAY SO IN WRITING, not only out loud. The notch used to
    // turn amber and hold the countdown in place of the clock; it does not any
    // more — the clock is the clock — so a chime on a machine whose volume is
    // down would be the whole notification. A real message survives that: it
    // arrives as a toast AND stays in the notifications tab, so a timer that
    // went off while you were in another room is still findable afterwards.
    //
    // We are the notification server ourselves, so this arrives at our own
    // toast surface — measured on the VM, the test messages came through.
    //
    // ⚠️ SENT AS `critical`, which is what makes it survive Do Not Disturb. A
    // countdown you set yourself is not an interruption from outside, and
    // silently swallowing it would make the whole timer untrustworthy.
    Process { id: announce }

    onFinished: {
        announce.command = ["notify-send", "--urgency=critical",
                            "--app-name=buchhwin",
                            "--icon=alarm",
                            "Timer finished", root.clock(root.total) + " is up"]
        announce.running = true

        if (!Config.timer.sound) return
        chime.command = ["pw-play", Config.timer.soundFile]
        chime.running = true
    }

    // ------------------------------------------------------------- the state
    //
    // ⚠️ NOT in shell.json. That file is the user's settings, edited by hand and
    // by the settings window; a countdown that rewrote it every time it was
    // started or paused would put runtime churn into the one file that is
    // supposed to be stable — and would fight anyone editing it.
    FileView {
        id: state
        path: (Quickshell.env("XDG_STATE_HOME")
               || Quickshell.env("HOME") + "/.local/state") + "/buchhwin/timer.json"
        printErrors: false
        onLoaded: root._restore()
    }

    function _save() {
        state.setText(JSON.stringify({
            deadline: root.deadline,
            held: root.held,
            total: root.total,
            paused: root.paused,
            rang: root.rang
        }) + "\n")
    }

    function _restore() {
        try {
            var d = JSON.parse(state.text())
            root.total = d.total || 0
            root.paused = d.paused === true
            root.held = d.held || 0
            root.rang = d.rang === true
            // ⚠️ A deadline in the past means it ran out while the shell was
            // away. It rings now rather than being silently discarded — the
            // whole point of writing it down was not to lose that.
            var dl = d.deadline || 0
            if (dl > 0 && dl <= Date.now()) {
                root.deadline = 0
                root.rang = true
                root.remaining = 0
            } else {
                root.deadline = dl
                root.remaining = root.paused ? root.held
                              : dl > 0 ? dl - Date.now() : 0
            }
        } catch (e) {
            // A state file that cannot be read is not worth a message: the
            // honest answer is simply that no timer is running.
            root.stop()
        }
    }
}
