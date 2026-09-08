pragma Singleton

// Google Drive as a folder, through rclone.
//
// ⚠️ NOT GNOME ONLINE ACCOUNTS, AND HE CHOSE THAT. GOA plus gvfs is the way
// this normally goes and it would put Drive in Nautilus with no work at all —
// but it drags in gnome-control-center to sign in with, which is a second GTK
// application in a desktop whose first rule is that there are none. rclone is
// already in packages/dnf-sysadmin.txt, speaks Drive natively, and mounts it as
// an ordinary directory that every program can see, not only GTK ones.
//
// ⚠️ THE STATE COMES FROM systemd, NOT FROM shell.json. The same rule the power
// profile tile was rebuilt around on 09.08.: a mount can fail, a token can
// expire, the network can go away — and a switch that remembers its own
// position would go on saying "on" through all three. `systemctl --user
// is-active` is the answer, and it is the only answer.
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Singleton {
    id: root

    readonly property bool fake: !!Quickshell.env("BUCHHWIN_SHELL_FAKE")
    readonly property string home: Quickshell.env("HOME") || ""

    // Whether rclone is installed at all, whether a remote has been configured,
    // and whether the mount is up. Three different answers, three different
    // things to say.
    property bool installed: false
    property bool configured: false
    // Every remote rclone knows, for the suggestion list in the
    // settings row — the names are the user's, not ours.
    property var remotes: []
    property bool mounted: false
    property string status: ""

    readonly property string remote: Config.drive ? Config.drive.remote : "gdrive"
    readonly property string mountPoint:
        Config.drive && String(Config.drive.mountPoint).length > 0
            ? String(Config.drive.mountPoint).replace("~", root.home)
            : root.home + "/Drive"

    // ⚠️ "AVAILABLE" MEANS THE SWITCH CAN DO SOMETHING. Not installed and not
    // configured are both "no", and the tile says which — because the fix is
    // different: one is a package, the other is a browser sign-in.
    readonly property bool available: root.installed && root.configured

    function toggle() {
        if (root.fake) { root.status = "fake mode — nothing was mounted"; return }
        if (!root.installed) { root.status = "rclone is not installed"; return }
        if (!root.configured) {
            root.status = "No remote called " + root.remote + " — run: bhctl drive setup"
            return
        }
        root.status = ""
        act.command = ["systemctl", "--user", root.mounted ? "stop" : "start",
                       "buchhwin-drive.service"]
        act.running = true
    }

    // ------------------------------------------------------------- the reads
    Process {
        id: haveRclone
        command: ["sh", "-c", "command -v rclone >/dev/null && echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.installed = String(this.text).trim() === "yes"
                if (root.installed)
                    listRemotes.running = true
            }
        }
    }

    // ⚠️ `rclone listremotes` READS A CONFIG FILE AND TALKS TO NOBODY. It does
    // not touch the network, so it is safe to run at startup — which matters,
    // because the alternative (asking Drive whether the token still works)
    // would be a network round trip every time the shell restarts.
    Process {
        id: listRemotes
        command: ["rclone", "listremotes"]
        stdout: StdioCollector {
            onStreamFinished: {
                var want = root.remote + ":"
                var lines = String(this.text).split("\n")
                var found = false, names = []
                for (var i = 0; i < lines.length; i++) {
                    var t = lines[i].trim()
                    if (t.length === 0)
                        continue
                    if (t === want)
                        found = true
                    // rclone prints "name:" — the colon is its syntax, not part
                    // of the name, and leaving it on would make every suggestion
                    // one character wrong.
                    names.push(t.replace(/:$/, ""))
                }
                root.remotes = names
                root.configured = found
                readMount.running = true
            }
        }
    }

    Process {
        id: readMount
        command: ["systemctl", "--user", "is-active", "buchhwin-drive.service"]
        stdout: StdioCollector {
            onStreamFinished: root.mounted = String(this.text).trim() === "active"
        }
        // ⚠️ is-active EXITS NON-ZERO WHEN IT IS NOT ACTIVE, and that is not a
        // failure — it is the answer. The same shape that made `bhctl greeter
        // status` print a stray line an hour ago.
        onExited: function (code) { /* the collector already has the word */ }
    }

    Process {
        id: act
        onExited: function (code) {
            if (code !== 0)
                root.status = "systemd refused (" + code + ") — journalctl --user -u buchhwin-drive"
            settle.restart()
        }
    }

    // ⚠️ A MOUNT TAKES A MOMENT, so the read after a switch is delayed rather
    // than immediate — otherwise the tile reports the state from before the
    // thing it just did.
    Timer { id: settle; interval: 1200; onTriggered: readMount.running = true }

    Component.onCompleted: if (!root.fake) haveRclone.running = true
}
