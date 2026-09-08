// What does the shell think it is running from?
//
// ⚠️ THE ANSWER IS DERIVED, NOT CONFIGURED, and that is exactly why it needs a
// check. Services/Update takes `Quickshell.shellDir`, resolves it with
// `readlink -f` and takes the parent — because on an installed machine the
// shell directory is a SYMLINK (~/.config/quickshell/buchhwin → $REPO/shell)
// and `shellDir` hands back the link rather than its target. Measured, with a
// control: the same probe from a real directory returns the real path, and
// through a symlink to it returns the link.
//
// A rule derived like that is one rename away from pointing at
// ~/.config/quickshell, where every button in the update group would be
// permanently and quietly unavailable. Nothing would crash and no other check
// would go red — the group would simply always say "not a checkout", which is
// a sentence that is TRUE of ~/.config/quickshell.
//
// So this reports what it found and tests/update.sh decides. Three arrangements
// are run against it there: a real checkout, a copied tree with no .git, and a
// bare shell folder with no repository around it at all.
import QtQuick
import Quickshell
import Quickshell.Io
import "../common"
import "../services" as Services

Item {
    id: root

    readonly property string out:
        Quickshell.env("BUCHHWIN_UPDATE_OUT") || "/tmp/buchhwin-update-check.txt"

    // ⚠️ Written as key=value rather than as ok/FAIL lines, unlike the other
    // tools. The three runs in the shell script expect three DIFFERENT answers
    // from the same code — "not a checkout" is the correct result in one of
    // them — so the judgement cannot live in here.
    function report() {
        var u = Services.Update
        var lines = [
            "shellDir=" + Quickshell.shellDir,
            "repoDir=" + u.repoDir,
            "isRepo=" + (u.isRepo ? "yes" : "no"),
            "isCheckout=" + (u.isCheckout ? "yes" : "no"),
            "commit=" + u.commit,
            "branch=" + u.branch,
            "dirty=" + u.dirtyFiles,
            "canInstall=" + (u.canInstall ? "yes" : "no"),
            "status=" + u.statusLine
        ]
        log.setText(lines.join("\n") + "\n")
        Qt.callLater(Qt.quit)
    }

    FileView { id: log; path: root.out }

    // ⚠️ `probe()` has to be CALLED. Nothing in this service runs by itself —
    // that is the whole point of it — so a tool that only waits on `available`
    // would wait until the timeout and then report a service that works as one
    // that never answers.
    Component.onCompleted: Services.Update.probe()

    WaitFor {
        condition: Services.Update.available
        timeoutMs: 15000        // it shells out to git; a cold page cache is slow
        onReady: root.report()
        onTimedOut: {
            log.setText("timeout=yes\n")
            Qt.callLater(Qt.quit)
        }
    }
}
