pragma Singleton

// What is actually installed on this machine: cursor themes, fonts, keyboard
// layouts.
//
// ⚠️ IT EXISTS BECAUSE A TEXT BOX IS THE WRONG QUESTION. The settings window
// asked you to TYPE a cursor theme, and his report was short: "bei den cursorn    english-ok: the report, quoted
// gibt es aktuell keine auswahl nur eine texteingabe was falsch ist". He is       english-ok: the report, quoted
// right, and the proof is in the defaults: `cursor.theme` ships as
// "Breeze_Dark", and this machine has Adwaita, breeze_cursors, Breeze_Light and
// McMojave-cursors — no Breeze_Dark at all. A field you type into cannot tell
// you that; a list cannot avoid telling you.
//
// ⚠️ NOTHING RUNS UNTIL SOMETHING ASKS. `scan()` is called by the settings
// pages that need it, once per shell life. An idle desktop must not be listing
// fonts, and `fc-list` on a machine with 133 families is not free.
//
// ⚠️ ONE PROCESS, NOT FOUR. Each of these is a one-line shell command; spawning
// four processes to answer one question is the shape this project keeps finding
// in its own code (a `ps` per row, a render per key). The answers are separated
// by markers instead.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ⚠️ `available`, NOT `ready` — this said `ready`, nothing in the whole
    // shell read it, and services/qmldir states that every service carries
    // `available` "without exception". So the rule had a hole in it and the
    // hole had no reader: two faults sharing one line. tools/smoke.qml never
    // caught it because this service was not in its list either, which is the
    // second half of the same omission and is fixed alongside.
    readonly property bool available: root._done
    property bool _done: false
    property bool _running: false

    // Sorted, de-duplicated, and empty until asked.
    property var cursorThemes: []
    property var fonts: []
    property var monoFonts: []
    property var keyboardLayouts: []
    property var keyboardVariants: []
    // xkb's own option names, "caps:escape" and the other ninety. The row for
    // these was a free text box, and a typo in it is not an error anywhere —
    // niri passes the string to xkb, xkb ignores what it does not know, and the
    // key you rebound simply does not change.
    property var keyboardOptions: []
    // ⚠️ FULL PATHS, because that is what the setting holds. The label is
    // shortened for reading; the value has to stay the path or the timer plays
    // nothing. Sorted so alarm-clock-elapsed — the default — is near the top of
    // its own theme rather than wherever the filesystem put it.
    property var soundFiles: []
    // The render nodes this machine has, stable form first. Feeds the one row
    // that can stop niri from starting if it is given a path that does not
    // resolve, so offering the real ones is not a convenience here.
    property var renderDevices: []

    function scan() {
        if (root._done || root._running)
            return
        root._running = true
        proc.running = true
    }

    Process {
        id: proc
        // ⚠️ The cursor directories are the DIRECTORIES THAT CONTAIN a
        // `cursors` folder — that is what makes a theme a cursor theme rather
        // than an icon theme, and it is why `Adwaita` appears here while most
        // of /usr/share/icons does not.
        //
        // `:spacing=100` is fontconfig's own word for monospaced. Asking it
        // beats keeping a list of names that would be wrong on the next
        // machine.
        command: ["sh", "-c", `
            echo "--cursors"
            for d in /usr/share/icons "$HOME/.icons" "$HOME/.local/share/icons"; do
                [ -d "$d" ] || continue
                find "$d" -maxdepth 2 -name cursors -type d 2>/dev/null
            done | sed 's|/cursors$||' | while read -r p; do basename "$p"; done | sort -u
            echo "--fonts"
            fc-list : family 2>/dev/null | tr ',' '\\n' | sed 's/^ *//; s/ *$//' \\
                | grep -v '^$' | sort -u
            echo "--mono"
            fc-list :spacing=100 : family 2>/dev/null | tr ',' '\\n' | sed 's/^ *//; s/ *$//' \\
                | grep -v '^$' | sort -u
            echo "--layouts"
            awk '/^! layout/{f=1;next} /^!/{f=0} f&&NF{print $1}' \\
                /usr/share/X11/xkb/rules/base.lst 2>/dev/null | sort -u
            echo "--variants"
            awk '/^! variant/{f=1;next} /^!/{f=0} f&&NF{print $1}' \\
                /usr/share/X11/xkb/rules/base.lst 2>/dev/null | sort -u
            echo "--options"
            awk '/^! option/{f=1;next} /^!/{f=0} f&&NF{print $1}' \\
                /usr/share/X11/xkb/rules/base.lst 2>/dev/null | sort -u
            echo "--sounds"
            for d in /usr/share/sounds "$HOME/.local/share/sounds"; do
                [ -d "$d" ] || continue
                find "$d" -type f \\( -name '*.oga' -o -name '*.ogg' \\
                     -o -name '*.wav' \\) 2>/dev/null
            done | sort -u
            echo "--drm"
            for n in /dev/dri/renderD*; do
                [ -e "$n" ] || continue
                b=$(basename "$n")
                p=$(readlink -f "/sys/class/drm/$b/device" 2>/dev/null)
                d=$(basename "$(readlink -f "/sys/class/drm/$b/device/driver" 2>/dev/null)")
                # ⚠️ ONE ENTRY PER DEVICE, and the by-path form when there is
                # one — not both forms. renderD128/renderD129 are handed out in
                # probe order, so on a hybrid machine they can swap between
                # boots and the setting would then quietly name the other card.
                # The by-path name is the PCI address, which does not move.
                # Offering both would also put two pills with the same driver
                # label next to each other, which answers nothing.
                path="$n"
                if [ -n "$p" ] && [ -e "/dev/dri/by-path/pci-$(basename "$p")-render" ]; then
                    path="/dev/dri/by-path/pci-$(basename "$p")-render"
                fi
                # ⚠️ NOT \${d:-unknown}. This whole command is a JavaScript
                # template literal, so \${...} is an INTERPOLATION and QML tries
                # to parse the shell default-value syntax as JavaScript —
                # "Expected token ','" at this line, and every singleton that
                # imports this one then reports as unavailable, which makes it
                # look like a qmldir problem three files away. Plain "$d" is
                # safe because it has no brace; the fallback moves to a line of
                # its own.
                [ -n "$d" ] || d=unknown
                echo "$path	$d"
            done
            echo "--end"
        `]
        stdout: StdioCollector { id: collected }

        onExited: function (code) {
            root._running = false
            var buckets = { "cursors": [], "fonts": [], "mono": [],
                            "layouts": [], "variants": [], "options": [],
                            "sounds": [], "drm": [] }
            var cur = ""
            var lines = String(collected.text || "").split("\n")
            for (var i = 0; i < lines.length; i++) {
                var ln = lines[i]
                if (ln.indexOf("--") === 0) {
                    cur = ln.substring(2)
                    continue
                }
                if (cur.length > 0 && buckets[cur] !== undefined && ln.length > 0)
                    buckets[cur].push(ln)
            }
            root.cursorThemes = buckets.cursors
            root.fonts = buckets.fonts
            root.monoFonts = buckets.mono
            root.keyboardLayouts = buckets.layouts
            root.keyboardVariants = buckets.variants
            root.keyboardOptions = buckets.options
            root.soundFiles = buckets.sounds
            // ⚠️ The driver name rides along on the same line, separated by a
            // tab, because "which of these is the NVIDIA" is the only question
            // anybody has when they open this list — and answering it here
            // costs nothing, where a second lookup per entry would be a process
            // per row. Split into {path, driver} so the path can never end up
            // in the settings file with a label glued to it.
            var drm = []
            for (var j = 0; j < buckets.drm.length; j++) {
                var parts = String(buckets.drm[j]).split("\t")
                if (parts[0] && parts[0].length)
                    drm.push({ path: parts[0], driver: parts.length > 1 ? parts[1] : "" })
            }
            root.renderDevices = drm
            // ⚠️ `_done` even on a non-zero exit, and even on an empty answer.
            // A machine without fontconfig is a machine where the list stays
            // empty and the field stays typable — retrying forever would be a
            // process that never stops on exactly the machine that can least
            // afford one.
            root._done = true
        }
    }
}
