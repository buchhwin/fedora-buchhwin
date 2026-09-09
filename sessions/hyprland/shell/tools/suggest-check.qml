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

    function report(timedOut) {
        var s = Services.Suggest
        var lines = [
            // ⚠️ WHO ANSWERED COMES FIRST, and it is measurement rather than
            // decoration. Two services are waited on below; when the wait ran
            // out this file used to write `timeout=yes` and nothing else, and
            // the script turned that into "the services never answered —
            // nothing could be measured". True, and useless: it named neither
            // service, and it decided the verdict here, which is precisely the
            // split this tool's own header says it must not make.
            "timedOut=" + (timedOut ? "yes" : "no"),
            "installed=" + (Services.Installed.available ? "yes" : "no"),
            "apps=" + (Services.Apps.available ? "yes" : "no"),
            "appCount=" + Services.Apps.apps.length,
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
        onReady: root.report(false)

        // ⚠️ A TIMEOUT STILL REPORTS, and that is the fix rather than a longer
        // wait. `Apps.available` is `apps.length > 0` — deliberately, because
        // the launcher must be able to say "nothing installed" — so on a machine
        // whose only .desktop file is NoDisplay, which is exactly what a bare
        // Fedora WSL and the CI container are, this condition is false forever.
        // Waiting longer cannot help; the wait was measuring the machine.
        //
        // So the numbers are written either way and the script judges them
        // against what this machine can supply, the same way it already does for
        // sounds and for screens. A genuine hang is still loud: `installed=no`
        // says so, and every list it feeds comes out empty and fails there.
        onTimedOut: root.report(true)
    }
}
