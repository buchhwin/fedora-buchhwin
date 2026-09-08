pragma ComponentBehavior: Bound

// Key bindings — all of them, searchable, and the one handle that unfreezes a
// machine.
//
// ⚠️ IT EDITS NOW, AND THE CLASH CHECK IS THE REASON IT TOOK A SECOND PASS.
// Two bindings on one key is a KDL parse error, and niri does not start with a
// config it cannot parse — so a rebinding that is only checked afterwards costs
// a session, on the machine of somebody who was changing a shortcut. The check
// runs in Config.bindClash BEFORE anything is written, and the row says which
// binding is in the way rather than just refusing.
//
// ⚠️ AND IT WRITES AN OVERRIDE, NOT THE WHOLE LIST. See the note beside
// Config.binds: `binds` is all-or-nothing, so rebinding one key by saving the
// resolved list would freeze all the others and every default added
// later would never reach this machine. That has happened here once already.
//
// ⚠️ AND "RESET" IS NOT A PROCESS CALL. `bhctl binds reset` exists and does this
// from a terminal, but from here the whole operation is writing an empty list:
// Config.qml treats an empty `binds` as "the built-in set", so emptying it IS
// restoring the defaults. Spawning bhctl to do one assignment would put a second
// writer on shell.json, which is the one thing that file does not have.
//
// ⚠️ THE FROZEN LIST IS A REAL FAILURE THIS PROJECT HAS SEEN. A shell.json once
// carried 63 bindings copied from the defaults of the day, because `binds` used
// to have those defaults inside the adapter — so "the file wins when it says
// anything at all" froze them forever, and every new default afterwards was
// invisible on that machine. Migration 7→8 removes such a copy when it is
// exactly ours; this is the button for when it is not.
import QtQuick
import QtQuick.Layouts
import "../common"
import "../../config"
import "../../services" as Services
import "../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space3

    // ⚠️ WHAT "RESET THIS PAGE" HAS TO REMOVE, for the same reason OutputScales
    // carries the same line: this is not a `SettingRow`, so the reset cannot
    // find these two by walking the page. Both are TOP-LEVEL keys — see the note
    // beside them in Config.qml, where being nested is what brought back the
    // startup segfault.
    readonly property var resetKeys: ["binds", "rebinds"]

    // What the FILE says, as opposed to what is in force. Empty is the healthy
    // state and means "the built-in set".
    readonly property int frozen: {
        var b = Config.get("binds")
        return b && b.length ? b.length : 0
    }

    // ⚠️ THE ROWS COME FROM THE DEFAULTS, NOT FROM THE RESOLVED LIST, because a
    // row has to know the key it is an override OF. `Config.binds` has already
    // had the overrides applied, so a row built from it could only ever see
    // where a binding is now and never where it came from — and the identifier
    // an override is stored under is the default key.
    readonly property var shown: {
        var q = search.text.trim().toLowerCase()
        var out = []
        var all = Config.get("binds")
        if (!all || !all.length)
            all = Config.defaultBinds
        for (var i = 0; i < all.length; i++) {
            var b = all[i]
            var over = Config.rebindOf(b.key)
            var now = (over === undefined) ? String(b.key) : over
            var row = { def: String(b.key), now: now,
                        desc: String(b.desc), action: String(b.action),
                        changed: over !== undefined }
            if (q.length === 0
                || row.now.toLowerCase().indexOf(q) >= 0
                || row.def.toLowerCase().indexOf(q) >= 0
                || row.desc.toLowerCase().indexOf(q) >= 0
                || row.action.toLowerCase().indexOf(q) >= 0)
                out.push(row)
        }
        return out
    }

    // Which row is waiting for a key, by its default key. Empty means none —
    // and only one at a time, or two rows would both be listening and the
    // second one would silently win.
    property string capturingFor: ""

    // What the last attempt refused to do, and for which row.
    property string clashFor: ""
    property string clashText: ""

    readonly property int changedCount: {
        var n = 0
        var s = root.shown
        for (var i = 0; i < s.length; i++) if (s[i].changed) n++
        return n
    }

    function beginCapture(defaultKey) {
        root.clashFor = ""
        root.clashText = ""
        root.capturingFor = defaultKey
    }

    function applyCapture(defaultKey, wanted) {
        var clash = Config.bindClash(defaultKey, wanted)
        if (clash) {
            // ⚠️ NAMED, NOT JUST REFUSED. "That key is taken" sends you hunting
            // through sixty-eight rows for the one that has it.
            root.clashFor = defaultKey
            root.clashText = wanted + " is already " + String(clash.desc) + "."
            return
        }
        root.capturingFor = ""
        root.clashFor = ""
        Config.setRebind(defaultKey, wanted)
        // ⚠️ AND THE GENERATOR RUNS. Bindings live in the generated niri config,
        // which nothing rewrites on its own — they are kept out of the theming
        // fingerprint so a palette change cannot touch them. Without this line
        // the new key would sit in shell.json doing nothing until somebody
        // typed `bhctl niri apply`.
        Services.Theming.applyNiri()
    }

    BarText {
        Layout.fillWidth: true
        text: "Key bindings"
        font.pixelSize: Theme.fontSizeSm
        font.weight: Theme.weightSemibold
        color: Theme.fgMuted
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space3

        TextField {
            id: search
            Layout.fillWidth: true
            placeholder: "Search bindings"
            onCancelled: search.text = ""
        }

        BarText {
            text: root.shown.length + " of " + Config.binds.length
            font.pixelSize: Theme.fontSizeSm
            color: Theme.fgMuted
        }
    }

    // Only when the file has its own copy. A button that says "restore
    // defaults" on a machine already running the defaults is a button that
    // teaches you it does nothing.
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.frozen > 0
        spacing: Theme.space1

        BarText {
            Layout.fillWidth: true
            text: "This machine has its own copy of " + root.frozen
                + " bindings, so new built-in ones do not reach it."
            font.pixelSize: Theme.fontSizeSm
            color: Theme.warn
            wrapMode: Text.WordWrap
        }

        Pill {
            interactive: true
            BarText { text: "Use the built-in bindings"; color: Theme.fg }
            onClicked: {
                Config.set("binds", [])
                Config.flush()
                // ⚠️ It used to say "then run `bhctl niri apply`" underneath,
                // and that sentence was the honest description of a button that
                // only did half the job. Bindings live in the generated niri
                // config, which is deliberately outside the theming fingerprint
                // so a palette change cannot rewrite it — so nothing rewrote it
                // at all. Now the button finishes.
                Services.Theming.applyNiri()
            }
        }
    }

    // Only when something has actually been moved, for the same reason the
    // frozen-list button is conditional: a "put them back" control on a machine
    // that has changed nothing teaches you that it does nothing.
    RowLayout {
        Layout.fillWidth: true
        visible: root.changedCount > 0
        spacing: Theme.space3

        BarText {
            Layout.fillWidth: true
            text: root.changedCount + (root.changedCount === 1 ? " binding has" : " bindings have")
                  + " been moved."
            font.pixelSize: Theme.fontSizeSm
            color: Theme.fgMuted
        }
        Pill {
            interactive: true
            BarText { text: "Put them all back"; color: Theme.fg }
            onClicked: {
                Config.clearRebinds()
                Services.Theming.applyNiri()
            }
        }
    }

    Repeater {
        model: root.shown

        ColumnLayout {
            id: bindRow
            required property var modelData

            Layout.fillWidth: true
            spacing: 0      // literal-ok: absence of a gap — a row and its refusal are one block

            readonly property bool listening: root.capturingFor === bindRow.modelData.def

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space3

                // The key itself in the monospace face, so Mod+Shift+comma and
                // Mod+Shift+period line up instead of drifting by a character.
                //
                // ⚠️ A PILL RATHER THAN A LABEL, because it is the target now.
                // The reference this project already paid for: a hit area
                // smaller than the thing it looks like was the "every pill was
                // half dead" bug.
                Pill {
                    Layout.preferredWidth: Theme.space6 * 6
                    interactive: true
                    onClicked: root.beginCapture(bindRow.modelData.def)

                    BarText {
                        text: bindRow.listening ? "…" : bindRow.modelData.now
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSm
                        color: bindRow.listening ? Theme.accent
                             : bindRow.modelData.changed ? Theme.accent : Theme.fg
                    }
                }

                BarText {
                    Layout.fillWidth: true
                    text: bindRow.modelData.desc
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.fgMuted
                    elide: Text.ElideRight
                }

                // Back to the key it ships on. Only on rows that have moved —
                // and it says the default rather than just "reset", so you can
                // see what you are going back to before you do it.
                Pill {
                    visible: bindRow.modelData.changed
                    interactive: true
                    BarText {
                        text: "↺ " + bindRow.modelData.def
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.fgMuted
                    }
                    onClicked: {
                        Config.setRebind(bindRow.modelData.def, bindRow.modelData.def)
                        Services.Theming.applyNiri()
                    }
                }
            }

            KeyCapture {
                Layout.fillWidth: true
                capturing: bindRow.listening
                onCaptured: function (key) {
                    root.applyCapture(bindRow.modelData.def, key)
                }
                onCancelled: root.capturingFor = ""
            }

            BarText {
                Layout.fillWidth: true
                visible: root.clashFor === bindRow.modelData.def
                text: root.clashText
                font.pixelSize: Theme.fontSizeSm
                color: Theme.warn
                wrapMode: Text.WordWrap
            }
        }
    }

    // One sentence, per the brief — not an empty box.
    BarText {
        Layout.fillWidth: true
        visible: root.shown.length === 0
        text: "No binding matches that."
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
    }
}
