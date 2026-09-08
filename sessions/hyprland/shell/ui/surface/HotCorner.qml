// A few pixels in a corner of the screen that open something when you rest in
// them.
//
// His decision, 06.08.2026: the TOP-RIGHT corner is ours and opens the
// notifications. The top-left stays niri's, where it toggles the overview —
// one gesture may not mean two things, and this project has already paid for
// that lesson once with the fullscreen strip. `left` and `both` remain settings
// (choosing either also switches niri's off, in tools/niri.qml), but the
// default is `right`.
//
// ⚠️ AND IT WAITS. A corner that fires the moment the pointer brushes it is a
// trap rather than a shortcut: you reach for something, you cross the corner,
// and a panel appears over what you were aiming at. `hotCornerDwellMs` is the
// whole difference between the two, and it is a setting rather than a constant
// because how long feels right is not something anyone can decide for somebody
// else.
//
// ⚠️ THE CORNER FITS INSIDE THE RESERVED BAND ON PURPOSE. The strut reserves
// the notch's height (34) at the top, so no window ever reaches y < 34 — a
// 24 px corner therefore steals nothing from anybody. Growing it past the
// strut would start eating clicks meant for whatever is underneath.
//
// ─────────────────────────────────────────────────────────────────────────────
// ⚠️ EVERYTHING THE PREVIOUS HEADER CLAIMED HERE WAS WRONG, AND IT COST TWO
// ROUNDS. It is written down because the mistake was in the MEASUREMENT, not in
// the code, and that is the part worth remembering:
//
//   * "It draws nothing." It draws. Measured by diffing a screenshot with the
//     corner on against one with it off: 576 changed pixels, x 1896..1919,
//     y 0..23 — exactly 24×24 in the corner, at y=0, not pushed down by the
//     strut. The earlier "zero pixels" came from hunting a colour in a single
//     screenshot; the wallpaper here is orange and the probe was yellow.
//   * "No QML warning of any kind in the shell's log." There were two, on every
//     single start: `Setting 'width' is deprecated. Set 'implicitWidth'
//     instead.` They were in the journal the whole time, saying that the pair
//     the header recommended is the wrong one.
//   * "The hover never fires." It fires: `hover true at 9 12`, and 250 ms later
//     `dwell fired`. What made it look dead is the loop below.
//
// The lesson is not "colour it in first" — that part was done. It is that a
// probe needs a CONTROL: the same screenshot without the thing in it. A colour
// picked by eye out of a photograph is a guess wearing a measurement's clothes.
// ─────────────────────────────────────────────────────────────────────────────

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../config"

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    // "left" or "right". Only the top edge for now: the bottom corners are
    // where windows put their resize grips.
    required property string corner
    // What to do when the pointer has stayed long enough.
    signal triggered()

    WlrLayershell.namespace: "buchhwin-hotcorner"

    // ⚠️ `Overlay`, NOT `Top`, and this is what turned a resting pointer into a
    // strobe. ClickCatcher — the full-screen surface that closes an open panel
    // when you click beside it — also sits on `Top` and is created later, so it
    // covered the corner the moment the corner had done its job. The pointer
    // never moved and the corner saw: hover, fire, LEAVE (the catcher), enter
    // again, fire again. Measured at 2 s a cycle, opening and closing the
    // notifications for as long as the pointer rested there.
    //
    // Above the catcher, `hovered` means what it says: the pointer is in the
    // corner. That is what `armed` below is allowed to rely on, and it is why
    // there is no timer here trying to guess the difference.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        left: root.corner === "left"
        right: root.corner === "right"
    }

    // Reserves nothing, and — the part that matters — is not moved by anything
    // else that does. Strut.qml says it in full: -1 "does not mean 'reserve
    // nothing', it additionally means DO NOT MOVE ME". Without it the notch's
    // own strut would push this 34 px down the screen, and a hot corner that is
    // not in the corner is not a hot corner.
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"          // literal-ok: absence of colour

    // ⚠️ `implicitWidth`/`implicitHeight`. quickshell 0.2.1 warns on every start
    // that `width`/`height` are deprecated on a layer surface, and the old note
    // here recommended exactly the deprecated pair on the strength of a
    // measurement that was itself wrong. Verified after the change: still 24×24
    // in the corner, still hovering, and the two warnings are gone.
    implicitWidth: Theme.space2 * 3
    implicitHeight: Theme.space2 * 3

    // Fires once per visit. Without it, `hovered` staying true would keep
    // restarting the dwell every time anything else on screen changed, and a
    // corner that keeps re-triggering while you rest in it is the strobe
    // described above wearing a different hat. Re-armed by LEAVING, which is
    // the one thing that unambiguously means "this visit is over".
    property bool armed: true

    // ⚠️ A RECTANGLE WITH `opacity: 0.004`, NOT AN EMPTY ITEM — and the answer
    // was already in this repository. ui/surface/ClickCatcher.qml does exactly
    // this and says why: "Not zero — anything that reads this as 'why not just
    // 0' will spend an afternoon on it." A surface that draws nothing at all
    // has nothing to receive a pointer.
    Rectangle {
        id: hitArea
        anchors.fill: parent
        color: Theme.scrim
        opacity: 0.004          // literal-ok: input-region threshold, not a style

        HoverHandler {
            id: hover
            onHoveredChanged: {
                if (!hovered) {
                    dwell.stop()
                    root.armed = true
                } else if (root.armed) {
                    dwell.restart()
                }
            }
        }
    }

    // ⚠️ The timer is what makes this usable rather than hostile. It restarts on
    // entry and stops on exit, so crossing the corner does nothing at all and
    // resting in it does the thing.
    Timer {
        id: dwell
        interval: Config.surfaces.hotCornerDwellMs
        onTriggered: {
            root.armed = false
            root.triggered()
        }
    }
}
