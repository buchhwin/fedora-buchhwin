pragma Singleton

// What the graphics hardware is, and whether Secure Boot is standing in the way
// of the driver for it.
//
// ⚠️ IT EXISTS FOR ONE STATE, AND THE CONDITION IS DELIBERATELY NARROW: an
// NVIDIA card is present, its module has been built, Secure Boot is on, and the
// module is NOT loaded. That is the akmods signing key never having been
// enrolled — the installer schedules it with `mokutil --import`, the enrolment
// itself happens in a blue firmware screen at the next boot with a short
// timeout, and missing that screen leaves exactly this state behind.
//
// ⚠️ WHAT A WINDOW CANNOT DO, which is why there is no wizard: the enrolment is
// outside the operating system. Nothing here can drive it. What a window CAN do
// better than any guide is say afterwards whether it worked — and that is
// precisely where people get stuck, because a module that was never signed and
// a module that was signed but not enrolled look identical from userspace.
//
// ⚠️ AND THE CONDITION HAS TO STAY NARROW OR IT BECOMES NOISE. A machine with
// no NVIDIA says nothing. Secure Boot off says nothing. Module loaded says
// nothing. The desktop does not depend on any of it — niri draws on the
// integrated GPU, whose driver is in the kernel.
//
// ⚠️ NOTHING RUNS UNTIL SOMETHING ASKS, like Installed.qml next door. `probe()`
// is called when the settings window first opens, and never at startup: this is
// a laptop, `bhctl doctor` measures the start path, and the answer changes at
// most twice in the machine's life. The other two routes to it already exist —
// the installer says it on the terminal, and `bhctl doctor` says it over SSH.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // "We have asked, and can answer" — not "there is a GPU". A service that
    // reported false for "no NVIDIA here" would be indistinguishable from one
    // that had not run yet, which is the shape services/qmldir forbids.
    readonly property bool available: root._done
    property bool _done: false
    property bool _running: false

    property bool nvidiaPresent: false
    property bool hybrid: false
    property string nvidiaAddress: ""
    property bool driverBuilt: false
    property bool moduleLoaded: false
    property bool secureBoot: false
    // `mokutil --list-new` is non-empty when an enrolment is already scheduled
    // and waiting for the next boot. It changes the advice from "run this
    // command" to "reboot and answer the blue screen", which is the difference
    // between useful and infuriating.
    property bool enrolmentPending: false

    // Whether an akmods key is in the MOK list at all, and whether the built
    // module actually carries a signature. Together they say WHICH of the two
    // Secure Boot failures this machine has — and they are different jobs.
    property bool keyEnrolled: false
    property bool moduleSigned: false

    // ⚠️ THE CARD USED TO SAY ONE THING FOR TWO DIFFERENT FAULTS. `needsEnrolment`
    // is only true when there is genuinely no key; when a key IS enrolled and
    // the module is unsigned, the answer is to rebuild and re-sign, and telling
    // someone to enrol a key they already enrolled is the kind of message that
    // costs an evening.
    readonly property bool needsResigning:
        root._done && root.nvidiaPresent && root.driverBuilt
        && root.secureBoot && !root.moduleLoaded
        && root.keyEnrolled && !root.moduleSigned

    readonly property bool needsEnrolment:
        root._done && root.nvidiaPresent && root.driverBuilt
        && root.secureBoot && !root.moduleLoaded
        && !root.needsResigning

    // ⚠️ A TEST SEAM, in the shape of the existing BUCHHWIN_SHELL_FAKE. The card
    // this service feeds appears on exactly one combination of four facts, and
    // no test machine can produce it: the VM has no NVIDIA and no Secure Boot,
    // and his laptop will only be in that state for the few minutes between
    // installing and rebooting. Without this the card would ship having never
    // been drawn, its text never read and its button never pressed — which is
    // how a warning ends up with a typo in it that nobody sees for a year.
    //
    //   BUCHHWIN_GPU_FAKE=needs-enrolment   the card, with the command
    //   BUCHHWIN_GPU_FAKE=pending           the card, with "reboot" instead
    //   BUCHHWIN_GPU_FAKE=loaded            NVIDIA fine — no card
    //   BUCHHWIN_GPU_FAKE=none              no NVIDIA at all — no card
    //
    // The last two are the controls: a card that is visible under every fake is
    // not conditional, it is just visible.
    function _fake(mode) {
        root.nvidiaPresent = mode !== "none"
        root.hybrid = mode !== "none"
        root.nvidiaAddress = mode === "none" ? "" : "0000:01:00.0"
        root.driverBuilt = mode !== "none"
        root.moduleLoaded = mode === "loaded"
        root.secureBoot = mode !== "none"
        root.enrolmentPending = mode === "pending"
        // ⚠️ The fake has to cover the new state too, or the resigning card
        // ships having never been drawn once — which is how a warning ends up
        // with a typo nobody sees for a year.
        root.keyEnrolled = mode === "needs-resigning"
        root.moduleSigned = false
        root._done = true
    }

    function probe() {
        if (root._done || root._running)
            return
        var fake = Quickshell.env("BUCHHWIN_GPU_FAKE")
        if (fake && String(fake).length) {
            root._fake(String(fake))
            return
        }
        root._running = true
        proc.running = true
    }

    Process {
        id: proc
        // ⚠️ ONE PROCESS, NOT SIX — the rule Installed.qml states and this
        // follows. Six markers, six answers, one fork.
        //
        // ⚠️ EVERY COMMAND HERE ANSWERS AS AN ORDINARY USER. mokutil --sb-state,
        // --list-new and the sysfs reads need no password, which is what lets
        // both this and `bhctl doctor` tell the truth without a polkit prompt.
        //
        // ⚠️ /sys/module/nvidia IS A DIRECTORY TEST, not `lsmod | grep`. There
        // is nothing to parse and nothing to get wrong.
        //
        // ⚠️ NO efivar FALLBACK for the Secure Boot state. Reading
        // /sys/firmware/efi/efivars/SecureBoot-* would be a second answer that
        // can disagree with the first; when mokutil is absent the state is
        // UNKNOWN and the card stays away, because the condition requires
        // Secure Boot known-on. lib/10-gpu.sh installs mokutil whenever there
        // is an NVIDIA to care about.
        command: ["sh", "-c", `
            echo "--gpus"
            for d in /sys/bus/pci/devices/*; do
                [ -r "$d/class" ] && [ -r "$d/vendor" ] || continue
                case "$(cat "$d/class")" in
                    0x03*) echo "$(basename "$d") $(cat "$d/vendor")" ;;
                esac
            done
            echo "--built"
            ls /lib/modules/"$(uname -r)"/extra/nvidia/nvidia.ko* 2>/dev/null | head -1
            echo "--loaded"
            [ -d /sys/module/nvidia ] && echo yes
            echo "--sb"
            mokutil --sb-state 2>/dev/null
            echo "--pending"
            mokutil --list-new 2>/dev/null | head -1
            echo "--enrolled"
            mokutil --list-enrolled 2>/dev/null | grep -ci "akmods"
            echo "--signed"
            modinfo nvidia 2>/dev/null | grep -ci "^sig"
            echo "--end"
        `]
        stdout: StdioCollector { id: collected }

        onExited: function (code) {
            root._running = false
            var buckets = { "gpus": [], "built": [], "loaded": [], "sb": [], "pending": [],
                            "enrolled": [], "signed": [] }
            var cur = ""
            var lines = String(collected.text || "").split("\n")
            for (var i = 0; i < lines.length; i++) {
                var ln = lines[i]
                if (ln.indexOf("--") === 0) { cur = ln.substring(2); continue }
                if (cur.length > 0 && buckets[cur] !== undefined && ln.length > 0)
                    buckets[cur].push(ln)
            }

            var nv = "", others = 0
            for (var j = 0; j < buckets.gpus.length; j++) {
                var f = String(buckets.gpus[j]).split(" ")
                if (f.length < 2)
                    continue
                if (f[1] === "0x10de")
                    nv = f[0]
                else
                    others++
            }
            root.nvidiaAddress = nv
            root.nvidiaPresent = nv.length > 0
            root.hybrid = nv.length > 0 && others > 0
            root.driverBuilt = buckets.built.length > 0
            root.moduleLoaded = buckets.loaded.length > 0
            root.secureBoot = String(buckets.sb.join(" ")).indexOf("SecureBoot enabled") >= 0
            root.enrolmentPending = buckets.pending.length > 0

            // ⚠️ THE TWO FACTS THAT TELL "not enrolled" FROM "not signed", and
            // without them the card told him to do something he had already
            // done. Measured on his laptop: three MOK keys enrolled, nothing
            // pending, and `modinfo nvidia` with NO signature field at all —
            // `modprobe` answers "Key was rejected by service". The key was
            // never the problem; the modules were built before it existed.
            //
            // Counted rather than parsed. `grep -c` gives a number on one line,
            // which cannot be half-read the way a name can.
            root.keyEnrolled = Number(buckets.enrolled.join("")) > 0
            root.moduleSigned = Number(buckets.signed.join("")) > 0

            // `_done` even on a non-zero exit and even on an empty answer, for
            // the same reason Installed.qml gives: retrying for ever is a
            // process that never stops on exactly the machine that can least
            // afford one. An unanswerable question means the card stays away.
            root._done = true
        }
    }
}
