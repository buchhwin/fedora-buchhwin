// The emoji picker, on Mod+. — the same key Windows and GNOME use, which is
// the one his fingers already know.
//
// ⚠️ THERE WAS NOTHING AT ALL BEFORE THIS. The colour emoji font is installed
// and there was no way to reach a character with it: one of the three gaps he
// picked out on 08.08.2026.
//
// ⚠️ THE LIST IS A GENERATED FILE, NOT A TABLE TYPED BY HAND AND NOT A LOOKUP
// AT RUNTIME. Fedora ships no emoji-test.txt (checked: nothing under
// /usr/share/unicode/emoji, and no package owns that path), so there is nothing
// on the machine to read. The names come from Python's `unicodedata` and were
// written out ONCE into emoji.json — a data file in the repository, the same
// way the palettes are. Nothing computes it at startup and nothing needs Python
// at runtime, which is the house rule.
//
// ⚠️ AND IT INSERTS TWO WAYS, BECAUSE ONE OF THEM CANNOT BE RELIED ON. `wtype`
// synthesises the keystrokes through the virtual-keyboard protocol, which is
// what you want — the character lands in the window you were in. It is also a
// protocol a compositor may refuse. So the clipboard is the fallback, and the
// page SAYS WHICH ONE HAPPENED rather than leaving you to wonder why nothing
// appeared. A silent fallback is a tool you cannot trust.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../theme"
import "../../../ipc"
import "../../common"

Item {
    id: root

    // The notch pages are sized by their content; this one is a grid, so it
    // states its size rather than growing to fit 1429 characters.
    implicitWidth: 620
    implicitHeight: 380

    property var all: []
    property string query: ""
    property string group: ""
    property string note: ""

    readonly property var groups: ["Smileys", "People", "Nature", "Objects", "Symbols", "Travel"]

    FileView {
        id: data
        // ⚠️ Quickshell.shellDir, not a path relative to this file. The greeter
        // runs the same tree from /usr/share/buchhwin and the desktop from a
        // symlink in ~/.config — a relative path resolves differently in the
        // two, and this file has to be found in both.
        path: Quickshell.shellDir + "/ui/notch/pages/emoji.json"
        blockLoading: true
        onLoaded: root.reread()
        onLoadFailed: {
            root.note = "emoji.json is missing — the picker has nothing to show"
            root.all = []
        }
    }

    function reread() {
        try {
            root.all = JSON.parse(data.text()).emoji || []
        } catch (e) {
            root.all = []
            root.note = "emoji.json does not parse: " + e
        }
    }

    Component.onCompleted: root.reread()

    // ⚠️ FILTERED IN ONE PASS INTO AN ARRAY, not with a `visible:` on 1429
    // delegates. A Repeater builds every delegate it is given whether or not it
    // is visible, so hiding them costs the same as showing them — and this is a
    // laptop.
    readonly property var shown: {
        var q = root.query.toLowerCase().trim()
        var g = root.group
        if (q.length === 0 && g.length === 0)
            return root.all.slice(0, 300)
        var out = []
        for (var i = 0; i < root.all.length && out.length < 300; i++) {
            var e = root.all[i]
            if (g.length > 0 && e.g !== g)
                continue
            if (q.length > 0 && e.n.indexOf(q) < 0)
                continue
            out.push(e)
        }
        return out
    }

    function pick(ch) {
        // Clipboard first and always: it is the one that cannot fail, and it
        // means the character is recoverable even if the typing does not land.
        copy.command = ["wl-copy", "--", ch]
        copy.running = true

        root.pending = ch
        type.command = ["wtype", "--", ch]
        type.running = true
    }

    property string pending: ""

    Process {
        id: copy
        onExited: function (code) {
            if (code !== 0)
                root.note = "wl-copy failed (" + code + ")"
        }
    }

    Process {
        id: type
        onExited: function (code) {
            // ⚠️ THE BRANCH IS NAMED. Not "copied" for both — the difference
            // between "it is in your window" and "it is in your clipboard" is
            // the difference between working and looking broken.
            root.note = code === 0
                ? root.pending + "  typed into the focused window"
                : root.pending + "  copied — wtype could not type it"
                  + (code === 127 ? " (wtype is not installed)" : "")
            root.pending = ""
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space3

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space2

            TextField {
                id: search
                Layout.fillWidth: true
                placeholder: "Search emoji"
                onTextChanged: root.query = text
                focus: true
            }

            Repeater {
                model: root.groups
                Pill {
                    id: gPill
                    required property var modelData
                    interactive: true
                    active: root.group === gPill.modelData
                    onClicked: root.group = (root.group === gPill.modelData) ? "" : gPill.modelData
                    BarText {
                        text: gPill.modelData
                        font.pixelSize: Theme.fontSizeSm
                        color: gPill.active ? Theme.accentFg : Theme.fgMuted
                    }
                }
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: grid.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Grid {
                id: grid
                width: parent.width
                columns: Math.max(1, Math.floor(width / (Theme.space6 + Theme.space2)))
                spacing: Theme.space1

                Repeater {
                    model: root.shown
                    Rectangle {
                        id: cell
                        required property var modelData
                        width: Theme.space6 + Theme.space1
                        height: Theme.space6 + Theme.space1
                        radius: Theme.radiusSm
                        color: hov.hovered ? Theme.pillHover : "transparent"   // literal-ok: absence of colour

                        Behavior on color {
                            enabled: Theme.animate
                            ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                        }

                        HoverHandler { id: hov }
                        TapHandler { onTapped: root.pick(cell.modelData.c) }

                        Text {
                            anchors.centerIn: parent
                            text: cell.modelData.c
                            font.pixelSize: Theme.fontSizeXl
                            // ⚠️ NO `color`. A colour emoji font carries its own
                            // colours, and setting one here tints the glyph on
                            // some Qt builds and does nothing on others.
                        }
                    }
                }
            }
        }

        BarText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSizeSm
            color: Theme.fgMuted
            text: root.note.length > 0 ? root.note
                : root.all.length === 0 ? "no emoji loaded"
                : root.shown.length + " of " + root.all.length
                  + (root.shown.length >= 300 ? " — keep typing to narrow it" : "")
        }
    }

    Keys.onEscapePressed: function (event) {
        if (root.query.length > 0 || root.group.length > 0) {
            root.query = ""; root.group = ""; search.text = ""
            event.accepted = true
        }
        // Otherwise it falls through and the surface closes — the forwarding
        // chain set up on 09.08. is what makes that work.
    }
}
