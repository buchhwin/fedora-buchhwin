pragma ComponentBehavior: Bound

// The system tray, as a page of the island.
//
// The tray already lives on the bar. It has to live here as well, and that is
// not duplication — the bar is OFF in the default setup, and the rule this
// shell is built to is that no function may be reachable only through a surface
// the user has switched off. Every bar function needs a key and an ipc verb too.
//
// ⚠️ A tray MENU needs a window to open against. On the bar that is the bar's
// own surface; here it is the island's, handed down through `hostWindow`.
// Without it a right-click does nothing at all, silently — which is why the
// plan reserved a separate popup host for this. It turned out not to be needed:
// the island is a real window and it is present exactly when this page is.
import QtQuick
import "../../../theme"
import "../../../services" as Services
import "../../common"

Item {
    id: root

    // The window tray menus anchor to. Handed down from ShellSurface through
    // NotchContent; without it `display()` has nowhere to put the menu.
    property var hostWindow: null

    readonly property int cell: Theme.space6 * 2

    // The guard used to be rebuilt here by hand, because the tray was reached
    // through a direct import rather than through a service. It lives in
    // services/Tray.qml now, where the other services keep theirs — the tray
    // host registers on the bus asynchronously, so for the first moments of a
    // session `items.values` does not exist and reading it throws.
    readonly property int itemCount: Services.Tray.count

    implicitWidth: Math.max(Theme.space6 * 10,
                            itemCount * (cell + Theme.space2))
    implicitHeight: cell

    // One sentence, not an empty box. On a machine with nothing in the tray
    // this is the honest and complete answer.
    BarText {
        anchors.centerIn: parent
        visible: root.itemCount === 0
        color: Theme.fgMuted
        text: "Nothing in the tray"
    }

    Row {
        anchors.centerIn: parent
        spacing: Theme.space2

        Repeater {
            model: Services.Tray.items

            Pill {
                id: trayPill
                required property var modelData
                interactive: true

                Image {
                    source: trayPill.modelData.icon
                    sourceSize.width: Theme.fontSizeXl
                    sourceSize.height: Theme.fontSizeXl
                    width: Theme.fontSizeXl
                    height: Theme.fontSizeXl
                    asynchronous: true
                }

                onClicked: Services.Tray.activate(trayPill.modelData)
                // Anchored to the island's own window, below it — the same call
                // the bar makes, with a different host.
                onRightClicked: if (root.hostWindow)
                    Services.Tray.menu(trayPill.modelData, root.hostWindow,
                                       trayPill.x, root.height)
            }
        }
    }
}
