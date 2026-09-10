pragma Singleton

// The one place user settings live: ~/.config/buchhwin/shell.json.
//
// One file, one writer. The settings window writes through this adapter and
// nothing else touches the file, so there is no second format to keep in sync
// and no daemon in the middle. the compositor's own Lua config is GENERATED from these
// values (see tools/hypr.qml) — it is an output, never an input, and editing
// it by hand is editing something that will be overwritten.
//
// Every key has a default here. A missing file, a truncated file or a key that
// does not exist yet all resolve to the same working desktop, which is what
// makes it safe to ADD settings later without a migration for every one.
//
// `version` does not contradict that. Adding a key still needs no migration;
// RENAMING or REMOVING one does, because the old name is already sitting in
// somebody's file. See Migrations.qml — the chain is deliberately almost empty,
// and exists so that the first rename is not the moment we discover we need it.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property alias look: adapter.look
    readonly property alias theme: adapter.theme
    readonly property alias theming: adapter.theming
    readonly property alias quick: adapter.quick
    readonly property alias surfaces: adapter.surfaces
    readonly property alias notifications: adapter.notifications
    readonly property alias nightlight: adapter.nightlight
    readonly property alias cursor: adapter.cursor
    readonly property alias gpu: adapter.gpu
    readonly property alias brightness: adapter.brightness
    readonly property alias motion: adapter.motion
    readonly property alias lock: adapter.lock
    readonly property alias fetch: adapter.fetch
    readonly property alias drive: adapter.drive
    readonly property alias power: adapter.power
    readonly property alias terminal: adapter.terminal
    readonly property alias notch: adapter.notch
    readonly property alias bar: adapter.bar
    readonly property alias session: adapter.session

    // Everything below feeds the generated compositor config.
    readonly property alias programs: adapter.programs
    readonly property alias keys: adapter.keys
    readonly property alias input: adapter.input
    readonly property alias windows: adapter.windows
    readonly property alias outputs: adapter.outputs
    readonly property alias autostart: adapter.autostart
    readonly property alias workspaces: adapter.workspaces
    readonly property alias wallpaper: adapter.wallpaper
    readonly property alias location: adapter.location

    readonly property alias version: adapter.version

    // Resolve "@terminal" against `programs`, returning an ARGUMENT LIST.
    //
    // the compositor's `spawn` takes one string per argument: `spawn "kitty" "-e" "fish"`.
    // Passing the whole command line as a single string makes the compositor look for a
    // binary with spaces in its name, which fails with a message that does not
    // mention the real cause. So commands are lists everywhere, and only the
    // generator ever turns them into text.
    function program(ref) {
        if (typeof ref !== "string" || !ref.length)
            return []
        if (ref.charAt(0) !== "@")
            return [ref]
        var list = adapter.programs[ref.substring(1)]
        if (list === undefined || list === null)
            return []
        // JsonAdapter hands back a QJSValue wrapper, not a JS Array —
        // Array.isArray() says false for it. Length and indexing are what work.
        var out = []
        for (var i = 0; i < list.length; i++)
            out.push(String(list[i]))
        return out
    }

    readonly property bool loaded: file.loaded

    // "We know what the config is" — which includes knowing there isn't one.
    //
    // On a fresh machine there is no file, the adapter defaults ARE the right
    // answer, and waiting for a load that will never come would block until
    // timeout. `_failed` covers that.
    //
    // ⚠️ `settled` is NOT the same as "a one-shot read is safe". Measured:
    // `loaded` turns true one event-loop step BEFORE the JsonAdapter pushes the
    // parsed values into its properties, so reading Config.look.gapsOut in the
    // same tick still returns the default. A binding survives that (it
    // re-evaluates); a generator that reads inside a function does not, and
    // writes the default into a file with no error anywhere — gapsOut 24 in
    // shell.json, `gaps_out = 10` in generated/settings.lua.
    //
    // The one-step deferral therefore lives in common/WaitFor.qml, so that
    // every consumer gets it instead of each rediscovering it. (`adapterUpdated`
    // looks like the right signal and is not: it does not fire on load.)
    //
    // ⚠️ AND `settled` DELIBERATELY DOES NOT TEST THAT THE BLOCKS EXIST.
    //
    // During the window above `adapter.theme` is NULL — not "still the
    // defaults", null — so `Config.theme.palette` throws, and it does so with a
    // config file that contains no nulls at all. The obvious repair, adding
    // `&& adapter.theme !== null` to this binding, made `qs -p shell` SEGFAULT
    // 6 times out of 6 where the same run without it merely warned. The
    // backtrace is the one this project knows by heart: QObjectWrapper::wrap ←
    // QQmlVMEMetaObject::writeProperty ← JsonAdapter::deserializeRec. Reading a
    // JsonAdapter sub-object from a binding that the adapter's own
    // deserialisation dirties is re-entrant, and quickshell does not survive it.
    // Moving the test into `onLoaded` avoided the crash and then hung on the
    // `onLoadFailed` path instead — two ways of being wrong about the same
    // thing.
    //
    // So the guard lives where the value is READ, not where it is announced:
    // theme/Scheme.qml, theme/Theme.qml and services/Theming.qml each check
    // `Config.theme` before dereferencing it. Three small guards that cannot
    // re-enter beat one clever one that can.
    readonly property bool settled: file.loaded || _failed
    property bool _failed: false

    // The built-in key bindings.
    //
    // ⚠️ THEY LIVE HERE, NOT IN THE ADAPTER, AND THAT IS LOAD-BEARING. As the
    // default of `adapter.keys.binds` they made quickshell segfault on about
    // half of all starts — see the note there for the bisection. JsonAdapter
    // never touches this property, so nothing overwrites a large JS array.
    //
    // ⚠️ An empty `keys.binds` in shell.json therefore means "the built-in
    // set", not "no bindings at all". That is the right default for a file
    // that has never been edited, and it is the one thing this arrangement
    // cannot express: to run with NO bindings, the settings window will have
    // to write an explicit marker rather than an empty list.
    // ⚠️ THE TABLE ITSELF LIVES IN config/Binds.qml.
    // It was 460 lines in the middle of this file, which made the one file
    // everyone has to open in order to change anything a third longer than it
    // needed to be. Nothing else moved: `binds` below, `rebindOf`,
    // `bindClash` and `setRebind` all still live here, because they are about
    // resolving what the USER wants rather than about what ships.
    readonly property var defaultBinds: Binds.defaultBinds

    // What everything reads. The file wins when it says anything at all.
    //
    // ⚠️ REBINDING WRITES AN OVERRIDE, NOT A COPY OF THE WHOLE LIST, and this is
    // the difference between a feature and a trap. `adapter.binds` is
    // all-or-nothing: the moment it holds anything the built-in set is gone, so
    // rebinding one key by writing the resolved list would freeze the other
    // all the others at whatever they were that day, and every default added
    // afterwards would be invisible on this machine. That has already happened
    // once here — a shell.json carried 63 frozen bindings for weeks — and
    // migration 7→8 exists to clean it up.
    //
    // So an override says only "the binding that ships on THIS key now lives on
    // that one". The default key is the identifier because the default keys are
    // unique and the actions are not: 68 bindings, 68 distinct keys, 30 distinct
    // actions. Changing a default key later makes its override stop applying,
    // which leaves the binding at the new default — the safe direction.
    //
    // An override to the empty string unbinds. That is a real thing to want and
    // it cannot be said any other way, since a missing entry means "unchanged".
    readonly property var binds: {
        var base = (adapter.binds && adapter.binds.length)
                       ? adapter.binds : root.defaultBinds
        var over = adapter.rebinds || []
        if (!over.length)
            return base

        var by = ({})
        for (var i = 0; i < over.length; i++)
            if (over[i] && over[i].from !== undefined)
                by[String(over[i].from)] = String(over[i].to === undefined ? "" : over[i].to)

        var out = []
        for (var j = 0; j < base.length; j++) {
            var b = base[j]
            var to = by[String(b.key)]
            if (to === undefined) { out.push(b); continue }
            if (to === "") continue                  // unbound on purpose
            // ⚠️ A COPY. Writing `b.key = to` would edit `defaultBinds`, which
            // is a readonly property holding one shared array — the override
            // would survive being removed, and only until the next restart, so
            // it would look like a bug in the file rather than in this loop.
            var c = ({})
            for (var k in b) c[k] = b[k]
            c.key = to
            out.push(c)
        }
        return out
    }

    // Which default key this one currently sits on, or "" when it is unbound.
    // The list is short enough that a scan is cheaper than an index nobody else
    // needs.
    function rebindOf(defaultKey) {
        var over = adapter.rebinds || []
        for (var i = 0; i < over.length; i++)
            if (over[i] && String(over[i].from) === String(defaultKey))
                return String(over[i].to === undefined ? "" : over[i].to)
        return undefined
    }

    // ⚠️ THE CONFLICT CHECK IS THE POINT OF THE WHOLE FEATURE, and it has to run
    // BEFORE the write. Two bindings on one key leaves Hyprland to keep one of them, and which
    // does not start with a config it cannot parse — so the cost of finding out
    // afterwards is a session that will not come up, on the machine of somebody
    // who was changing a shortcut.
    //
    // Returns the binding that is in the way, or null.
    function bindClash(defaultKey, wantedKey) {
        if (!wantedKey || wantedKey.length === 0)
            return null                     // unbinding cannot clash
        var all = root.binds
        for (var i = 0; i < all.length; i++) {
            var b = all[i]
            if (String(b.key) !== String(wantedKey)) continue
            // The binding being moved is allowed to keep its own key.
            var home = root.rebindOf(defaultKey)
            var itsCurrent = (home === undefined) ? String(defaultKey) : home
            if (String(b.key) === itsCurrent && itsCurrent === String(wantedKey))
                continue
            return b
        }
        return null
    }

    function setRebind(defaultKey, wantedKey) {
        var over = []
        var existing = adapter.rebinds || []
        for (var i = 0; i < existing.length; i++)
            if (existing[i] && String(existing[i].from) !== String(defaultKey))
                over.push(existing[i])
        // An override back onto the default key is not an override; dropping it
        // keeps the file free of entries that say nothing.
        if (String(wantedKey) !== String(defaultKey))
            over.push({ from: String(defaultKey), to: String(wantedKey) })
        adapter.rebinds = over
        root.flush()
    }

    function clearRebinds() {
        adapter.rebinds = []
        root.flush()
    }

    function save() { file.writeAdapter() }

    // ------------------------------------------------------------ by path
    //
    // Read and write one setting by its dotted path: "notch.flare",
    // "input.touchpad.tap". The settings window is built on these two, and
    // that is the whole point of them existing. A row declares ONE path and
    // both its reading and its writing go through it, so a slider labelled
    // "Notch flare" cannot be wired to `collapsedWidth`.
    //
    // ⚠️ That failure is the one tests/key-readers.sh CANNOT catch. Its subject
    // is "a row that writes a key nothing reads is a switch that lies"; this is
    // the version where both halves are real keys with real readers and the
    // label is simply attached to the wrong one. No text check finds that. Only
    // having a single source for the path does.
    //
    // ⚠️ Both walk `adapter`, not `root`. The aliases at the top of this file
    // cover the sections but not `version`, and `root.binds` is the RESOLVED
    // list — the built-in set when the file is silent — rather than what the
    // file actually says.
    function get(path) {
        var parts = String(path).split(".")
        var node = adapter
        for (var i = 0; i < parts.length; i++) {
            if (node === null || node === undefined)
                return undefined
            node = node[parts[i]]
        }
        return node
    }

    // ------------------------------------------------------ what the defaults ARE
    //
    // ⚠️⚠️ THIS EXISTS BECAUSE "DELETING THE KEY IS SETTING IT BACK" IS ONLY TRUE
    // ON DISK. config/Backup.qml carried that sentence as the reason it needs no
    // schema of its own, and it is half right: a file without the key does start
    // the shell at the default. A RUNNING shell does not.
    //
    // Measured on the test VM, with a control, because this is the whole reason
    // "die reset buttons machen nichts auf keiner seite":                        // english-ok: his report, quoted
    //
    //   the key written externally to a NON-default value  ->  the switch moved
    //   the same key DELETED externally                    ->  the switch did not
    //   restart the shell                                  ->  the switch moved
    //
    // A JsonAdapter writes the properties the document CONTAINS. A key that is
    // absent is not "restored to its default", it is simply not written — so the
    // property keeps whatever it last held, and the declared default only applies
    // when the object is constructed. Reset wrote a correct file and left every
    // control on screen showing the old value.
    //
    // ⚠️ AND THE DEFAULTS ARE STILL DECLARED IN EXACTLY ONE PLACE. This is not a
    // second copy of the schema: it is a snapshot of THE schema, taken from the
    // adapter itself in the one moment it holds its declared values and the file
    // has not landed on top of them. Measured: at the adapter's
    // `Component.onCompleted` the values are the declared ones even when
    // shell.json says the opposite, and the snapshot does not move afterwards.
    property var defaults: null

    // Plain JS all the way down, so nothing here is a live view of the adapter.
    // A reference would follow the file and the snapshot would quietly become a
    // copy of the user's settings — which is the same bug wearing a hat.
    function _snapshot(node, depth) {
        if (node === null || node === undefined || depth > 6)
            return undefined
        var t = typeof node
        if (t === "boolean" || t === "number" || t === "string")
            return node
        if (t !== "object")
            return undefined
        var out = {}
        var found = 0
        for (var k in node) {
            // `objectName` is Qt's, and a leading underscore is this project's
            // mark for something internal. Neither is a setting.
            if (k === "objectName" || k.indexOf("_") === 0)
                continue
            var v = node[k]
            var vt = typeof v
            if (vt === "function")
                continue
            if (vt === "boolean" || vt === "number" || vt === "string") {
                out[k] = v
                found++
            } else if (Array.isArray(v)
                       || (vt === "object" && v !== null
                           && typeof v.length === "number")) {
                // ⚠️ A LIST IS A LEAF, and treating it as a group cost a red
                // run: the walk below produces `undefined` for an EMPTY object,
                // an empty array is one, and `outputs` — whose default is `[]` —
                // came back as "the schema does not know this path". Resetting
                // the displays page then refused instead of clearing the list.
                // Every list in this config is owned whole by one row, which is
                // the same rule Backup.resetPaths applies when it refuses a
                // group but accepts an array.
                //
                // ⚠️⚠️ AND `Array.isArray` ALONE IS NOT ENOUGH — THIS IS THE WHOLE
                // OF "manche reset buttons gehen und manche nicht". A QML       // english-ok: his report, quoted
                // `property list<string>` is not a JS array and `Array.isArray`
                // answers FALSE for one, so every such key fell through to the
                // branch below. An empty list has no properties, the walk
                // returns `undefined` for it, and the key never reached the
                // snapshot at all — while a non-empty one came back as
                // `{"0": "kitty", "1": …}`, which is worse because it looks
                // like an answer.
                //
                // `Config.defaultFor` then says "undefined", and
                // Backup.resetPaths stops the WHOLE page on one unknown path —
                // deliberately, so a page is never left half reset. So a single
                // `list<string>` anywhere on a page killed that page's reset
                // button and left every other page working. Measured on the
                // running shell, in its own words: "no default is declared for
                // bar.monitors — nothing was changed". There are TWENTY such
                // properties in this file.
                //
                // Copied by index rather than through JSON, because that is the
                // one way that works for both kinds.
                var list = []
                for (var n = 0; n < v.length; n++)
                    list.push(v[n])
                out[k] = list
                found++
            } else if (vt === "object" && v !== null) {
                var sub = root._snapshot(v, depth + 1)
                if (sub !== undefined) {
                    out[k] = sub
                    found++
                }
            }
        }
        return found > 0 ? out : undefined
    }

    // What a single dotted path is declared to be. `undefined` for a path that
    // does not exist, which the caller must tell apart from a default of `false`
    // or `""` — hence `undefined` rather than null.
    function defaultFor(path) {
        var parts = String(path).split(".")
        var node = root.defaults
        for (var i = 0; i < parts.length; i++) {
            if (node === null || node === undefined || typeof node !== "object")
                return undefined
            node = node[parts[i]]
        }
        return node
    }

    // Returns whether anything changed, so a caller can tell "set" from "was
    // already that". An unknown path warns rather than creating one: JsonAdapter
    // drops keys it does not declare, so a typo would write into a JS object
    // that is thrown away at the next parse and the row would appear to work.
    // ⚠️⚠️ A REFUSED WRITE USED TO BE COMPLETELY SILENT TO THE USER, and that is
    // the whole shape of the "manche switches gehen nicht … der schalter springt // english-ok: the report, quoted
    // zurück" report. `set` warned to the journal, returned false, and the row   // english-ok: the report, quoted
    // re-read the unchanged value and snapped back. Nothing on screen said a
    // word. Rule 5: what does not work has to say so.
    //
    // ⚠️ AND THE SIGNAL FIRES ONLY FOR THE TWO REAL FAULTS. `set` returns false
    // for THREE different things, and the third is not a fault at all — "the
    // value is already that" is a no-op, and reporting it would put a warning on
    // screen every time a row was set to what it already held. A warning that
    // cries wolf is worse than none; that is the same rule one level up.
    signal refused(string path, string reason)

    function set(path, value) {
        var parts = String(path).split(".")
        var node = adapter
        for (var i = 0; i < parts.length - 1; i++) {
            node = node[parts[i]]
            if (node === null || node === undefined) {
                console.warn("Config.set: no such section: " + path)
                root.refused(path, "no such section")
                return false
            }
        }
        var leaf = parts[parts.length - 1]
        if (node[leaf] === undefined) {
            console.warn("Config.set: no such key: " + path)
            root.refused(path, "no such key")
            return false
        }
        // Only for primitives. A list compares by identity, so an unchanged
        // list would look changed and — worse — a changed one could look equal
        // if the caller edited it in place.
        if (typeof value !== "object" && node[leaf] === value)
            return false
        node[leaf] = value
        writeSoon.restart()
        return true
    }

    // ⚠️ WRITES ARE DEBOUNCED, AND THAT IS NOT A NICETY. `save()` serialises the
    // entire adapter and rewrites shell.json; a dragged slider produces a value
    // per frame, so a row that saved on every change would rewrite the whole
    // file sixty times a second — on a laptop, which is what this is for.
    //
    // ⚠️ It is also the re-entrancy guard. services/Location.qml defers its one
    // write for exactly this reason: "a write that lands inside the handler
    // which triggered it re-enters the config adapter, and that is not
    // survivable." A timer is that deferral, and it happens to collapse the
    // drag as well.
    //
    // Nothing runs while nothing changes: the timer is started by `set`, never
    // repeats, and an idle desktop has no config writer ticking in it.
    Timer {
        id: writeSoon
        interval: 250
        onTriggered: root.save()
    }

    // Make a pending write immediate. The end of a drag knows it is the end —
    // LevelRow says so with `released` — and "soon" is the wrong answer for a
    // value the user has finished choosing.
    function flush() {
        if (writeSoon.running) {
            writeSoon.stop()
            root.save()
        }
    }

    // Migration ran and could not finish. Empty while all is well; the settings
    // window will show it, because a config that refused to move forward is
    // something the user has to know about rather than something to log.
    property string migrationError: ""

    // Blocks that came back as `null` and were replaced by their defaults. It
    // is a property rather than a log line for the same reason `migrationError`
    // is: something silently reverted to defaults is a thing the user has to be
    // able to find out about. tools/smoke.qml reports it and the settings
    // window will show it.
    property var nulledKeys: []

    // Bring an older file forward, before anything reads meaning into it.
    //
    // ⚠️ This runs on the RAW TEXT, not through the adapter — JsonAdapter drops
    // every key it does not declare, so by the time the adapter has parsed the
    // file the old field a migration exists to rescue is already gone.
    //
    // The rewrite goes through the same FileView that read it. A second view on
    // this path would be the trap that has cost this project three debugging
    // rounds; and because `watchChanges` reloads afterwards, the adapter ends up
    // parsing the MIGRATED text rather than the original.
    function _migrate() {
        var raw = file.text()
        if (!raw || !raw.length)
            return                    // no file: the defaults are correct

        var cfg
        try {
            cfg = JSON.parse(raw)
        } catch (e) {
            // A file we cannot parse must not be "migrated" — that would mean
            // replacing it with guesswork. Leave it; FileView already shouted.
            root.migrationError = "shell.json is not valid JSON: " + e
            return
        }

        // ⚠️ A `null` BLOCK IS DAMAGE, NOT A SETTING — and it perpetuates itself.
        //
        // Found on the test VM: shell.json contained `"theme": null`. JsonAdapter
        // then hands back null for the whole block, so `Config.theme.palette`
        // throws, and three separate readers went down with it — Scheme (the
        // palette name), Theme (the accent) and the Theming watcher (which
        // re-renders GTK, kitty and the compositor when the palette changes). None of them
        // said anything: the shell fell back to the built-in palette, which
        // happens to look like the default, so the desktop looked right while
        // choosing a different palette would have changed nothing outside the
        // shell. tests/smoke.sh had been failing on it for at least a day.
        //
        // Worse, `save()` writes the adapter back out — so once a null is in the
        // file, every settings change writes it again. The file heals only if
        // something removes it before the adapter ever sees it, which is here.
        //
        // ⚠️ HOW IT GOT THERE IS NOT PROVEN. No migration writes null, so the
        // likeliest source is a `writeAdapter()` during the window Shell.qml
        // documents at length — JsonAdapter is demonstrably racy while the shell
        // is still being built. That is a guess and is labelled as one; the
        // repair does not depend on it being right.
        //
        // ⚠️ AND IT HAS TO GO ALL THE WAY DOWN. The first version of this only
        // looked at the top level, which fixed `"theme": null` and left
        // `"timer": {"presets": null}` — measured on the same file, and the
        // adapter says so out loud: "Failed to deserialize property presets:
        // expected QList<int> but got std::nullptr_t". Nested is where a null is
        // most likely to appear and least likely to be noticed.
        //
        // Only exact `null`. `0`, `""`, `false` and `[]` are values somebody
        // chose; a null is a value nothing in this shell ever writes on purpose.
        var scrubbed = []
        function scrub(node, path) {
            if (node === null || typeof node !== "object")
                return
            if (Array.isArray(node)) {
                // A null IN a list would deserialize just as badly. Walk
                // backwards so removing one does not renumber the rest.
                for (var i = node.length - 1; i >= 0; i--) {
                    if (node[i] === null) {
                        node.splice(i, 1)
                        scrubbed.push(path + "[" + i + "]")
                    } else {
                        scrub(node[i], path + "[" + i + "]")
                    }
                }
                return
            }
            for (var key in node) {
                if (node[key] === null) {
                    delete node[key]
                    scrubbed.push(path + key)
                } else {
                    scrub(node[key], path + key + ".")
                }
            }
        }
        scrub(cfg, "")
        if (scrubbed.length) {
            root.nulledKeys = scrubbed
            // Written even when no migration is due — see below. A repair is not
            // a migration, so it does not wait for a version bump.
            file.setText(JSON.stringify(cfg, null, 2) + "\n")
        }

        if (Migrations.fromFuture(cfg)) {
            root.migrationError =
                "shell.json was written by a newer build (version " +
                Migrations.versionOf(cfg) + " > " + Migrations.current +
                "); leaving it untouched"
            return
        }
        if (!Migrations.needed(cfg)) {
            root.migrationError = ""
            return
        }

        var res = Migrations.migrate(cfg, { defaultBinds: root.defaultBinds })
        if (!res.ok) {
            root.migrationError = res.error
            return
        }
        root.migrationError = ""
        file.setText(JSON.stringify(res.config, null, 2) + "\n")

        // ⚠️ THE NEW NUMBER IS ADOPTED HERE, NOT WHEN THE FILE COMES BACK.
        //
        // The write triggers onFileChanged → reload → onLoaded, and until that
        // round trip completes the adapter still reports the OLD version — so
        // anything asking "is this config current" during the first run after a
        // version bump gets the wrong answer. Measured: bumping to 5 made
        // tests/smoke.sh fail on its first run on the test VM and pass on the
        // second.
        //
        // Waiting for that notification is the same mistake theme/Scheme.qml
        // documents at length: in a container it never arrives at all. The
        // migration has already happened in memory, so the number is set from
        // memory and the file is what the NEXT start reads.
        //
        // Only the version needs this. JsonAdapter drops every key it does not
        // declare, so a removed key was never in the adapter to begin with.
        adapter.version = Migrations.current
    }

    FileView {
        id: file
        path: Quickshell.env("XDG_CONFIG_HOME")
              ? Quickshell.env("XDG_CONFIG_HOME") + "/buchhwin/shell.json"
              : Quickshell.env("HOME") + "/.config/buchhwin/shell.json"
        watchChanges: true
        // Atomic: a settings write that is interrupted must not leave a
        // half-written file that the next start refuses to parse.
        atomicWrites: true
        onFileChanged: reload()
        // A parse failure must NOT overwrite the user's file with defaults.
        printErrors: true
        onLoaded: {
            root._failed = false
            root._migrate()
        }
        onLoadFailed: root._failed = true

        JsonAdapter {
            id: adapter

            // ⚠️ THE ONE MOMENT THE DEFAULTS ARE VISIBLE. The adapter is
            // constructed with its declared values; the FileView delivers the
            // document afterwards and overwrites them. Taking the snapshot here
            // is what makes `Config.defaults` the schema rather than a copy of
            // it — see the long note beside `defaults` for the measurement that
            // says this ordering holds.
            Component.onCompleted: root.defaults = root._snapshot(adapter, 0)

            // Bumped only when a key is RENAMED or REMOVED, never when one is
            // added. 0 means "written before versioning existed".
            //
            // ⚠️ This number and Migrations.current must match, and NOTHING
            // ELSE may state it. The installer used to seed `"version": 2` and
            // `bhctl shell reset` used to write `"version": 1` while the code
            // said 3 — three places claiming to know, two of them wrong, and
            // only the migration chain quietly papering over it. Both now write
            // no version at all: a file without one reads as 0 and is migrated
            // forward, which is exactly the path a genuinely old file takes.
            property int version: 19

            property JsonObject theme: JsonObject {
                // ⚠️ BLACK IS THE SHIPPED DEFAULT SINCE 09.09.2026, his
                // decision: "das default theme soll schwarz plain wie auf den   // english-ok: his decision, quoted
                // screenshots sein". The palette file is theme/palettes/       // english-ok: same
                // black.json — neutral greys from #000000 up, with the colours
                // present but desaturated, and a pastel green accent. It is a
                // file like every other palette rather than a special case, so
                // it can be left for another one in a keystroke.
                //
                // ⚠️ NOT `look.surfaceStyle` INSTEAD. That draws OUR OWN
                // surfaces black over whatever palette is loaded, which leaves
                // the text, the accent and every foreign program's colours
                // belonging to a scheme nobody chose. Both are on: the palette
                // makes the desktop black, the style keeps our surfaces opaque.
                property string palette: "black"
                property string accent: "green"

                // Where the accent comes from — his request: "man soll          // english-ok: the request, quoted
                // einstellen können ob dabei eine statische farbe als akzent    // english-ok: same
                // übernommen wird oder die vom wallpaper basiert".              // english-ok: same
                //
                //   "static"     the colour named by `accent` above
                //   "wallpaper"  one colour taken from the picture on screen
                //
                // ⚠️ THIS IS NOT `palette: "wallpaper"`, and the difference is
                // the whole point of the setting. That derives all 26 colours
                // from the image and repaints the desktop with it. This changes
                // ONE colour and leaves the black scheme alone, which is what
                // "schwarz plain, aber der Akzent darf mitgehen" means.   // english-ok: his words, quoted
                property string accentSource: "static"
                // The light half of the pair. `palette` is the one in force by
                // day-or-night default; this is what `autoLight` swaps to.
                property string lightPalette: "everforest-light"

                // ⚠️ THE SCHEDULE THAT `lightPalette` WAS WAITING FOR. The
                // comment beside it used to say "a name here switches on a
                // schedule later" — and later never came, so the key sat there
                // for months being read by nobody. tests/key-readers.sh found
                // it; he chose to build the switch rather than drop the key.
                //
                // "off" or "schedule". Sunrise/sunset is the obvious third mode
                // and is deliberately NOT declared yet: a mode nothing
                // implements is the same lie this key just stopped telling.
                property string autoLight: "off"
                // Local time, 24 hour. Light between these two.
                property string lightFrom: "07:00"
                property string lightUntil: "19:00"
                // Used when `palette` is "custom": one colour, and the whole
                // 26-name scheme is calculated from it. The same calculation
                // the wallpaper goes through — the image only ever contributed
                // a hue and a saturation, so handing those over directly needs
                // no second generator. See theme/FromImage.qml.
                // The default seed a "custom" scheme is calculated from — not a
                // colour anything is painted with, and only in effect once the
                // user has chosen "custom", by which point it is their value.
                property string customColor: "#7fbbb3"  // literal-ok: a seed, not a style
            }

            // ⚠️ WHICH PROGRAMS WE COLOUR, AND HOW — one of three states each.
            //
            //   "colour"   the system's colours (wallpaper, custom, or a
            //              shipped palette — whatever `theme.palette` says)
            //   "neutral"  a grey scheme: themed, but colourless
            //   "off"      we write nothing AND remove what we wrote before,
            //              so the program looks the way it would without us
            //   "inherit"  follow `mode` below — the default, so switching
            //              everything at once is one edit rather than twelve
            //
            // ⚠️ "off" has to CLEAN UP, not merely skip. A switch that leaves
            // the last file lying there does nothing visible, and a setting
            // that does nothing is the fault this project has now fixed four
            // times over. Only our own files are touched: kitty.conf,
            // btop.conf and .gitconfig belong to the user and are never
            // overwritten — only the pointer line we added is taken back out.
            property JsonObject theming: JsonObject {
                property bool enabled: true
                property string mode: "colour"
                // ⚠️ FLAT, not `targets: { gtk: … }`. Two levels of JsonObject
                // nesting does not come back from the file — measured: the
                // block parsed, the inner values stayed at their defaults, and
                // every switch silently did nothing. Every other block in this
                // file is one level deep, and now so is this one.
                property string gtk: "inherit"
                property string qt: "inherit"
                property string kitty: "inherit"
                property string alacritty: "inherit"
                // The compositor's own colours: window borders and the shadow.
                // Structure — gaps, border WIDTH, blur — is not here; that is
                // the config generator's, and a setting written by two tools on
                // two different triggers is a setting that can disagree with
                // itself.
                property string hypr: "inherit"
                property string btop: "inherit"
                property string bat: "inherit"
                property string fastfetch: "inherit"
                property string delta: "inherit"
                property string tmux: "inherit"
                property string starship: "inherit"
                property string lazygit: "inherit"

                // ⚠️⚠️ THIS COMMENT LOST ITS PROPERTY AND KEPT ITS SENTENCES.
                // `property string vscode` stood here, and its note said the
                // target also sets window.titleBarStyle: "native" — the line
                // that took VS Code's title bar off. The key went when the
                // profile was cut back; three lines of the note stayed, and
                // what followed began mid-thought — "Brave, and it is the exact
                // counterpart of the line above" — with no line above it any
                // more. A dangling comment is not harmless: it describes a
                // feature the reader then goes looking for.
                //
                // Brave is that counterpart, and now it is the whole of it: the
                // one target here that writes into a file the program owns.
                //
                // ⚠️ TWO SEPARATE THINGS, AND HE ASKED FOR BOTH IN ONE BREATH:
                // "ich will das mein brave auch so aussieht also ohne close      // english-ok: his report, quoted
                // button rechts etc" and "genau so ohne alles aber trozdem theme // english-ok: his report, quoted
                // abhänig".                                                      // english-ok: his report, quoted
                //
                //   browser.custom_chrome_frame = false   the FRAME. Set in
                //       every state including "off", like VS Code's
                //       titleBarStyle: it is not a colour, and the compositor's
                //       prefer-no-csd then draws no frame at all.
                //   browser.theme.user_color              the COLOUR, and only
                //       when we are colouring.
                //
                // ⚠️ BOTH NAMES ARE MEASURED, not remembered — `strings` over
                // /opt/brave.com/brave/brave lists them. The name this project
                // used before, `extensions.theme.system_theme`, was from an
                // older Chromium and Brave 151 dropped it on every start.
                //
                // ⚠️ AND THE TAB STRIP STAYS. It is browser content, not
                // decoration — the same boundary that keeps libadwaita header
                // bars in Nautilus. What goes is the window buttons.
                property string brave: "inherit"

                // ⚠️ `vesktop` AND `spicetify` STOOD HERE AND ARE GONE. They
                // went with the flatpaks: Spotify, Vesktop and Obsidian are
                // applications somebody chooses, and a window manager that
                // installs them is the overreach packages/flatpak.txt describes.
                // Colouring a program we no longer install would be a switch
                // that does nothing on every machine this installs on.
                //
                // Their note stayed behind for a while and said "the TWO that
                // colour a foreign program", about a block that had one left.
                // docs/CONFIG.md said the same, at more length, with a table.
                // tests/config-shape.sh now reads the targets out of this block
                // and requires that document to name exactly these — the
                // direction it was missing, and the one this drifted through.
            }


            // Night light, over gammastep — quickshell has no gamma API, and
            // this is one of the five programs the plan names as staying
            // external for that reason.
            property JsonObject nightlight: JsonObject {
                property bool on: false
                // 6500 K is neutral by definition; below it goes warm. 4000 is
                // a clear change without turning the screen orange.
                property int temperature: 4000
            }

            // Brightness on a screen that is not the laptop's own. The internal
            // backlight needs no settings — it either exists or it does not —
            // but an external monitor is talked to over I²C, and that is slow
            // enough and odd enough per model to deserve two switches.
            // ⚠️ THE POINTER, AND NOTHING SET IT BEFORE. It came from whatever
            // gsettings happened to hold — `Adwaita` at 24 on the test VM —
            // and the compositor's own `cursor {}` block carried only `hide-when-typing`,
            // so the desktop had no opinion about its own pointer at all.
            //
            // Two writers, and BOTH are needed: the compositor draws the pointer over the
            // desktop and over any surface that does not set its own, while GTK
            // applications read `org.gnome.desktop.interface cursor-theme` and
            // ignore the compositor entirely. Setting one leaves the other
            // wrong, which shows up as a pointer that changes shape when it
            // crosses a window edge. Verified from the compositor's shipped documentation
            // (Configuration: Miscellaneous.md:20) that the block accepts
            // `xcursor-theme` and `xcursor-size` — not from memory.
            property JsonObject cursor: JsonObject {
                // ⚠️⚠️ THE DEFAULT MUST NAME A THEME THAT IS ACTUALLY INSTALLED,
                // and it has been wrong twice for the same reason.
                //
                // First it was `Breeze_Dark`, described here as shipping with
                // breeze-cursor-theme — a package that was in no list under
                // packages/, so nothing installed it. The compositor was handed
                // a name that does not resolve, fell back to its own pointer at
                // its own size, and the report was "the cursor is far too big
                // and cannot be changed".
                //
                // Then it was `McMojave-cursors`, which was honest at the time
                // because lib/50-fonts.sh fetched it — a pinned third-party
                // tarball, downloaded at install time onto a work machine, to
                // replace a cursor the KDE base already provides. That phase is
                // gone with the rest of the minimalism pass, so naming it here
                // would put this comment straight back into its first mistake.
                //
                // `breeze_cursors` is the one that is genuinely there:
                // packages/dnf-desktop.txt installs breeze-cursor-theme, the
                // Fedora KDE base has it anyway, and it is the pointer Plasma
                // itself uses — so the two sessions match without either of them
                // deciding anything for the other.
                //
                // ⚠️ Note the second half of that first report: "and cannot be
                // changed". That was a separate fault in the settings row (see
                // SettingRow.qml), and fixing only one of the two would have
                // left a pointer that still could not be corrected.
                property string theme: "breeze_cursors"
                // 24 is the GNOME default and what the VM was running. It is a
                // separate key from `look.scale` on purpose: the pointer is
                // drawn by the compositor at its own size and does not follow
                // the shell's grid.
                property int size: 24
            }

            // ⚠️ WHICH CHIP DRAWS THE DESKTOP, and it exists for one specific
            // machine shape: a hybrid laptop. On most of them the external
            // display connectors are wired to the discrete GPU, so the compositor renders
            // on the integrated one and copies every frame across for that
            // screen. the compositor's own FAQ.md:43-55 names this and names the remedy —
            // `debug { render-drm-device }`, pointed at the discrete card.
            //
            // ⚠️ IT IS NOT FREE. Naming the discrete GPU means it never idles,
            // which on a laptop is watts. That is why the default is "let Hyprland
            // choose" and not "be clever".
            //
            // A separate group rather than a field on `outputs`: `outputs` is
            // one entry per monitor, and this is a single global choice with no
            // per-output meaning in the compositor. Not in `look` either — `look` is
            // appearance, and this is hardware.
            property JsonObject gpu: JsonObject {
                // "" means the compositor decides, following `outputs: []` — the mark for
                // "set by hand" is the entry existing, so there is one state
                // rather than a value plus a flag that can disagree with it.
                //
                // ⚠️ THE by-path FORM IS THE ONE TO USE:
                //   /dev/dri/by-path/pci-0000:01:00.0-render
                // renderD128/renderD129 are assigned in probe order and are not
                // guaranteed to mean the same card after a reboot. Both forms
                // are offered by the settings row; the stable one is offered
                // first.
                //
                // ⚠️⚠️ A PATH the compositor CANNOT OPEN IS NOT CAUGHT BY `Hyprland --verify-config`.
                // Measured on the compositor 26.04 with three controls: the block is
                // accepted, an invented key inside it IS rejected (so the name
                // is real and not silently ignored), and a device that does not
                // exist validates perfectly happily. The safeguards are
                // therefore elsewhere — the settings row is a CLOSED list built
                // from the render nodes this machine really has, an empty value
                // writes no block at all, and docs/HYPRLAND.md carries the way out
                // from a TTY.
                property string renderDevice: ""
            }

            property JsonObject brightness: JsonObject {
                // Whether to look for DDC/CI monitors at all. Measured on a
                // machine with none: `ddcutil detect` answers in 0.01 s and
                // never opens a device — it rules the whole thing out from
                // /sys/bus/i2c first. So the probe is not what this is for.
                // It is for the monitor that answers DDC badly, where the
                // honest fix is to stop asking.
                property bool external: true

                // ⚠️ FALSE, i.e. SEND ONCE ON RELEASE, and that is the careful
                // choice rather than the measured one. A DDC write takes as
                // long as the monitor feels like taking, and many pop their own
                // on-screen menu up for every one — a slider dragged live would
                // strobe that menu across the picture. No external monitor
                // exists on the test VM, so the honest state of this is: not
                // verified on real hardware, defaulted to the quiet side.
                //
                // Turning it on is safe from the shell's side either way:
                // Brightness.qml keeps at most ONE write in flight and
                // overwrites the pending value, so a fast bus feels live and a
                // slow one simply arrives late. It never queues up a drag.
                property bool externalLive: false
            }


            // How quickly the shell moves.
            //
            // ⚠️ ONE NUMBER, NOT THREE. The three durations are 120/200/320 ms
            // and their RATIO is a design decision — the fade is faster than the
            // settle, which is what makes content appear to arrive inside a
            // shape rather than after it. Three separate keys would invite
            // breaking that; a multiplier cannot.
            // ⚠️⚠️ FOUR NUMBERS AND A SWITCH, WHERE THERE USED TO BE ONE
            // MULTIPLIER — his design, handed over as a picture on 10.08.2026:
            // Reduce motion, Movement, Fades & colour, Hover response, Bounce.
            //
            // What that costs, said out loud because the old comment promised
            // the opposite: `motion.speed` scaled all three durations together,
            // so the RATIO between them survived any setting. Three separate
            // numbers can be set to any ratio at all, including ones that look
            // wrong. That is the trade he chose, with the alternative on the
            // table.
            //
            // ⚠️ Migration 14 → 15 converts an existing `speed` into these three
            // rather than dropping it. Somebody who had set 1.4 keeps the tempo
            // they chose instead of silently going back to the default.
            property JsonObject motion: JsonObject {
                // ⚠️ NOT the same switch as `look.profile: minimal`, and the
                // difference is what each one is FOR. `minimal` is a machine
                // decision — no animation, no blur, no shadows, no glass — for
                // hardware that would rather have the frames. This is a comfort
                // decision: keep the desktop as it looks, stop it moving.
                property bool reduce: false

                // Size and position: an island opening, a panel growing, a
                // window sliding. The slowest of the three because it is the
                // one the eye follows.
                // Fades and colour changes — a hover tint, a card appearing.
                // The response to the pointer arriving. Deliberately the
                // shortest: anything above about 200 ms reads as lag rather
                // than as motion.

                // How much a movement overshoots and settles back, as a
                // percentage. 0 is the plain curve; his picture asks for 79.
            }


            // The terminal's BEHAVIOUR, not its colours.
            //
            // ⚠️ THIS IS A LINE WE HAVE NOT CROSSED BEFORE. Until now the
            // renderer wrote foreign programs' COLOURS and nothing else — the
            // rule being that their configuration belongs to them. These four
            // are behaviour, and they are here because he asked for one of them
            // by name: the cursor trail from the predecessor
            // (fedora-buchhwin-hyprland/dotfiles/kitty/kitty.conf:44-46), which
            // the rewrite never carried across.
            //
            // It goes in the file we already generate and kitty already
            // includes, so there is no second include to seed and no file that
            // exists only on machines installed after today. Switching kitty's
            // theming off removes these with the colours, which is the honest
            // meaning of "off": we write nothing.
            property JsonObject terminal: JsonObject {
                // block | beam | underline — kitty's own three.
                property string cursorShape: "beam"
                // Seconds. 0 stops the blink; kitty treats a negative as
                // "system default", which is a third meaning nobody needs here.
                property real cursorBlinkInterval: 0.6
                // ⚠️ THE ANIMATION HE MEANT. kitty's `cursor_trail` is the
                // number of cells the cursor may fall behind before it catches
                // up in an animated sweep; 0 is off. Checked on the test
                // machine rather than assumed — kitty 0.47.1, and the option
                // exists in kitty's own option table.
                property int cursorTrail: 3
                property int scrollbackLines: 20000

                // ⚠️ THE FOUR BELOW ARE THE PREDECESSOR'S kitty.conf COMING
                // BACK, and their absence is the clearest single example of the
                // rule that decided what was carried across at all: the rewrite
                // took the lines that fit in a THEME file — font, cursor,
                // scrollback — and left behind every line that described how the
                // terminal BEHAVES. The old comment beside `allow_remote_control`
                // called the ssh kitten "the single biggest quality-of-life win
                // when you live in SSH sessions", which is most of his day.
                //
                // Keys with rows rather than fixed lines in the generated file,
                // for the same reason the cursor is one: a value nobody can
                // change from the settings window is a value that gets edited
                // into the generated file by hand and lost on the next palette
                // switch.

                // kitty marks where each command starts and ends. That is what
                // makes jump-to-prompt work and what lets the scrollback pager
                // open at the right line rather than at the top.
                property bool shellIntegration: true

                // ⚠️ TWO LINES, ONE SWITCH. `allow_remote_control` without
                // `listen_on` gives remote control over kitty's own pty only,
                // which is not what anybody enables it for; `listen_on` without
                // the first is ignored outright. Two settings would offer a
                // combination that silently does nothing.
                property bool remoteControl: true

                // Off, and it stays off: an audible bell on a laptop in an
                // office is a decision somebody else has to live with.
                property bool audibleBell: false

                // Send the scrollback to a pager rather than scrolling it in
                // place. Uses less with the same options ~/.zshrc exports.
                property bool scrollbackPager: true
            }

            // The lock screen: a large clock, the date, a round avatar, and
            // nothing else until you touch a key. Each of those three can go.
            property JsonObject lock: JsonObject {
                property bool showDate: true
                property bool showAvatar: true

                // Whether the wallpaper is behind it.
                //
                // ⚠️⚠️ ON, AND IT USED TO BE OFF FOR NO REASON WORTH THE NAME.
                // The old comment here said "off is a plain dark surface, which
                // is what it was before this key existed" — that is inertia
                // written down as a decision. His reference for this screen
                // (2026-08-04, vorlage-sperrbildschirm.png) is explicit: a
                // BLURRED WALLPAPER, the date, a huge clock, the avatar in a
                // circle, the name, the password field. Measured on 10.08.2026:
                // the screen was a flat #150f0f across all six sample points,
                // standard deviation 2.8 — the picture his reference asks for
                // was simply not there.
                //
                // ⚠️ The lock screen is a SEPARATE PROCESS (BUCHHWIN_MODE=lock),
                // so it reads shell.json itself and does not learn anything from
                // the running shell. That is also why it is the one surface
                // where a mistake is not merely ugly.
                property bool wallpaper: true

                // How soft the picture behind it is. 0 is the sharp photograph.
                //
                // ⚠️ IT IS BLURRED IN QML, NOT BY THE COMPOSITOR, and that is
                // forced rather than chosen: the compositor's blur applies to LAYER
                // surfaces, and neither of these is one — the lock screen is an
                // ext-session-lock surface and the greeter runs before there is
                // a session at all. MultiEffect is the same tool the avatar mask
                // already uses in both files.
                property int wallpaperBlur: 48
            }

            // Google Drive as a folder, through rclone. His choice over
            // GNOME Online Accounts, which would have meant a second GTK
            // application to sign in with.
            //
            // ⚠️ THE NAME IS A SETTING BECAUSE rclone REMOTES ARE NAMED BY
            // WHOEVER MADE THEM. "gdrive" is only this project's suggestion;
            // somebody who already had a remote called "work" would otherwise
            // have a switch pointing at nothing, with no way to say so.
            property JsonObject drive: JsonObject {
                property string remote: "gdrive"
                // `~` is expanded by the service — a literal tilde in a path is
                // a directory called "~" in your home, which is a mistake that
                // takes an afternoon to notice.
                property string mountPoint: "~/Drive"
            }

            // The terminal greeting.
            //
            // ⚠️⚠️ THIS BLOCK HELD FOUR KEYS AND NOW HOLDS ONE. `spin`, `fps`
            // and `stopAfter` described an animation that no longer exists — he
            // asked for the spinning logo on 10.08.2026 and asked for it back
            // out the same day. A key whose reader has been deleted is exactly
            // the debt rule 5 is about: it stays visible in the settings, it
            // can still be changed, and nothing on the machine cares. Deleted
            // rather than left "for later".
            //
            // ⚠️ AND THEIR ROWS WENT WITH THEM. tests/setting-rows.sh checks
            // both directions — a key with no row AND a row with no key — so
            // taking one side out and not the other is caught rather than
            // shipped.
            property JsonObject fetch: JsonObject {
                // Whether a new interactive terminal greets you. Read by
                // dotfiles/zsh/zshrc, which greps this file directly — there is
                // no shell running when a terminal starts, so there is nothing
                // to ask.
                //
                // ⚠️⚠️ B79 · OFF BY DEFAULT, on his request: "akutell startet ja   // english-ok: the request, quoted
                // fastfetch wenn man kitty aufmacht das bitte raus nehmen das     // english-ok: the request, quoted
                // fastfetch nicht startet". The greeting stays available as `ff`  // english-ok: the request, quoted
                // and the switch stays on the Programs page — what changed is
                // which way it points when nobody has said.
                //
                // ⚠️ AND A DEFAULT CHANGE DOES NOT REACH AN EXISTING MACHINE, by
                // rule 12: a `shell.json` that already carries this key is left
                // alone, deliberately, on every installer run. So this takes
                // effect on a fresh install and on "Reset everything"; a machine
                // that already has it on turns it off with the switch. Saying so
                // here rather than letting the next round wonder why the default
                // "did not work".
                // ⚠️ A PICTURE INSTEAD OF THE BUILT-IN MARK, taken from the
                // dwl session (DECISIONS #12). Empty means Fedora's own logo,
                // which is what ships.
                //
                // ⚠️ THE SETTING, NOT dwl'S STATIC fastfetch.jsonc. That session
                // keeps a hand-written config file and a script that edits it;
                // this one GENERATES the whole config in tools/render.qml on
                // every palette change, so a checked-in file would be overwritten
                // on the next render and a script that edited it would be
                // fighting the generator. One value in shell.json, read by the
                // generator, is the same feature without the argument.
                property string fetchImage: ""
                property bool onNewTerminal: false
            }

            // ⚠️ NONE OF THIS EXISTED, on a laptop. No idle, no automatic lock,
            // no suspend, no lid behaviour: the machine sat awake and unlocked
            // until the battery ran out. The brief is "eine Energieseite in den   english-ok: quoted brief
            // Settings wo man automatische Lockzeit, Sperrzeit etc. einstellen    english-ok: quoted brief
            // kann, du checkst wie bei Windows".                                  english-ok: quoted brief
            //
            // ⚠️ AND IT NEEDED NO NEW TECHNOLOGY, which was the opposite of what
            // the last session concluded. Quickshell 0.2.1 ships `IdleMonitor`
            // (Quickshell.Wayland, re-exported from _IdleNotify) with `timeout`,
            // `isIdle` and `respectInhibitors`; the compositor 26.04 implements
            // `ext_idle_notifier_v1`, and the lock screen has been here all
            // along. swayidle was never needed and is not installed.
            //
            // ⚠️ EVERY DELAY IS MINUTES FROM THE START OF IDLE, not from the
            // previous step. Three independent timers, the way Windows counts:
            // "screen off after 5, lock after 6" is two numbers, not one number
            // plus an offset that has to be re-derived every time either moves.
            // 0 means never, everywhere, and it means it consistently — a zero
            // timeout would otherwise fire instantly, which is the worst
            // possible reading of "off".
            property JsonObject power: JsonObject {
                // ⚠️ CHARGE THRESHOLDS, AND ZERO MEANS "LEAVE THE FIRMWARE
                // ALONE". A laptop kept at 100 % on a desk all day is a battery
                // being aged on purpose, and stopping the charge around 80 % is
                // the single biggest thing M10 can do for it — but plenty of
                // machines expose no thresholds at all, and writing a default
                // into firmware that never asked for one is the opposite of
                // careful. Both zero is therefore off, and the row says whether
                // this machine has them rather than showing a dead slider.
                //
                // ⚠️ NOT MEASURED ON HARDWARE. Neither the test VM nor the build host
                // has a battery — /sys/class/power_supply is EMPTY on the VM —
                // so the writing end of this is built and unproven. Said here
                // rather than in a changelog nobody reads.
                property int chargeStart: 0
                property int chargeEnd: 0

                // Battery first in each pair, because that is the one that
                // matters and the one people forget to set.
                property int screenOffBattery: 5
                property int screenOffAc: 15

                // ⚠️ Locking later than the screen goes off is deliberate. They
                // are separate because a screen that blanks is not a screen you
                // have walked away from — a minute of grace turns "I looked away
                // to read something" into a keypress rather than a password.
                property int lockBattery: 6
                property int lockAc: 20

                property int suspendBattery: 20
                // Never, on mains: a machine that is plugged in is usually
                // plugged in because something should keep running.
                property int suspendAc: 0

                // ⚠️ THESE THREE ARE logind's OWN WORDS, not ours. They are
                // written verbatim into /etc/systemd/logind.conf.d/ by
                // `bhctl power apply`, so inventing friendlier names here would
                // mean a translation table that can drift. "lock" is a real
                // HandleLidSwitch value; systemd 259 on this machine.
                property string lidClosedBattery: "suspend"
                property string lidClosedAc: "suspend"

                // balanced | performance | power-saver — exactly the three
                // tuned-ppd offers on this machine over
                // net.hadess.PowerProfiles. Measured rather than assumed, and
                // polkit's allow_active is `yes`, so the shell may switch it
                // without a prompt while its session is the active one.
                property string profile: "balanced"

                // ⚠️ THE TWO THRESHOLDS
                // and nothing ever read. Power.qml hard-coded 15 and 5, so the
                // documented numbers and the real ones agreed by luck.
                property int warnAt: 15
                property int criticalAt: 5

                // Half brightness shortly before the screen goes off, restored
                // the moment anything happens. It is the difference between a
                // screen that dies without warning and one that tells you it is
                // about to.
                property bool dimBeforeOff: true
            }

            property JsonObject look: JsonObject {
                // ⚠️ ONE NUMBER FOR THE SIZE OF EVERYTHING. The reference
                // measurements in this file come from a 1920-wide screen; on a
                // 1280 one the same pixels are half again as much of the
                // display, and it reads as "everything is a bit too big by
                // default". Rather than a second set of numbers, this scales
                // the font sizes and the 4 px grid together — 0.9 is a notch
                // smaller everywhere, 1.1 a notch larger, and everything stays
                // in proportion because it all derives from these two.
                //
                // It does NOT touch the notch's own geometry: those are exact
                // measurements from the reference screenshot and have their own
                // keys, so shrinking the interface must not silently change the
                // shape that was specified.
                property real uiScale: 1.0
                property int rounding: 16          // every radius derives from this
                property int borderWidth: 0        // 0: no window borders anywhere
                // The same question for OUR surfaces — the quick panel, the
                // launcher, the toasts. 0 is the default and the brief:
                // "ich will das die ohne umrandung sind wie die fenster dort  english-ok: quoted brief
                // auch sowas nicht, aber in den settings später soll man       english-ok: quoted brief
                // optional einen rand einstellen können". The window rule above english-ok: quoted brief
                // is off, so the panes match the windows.
                //
                // ⚠️ It has a reader NOW, in ui/common/GlassPane.qml, rather
                // than waiting for the settings window to give it one. A key
                // nothing reads is the fault this project has found five times;
                // M8 adds the row, not the meaning.
                property int panelBorderWidth: 0
                property int gapsIn: 8
                // Windows should read as separate objects lying on the
                // wallpaper, not as panes butted against the screen edge —
                // "bubbles", in the words of the brief. That is this number
                // plus `rounding` plus `shadows`, and it is the one of the
                // three you actually feel.
                property int gapsOut: 16
                // ⚠️ 1.0 AND 1.0, AND THIS IS THE SECOND ATTEMPT AT ONE
                // INSTRUCTION. The brief was "Transparenz raus — überall außer   // english-ok: quoted brief
                // im Terminal", and migration 10 → 11 lifted `opacityPanel` and  // english-ok: quoted brief
                // `opacityApp`. Those are OUR panels and GTK's own background.
                // The two keys that make a WINDOW see-through are these, and they
                // were left at 0.95 and 0.90 — so VS Code and the browser stayed
                // exactly as transparent as before and he had to say it twice.
                //
                // They were "chosen deliberately: enough to see the blur behind a
                // window and not enough to grey the text out". That reasoning was
                // fine and it is not the point; he does not want it. Compositor
                // opacity also fades the TEXT, which is the honest argument
                // against it and the reason the terminal uses its own key.
                property real opacityActive: 1.0
                property real opacityInactive: 1.0
                // Translucency the blur sits behind. Lower than it looks like it
                // should be: a panel is read, not looked through, so this is the
                // one place where legibility outranks the effect — but at 0.88
                // the blur behind it was being computed and then covered, the
                // same waste as the terminal at 0.90.
                // ⚠️ 1.0, NOT 0.78 — HIS DECISION, AND IT ALSO EXPLAINS THE
                // "STRANGE GRADIENT". He reported two things that turned out to
                // be one: every menu has "a strange gradient and is not clean",
                // and "take the transparency out everywhere except the
                // terminal". Seen on a screenshot from his laptop: the settings
                // window is see-through, and the wallpaper behind it is not
                // uniform — so the panel picked up the picture's gradient. It
                // was never a gradient in the theme.
                //
                // The terminal keeps its own (`opacityTerminal` below), and
                // that is a different mechanism: kitty's own background_opacity
                // rather than compositor opacity, which is why the text stays
                // sharp there and would not here.
                property real opacityPanel: 1.0

                // ⚠️ WHAT OUR OWN SURFACES ARE MADE OF — his request on
                // 10.08.2026, and `black` is the default he asked for.
                //
                //   "black"   the notch, the quick settings, the settings
                //             window, the launcher and the toasts are
                //             plain black and fully opaque
                //   "scheme"  they take their tint from the palette and stay
                //             slightly see-through, which is how it was before
                //
                // ⚠️ APPLICATIONS ARE NEVER AFFECTED, and that is structural
                // rather than a promise: foreign themes come out of
                // tools/render.qml, which reads the PALETTE and never reads
                // theme/Theme.qml. kitty, GTK, Qt, VS Code and the rest keep
                // their colours either way. He asked for exactly that boundary
                // — applications are explicitly outside the switch.
                //
                // ⚠️ AND BLACK IS THE BACKGROUND, NOT EVERY SURFACE. Theme.qml
                // keeps the elevation ladder in black mode (#000 → #0f0f0f →
                // #1a1a1a → #262626), because a sweep on the same day found
                // eight places where an element already had exactly its
                // parent's colour and was therefore invisible. Flattening
                // everything onto one black would be shipping that on purpose.
                //
                // ⚠️ An unknown value falls back to "black" rather than to
                // nothing — the same direction the theming states fall in, for
                // the same reason: a typo must not remove the desktop's colour
                // scheme AND its opacity at once.
                property string surfaceStyle: "black"
                // The background of GTK applications, written into their own
                // CSS rather than applied by the compositor.
                //
                // ⚠️ NOT `opacityActive`. Compositor opacity fades the TEXT with
                // the background — the same reason the terminal uses kitty's own
                // `background_opacity`. This is the file manager on the
                // reference screenshot: near-black with the wallpaper showing
                // through, and the file names still sharp.
                //
                // ⚠️ It only shows where the compositor also blurs behind the
                // window; see `windows.blurred`. Without that, a translucent
                // window is a window with the raw wallpaper behind it, which is
                // worse than an opaque one.
                // 1.0 for the same reason as opacityPanel — see there. This is
                // the one for foreign windows (the file manager), and compositor
                // opacity fades their TEXT along with the background, which is
                // exactly the "not clean" he means.
                property real opacityApp: 1.0
                // The terminal's own background, through kitty rather than
                // through the compositor — see tools/render.qml for why.
                //
                // ⚠️ This is the single biggest lever on the glass look, bigger
                // than any blur setting: blur is only visible where the window
                // is see-through, so at 0.90 there was nothing to see and every
                // blur pass behind it was paid for and wasted. Measured against
                // the reference screenshot, which is open enough to read the
                // wallpaper through the terminal while the text stays sharp —
                // that last part is why this lives in kitty's own
                // background_opacity and not in compositor opacity, which would
                // fade the glyphs out with it.
                property real opacityTerminal: 0.62
                property bool blur: true
                // The most expensive number in the whole desktop: every pass is
                // another full-screen GPU read on every frame. It gets a key of
                // its own rather than being buried in the generator, because it
                // is the first thing to turn down on a slow machine.
                property int blurPasses: 3
                // ⚠️ The FREE one, and therefore the one to reach for first.
                // the compositor's own words: "Larger values produce a smoother blur, at
                // no additional GPU cost", and "try increasing offset first
                // until you start getting artifacts. Then, if you still need
                // smoother blur, increase passes by 1." the compositor's default is 3.
                property real blurOffset: 5
                // Pixel noise over the blur. It exists to break up the colour
                // banding that a wide blur produces on a gradient — which is
                // exactly what a sunset wallpaper is. the compositor's default is 0.02.
                property real blurNoise: 0.03
                // Saturation of what shows through: 0 is grey, 1 is untouched,
                // 2 is doubled. This is the difference between glass and frosted
                // plastic — blur alone washes the colour out, and the reference
                // screenshots are anything but washed out. the compositor's default is 1.5.
                //
                // ⚠️ 1.8 was too much, and it took the corner bug to show it.
                // Measured with the quick panel open over a warm wallpaper: where
                // the blur came through unattenuated it read rgb(144,46,6),
                // r−b = +138, against +81 for the same wallpaper unblurred — the
                // "glass" was more colourful than the thing behind it. With the
                // corners fixed that only shows THROUGH the pane, but the pane is
                // 0.78 opaque, so the tint is still there and still overdone.
                // 1.2 keeps the colour without the neon. His call, and it stays a
                // key: the settings window makes it a slider.
                property real blurSaturation: 1.2
                // The lit edge on our own surfaces — rim and sheen, no shader.
                // See the glass tokens in theme/Theme.qml for why it is drawn
                // this way and not as refraction.
                property bool glass: true
                property bool shadows: true
                // A shadow you notice as depth rather than as a shadow. These
                // are the compositor's own numbers (CSS box-shadow semantics): softness
                // is the blur radius, spread grows the rectangle, offset moves
                // it down. Generous and soft, as in the reference screenshots —
                // and the same three values apply to windows AND to our own
                // surfaces, so nothing floats differently from anything else.
                //
                // ⚠️ 40/3/8 AND NOT 28/2/6, and the reason is a measurement
                // rather than taste. "Windows have no shadow" was reported and
                // then chased for two rounds as a broken config — it was not.
                // With the shadow switched off and on again at the same window
                // position, the wallpaper right of the edge differs by up to
                // 192 (sum of R+G+B) and fades to nothing over exactly 30 px:
                // the shadow was always being drawn, it was just too small and
                // too pale to read as one. He asked for the opposite in so many
                // words, and his words are the specification:
                // "ein weicher, klar sichtbarer Schatten,   // english-ok: his own words, quoted
                //  deutlich präsenter als eine bloße Andeutung"  // english-ok: his own words, quoted
                property int shadowSoftness: 40
                property int shadowSpread: 3
                property int shadowOffsetY: 8
                // How opaque the shadow is, 0…1. The one number that decides
                // whether it reads as depth or as nothing at all, which is why
                // it is a key and not a constant in the renderer.
                //
                // ⚠️ It is deliberately NOT the alpha of a palette colour: on a
                // light palette the shadow is not the palette's darkest tone at
                // all, it is black — see tools/render.qml.
                property real shadowOpacity: 0.85
                // Whether the compositor draws the shadow BEHIND the window as well as
                // around it.
                //
                // ⚠️ false, and it is a measurement rather than a preference.
                // the compositor's reason for the other setting is real — without it a
                // client's own rounded corners can show square shadow
                // artefacts — but it costs everything the translucency buys:
                // the shadow shows THROUGH an open window and darkens it.
                // Measured on Nautilus at opacityApp 0.80, same pixels:
                //
                //   inside the window   true (40,32,25)   false (66,50,35)
                //   beside the window   identical in both
                //
                // So the shadow around the window is unaffected and only the
                // show-through changes. Our window rule already sets
                // `clip-to-geometry true` with a corner radius, so the compositor does
                // know the shape and the artefact it guards against does not
                // arise. Anyone running fully opaque windows can set it back.
                // ⚠️ shadowBehindWindow WAS HERE AND HAS NO EQUIVALENT.
                // It came from a compositor that could choose whether to draw a
                // shadow under an opaque window. Hyprland always does, and its
                // decoration.shadow block has no key for it.
                property string fontUi: "Inter"
                property string fontMono: "JetBrainsMono Nerd Font"
                // ⚠️ "Material Symbols Rounded" is NOT what Fedora ships.
                // material-icons-fonts provides the older "Material Icons Round";
                // fc-match resolves the Symbols name to Noto Sans, so every icon
                // silently renders as a fallback glyph or as tofu. Measured, not
                // assumed — the gear only appeared because U+2699 happens to
                // exist in Noto Sans.
                property string fontIcon: "Material Icons Round"
                property int fontSize: 11          // pt
                // full | minimal — minimal turns motion and effects off wholesale
                property string profile: "full"
            }

            // Every surface can be switched off on its own, and limited to
            // named monitors. An empty list means "all screens".
            property JsonObject surfaces: JsonObject {
                property bool notifications: true
                property bool osd: true
                // The wallpaper is drawn by the shell rather than by a second
                // daemon, so it is a surface like any other and switches off
                // like any other — leaving whatever is behind it, which is the
                // compositor's own background.
                property bool wallpaper: true

                // Hot corners: "off", "left", "right" or "both".
                //
                // ⚠️ "right" IS THE DEFAULT, NOT "both", and that is not
                // caution — the compositor already owns the top-LEFT corner and has it
                // switched on. Its own docs (Configuration: Gestures.md) say
                // "Put your mouse at the very top-left corner of a monitor to
                // toggle the overview". Claiming that corner as well would give
                // one gesture two meanings, and the one you wanted would be the
                // other one.
                //
                // Choosing "left" or "both" is therefore also a decision to turn
                // the compositor's off, and the generator says so rather than letting the
                // two fight.
                // It shipped as "off" for a round because the corner was
                // believed to draw nothing and answer nothing. It did both; the
                // measurement that said otherwise was the broken part, and what
                // was actually wrong is written down in HotCorner.qml.
                property string hotCorners: "right"
                // How long the pointer has to REST there. A corner that fires on
                // contact is a trap: you reach for a window's close button, you
                // cross the corner, and a panel lands on what you were aiming
                // at. It is a key because how long feels right is not something
                // anyone can decide for somebody else.
                property int hotCornerDwellMs: 250

                // ⚠️ A ROUNDED SCREEN CORNER IS OURS TO DRAW — the compositor has
                // `geometry-corner-radius` for windows and for layer surfaces
                // and nothing at all for the output, asked in its own wiki
                // rather than assumed. Four surfaces of this many pixels each,
                // input passing straight through them.
                //
                // 0 switches them off entirely and creates no surfaces, which
                // is the right default for a desktop nobody has asked for them
                // on — but he did ask, with a picture, so it ships on and
                // gently: "ganz leicht" were his words.
                property int screenCornerRadius: 12
            }

            // How arriving notifications behave on screen. They are their own
            // surface in the top-right corner, NOT a page of the notch: the
            // notch is where you go to look at something, and a message that
            // arrives on its own has not been asked for. Making it take over
            // the notch meant every notification interrupted whatever the notch
            // was showing and then vanished after 1.6 s, whether it had been
            // read or not.
            property JsonObject notifications: JsonObject {
                // ⚠️ IT PERSISTS, on purpose. "Do not disturb" that forgets
                // itself at the next login is a switch you have to remember to
                // press again, which is the opposite of what it is for. It
                // silences the toasts only: everything still arrives and is
                // still in the list on Mod+N, and critical messages still come
                // through — the urgency level exists to say "this one anyway".
                property bool dnd: false

                // ⚠️⚠️ WHERE THEY APPEAR IS A SETTING NOW, and it was hard-wired
                // to the top right until he asked where they should be at all:
                // "kannst du mir ideen vorschlagen wo das am besten wäre also    // english-ok: the request, quoted
                // oben rechts oder in der notch oder was sagst du?".             // english-ok: the request, quoted
                //
                // The answer to the question he asked is that they were already
                // top right, and the notch was tried once and measured as wrong:
                // a message opened it on its notifications page and closed it
                // 1.6 s later, so whatever was open got interrupted and the
                // message was gone before it could be acted on. The notch is
                // where you GO; a message arrives unasked and must not take the
                // place over.
                //
                // What was genuinely missing is rule 6: the corner had no key.
                // "topRight" | "topLeft" | "bottomRight" | "bottomLeft".
                property string corner: "topRight"
                // How long an ordinary toast stays. Senders may ask for their
                // own duration via `expireTimeout`, and that is honoured; this
                // is the answer when they do not.
                property int timeoutMs: 5000
                // ⚠️ Critical notifications never time out on their own. That
                // is the whole meaning of the urgency level, and a disk-full
                // warning that disappears while you are in another window is
                // worse than none.
                property int maxVisible: 3
                // ⚠️ Empty means every screen — which on two monitors means the
                // same message twice, once in each top-right corner. That is
                // the honest default (a message must not land on a screen you
                // are not looking at) but it is worth naming one output here
                // once a second monitor is in play.
                property list<string> monitors: []
            }

            // Off by default: the notch IS the surface. That is a design
            // decision, not an oversight — so every function the bar would have
            // carried needs a key and an ipc verb as well, or it is unreachable.
            property JsonObject bar: JsonObject {
                property bool enabled: false
                property int height: 34
                property list<string> monitors: []
            }

            // ⚠️ `collapsedWidth` is the width AT THE SCREEN EDGE — the widest
            // point of the shape, not the width of the pill's body. The
            // shoulders flare outwards towards the edge, so the body measures
            // `collapsedWidth - 2 * flare`. That is what keeps the layer surface
            // exactly as big as what is painted on it: the compositor blurs and shadows
            // the whole surface, invisible margins included, and a shape that
            // reached past its own window was the coloured halo around the pill.
            // ⚠️⚠️ THE QUICK PANEL HAS TWO LEVELS NOW, on his instruction: "was
            // noch nicht gut ist das im quickpanel alles unübersichtlich und    // english-ok: the report, quoted
            // zu viel ist also im dashboard das muss man anders machen".        // english-ok: the report, quoted
            //
            // Ten tiles, a drawer and three sliders were on one surface. Put to
            // him as a choice, he picked the same shape he had already chosen
            // for the settings window: the four he reaches for stay out, the
            // rest fold away behind "Show more".
            //
            // ⚠️ IT IS A SETTING RATHER THAN PANEL STATE, because rule 6 says so
            // and because the alternative is worse: state that resets every time
            // the panel is rebuilt means a man who wants all ten opens the fold
            // ten times a day.
            //
            // ⚠️ SHUT BY DEFAULT — that is the whole point of the change.
            property JsonObject quick: JsonObject {
                property bool showMore: false
            }

            property JsonObject notch: JsonObject {
                // ⚠️ THE SHAPE OF THE THING AT THE TOP, his request: a notch or a
                // pill, switchable.
                //
                //   "notch"  it hangs from the top edge — square shoulders up
                //            there, rounded corners underneath, the way a
                //            hardware notch is cut out of a screen
                //   "pill"   it floats below the edge, rounded all round, with a
                //            gap of its own above it
                //
                // ⚠️ IT IS A SHAPE, NOT A SECOND SURFACE. Both are the same
                // PanelWindow at the same size with the same contents; what
                // changes is the top corners and the gap. Building two would be
                // two things to keep in step, which is the rule this project
                // spends most of its comments on.
                property string shape: "notch"
                property bool enabled: true
                property int flare: 7             // the concave shoulder radius
                property int collapsedWidth: 150
                // Its own key on purpose. This used to borrow `bar.height`,
                // which meant the notch changed size when a bar that was
                // switched off was resized.
                property int collapsedHeight: 34
                property int cornerRadius: 9      // the two rounded corners below
                // What the notch grows to while the pointer is on it: media on
                // the left, clock and date in the middle, a status pill on the
                // right. Both numbers are measured off the reference screenshot
                // (shots/2026-08-06/vorlage-notch-ausgefahren.png): the pill
                // there is 359 x 68 in a 1318-wide capture, which is 523 x 99 at
                // 1920. Rounded onto the 4 px grid.
                //
                // ⚠️ The width is a FLOOR, not the width. Nothing is shown that
                // does not exist — no music means no media block — so the shape
                // follows what is actually in it and this stops it looking empty
                // when there is little to say.
                property int hoverHeight: 96
                property int hoverMinWidth: 520
                // ⚠️ Its own radius, because a corner is a PROPORTION of the
                // shape and this shape is three times as tall. 9 on a 34 px pill
                // is 26 % of its height, which is the ratio the reference was
                // measured at; 9 on a 96 px pill is 9 % and looks like a box.
                // 24 keeps the same proportion. It is a key rather than a
                // multiplication so the settings window can show both numbers.
                property int hoverCornerRadius: 24
                // ⚠️ `expandedHeight` IS GONE, and removing it is the honest
                // answer rather than giving it a reader back. It was a MINIMUM
                // applied to every page, and commit 9bec5fa deleted that on
                // purpose — it was the second half of his report about the
                // spacing: a page shorter than 135 got the difference split
                // above and below it as dead space, measured at media 161→138,
                // tray 161→138, calculator 161→120.
                //
                // After that only ui/notch/pages/WallpaperPage.qml still used
                // it, to size its covers — and commit 3added8 turned that page
                // into a grid whose cells come from the column count. So the
                // key had no reader at all, which tests/key-readers.sh found.
                //
                // Restoring a reader would mean re-introducing the dead space
                // that was measured away. Pages are as tall as what is on them.
                property int minExpandedWidth: 619

                // ⚠️ THE ONE SURFACE THAT DOES NOT DEFAULT TO EVERY SCREEN, and
                // the reason is measured rather than aesthetic. On his
                // three-monitor desk the notch is a READOUT: three clocks,
                // three battery pills and three copies of the same media title
                // say nothing the first one did not. Each is a real Wayland
                // layer surface that repaints, and one of the two machines this
                // has to run on is a 2018 Intel iGPU.
                //
                // Asked directly, he agreed — and added the argument that
                // settles it: "es gibt für fast alles eh hotkey", so reaching   // english-ok: his words, quoted
                // it is not what the extra copies were buying.
                //
                // ⚠️ `@primary` RATHER THAN A CONNECTOR NAME. A default may not
                // name a monitor: DP-2 is right on exactly one desk and wrong
                // everywhere else. ui/Shell.qml resolves it against the entry
                // marked `primary` in `outputs`, falling back to the first
                // screen the compositor reports. Put a connector name here instead and it
                // simply wins — the list is still a plain list of names.
                //
                // ⚠️ AND THE PAGES DO NOT FOLLOW IT. The quick panel opens where
                // you are, not where the clock is; see `overlayHere` in
                // ui/Shell.qml. Those are two different questions and this key
                // only answers the first.
                property list<string> monitors: ["@primary"]
            }




            // ---------------------------------------------------------------
            // Programs the key bindings point at.
            //
            // ARGUMENT LISTS, not command lines — see Config.program(). A key
            // refers to one of these as "@terminal", so changing your terminal
            // is one edit here instead of a hunt through the bindings.
            property JsonObject programs: JsonObject {
                property list<string> terminal: ["kitty"]
                // ⚠️ THE FLAG IS HERE BECAUSE Mod+B DOES NOT USE THE .desktop
                // FILE. tools/hypr.qml writes an override into
                // ~/.local/share/applications with --ozone-platform=wayland, and
                // that override is real — measured: the launcher resolves Brave
                // to "/usr/bin/brave-browser-stable --ozone-platform=wayland".
                // But `spawn "brave-browser"` runs the binary directly and never
                // reads a desktop file, so the key and the launcher were
                // starting two different browsers. The slow one was the key.
                //
                // ⚠️ AND ~/.config/brave-flags.conf DOES NOTHING AT ALL. That
                // convention is Arch's; Fedora's /opt/brave.com/brave/brave-browser
                // is a bash wrapper with zero occurrences of "flags.conf",
                // checked with grep. The file had been sitting there being
                // believed in — lib/60-shell.sh stopped writing it on
                // 10.08.2026 and removes the leftover on the next run.
                property list<string> browser: ["brave-browser", "--ozone-platform=wayland"]
                property list<string> fileManager: ["dolphin"]
                // ⚠️ THE SAME FLAG AS THE BROWSER, AND FOR THE SAME REASON.
                // A keybinding runs the binary directly and never reads a
                // desktop file, so the .desktop override next door does not
                // cover Mod+E. Without it the key and the launcher would start
                // two different editors, which is precisely the split that was
                // found and fixed for Brave.
                property list<string> editor: ["kate"]
                property list<string> imageViewer: ["gwenview"]
                property list<string> video: ["vlc"]
                // ⚠️ NO `launcher` KEY. There was one, empty, waiting for M6 to
                // fill it with the name of some other program. M6 built the
                // launcher instead, so the key would now point at a second one
                // that nothing starts — and a setting nothing reads is the
                // fault this project has removed four times. The launcher is
                // opened by `ipc call launcher toggle`, like every other
                // surface the shell owns.
            }

            // ---------------------------------------------------------------
            // Key bindings. Written to generated/binds.lua, never handled by the shell:
            // The compositor has no protocol for shell-owned shortcuts, and keys that
            // live in the compositor keep working when the shell is dead.
            //
            // Each entry: { key, action, arg, desc } plus optional
            // allowWhenLocked / repeat / cooldownMs.
            //   action "spawn"     → arg is a program ref ("@terminal") or a
            //                        bare command name
            //   action "spawn-sh"  → arg is a shell line (pipes, $VARS)
            //   anything else      → a compositor action, verbatim; arg is its
            //                        argument if it takes one
            property JsonObject keys: JsonObject {
                property string mod: "Super"

            }

            // ---------------------------------------------------------------
            property JsonObject input: JsonObject {
                property JsonObject keyboard: JsonObject {
                    property string layout: "de"
                    property string variant: ""
                    property string options: ""
                    property int repeatDelay: 400   // snappier than the compositor's 600
                    property int repeatRate: 40
                }
                // ⚠️ libinput flags do not accept `false` — `natural-scroll false`
                // is a hard parse error, unlike most other the compositor flags. The
                // generator must OMIT a false flag, never write it out.
                property JsonObject touchpad: JsonObject {
                    property bool tap: true
                    property bool dwt: true             // disable while typing
                    property bool naturalScroll: true
                    property bool middleEmulation: true
                    // ⚠️ accelSpeed, accelProfile AND scrollMethod WERE HERE
                    // AND COULD NOT WORK. Hyprland configures pointer
                    // acceleration and scroll method GLOBALLY — input.sensitivity,
                    // input.accel_profile, input.scroll_method — with per-device
                    // overrides addressed by device NAME, which nothing knows at
                    // generation time. Its input.touchpad block has no such keys;
                    // checked against /usr/share/hypr/stubs/hl.meta.lua rather
                    // than assumed.
                    //
                    // The mouse block already writes the globals. Leaving three
                    // touchpad rows that write into shell.json and reach nothing
                    // is the exact fault this project keeps finding: a control
                    // that looks like it works. scroll_factor below DOES apply
                    // per touchpad, which is why it stayed.

                    // ⚠️ THE SCHEMA HAD naturalScroll, accelSpeed AND
                    // scrollMethod BUT NO SPEED, so "scrolling is too fast" had
                    // no answer anywhere in the settings. The compositor can do it, per
                    // device, and it was probed on the compositor 26.04 with a control: a
                    // `scroll-factor` in this block validates, an invented key
                    // in the same block is rejected as an unexpected node — so
                    // the block really is parsed and this is not a name being
                    // quietly swallowed.
                    //
                    // 1.0 is the compositor's own default, so the generator writes it
                    // always rather than conditionally; there is no "off" for a
                    // multiplier.
                    property real scrollFactor: 1.0
                    property string clickMethod: "clickfinger"
                }
                property JsonObject mouse: JsonObject {
                    property bool naturalScroll: false
                    property real accelSpeed: 0.0
                    property string accelProfile: "flat"

                    // The same knob for the mouse. Separate from the touchpad's
                    // on purpose: a wheel notch and two fingers on glass are not
                    // the same gesture and almost never want the same number.
                    property real scrollFactor: 1.0
                }
                // ⚠️⚠️ ON BY DEFAULT ON HIS INSTRUCTION, and it is the fix for a
                // report that sounded like a shell bug and is not one.
                //
                // "wenn ich links und rechts einen monitor habe und ich habe     // english-ok: the report, quoted
                // rechts den browser … jetzt gehe ich mit der maus auf den       // english-ok: the report, quoted
                // linken bildschirm ohne zu klicken und mach super d fürs        // english-ok: the report, quoted
                // launcher, das öffnet er aufn rechten bildschirm … das die      // english-ok: the report, quoted
                // maus der punkt ist und dort das neue passiert".                // english-ok: the report, quoted
                //
                // Our surfaces open on `Compositor.activeOutput`, which comes
                // from the FOCUSED workspace. Moving the pointer without
                // clicking does not move focus, so the launcher was right about
                // the focus and wrong about him. the compositor's own wiki says this knob
                // "focuses windows AND OUTPUTS automatically when moving the
                // mouse over them" — so with it on, the value we already read
                // follows the pointer and every surface lands where he is
                // looking. No pointer tracking of our own.
                //
                // ⚠️ IT ALSO FOCUSES WINDOWS, not only outputs, and that is a
                // real change of feel rather than a free win: the keyboard goes
                // where the pointer rests. It is a setting for exactly that
                // reason — Windows & Behaviour has the row.
                //
                // ⚠️ WHETHER A CHANGED DEFAULT REACHES AN EXISTING MACHINE
                // DEPENDS ON WHETHER THE KEY IS IN THE FILE, and it was worth
                // checking rather than assuming: on a real installed machine
                // `focusFollowsMouse` is ABSENT from shell.json, so the default
                // applies and an update carries it. If a file does carry the old
                // `false`, Vorgabe 12 keeps it — and then the switch in Windows &
                // Behaviour is the way, not the update.
                //
                // ⚠️ THE MEASUREMENT THAT STOOD HERE WAS THE PREVIOUS
                // COMPOSITOR'S. It said `focus-follows-mouse` appears 0 times in
                // the generated config.kdl when this is forced false and 1 time
                // when forced true. This generator writes neither that key nor
                // that file: tools/hypr/EmitSettings.qml emits `follow_mouse`
                // into generated/settings.lua as 0 or 1, so the key is always
                // there and it is the VALUE that moves. A control nobody can
                // re-run is a claim wearing a measurement's clothes.
                property bool focusFollowsMouse: true
                property bool warpMouseToFocus: false
            }

            // ---------------------------------------------------------------
            property JsonObject windows: JsonObject {
                // No client-side decorations where a client will listen.
                property bool noCsd: true
                // Programs that must never be recorded or streamed.
                property list<string> blockFromScreencast: []
                // Windows that get the wallpaper blurred behind them.
                //
                // ⚠️ Blur is only VISIBLE where the window is translucent —
                // an opaque window covers it completely. The terminal is here
                // because look.opacityTerminal makes it see-through; adding an
                // opaque application would cost the GPU work and show nothing.
                //
                // The compositor turns on "xray" automatically alongside blur, which
                // blurs the wallpaper ONCE and reuses it for every window
                // instead of recomputing per window per frame. That is the
                // cheap path and the reason this is affordable on a laptop.
                //
                // ⚠️ Nautilus is here because `look.opacityApp` opens every GTK
                // window's background — without a blur behind it you get raw
                // wallpaper through a file list, which is worse than opaque.
                // The two settings belong together and neither is worth having
                // alone.
                property list<string> blurred: ["kitty", "org.kde.dolphin"]
                // app-ids that should open floating.
                property list<string> floating: []

                // How wide a new window opens, as a fraction of the screen.
                //
                // ⚠️⚠️ 1.0 RATHER THAN the compositor's OWN DEFAULT, and that is his
                // report rather than a preference of mine: "wenn man ein         // english-ok: his report, quoted
                // terminal öffent oder genrell eine app soll die fullscrenn      // english-ok: his report, quoted
                // sein und nicht halb vom screen wie jetzt". The compositor opens new      // english-ok: his report, quoted
                // windows at HALF the output and this project never said
                // otherwise — `default-column-width` did not appear in the
                // generator at all, so the compositor's default applied and looked like a
                // decision somebody had made.
                //
                // ⚠️ IT IS A COLUMN WIDTH, NOT FULLSCREEN, and the difference is
                // the point: the window fills the working area and keeps the
                // bar, the gaps and its border. Real fullscreen is Mod+Shift+F
                // and draws a black backdrop over everything.
                //
                // ⚠️ 0 MEANS "the window decides", which is the compositor's other mode —
                // `default-column-width {}` with nothing inside it. A dialog
                // that knows it wants to be small then gets to be small.
                // ⚠️ defaultWidth WAS HERE AND SAID THE SAME THING TWICE.
                // It set the fraction of the screen a new window takes, which
                // in Hyprland's master layout is master.mfact — already driven
                // by the layout settings. Two keys for one number is the drift
                // this project has a rule against, and the one that reaches the
                // compositor is the one that stayed.
            }

            // Empty = let the compositor decide. Filled in per machine; the VM and the
            // laptop are not the same and this file is not shared between them.
            // ⚠️ TOP LEVEL, AND THAT IS THE WHOLE FIX FOR THE STARTUP CRASH.
            //
            // It used to be `keys.binds`, and quickshell segfaulted on about
            // half of all starts because of exactly that nesting. Measured on
            // the machine, twelve runs each:
            //
            //   {"outputs":[ …objects… ]}          var, TOP LEVEL    0/12
            //   {"keys":{"binds":[ …objects… ]}}   var, NESTED       6/12
            //   {"keys":{"binds":[]}}              var, NESTED       6/12
            //   {"windows":{"blurred":["kitty"]}}  list<string>      0/12
            //   {}                                                   0/10
            //
            // An empty nested list is enough to do it, so it is not the length
            // and not the contents: JsonAdapter cannot write a `var` property
            // that lives inside a nested JsonObject. The backtrace says the same
            // thing — QObjectWrapper::wrap under QMetaProperty::write, with TWO
            // deserializeRec frames, which is what nesting looks like.
            //
            // These were the only two `var` properties in the whole adapter, and
            // now both are up here. Everything else is `list<string>` or
            // `list<int>`, which never crashed. If a third one is ever added, it
            // belongs here too — tests/config-shape.sh is the tripwire.
            //
            // ⚠️ THAT NAME WAS WRONG FOR MONTHS AND IT SAID `config-crash.sh`,
            // WHICH DOES NOT EXIST. A comment naming a guard that is not there
            // is worse than no comment: it is read, believed, and closes the
            // question. Anybody who checked would have found nothing and
            // concluded the rule was unguarded — which it never was.
            //
            // ⚠️ AND THE CRASH IT DESCRIBES IS NOT REPRODUCIBLE ANY MORE. On
            // quickshell 0.2.1 the same shape was rebuilt on purpose and started
            // 10 times out of 10 without falling over. The rule stays — it costs
            // nothing and the cause was upstream, so a later version can bring
            // it back — but "it must be here or it segfaults" is a claim that
            // now needs measuring again before it is used as an argument.
            //
            // ⚠️ Empty means "use Config.defaultBinds", not "no bindings".
            property var binds: []

            // Rebinding, as a list of `{ from, to }` — "the binding that ships
            // on `from` now lives on `to`", and `to: ""` unbinds it.
            //
            // ⚠️ TOP LEVEL FOR THE REASON WRITTEN ABOVE. It is the third `var`
            // in this adapter and it is up here with the other two; nested, it
            // would bring back the startup segfault, and an empty list is
            // enough to do that.
            //
            // ⚠️ AND IT IS AN OVERRIDE RATHER THAN A COPY OF `binds`. Writing
            // the whole resolved list to rebind one key is what froze 63
            // bindings on this machine once already — see the note beside
            // `Config.binds`.
            property var rebinds: []

            property var outputs: []


            // ⚠️⚠️ B75 · TOP LEVEL, AND THAT IS NOT TIDINESS — IT IS THE SEGFAULT.

            // This started life inside the `wallpaper` block, which is a NESTED

            // JsonObject, and quickshell died on every start that read a filled list:

            //

            //     QV4::QObjectWrapper::wrap

            //     QQmlVMEMetaObject::writeProperty

            //     qs::io::JsonAdapter::deserializeRec     <- twice: a substructure

            //     qs::io::FileViewAdapter::onDataChanged

            //

            // That is the same backtrace, frame for frame, as the `keys.binds` crash

            // this project spent its most expensive evening on. `outputs` above is a

            // `var` too and has never crashed — because it is UP HERE. ERFAHRUNG says

            // the fault was not reproducible on quickshell 0.2.1; it is, with a list

            // of objects rather than an empty one, and that note is now corrected.

            //

            // ⚠️ tests/config-shape.sh had been red about this line the whole time. It

            // was not run before deploying, which is the actual mistake here — a

            // guard that runs after the crash reports history.

            //

            // Empty means one picture everywhere (`wallpaper.current`); filled means

            // these assignments win, with `current` as the fallback for a screen that

            // is not named — a monitor plugged in later must show something.

            //

            //     [ { "name": "DP-1", "image": "file:///…/a.jpg" }, … ]

            property var wallpaperPerScreen: []

            // Extra programs for the session. NOT the shell and NOT the
            // clipboard watcher — those are systemd user units already, and
            // listing them here too would start a second copy of each.
            //
            // ⚠️ The polkit agent IS here, and it has to be. It ships an XDG
            // autostart file (/etc/xdg/autostart/), and the compositor does not process
            // those — so on this desktop nothing would ever start it and the
            // wifi radio switch would keep being refused. See
            // packages/dnf-desktop.txt for why a foreign program is here at all.
            //
            // ⚠️⚠️ IT IS FOUND, NOT NAMED, AND THAT IS THE FIX FOR A REAL FAULT.
            // The path used to be written out as
            // /usr/libexec/polkit-kde-authentication-agent-1. KDE Frameworks 6
            // moved it into a `kf6` subdirectory, and the two locations have
            // both been true on Fedora at different points — so a typed path is
            // right on one release and silently wrong on the next. Wrong how:
            // the agent does not start, nothing says so, and every action
            // needing authentication is refused with no prompt. That is the
            // worst shape of failure this project keeps finding, and it cannot
            // be spotted by reading the line.
            //
            // The shell picks whichever exists, in one short command that runs
            // once at session start. A machine with neither gets nothing
            // started, which is what it would have got anyway.
            property list<string> autostart: [
                // ⚠️ NO NESTED `sh -c`: `hl.exec_cmd` already runs what it is
                // given through a shell, so this is a shell command as it
                // stands. Wrapping it again would mean quoting quotes inside a
                // Lua string inside a QML string, which is three chances to get
                // one backslash wrong for no gain.
                "for a in /usr/libexec/kf6/polkit-kde-authentication-agent-1 /usr/libexec/polkit-kde-authentication-agent-1; do [ -x $a ] && exec $a; done"
            ]

            // ⚠️ WHAT WAS OPEN LAST TIME, and the honest limit belongs with the
            // key rather than only in the settings row: we can bring the
            // PROGRAMS back, not what was in them. Which file the editor had,
            // which tab the browser was on, how far anything was scrolled — only
            // the program knows that, and Brave and VS Code restore their own
            // while kitty does not. "The same programs on the same workspaces"
            // is the promise; "the same state" is not one we can keep.
            property JsonObject session: JsonObject {
                property bool restore: false
                // app-ids as the compositor reports them, which are the freedesktop entry
                // ids in nearly every case (kitty, org.gnome.Nautilus,
                // brave-browser). Maintained while you work rather than written
                // at shutdown: a list only written on the way out is missing
                // exactly when the machine went down without asking.
                property list<string> apps: []
            }

            property list<string> workspaces: ["scratch"]

            // The wallpaper, and the one key that makes it colour the desktop.
            //
            // There is no separate "derive" switch: `theme.palette` set to
            // "wallpaper" IS the switch, and a second key that means the same
            // thing is how a settings file starts to contradict itself. It
            // existed until version 1 and is removed by a migration.
            // Where this machine is — for EVERYTHING that needs a place, not
            // for the weather alone. Today: the weather; next: sunrise and
            // sunset for automatic light/dark, and gammastep's night light.
            //
            // COORDINATES, not a search term. A name is ambiguous, would need
            // resolving on every start, and resolving needs the network — so a
            // laptop opened in a tunnel would show nothing for a place it has
            // known for months.
            //
            // ⚠️ No timezone here. The system knows it, and a copy drifts.
            property JsonObject location: JsonObject {
                property string name: ""      // for display only

                // ⚠️⚠️ 0, NOT NaN, AND THE OLD DEFAULT COST TWO FILE WRITES ON
                // EVERY SETTINGS CHANGE. JSON has no NaN. `writeAdapter()` put
                // `null` in the file, `_migrate()` correctly read those nulls as
                // damage, deleted them, wrote the file A SECOND TIME, and listed
                // both keys in `nulledKeys` — so the settings window was told to
                // report damage that this file had just invented. Then the next
                // save started it again.
                //
                // Measured on 10.08.2026 against a file containing only
                // `{"version":14}`: sixteen "expected double but got
                // std::nullptr_t" warnings per run, thirty-one per boot in the
                // journal of the running shell, and `tests/smoke.sh` failing
                // with "no settings were nulled and scrubbed (location.lat,
                // location.lon)" the moment it was pointed at a file the shell
                // had written itself.
                //
                // ⚠️ NOTHING READS THESE AS A SENTINEL, which is why the change
                // is safe: services/Location.qml:57 asks `name.length` — the
                // presence of a NAME is the whole distinction, as the note below
                // already says. A number that cannot survive being written down
                // was carrying a meaning nobody was reading.
                property real lat: 0
                property real lon: 0
                // ⚠️ No `source` field. A guess is never written here, so
                // anything in this block IS the answer you gave — the presence
                // of a name is the whole distinction. The guess is recomputed
                // from the timezone on every start, in memory, which also keeps
                // it current when the machine travels.

                // Ask the network where this machine is, when nothing has been
                // set by hand.
                //
                // ⚠️⚠️ THIS IS THE ONE THING ON THIS DESKTOP THAT CONTACTS AN
                // OUTSIDE SERVICE ABOUT HIM, AND IT IS ON BY DEFAULT. Both
                // halves of that sentence are his decision, taken with the cost
                // on the table, and both are written down here because his
                // standing rule is that nothing private leaves the machine.
                //
                // What the service learns: his public IP address, because that
                // is what an HTTP request carries, and it answers with a city.
                // Not his name, not the machine, not an account. What we keep:
                // a city name and two numbers, in memory — the same shape the
                // timezone guess already has, and written to shell.json only if
                // he clicks to confirm it.
                //
                // ⚠️ WHY NOT GeoClue, which would be the obvious answer: it is
                // measured dead on this system. Its whitelist in
                // /etc/geoclue/geoclue.conf admits gnome-shell, phosh and a
                // handful of others and not us, the Mozilla location service
                // behind it was discontinued, and its client object is bound to
                // the calling D-Bus connection so `busctl` cannot drive it at
                // all. Building a path that provably never answers, so that it
                // can look like a bug later, is worse than not building it.
                //
                // ⚠️ AND THE TIMEZONE GUESS IS NOT ENOUGH, which is why this
                // exists: zone1970.tab has ONE line for the whole of Germany.
                // Home and the office produce a bit-identical point. That is not
                // a location, it is a constant per country — and his ask was
                // "egal wo ich bin … will ich das das wetter dazu passt".      // english-ok: the request, quoted
                property bool fromIp: true
            }

            property JsonObject wallpaper: JsonObject {
                // Where the picker looks. Set by the installer; empty means
                // there is no wallpaper on this machine, not "the home folder".
                property string folder: ""
                // The image in use, as a file:// URL. THIS is what survives a
                // restart — the derived palette is a cache keyed on it.
                property string current: ""
                property list<string> monitors: []


                // ------------------------------------------------- slideshow
                property bool slideshow: false
                // Minutes. ⚠️ A number rather than a set of names, because the
                // useful values are hours apart at one end and minutes at the
                // other, and any list short enough to read would miss somebody.
                property int intervalMinutes: 15
                property bool shuffle: false

                // ⚠️ WHETHER THE COLOURS COME ALONG, AND IT IS OFF BY DEFAULT.
                // With `theme.palette` on "wallpaper" every picture change
                // recalculates the WHOLE scheme — terminal, GTK, Qt, btop,
                // the compositor, all of it — so a slideshow every fifteen minutes would
                // repaint the entire desktop every fifteen minutes. Measured:
                // Forest_Color1.png gives base 27201b (warm), Desert_Color2.png
                // gives 1b2027 (cold). That is not a slideshow, it is a desktop
                // that will not sit still.
                //
                // "Change the picture" and "change the colours" are two
                // different wishes and they get two different switches.
                property bool slideshowRecolour: false

                // Which image the palette is derived from, when that is not the
                // one on screen. Empty means "the one on screen", which is what
                // every non-slideshow case wants — so this key is invisible
                // until a slideshow with the colours pinned turns it on, and
                // choosing a wallpaper by hand clears it again.
                property string paletteFrom: ""
            }
        }
    }
}
