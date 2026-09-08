pragma Singleton

// Where this desktop came from, and whether there is a newer one.
//
// ⚠️ IT HAS TO FIND ITS OWN REPOSITORY FIRST, AND THE OBVIOUS WAY IS WRONG.
// `Quickshell.shellDir` is the folder the shell was loaded from, and on an
// installed machine that folder is a SYMLINK: lib/60-shell.sh links
// ~/.config/quickshell/buchhwin to $REPO/shell so `qs -c buchhwin` resolves.
// Measured on the test machine, with a control (the same probe run from a real
// directory and again through a symlink to it):
//
//   qs -p /tmp/pp        shellDir = /tmp/pp                         the real path
//   qs -c pp (a symlink) shellDir = ~/.config/quickshell/pp         the LINK
//
// So the parent of `shellDir` is ~/.config/quickshell on any installed machine,
// which is not a repository and never will be. `readlink -f` first, then the
// parent — and that one rule is right in both cases, because resolving a path
// that is not a link is a no-op. This also answers the honest question rather
// than a near one: not "where might a checkout be" but "which tree is the
// desktop I am looking at actually running from".
//
// ⚠️ NOTHING HERE RUNS BY ITSELF. `probe()` is called by the page that shows
// the rows, once per shell life, and `check()` only when the button is pressed.
// An idle desktop must not be running `git fetch` — see services/Installed.qml
// for the same rule and the same reason.
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Singleton {
    id: root

    // True once we know what this machine is — including knowing it is not a
    // checkout, which is a real answer and the common one on a machine the tree
    // was rsynced to.
    readonly property bool available: root._probed
    property bool _probed: false

    // --------------------------------------------------------------- what we are
    property string repoDir: ""
    property bool isRepo: false          // the tree is there (install.sh, bin/bhctl)
    property bool isCheckout: false      // …and it is a git checkout
    property string commit: ""
    property string subject: ""
    property string date: ""
    property string branch: ""
    property int dirtyFiles: 0

    // --------------------------------------------------------------- what we found
    property bool busy: false
    property bool checked: false
    property string error: ""
    // One line per new commit, "abc1234  Subject". Empty after a successful
    // check means "already current", which is why `checked` is separate: an
    // empty list before any check is not the same statement.
    property var newCommits: []

    readonly property string statusLine: {
        if (!root._probed)
            return ""
        if (!root.isRepo)
            return "This shell is not running from a repository folder."
        if (!root.isCheckout)
            return root.repoDir + " is not a git checkout — it cannot pull."
        var s = root.branch + " at " + root.commit
        if (root.date.length > 0)
            s += ", " + root.date
        if (root.dirtyFiles > 0)
            s += " · " + root.dirtyFiles + " uncommitted file"
                 + (root.dirtyFiles === 1 ? "" : "s")
        return s
    }

    // ⚠️ THE REASON THE INSTALL BUTTON REFUSES BEFORE bhctl DOES. bhctl update
    // stops on a dirty tree, which is right, but it stops in a terminal the
    // person has just been made to open. Saying it here costs nothing and is
    // the same refusal one step earlier.
    readonly property bool canInstall:
        root.isCheckout && root.dirtyFiles === 0

    function probe() {
        if (root._probed || probeProc.running)
            return
        probeProc.running = true
    }

    function check() {
        if (root.busy || !root.isCheckout)
            return
        root.busy = true
        root.error = ""
        checkProc.running = true
    }

    // ⚠️ A TERMINAL, ON PURPOSE, AND DETACHED FROM US ON PURPOSE TOO.
    //
    //   * a terminal, because install.sh needs sudo. A button that silently
    //     waits on a password prompt nobody can see is a button that hangs.
    //   * detached, because install.sh RESTARTS buchhwin-shell. A Process
    //     owned by this shell would be killed by the very update it is running,
    //     somewhere in the middle. Quickshell.execDetached reparents it away
    //     from us before that can happen.
    function install() {
        if (!root.canInstall)
            return
        var argv = Config.program("@terminal")
        if (!argv.length)
            return
        // The same shape the `@terminal -e btop` binding resolves to — one
        // string per argument, never a command line in one string.
        argv.push("-e")
        argv.push(root.repoDir + "/bin/bhctl")
        argv.push("update")
        Quickshell.execDetached(argv)
    }

    function _bucketed(text) {
        var out = {}
        var cur = ""
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var ln = lines[i]
            if (ln.indexOf("--") === 0) {
                cur = ln.substring(2)
                if (out[cur] === undefined)
                    out[cur] = []
                continue
            }
            if (cur.length > 0 && ln.length > 0)
                out[cur].push(ln)
        }
        return out
    }

    function _first(b, name) {
        return (b[name] && b[name].length) ? b[name][0] : ""
    }

    Process {
        id: probeProc

        // ⚠️ NO SHELL BRACE SYNTAX IN HERE. This is a JavaScript template
        // literal, so `$` followed by a brace is an INTERPOLATION: a shell
        // default like a colon-dash fallback makes QML try to parse shell as
        // JavaScript and the whole file fails to load — services/Installed.qml
        // carries the same warning after paying for it once. Plain `$var` and
        // `$(cmd)` are safe, and the one interpolation below is deliberate.
        command: ["sh", "-c", `
            sd=$(readlink -f "${Quickshell.shellDir}" 2>/dev/null)
            repo=$(dirname "$sd")
            printf '%s\\n' "--repo" "$repo"
            if [ -f "$repo/install.sh" ] && [ -f "$repo/bin/bhctl" ]; then
                printf '%s\\n' "--isrepo" "yes"
            fi
            if git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
                printf '%s\\n' "--checkout" "yes"
                printf '%s\\n' "--commit" "$(git -C "$repo" log -1 --format=%h 2>/dev/null)"
                printf '%s\\n' "--subject" "$(git -C "$repo" log -1 --format=%s 2>/dev/null)"
                printf '%s\\n' "--date" "$(git -C "$repo" log -1 --format=%cd --date=format:'%-d %b %Y' 2>/dev/null)"
                printf '%s\\n' "--branch" "$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)"
                printf '%s\\n' "--dirty" "$(git -C "$repo" status --porcelain 2>/dev/null | wc -l)"
            fi
            printf '%s\\n' "--end"
        `]
        stdout: StdioCollector { id: probeOut }

        onExited: function (code) {
            var b = root._bucketed(probeOut.text)
            root.repoDir = root._first(b, "repo")
            root.isRepo = root._first(b, "isrepo") === "yes"
            root.isCheckout = root.isRepo && root._first(b, "checkout") === "yes"
            root.commit = root._first(b, "commit")
            root.subject = root._first(b, "subject")
            root.date = root._first(b, "date")
            root.branch = root._first(b, "branch")
            root.dirtyFiles = Number(root._first(b, "dirty")) || 0
            // ⚠️ `_probed` even on a bad exit. A machine where this fails is a
            // machine where the rows say "cannot update from here" and stop —
            // retrying forever would be the runaway process on exactly the
            // machine that can least afford one.
            root._probed = true
        }
    }

    Process {
        id: checkProc

        command: ["sh", "-c", `
            cd "${root.repoDir}" 2>/dev/null || {
                printf '%s\\n' "--error" "the repository folder is gone" "--end"
                exit 0
            }
            up=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
            if [ -z "$up" ]; then
                printf '%s\\n' "--error" "this branch does not follow a remote one" "--end"
                exit 0
            fi
            if ! msg=$(git fetch --quiet 2>&1); then
                printf '%s\\n' "--error" "$msg" "--end"
                exit 0
            fi
            printf '%s\\n' "--commits"
            git log --format='%h  %s' "HEAD..$up" 2>/dev/null
            printf '%s\\n' "--end"
        `]
        stdout: StdioCollector { id: checkOut }

        onExited: function (code) {
            var b = root._bucketed(checkOut.text)
            root.busy = false
            root.error = root._first(b, "error")
            root.newCommits = b["commits"] ? b["commits"] : []
            // Only a check that actually reached the remote counts as one. With
            // an error the list is empty, and an empty list is otherwise read as
            // "already current" — the wrong sentence to put under a failure.
            root.checked = root.error.length === 0
        }
    }
}
