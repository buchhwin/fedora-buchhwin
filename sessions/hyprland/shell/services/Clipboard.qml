pragma Singleton

// The clipboard history, or the honest absence of one.
//
// ⚠️ THIS SERVICE EXISTS BECAUSE THE DAEMON DID AND NOTHING READ IT. The
// installer has been running `wl-paste --watch cliphist store` as its own
// systemd unit since the beginning, filling a database that no key, no page and
// no ipc verb could open. A process spending battery to collect something
// nobody can look at is the exact opposite of what this desktop is for.
//
// ⚠️ COPY AND PASTE ARE NOT TOUCHED. Ctrl+C and Ctrl+V are handled by the
// application itself through the Wayland clipboard; cliphist only listens.
// Nothing here binds either of them, and nothing here injects keys — picking an
// entry puts it ON the clipboard, and you then paste it wherever you like, the
// way you always would.
//
// There is no Wayland protocol for clipboard history, so this shells out —
// one of the five places the plan names for exactly that reason.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // { id: "42", preview: "some text" }, newest first — which is the order
    // cliphist prints and the order the list is read in.
    property var entries: []
    readonly property int count: entries.length

    // ⚠️ Not "the list is non-empty". An empty history on a fresh machine is
    // normal; a missing binary is not, and the page has to be able to tell the
    // difference between "nothing copied yet" and "this cannot work here".
    property bool available: false

    // ⚠️ NOTHING RUNS UNTIL SOMEBODY LOOKS. The history changes on every copy,
    // and following that would mean either a watch on the database or a poll —
    // for a list that is only ever read when the page is open. So `refresh()`
    // is called by the page when it opens, and at no other time. The service
    // costs nothing while it is not being read.
    function refresh() {
        list.running = true
    }

    // Put an entry back on the clipboard. Deliberately NOT pasting it: pasting
    // means injecting a keystroke into whatever has focus, which needs a tool
    // we do not ship and guesses at an application's key bindings. Selecting
    // copies; Ctrl+V pastes, as always.
    //
    // ⚠️ `cliphist decode` reads the ID from stdin, so this needs a shell for
    // the pipe. The id comes from our own parse of `cliphist list` and is
    // digits only — checked below rather than assumed, because building a shell
    // command out of unchecked text is how a clipboard entry becomes a command.
    function pick(id) {
        if (!root.available || !/^[0-9]+$/.test(String(id))) return
        copy.command = ["sh", "-c",
                        "cliphist decode " + id + " | wl-copy"]
        copy.running = true
    }

    function wipe() {
        if (!root.available) return
        clear.command = ["cliphist", "wipe"]
        clear.running = true
        root.entries = []
    }

    Process { id: copy }
    Process { id: clear }

    Process {
        id: list
        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                // Format, read off the real binary rather than its README:
                // "<id>\t<preview>" per line, newest first. The preview is
                // truncated by cliphist itself (-preview-width, default 100).
                var out = []
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i].length) continue
                    var tab = lines[i].indexOf("\t")
                    if (tab < 1) continue
                    out.push({ id: lines[i].substring(0, tab),
                               preview: lines[i].substring(tab + 1) })
                }
                root.entries = out
            }
        }

        // A missing binary exits non-zero and prints nothing. That is the
        // answer, not a fault: `available` stays false and the page says so
        // instead of showing an empty list that looks like "you copied nothing".
        onExited: function (code) { root.available = (code === 0) }
    }
}
