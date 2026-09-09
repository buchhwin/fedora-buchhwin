pragma Singleton

// The active colour palette.
//
// A palette is 26 semantic colour names — see palettes/SCHEMA.md. They are the
// only hand-authored colour data in the project; everything visible is derived
// from them in Theme.qml. Drop a JSON file in palettes/ and it appears
// everywhere, with no code change.
//
// Loading is asynchronous. Anything that reads `colors` before `ready` turns
// true gets the fallback below, never an error and never a blank screen — a
// desktop that cannot draw because a file was slow is not a desktop.
//
// ONE palette is not hand-written: "wallpaper" is derived from the image that
// is currently set. It is still an ordinary palette file in the ordinary
// folder, so nothing downstream knows the difference — and that is deliberate,
// because the alternative (a second search path for user palettes) was tried
// and broke loading for all eleven shipped palettes, twice.
//
// The derived palette is therefore both READ and WRITTEN through the single
// FileView below. Not two views on one path: that is the trap this project has
// now paid for three times. One object owns the file, so a read cannot race a
// write, and `watchChanges` carries the new colours through the whole shell in
// the same process.
//
// The cache is what makes a wallpaper survive a restart. On start the file is
// loaded like any other palette — colours are up instantly, with no flash of
// the fallback — and only if its `source` no longer names the wallpaper that
// is actually set does the image get re-read. Choosing a wallpaper writes one
// key in shell.json; everything else follows from that on the next start.

import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Singleton {
    id: root

    // Bound to the user's choice, not merely documented as such.
    //
    // This was a plain "everforest-dark" until M2, and the comment claimed
    // Config wrote it — nothing did. Changing theme.palette in shell.json was
    // therefore a no-op, and tests/all-palettes.sh passed vacuously: it loaded
    // Everforest eleven times and, because every palette's first accent is one
    // of the 26 names Everforest also defines, never saw the magenta sentinel.
    //
    // It stays a binding rather than a readonly alias so a headless tool can
    // still assign over it — an assignment breaks the binding, which is exactly
    // the escape hatch the old comment wanted.
    // ⚠️ `Config.theme` can be NULL, and this binding is one of the three that
    // proved it. JsonAdapter has a window during construction where the block
    // does not exist yet — see Config.qml's note on `settled`. A binding
    // re-evaluates once it does, so the guard costs a frame of the fallback and
    // nothing else; without it the binding throws and QML keeps whatever the
    // property had, which is the empty string.
    // ⚠️ THE LIGHT/DARK SWITCH DECIDES HERE, not in a service. `name` is the one
    // place the palette is chosen, and a service that wrote `theme.palette`
    // instead would DESTROY the dark one every morning — there would be nothing
    // left to switch back to. Nothing is written at all; the choice is a
    // binding, so it survives a restart with no state to keep in step.
    //
    // It also avoids a circle: services/ import theme/, so a Scheme that
    // imported a service back would close one, and this project's failure mode
    // for that is "Type Config unavailable" with a stack naming the wrong file.
    readonly property bool lightNow:
        Config.theme && Config.theme.autoLight === "schedule" && root._withinLight

    property string name: {
        if (!Config.theme) return "everforest-dark"
        var n = root.lightNow ? Config.theme.lightPalette : Config.theme.palette
        return n || "everforest-dark"
    }

    // ---------------------------------------------------------- the schedule
    // ⚠️ ONE TIMER, SET TO THE NEXT BOUNDARY — never an hourly wake-up. The
    // laptop rule this project is held to: a machine that wakes sixty times a
    // day to ask "is it seven yet" is doing the work of one alarm clock badly.
    // After each switch the timer is set again from the new time.
    //
    // ⚠️ And it is not running at all while `autoLight` is off, so the ordinary
    // case costs nothing.
    property bool _withinLight: false
    property int _tick: 0        // bumped by the timer to re-evaluate the clock

    function _minutesOf(hhmm) {
        var m = /^(\d{1,2}):(\d{2})$/.exec(String(hhmm || ""))
        if (!m) return -1
        var h = parseInt(m[1]), mi = parseInt(m[2])
        return (h >= 0 && h < 24 && mi >= 0 && mi < 60) ? h * 60 + mi : -1
    }

    function _recompute() {
        if (!Config.theme || Config.theme.autoLight !== "schedule") {
            root._withinLight = false
            boundary.stop()
            return
        }
        var from = root._minutesOf(Config.theme.lightFrom)
        var until = root._minutesOf(Config.theme.lightUntil)
        // A time we cannot read is not a reason to guess at one: stay dark and
        // stop, rather than switching at some hour nobody asked for.
        if (from < 0 || until < 0 || from === until) {
            root._withinLight = false
            boundary.stop()
            return
        }
        var now = new Date()
        var mins = now.getHours() * 60 + now.getMinutes()
        // Wrapping is normal: "light from 19:00 until 07:00" is a legitimate
        // way to say it, and treating it as an error would be a rule nobody
        // expects.
        root._withinLight = from < until ? (mins >= from && mins < until)
                                         : (mins >= from || mins < until)
        var next = root._withinLight ? until : from
        var delta = next - mins
        if (delta <= 0) delta += 24 * 60
        // Plus a few seconds, so the timer cannot land a hair BEFORE the minute
        // it is waiting for and immediately re-arm for the same one.
        boundary.interval = delta * 60000 + 5000
        boundary.restart()
    }

    Timer {
        id: boundary
        repeat: false
        onTriggered: root._recompute()
    }

    // ⚠️ A BINDING ON THE VALUES, NOT `Config.onSettledChanged`. That was the
    // first attempt and it fires ONCE, when the file first settles — so editing
    // the schedule changed nothing until the next restart. Measured: mode
    // switched to "schedule" with a window covering the current minute, and
    // gtk-theme stayed adw-gtk3-dark.
    //
    // Concatenating the three into one string gives a single change signal that
    // fires whenever any of them moves, which is exactly when the schedule has
    // to be worked out again.
    readonly property string _sched: Config.theme
        ? (Config.theme.autoLight + "|" + Config.theme.lightFrom
           + "|" + Config.theme.lightUntil)
        : ""
    on_SchedChanged: root._recompute()
    Component.onCompleted: root._recompute()

    // Honest readiness: the data is what matters, not the file object's state
    // — and it must be the data for the palette we are asking about NOW.
    //
    // Checking only `_data.colors` had a race: `name` is bound to the config,
    // so it changes from the default to the user's choice a few milliseconds
    // in. Between those two moments the old palette's data is still loaded and
    // `ready` would say true while `name` already named a different palette.
    // Anything that sampled it there wrote one palette's colours under another
    // palette's name.
    readonly property bool ready: !!_data.colors && _loadedName === root.name
    property string _loadedName: ""

    // Why it is not ready, for a tool that has to explain itself rather than
    // exit quietly. Empty while everything is fine.
    property string failure: ""
    readonly property var colors: _data.colors || fallback
    readonly property string family: _data.family || "Everforest"
    readonly property string displayName: _data.display_name || root.name
    readonly property bool dark: _data.dark !== undefined ? _data.dark : true
    readonly property var accents: _data.accents || ["green"]

    property var _data: ({})


    // ------------------------------------------------------ derived palette
    //
    // Three palettes are GENERATED rather than shipped, and they all come out
    // of the same function in FromImage — only the seed differs:
    //
    //   "wallpaper"  the seed is quantised out of the current image
    //   "custom"     the seed IS theme.customColor
    //   "neutral"    the seed has saturation 0, so the ramps come out grey
    //
    // They share everything below: the same cache file shape, the same guards,
    // the same "is what is on disk still valid" test. What separates them is
    // one line in `_maybeDerive()` — wallpaper has to read an image and is
    // therefore asynchronous, the other two are a calculation.
    readonly property bool derivedFromImage: root.name === "wallpaper"
    readonly property bool derivedFromColour: root.name === "custom"
    readonly property bool derivedNeutral: root.name === "neutral"
    readonly property bool derived: derivedFromImage || derivedFromColour
                                    || derivedNeutral

    // What the palette SHOULD be built from, and what the loaded file actually
    // was built from. Bindings on purpose: a function reading Config here would
    // run before JsonAdapter had pushed the parsed values in and would compare
    // against an empty string.
    //
    // For the two calculated modes the "source" is not a file but the input
    // itself — the colour, or the constant "neutral". Same comparison, same
    // cache invalidation, no second mechanism.
    // ⚠️ `paletteFrom` WINS WHEN IT IS SET, and it exists so a slideshow can
    // change the picture without repainting the desktop. Every picture change
    // recalculates all 26 colours and every foreign application's config;
    // pinning the derivation to one image is what makes "change the picture,
    // keep the colours" possible at all. Empty — which is the normal state and
    // what choosing a wallpaper by hand restores — means the one on screen.
    readonly property string paletteSource:
        (Config.wallpaper && String(Config.wallpaper.paletteFrom).length)
            ? String(Config.wallpaper.paletteFrom)
            : String(Config.wallpaper.current)

    readonly property string wantedSource:
        root.derivedFromImage ? root.paletteSource
      : root.derivedFromColour ? String(Config.theme.customColor)
      : root.derivedNeutral ? "neutral"
      : ""
    readonly property string loadedSource: _data.source ? String(_data.source) : ""

    // Two guards, each against a loop that would otherwise be silent:
    //   _deriving — a derivation is in flight for this image
    //   _refused  — this image cannot make a readable scheme, so trying again
    //               on every property change would spin forever
    property string _deriving: ""
    property string _refused: ""

    // Light or dark is the USER's decision, never the image's: a bright photo
    // must not turn a dark desktop light. ⚠️ The light/dark switch DOES exist
    // now (`theme.autoLight`, evaluated as `lightNow` 150 lines above this) —
    // this comment claimed otherwise while the code beneath it did the work.
    // What stays true is the rule:
    // that is an M8 setting — so the direction comes from the cached palette,
    // and from the project default the very first time.
    readonly property bool _deriveDark: _data.dark !== undefined ? _data.dark : true

    function _maybeDerive() {
        if (!root.derived)
            return
        // Before the config has settled there is nothing to decide: an empty
        // wallpaper.current at this point means "not read yet", not "unset",
        // and reporting it as a fault would make every tool start by
        // announcing a problem it is about to not have.
        if (!Config.settled)
            return

        var src = root.wantedSource
        if (!src.length) {
            // Only a fault when there is nothing to fall back on. A cached
            // derived palette with no wallpaper currently set is what a
            // headless tool run sees, and it is perfectly usable.
            if (!root._data.colors)
                root.failure = root.derivedFromColour
                    ? "theme.palette is \"custom\" but theme.customColor is empty"
                    : "theme.palette is \"wallpaper\" but no wallpaper is set"
            return
        }
        // The cache already describes this source, or we are already busy with
        // it, or it has been tried and refused.
        if (src === root.loadedSource || src === root._deriving || src === root._refused)
            return

        // A new attempt clears the last complaint, so a stale message cannot be
        // read as the outcome of the work that is only just starting.
        root.failure = ""
        root._deriving = src

        // ⚠️ THE TWO CALCULATED MODES DO NOT GO THROUGH THE QUANTISER, and it
        // is not an optimisation — a colour is already a seed. Sending them
        // round the image path would mean setting `quant.source` to something
        // that is not an image and then waiting 1800 ms for a timer that exists
        // only because the quantiser lies on its first signal.
        if (root.derivedFromColour || root.derivedNeutral) {
            _finish(root.derivedNeutral
                    ? FromImage.neutral(root._deriveDark, 0)
                    : FromImage.fromColour(Qt.color(src), root._deriveDark,
                                           root.name),
                    src)
            return
        }

        quant.source = src
        settle.restart()
    }

    // Everything that happens once a palette object exists, whichever way it
    // was built. It was inline in the timer while there was only one way in.
    function _finish(pal, src) {
        root._deriving = ""

        var why = pal ? FromImage.usable(pal) : "no palette was built"
        if (why.length) {
            // Leaving the previous scheme in place is the right answer.
            root._refused = src
            root.failure = "palette refused: " + why
            return
        }

        root.failure = ""

        // ⚠️ THE PALETTE IS ADOPTED HERE, NOT WHEN THE FILE COMES BACK.
        //
        // This used to write the file and wait: the write triggers
        // onFileChanged → reload → onLoaded, which parses it back and sets
        // `_data`. That is one round trip through the filesystem's change
        // notification for a value we are holding in our hand, and it is not
        // guaranteed to arrive. In the CI container it did not: every headless
        // wallpaper run ended in "ABORT: the palette was not derived in time"
        // after the full twelve seconds, with the palette sitting correctly on
        // disk the whole time. Red for weeks, green on every machine it was run
        // on by hand — the write worked, the notification about our own write
        // did not.
        //
        // So the object is adopted directly and the file is what it always
        // should have been: how the next start finds it, not how this one does.
        // A reload that arrives afterwards parses the same bytes and changes
        // nothing.
        root._data = pal
        root._loadedName = root.name
        file.setText(JSON.stringify(pal, null, 2) + "\n")
    }

    onWantedSourceChanged: _maybeDerive()
    onDerivedChanged: _maybeDerive()

    // ------------------------------------------------- one colour from the image
    //
    // ⚠️⚠️ A SECOND QUANTISER, AND IT IS NOT A COPY OF THE ONE ABOVE. That one
    // answers "what are all 26 colours of this picture" and only runs when the
    // PALETTE is derived from an image. This answers "what is the one colour to
    // accent with", and it runs whenever `theme.accentSource` is "wallpaper" —
    // which is the case the black default was made for: the scheme stays black
    // and plain, and the accent follows the picture.
    //
    // Sharing one instance was tried on paper and refused: the two want
    // different sources at different moments (`paletteFrom` pins the palette's
    // image so a slideshow does not repaint the desktop, while the accent is
    // meant to follow the picture actually on screen), and a quantiser that
    // serves two masters needs a mode flag whose two states are exactly these
    // two blocks. Two small blocks that each say what they are beat one that
    // asks which mode it is in.
    //
    // ⚠️ IT COSTS NOTHING WHILE THE SETTING IS OFF. `accentWanted` is false, no
    // source is ever assigned, and ColorQuantizer with no source does no work.
    readonly property bool accentFromImage:
        !!Config.theme && String(Config.theme.accentSource) === "wallpaper"

    readonly property string accentSourceImage:
        (root.accentFromImage && Config.wallpaper)
            ? String(Config.wallpaper.current) : ""

    // The accent, as "#rrggbb". Empty until an image has been read — Theme.qml
    // falls back to the palette's own accent while it is, because a surface
    // painted with "" shows the magenta sentinel.
    property string imageAccent: ""
    property string _accentFrom: ""

    onAccentSourceImageChanged: root._maybeAccent()
    onAccentFromImageChanged: root._maybeAccent()

    function _maybeAccent() {
        if (!Config.settled)
            return
        if (!root.accentFromImage) {
            root.imageAccent = ""
            root._accentFrom = ""
            return
        }
        var src = root.accentSourceImage
        if (!src.length || src === root._accentFrom)
            return
        root._accentFrom = src
        accentQuant.source = src
        accentSettle.restart()
    }

    ColorQuantizer {
        id: accentQuant
        rescaleSize: 64
        depth: 4
    }

    Timer {
        id: accentSettle
        // ⚠️ THE SAME 1800 ms AND THE SAME REASON, written out because the two
        // blocks are read separately: the quantiser emits once with the
        // PREVIOUS image's colours when a new source is set. Reading on
        // `colorsChanged` looked like twelve wallpapers producing six schemes.
        interval: 1800
        onTriggered: {
            if (!root.accentFromImage)
                return
            var cols = accentQuant.colors
            if (!cols || cols.length === 0) {
                // No complaint and no change: the palette's own accent is
                // already on screen and is a perfectly good answer. A failure
                // message for a decoration would be noise.
                root.imageAccent = ""
                return
            }
            // The same seed the palette derivation uses — most saturated at a
            // middling lightness, rather than the single brightest pixel — so
            // "the accent from this picture" means one thing in both places.
            var seed = FromImage.seedOf(cols)
            // ⚠️ THE IMAGE'S HUE, OUR OWN LIGHTNESS. A photograph's own
            // saturation and lightness are whatever the photograph is: a dark
            // forest gives an accent that cannot be seen on a black surface,
            // and a snow scene gives one that cannot be read against white
            // text. The hue is what the picture has to say; the rest is what
            // makes it usable, and it is the same pastel range black.json
            // ships with.
            // ⚠️ THROUGH `_hex`, because `_tone` hands back a colour OBJECT
            // and this property is a string. Assigning the object coerces it to
            // something Qt.color cannot read back, which paints the sentinel.
            root.imageAccent =
                FromImage._hex(FromImage._tone(seed.h, 0.45, root.dark ? 0.72 : 0.42))
        }
    }

    ColorQuantizer {
        id: quant
        // 64 is plenty: the seed is a hue, and a hue does not get truer with
        // more pixels. Measured at ~40 ms for a 6000x3750 image.
        rescaleSize: 64
        depth: 4
    }

    Timer {
        id: settle
        // ⚠️ Read after a wait, never on `colorsChanged`. The quantiser emits
        // once with the PREVIOUS image's colours when a new source is set —
        // measured, and it looked like twelve wallpapers producing six schemes.
        interval: 1800
        onTriggered: {
            var src = root._deriving
            if (!src.length || src !== root.wantedSource) {
                root._deriving = ""
                return          // the user moved on while we were working
            }

            if (!quant.colors || quant.colors.length === 0) {
                root._deriving = ""
                root._refused = src
                root.failure = "no colours came back from " + src +
                               " — is the format supported? (this Qt has no WebP and no TIFF plugin)"
                return
            }

            // Everything from here on is the same for all three modes, so it
            // lives in _finish() rather than being written out twice.
            root._finish(FromImage.build(quant.colors, root._deriveDark,
                                         "wallpaper", src), src)
        }
    }

    // Everforest Dark, inlined. Not a second source of truth — a raft. If the
    // palette file is missing or malformed the shell still has readable
    // colours, and `ready` stays false so the settings UI can say so.
    readonly property var fallback: ({
        "rosewater": "e69875", "flamingo": "e69875", "pink": "d699b6",
        "mauve": "d699b6", "red": "e67e80", "maroon": "e67e80",
        "peach": "e69875", "yellow": "dbbc7f", "green": "a7c080",
        "teal": "83c092", "sky": "83c092", "sapphire": "7fbbb3",
        "blue": "7fbbb3", "lavender": "d699b6", "text": "d3c6aa",
        "subtext1": "9da9a0", "subtext0": "859289", "overlay2": "7a8478",
        "overlay1": "56635f", "overlay0": "4f585e", "surface2": "475258",
        "surface1": "3d484d", "surface0": "343f44", "base": "2d353b",
        "mantle": "232a2e", "crust": "232a2e"
    })

    // "#rrggbb" for a semantic name, with the fallback behind it so a palette
    // that is missing a key degrades to a colour instead of to `undefined`,
    // which QML would render as black.
    // What `hex()` answers for a name it does not know. Magenta because it is
    // impossible to miss in a screenshot — and a named property rather than a
    // literal in two places, so a test can ask "did anything come back unknown"
    // without typing the colour again. tests/smoke.sh does exactly that.
    readonly property string unknown: "#ff00ff"

    function hex(key) {
        var c = root.colors[key] || root.fallback[key]
        return c ? "#" + c : root.unknown
    }

    function color(key) { return Qt.color(hex(key)) }

    // Every palette that ships, for the settings window and `bhctl theme`.
    // Read from disk rather than listed here — a list would go stale the first
    // time somebody adds a file.
    readonly property list<string> available: dir.text().trim().length
        ? dir.text().trim().split("\n") : [root.name]

    // ⚠️ THE DERIVED PALETTE IS NOT A REPOSITORY FILE. It used to be written to
    // theme/palettes/wallpaper.json inside the shell tree, next to the eleven
    // palettes that ship — which put generated user state into a source
    // checkout. `git pull`, `git clean`, or any deploy that mirrors the tree
    // deletes it, and the desktop silently loses its colours. Measured, not
    // theorised: an rsync --delete of shell/ during this session wiped it and
    // the next start came up on the fallback.
    //
    // XDG_STATE_HOME, not cache: it has to survive a reboot (that was tested
    // for M3.5 and is a promise now), and a cache is something a cleaner is
    // entitled to empty.
    //
    // One file per generated mode, named after the mode: they have different
    // sources and must not overwrite each other, or switching from a custom
    // colour back to the wallpaper would re-derive the image every time.
    readonly property string stateDir:
        (Quickshell.env("XDG_STATE_HOME")
         || (Quickshell.env("HOME") + "/.local/state")) + "/buchhwin"

    // ⚠️ ONE expression, not a chain, and that is a bug fix rather than a
    // style. It was `derived ? derivedPath : shellPath(name)` with
    // `derivedPath` separately built from `name` — three bindings that update
    // in an order QML does not promise. Switching from everforest-dark to
    // custom therefore wrote the freshly calculated custom palette into
    // `<state>/everforest-dark.json`: `derived` had already turned true while
    // the path still carried the old name. Measured, not reasoned about — the
    // file was on disk with `"name": "custom"` inside it.
    //
    // Written out per mode rather than interpolated, so a palette that ships
    // can never resolve into the state directory by accident.
    readonly property string palettePath:
        root.derivedFromImage ? stateDir + "/wallpaper.json"
      : root.derivedFromColour ? stateDir + "/custom.json"
      : root.derivedNeutral ? stateDir + "/neutral.json"
      : Quickshell.shellPath("theme/palettes/" + root.name + ".json")

    FileView {
        id: file
        path: root.palettePath
        watchChanges: true
        // Loud on purpose. This failing silently is exactly how the whole
        // desktop ran on fallback colours without anyone noticing.
        //
        // The one exception is the derived palette: it is GENERATED, not
        // shipped, so on a machine that has never had a wallpaper set the file
        // is legitimately absent. Shouting about that would train everyone to
        // ignore the message that matters.
        printErrors: !root.derived
        onFileChanged: reload()
        onLoaded: {
            try {
                root._data = JSON.parse(text())
                root._loadedName = root.name
                root.failure = ""
                // The cache may describe a wallpaper that is no longer set.
                root._maybeDerive()
            } catch (e) {
                // A palette that is present but malformed is a different fault
                // from one that is missing, and the difference is what someone
                // needs in order to fix it.
                root._data = ({})
                root._loadedName = ""
                root.failure = "palette '" + root.name + "' is not valid JSON: " + e
            }
        }
        onLoadFailed: {
            root._data = ({})
            root._loadedName = ""
            if (root.derived) {
                // Not a fault: it has simply never been built. Build it.
                root._maybeDerive()
            } else {
                root.failure = "palette '" + root.name + "' could not be read from " + path
            }
        }
    }

    // Written by the installer (a plain `ls` of the palette folder). Absent on
    // a source checkout, which is normal and not worth a warning on every
    // start — hence printErrors off.
    FileView {
        id: dir
        path: Quickshell.shellPath("theme/palettes/index.txt")
        printErrors: false
    }
}
