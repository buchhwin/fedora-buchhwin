// The settings window — a REAL niri window, not a surface floating over one.
//
// ⚠️ THAT IS THE DECISION THIS FILE EXISTS TO RECORD, and it is his. Everything
// else this shell opens is a layer surface: the notch pages, the launcher, the
// toasts. Those are things you look at and dismiss. This is a thing you WORK in
// — you move it, you push it to another workspace, you leave it open beside
// whatever you are adjusting — and a layer surface can do none of that.
//
// It also has to be a window because of what is on it. Half these settings
// change how OTHER windows look: corner radius, gaps, opacity, blur, shadow. A
// pane on the overlay layer would cover the only evidence that the setting did
// anything, so you would be adjusting the look of windows you cannot see.
//
// ⚠️ `FloatingWindow` HAS NO `appId`. Checked in quickshell 0.2.1's own type
// data rather than assumed: it carries `title`, `minimumSize`, `maximumSize`,
// `minimized`, `maximized` and `fullscreen`, and the app-id is whatever Qt
// gives the process. The niri window rule that rounds and floats this window
// therefore matches on the id READ OFF THE RUNNING MACHINE with
// `niri msg -j windows`, not on a name invented here. See tools/niri.qml.
//
// There is no title bar to remove: `prefer-no-csd` is already in the generated
// config, so niri asks every client to draw none and draws none itself.
import QtQuick
import Quickshell
import "../../ipc"
import "../../theme"
import "../common"

FloatingWindow {
    id: root

    title: "Settings"

    // A working size on the 4 px grid, and one that still fits the 1280x800 the
    // lab VM runs at. niri decides where it lands; the window rule makes it
    // float rather than joining the scrolling row.
    //
    // ⚠️ IT GREW WITH THE PAGE SPLIT. Twenty-one entries under three headings is
    // a taller sidebar than ten unlabelled ones, and One UI's spacing is airier
    // than what it replaced — at the old height the list scrolled before the
    // window was even full, which is the opposite of what splitting the pages
    // was for. 960x704 still leaves room on the 1280-wide machine.
    implicitWidth: Theme.space6 * 30
    implicitHeight: Theme.space6 * 22
    minimumSize: Qt.size(Theme.space6 * 18, Theme.space6 * 12)

    // ⚠️ The window is CREATED when the settings open and destroyed when they
    // close — ui/Shell.qml loads it on `Ipc.settingsOpen`, the same way the
    // launcher is loaded. So `closed` is the other direction of the same
    // switch: niri can shut this window (Mod+Q, and it is a window like any
    // other), and without this the shell would still believe it was open and
    // `settings toggle` would do nothing on the next press.
    onClosed: Ipc.hideSettings()

    color: "transparent"                    // literal-ok: absence of colour

    GlassPane {
        anchors.fill: parent
        // Matched by `geometry-corner-radius` in the generated window rule, so
        // niri's clip and shadow follow the same shape this paints. Both come
        // from `look.rounding`, which is the one number.
        radius: Theme.radiusXl
        fill: Theme.panelBg
    }

    SettingsContent {
        anchors.fill: parent
        focus: true
    }

    // ⚠️⚠️ THE ONE THING A POPUP LIST CANNOT DO FOR ITSELF. `PopupWindow` is its
    // own Wayland surface — chosen precisely so no `clip` or z-order can reach
    // it — and the price is that a click BESIDE it lands in this window, where
    // the list cannot see it. Three attempts to detect it from inside the popup
    // all failed, the last one measured dead in tools/popup-close-check.qml:
    // over a whole open-click-away cycle the sheet's `activeFocus` never
    // changed, and `closed` never fired.
    //
    // His words for what should happen: "wenn man irgendwo anders hinklickt      // english-ok: the request, quoted
    // dann schließt sich das dropdown menü einfach ohne was zu tun". So the      // english-ok: the request, quoted
    // press is SWALLOWED, not passed on — letting it through would also switch
    // whatever tab it landed on, which is not "ohne was zu tun".            // english-ok: the request, quoted
    //
    // ⚠️ THIS IS NOT THE CATCHER THIS PROJECT DELETED. That one was permanent
    // and invisible and ate clicks meant for the tabs behind it. This one is
    // `enabled` only while a list is open, and an `enabled: false` MouseArea is
    // not in the delivery path at all. Proven in both directions on the lab VM:
    // with no list open the widget below was hit, with a list open the press was
    // swallowed and the widget below was NOT hit, and immediately afterwards it
    // was hit again.
    //
    // ⚠️ AND IT CANNOT COVER THE LIST ITSELF, which is the whole reason this
    // works: the popup is a different surface, so choosing an entry is a click
    // that never comes near this item.
    MouseArea {
        anchors.fill: parent
        enabled: OpenMenu.current !== null
        acceptedButtons: Qt.AllButtons
        onPressed: OpenMenu.closeCurrent()
    }
}
