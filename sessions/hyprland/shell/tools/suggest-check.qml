// Do the suggestion lists actually have anything in them?
//
// ⚠️ THE STRUCTURAL CHECK CANNOT ANSWER THIS, and the difference is the whole
// bug it is guarding against. tests/suggestions.sh proves every `pick` row
// names a source; it cannot prove the source answers. A list that is empty
// draws a text box with no pills under it — which is indistinguishable from a
// machine that has no fonts, and that is exactly how the pick control was
// reported broken once already, when a headless probe found 109 fonts on the
// same machine at the same moment.
//
// So this asks the services themselves and prints what they hand back, and the
// shell script decides which of them are allowed to be empty here. That split
// matters: on the test machine `players` is legitimately empty (nothing is
// playing) and `workspaceNames` is empty until somebody names a workspace,
// while `monitors` being empty would mean a desktop that cannot see its own
// screen.
import QtQuick
import Quickshell
import Quickshell.Io
import "../common"
import "../services" as Services

Item {
    id: root

    readonly property string out:
        Quickshell.env("BUCHHWIN_SUGGEST_OUT") || "/tmp/buchhwin-suggest-check.txt"

    function report() {
        var s = Services.Suggest
        var lines = [
            "monitors=" + s.monitors.length,
            "monitorsFirst=" + (s.monitors.length ? s.monitors[0].value : ""),
            "appIds=" + s.appIds.length,
            "allPrograms=" + s.allPrograms.length,
            // ⚠️ ORDERED, NOT FILTERED — and this is where that is measured.
            // programs(["Network"]) must return the SAME COUNT as the unfiltered
            // list with the browsers moved to the front. A count that shrinks
            // means somebody turned the ordering into a filter, and the first
            // program it hides will be one that carries no category.
            "networkFirst=" + s.programs(["Network"]).length,
            "keyboardOptions=" + Services.Installed.keyboardOptions.length,
            "sounds=" + s.sounds.length,
            "soundsLabelled=" + (s.sounds.length
                ? (s.sounds[0].label !== s.sounds[0].value ? "yes" : "no") : ""),
            "players=" + s.players.length,
            "workspaceNames=" + s.workspaceNames.length,
            "durations=" + s.durations.length
        ]
        log.setText(lines.join("\n") + "\n")
        Qt.callLater(Qt.quit)
    }

    FileView { id: log; path: root.out }

    // Installed is the one source that has to be asked; the rest are bindings
    // over services that fill themselves.
    Component.onCompleted: Services.Installed.scan()

    WaitFor {
        // ⚠️ Apps fills about 50 ms after the component completes — its own file
        // says so — so waiting on Installed alone would print an empty
        // `allPrograms` and call it a finding.
        condition: Services.Installed.available && Services.Apps.available
        timeoutMs: 20000
        onReady: root.report()
        onTimedOut: {
            log.setText("timeout=yes\n")
            Qt.callLater(Qt.quit)
        }
    }
}
