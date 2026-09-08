pragma Singleton

// The thing that makes "change the palette, everything follows" true.
//
// ⚠️ NOTHING DID THIS BEFORE, and the file that most needed it said otherwise:
// tools/render.qml's own header claims it runs "whenever the palette or a look
// setting changes (from the running shell)". Nothing in shell/ started it — no
// Process, no watcher, no Connections. Measured by grepping for every way a
// process can be launched.
//
// What that meant in use: pick a wallpaper, and the SHELL recolours instantly
// (QML bindings all the way down from Config to Theme), while GTK, Qt, kitty
// and niri sit on the old colours until somebody types `bhctl theme apply`.
// Half of the project's central promise, quietly untrue — and
// ui/notch/pages/WallpaperPage.qml even promised the other half in a comment.
//
// ⚠️ IT DOES NOT RENDER AT STARTUP. The files on disk were written the last
// time something changed; rewriting them on every login is a process spawn and
// a fistful of file writes to produce byte-identical output. So the first
// settled state is only RECORDED, and rendering happens on changes after that.
// "Nothing happens while nothing is happening" is the standard this project is
// held to.
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
import "../theme"

Singleton {
    id: root

    // There is no hardware behind this one; it is available as soon as there is
    // a palette to render. Every service carries the flag — see services/qmldir.
    readonly property bool available: Scheme.ready

    property bool busy: false
    property string lastError: ""

    // ⚠️ A LOG, because this service does its work in another process and would
    // otherwise fail in complete silence — which is exactly how the thing it
    // replaces went unnoticed for a milestone. `bhctl doctor` reads it (the
    // REFUSED/FAILED lines, and the last line otherwise), and so can anyone
    // wondering why a palette did not arrive. That claim stood here for a while
    // before it was true: bin/bhctl did not touch this file at all, so a
    // refusal was visible only as a banner inside a window you might not be
    // able to open, and not at all over SSH.
    //
    // It only ever holds the last few lines: an append-forever file on a
    // desktop that runs for weeks is a slow leak, not a diagnostic.
    property var _lines: []
    FileView { id: logFile; path: "/tmp/buchhwin-theming.log" }
    function log(s) {
        var l = root._lines.slice()
        l.push(s)
        while (l.length > 20) l.shift()
        root._lines = l
        logFile.setText(l.join("\n") + "\n")
    }

    // Everything the renderer actually reads, as one string. A change to any of
    // it means the generated files would come out different; a change to
    // anything else must NOT spawn a process.
    //
    // ⚠️ Built from the same values render.qml consumes, deliberately by hand
    // rather than by walking the config: a `JSON.stringify(Config)` would also
    // catch the notch geometry and the key bindings, and every keystroke in the
    // settings window would then rewrite twelve foreign config files.
    //
    // ⚠️ THE `settled` GUARD IS NOT AN OPTIMISATION, IT IS THE CRASH GUARD.
    // Touching two dozen JsonAdapter properties while the adapter is still
    // deserialising is exactly the shape that segfaults quickshell — the
    // backtrace sits in `JsonAdapter::deserializeRec`, and ui/Shell.qml
    // documents the Weather service being kept out of construction for that
    // reason. Before the config has settled this reads ONE property and
    // returns; afterwards the adapter is done and the rest is safe.
    // ------------------------------------------------- the three list prints
    //
    // Kept out of the fingerprint expression itself so that string is still
    // readable, and so each one can say what it costs.

    // ⚠️ KEY AND ACTION AND ARGUMENT, not the length. A rebinding tool changes
    // entries IN PLACE — same count, different meaning — so a length would sit
    // there saying nothing had happened while every key moved. `\u0000` as the
    // separator for the same reason Migrations.qml uses it: no key name, action
    // or argument can contain it, so two different lists cannot collide.
    readonly property string bindsPrint: {
        var b = Config.binds
        if (!b || !b.length)
            return ""
        var out = []
        for (var i = 0; i < b.length; i++)
            out.push(String(b[i].key) + "\u0000" + String(b[i].action)
                     + "\u0000" + String(b[i].arg === undefined ? "" : b[i].arg))
        return out.join("\u0001")
    }

    // The eighteen input keys, which were the largest hole of the twenty-eight.
    // Written out rather than walked, for the same reason render.qml writes its
    // thirteen theme targets out: a loop over a section reads whatever is there,
    // so a key added to Config and forgotten here would look watched and not be.
    readonly property string inputPrint: {
        var i = Config.input
        if (!i || !i.keyboard || !i.touchpad || !i.mouse)
            return ""
        var k = i.keyboard, t = i.touchpad, m = i.mouse
        return [k.layout, k.variant, k.options, k.repeatDelay, k.repeatRate,
                t.tap, t.dwt, t.naturalScroll, t.middleEmulation,
                t.accelSpeed, t.accelProfile, t.scrollMethod, t.clickMethod,
                t.scrollFactor, m.scrollFactor,
                m.naturalScroll, m.accelSpeed, m.accelProfile,
                i.focusFollowsMouse, i.warpMouseToFocus].join("\u0000")
    }

    // ⚠️ The six program references. niri.qml never names them — it resolves
    // `@terminal` through Config.program(), a STRING lookup that no search for
    // the identifier can see. That is exactly why they were missed, and why
    // switching the terminal left Mod+Return starting the old one.
    readonly property string programsPrint: {
        var p = Config.programs
        if (!p)
            return ""
        return JSON.stringify([p.terminal, p.browser, p.fileManager,
                               p.editor, p.imageViewer, p.video])
    }

    readonly property string fingerprint: {
        if (!Config.settled)
            return ""
        var t = Config.theme, l = Config.look, g = Config.theming
        // ⚠️ AND `settled` IS NOT ENOUGH — measured, not reasoned about. It goes
        // true one event-loop step before JsonAdapter has built its sub-objects,
        // so `t` is NULL here on every single start and this whole binding threw
        // with "Cannot read property 'palette' of null". Silently: the watcher
        // simply never got a fingerprint, so changing the palette re-coloured
        // the shell and left GTK, Qt, kitty and niri alone — the exact failure
        // this service was written to end.
        //
        // The test belongs here rather than inside `settled`: putting it in that
        // binding made quickshell segfault 6 runs out of 6, because reading a
        // JsonAdapter sub-object from a binding the adapter itself dirties is
        // re-entrant. See Config.qml's note.
        if (!t || !l || !g)
            return ""
        return [t.palette, t.accent, t.customColor,
                // ⚠️ `opacityPanel` AND `panelBorderWidth` ARE GONE FROM HERE,
                // and their absence is deliberate. Nothing under shell/tools/
                // reads either — they colour OUR OWN surfaces, which follow the
                // Theme singleton live and need no generator at all. Each cost a
                // full render over thirteen foreign files plus a `niri validate`
                // on every drag of a slider, for a result that was byte-identical
                // by construction. On a laptop.
                //
                // ⚠️ tests/key-readers.sh counted them as read BECAUSE THEY WERE
                // HERE — it treats any occurrence outside Config.qml as a reader,
                // including one inside this very string. So the fingerprint was
                // the only thing keeping them off that test's orphan list, and
                // removing them is what makes that test honest about them.
                l.rounding, l.borderWidth, l.opacityTerminal,
                // ⚠️ The renderer reads this one and the watcher did not
                // know it existed — so opening up GTK windows changed
                // nothing until something ELSE happened to move the
                // fingerprint. Every value render.qml reads belongs here;
                // that is the whole contract of this string.
                l.opacityApp,
                l.fontUi, l.fontMono, l.fontSize, l.profile,
                g.enabled, g.mode,
                g.gtk, g.qt, g.kitty, g.alacritty, g.hypr, g.btop, g.bat,
                g.fastfetch, g.delta, g.tmux, g.starship, g.lazygit, g.vscode,
                // ⚠️ Brave, and it belongs here for the ordinary reason —
                // render.qml reads it — but it is worth naming because this is
                // the rule the project has broken four times: a new generator
                // without a fingerprint entry colours nothing until something
                // ELSE happens to move the string.
                g.brave,
                // The two foreign programs whose files an UPDATE of that
                // program can throw away. They are in the fingerprint for the
                // ordinary reason — render.qml reads them — and the update
                // problem is a separate one, named in docs/CONFIG.md.
                g.vesktop, g.spicetify,
                // ⚠️ AND THE KEYS THE NIRI GENERATOR READS. Until now this
                // watcher only ran the RENDERER, so every niri-side setting had
                // no watcher at all: adding an app to `windows.blurred` wrote
                // nothing, and the window rule appeared only when somebody
                // happened to run `bhctl niri apply`. Measured — Nautilus got
                // its translucent CSS and no blur rule, which is a worse look
                // than leaving it opaque.
                //
                // ⚠️ THE CONTRACT WAS BROKEN TWENTY-EIGHT TIMES, AND THAT IS
                // WHY tests/fingerprint.sh NOW EXISTS. The note that used to
                // stand here said the rule had been broken "twice in one day"
                // and asked whoever adds a key to remember. Nobody remembers,
                // and a rule with no check is a wish. Counted on 07.08.2026:
                //
                //   input.*        18   layout, tap-to-click, pointer speed,
                //                       scroll method — none of it applied
                //   programs.*      6   switching the terminal left Mod+Return
                //                       starting the old one
                //   keys.mod        1   Super -> Alt wrote nothing at all
                //   binds           1   every key change, which is exactly what
                //                       a rebinding tool would produce
                //   motion.speed    1   the shell sped up, niri's own window
                //                       animations did not
                //   theming.vscode  1   the newest theme target, forgotten
                //
                // Measured rather than read, each against a control that DID
                // regenerate: change the key, wait, ask whether config.kdl was
                // rewritten. Four of them, four times "unchanged".
                //
                // ⚠️ AND THE OLD NOTE ARGUED `binds` OUT ON COST — "a settings
                // window rewriting a 63-entry list on every keystroke". The
                // argument does not hold: the debounce below is 800 ms, and the
                // generator compares before writing, so a keystroke costs one
                // process and no compositor reload. `length` rather than the
                // whole list settles even that: a bind editor changes entries in
                // place, so the length alone would miss it — the join of key and
                // action is what actually moves, and it is 63 short strings once
                // per change, next to the 26 colours already here.
                Config.surfaces.hotCorners,
                Config.keys.mod,
                // The terminal's behaviour, written into the file the renderer
                // already produces. tests/fingerprint.sh asked for these the
                // moment they existed, which is what it is for.
                Config.terminal.cursorShape, Config.terminal.cursorBlinkInterval,
                Config.terminal.cursorTrail, Config.terminal.scrollbackLines,
                // The four behaviour keys the rewrite left behind, back and
                // watched from the first commit that has them — rather than
                // after somebody reports that switching remote control off
                // changes nothing until the palette is touched.
                Config.terminal.shellIntegration, Config.terminal.remoteControl,
                Config.terminal.audibleBell, Config.terminal.scrollbackPager,
                root.bindsPrint,
                root.inputPrint,
                root.programsPrint,
                // ⚠️ THESE WERE THE THREE DURATIONS, and they moved because the
                // generator stopped reading them. It no longer restates niri's
                // eight animations in our own numbers; it writes `slowdown` and
                // lets niri's tuned defaults stand. So what has to be watched is
                // what the file now actually depends on: the speed multiplier
                // and whether animation happens at all. Both still resolve back
                // through Theme to `motion.speed` and `look.profile`, so the
                // profile switch is caught exactly as before.
                //
                // Watching the old three here would now be watching something
                // for nothing, and fingerprint.sh checks that direction too.
                Theme.motionSpeed, Theme.animate,
                // ⚠️ BOTH GENERATORS READ THESE, so they belong here — the rule
                // three lines up, applied on the way in this time instead of
                // after somebody noticed the pointer never changed.
                Config.cursor.theme, Config.cursor.size,
                // ⚠️ THE GPU niri DRAWS ON. tools/niri.qml reads it, so it
                // belongs here — the same rule as the two lines above, applied
                // on the way in for the sixth time. The `Config.gpu ?` guard is
                // not decoration: `settled` goes true one event-loop step before
                // the adapter has built its sub-objects, which is why every
                // neighbour below is written the same way.
                Config.gpu ? Config.gpu.renderDevice : "",
                // ⚠️ The light/dark schedule. Scheme decides the palette from
                // these three, so a change to any of them has to move the
                // fingerprint or the generators keep yesterday's colours until
                // something else happens to nudge them. Fifth time this rule is
                // being applied on the way in rather than after a bug report.
                Config.theme ? Config.theme.autoLight : "",
                Config.theme ? Config.theme.lightFrom : "",
                Config.theme ? Config.theme.lightUntil : "",
                Config.theme ? Config.theme.lightPalette : "",
                // ⚠️ The wallpaper itself, and it is NOT a duplicate of the
                // palette file below. Scheme derives the colours from it, so it
                // is genuinely a key a generator's dependency reads — and
                // tests/fingerprint.sh has no exemption list on purpose, so
                // "covered indirectly" is not an answer it accepts. The two
                // arrive within the same 800 ms window and collapse into one
                // render, so being literal here costs nothing.
                // ⚠️ THE EFFECTIVE PALETTE SOURCE, NOT THE PICTURE ON SCREEN,
                // and the difference is the whole cost of a slideshow. This
                // used to be `wallpaper.current`, which was the same string
                // back when the palette could only come from the image you were
                // looking at. With the colours pinned they are two things, and
                // listing the picture would re-render every foreign config on
                // every slide — the exact repainting the pin exists to prevent.
                //
                // Neither generator reads the wallpaper path itself; both were
                // downstream of it only through the palette, which is why the
                // one expression Scheme derives from is the right one to watch.
                Scheme.paletteSource,
                JSON.stringify(Config.autostart),
                JSON.stringify(Config.workspaces),
                JSON.stringify(Config.outputs),
                JSON.stringify(Config.windows.blurred),
                JSON.stringify(Config.windows.floating),
                JSON.stringify(Config.windows.blockFromScreencast),
                Config.windows.noCsd,
                // ⚠️ How wide a new window opens. tests/fingerprint.sh caught
                // this one the same hour it was added — the generator read it
                // and this string did not, so dragging the slider would have
                // written shell.json and regenerated nothing. Twenty-ninth time
                // the contract was broken, first time a check said so before
                // anybody shipped it.
                Config.windows.defaultWidth,
                l.gapsIn, l.gapsOut, l.blur, l.blurPasses, l.blurOffset,
                l.blurNoise, l.blurSaturation, l.shadows, l.shadowSoftness,
                l.shadowSpread, l.shadowOffsetY, l.shadowBehindWindow,
                // The renderer reads this one, so it belongs here — same
                // contract as opacityApp above, which was missing for a week.
                l.shadowOpacity,
                l.opacityActive,
                // `hoverCornerRadius` went with them: niri.qml:497 reads
                // `notch.cornerRadius` and nothing else. It was picked up along
                // with its neighbour rather than because anything wanted it.
                l.opacityInactive, Config.notch.cornerRadius,
                // ⚠️ THE COLOURS THEMSELVES, not the palette's NAME. The first
                // version watched `Scheme.name` and `theme.palette`, and the
                // acceptance test failed on the very case this service exists
                // for: choosing a different wallpaper leaves the name at
                // "wallpaper" and changes only the colours, so the fingerprint
                // never moved and nothing was re-rendered. Measured — kitty's
                // theme.conf came back byte-identical after a wallpaper change.
                //
                // Twenty-six short strings, compared once per change. It is
                // also the honest question: "did the colours change", not "did
                // the setting that usually changes them change".
                // The palette as it was WRITTEN, not as a property reports it.
                // See the FileView below for why that distinction had to be
                // made the hard way.
                paletteFile.text()].join("")
    }

    property string _seen: ""
    // Whether THIS session has completed a render. Without it the first
    // `_consider` after arming would stamp a state nobody produced — the files
    // on disk would be blessed as current on the strength of having been looked
    // at rather than written.
    property bool _rendered: false
    // Whether the palette file has answered — loaded OR failed. See _consider.
    property bool _palReady: false

    // Records what the generated files were last written from, once the
    // fingerprint has stopped moving. Refuses while a render is in flight or
    // the last one refused: a stamp over a failed run would tell the next login
    // that stale files are current, which is worse than no stamp at all.
    //
    // The md5 rather than the fingerprint itself — the fingerprint ends with the
    // whole palette file, so storing it verbatim would rewrite a few kilobytes
    // on every change for nothing.
    function _syncStamp() {
        if (root.busy || root.lastError.length || !root._rendered)
            return
        var want = Qt.md5(root.fingerprint)
        if (String(stamp.text() || "").trim() !== want)
            stamp.setText(want + "\n")
    }

    onFingerprintChanged: root._consider()

    // ⚠️ THE PALETTE IS WATCHED AS A FILE, NOT AS A SIGNAL — and that is the
    // fourth attempt, after three that did not work and were each measured:
    //
    //   1. reading Scheme.colors inside the fingerprint's JS block. Never fired
    //      again after the first evaluation; a binding whose first run takes an
    //      early `return` does not reliably carry the dependencies of the
    //      branch it skipped.
    //   2. `Connections { target: Scheme; onColorsChanged }`. Never fired —
    //      and this project already had that written down as a trap for
    //      singletons that are still coming into existence.
    //   3. the prescribed replacement, a bound property plus on…Changed. Also
    //      never fired, while the palette demonstrably re-derived: the cache
    //      file on disk changed its `source` and its `base` inside the test
    //      window, every time.
    //
    // What IS certain: the service is bound to the live Scheme, not a second
    // instance — when it arms it reports the same `base` that is on disk.
    //
    // So this stops asking the singleton and asks the file, which is the one
    // mechanism this project has never had trouble with: Config watches
    // shell.json exactly this way and has been reliable since M1. It also makes
    // the fingerprint honest — it now contains the palette AS WRITTEN rather
    // than a property's opinion of it.
    FileView {
        id: paletteFile
        path: Scheme.palettePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        // ⚠️ BOTH OUTCOMES ARM IT. A palette file that cannot be read is a
        // state this has to leave rather than wait in: `_consider` refuses
        // until `_palReady`, so a missing file with only `onLoaded` wired up
        // would mean the watcher never starts at all and no setting ever
        // reaches a generated file again. Same shape as Config.qml, where
        // `settled` is `loaded || _failed`.
        onLoaded: { root._palReady = true; root._consider() }
        onLoadFailed: { root._palReady = true; root._consider() }
    }

    function _consider() {
        // Both guards matter. Before the config settles the fingerprint is
        // built from adapter defaults, and rendering those would write the
        // wrong colours into every foreign config with no error anywhere —
        // exactly the failure Config.qml documents for one-shot reads.
        if (!Config.settled || !Scheme.ready || !root.fingerprint.length)
            return

        // ⚠️ AND THE PALETTE FILE MUST HAVE BEEN READ, which is a third guard
        // and it was missing. The fingerprint ends with paletteFile.text(), and
        // a FileView returns "" until it has loaded — so arming happened on an
        // INCOMPLETE fingerprint, and the file arriving a moment later looked
        // like a change. That is visible in the log as "armed …" immediately
        // followed by "something changed", on a machine where nothing had.
        //
        // On its own that only cost one render per login. It became a real
        // fault with the stamp: the baseline recorded at arming and the value
        // stamped after rendering could never agree, so every restart reported
        // "the generated files are behind" and rendered again — the control for
        // the catch-up was red three times in a row before this was found.
        if (!root._palReady)
            return

        if (root._seen === "") {
            root._seen = root.fingerprint

            // ⚠️ ARMING USED TO SWALLOW EVERY CHANGE MADE WHILE THE SHELL WAS
            // OFF. It recorded the first settled state and rendered nothing —
            // which is right when the generated files already match, and wrong
            // in exactly the cases nobody is watching: editing shell.json by
            // hand, a `git pull` that changes a palette, a restore from backup,
            // `bhctl shell reset` followed by a restart. The desktop then ran
            // with GTK, Qt, kitty and niri files describing yesterday's
            // settings, and stayed that way until some UNRELATED setting moved
            // the fingerprint. Nothing reported it, because from the watcher's
            // point of view nothing had happened.
            //
            // ⚠️ AND THE FIX IS NOT "RENDER AT STARTUP". That was the obvious
            // one and it is what the header of this file argues against: a
            // process spawn and thirteen file writes on every single login to
            // produce byte-identical output. The stamp is what makes the
            // difference measurable — render only when the files are actually
            // behind, which on a normal login is never.
            var want = Qt.md5(root.fingerprint)
            var have = String(stamp.text() || "").trim()
            if (have === want) {
                root.log("armed on palette " + Scheme.name + " (generated files are current)")
                return
            }
            root.log(have.length
                     ? "armed — the generated files are behind, catching up"
                     : "armed — no stamp yet, rendering once")
            debounce.restart()
            return
        }
        if (root._seen === root.fingerprint) {
            // ⚠️ THE STAMP IS WRITTEN HERE, NOT WHEN THE GENERATOR EXITS, AND
            // THAT WAS MEASURED THE WRONG WAY ROUND FIRST. Stamping in
            // niriProc.onExited looked obviously right and made every single
            // restart report "the generated files are behind": the renderer
            // rewrites the derived palette, this service watches that file, and
            // at the moment the generator exits the fingerprint still contains
            // the palette text from BEFORE the write. So the stamp recorded a
            // state that had already stopped being true, and the next login
            // compared against it and rendered again — one wasted process per
            // login, which is precisely what the arming rule exists to avoid.
            //
            // The control caught it: a normal restart with nothing changed must
            // say "current", and it said "catching up".
            //
            // Here, the fingerprint has stopped moving. That is the only moment
            // at which "this is what the generated files were written from" is
            // a true statement.
            root._syncStamp()
            return
        }

        root._seen = root.fingerprint
        root.log("something changed — rendering in " + debounce.interval + " ms")
        debounce.restart()
    }

    // A palette change is one event, but it arrives as several property
    // changes — palette, then the derived colours, then `ready`. Rendering on
    // each would spawn three processes to produce one result.
    Timer {
        id: debounce
        // ⚠️ 800 ms, not 300. Measured: a wallpaper change produced TWO renders
        // in a row — the palette file is written, then read back, and each is a
        // change the fingerprint sees. Two processes for one result. The window
        // has to be wider than that write-then-reload round trip, and 800 ms is
        // still nothing to a human who has just clicked a picture.
        interval: 800
        onTriggered: root.render()
    }

    // Runs the same tool the installer and `bhctl` run. One renderer, three
    // callers — a second copy of this logic is how the predecessor ended up
    // with two sets of colours that disagreed.
    // ⚠️ THE WAY OUT OF A STUCK BANNER. `lastError` is only recomputed when the
    // generator runs, and the generator only runs when the fingerprint MOVES —
    // so after a refusal, fixing the cause by putting a setting back to what it
    // was leaves the fingerprint where it started and nothing runs. The banner
    // then reports a failure that is already repaired, forever. That is exactly
    // what he reported, and the sticky half of it needs a door rather than a
    // cleverer condition.
    function retry() {
        if (root.busy)
            return
        root.log("retry asked for")
        debounce.restart()
    }

    // ⚠️ THE COMPOSITOR HALF ON ITS OWN, and it exists because of a rule this
    // project set itself: no key without an answer. Key bindings are
    // deliberately NOT in the fingerprint — a palette change must not rewrite
    // the bindings — so nothing at all happened when they changed, and the only
    // way to make a rebinding real was to type a command in a terminal. A
    // settings window that needs a terminal afterwards has not finished the job.
    //
    // ⚠️⚠️ AND THIS FUNCTION USED TO SKIP THE GENERATOR ENTIRELY. It ran
    // `hyprctl reload` and nothing else, which reloaded a config that contained
    // none of the bindings — so every rebind was a no-op that looked like a
    // success. The generator is the whole point of the call.
    //
    // Only the generator runs, not the renderer: a moved shortcut has nothing to
    // do with colours, and re-rendering fifteen foreign configs to move one
    // binding is the kind of cost that is invisible until it is on a battery.
    // tools/hypr.qml compares before it writes, so an unchanged config still
    // costs nothing but the process.
    function applyHyprland() {
        if (root.busy) {
            // A render is mid-flight and it ends with this same generator, so
            // the change is already going to be picked up.
            root.log("compositor apply asked for while busy — the running pass covers it")
            return
        }
        root.busy = true
        root.log("generating the compositor config")
        generatorProc.running = true
    }

    function render() {
        if (root.busy) {
            // Something changed while we were writing. Go round once more when
            // this one finishes rather than running two at a time.
            debounce.restart()
            return
        }
        root.busy = true
        root.log("running: " + proc.command.join(" "))
        proc.running = true
    }

    Process {
        id: proc
        // `env` as the binary rather than an environment property: it is the
        // one form that is certain to exist, and the tool needs both variables.
        //
        // `-p <root>` rather than `-c buchhwin`: the running shell already holds
        // that config name, and a second instance under the same name is a
        // question this does not need to ask.
        command: ["env", "BUCHHWIN_TOOL=render", "QT_QPA_PLATFORM=offscreen",
                  "qs", "-p", Quickshell.shellPath("")]

        onExited: function (code) {
            // ⚠️ The tool exits 0 even when it refuses to write — it says so in
            // its log instead. Silence here would mean a palette that never
            // reached anything, reported as success.
            root.lastError = code === 0 ? "" : "render exited " + code
            root.log(code === 0 ? "render finished" : "RENDER FAILED, exit " + code)
            // ⚠️ `busy` STAYS TRUE until the compositor pass is done too, or a
            // second change arriving in between would start a render while this
            // one is still finishing its other half.
            generatorProc.running = true
        }
    }

    // The second half, and it is not optional.
    //
    // ⚠️ THE RENDERER DOES NOT WRITE THE COMPOSITOR CONFIG. It writes colours,
    // including the compositor's, and the config itself is a separate
    // generator — so every compositor-side setting (gaps, borders, blur,
    // shadows, monitor layout, and every keybinding) had NO watcher at all and
    // only reached the machine when somebody ran a command by hand. That is the
    // same "a key with no reader" fault this project has now found six times,
    // one level up: a key with a reader that nothing calls.
    //
    // Running it unconditionally after every render is affordable because
    // tools/hypr.qml compares before writing — tests/hypr-config.sh has a check
    // named "a second run writes nothing" for exactly this — so an unchanged
    // config costs one process and no compositor reload.
    Process {
        id: generatorProc
        command: ["env", "BUCHHWIN_TOOL=hypr", "QT_QPA_PLATFORM=offscreen",
                  "qs", "-p", Quickshell.shellPath("")]

        onExited: function (code) {
            // ⚠️ THE TOOL EXITS 0 EVEN WHEN IT REFUSES TO WRITE. quickshell has
            // no exit code to set, so the log is the truth: a refusal writes a
            // line starting "buchhwin hypr — ABORT:". Reloading after a refusal
            // would reload the config that was just put back, which is harmless
            // but reports success for a change that did not happen.
            if (code !== 0) {
                root.busy = false
                root.lastError = "the compositor generator exited " + code
                root.log("GENERATOR FAILED, exit " + code)
                return
            }
            generatorLog.reload()
            var text = String(generatorLog.text() || "")
            var refusal = text.match(/^buchhwin hypr — ABORT:.*$/m)
            if (refusal) {
                root.busy = false
                root.lastError = String(refusal[0]).replace(/^buchhwin hypr — ABORT:\s*/, "")
                root.log("GENERATOR REFUSED: " + root.lastError)
                return
            }
            root.log("compositor config generated")
            reloadProc.running = true
        }
    }

    // What the generator said. Read once, after it exits — not watched, because
    // the only writer is a process this service started.
    FileView {
        id: generatorLog
        path: "/tmp/buchhwin-hypr.log"
        printErrors: false
    }

    Process {
        id: reloadProc
        command: ["hyprctl", "reload"]

        onExited: function (code) {
            root.busy = false
            root.lastError = code === 0 ? "" : "Hyprland reload exited " + code
            root.log(code === 0 ? "Hyprland reloaded" : "HYPRLAND RELOAD FAILED")
            if (code !== 0) return
            root._rendered = true
            root._syncStamp()
        }
    }

    // What the generated files were last written FROM. Lives in the state
    // directory, not the config one: it is a record of something that happened,
    // not a setting, and deleting it costs one extra render rather than losing
    // anything.
    //
    // ⚠️ NOT `watchChanges`. This service is the only writer, so watching it
    // would mean reacting to itself.
    FileView {
        id: stamp
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
              + "/buchhwin/theming-fingerprint"
        blockLoading: true
        printErrors: false
        atomicWrites: true
    }

    // Read after the generator has run, never watched: a log that is watched
    // would re-trigger everything that reads this service every time a line is
    // appended to it.
}
