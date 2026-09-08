// Checks for the launcher: which category a program lands in, and what never
// reaches the list at all.
//
//   BUCHHWIN_TOOL=launcher-check QT_QPA_PLATFORM=offscreen qs -p shell
//
// ⚠️ THE RULES ARE CHECKED AGAINST INVENTED CATEGORY LISTS, NOT AGAINST THE
// MACHINE'S OWN PROGRAMS. What is installed differs between a laptop, the test
// VM and a CI container, so a test that counted real programs would pass or
// fail for reasons that have nothing to do with the code. The category rules
// are pure functions of a string list, and that is what is asked here.
//
// The one thing that IS asked of the real database is the shape of the answer:
// that every program in the list has a category which is offered, and that no
// category is offered with nothing in it. Both hold whether the machine has
// four programs or four hundred — including zero.
import QtQuick
import Quickshell
import Quickshell.Io
import "../services" as Services
import "../common"

Scope {
    id: root

    property string report: ""
    property int failures: 0

    FileView { id: out; path: "/tmp/buchhwin-launcher-check.txt" }
    function note(s) { report += s + "\n"; out.setText(report) }
    function eq(what, got, want) {
        if (String(got) === String(want)) note("  ok    " + what)
        else { failures++; note("  FAIL  " + what + "\n          got:  " + got +
                                "\n          want: " + want) }
    }

    // ⚠️ WAIT FOR THE LIST, DO NOT GUESS A DELAY. Measured on the test VM:
    // DesktopEntries is empty when a component completes and fills roughly 50 ms
    // later. A fixed timer that happened to be long enough here would be the
    // same mistake WaitFor.qml was written to end — and a machine with no
    // programs at all is a legitimate state, so the timeout is not a failure.
    WaitFor {
        condition: Services.Apps.apps.length > 0
        timeoutMs: 3000
        onTimedOut: root.run()
        onReady: root.run()
    }

    function run() {
        note("buchhwin launcher-check")
        var A = Services.Apps

        // ------------------------------------------------ main categories
        root.eq("a single main category is taken as it is",
                A.categoryOf(["Development"]), "Development")

        // ⚠️ The rule the plan states: first match wins, in OUR order — not
        // the order the .desktop file happens to list them in. Without it,
        // a media player calling itself "Audio;AudioVideo" and one calling
        // itself "AudioVideo;Audio" would land in different columns.
        root.eq("first main category in menu order wins, not file order",
                A.categoryOf(["Audio", "AudioVideo"]), "AudioVideo")

        // ------------------------------------------------ toolkit markers
        //
        // This is the one that produced a "GTK" category with half the
        // system in it. GTK, Qt, KDE, GNOME, Java and Motif are registered
        // freedesktop values, they are simply not main categories.
        root.eq("GTK is not a category", A.categoryOf(["GTK"]), "Other")
        root.eq("Qt is not a category", A.categoryOf(["Qt"]), "Other")
        root.eq("KDE is not a category", A.categoryOf(["Qt", "KDE"]), "Other")
        root.eq("a toolkit next to a real category does not win",
                A.categoryOf(["GTK", "Office"]), "Office")

        // ------------------------------------------------ vendor prefixes
        root.eq("X-* is not a category",
                A.categoryOf(["X-Fedora", "X-Red-Hat-Base"]), "Other")
        root.eq("a vendor prefix next to a real category does not win",
                A.categoryOf(["X-GNOME-Utilities", "Utility"]), "Utility")

        // ------------------------------------------------ the empty cases
        root.eq("no categories at all is Other", A.categoryOf([]), "Other")
        root.eq("undefined categories is Other", A.categoryOf(undefined), "Other")

        // A real line from a real file, as the last word on it.
        root.eq("a real Exec line's categories resolve",
                A.categoryOf(["AudioVideo", "Audio", "Player", "GTK"]), "AudioVideo")

        // --------------------------------------------- labels and icons
        // Every category that can be offered needs a name and an icon, or
        // the column shows a raw freedesktop token or an empty box.
        var unnamed = [], iconless = []
        var keys = A.mainCategories.concat(["Other", "all", "frequent"])
        for (var i = 0; i < keys.length; i++) {
            if (!A.label(keys[i]).length)
                unnamed.push(keys[i])
            // ⚠️ Not merely "non-empty": icon() falls back to "apps" for
            // anything it does not know, so an unnamed category would come
            // back with a plausible icon and no complaint. Asked against
            // the table itself.
            if (!A.categoryIcons[keys[i]])
                iconless.push(keys[i])
        }
        root.eq("every category has a label" +
                (unnamed.length ? " (missing: " + unnamed.join(", ") + ")" : ""),
                unnamed.length, 0)
        root.eq("every category has an icon" +
                (iconless.length ? " (missing: " + iconless.join(", ") + ")" : ""),
                iconless.length, 0)

        // ------------------------------------------- the real database
        //
        // Whatever is installed, the shape has to hold.
        var apps = A.apps
        note("  (" + apps.length + " programs found on this machine)")

        var offered = A.categories
        var orphans = 0, hidden = 0
        for (var a = 0; a < apps.length; a++) {
            if (offered.indexOf(apps[a].category) < 0)
                orphans++
            if (!apps[a].name.length)
                hidden++
        }
        root.eq("every program is in a category the column offers", orphans, 0)
        root.eq("every program has a name to show", hidden, 0)

        var emptyCats = 0
        for (var c = 0; c < offered.length; c++)
            if (A.inCategory(offered[c]).length === 0)
                emptyCats++
        root.eq("no category is offered with nothing in it", emptyCats, 0)

        // "All" is the whole list by definition, and Frequent is capped.
        root.eq("All is the whole list", A.inCategory("all").length, apps.length)
        root.eq("Frequent is at most ten", A.frequent.length <= 10, true)

        // Search: an empty query is not "everything", it is "no result yet"
        // — the launcher shows the categories then, not a wall of programs.
        root.eq("an empty query returns nothing", A.search("").length, 0)
        root.eq("a query of spaces returns nothing", A.search("   ").length, 0)

        note(root.failures === 0 ? "all good"
                                 : root.failures + " check(s) failed")
        Qt.callLater(Qt.quit)
    }
}
