// Clicking beside the island closes it.
//
// niri has no focus-grab, so this cannot be had for free: it takes a real
// fullscreen surface that swallows the click.
//
// ⚠️ The opacity is 0.004 and that number is load-bearing. A surface that is
// FULLY transparent is treated as "not drawn" and is given an EMPTY input
// region — so it catches nothing and the island can never be dismissed. A
// hair above zero keeps it a real surface while remaining invisible.
//
// It exists only while the island is open, which is also why it cannot get in
// the way of anything else: there is nothing to get in the way of the rest of
// the time.

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../ipc"
import "../../services" as Services

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "buchhwin-catcher"
    // Below the island, above everything else: a click must reach this before
    // it reaches a window, but never before it reaches the island itself.
    //
    // ⚠️ THAT SENTENCE WAS A WISH, NOT A FACT, UNTIL THE PANEL MOVED UP. This
    // surface and the panel were both on `Top`, where stacking follows creation
    // order — and Shell.qml creates this one second, so it was in front of the
    // thing it is supposed to sit behind, and the panel could not be used at
    // all. The panel is on `Overlay` now; this one stays here, which is what
    // makes the comment true.
    // ⚠️⚠️ EXCEPT UNDER A FULLSCREEN WINDOW, WHERE `Top` IS BURIED. A fullscreen
    // window renders ABOVE the Top layer, so this surface ended up underneath
    // the very thing the click was supposed to travel past: the panel was on
    // Overlay and visible, this was on Top and unreachable, and a click beside
    // the panel went into the fullscreen application instead of closing it.
    // Reported as "wenn ich da dann im fullscreen mode das quickpannel öffne     // english-ok: the report, quoted
    // lässt es sich nur mit esc schließen nicht wenn ich wo andres hin clicke".  // english-ok: the report, quoted
    //
    // ⚠️ THE ISLAND ALREADY HAD THIS EXACT SWITCH — surface/ShellSurface.qml
    // raises itself to Overlay when a fullscreen window is on its screen — and
    // this file was left behind when that was written. Same expression, same
    // reason, and now the pair moves together.
    //
    // ⚠️ AND THE PARAGRAPH ABOVE STILL HOLDS: within one layer, stacking follows
    // creation order and Shell.qml builds this one after the panel, so raising
    // it would put it in FRONT of what it protects. That is why it only goes up
    // when it has to, and why what it is behind goes up with it — the island's
    // rule is the same shape for the same measured reason.
    WlrLayershell.layer: root.fullscreenHere ? WlrLayer.Overlay : WlrLayer.Top

    // Is a fullscreen window on this screen? The same question ShellSurface
    // asks, through the same service call, so the two cannot drift apart.
    readonly property bool fullscreenHere:
        root.screen ? Services.Compositor.focusedIsFullscreen(root.screen.width,
                                                              root.screen.height)
                    : false

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"            // literal-ok: absence of colour, not a colour

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        // Not zero — see above. Anything that reads this as "why not just 0"
        // will spend an afternoon on it.
        opacity: 0.004              // literal-ok: input-region threshold, not a style

        TapHandler { onTapped: Ipc.collapse() }
    }
}
