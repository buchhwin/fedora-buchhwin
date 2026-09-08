// The one entry point.
//
//   qs -c buchhwin                          the desktop
//   BUCHHWIN_MODE=lock qs -c buchhwin       the lock screen, its own process
//   BUCHHWIN_TOOL=dump-tokens qs -p shell   a headless tool
//
// ⚠️ THE LOCK SCREEN IS A SEPARATE PROCESS, not a surface of the desktop, and
// that is a safety property rather than a structural preference: if the shell
// crashes while it holds the lock, the screen unlocks. As its own process it
// can crash without unlocking — the ext-session-lock protocol keeps the session
// locked behind a blank screen when its client dies, which is the correct
// failure and the whole reason for the split.
//
// There is deliberately no second entry point for tools. Quickshell makes the
// folder of the file it is given the config root, so a tool started by its own
// path would put theme/ and config/ "outside the config folder" and the
// singletons would never register — the tool would then quietly compute
// different values than the shell it is supposed to describe.
//
// One root means the renderer, the token dump and the running desktop all walk
// the same import graph. That is not tidiness, it is the reason a palette
// switch can be trusted to produce the same colours everywhere.

import QtQuick
import Quickshell

ShellRoot {
    id: root

    readonly property string tool: Quickshell.env("BUCHHWIN_TOOL") || ""
    readonly property string mode: Quickshell.env("BUCHHWIN_MODE") || ""

    // ⚠️ `active`, deliberately, where everything else in this project uses
    // `activeAsync`. These three decide what the PROCESS IS, and they are
    // mutually exclusive: deferring them by a frame means a headless tool with
    // no event loop left to defer into, and a lock screen that shows the
    // desktop for one frame before it covers it. The rule against `active`
    // exists for surfaces that come and go, which none of these do.
    LazyLoader {
        id: toolLoader
        active: root.tool !== ""
        source: root.tool !== "" ? "tools/" + root.tool + ".qml" : ""
    }

    // ⚠️ A MISSPELT TOOL NAME USED TO START THE WHOLE DESKTOP. `BUCHHWIN_TOOL`
    // names a file; if that file is not there the loader simply has nothing to
    // load, the other two loaders are still switched off by `tool !== ""`, and
    // the process sits in its event loop with no windows and no output until
    // whatever `timeout` wrapped it kills it. From outside — a test runner, or
    // a person — that looks exactly like a tool that hung, and half an hour can
    // go into looking for the hang. It costs one timer to say so instead.
    Timer {
        running: root.tool !== ""
        interval: 2000
        onTriggered: {
            if (toolLoader.item === null) {
                console.warn("buchhwin: no such tool: shell/tools/"
                             + root.tool + ".qml")
                Qt.exit(2)
            }
        }
    }

    LazyLoader {
        active: root.tool === "" && root.mode === "lock"
        source: "ui/lock/LockScreen.qml"
    }

    LazyLoader {
        active: root.tool === "" && root.mode === ""
        source: "ui/Shell.qml"
    }
}
