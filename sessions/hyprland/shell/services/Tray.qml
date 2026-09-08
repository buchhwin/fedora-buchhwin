pragma Singleton

// The system tray, or the honest absence of one.
//
// ⚠️ THIS EXISTED ONLY AS A DIRECT IMPORT BEFORE. Both the bar and the island's
// tray page reached into `Quickshell.Services.SystemTray` themselves, which
// broke the one rule services/qmldir states without exception: a service has an
// `available` flag so the ui can ASK rather than assume. Without it the page
// rebuilt the null-guard by hand and the bar did not guard at all — and "the
// tray host has not registered yet" reads as a hard error that takes the whole
// surface down, not as an empty tray.
//
// Nothing here polls. `SystemTray.items` is a live model; the count is a
// binding on it.
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Singleton {
    id: root

    readonly property var items: SystemTray.items

    // ⚠️ `.values` may not exist yet. The StatusNotifier host registers on the
    // bus asynchronously, so for the first moments of a session `items` is
    // there and `items.values` is not — reading `.length` off nothing throws,
    // and a throw inside a binding takes the surface with it.
    readonly property int count:
        root.items && root.items.values ? root.items.values.length : 0

    // An empty tray is not an unavailable one: the host is running, nothing has
    // asked for an icon. Saying "unavailable" there would make a bar hide its
    // tray section on a perfectly working machine — so this reports whether the
    // MODEL exists, and `count` answers how full it is.
    readonly property bool available: root.items !== null
                                      && root.items !== undefined

    // Left click. Whatever the program decided that means — usually show or
    // hide its window.
    function activate(item) {
        if (!item) return
        item.activate()
    }

    // Right click: the program's own menu, anchored to a real window.
    //
    // ⚠️ A tray menu NEEDS a window to open against, and it must be the surface
    // the click happened on — the bar's on the bar, the island's on the island.
    // Passing nothing makes the right-click do nothing at all, silently.
    function menu(item, window, x, y) {
        if (!item || !window) return
        item.display(window, x, y)
    }
}
