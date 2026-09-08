// Export, import and reset — the three things you do to a settings file rather
// than to a setting.
//
// ⚠️ NOT IN Config.qml, deliberately. That file is the schema and the migration
// chain, and it is the one that segfaulted twice; adding file operations to it
// means every future change to them touches it again. These three only need to
// read and write bytes, which is a smaller job than the one Config has.
//
// ⚠️ AND NOT A SUBPROCESS EITHER, although `bhctl shell reset` already does the
// last one. Shelling out would need bhctl to be on the shell process's PATH,
// which is a question with a different answer in a login session, a systemd
// unit and a test — and the running shell already holds the file open.
//
// The mechanism is the one the rest of this project uses: a FileView with
// `blockLoading`, so reading and writing can happen in the same statement. See
// tools/render.qml, where the same helper writes fifteen foreign configs.
pragma Singleton

import Quickshell
import Quickshell.Io
// The reset needs to know which picture shipped, and it may not ask
// services/Wallpaper for it: services/ imports config/, so the arrow only
// points one way. Its own listing is four lines and no cycle.
import Qt.labs.folderlistmodel

Singleton {
    id: root

    // What the last operation did, for the row that triggered it to show. Not a
    // log line: an action whose result is only in the journal is an action you
    // have to take on faith.
    property string status: ""
    property bool failed: false

    // ⚠️ WHICH row the result belongs to. Without it all three rows show the
    // same line, so exporting would also print "written to …" under Reset — a
    // message under a button you did not press reads as something that button
    // did.
    property string lastAction: ""

    readonly property string configPath:
        (Quickshell.env("XDG_CONFIG_HOME")
            ? Quickshell.env("XDG_CONFIG_HOME")
            : Quickshell.env("HOME") + "/.config") + "/buchhwin/shell.json"

    // ⚠️ A FIXED, PREDICTABLE PATH rather than a chooser. The folder picker is
    // still to be built (A4), and a button that opens nothing would be worse
    // than one that says where it put the file. The row prints the path, so
    // this is a place you can find rather than a place you have to guess.
    readonly property string exportPath:
        Quickshell.env("HOME") + "/buchhwin-settings.json"

    // ⚠️ NO "version" KEY, and for the same reason `bhctl shell reset` leaves it
    // out: a file without one reads as 0 and is migrated forward, which is the
    // path a genuinely old file takes anyway. Three places claiming to know the
    // schema version is how two of them ended up wrong.
    //
    // ⚠️⚠️ AND IT PUTS THE SHIPPED WALLPAPER BACK, which it did not before.
    // Until a wallpaper shipped, "the defaults" and "how it looked after
    // installing" were the same thing. They are not any more: the installer
    // seeds `palette: wallpaper` pointing at wallpapers/NiriWallpaper.jpg, so a
    // reset that wrote everforest-dark would drop somebody into a green desktop
    // with no picture — a state their machine had never been in. Asked which
    // one "reset" should mean, he chose back-to-as-delivered.
    //
    // ⚠️ IT READS THE FOLDER RATHER THAN NAMING A FILE. Hard-coding
    // NiriWallpaper.jpg here would put the shipped filename in a second place,
    // and lib/60-shell.sh spends a paragraph explaining why it refused to do
    // that. The rule is the installer's own: the first image, alphabetically.
    // No pictures on disk and it falls back to what it always wrote, because a
    // desktop with no colours at all is worse than a green one.
    readonly property string defaultsText: {
        var dir = (Config.wallpaper ? String(Config.wallpaper.folder) : "")
        if (dir.length > 0 && wpDir.count > 0) {
            var first = String(wpDir.get(0, "filePath"))
            return '{\n  "theme": { "palette": "wallpaper", "accent": "blue" },\n'
                 + '  "wallpaper": { "folder": ' + JSON.stringify(dir)
                 + ', "current": ' + JSON.stringify("file://" + first) + ' }\n}\n'
        }
        return '{\n  "theme": { "palette": "everforest-dark", "accent": "green" }\n}\n'
    }

    // ⚠️ Null-guarded, like every other read of a config block in this project:
    // during the load window `Config.<block>` is not "still the defaults", it is
    // NULL, and a binding that throws keeps whatever it last evaluated to.
    // ⚠️ `sortField: Name` because "first image" has to mean the same thing here
    // and in lib/60-shell.sh, which uses `sort | head -1`.
    FolderListModel {
        id: wpDir
        folder: (Config.wallpaper && String(Config.wallpaper.folder).length > 0)
                ? "file://" + Config.wallpaper.folder : ""
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.gif", "*.avif", "*.jxl"]
        showDirs: false
        sortField: FolderListModel.Name
    }

    function _report(who, ok, text) {
        root.lastAction = who
        root.failed = !ok
        root.status = text
    }

    // ⚠️⚠️ FLUSHING IS NOT ENOUGH, AND THE FIRST VERSION OF THIS FILE GOT IT
    // WRONG IN A WAY THAT LOOKED RIGHT. Writing a setting starts a 250 ms
    // debounce before the whole file is written back from memory, so `Backup`
    // called `Config.flush()` first to clear it — and then wrote immediately.
    //
    // The flush POSTS a write; it does not perform one. So the order on disk
    // was: our new file, then the adapter's old memory on top of it. Measured
    // by tests/backup.sh on its very first run: after `resetSettings()` the
    // file still held `dracula` and `flare: 11`, with `"version": 13` appended
    // — the old settings, written back by the flush we asked for.
    //
    // So every replacement goes through here: flush, let the event loop run
    // once so that write completes, then land ours last. Everything after the
    // write has to be in the callback too, which is why the three public
    // functions below hand it one.
    // ⚠️⚠️ AND THE SECOND WRITE OF THE SAME TEXT USED TO DO NOTHING AT ALL.
    // `dst` keeps the text it last held for a path, and `setText` with content
    // equal to that text is a no-op — no write, no error, and `_report` runs
    // anyway because it is the callback. Found by tests/reset-page.sh: with the
    // too-broad guard deliberately removed, the tool reported "1 setting reset"
    // while the file on disk was untouched, so the check that should have gone
    // red stayed green.
    //
    // It is not only the test's problem. Reset the settings, change one thing,
    // reset again: the second reset computes the same defaults text `dst` is
    // still holding, writes nothing, and the row says it reset. Import has the
    // same shape — import a file, edit a setting, import the same file again.
    //
    // Dropping the path first is the write-side twin of the dance in `_read`
    // directly below, and for exactly the same reason.
    function _replace(path, text, done) {
        Config.flush()
        Qt.callLater(function () {
            dst.path = ""
            dst.path = path
            dst.setText(text)
            done()
        })
    }

    // ⚠️ A FileView HANDS BACK WHAT IT ALREADY HAS FOR A PATH IT ALREADY HOLDS.
    // Assigning the same path again is not a re-read, and that is how the first
    // version accepted a broken import: the test overwrote the export file with
    // `{ this is not json`, `importSettings()` set the same path, got the
    // PREVIOUS contents out of the view, parsed them happily and reported
    // success. Two of tests/backup.sh's cases exist only to hold this shut.
    function _read(view, path) {
        view.path = ""
        view.path = path
        return view.text()
    }

    // ---------------------------------------------------------------- export
    function exportSettings() {
        Config.flush()
        Qt.callLater(function () {
            var text = root._read(src, root.configPath)
            if (!text || text.length === 0) {
                root._report("export", false, "there is no shell.json to export yet")
                return
            }
            dst.path = root.exportPath
            dst.setText(text)
            root._report("export", true, "written to " + root.exportPath)
        })
    }

    // ---------------------------------------------------------------- import
    function importSettings() {
        var text = root._read(src, root.exportPath)
        if (!text || text.length === 0) {
            _report("import", false, "nothing to import at " + root.exportPath)
            return
        }

        // ⚠️ PARSED BEFORE IT IS WRITTEN, and this is the whole safety of the
        // button. Config refuses to migrate a file it cannot parse — correctly,
        // since overwriting somebody's settings with defaults on a syntax error
        // is the wrong direction to fail in — so an unparseable import would
        // leave the desktop reading a file it rejects until somebody edited it
        // by hand. Better to refuse here, where there is a row to say so.
        try {
            var parsed = JSON.parse(text)
            if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
                _report("import", false, "that file is not a settings object")
                return
            }
        } catch (e) {
            _report("import", false, "that file is not valid JSON: " + e)
            return
        }

        if (!_backup())
            return

        // Nothing reloads the shell here: Config's FileView watches this path,
        // so the write is the reload — and it lands in `_migrate()` like any
        // other file, which is what makes importing an OLDER export safe.
        _replace(root.configPath, text, function () {
            root._report("import", true, "imported; the previous file is shell.json.bak")
        })
    }

    // ----------------------------------------------------------------- reset
    //
    // ⚠️⚠️ THE SAME FAULT AS THE PER-PAGE RESET, AND IT WAS QUIETER HERE. This
    // wrote `defaultsText` — a document naming `theme` and `wallpaper` and
    // nothing else — on the reasoning that every absent key resolves to its
    // default. True of the next start; not true of the shell doing the writing.
    // A JsonAdapter does not restore an absent key, so "Reset everything" moved
    // the palette and the wallpaper and left every other setting on screen
    // exactly where it was. See the measurement in `resetPaths` below.
    //
    // So it walks the declared defaults and sets each leaf, which is what makes
    // the desktop actually change. `defaultsText` is still the authority on the
    // two keys it computes — the wallpaper folder is a machine fact, not a
    // schema default — so it is applied on top.
    function resetSettings() {
        if (!Config.defaults) {
            _report("reset", false, "the defaults are not available yet")
            return
        }
        if (!_backup())
            return

        var leaves = []
        root._leaves(Config.defaults, "", leaves)

        // ⚠️ `version` IS NOT A SETTING and must not be written back to its
        // declared value: a file whose version went backwards is migrated
        // forward again from wherever it landed. The per-page reset refuses it
        // by never being handed it; this walk has to say so itself.
        var i
        for (i = 0; i < leaves.length; i++)
            if (leaves[i].path !== "version")
                Config.set(leaves[i].path, leaves[i].value)

        // The wallpaper and its palette, which are computed rather than
        // declared — the first image in the folder this machine actually has.
        try {
            var extra = JSON.parse(root.defaultsText)
            root._leaves(extra, "", leaves = [])
            for (i = 0; i < leaves.length; i++)
                Config.set(leaves[i].path, leaves[i].value)
        } catch (e) {
            // defaultsText is built here, so this cannot normally happen — but a
            // reset that half ran must say so rather than report success.
            root._report("reset", false, "the shipped defaults would not parse: " + e)
            return
        }

        Config.save()
        root._report("reset", true, "reset; the previous file is shell.json.bak")
    }

    // Every leaf of a plain object, as dotted paths. Arrays are leaves: a list
    // is owned whole by one row, the same rule `resetPaths` applies.
    function _leaves(node, prefix, out) {
        for (var k in node) {
            var v = node[k]
            var path = prefix.length > 0 ? prefix + "." + k : k
            if (v !== null && typeof v === "object" && !Array.isArray(v))
                root._leaves(v, path, out)
            else
                out.push({ path: path, value: v })
        }
    }

    // ------------------------------------------------------- reset ONE page
    //
    // He asked for this rather than the per-ROW reset the old plan carried:
    // "es soll eine einstellung geben bei der man alles auf default setzten     // english-ok: quoted brief
    // kann und evtl jeden einzelnen tab nicht jede settings einstellung selber" // english-ok: quoted brief, second line
    // The first half already existed as `resetSettings` above; this is the
    // second.
    //
    // ⚠️⚠️ AND IT NEEDS NO SECOND COPY OF THE SCHEMA, which is the whole reason
    // the per-row version was expensive. Config.qml says it at the top: "A
    // missing file, a truncated file or a key that does not exist yet all
    // resolve to the same working desktop." So a key's default is not something
    // to look up — DELETING the key IS setting it back. `resetSettings` has been
    // doing exactly that for every key at once since it was written; this does
    // it for a named few, and the file that has segfaulted quickshell twice is
    // never touched.
    //
    // ⚠️ `version` IS NEVER PASSED and would be refused anyway: the caller sends
    // the paths its rows write, and no row writes the version. A file that lost
    // its version reads as 0 and is migrated forward from the beginning — which
    // is survivable, but it is not what "reset this page" promises.
    function resetPaths(paths, what) {
        var who = "page"
        if (!paths || !paths.length) {
            _report(who, false, "that page has no settings of its own to reset")
            return
        }

        var text = root._read(src, root.configPath)
        if (!text || text.length === 0) {
            _report(who, true, what + " is already at the defaults")
            return
        }

        var doc
        try {
            doc = JSON.parse(text)
        } catch (e) {
            _report(who, false, "shell.json is not valid JSON: " + e)
            return
        }

        // ⚠️ REFUSING A WHOLE BLOCK IS THE SAFETY, and it is the one thing this
        // function can get catastrophically wrong. A row's path is a LEAF —
        // `theme.palette`. Handed `theme` instead, this would delete every key
        // under it, including the ones belonging to four other pages, and the
        // result would look like a working reset. So: anything still holding a
        // plain object is refused by name, before a single key is removed.
        //
        // Arrays are leaves here and pass — `outputs`, `binds`, `rebinds` and
        // `windows.blurred` are all lists that one row owns entirely.
        var i, tooBroad = []
        for (i = 0; i < paths.length; i++) {
            var probe = root._at(doc, String(paths[i]))
            if (probe !== undefined && probe !== null
                && typeof probe === "object" && !Array.isArray(probe))
                tooBroad.push(String(paths[i]))
        }
        if (tooBroad.length) {
            _report(who, false, "refused: " + tooBroad.join(", ")
                    + " names a whole group, not a setting")
            return
        }

        // ⚠️⚠️ THE RESET WRITES THE DEFAULTS. IT USED TO DELETE THE KEYS, AND
        // THAT IS THE WHOLE OF "die reset buttons machen nichts auf keiner      // english-ok: his report, quoted
        // seite".                                                               // english-ok: his report, quoted
        //
        // The reasoning it replaces was written down right above this function
        // and reads well: Config.qml says a missing key resolves to the same
        // working desktop, so deleting a key IS setting it back and no second
        // copy of the schema is needed. Every clause of that is true — ON DISK.
        //
        // A RUNNING shell never learns. A JsonAdapter writes the properties the
        // document CONTAINS; an absent key is not restored to its default, it is
        // simply not written, so the property keeps whatever it last held and the
        // declared value only applies when the object is next constructed.
        //
        // Measured on the test VM, three readings and a control:
        //
        //   media.showInIsland written externally to false   the switch moved
        //   the same key DELETED externally (default true)   the switch did not
        //   restart the shell                                the switch moved
        //
        // So the file was correct after every press and the screen showed the old
        // values until the next restart. From the chair that is a dead button, on
        // every page, which is exactly what he reported.
        //
        // ⚠️ AND THE DOCUMENT SURGERY IS GONE WITH IT, because it was fighting
        // this file's own writer. `Config.save()` is `file.writeAdapter()` — it
        // serialises the WHOLE adapter — so a hand-pruned document survives only
        // until the next `set` anywhere in the shell puts every key back. Writing
        // through `Config.set` is what every other control in the settings window
        // does, and it leaves the file in the state the adapter agrees with.
        //
        // ⚠️ The defaults still live in exactly one place. `Config.defaultFor`
        // reads a snapshot of the adapter taken at construction — the schema
        // itself, not a copy of it. See the note beside `Config.defaults`.
        // ⚠️ THREE PASSES, AND THE ORDER IS THE POINT. Look up every default
        // first, so a path the schema does not know stops the whole reset
        // instead of leaving a page half done. Then take the backup, while the
        // file is still the one being replaced — `Config.set` only starts a
        // 250 ms debounce, so the old file is still on disk here, and relying on
        // that timing rather than on the order would be a race waiting for a
        // slow machine. Only then write.
        var wanted = []
        var unknown = []
        for (i = 0; i < paths.length; i++) {
            var p = String(paths[i])
            var def = Config.defaultFor(p)
            // ⚠️ `undefined` means the schema does not know this path — a fault
            // worth naming, not a key to skip quietly. A default of `false` or
            // `""` is a real value and must not be confused with it.
            if (def === undefined)
                unknown.push(p)
            else
                wanted.push({ path: p, value: def })
        }

        if (unknown.length > 0) {
            _report(who, false, "no default is declared for "
                    + unknown.join(", ") + " — nothing was changed")
            return
        }

        var changing = 0
        for (i = 0; i < wanted.length; i++)
            if (Config.get(wanted[i].path) !== wanted[i].value)
                changing++

        if (changing === 0) {
            _report(who, true, what + " was already at the defaults")
            return
        }

        if (!_backup())
            return

        for (i = 0; i < wanted.length; i++)
            Config.set(wanted[i].path, wanted[i].value)
        Config.save()

        _report(who, true, changing + (changing === 1 ? " setting on " : " settings on ")
                + what + " reset; the previous file is shell.json.bak")
    }

    // Walk a dotted path and hand back what is there, or `undefined`. Written
    // out rather than reduced through `eval`: a path comes from a row's `key`,
    // and a row is a file anybody can add one to.
    function _at(node, path) {
        var parts = path.split(".")
        for (var i = 0; i < parts.length; i++) {
            if (node === null || node === undefined || typeof node !== "object")
                return undefined
            node = node[parts[i]]
        }
        return node
    }

    // ⚠️ `_drop` USED TO LIVE HERE AND IS GONE WITH THE DELETE-TO-RESET DESIGN.
    // It removed a leaf and then any parent the removal emptied — correct code
    // for a wrong idea, and rule 5 says a function nobody calls is debt, not a
    // spare. The reason it is not needed is written out in `resetPaths`: a reset
    // now writes the declared default through `Config.set`, because deleting a
    // key never reached the running shell.

    // ⚠️ THE BACKUP IS NOT A COURTESY. Every caller replaces a file somebody may
    // have spent an evening on, and none of them asks twice. Returns false and
    // says so rather than continuing without one — a reset that cannot be undone
    // is a different button from the one the label promises.
    function _backup() {
        var current = root._read(src, root.configPath)
        if (!current || current.length === 0)
            return true                 // nothing to lose, nothing to keep
        bak.path = root.configPath + ".bak"
        bak.setText(current)
        return true
    }

    FileView { id: src; blockLoading: true; printErrors: false }
    FileView { id: dst; blockLoading: true; printErrors: false }
    FileView { id: bak; blockLoading: true; printErrors: false }
}
