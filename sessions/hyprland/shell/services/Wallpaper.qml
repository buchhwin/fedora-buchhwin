pragma Singleton

// The wallpaper: which images exist, which one is shown.
//
// The folder is listed with FolderListModel — pure QML, no shell command and no
// Process. Thumbnails must set Image.sourceSize so Qt decodes a 4K JPEG at
// thumbnail size instead of decoding it fully and then shrinking it; that is
// the difference between a picker that opens instantly and one that stutters.
//
// ⚠️ This Qt build has NO WebP and NO TIFF plugin (qt6-qtimageformats is not
// installed). A .webp wallpaper fails to load SILENTLY — hence `supported`,
// so the picker can leave it out rather than showing an empty tile.
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import "../config"
// ⚠️ B75 needs to know which screen the pointer is on. Without this import the
// expression would read `undefined` and QML would say nothing at all — the
// per-screen assignment would silently fall through to the global one.
import "." as Services

Singleton {
    id: root

    readonly property string folder: Config.wallpaper.folder
    readonly property string current: Config.wallpaper.current

    // ⚠️⚠️ B75 · WHAT ONE SCREEN SHOWS. `current` above is still the answer for
    // the whole desktop; this is the answer for a named output, and every
    // surface asks through here rather than reading the config itself. One
    // reader, so "which picture is on that wall" cannot be answered two ways.
    //
    // An empty assignment list means one picture everywhere, which is both the
    // default and what most machines stay on. A screen that is not named — one
    // plugged in after the assignments were made — falls back to `current`
    // rather than to nothing: a black rectangle on a new monitor reads as a
    // broken desktop, not as an unset preference.
    function forScreen(name) {
        var list = Config.wallpaperPerScreen
        if (list && list.length) {
            for (var i = 0; i < list.length; i++) {
                var e = list[i]
                if (e && String(e.name) === String(name)
                      && String(e.image || "").length)
                    return String(e.image)
            }
        }
        return root.current
    }

    // Assign a picture to one screen, or clear it with an empty url.
    //
    // ⚠️ IT REWRITES THE WHOLE LIST rather than mutating an entry in place. A
    // JsonAdapter hands back a WRAPPER, and mutating one of those is the exact
    // shape that used to segfault quickshell — the note is in ERFAHRUNG and in
    // Backup._write, which learned it first.
    function setForScreen(name, url) {
        var old = Config.wallpaperPerScreen || []
        var next = []
        for (var i = 0; i < old.length; i++) {
            var e = old[i]
            if (!e || String(e.name) === String(name))
                continue
            next.push({ name: String(e.name), image: String(e.image || "") })
        }
        if (String(url || "").length)
            next.push({ name: String(name), image: String(url) })
        Config.set("wallpaperPerScreen", next)
        Config.save()
    }

    // Back to one picture for everything — the switch's "All screens" position.
    function clearPerScreen() {
        Config.set("wallpaperPerScreen", [])
        Config.save()
    }
    readonly property bool available: folder.length > 0 && dir.count > 0

    // Formats this Qt actually has a plugin for. JPEG/PNG/GIF come from
    // qt6-qtbase-gui; AVIF/HEIF/JXL from kf6-kimageformats when installed.
    readonly property var supported: ["jpg", "jpeg", "png", "gif", "avif", "jxl", "webp"]

    readonly property int count: dir.count

    // ⚠️ The role is `fileUrl`, NOT `fileURL`. Qt 6 renamed it, and asking for
    // the old name does not fail — it returns `undefined`, which becomes the
    // empty string here. Measured: every image in a folder of twelve came back
    // as "", so choosing a wallpaper would have stored nothing at all and the
    // picker would have looked merely unresponsive.
    function pathAt(i) {
        var u = dir.get(i, "fileUrl")
        return u ? String(u) : ""
    }

    function nameAt(i) {
        var n = dir.get(i, "fileName")
        return n ? String(n) : ""
    }

    // Where a given image sits in the listing, or 0 when it is not in the
    // folder at all — a wallpaper set by hand to a file somewhere else is
    // perfectly legal, and the picker should still open somewhere sensible
    // rather than refuse to place its cursor.
    function indexOf(url) {
        var want = String(url)
        for (var i = 0; i < dir.count; i++)
            if (root.pathAt(i) === want)
                return i
        return 0
    }

    // Choosing writes ONE key, and that is the whole persistence story: the
    // image on screen, the derived palette and every foreign application's
    // colours are all downstream of it, on this start and on the next one.
    //
    // ⚠️ AND IT CLEARS THE PIN. `paletteFrom` exists so a slideshow can change
    // the picture without repainting the desktop — but picking a wallpaper on
    // purpose is the one moment where you certainly do mean the colours too.
    // Leaving it set would make a deliberate choice the one case that did not
    // recolour, which is the opposite of what anybody would expect.
    // ⚠️⚠️ AND IT SWITCHES THE SCHEME BACK ON, WHICH IT DID NOT BEFORE. The
    // paragraph above says "the derived palette is downstream of it" — true
    // only while `theme.palette` says `wallpaper`. Pick any of the eleven fixed
    // palettes once and every later wallpaper change repaints nothing: the
    // picture swaps, the colours stay. That is exactly what he reported, in his
    // words, "das farbschema passt nicht dazu", and neither the picker nor any  // english-ok: his report, quoted
    // hint anywhere said the two had come apart or how to rejoin them.
    //
    // ⚠️ ONLY OUT OF A FIXED PALETTE, NEVER OUT OF `custom`. A colour he typed
    // in himself is a decision about colour; overruling it with a photograph
    // would be this function taking a choice off him rather than giving one
    // back. `wallpaper` stays `wallpaper`, so the common case writes nothing.
    // ⚠️⚠️ B75 · WHILE "PER SCREEN" IS ON, CHOOSING ASSIGNS TO THE SCREEN YOU ARE
    // ON. That is deliberately the SAME gesture as before — Mod+Shift+W, pick a
    // picture — rather than a second picker somewhere else. A per-monitor grid
    // in the settings window would be a second way to do one thing, which is
    // the duplication rule 6 is about, and it would drift from this one.
    //
    // "On" is not a flag: it is the assignment list having entries. The switch
    // on the settings page seeds that list from the current picture, so turning
    // it on changes nothing on screen and the next choice lands on one monitor.
    function choose(url) {
        var perScreen = (Config.wallpaperPerScreen || []).length > 0
        if (perScreen) {
            var here = String(Services.Compositor.activeOutput || "")
            if (here.length) {
                root.setForScreen(here, String(url))
                // ⚠️ The palette still follows the picture you just chose, on
                // the same reasoning as below: picking one on purpose is the
                // moment you mean the colours too. It is one palette for the
                // desktop either way — per-screen COLOUR schemes are not a
                // thing this shell has, and pretending otherwise would be a
                // half-feature.
                Config.wallpaper.paletteFrom = ""
                if (Config.theme && String(Config.theme.palette) !== "wallpaper"
                                 && String(Config.theme.palette) !== "custom")
                    Config.theme.palette = "wallpaper"
                Config.save()
                return
            }
        }
        Config.wallpaper.current = String(url)
        Config.wallpaper.paletteFrom = ""
        if (Config.theme && String(Config.theme.palette) !== "wallpaper"
                         && String(Config.theme.palette) !== "custom")
            Config.theme.palette = "wallpaper"
        Config.save()
    }

    // ------------------------------------------------------------- slideshow
    //
    // ⚠️ THE TIMER RUNS ONLY WHEN THE SLIDESHOW IS ON, and `running` says so in
    // one expression rather than a start/stop pair that can drift apart. With
    // it off there is no timer, which is the standard this project holds itself
    // to: nothing happens at idle.
    //
    // ⚠️ AND IT IS MINUTES, NOT SECONDS. A one-second interval typed into a
    // seconds field would swap the wallpaper sixty times a minute, and each
    // swap decodes a photograph.
    function advance() {
        if (dir.count <= 1)
            return

        var here = root.indexOf(root.current)
        var next
        if (Config.wallpaper.shuffle) {
            // ⚠️ NEVER THE ONE ALREADY SHOWING. A shuffle that can pick the
            // current picture looks like a slideshow that sometimes stops.
            next = here
            for (var tries = 0; tries < 8 && next === here; tries++)
                next = Math.floor(Math.random() * dir.count)
            if (next === here)
                next = (here + 1) % dir.count
        } else {
            next = (here + 1) % dir.count
        }

        // Pin the colours to the picture that is leaving, so the desktop keeps
        // the scheme it had when the slideshow started. Written once — after
        // that `paletteFrom` is already set and this does nothing.
        if (!Config.wallpaper.slideshowRecolour
            && String(Config.wallpaper.paletteFrom).length === 0)
            Config.wallpaper.paletteFrom = String(root.current)
        else if (Config.wallpaper.slideshowRecolour)
            Config.wallpaper.paletteFrom = ""

        Config.wallpaper.current = root.pathAt(next)
        Config.save()
    }

    Timer {
        running: Config.wallpaper.slideshow && root.available && dir.count > 1
        repeat: true
        // Clamped rather than trusted: the key is an int in a file somebody can
        // edit, and a 0 there would be a timer firing as fast as the loop runs.
        interval: Math.max(1, Config.wallpaper.intervalMinutes) * 60000
        onTriggered: root.advance()
    }

    FolderListModel {
        id: dir
        // An empty folder setting means "no wallpaper", not "the home
        // directory" — which is what an unset folder would otherwise list.
        folder: root.folder.length ? "file://" + root.folder : ""
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.gif", "*.avif", "*.jxl"]
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Name
    }

    readonly property var model: dir
}
