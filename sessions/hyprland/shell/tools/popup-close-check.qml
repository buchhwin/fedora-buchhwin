// What actually happens to a PopupWindow when you click somewhere else?
//
//   BUCHHWIN_TOOL=popup-close-check qs -p shell
//   … click the box, then click away, then read /tmp/buchhwin-popup-close.log
//
// ⚠️⚠️ THE FAULT THIS EXISTS FOR IS THE ONE THAT HAS BEEN "FIXED" THREE TIMES.
// ui/common/Dropdown.qml opens a menu that will not close on a click beside it:
//
//   attempt 1  a child of the row            the group card's `clip` cut it off
//   attempt 2  reparented to contentItem     a construct used nowhere else here
//   attempt 3  `onActiveFocusChanged` on the sheet, with an `everFocused` latch
//
// The third is still in the file and still does not work. What every one of them
// has in common is that none was ever measured — the signal was chosen because
// it sounded like the right one.
//
// ⚠️ AND THE MENU CANNOT BE DRIVEN WHERE IT LIVES. Measured on the lab VM with a
// control: a synthetic click lands on a LAYER SURFACE (clicking the bar switched
// workspace), and lands on the SESSION LOCK (the password was typed in), but
// neither a click nor a keystroke reaches the settings window, which is a
// quickshell `FloatingWindow`. Three click timings and a typed string, all
// byte-identical screenshots. So the real dropdown cannot be exercised here at
// all — hence a stand.
//
// ⚠️ WHAT THIS STAND CANNOT SAY, stated before its results are used: its popup
// hangs off a `PanelWindow`, not a `FloatingWindow`. Parent surface type is
// therefore the one variable it does not hold still. It answers "does this
// signal fire at all, and which one", not "the settings window behaves exactly
// so".
//
// The three candidates it watches, all read out of quickshell's own type
// description rather than guessed:
//
//   Signal   closed                 on ProxyWindowBase — what a compositor
//                                   dismissing an xdg-popup should surface as
//   Property backingWindowVisible   the real surface, as opposed to `visible`,
//                                   which is bound to our own flag
//   activeFocus on the content      what attempt 3 hangs on
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../theme"

Scope {
    id: root

    property string report: ""
    FileView { id: out; path: "/tmp/buchhwin-popup-close.log" }
    function note(s) { root.report += s + "\n"; out.setText(root.report) }

    property bool menuOpen: false

    // ⚠️ A COUNTER, NOT A BOOLEAN. "Did `closed` fire" is answered by a flag;
    // "did it fire on the way up as well" is only answered by counting, and an
    // extra firing during opening is exactly what would make a naive
    // `onClosed: menuOpen = false` close the menu before it is on screen — the
    // trap attempt 3 documents for focus and never checked for anything else.
    property int closedCount: 0
    property int backingHides: 0
    property int focusGains: 0
    property int focusLosses: 0

    PanelWindow {
        id: panel
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"                        // literal-ok: absence of colour
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.namespace: "buchhwin-popupcheck"

        // ⚠️ THE CATCHER EXISTS ONLY WHILE A MENU IS OPEN, and that is the whole
        // difference from the one this project deleted. That one was permanent
        // and invisible, so it ate clicks meant for the tabs behind it — the bug
        // nobody suspects. This one cannot: with no menu open it is not enabled,
        // and `enabled: false` on a MouseArea is not in the delivery path at all.
        //
        // ⚠️ AND IT CONSUMES THE CLICK ON PURPOSE. His words are "wenn man        // english-ok: the request, quoted
        // irgendwo anders hinklickt dann schließt sich das dropdown menü einfach  // english-ok: the request, quoted
        // ohne was zu tun" — the first click closes and does nothing else, which  // english-ok: the request, quoted
        // is what every desktop menu does. Passing it through would ALSO switch
        // the tab it landed on.
        MouseArea {
            anchors.fill: parent
            z: 100          // literal-ok: above the stand's content, ordering only
            enabled: root.menuOpen
            acceptedButtons: Qt.AllButtons
            onPressed: {
                root.note("  CATCHER swallowed a press    menuOpen was "
                          + root.menuOpen)
                root.menuOpen = false
            }
        }

        // The widget underneath, so "the catcher is gone when no menu is open"
        // is a reading rather than a hope.
        Rectangle {
            id: target
            x: 700; y: 200; width: 200; height: 48   // literal-ok: a stand
            color: Theme.surface
            radius: Theme.radiusSm
            property int hits: 0
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    target.hits++
                    root.note("  the widget below was hit     total "
                              + target.hits)
                }
            }
            Text { anchors.centerIn: parent; text: "target " + target.hits; color: Theme.fg }
        }

        Rectangle {
            id: field
            x: 200; y: 200; width: 240; height: 48   // literal-ok: a stand, not a surface of the product
            color: Theme.surfaceHigh
            radius: Theme.radiusSm

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.menuOpen = !root.menuOpen
                    root.note("  click on the box             menuOpen now "
                              + root.menuOpen)
                }
            }

            Text {
                anchors.centerIn: parent
                text: root.menuOpen ? "open" : "closed"
                color: Theme.fg
            }
        }

        PopupWindow {
            id: popup
            // Exactly the shape ui/common/Dropdown.qml uses today, so that what
            // this measures is that shape and not a nicer one.
            visible: root.menuOpen
            color: "transparent"                    // literal-ok: absence of colour
            anchor.item: field
            anchor.rect.y: field.height
            anchor.edges: Edges.Bottom | Edges.Left
            anchor.gravity: Edges.Bottom | Edges.Right
            anchor.adjustment: PopupAdjustment.All
            grabFocus: true
            implicitWidth: 240                      // literal-ok: a stand
            implicitHeight: 160                     // literal-ok: a stand

            onClosed: {
                root.closedCount++
                root.note("  SIGNAL closed                #" + root.closedCount
                          + "  visible=" + popup.visible
                          + "  backing=" + popup.backingWindowVisible)
            }

            onBackingWindowVisibleChanged: {
                if (!popup.backingWindowVisible)
                    root.backingHides++
                root.note("  backingWindowVisible ->      "
                          + popup.backingWindowVisible
                          + "  (our visible=" + popup.visible + ")")
            }

            Rectangle {
                id: sheet
                anchors.fill: parent
                color: Theme.menuBg
                focus: true
                onActiveFocusChanged: {
                    if (sheet.activeFocus) root.focusGains++
                    else root.focusLosses++
                    root.note("  sheet.activeFocus ->         "
                              + sheet.activeFocus)
                }
            }
        }
    }

    Component.onCompleted: root.note("buchhwin popup-close-check — click the box, then click away")

    // ⚠️ IT ENDS BY ITSELF. A stand that waits for a person is a stand that gets
    // left running, and a second quickshell instance of the same config makes
    // `qs -c <name> ipc` unresolvable for everything else — measured, twice.
    Timer {
        running: true
        interval: 25000
        onTriggered: {
            root.note("")
            root.note("  closed fired          " + root.closedCount + "x")
            root.note("  backing went hidden   " + root.backingHides + "x")
            root.note("  focus gained          " + root.focusGains + "x")
            root.note("  focus lost            " + root.focusLosses + "x")
            Qt.callLater(Qt.quit)
        }
    }
}
