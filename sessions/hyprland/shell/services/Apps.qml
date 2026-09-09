pragma Singleton

// Every installed program, in the two columns the launcher shows.
//
// The list comes from Quickshell's own DesktopEntries — the freedesktop
// database every desktop reads — so there is no scanning, no cache to go stale
// and nothing to keep in step with dnf. It updates itself when a package is
// installed.
//
// ⚠️ THREE FILTERS, AND EACH ONE IS A BUG THIS PROJECT ALREADY PAID FOR:
//
//   * `noDisplay` entries are dropped. They are the ones that exist to own a
//     MIME type or to be started by another program, not to be picked out of a
//     menu — the predecessor's menu had 60 of them and a cleanup script to
//     delete them again.
//
//   * `entry.actions` is IGNORED, and it is the reason this note exists. An
//     action is a second entry point of the same program ("Compose a message",
//     "Open a private window"); listing them turned Evolution into twenty
//     lines in the old launcher. One program, one row.
//
//   * Categories are read as freedesktop MAIN categories only, first match
//     wins. Everything else in that field is either a toolkit marker (GTK, Qt,
//     KDE, GNOME, Java, Motif) or a vendor extension (X-*), and neither says
//     anything about what a program is FOR. Sorting by them produced a "GTK"
//     category with half the system in it.
//
// The plan asks for two pinned entries above the categories: All and Frequent.
// Frequent is counted here rather than guessed, because there is no other
// source for it — see the note on the usage file below.
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Singleton {
    id: root

    // A program list that is empty is a real state on a container or a broken
    // installation, and the launcher says so rather than showing an empty grid.
    readonly property bool available: root.apps.length > 0

    // ⚠️ THE ORDER IS THE MENU ORDER, and it is fixed rather than sorted: it
    // runs from what people reach for most to what they reach for least.
    // Alphabetical would put Development first and Utility last for no reason
    // anyone could name.
    //
    // These are the freedesktop main categories, all thirteen of them
    // (Desktop Menu Specification, "Main Categories" table). Audio and Video
    // are main categories in their own right but only ever appear alongside
    // AudioVideo, so they sit next to it and the first match takes them.
    readonly property var mainCategories: [
        "AudioVideo", "Audio", "Video", "Graphics", "Office", "Development",
        "Network", "Game", "Education", "Science", "Settings", "System",
        "Utility"]

    // What each one is called in the column. A category nobody can read is a
    // category nobody clicks.
    readonly property var categoryLabels: ({
        "AudioVideo": "Media", "Audio": "Audio", "Video": "Video",
        "Graphics": "Graphics", "Office": "Office", "Development": "Development",
        "Network": "Internet", "Game": "Games", "Education": "Education",
        "Science": "Science", "Settings": "Settings", "System": "System",
        "Utility": "Utilities", "Other": "Other"
    })

    readonly property var categoryIcons: ({
        "AudioVideo": "movie", "Audio": "music_note", "Video": "movie",
        "Graphics": "palette", "Office": "description", "Development": "code",
        "Network": "public", "Game": "sports_esports", "Education": "school",
        "Science": "science", "Settings": "tune", "System": "memory",
        "Utility": "build", "Other": "apps",
        "all": "apps", "frequent": "schedule"
    })

    // Which category a program belongs in. Only the main categories count, and
    // the first one in OUR order wins — so a program that calls itself
    // "AudioVideo;Audio;GTK;X-Fedora" is Media, not a toolkit.
    //
    // ⚠️ A program with no main category is not dropped. It goes to "Other",
    // which is offered only when something is in it, like every other category.
    // Dropping it would mean a program that is installed, works, and cannot be
    // found — the exact failure the launcher exists to end.
    function categoryOf(categories) {
        if (categories) {
            for (var i = 0; i < root.mainCategories.length; i++)
                if (categories.indexOf(root.mainCategories[i]) >= 0)
                    return root.mainCategories[i]
        }
        return "Other"
    }

    // The whole list. Plain objects rather than DesktopEntry handles: the list
    // is filtered, sorted and searched on every keystroke, and a plain object is
    // something QML can hold still while a C++ model underneath is free to
    // change.
    //
    // ⚠️ A BINDING, NOT A FUNCTION CALLED FROM Component.onCompleted, and not a
    // Connections either. Measured on the test VM: DesktopEntries.applications
    // is EMPTY when a component completes and fills about 50 ms later — a
    // one-shot rebuild at startup would leave the launcher permanently empty on
    // a machine with programs installed. `values` carries a notify signal
    // (UntypedObjectModel, quickshell 0.2.1), so a binding re-runs by itself;
    // Connections on a singleton that is still coming into existence is the
    // trap services/Theming.qml documents three failed attempts at.
    readonly property var apps: {
        var out = []
        var list = DesktopEntries.applications ? DesktopEntries.applications.values : []
        for (var i = 0; i < list.length; i++) {
            var e = list[i]
            if (!e || e.noDisplay)
                continue
            var cats = e.categories || []
            out.push({
                id: e.id,
                name: e.name || e.id,
                generic: e.genericName || "",
                comment: e.comment || "",
                icon: e.icon || "",
                category: root.categoryOf(cats),
                // What the program actually is, for the case below where two of
                // them insist on the same name. `command` is the parsed argv,
                // so [0] is the binary without the field codes.
                binary: (e.command && e.command.length ? String(e.command[0]) : "")
                        .split("/").pop(),
                // Lower-cased once, here, rather than on every keystroke for
                // every program. The search below runs on this string.
                haystack: ((e.name || "") + " " + (e.genericName || "") + " " +
                           (e.comment || "") + " " + (e.keywords || []).join(" ") +
                           " " + e.id).toLowerCase()
            })
        }
        out.sort(function (a, b) { return a.name.localeCompare(b.name) })

        // ⚠️ TWO PROGRAMS ARE ALLOWED TO SHARE A NAME, AND DEDUPING WOULD HIDE
        // ONE OF THEM. Seen on the test machine: nemo and Nautilus are both
        // called "Files" and both describe themselves as "Access and organize
        // files", so the list showed the same row twice and picking one was a
        // coin toss. They are not duplicates — they are two different file
        // managers — so the answer is to say which is which, not to drop one.
        //
        // The binary is only shown where it settles something. Putting it on
        // every row would be noise on the 99% that need no explanation.
        var byName = ({})
        for (var n = 0; n < out.length; n++)
            byName[out[n].name] = (byName[out[n].name] || 0) + 1
        for (var m = 0; m < out.length; m++)
            out[m].ambiguous = byName[out[m].name] > 1 && out[m].binary.length > 0

        return out
    }

    // ------------------------------------------- an app_id to its icon name
    //
    // ⚠️⚠️ THE COMPOSITOR'S app_id IS NOT AN ICON NAME, and treating it as one
    // is what put a circle with a letter in it beside every window in the
    // Super+Tab card and the task manager. `ui/common/AppIcon.qml`
    // asked `Quickshell.hasThemeIcon(app_id)` directly; that answers for a
    // minority of programs and silently falls back for the rest.
    //
    // The icon name lives in the .desktop entry. An app_id finds that entry by
    // one of three keys, and all three are needed — measured on 10.08.2026 over
    // the twenty programs this desktop ships:
    //
    //   by desktop id            11   kitty, vlc, org.gnome.Nautilus, code …
    //   by StartupWMClass         4   Code, alacritty, keepassxc, …
    //   only as an icon name      1   org.quickshell (our own windows)
    //   nothing at all            4   programs not installed on that machine
    //
    // ⚠️ `startupClass` IS Quickshell's name for StartupWMClass — read out of
    // the installed qmltypes, not guessed. It exists for exactly this question:
    // "which entry belongs to the window the compositor is showing me".
    //
    // ⚠️ AN INDEX, NOT A SCAN PER ICON. Every switcher tile, every task-manager row and
    // every task-manager row asks this; a linear walk per lookup is the shape
    // this project bans outright (see the note above `Calendar.dayIndex`, where
    // 42 cells × every event was the same mistake). Built once, as a binding.
    //
    // ⚠️ AND THREE SEPARATE MAPS RATHER THAN ONE. Folded into a single map, an
    // exact id could be overwritten by another entry's lower-cased id, and the
    // wrong program's icon would appear with nothing to say so.
    readonly property var iconById: root._index("id")
    readonly property var iconByIdLower: root._index("lower")
    readonly property var iconByClass: root._index("class")

    function _index(kind) {
        var idx = ({})
        // ⚠️ READ AS A BINDING — this function is only ever called from the
        // three property initialisers above, never from a Timer or a handler.
        // `DesktopEntries.applications` read imperatively hands back an EMPTY
        // list, which is documented above `apps` and has now cost three
        // separate probes their result.
        var list = DesktopEntries.applications ? DesktopEntries.applications.values : []
        for (var i = 0; i < list.length; i++) {
            var e = list[i]
            if (!e || !e.icon)
                continue
            var key = ""
            if (kind === "id")
                key = String(e.id)
            else if (kind === "lower")
                key = String(e.id).toLowerCase()
            else
                key = e.startupClass ? String(e.startupClass).toLowerCase() : ""
            // First one wins. Two entries claiming the same key is a machine
            // with two programs fighting over a window class, and picking the
            // later one would make the answer depend on directory order.
            if (key.length && idx[key] === undefined)
                idx[key] = String(e.icon)
        }
        return idx
    }

    // The icon name for a window's app_id, or "" if nothing claims it.
    function iconFor(appId) {
        if (appId === undefined || appId === null)
            return ""
        var s = String(appId)
        if (!s.length)
            return ""
        if (root.iconById[s] !== undefined)
            return root.iconById[s]
        var low = s.toLowerCase()
        if (root.iconByClass[low] !== undefined)
            return root.iconByClass[low]
        if (root.iconByIdLower[low] !== undefined)
            return root.iconByIdLower[low]
        return ""
    }

    // The categories that actually have something in them, in menu order.
    // ⚠️ An empty category is never offered — a column of headings that lead to
    // nothing is worse than a shorter column.
    readonly property var categories: {
        var seen = ({})
        for (var i = 0; i < root.apps.length; i++)
            seen[root.apps[i].category] = true
        var out = []
        for (var c = 0; c < root.mainCategories.length; c++)
            if (seen[root.mainCategories[c]])
                out.push(root.mainCategories[c])
        if (seen["Other"])
            out.push("Other")
        return out
    }

    function label(key) {
        return key === "all" ? "All"
             : key === "frequent" ? "Frequent"
             : (root.categoryLabels[key] || key)
    }
    function icon(key) { return root.categoryIcons[key] || "apps" }

    // ------------------------------------------------------------- frequency
    //
    // ⚠️ COUNTED HERE, BECAUSE THERE IS NO OTHER SOURCE. Nothing on a
    // freedesktop system records how often you start a program; the
    // predecessor had a Python script that parsed shell history to guess it.
    //
    // It lives in XDG_STATE_HOME rather than in shell.json for two reasons that
    // both matter: it is data and not a setting, so it has no business in a
    // file the user edits by hand — and shell.json is written through
    // Config.save(), which would mean rewriting the entire configuration every
    // time a program is started.
    readonly property string usagePath:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
        + "/buchhwin/app-usage.json"

    property var usage: ({})

    FileView {
        id: usageFile
        path: root.usagePath
        // Absent on a machine that has never started a program from here, which
        // is the normal first state and not worth a message.
        printErrors: false
        onLoaded: {
            try {
                root.usage = JSON.parse(text()) || ({})
            } catch (e) {
                // A broken counter is not worth losing the launcher over: start
                // counting again rather than refuse to open.
                root.usage = ({})
            }
        }
        onLoadFailed: root.usage = ({})
    }

    // The most-used programs, most first. Ten is a screen's worth without
    // scrolling and short enough that the order still means something.
    readonly property var frequent: {
        var out = []
        for (var i = 0; i < root.apps.length; i++)
            if (root.usage[root.apps[i].id] > 0)
                out.push(root.apps[i])
        out.sort(function (a, b) { return root.usage[b.id] - root.usage[a.id] })
        return out.slice(0, 10)
    }

    // ---------------------------------------------------------------- search
    //
    // Substring, not fuzzy. A fuzzy match puts "Files" third for the query
    // "fi" and nobody can say why; a substring match is a rule you can hold in
    // your head. Name matches are ranked above description matches, so typing
    // "code" finds VS Code before it finds whatever mentions code in its
    // comment.
    function search(query) {
        var q = String(query || "").trim().toLowerCase()
        if (!q.length)
            return []
        var strong = [], weak = []
        for (var i = 0; i < root.apps.length; i++) {
            var a = root.apps[i]
            if (a.name.toLowerCase().indexOf(q) >= 0)
                strong.push(a)
            else if (a.haystack.indexOf(q) >= 0)
                weak.push(a)
        }
        return strong.concat(weak)
    }

    function inCategory(key) {
        if (key === "all")
            return root.apps
        if (key === "frequent")
            return root.frequent
        var out = []
        for (var i = 0; i < root.apps.length; i++)
            if (root.apps[i].category === key)
                out.push(root.apps[i])
        return out
    }

    // ---------------------------------------------------------------- launch
    //
    // ⚠️ Through DesktopEntry.execute(), not through a Process of our own.
    // The entry knows things the Exec line does not say: the working directory,
    // whether it has to run in a terminal, and the field codes to strip. A
    // shell command built here would get the simple cases right and the rest
    // quietly wrong.
    function launch(id) {
        var entry = DesktopEntries.byId(id)
        if (!entry)
            return false
        var u = ({})
        for (var k in root.usage)
            u[k] = root.usage[k]
        u[id] = (u[id] || 0) + 1
        root.usage = u
        usageFile.setText(JSON.stringify(u))
        entry.execute()
        return true
    }
}
