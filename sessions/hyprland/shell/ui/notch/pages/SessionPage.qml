pragma ComponentBehavior: Bound

// Lock, suspend, log out, restart, shut down.
//
// It exists because `Super+Shift+E` was bound straight to the compositor's `quit`: one
// keystroke, no question, every unsaved thing gone. A session menu is not
// decoration around that — the SECOND press is the feature.
//
// So: choose an action, and it asks. Enter or a second press on the same action
// carries it out, anything else backs out. Locking and suspending skip the
// question, because both are reversible and asking about them is the kind of
// dialog people learn to dismiss without reading — which is exactly how the
// habit forms that makes the shutdown question useless too.
// ⚠️ Icon names are LIGATURES, and Fedora ships "Material Icons Round", not the
// newer "Material Symbols". `logout` and `restart_alt` are Symbols names: they
// do not resolve here and render as the literal letters — measured at 500 px and
// 700 px wide against a 100 px font, where a real glyph is about 70. On screen
// that showed as a missing icon and a wrong one. tests/icons.sh now measures
// every name the shell uses, so the next one cannot ship unnoticed.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../theme"
import "../../../ipc"
import "../../../services" as Services
import "../../common"

ColumnLayout {
    id: root
    spacing: Theme.space3
    implicitWidth: Theme.space6 * 14

    // Which action is armed, i.e. asked about. Empty = nothing pending.
    property string pending: ""

    Component.onCompleted: keys.forceActiveFocus()

    // ⚠️ THE LIST LIVES IN services/Session.qml NOW. It was spelled out here, and
    // then he asked for the same five in the quick panel's corner — at which
    // point a copy would have been the fault this project has already paid for
    // four times. `restart_alt` and `logout` are in this file's own history as
    // names that did not resolve; a second table is a second chance at that.
    readonly property var actions: Services.Session.actions

    property int cursor: 0

    function activate(i) {
        if (i < 0 || i >= root.actions.length)
            return
        var a = root.actions[i]
        if (a.ask && root.pending !== a.id) {
            root.pending = a.id
            return
        }
        // ⚠️ THE SERVICE RUNS IT, THE PAGE CLOSES ITSELF. Session.qml imports no
        // Ipc — services/qmldir forbids ui imports — so collapsing the notch
        // stays here, where it is true, rather than in a service that would
        // have to be right about two different surfaces.
        Services.Session.run(a.id)
        Ipc.collapse()
    }

    Item {
        id: keys
        Layout.fillWidth: true
        implicitHeight: 0
        focus: true
        Keys.onLeftPressed: { root.pending = ""; root.cursor = Math.max(0, root.cursor - 1) }
        Keys.onRightPressed: { root.pending = ""; root.cursor = Math.min(root.actions.length - 1, root.cursor + 1) }
        Keys.onReturnPressed: root.activate(root.cursor)
        Keys.onEnterPressed: root.activate(root.cursor)
        Keys.onEscapePressed: {
            // Escape backs out of the question first, and only then closes.
            // Otherwise an armed shutdown would still be armed the next time
            // the page opened.
            if (root.pending.length) root.pending = ""
            else Ipc.collapse()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space2

        Repeater {
            model: root.actions

            Pill {
                id: tile
                required property int index
                required property var modelData

                readonly property bool armed: root.pending === modelData.id

                Layout.fillWidth: true
                interactive: true
                // Accent marks the ARMED action, not merely the one under the
                // cursor: on this page the difference between "highlighted" and
                // "about to happen" is the whole point.
                active: armed

                ColumnLayout {
                    spacing: Theme.space1

                    Icon {
                        Layout.alignment: Qt.AlignHCenter
                        text: tile.modelData.icon
                        size: Theme.fontSizeXl
                        color: tile.armed ? Theme.accentFg
                             : tile.index === root.cursor ? Theme.fg : Theme.fgMuted
                    }

                    BarText {
                        Layout.alignment: Qt.AlignHCenter
                        text: tile.modelData.label
                        font.pixelSize: Theme.fontSizeSm
                        color: tile.armed ? Theme.accentFg
                             : tile.index === root.cursor ? Theme.fg : Theme.fgMuted
                    }
                }

                onClicked: {
                    root.cursor = tile.index
                    root.activate(tile.index)
                }
            }
        }
    }

    BarText {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: Theme.fontSizeSm
        color: root.pending.length ? Theme.warn : Theme.fgMuted
        text: root.pending.length
              ? "Press again to confirm — Escape cancels"
              : "Arrow keys choose · Enter confirms"
    }
}
