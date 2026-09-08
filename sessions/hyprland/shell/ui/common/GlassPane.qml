// A translucent panel that reads as a pane of glass.
//
// What makes glass look like glass is its EDGE. The middle of a translucent
// panel is just blurred backdrop, and the compositor already produces that —
// once, cheaply, via niri's xray blur. So everything here is about the edge: a
// sheen lying over the upper part of the pane, and a fine glint along the
// bottom where light bounces back up through it.
//
// ⚠️ THERE IS NO EDGE AT ALL ANY MORE, and that is a decision rather than an
// omission. First the ring went — a gradient rectangle behind the body, showing
// as a hairline all the way round, reported as "the quick panel still has a
// border round it, that should go". What survived that was the glint along the
// bottom, because both reference screenshots show "a fine lighter line along the
// bottom edge".
//
// On 06.08.2026 the glint went too. Asked directly whether it should stay once
// the red corners were fixed, the answer was "ganz weg": the panes are to look  english-ok: quoted answer
// like the windows, and the windows have neither border nor focus ring
// (`border { off }`, `focus-ring { off }` in the generated niri config).
//
// ⚠️ THIS DEPARTS FROM THE REFERENCE SCREENSHOTS. That is deliberate and the
// newer instruction wins; it is written down here so nobody later "restores"
// the line by going back to the pictures.
//
// What is left for anyone who wants an edge is `look.panelBorderWidth`, which
// is 0 by default and draws a real border when it is not — one key, one reader,
// and a row in the settings window when that exists.
//
// ⚠️ WHY THERE IS NO SHADER HERE. Refraction — the thing that actually bends
// what is behind the glass — needs to sample the backdrop, and a layer surface
// cannot see its own backdrop. Only the compositor can. A shader in here would
// have to draw and blur its own copy of the wallpaper in order to refract it,
// which duplicates the one thing niri does for free and pays for it on every
// frame. On a laptop that trade is the wrong way round. hyprglass does real
// refraction because it runs inside Hyprland's render pipeline; niri has no
// plugin interface, so that road is closed rather than merely harder.
//
// Cost: one extra draw for the sheen, no per-frame work, nothing running when
// the surface is closed. `look.glass false` (or `look.profile minimal`) removes
// it and leaves the plain body.

import QtQuick
import "../../theme"

Item {
    id: root

    // The body colour. Callers pass their own so a bar, a card and a page can
    // differ in tint without each re-deriving what "glass" means.
    property color fill: Theme.panelBg
    property int radius: Theme.radiusLg

    Rectangle {
        id: body
        anchors.fill: parent
        radius: root.radius
        color: root.fill
        // Off by default. `border.width: 0` draws nothing at all, so this costs
        // one comparison and no pixels in the state everybody runs.
        border.width: Theme.panelBorderWidth
        border.color: Theme.outline
    }

    // The sheen. It stops well before the middle: any further and it stops
    // reading as light on a surface and starts reading as a lighter background.
    Rectangle {
        anchors.fill: body
        radius: body.radius
        visible: Theme.glass
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.glassSheen }
            GradientStop { position: 0.38; color: "transparent" }  // literal-ok: absence of colour
        }
    }

}
