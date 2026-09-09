// Does the real surface tree BUILD? Every type, headless, with the reason if not.
//
// ⚠️⚠️ WRITTEN AFTER THE WHOLE SHELL WENT MISSING AND EVERY SUITE STAYED GREEN.
// A second `visible:` on three tiles made QML refuse to build QuickSettings, and
// the refusal travelled: QuickPage → NotchContent → ShellSurface. The notch, the
// bar, the launcher, the quick panel and every IPC target were gone. Nothing
// crashed, nothing exited non-zero.
//
// Why nothing caught it, and this is the part worth keeping:
//
//   smoke.qml       imports only ../ui/common — it never builds Shell.qml or
//                   anything under ui/surface, ui/notch, ui/quick
//   surfaces.sh     reads the journal, but of whatever shell is RUNNING, not of
//                   one built from the code under test
//   pages.sh        builds every settings page; the notch surfaces are not pages
//
// So nothing in the project built the real tree. This does.
//
// ⚠️ IT ASKS Qt.createComponent, NOT "did a window appear". Offscreen there is no
// wlr-layer-shell, so a PanelWindow cannot be shown and asking whether one is on
// screen would fail for a reason that is not a fault. `Component.Error` is a
// different question — it means the QML could not be turned into a type at all,
// which is exactly the failure that shipped.
//
// ⚠️ AND IT NAMES THE TYPE THAT BROKE, not the one that noticed. The journal
// reports the outermost failure first (Shell.qml: Type ShellSurface unavailable)
// and the cause last; walking the list in dependency order puts the cause first,
// where somebody can act on it.
//
//   BUCHHWIN_TOOL=surface-build QT_QPA_PLATFORM=offscreen qs -p shell
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property string outPath:
        Quickshell.env("BUCHHWIN_SURFACES_OUT") || "/tmp/buchhwin-surface-build.txt"

    // Innermost first: a break in QuickSettings makes every type above it
    // unavailable too, and reporting the outermost one sends the reader to a
    // file that is perfectly fine.
    readonly property var types: [
        "../ui/quick/QuickSettings.qml",
        "../ui/quick/SessionButtons.qml",
        "../ui/notch/WeekStrip.qml",
        "../ui/notch/NotchWide.qml",
        "../ui/notch/pages/QuickPage.qml",
        "../ui/notch/NotchContent.qml",
        "../ui/surface/OverlaySurface.qml",
        "../ui/surface/ShellSurface.qml",
        "../ui/bar/BarContent.qml",
        "../ui/launcher/LauncherSurface.qml",
        "../ui/notif/ToastSurface.qml",
        "../ui/wallpaper/WallpaperSurface.qml",
        "../ui/settings/SettingsContent.qml",
        // ⚠️ THE WINDOW AS WELL AS ITS CONTENT, and the gap was real: the
        // content was walked here from the first version and the window never
        // was, so anything added to SettingsWindow.qml itself — a catcher, a
        // pane, a binding onto a singleton — had no builder at all. That is the
        // same shape as the fault this whole tool exists for.
        "../ui/settings/SettingsWindow.qml",
        "../ui/lock/LockFace.qml",
        "../ui/Shell.qml"
    ]

    property string report: ""
    property int failures: 0

    function line(s) {
        root.report += s + "\n"
        console.log("surface-build: " + s)
    }

    FileView { id: out; path: root.outPath }

    Component.onCompleted: {
        for (var i = 0; i < root.types.length; i++) {
            var path = root.types[i]
            var c = Qt.createComponent(path)

            if (c.status === Component.Error) {
                // ⚠️⚠️ ONE EXEMPTION, AND IT HAS TO BE THIS EXACT REASON RATHER
                // THAN A LOOSER PATTERN. Offscreen there is no wlr-layer-shell,
                // so anything containing a PanelWindow cannot be turned into a
                // type — that is the stated limit of headless testing here, and
                // it is why `smoke.sh` carries the same exemption.
                //
                // Any OTHER reason is a real broken component. A duplicate
                // property, an unknown type, a bad import: those are what this
                // tool exists for, and widening the exemption to "unavailable"
                // would swallow exactly the fault that made it necessary — the
                // journal reported the shell's collapse as `Type QuickSettings
                // unavailable`.
                var lines = String(c.errorString()).split("\n")
                var reasons = []
                for (var j = 0; j < lines.length; j++)
                    if (lines[j].length > 0)
                        reasons.push(lines[j])

                var last = reasons.length ? reasons[reasons.length - 1] : ""
                if (last.indexOf("No PanelWindow backend loaded") >= 0) {
                    root.line("skip  " + path + "  (no layer shell offscreen)")
                    c.destroy()
                    continue
                }

                root.failures++
                root.line("FAIL  " + path)
                for (var k = 0; k < reasons.length; k++)
                    root.line("        " + reasons[k])
            } else {
                root.line("ok    " + path)
            }
            c.destroy()
        }

        root.line(root.failures === 0
                  ? "all good: every type either builds or is skipped for the "
                    + "missing layer shell"
                  : "ABORT: " + root.failures + " type(s) failed to build")
        out.setText(root.report)
        Qt.exit(root.failures === 0 ? 0 : 1)
    }
}
