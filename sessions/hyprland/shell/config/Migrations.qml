pragma Singleton

// Numbered migrations for ~/.config/buchhwin/shell.json.
//
// This does NOT walk back the rule stated in Config.qml. Adding a key still
// needs nothing: the adapter default answers for it, and a file written last
// month keeps working. A migration is only for the two cases a default cannot
// cover — a key that was RENAMED, and a key that was REMOVED. In both, the old
// name is already sitting in somebody's file and only code can know what it
// meant.
//
// It runs on the RAW JSON, deliberately, and this is the part that is easy to
// get wrong: JsonAdapter drops every key it does not declare. So a migration
// reading through the adapter cannot see the old field it exists to rescue —
// by the time the adapter has parsed the file, the evidence is gone. Read the
// text, transform the object, write it back, and only then let the adapter look.
//
// The chain is almost empty on purpose. It is here before the first rename so
// that the first rename is not also the day we discover we need a mechanism.

import QtQuick
// `Singleton` is a Quickshell type, not a QtQuick one. Leaving this import out
// fails as "Singleton is not a type" — and, because both singletons here share
// one qmldir, it takes Config down with it and the whole desktop reports
// "Type Config unavailable" instead of naming the real file.
import Quickshell

Singleton {
    id: root

    // Must match Config's `version` default. A file with a lower number is
    // brought forward; a HIGHER number means the config was written by a newer
    // build than this one, which we must not "migrate" — see needed().
    // ⚠️ THE SEPARATOR IS WRITTEN AS AN ESCAPE, and it used to be a RAW NUL
    // BYTE sitting in the source. It worked — QML is happy with one inside a
    // string — but it made this file `data` rather than `text` to every tool
    // that asks: `grep` prints "binary file matches" and no line, `git diff`
    // refuses to show it, and searching the repository for anything in here
    // came back EMPTY rather than wrong. That is the worst kind of quiet: a
    // search that finds nothing looks exactly like a fact that is not there.
    //
    // NUL because it cannot occur in a key name, an action or an argument, so
    // joining three fields with it can never collide with their contents.
    readonly property string sep: "\u0000"

   readonly property int current: 16

    // step[n] upgrades a config at version n to version n+1.
    // Each is a pure function: take the parsed object, return it changed.
    readonly property var steps: [
        // 0 → 1: versioning introduced. Files written before this had no
        // `version` key at all and no renamed fields to repair, so there is
        // nothing to do but stamp them.
        function (cfg) {
            return cfg
        },

        // 1 → 2: `wallpaper.derive` removed.
        //
        // It named three modes ("none", "accent", "full") and only ever held
        // the first, because the decision it described is already made by
        // theme.palette: setting that to "wallpaper" derives the scheme from
        // the image, and anything else does not. Two keys for one decision can
        // disagree, and the one that loses is whichever the reader forgot.
        //
        // Deleting it is safe precisely because it did nothing. It still needs
        // a migration rather than a default, since the old key is already
        // sitting in files and JsonAdapter would otherwise carry it forward
        // for ever as a fossil nobody dares remove.
        function (cfg) {
            if (cfg.wallpaper && typeof cfg.wallpaper === "object")
                delete cfg.wallpaper.derive
            return cfg
        },

        // 2 → 3: `weather` became `location`.
        //
        // The place was stored under the one feature that happened to need it
        // first. It is a property of the machine — the weather wants it, and so
        // do sunrise/sunset for automatic light/dark and gammastep's night
        // light. Moving it is a RENAME, which is exactly what this chain is for:
        // the old key is already sitting in files, and only code can know that
        // `weather.lat` and `location.lat` mean the same thing.
        //
        // Anything already under `location` wins — a newer build may have
        // written it, and a migration must not undo that.
        function (cfg) {
            if (cfg.weather && typeof cfg.weather === "object") {
                if (!cfg.location || typeof cfg.location !== "object")
                    cfg.location = {}
                var w = cfg.weather
                if (cfg.location.name === undefined && w.name !== undefined)
                    cfg.location.name = w.name
                if (cfg.location.lat === undefined && w.lat !== undefined)
                    cfg.location.lat = w.lat
                if (cfg.location.lon === undefined && w.lon !== undefined)
                    cfg.location.lon = w.lon
                // No `source` is carried over: a place in this block IS the
                // answer you gave. The timezone guess is never written, so the
                // presence of a name is the whole distinction.
                delete cfg.location.source
                delete cfg.weather
            }
            return cfg
        },

        // 3 → 4: the `dock` block and `surfaces.dock` removed.
        //
        // They described a dock that does not exist — iconSize, pinned,
        // monitors, and a switch to turn the whole thing off — and not one key
        // of it was ever read, because the dock is M7. A setting that does
        // nothing is worse than a missing one: it is a promise, and the only
        // way to discover it was empty is to try it and watch nothing happen.
        //
        // They come back with the dock itself, and then they will mean
        // something. Until then they are removed rather than left as furniture,
        // which is the same judgement the plan makes about the predecessor's
        // dead `bar.*` keys and its `dock.height`.
        function (cfg) {
            delete cfg.dock
            if (cfg.surfaces && typeof cfg.surfaces === "object")
                delete cfg.surfaces.dock
            return cfg
        },

        // 4 → 5: `programs.launcher` removed.
        //
        // It was an empty argument list waiting for M6 to name some other
        // program to shell out to. M6 built the launcher instead, so the key
        // now describes a second launcher that nothing would ever start — the
        // same emptiness as the `dock` block above, and removed for the same
        // reason rather than left as furniture.
        //
        // ⚠️ Only the key goes. Somebody who put a real command in it was
        // asking for that program to be their launcher, and they lose that
        // here — which is why it is a migration with a note and not a silent
        // default change. The shell's own launcher is on Super+D.
        function (cfg) {
            if (cfg.programs && typeof cfg.programs === "object")
                delete cfg.programs.launcher
            return cfg
        },

        // 5 → 6: `keys.binds` moves to the top level as `binds`.
        //
        // ⚠️ THIS IS A CRASH FIX, NOT TIDYING. quickshell segfaulted on roughly
        // half of all starts, always with the same backtrace: QObjectWrapper::wrap
        // ← QMetaProperty::write ← JsonAdapter::deserializeRec, and the
        // deserializeRec frame appeared TWICE — a nested object. Bisected on the
        // machine, one key at a time, twelve runs each:
        //
        //   {"outputs":[ …objects… ]}            var, TOP LEVEL    0/12
        //   {"keys":{"binds":[ …objects… ]}}     var, NESTED       6/12
        //   {"windows":{"blurred":["kitty"]}}    list<string>      0/12
        //   {"keys":{"binds":[]}}                var, NESTED       6/12
        //
        // An EMPTY nested list is enough, so it is neither the length nor the
        // contents: writing a `var` property that sits inside a nested
        // JsonObject is what quickshell cannot survive. `binds` was the only one
        // in the whole config — every other list is a `list<string>` or
        // `list<int>`, and `outputs` is the one other `var` and is top level.
        //
        // Moving it up is therefore the whole fix, and it costs a migration
        // rather than a workaround that would have to be remembered.
        function (cfg) {
            if (cfg.keys && typeof cfg.keys === "object"
                && cfg.keys.binds !== undefined) {
                // The file wins over anything already at the top level: it is
                // where the user's bindings actually were.
                cfg.binds = cfg.keys.binds
                delete cfg.keys.binds
            }
            return cfg
        },

        // 6 → 7: the window shadow's three numbers were too small to be seen.
        //
        // ⚠️ THE FIRST MIGRATION IN THIS CHAIN THAT IS NEITHER A RENAME NOR A
        // REMOVAL, and it needs to exist for a reason the header does not
        // cover: JsonAdapter writes every key it knows into shell.json, so the
        // OLD default is already sitting in the file on every machine that has
        // ever started this shell. Changing the default alone would fix new
        // installations and leave his own desktop exactly as it was — and "the
        // windows have no shadow" is his report, not a new machine's.
        //
        // Measured before touching it: with the shadow switched off and on
        // again at the same window position, the wallpaper beside the window
        // differs by up to 192 (sum of R+G+B) and fades out over exactly 30 px.
        // The shadow was always being drawn. At 28/2/6 it was simply too small
        // and too pale to read as one.
        //
        // ⚠️ ONLY THE UNTOUCHED TRIPLE IS LIFTED. Somebody who set their own
        // numbers chose them, and a migration that overwrites a choice is a bug
        // with a version number on it.
        function (cfg) {
            var l = cfg.look
            if (l && typeof l === "object"
                && l.shadowSoftness === 28 && l.shadowSpread === 2
                && l.shadowOffsetY === 6) {
                l.shadowSoftness = 40
                l.shadowSpread = 3
                l.shadowOffsetY = 8
            }
            return cfg
        },

        // 7 → 8: a frozen copy of the DEFAULT key bindings is dropped.
        //
        // ⚠️ THIS IS A LANDMINE THAT WOULD HAVE GONE OFF ON EVERY FUTURE
        // BINDING. Found while adding one: `Mod+Tab` for the workspace map was
        // in the defaults, the generator ran, the config validated — and the
        // key was not in it. The reason was in shell.json: 63 entries under
        // `binds`, every one of them our own default, put there by the build in
        // which `keys.binds` was a `var` inside a nested JsonObject and carried
        // the whole list as its default. JsonAdapter wrote them out, the 5 → 6
        // step moved them to the top level, and "the file wins when it says
        // anything at all" did the rest: the defaults were frozen at the day
        // that file was first written. Every binding added since — and every one
        // that will ever be added — would have been invisible on every machine
        // that has run this shell, silently.
        //
        // So a list that is EXACTLY ours is not a decision, it is a fossil, and
        // it goes. The test is per entry: same key, same action, same argument.
        // One rebound key, one added binding, one entry we never shipped, and
        // the whole list is a decision and stays untouched.
        //
        // ⚠️ WHAT THIS DOES COST, said plainly: somebody who deleted a default
        // binding by hand and changed nothing else gets it back. That is the
        // one case this cannot tell from a fossil, and it is the smaller harm —
        // a binding you did not want is a nuisance, a binding you cannot get is
        // a feature that does not exist.
        function (cfg, ctx) {
            var b = cfg.binds
            var d = ctx ? ctx.defaultBinds : null
            if (!Array.isArray(b) || b.length === 0 || !Array.isArray(d))
                return cfg

            function sig(e) {
                return (e && e.action !== undefined ? e.action : "")
                     + sep + (e && e.arg !== undefined ? e.arg : "")
            }
            var ours = {}
            for (var i = 0; i < d.length; i++)
                if (d[i] && d[i].key !== undefined)
                    ours[d[i].key] = sig(d[i])

            for (var j = 0; j < b.length; j++) {
                var e = b[j]
                if (!e || e.key === undefined || ours[e.key] === undefined)
                    return cfg               // something we never shipped
                if (ours[e.key] !== sig(e))
                    return cfg               // a key bound to something else
            }
            delete cfg.binds
            return cfg
        },

        // 8 → 9: `timer.presets` holds STRINGS.
        //
        // ⚠️ Not a rename and not a removal — a TYPE change, which this chain
        // has not had before, and it is here because the old type never worked.
        // `property list<int>` is something JsonAdapter cannot deserialise at
        // all: a JSON array of numbers arrives as a QVariantList and it refuses
        // the conversion, for a valid list as much as for a null one. So any
        // presets anybody had written were being ignored in favour of the
        // defaults, with a single journal line as the only sign.
        //
        // Measured before changing anything — list<string> is clean nested and
        // at the top level, list<int> and list<real> both warn at either depth.
        // The full table is in config/Config.qml beside the property.
        //
        // Numbers become their own text so the value a user chose survives the
        // change instead of being reset to the defaults, which is what "we only
        // ever migrate forwards" is for. Anything that is not a positive number
        // is dropped rather than carried: the reader treats 0 as "not a preset"
        // and would draw a dead pill.
        function (cfg) {
            var t = cfg.timer
            if (!t || t.presets === undefined || t.presets === null)
                return cfg
            var out = []
            for (var i = 0; i < t.presets.length; i++) {
                var n = parseInt(t.presets[i])
                if (!isNaN(n) && n > 0)
                    out.push(String(n))
            }
            t.presets = out
            return cfg
        },

        // 9 → 10: `notch.expandedHeight` removed.
        //
        // It was a MINIMUM height applied to every page, and commit 9bec5fa
        // deleted that behaviour on purpose — a page shorter than 135 got the
        // difference split above and below it as dead space, measured at
        // media 161→138, tray 161→138, calculator 161→120. After that only the
        // wallpaper picker still read it, to size its covers, and 3added8 made
        // that page a grid. tests/key-readers.sh found the key with no reader
        // left at all.
        //
        // Removed rather than given a reader back: restoring one would mean
        // re-introducing the space that was measured away.
        function (cfg) {
            if (cfg.notch && cfg.notch.expandedHeight !== undefined)
                delete cfg.notch.expandedHeight
            return cfg
        },

        // 10 → 11: three fossilised defaults are lifted to their new values.
        //
        // ⚠️⚠️ EVERY DEFAULT THIS PROJECT SHIPS IS DEAD ON A MACHINE THAT HAS
        // WRITTEN ITS SETTINGS ONCE, and that is not a bug in one key — it is
        // how JsonAdapter works. Measured on his laptop: shell.json holds **148
        // keys**, which is every setting there is. The installer seeds a file
        // with two groups in it; the moment anything is changed, the adapter
        // serialises the whole tree and "the file wins as soon as it says
        // anything" freezes the lot. Exactly the shape of the 63 frozen key
        // bindings in step 7 → 8, one level wider.
        //
        // So a changed default has to be MIGRATED, not just changed. The three
        // here are the ones that hurt on a real machine:
        //
        //   cursor.theme "Breeze_Dark" — that theme does not exist. The package
        //     we install, breeze-cursor-theme, ships Breeze_Light and
        //     breeze_cursors and nothing called Breeze_Dark (checked with
        //     `rpm -ql`). The compositor was handed a name that resolves to nothing and
        //     drew its own pointer at its own size: "far too big".
        //   look.opacityPanel 0.78 and look.opacityApp 0.80 — his decision, in
        //     his words: take the transparency out everywhere except the
        //     terminal. It also turned out to be what he was calling "a strange
        //     gradient in every menu": the wallpaper showing unevenly through a
        //     half-transparent surface. Never a gradient in the theme at all.
        //
        // ⚠️ ONLY WHEN THE VALUE IS EXACTLY THE OLD DEFAULT, per key. A value
        // somebody chose is a decision and stays. This cannot tell a deliberate
        // 0.78 from a fossilised one — the same admitted cost as step 7 → 8, and
        // the same reasoning: a transparency you did not ask for is a nuisance,
        // a pointer you cannot read is a desktop you cannot use.
        function (cfg) {
            if (cfg.cursor && cfg.cursor.theme === "Breeze_Dark")
                cfg.cursor.theme = "McMojave-cursors"
            if (cfg.look) {
                if (cfg.look.opacityPanel === 0.78)
                    cfg.look.opacityPanel = 1.0
                if (cfg.look.opacityApp === 0.80 || cfg.look.opacityApp === 0.8)
                    cfg.look.opacityApp = 1.0
            }
            return cfg
        },

        // ---------------------------------------------------------- 11 -> 12
        // `programs.browser` gains the Wayland flag.
        //
        // ⚠️ THE KEY AND THE LAUNCHER WERE STARTING TWO DIFFERENT BROWSERS.
        // tools/hypr.qml writes a .desktop override carrying
        // --ozone-platform=wayland, and the launcher honours it — measured on
        // his machine, the launcher resolves Brave to the flagged command. But
        // `spawn "brave-browser"` runs the binary and never looks at a desktop
        // file, so Mod+B got the unflagged one. Without the flag Brave picks
        // X11 and took 43 to 100 seconds to start against 1.4 with it.
        //
        // Same rule as every lift in this file: ONLY when the value is exactly
        // the old default. Somebody who has put their own arguments there has
        // made a decision, and a decision is not a fossil.
        function (cfg) {
            if (cfg.programs
                && Array.isArray(cfg.programs.browser)
                && cfg.programs.browser.length === 1
                && cfg.programs.browser[0] === "brave-browser")
                cfg.programs.browser = ["brave-browser", "--ozone-platform=wayland"]
            return cfg
        },

        // ---------------------------------------------------------- 12 -> 13
        // The window opacities, and this is the SECOND half of an instruction
        // whose first half shipped in step 10 → 11.
        //
        // ⚠️ THAT STEP LIFTED THE WRONG TWO KEYS. "Transparenz raus — überall     // english-ok: quoted brief
        // außer im Terminal" was answered with `opacityPanel` and `opacityApp`,  // english-ok: quoted brief
        // which are our own surfaces and GTK's background. The two that make a
        // WINDOW see-through are `opacityActive` and `opacityInactive`, and they
        // stayed at 0.95 and 0.90 — so nothing he actually looks at changed, and
        // he had to report the same thing twice.
        //
        // Same rule as every lift here: ONLY when the value is exactly the old
        // default. 0.90 is written `0.9` by JSON, so both spellings are checked —
        // the same care step 10 → 11 took with opacityApp.
        function (cfg) {
            if (!cfg.look)
                return cfg
            if (cfg.look.opacityActive === 0.95)
                cfg.look.opacityActive = 1.0
            if (cfg.look.opacityInactive === 0.90 || cfg.look.opacityInactive === 0.9)
                cfg.look.opacityInactive = 1.0
            return cfg
        },

        // ---------------------------------------------------------- 13 -> 14
        //
        // The Apple pointer, because he asked for it by name on 08.08.2026 and
        // because the value standing in its way was never a choice anybody made.
        //
        // ⚠️ THIS OVERWRITES A STORED VALUE, which this file does not normally
        // do, so the reason has to be here rather than in a plan. `McMojave-
        // cursors` has been the DEFAULT for a while and the installer places it
        // pinned by commit and SHA256 — but a file that says anything at all
        // wins, and files were still carrying the Breeze names. Those got there
        // in the era when our own default was `Breeze_Dark`, a theme that is on
        // no machine: the compositor could not resolve it, fell back to its own pointer at
        // its own size, and that is the "the cursor is far too big" report.
        // Step 8 -> 9 already rescued `Breeze_Dark` for exactly this reason and
        // simply did not know about the other two names.
        //
        // ⚠️ AND IT IS DELIBERATELY NOT A BLANKET RESET. Only the two Breeze
        // names move. Anything else in there — including a theme somebody chose
        // from the list in the settings window — is left exactly where it is.
        function (cfg) {
            if (cfg.cursor
                && (cfg.cursor.theme === "breeze_cursors"
                    || cfg.cursor.theme === "Breeze_Light"))
                cfg.cursor.theme = "McMojave-cursors"
            return cfg
        },

        // ---------------------------------------------------------- 14 -> 15
        //
        // `motion.speed` becomes three durations. He asked for the page in his
        // picture — Reduce motion, Movement, Fades & colour, Hover response,
        // Bounce — and one multiplier cannot answer four of those.
        //
        // ⚠️ THE SETTING IS CARRIED OVER RATHER THAN DROPPED. Somebody who had
        // set 1.4 chose a tempo, and a rename that quietly resets it is the same
        // fault as a switch that does nothing. The old meaning was "higher is
        // faster", so each new duration is the default divided by the speed —
        // which reproduces exactly what Theme.qml used to compute.
        //
        // ⚠️ Only when it is really there and really a number. A file that never
        // set it keeps the new defaults, and a broken value is left to the
        // schema rather than turned into a duration of NaN.
        function (cfg) {
            if (!cfg.motion || typeof cfg.motion !== "object")
                return cfg
            var s = Number(cfg.motion.speed)
            if (s > 0) {
                cfg.motion.durMove = Math.round(400 / s)
                cfg.motion.durFade = Math.round(200 / s)
                cfg.motion.durHover = Math.round(150 / s)
            }
            delete cfg.motion.speed
            return cfg
        },

        // ---------------------------------------------------------- 15 -> 16
        //
        // The dock is gone — the surface, the settings page, the IPC verb and
        // the whole `dock` block in Config. His decision: the bar at the TOP
        // stays, the strip at the bottom goes.
        //
        // ⚠️ THIS IS THE SECOND TIME THIS BLOCK HAS BEEN REMOVED, and the two
        // removals mean opposite things. Migration 3 -> 4 took it out because
        // nothing read a single key of it: a setting that does nothing is worse
        // than a missing one. It came back on 09.08.2026 when the dock shipped,
        // and every key did have a reader. It goes now because the SURFACE
        // goes, so the keys have nothing left to be read by — and a key with no
        // reader is exactly what tests/key-readers.sh refuses to let stand.
        //
        // ⚠️ AND A REMOVAL NEEDS A MIGRATION, unlike an addition. A config that
        // never had `dock` simply takes the defaults; a config that HAS one
        // keeps an object the schema no longer knows, and JsonAdapter carries
        // unknown keys forward forever. Left alone it would sit in every
        // shell.json on the machine, describing a surface that cannot be built.
        function (cfg) {
            delete cfg.dock
            if (cfg.surfaces && typeof cfg.surfaces === "object")
                delete cfg.surfaces.dock
            return cfg
        },
    ]

    function versionOf(cfg) {
        if (!cfg || typeof cfg !== "object")
            return 0
        var v = cfg.version
        return (typeof v === "number" && isFinite(v) && v >= 0) ? Math.floor(v) : 0
    }

    // Only true when there is work to do AND it is work we can do.
    function needed(cfg) {
        var v = versionOf(cfg)
        return v < root.current
    }

    // A config from the future is left strictly alone: downgrading by guesswork
    // would delete settings this build has never heard of. The caller should
    // say so rather than proceed quietly.
    function fromFuture(cfg) {
        return versionOf(cfg) > root.current
    }

    // Returns { ok, config, from, to, error }.
    // On any failure the ORIGINAL object comes back untouched — a half-migrated
    // config is worse than an old one.
    //
    // ⚠️ `ctx` carries what a step cannot know on its own — today only
    // `defaultBinds`, for the 7 → 8 step. It is PASSED IN rather than imported:
    // Config already imports this file, so reaching back for Config from here
    // would close a circle between two singletons, and the failure mode for
    // that in this project is "Type Config unavailable" with a stack that names
    // the wrong file.
    function migrate(cfg, ctx) {
        var from = versionOf(cfg)

        if (fromFuture(cfg))
            return { ok: false, config: cfg, from: from, to: from,
                     error: "config version " + from + " is newer than this build (" +
                            root.current + "); refusing to downgrade" }

        if (from === root.current)
            return { ok: true, config: cfg, from: from, to: from, error: "" }

        // Work on a copy so a throwing step cannot leave the caller holding a
        // partly-rewritten object.
        var out
        try {
            out = JSON.parse(JSON.stringify(cfg))
        } catch (e) {
            return { ok: false, config: cfg, from: from, to: from,
                     error: "config is not serialisable: " + e }
        }

        for (var v = from; v < root.current; v++) {
            var step = root.steps[v]
            if (typeof step !== "function")
                return { ok: false, config: cfg, from: from, to: v,
                         error: "no migration from version " + v }
            try {
                out = step(out, ctx || {})
            } catch (e2) {
                return { ok: false, config: cfg, from: from, to: v,
                         error: "migration " + v + "→" + (v + 1) + " failed: " + e2 }
            }
            if (!out || typeof out !== "object")
                return { ok: false, config: cfg, from: from, to: v,
                         error: "migration " + v + "→" + (v + 1) + " returned nothing" }
        }

        out.version = root.current
        return { ok: true, config: out, from: from, to: root.current, error: "" }
    }
}
