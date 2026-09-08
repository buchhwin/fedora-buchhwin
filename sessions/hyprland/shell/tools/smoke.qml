// The smoke test: start everything the desktop is made of, headless, and say
// so if any of it failed to come into existence.
//
//   BUCHHWIN_TOOL=smoke QT_QPA_PLATFORM=offscreen qs -p shell
//
// ⚠️ THIS IS THE CHECK A LINTER CANNOT DO. qmllint reads files; it does not
// build the object graph. It cannot see a missing qmldir entry, a singleton
// shadowed by a Qt type, or a `Connections { target: <singleton> }` that
// crashes on a singleton still being constructed — and every one of those has
// turned this desktop black at some point during development. The plan called
// for this from M1 and it was never written, so the CI has been linting and
// calling it proof.
//
// ⚠️ IT DOES NOT START THE SURFACES. A PanelWindow needs a Wayland compositor
// with wlr-layer-shell, which a CI container does not have. What it does start
// is everything BELOW the surfaces — config, migrations, theme, every service —
// which is where the singleton faults live. The surfaces themselves are checked
// on the VM, by looking at them.
//
// The plan names this file shell/tests/headless.qml. It is here instead because
// quickshell treats the folder of the file it is given as the config root: a
// second root would give the tools a different import graph from the shell, and
// then the thing being tested is not the thing that runs. Same reason there is
// only one entry point — see shell.qml.
import QtQuick
import Quickshell
import Quickshell.Io
import "../services" as Services
import "../config"
import "../theme"
import "../ipc"
import "../common"
import "../ui/common" as Ui

Scope {
    id: root

    property string report: ""
    property int failures: 0

    FileView { id: out; path: "/tmp/buchhwin-smoke.txt" }
    function note(s) { report += s + "\n"; out.setText(report) }

    function ok(what, cond) {
        if (cond) note("  ok    " + what)
        else { failures++; note("  FAIL  " + what) }
    }

    // A singleton that failed to build is `null` here rather than throwing, and
    // QML says so only in a warning on stderr that nothing reads. Hence a test.
    function service(name, obj) {
        if (obj === null || obj === undefined) {
            failures++
            note("  FAIL  services/" + name + " did not build")
            return
        }
        // Every service carries `available`; the rule is in the plan and the
        // point of it is that the ui can ask rather than assume. A service
        // without one will be used as though it were always there.
        if (obj.available === undefined) {
            failures++
            note("  FAIL  services/" + name + " has no `available` flag")
            return
        }
        note("  ok    services/" + name + " (available: " + obj.available + ")")
    }

    // A pill with something in it, built off screen purely so the check below
    // can ask whether it carries a tap handler of its own. Nothing draws it.
    Ui.Pill {
        id: probe
        interactive: true
        Ui.BarText { text: "Media" }
    }

    // Is there a TapHandler on the pill itself? `data` holds an Item's children
    // and its handlers together; a TapHandler is the one with a gesture policy,
    // which the HoverHandler beside it does not have.
    function pillHasOwnTap() {
        var d = probe.data
        for (var i = 0; i < d.length; i++)
            if (d[i] && d[i].gesturePolicy !== undefined)
                return true
        return false
    }

    // ⚠️ WaitFor, not a Timer, and the difference is documented in Config.qml:
    // `loaded` turns true one event-loop step BEFORE the JsonAdapter pushes the
    // parsed values into its properties. A timer that happens to fire in that
    // gap reads defaults and reports them as the truth. The first version of
    // this file used a 300 ms Timer and failed its own "config settled" check —
    // which is the test working, on itself.
    WaitFor {
        condition: Config.settled

        onTimedOut: {
            note("buchhwin smoke — ABORT: the configuration never settled")
            Qt.callLater(Qt.quit)
        }

        onReady: {
            note("buchhwin smoke — building every singleton headless")

            // ------------------------------------------------------ config
            root.ok("config settled", Config.settled)
            root.ok("no migration error: " + Config.migrationError,
                    Config.migrationError.length === 0)

            // ⚠️ THE COMMENT BESIDE `nulledKeys` PROMISED THIS AND NOTHING DID
            // IT. Config.qml says of that property: "tools/smoke.qml reports it
            // and the settings window will show it." Neither was true —
            // tests/key-readers.sh found it with no reader anywhere.
            //
            // It is not decoration. A `null` block in shell.json makes the
            // adapter hand back nulls instead of values, and `"theme": null`
            // once took out Scheme, Theme and Theming at once with no error
            // visible. The scrub in Config._migrate repairs it and records what
            // it had to throw away — and something silently reverted to
            // defaults is exactly what somebody has to be able to find out
            // about, which was the whole argument for keeping the list.
            root.ok("no settings were nulled and scrubbed" +
                    (Config.nulledKeys.length
                     ? " (" + Config.nulledKeys.join(", ") + ")" : ""),
                    Config.nulledKeys.length === 0)
            root.ok("config version matches the migration chain",
                    Config.version === Migrations.current)

            // The 6 → 7 step, both ways round. A migration that lifts an old
            // DEFAULT has to be able to tell a default from a decision, and
            // there is no way to see the difference from the value alone —
            // only from whether it is still the exact triple the old build
            // wrote. So both directions are asserted: the untouched file moves,
            // the chosen one does not.
            var alt = Migrations.migrate({ version: 6,
                look: { shadowSoftness: 28, shadowSpread: 2, shadowOffsetY: 6 } })
            root.ok("6→7 lifts the untouched shadow triple",
                    alt.ok && alt.config.look.shadowSoftness === 40
                    && alt.config.look.shadowSpread === 3
                    && alt.config.look.shadowOffsetY === 8)
            var eigen = Migrations.migrate({ version: 6,
                look: { shadowSoftness: 12, shadowSpread: 2, shadowOffsetY: 6 } })
            root.ok("6→7 leaves a chosen shadow alone",
                    eigen.ok && eigen.config.look.shadowSoftness === 12
                    && eigen.config.look.shadowSpread === 2
                    && eigen.config.look.shadowOffsetY === 6)

            // The 7 → 8 step, both ways round for the same reason. A frozen
            // copy of our own defaults has to go, or no binding added from now
            // on ever reaches a machine that has run this shell before; a list
            // somebody has actually touched must survive untouched.
            var ctx = { defaultBinds: Config.defaultBinds }
            var fossil = []
            for (var b = 0; b < Config.defaultBinds.length; b++)
                fossil.push(Config.defaultBinds[b])
            var gone = Migrations.migrate({ version: 7, binds: fossil }, ctx)
            root.ok("7→8 drops a frozen copy of the defaults",
                    gone.ok && gone.config.binds === undefined)

            var mine = []
            for (var c = 0; c < Config.defaultBinds.length; c++)
                mine.push(Config.defaultBinds[c])
            mine[0] = { key: mine[0].key, action: "spawn-sh", arg: "my-own-terminal" }
            var kept = Migrations.migrate({ version: 7, binds: mine }, ctx)
            root.ok("7→8 keeps a list that was rebound",
                    kept.ok && kept.config.binds !== undefined
                    && kept.config.binds.length === Config.defaultBinds.length)

            // ⚠️ BOTH DIRECTIONS, as every lift in that file needs. One of these
            // alone is not a check: a step that rewrote the key unconditionally
            // would pass the first, and a step that did nothing would pass the
            // second.
            var flagged = Migrations.migrate(
                { version: 11, programs: { browser: ["brave-browser"] } }, ctx)
            root.ok("11→12 gives the untouched browser its Wayland flag",
                    flagged.ok
                    && flagged.config.programs.browser.length === 2
                    && flagged.config.programs.browser[1] === "--ozone-platform=wayland")

            var chosen = Migrations.migrate(
                { version: 11, programs: { browser: ["firefox", "--new-window"] } }, ctx)
            root.ok("11→12 leaves a browser somebody chose alone",
                    chosen.ok
                    && chosen.config.programs.browser.length === 2
                    && chosen.config.programs.browser[0] === "firefox")

            // ⚠️ THE SECOND HALF OF AN INSTRUCTION THAT SHIPPED HALF-DONE. Step
            // 10 → 11 lifted opacityPanel and opacityApp and left the two keys
            // that actually make a window see-through. Both directions again,
            // because a step that clamped every opacity to 1 would pass the
            // first line and take a deliberate 0.5 with it.
            var opaque = Migrations.migrate(
                { version: 12, look: { opacityActive: 0.95, opacityInactive: 0.9 } }, ctx)
            root.ok("12→13 makes the untouched windows opaque",
                    opaque.ok
                    && opaque.config.look.opacityActive === 1.0
                    && opaque.config.look.opacityInactive === 1.0)

            var dimmed = Migrations.migrate(
                { version: 12, look: { opacityActive: 0.5, opacityInactive: 0.4 } }, ctx)
            root.ok("12→13 leaves a transparency somebody chose alone",
                    dimmed.ok
                    && dimmed.config.look.opacityActive === 0.5
                    && dimmed.config.look.opacityInactive === 0.4)

            // ------------------------------------------------------ theme
            // All 26 palette names resolve. `hex()` answers Scheme.unknown for
            // a name it does not know — magenta, impossible to miss in a
            // screenshot, and equally impossible to notice in CI unless
            // something looks. Asked by name rather than by colour, so the
            // tripwire against literals stays satisfied and there is still only
            // one place that decides what "unknown" looks like.
            var names = ["rosewater", "flamingo", "pink", "mauve", "red",
                         "maroon", "peach", "yellow", "green", "teal", "sky",
                         "sapphire", "blue", "lavender", "text", "subtext1",
                         "subtext0", "overlay2", "overlay1", "overlay0",
                         "surface2", "surface1", "surface0", "base", "mantle",
                         "crust"]
            var missing = []
            for (var i = 0; i < names.length; i++)
                if (Scheme.hex(names[i]) === Scheme.unknown)
                    missing.push(names[i])
            root.ok("all 26 palette names resolve" +
                    (missing.length ? " (missing: " + missing.join(", ") + ")" : ""),
                    missing.length === 0)

            // The neutral set, asked the same question. tools/render.qml builds
            // it with FromImage.neutral() to theme a single program grey while
            // the rest stay coloured; a name missing from it would come out as
            // one black surface in one program — the kind of gap that is only
            // ever found by looking.
            var neutral = FromImage.neutral(true, 0)
            var greyMissing = []
            for (var g = 0; g < names.length; g++)
                if (!neutral || !neutral.colors || !neutral.colors[names[g]])
                    greyMissing.push(names[g])
            root.ok("the neutral set has all 26 names" +
                    (greyMissing.length ? " (missing: " + greyMissing.join(", ") + ")" : ""),
                    greyMissing.length === 0)

            // ⚠️ TWO VOCABULARIES FOR ONE COLOUR, checked rather than trusted.
            //
            // The shell draws with ROLES (Theme.bg), the renderer writes with
            // PALETTE KEYS (Scheme.hex("base")) — it has to, because it must be
            // able to read the same role out of a second, grey colour set that
            // Theme knows nothing about. Theme.qml says the two are the same
            // thing; here they are compared, so that renaming a role or
            // repointing it cannot silently give foreign applications different
            // colours from our own surfaces.
            var roles = [[Theme.bg, "base"], [Theme.bgDim, "mantle"],
                         [Theme.bgDeep, "crust"], [Theme.surface, "surface0"],
                         [Theme.surfaceHigh, "surface1"],
                         [Theme.surfaceHigher, "surface2"],
                         [Theme.overlay, "overlay0"], [Theme.outline, "overlay1"],
                         [Theme.fgDisabled, "overlay2"], [Theme.fg, "text"],
                         [Theme.fgMuted, "subtext1"], [Theme.fgDim, "subtext0"],
                         [Theme.ok, "green"], [Theme.warn, "yellow"],
                         [Theme.error, "red"], [Theme.info, "sapphire"],
                         [Theme.accentAlt, "teal"]]
            // ⚠️⚠️ AND `look.surfaceStyle: "black"` BREAKS EIGHT OF THEM ON
            // PURPOSE — that is the feature, not drift. He asked on 10.08.2026
            // for our own surfaces to be plain black while APPLICATIONS keep
            // their palette colours, so in black mode the two vocabularies are
            // deliberately no longer the same thing for the eight background
            // roles. This check went red the moment that shipped, which is
            // exactly what it is for; the answer is to say which mode it is
            // asking about rather than to loosen it.
            //
            // ⚠️ The half that still has to hold either way is the one the user
            // can see: the FOREGROUND and status roles come from the palette in
            // both modes, and the renderer's output is untouched by this
            // setting. Those are checked unconditionally below.
            var surfaceRoles = ["base", "mantle", "crust", "surface0",
                                "surface1", "surface2", "overlay0", "overlay1"]
            var black = Theme.blackSurfaces
            var drifted = []
            var wrongly = []
            for (var r = 0; r < roles.length; r++) {
                var key = roles[r][1]
                var same = Theme.hex(roles[r][0]) === Scheme.hex(key)
                var mayDiffer = black && surfaceRoles.indexOf(key) >= 0
                if (!same && !mayDiffer)
                    drifted.push(key)
                // The other direction: in scheme mode NOTHING may differ, and in
                // black mode the surface roles MUST differ — a black mode that
                // quietly did nothing would pass a one-sided check.
                if (same && mayDiffer)
                    wrongly.push(key)
            }
            root.ok("every Theme role is the palette key the renderer writes"
                    + (black ? " (black surfaces: the eight background roles are"
                             + " deliberately their own)" : "")
                    + (drifted.length ? " (drifted: " + drifted.join(", ") + ")" : ""),
                    drifted.length === 0)
            root.ok("and black surfaces really are black, not quietly the palette"
                    + (wrongly.length ? " (still palette: " + wrongly.join(", ") + ")" : ""),
                    !black || wrongly.length === 0)

            root.ok("theme tokens exist",
                    Theme.panelBg !== undefined && Theme.radiusLg > 0
                    && Theme.space4 > 0 && Theme.fontSize > 0)
            // ⚠️ `glassRimBottom` is gone on purpose — the panes have no edge
            // any more ("ganz weg", 06.08.2026), so the token was deleted rather  english-ok: quoted answer
            // than left unread. What replaces it is the optional border, which
            // is 0 by default and must still HAVE a value: a key nobody reads is
            // exactly the debt this file exists to catch.
            root.ok("glass tokens exist",
                    Theme.glassSheen !== undefined
                    && Theme.hairline > 0
                    && Theme.panelBorderWidth !== undefined
                    && Theme.outline !== undefined)

            // ⚠️ THE TAP TARGET, because this one shipped. A TapHandler written
            // inside a Pill lands in the Pill's inner Item, which is sized to
            // its contents — so half the pill highlighted on hover and did
            // nothing on click. Measured on the quick panel's "Media" tab: pill
            // 68 x 29, target 44 x 21, 1050 px² lit and dead.
            //
            // The call sites are guarded statically by tests/tap-targets.sh.
            // This is the other half: that Pill still has a handler of its own
            // for them to rely on.
            root.ok("a Pill carries its own tap handler",
                    probe.width > 0 && probe.height > 0 && root.pillHasOwnTap())

            // ------------------------------------------------------ ipc
            // Every verb the generated keybindings call has to exist, or a key
            // answers with an error nobody sees. Checked against the config
            // rather than a list typed here, so a new binding cannot be added
            // without its verb.
            // ⚠️ BOTH TARGETS. The launcher is not a notch page — it has its
            // own ipc target — and a check that only knew about `notch` would
            // have let a typo in the launcher's key through silently, which is
            // the one thing this check exists to prevent.
            // ⚠️ ASKED, NOT LISTED. This was a hand-typed table of every
            // verb, and the comment above it said what was wrong with it: it
            // could only ever go stale in the direction of a verb that EXISTS
            // and is missing here. That came true the first time a verb was
            // added afterwards — the check went red at a keybinding that worked,
            // which is the worst way for a tripwire to fail, because the next
            // person edits the tripwire.
            //
            // Now each binding's verb is looked up on the handler object itself:
            // `typeof handler[verb] === "function"` is the same question the IPC
            // layer answers at run time, asked of the same object. Nothing to
            // keep in step.
            var binds = Config.binds
            var orphans = []
            for (var b = 0; b < binds.length; b++) {
                var arg = String(binds[b].arg || "")
                var m = arg.match(/ipc call ([a-z]+) ([a-z]+)/)
                if (!m)
                    continue
                var handler = Ipc.targets[m[1]]
                if (!handler || typeof handler[m[2]] !== "function")
                    orphans.push(binds[b].key + " → " + m[1] + " " + m[2])
            }
            // ⚠️ THE DUPLICATE CHECK BELONGS HERE, NOT IN tests/niri-config.sh.
            // That one reads the GENERATED config — and the generator drops a
            // duplicate key before writing, with a note in a log the test does
            // not read. So it could never go red: it was passing because the
            // duplicate had already been removed, not because there was none.
            // Measured by adding a second Mod+K and watching it stay green
            // while the binding silently did not exist.
            var byKey = ({})
            var twice = []
            for (var d = 0; d < binds.length; d++) {
                var k = String(binds[d].key || "")
                if (byKey[k]) {
                    if (twice.indexOf(k) < 0) twice.push(k)
                } else {
                    byKey[k] = true
                }
            }
            root.ok("no key is bound twice" +
                    (twice.length ? " (" + twice.join(", ") + ")" : ""),
                    twice.length === 0)

            root.ok("no keybinding calls an ipc target or verb that does not exist" +
                    (orphans.length ? " (" + orphans.join(", ") + ")" : ""),
                    orphans.length === 0)

            // ------------------------------------------------------ services
            root.service("Compositor", Services.Compositor)
            root.service("Hyprland", Services.Hyprland)
            root.service("Power", Services.Power)
            root.service("Audio", Services.Audio)
            root.service("Net", Services.Net)
            root.service("Bt", Services.Bt)
            root.service("Media", Services.Media)
            root.service("Notifications", Services.Notifications)
            root.service("Brightness", Services.Brightness)
            root.service("Nightlight", Services.Nightlight)
            root.service("Wallpaper", Services.Wallpaper)
            root.service("Calendar", Services.Calendar)
            root.service("Weather", Services.Weather)
            root.service("Location", Services.Location)
            root.service("Tray", Services.Tray)
            root.service("Clipboard", Services.Clipboard)
            root.service("Theming", Services.Theming)

            // ⚠️ NO EXCEPTION ANY MORE. Ical used to be waved through here as
            // "a parser rather than a device", while services/qmldir said every
            // service carries `available` "without exception". One of the two
            // was wrong, and it was cheaper to give the parser an honest flag
            // than to keep a rule with a hole in it.
            root.service("Ical", Services.Ical)
            root.service("Calculator", Services.Calculator)
            root.service("Countdown", Services.Countdown)

            // ⚠️ AND THE TWO THAT ANSWER QUESTIONS ABOUT THE MACHINE. Installed
            // was missing from this list from the day it was written, and it
            // carried `ready` instead of `available` the whole time — the rule
            // in services/qmldir and the list that enforces it had the same
            // hole, so neither could catch the other. Gpu is added with it
            // rather than after somebody notices the same thing twice.
            root.service("Installed", Services.Installed)
            root.service("Gpu", Services.Gpu)

            note(root.failures === 0
                 ? "smoke: all good"
                 : "ABORT: " + root.failures + " check(s) failed")
            Qt.callLater(Qt.quit)
        }
    }
}
