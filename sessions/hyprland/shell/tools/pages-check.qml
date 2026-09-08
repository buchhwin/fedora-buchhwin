// Build every settings page the window claims to have, and count the rows that
// actually come out.
//
//   BUCHHWIN_TOOL=pages-check QT_QPA_PLATFORM=offscreen qs -p shell
//
// ⚠️ THIS IS THE HALF tests/setting-rows.sh CANNOT SEE. That check greps the
// page files for `key: "…"` lines and matches them against the schema, which is
// exactly the right question asked of the SOURCE. It cannot tell you whether the
// window ever builds the file: a page registered under a path that does not
// exist, or one that throws on creation, greps perfectly and draws nothing.
//
// The registration used to live in three places — the page list, a Component
// declaration, and a branch in a ten-way ternary — and forgetting the third
// produced precisely that: a page that loads, greps clean, and is blank. It is
// one place now, and this is the check that keeps it honest.
//
// It reads the list from SettingsContent itself rather than from the folder, so
// a page file that exists but is not registered is not counted as present, and
// a registered page whose file is gone is a failure rather than a silence.
//
// ⚠️ AND THE ROW COUNT IS A CROSS-CHECK, not decoration. setting-rows.sh counts
// rows by reading; this one counts them by building. The two disagreeing means a
// row is declared somewhere the window never instantiates — inside a Loader that
// is never active, or a component nothing reaches — which is the same class of
// fault as a key with no reader, one level up.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property string report: ""
    property int failures: 0
    property int rowTotal: 0

    FileView { id: out; path: "/tmp/buchhwin-pages-check.txt" }
    function note(s) { root.report += s + "\n"; out.setText(root.report) }
    function ok(what, good) {
        if (good) root.note("  ok    " + what)
        else { root.failures++; root.note("  FAIL  " + what) }
    }

    // One frame, so the singletons exist before a page asks them anything. The
    // work is started FROM the timer, so there is nothing to race with.
    Timer {
        running: true
        interval: 250
        onTriggered: root.run()
    }

    // Walk an object tree and collect everything that looks like a settings row.
    //
    // ⚠️ IT ASKS FOR THE PROPERTIES, it does not match the type name. A row is a
    // row here because it carries `key` and a control, which is what the rest of
    // the system means by one — and a check that matched `SettingRow` by name
    // would go quietly blind the day somebody wraps one.
    //
    // ⚠️ AND `kind` IS NO LONGER THE ONLY CONTROL. The App Theming page lays its
    // thirteen programs out as a table of ThemingRows, which carry `states`
    // rather than `kind` — same promise, different geometry. Asking only for
    // `kind` counted 151 built against 164 declared and blamed the pages for it,
    // which is the check going blind in exactly the way its own note warns
    // about. Widened to what a row really is, not to whatever happens to pass.
    function harvest(obj, into) {
        if (!obj)
            return
        if (obj.key !== undefined && String(obj.key).length
            && obj.label !== undefined)
            into.push({ key: String(obj.key),
                        label: String(obj.label === undefined ? "" : obj.label) })

        // `children` is the visual tree; `data` also holds non-visual items. A
        // row inside a Repeater or an Instantiator hangs off the second one.
        var kids = obj.children === undefined ? [] : obj.children
        for (var i = 0; i < kids.length; i++)
            root.harvest(kids[i], into)
        var d = obj.data === undefined ? [] : obj.data
        for (var j = 0; j < d.length; j++)
            if (d[j] !== undefined && kids.indexOf(d[j]) < 0)
                root.harvest(d[j], into)
    }

    // The same three fields the window's own filter looks at, asked of the
    // index rather than of the box — there is no way to type into a TextField
    // from here, and re-implementing the filter would be testing a copy.
    function hits(idx, q) {
        var n = 0
        for (var i = 0; i < idx.length; i++) {
            var r = idx[i]
            if (String(r.label).toLowerCase().indexOf(q) >= 0
                || String(r.hint).toLowerCase().indexOf(q) >= 0
                || String(r.key).toLowerCase().indexOf(q) >= 0)
                n++
        }
        return n
    }

    function run() {
        root.note("buchhwin pages-check")

        var shellComp = Qt.createComponent("../ui/settings/SettingsContent.qml")
        if (shellComp.status === Component.Error) {
            root.failures++
            root.note("  FAIL  SettingsContent does not compile:\n" +
                      String(shellComp.errorString()).replace(/^/gm, "          "))
            root.finish()
            return
        }
        var content = shellComp.createObject(root)
        if (content === null) {
            root.failures++
            root.note("  FAIL  SettingsContent does not build:\n" +
                      String(shellComp.errorString()).replace(/^/gm, "          "))
            root.finish()
            return
        }
        root.ok("SettingsContent builds", true)

        var pages = content.pages
        root.ok("it publishes a page list", pages !== undefined && pages.length > 0)
        if (!pages || !pages.length) {
            content.destroy()
            root.finish()
            return
        }
        root.note("  --    " + pages.length + " pages registered")

        var seen = {}
        for (var i = 0; i < pages.length; i++) {
            var p = pages[i]

            if (p.source === undefined || !String(p.source).length) {
                root.ok("\"" + p.id + "\" names a file", false)
                continue
            }
            if (seen[p.id] !== undefined) {
                root.ok("\"" + p.id + "\" is registered once", false)
                continue
            }
            seen[p.id] = true

            // The URL in the list is relative to the settings window's own
            // folder, which is where the Loader resolves it. Resolving it from
            // here has to say the same thing, hence the prefix rather than a
            // second spelling of the path.
            var c = Qt.createComponent("../ui/settings/" + p.source)
            if (c.status === Component.Error) {
                root.ok("\"" + p.id + "\" compiles", false)
                root.note("          " + String(c.errorString())
                                          .replace(/\n/g, "\n          "))
                continue
            }
            var page = c.createObject(root)
            if (page === null) {
                root.ok("\"" + p.id + "\" builds", false)
                root.note("          " + String(c.errorString()))
                continue
            }

            var rows = []
            root.harvest(page, rows)
            root.rowTotal += rows.length
            root.ok("\"" + p.id + "\" builds — " + rows.length + " rows", true)
            page.destroy()
        }

        // ------------------------------------------------------- the row index
        // ⚠️ THE SEARCH IS THE OTHER THING THAT CAN BE GREEN AND USELESS. It
        // used to look at ten page titles and ten descriptions, so "blur" found
        // nothing at all — the box worked, it simply did not search the thing
        // anybody wanted. Counting the index is how that stays fixed.
        //
        // ⚠️ IT IS BUILT BETWEEN FRAMES NOW, one page per tick, because doing all
        // twenty-one at once froze the window mid-keystroke. So this has to WAIT
        // for it rather than read it on the next line — the first version of this
        // check did exactly that and went red the moment the index went
        // incremental, which is the check doing its job against its own author.
        root.pending = content
        content.buildIndex()
        waiter.start()
    }

    property var pending: null
    property int waited: 0

    Timer {
        id: waiter
        interval: 50
        repeat: true
        onTriggered: {
            root.waited += 1
            if (root.pending.rowIndex === null && root.waited < 200)
                return
            waiter.stop()
            root.checkIndex(root.pending)
        }
    }

    function checkIndex(content) {
        var idx = content.rowIndex
        root.ok("the search index builds", idx !== null)
        if (idx !== null) {
            root.ok("it holds every row (" + idx.length + ")",
                    idx.length === root.rowTotal)
            if (idx.length !== root.rowTotal)
                root.note("          index " + idx.length
                          + " vs " + root.rowTotal + " built")

            // A word that is on a ROW and in no page title or description. If
            // this finds nothing, the search has fallen back to what it did
            // before and nobody would notice.
            root.ok("\"blur\" finds a row", root.hits(idx, "blur") > 0)

            // ⚠️ THE CONTROL. A matcher that returns everything would pass the
            // line above and be worse than useless.
            root.ok("a nonsense word finds nothing",
                    root.hits(idx, "zzzznotathing") === 0)
        }

        content.destroy()
        root.note("  --    " + root.rowTotal + " rows built in total")
        root.finish()
    }

    function finish() {
        root.note(root.failures === 0
                  ? "pages-check: all good"
                  : "pages-check: " + root.failures + " check(s) failed")
        Qt.callLater(Qt.quit)
    }
}
