// The compositor config generator.
//
//   BUCHHWIN_TOOL=hypr QT_QPA_PLATFORM=offscreen qs -p shell
//
// Turns shell.json into the two Lua modules Hyprland loads after the shipped
// defaults:
//
//   generated/settings.lua   gaps, borders, decoration, input, monitors
//   generated/binds.lua      every keybinding, rebinds already resolved
//
// ⚠️ THIS IS THE FILE THAT MAKES REBINDING REAL. Before it existed, the
// settings window wrote a rebind into shell.json and then ran `hyprctl reload`,
// which reloaded a config containing none of the bindings. The row moved on
// screen and nothing happened — the worst kind of broken, because it looked
// like it worked.
//
// Four things here are copied deliberately from the generator this replaces,
// each because it prevents a fault that was actually observed rather than
// imagined:
//
//   1. WaitFor(Config.settled), which defers by one event-loop step.
//      FileView.loaded turns true BEFORE JsonAdapter has pushed the parsed
//      values into properties, so reading a setting in the same tick returns
//      the schema default. Without the deferral this writes gaps 8 into a file
//      whose source says 16, and reports success.
//
//   2. view.path = "" before every re-point. A FileView hands back the text it
//      already holds, so reusing one view for a second path reads the FIRST
//      file. That once wrote Brave's desktop entry out as code.desktop.
//
//   3. Compare before writing. Hyprland reloads on every write, so an
//      unchanged config must cost nothing.
//
//   4. The word ABORT in the log. bin/bhctl and services/Theming.qml both grep
//      for it, and it is how a refusal is told apart from a crash.
//
// What is NEW compared with that generator: the output is checked before it is
// trusted. `Hyprland --verify-config` exits 1 on a bad config, so a generated
// file that would break the session is rolled back to what was there before,
// rather than being written and discovered at the next login.

import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
import "../common"
import "hypr"

Scope {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string cfg: Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")
    readonly property string hyprDir: cfg + "/buchhwin/hyprland"

    property string report: ""
    property int written: 0
    property int unchanged: 0

    // What each file held before we touched it, so a config the compositor
    // refuses can be put back exactly as it was.
    property var previous: ({})

    function note(line) {
        report += line + "\n"
        log.setText(report)
    }

    function write(view, path, text, label) {
        // See warning 2 at the top of this file.
        view.path = ""
        view.path = path

        var old = String(view.text() || "")
        root.previous[path] = old

        if (old === text) {
            unchanged++
            note("  same   " + label)
            return
        }
        view.setText(text)
        written++
        note("  wrote  " + label + "  ->  " + path)
    }

    function restore() {
        for (var path in root.previous) {
            var old = root.previous[path]
            // A file that did not exist before is left absent rather than
            // written as an empty module: an empty generated/binds.lua would
            // make hyprland.lua load it INSTEAD of the shipped defaults, and
            // the desktop would come up with no keys at all.
            if (!old.length)
                continue
            restoreView.path = ""
            restoreView.path = path
            restoreView.setText(old)
        }
    }

    function finish() {
        note("done: " + written + " written, " + unchanged + " unchanged")
        Qt.callLater(Qt.quit)
    }

    WaitFor {
        condition: Config.settled

        onTimedOut: {
            root.note("buchhwin hypr — ABORT: the configuration never settled")
            Qt.callLater(Qt.quit)
        }

        onReady: {
            root.note("buchhwin hypr — generating from shell.json (version "
                      + Config.version + ")")

            root.write(fSettings, root.hyprDir + "/generated/settings.lua",
                       EmitSettings.build(), "compositor settings")

            var binds = EmitBinds.build()
            for (var i = 0; i < EmitBinds.warnings.length; i++)
                root.note("  ⚠ " + EmitBinds.warnings[i])
            root.write(fBinds, root.hyprDir + "/generated/binds.lua",
                       binds, "keybindings")

            // Nothing changed, so nothing can have broken. Skipping the check
            // here is the difference between one process per palette change and
            // one per palette change plus a compositor parse.
            if (root.written === 0) {
                root.finish()
                return
            }
            validator.running = true
        }
    }

    Process {
        id: validator
        // ⚠️ 97 SEPARATES "HYPRLAND IS NOT HERE" FROM "THE CONFIG IS BAD".
        // The generator runs during installation too, on a machine where the
        // compositor may not be installed yet, and "cannot check" must not read
        // as "is broken".
        command: ["sh", "-c",
                  "command -v Hyprland >/dev/null 2>&1 || exit 97; "
                  + "exec Hyprland --verify-config --config \"$1\"",
                  "sh", root.hyprDir + "/hyprland.lua"]
        stdout: StdioCollector { id: validatorOut }
        stderr: StdioCollector { id: validatorErr }

        onExited: function (code) {
            if (code === 97) {
                root.note("  ⚠ Hyprland is not installed — config written unchecked")
                root.finish()
                return
            }
            if (code === 0) {
                root.note("  config verified")
                root.finish()
                return
            }

            // ⚠️ ABORT, and the word is load-bearing: bin/bhctl and
            // services/Theming.qml both grep the log for it to tell a refusal
            // from a crash.
            root.note("buchhwin hypr — ABORT: Hyprland refused the generated config, "
                      + "so the previous one was put back.")
            root.restore()

            var text = String(validatorOut.text || "") + "\n" + String(validatorErr.text || "")
            var lines = text.split("\n")
            var shown = 0
            for (var i = 0; i < lines.length && shown < 24; i++) {
                if (lines[i].replace(/\s/g, "").length) {
                    root.note("    " + lines[i])
                    shown++
                }
            }
            root.finish()
        }
    }

    // One view per path. See warning 2: sharing them is what makes a reused
    // view read the previous file.
    FileView { id: fSettings; blockLoading: true; printErrors: false }
    FileView { id: fBinds; blockLoading: true; printErrors: false }
    FileView { id: restoreView; blockLoading: true; printErrors: false }

    FileView { id: log; path: "/tmp/buchhwin-hypr.log"; printErrors: false }
}
