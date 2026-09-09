pragma Singleton

// The design tokens. This is the single place a colour, a radius, a spacing
// step, a duration or a font is decided — for the shell AND for every foreign
// application we theme (see tools/render.qml).
//
// Nothing else in the project may contain a literal colour or radius. CI
// enforces that, because "keep it consistent" survives about three weeks
// without a machine checking it.
//
// Everything here is derived from two inputs: the 26-name palette and the
// handful of numbers in Config.look. Change the palette and the whole desktop
// follows, including GTK, Qt, kitty and the compositor — and, since M9, the login screen,
// which runs this same file from a copy in /usr/share/buchhwin because the
// greeter user cannot read a 0700 home. The line that used to stand here said
// "there is no greeter yet"; `bhctl greeter sync` is what keeps that true copy
// in step, and `bhctl greeter status` says when it has drifted.

import QtQuick
import Quickshell
import "../config"
import "."

Singleton {
    id: root

    // ---------------------------------------------------------------- helpers

    // Lightness steps in HSL, not Qt.lighter/darker: those scale VALUE, which
    // on an already-dark surface barely moves and on a saturated accent shifts
    // the hue's apparent colour. A flat lightness delta behaves the same on
    // every palette, which is the whole point of having nine of them.
    function shift(c, delta) {
        var col = Qt.color(c)
        var l = Math.max(0, Math.min(1, col.hslLightness + delta))
        return Qt.hsla(col.hslHue, col.hslSaturation, l, col.a)
    }
    function lighten(c, d) { return shift(c, d) }
    function darken(c, d)  { return shift(c, -d) }

    function alpha(c, a) {
        var col = Qt.color(c)
        return Qt.rgba(col.r, col.g, col.b, a)
    }

    // Perceived brightness, weighted the way an eye actually works — green
    // carries most of it. Used to pick a foreground that stays readable on any
    // accent, including the light palettes where white-on-accent is unreadable.
    function luminance(c) {
        var col = Qt.color(c)
        return Math.sqrt(0.299 * col.r * col.r +
                         0.587 * col.g * col.g +
                         0.114 * col.b * col.b)
    }
    // ⚠️ A NAME, because the renderer has to apply the same rule against a
    // DIFFERENT colour set. Theme is bound to the one active Scheme, so
    // Theme.on() always answers out of the system palette — which is the wrong
    // answer when a single program is being themed neutral grey. The renderer
    // therefore reimplements the choice, and reads the threshold from here so
    // there is one number rather than two that drift.
    readonly property real onThreshold: 0.55
    function on(c) { return luminance(c) > onThreshold ? p("crust") : p("text") }

    function p(key) { return Scheme.color(key) }

    readonly property bool dark: Scheme.dark
    // Elevation moves one way on dark palettes and the other on light ones.
    readonly property real lift: dark ? 0.04 : -0.04

    // ----------------------------------------------------------------- colour

    // ------------------------------------------------- black or scheme-tinted
    //
    // His request, 10.08.2026: the surfaces THIS PROJECT DRAWS — notch, quick
    // settings, the settings window, and everything that belongs to them — can
    // be plain black and fully opaque instead of tinted by the palette and
    // slightly see-through. Black is the default; the switch back is on the
    // Effects page.
    //
    // ⚠️ APPLICATIONS ARE NOT AFFECTED, and that is structural rather than a
    // promise: foreign themes are written by tools/render.qml, which reads the
    // PALETTE (`Scheme`) directly and never looks at this file. kitty, GTK, Qt
    // and the rest keep their colours whatever this is set to.
    //
    // ⚠️⚠️ "BLACK" IS THE BACKGROUND, NOT EVERY SURFACE, and the difference is
    // the whole reason this is a ladder and not one colour. On 10.08.2026 a
    // sweep found eight places where an element was drawn in exactly its
    // parent's colour — measured at a contrast ratio of 1.000:1, which is to
    // say invisible. ⚠️ That sweep was a SENTENCE for months and nothing else:
    // which eight it never said, and nothing could reproduce it.
    // tests/contrast.sh is that measurement now, over every palette, and the
    // structural one it named is fixed below at `pillBg`. Collapsing all five steps onto #000000 would ship that
    // fault everywhere, on purpose. So the base is true black and the steps
    // above it are small, deliberate lifts that keep every element findable.
    //
    // ⚠️ The foreground and accent colours are untouched. He asked for black
    // surfaces, not for a colourless desktop.
    readonly property bool blackSurfaces:
        Config.look ? String(Config.look.surfaceStyle) === "black" : true

    readonly property color bg:            blackSurfaces ? "#000000" : p("base")
    readonly property color bgDim:         blackSurfaces ? "#000000" : p("mantle")
    readonly property color bgDeep:        blackSurfaces ? "#000000" : p("crust")
    readonly property color surface:       blackSurfaces ? "#0f0f0f" : p("surface0")
    readonly property color surfaceHigh:   blackSurfaces ? "#1a1a1a" : p("surface1")
    readonly property color surfaceHigher: blackSurfaces ? "#262626" : p("surface2")
    readonly property color overlay:       blackSurfaces ? "#3a3a3a" : p("overlay0")
    readonly property color outline:       blackSurfaces ? "#4a4a4a" : p("overlay1")
    readonly property color outlineStrong: blackSurfaces ? "#5e5e5e" : p("overlay2")

    readonly property color fg:         p("text")
    readonly property color fgMuted:    p("subtext1")
    readonly property color fgDim:      p("subtext0")
    readonly property color fgDisabled: p("overlay2")

    // ⚠️ Guarded for the same reason as Scheme's `name`: `Config.theme` is null
    // for a moment while JsonAdapter builds. `p("")` would hand back the magenta
    // sentinel and paint it for a frame, so the fallback is the same key the
    // config declares as its default rather than nothing.
    readonly property string accentName: Config.theme ? Config.theme.accent : "green"
    readonly property color accent:       p(accentName)
    readonly property color accentFg:     on(accent)
    readonly property color accentHover:  lighten(accent, 0.06)
    readonly property color accentActive: darken(accent, 0.06)
    readonly property color accentAlt:    p("teal")

    readonly property color ok:      p("green")
    readonly property color warn:    p("yellow")
    readonly property color error:   p("red")
    readonly property color info:    p("sapphire")
    readonly property color okFg:    on(ok)
    readonly property color warnFg:  on(warn)
    readonly property color errorFg: on(error)
    readonly property color infoFg:  on(info)

    // Role colours. These carry the translucency, so a component never writes
    // an alpha value itself — that is how six different "panel background"
    // opacities crept into the old stack.
    // ⚠️ FULLY OPAQUE IN BLACK MODE — that is the other half of what he asked
    // for: black and fully opaque, not merely dark. The setting keeps its value;
    // it is simply not consulted while black is on, so switching back restores
    // what he had rather than what the switch happened to leave behind.
    readonly property real panelOpacity:
        blackSurfaces ? 1.0 : Config.look.opacityPanel

    // The terminal's own background transparency, written into kitty's config.
    // Separate from panelOpacity on purpose: a panel sits over a wallpaper and
    // wants to stay legible, a terminal sits over whatever is behind it and is
    // read as a foreground object regardless.
    readonly property real terminalOpacity: Config.look.opacityTerminal
    readonly property color barBg:     alpha(bgDeep, panelOpacity)
    // ⚠️ CLAMPED. In black mode `panelOpacity` is already 1, and 1.06 is not a
    // valid alpha — Qt would take it or clip it depending on the path, which is
    // exactly the kind of "probably fine" that this file does not rely on.
    function opaquer(step) { return Math.min(1, panelOpacity + step) }

    readonly property color panelBg:   alpha(bgDeep, opaquer(0.06))
    // ⚠️⚠️ `surfaceHigh`, NOT `surface`, AND THAT IS THE EIGHT-COLLISION FIX.
    // A pill sits ON a card, and `cardBg` is `alpha(surface, 0.92)` — so while
    // `pillBg` was also built from `surface` the two were the same colour and
    // the pill was invisible. Measured at 1.000:1 in ALL ELEVEN palettes by
    // tests/contrast.sh, which is the suite that finally made the sweep from
    // 10.08.2026 reproducible instead of a sentence in a comment.
    //
    // ⚠️ AND IT IS THE PILL THAT MOVES, NOT THE CARD. Cards are the larger,
    // calmer surface and their step is shared with everything else built on
    // `surface`; lifting the small thing that sits on top costs one step and
    // touches one role, where lowering the card would have moved every panel
    // under it.
    //
    // ⚠️ `pillHover` GOES UP WITH IT, or the hover state would collapse onto the
    // resting state instead — trading one invisible pair for another. The whole
    // ladder keeps its spacing; it is shifted, not squashed.
    readonly property color pillBg:    alpha(surfaceHigh, panelOpacity)
    readonly property color pillHover: alpha(surfaceHigher, opaquer(0.08))
    readonly property color cardBg:    alpha(surface, 0.92)
    readonly property color cardHover: alpha(surfaceHigh, 0.96)
    readonly property color menuBg:    alpha(bgDim, opaquer(0.08))
    readonly property color menuSelBg: accent
    readonly property color menuSelFg: accentFg
    readonly property color scrim:     alpha(bgDeep, 0.55)
    readonly property color shadow:    alpha("#000000", dark ? 0.45 : 0.18)

    // ----------------------------------------------------------------- glass
    //
    // What makes a translucent panel read as a pane of glass rather than as a
    // tinted rectangle is its EDGE, not its middle. The middle is blur, and the
    // compositor already does that — for free, once, via xray. So these four
    // tokens describe a rim and a sheen and nothing else.
    //
    // ⚠️ Deliberately NOT a shader. Refraction needs to sample what lies behind
    // the window, and a layer surface cannot see that — only the compositor
    // can. A shader here would have to draw and blur its own copy of the
    // wallpaper to refract, duplicating the one thing the compositor already does
    // cheaply, and paying for it every frame on a laptop. A gradient costs one
    // draw and no per-frame work.
    //
    // ⚠️ ONE TOKEN, NOT FOUR. There were a top rim, a side rim and a glint along
    // the bottom edge. The ring went first — on screen it reads as a border and
    // was reported as one. The glint went on 06.08.2026, on a direct answer:
    // asked whether the fine line along the bottom should stay now that the red
    // corners were going, the answer was "ganz weg" — the panes are to have no  english-ok: quoted answer
    // edge at all, like the windows, which have neither border nor focus ring.
    //
    // ⚠️ That DEPARTS from the two reference screenshots, which both show the
    // line. The newer instruction wins over the older one, and the note it
    // contradicts has been corrected rather than left to disagree.
    //
    // Tokens are deleted rather than set to transparent: a token with no reader
    // is the same debt as a config key with no reader.
    //
    // What is left is the sheen — light lying over the top of the pane, fading
    // out well before the middle. Any further and it stops reading as light and
    // starts reading as a lighter background.
    readonly property color glassSheen:     alpha(fg, dark ? 0.07 : 0.10)

    // ⚠️⚠️ THE PASSWORD FIELD HAS ITS OWN FILL, AND IT IS NOT `pillBg`. He asked
    // for it: "kannst du die auch transparent und kleiner machen wie bei mac".  // english-ok: his request, quoted
    //
    // `pillBg` is `alpha(surfaceHigh, panelOpacity)`, and `panelOpacity` is 1
    // whenever "our own surfaces are black and opaque" is on — which is the
    // default and which he asked for. That rule is about the notch, the quick
    // panel, the settings window, the launcher, the dock and the toasts; the
    // lock screen and the greeter are deliberately NOT on that list, because
    // they stand on a photograph rather than on the desktop.
    //
    // So the field cannot inherit that token: over a wallpaper it comes out as
    // an opaque grey slab, which is exactly what he was looking at. This one
    // stays translucent whatever `panelOpacity` says, and the GlassPane behind
    // it supplies the blur that makes it legible.
    readonly property color lockFieldBg:    alpha(surfaceHigh, dark ? 0.30 : 0.38)

    // ----------------------------------------------------------------- shape

    readonly property int r: Config.look.rounding
    readonly property int radiusXs:   Math.round(r * 0.33)
    readonly property int radiusSm:   Math.round(r * 0.5)
    readonly property int radiusMd:   r
    readonly property int radiusLg:   Math.round(r * 1.33)
    readonly property int radiusXl:   Math.round(r * 1.66)
    readonly property int radiusPill: 999

    readonly property int borderWidth: Config.look.borderWidth
    // The optional edge on OUR panes. 0 by default, which is the look asked
    // for; the settings window will make it a row rather than a discovery.
    readonly property int panelBorderWidth: Config.look.panelBorderWidth

    // One device pixel at scale 1, and the width of the glass rim. It is a
    // token rather than a bare 1 so the tripwire stays honest and so a future
    // "thicker edges" setting has one place to land.
    readonly property int hairline: 1

    // ---------------------------------------------------------------- spacing
    // One 4px grid. No "about ten pixels" anywhere.
    //
    // ⚠️ `look.uiScale` multiplies the grid and the type together, and nothing
    // else — see the note on the key. Rounded to whole pixels at every step, or
    // a scale of 0.9 turns the 4 px grid into 3.6 and every gap in the shell
    // stops landing on a pixel boundary.
    readonly property real scale: Config.look.uiScale
    readonly property int space1: Math.round(4 * scale)
    readonly property int space2: Math.round(8 * scale)
    readonly property int space3: Math.round(12 * scale)
    readonly property int space4: Math.round(16 * scale)
    readonly property int space5: Math.round(24 * scale)
    readonly property int space6: Math.round(32 * scale)

    // ------------------------------------------------------------- typography

    readonly property string fontUi:   Config.look.fontUi
    readonly property string fontMono: Config.look.fontMono
    readonly property string fontIcon: Config.look.fontIcon

    // ⚠️⚠️ THE SECOND ICON FONT, AND IT IS NOT A SETTING. Everything on this
    // desktop draws from `fontIcon` — Material Icons Round, which Fedora
    // packages — except the three status symbols in the notch, which he asked
    // to look like Windows: "nimm bitte die windows symbole her, das ist echt   // english-ok: the request, quoted
    // kacke". The real ones are Segoe Fluent Icons and may not be
    // redistributed; his choice was Microsoft's open set instead.
    //
    // ⚠️ IT IS A CONSTANT RATHER THAN A KEY because there is exactly one file
    // it can name: assets/fonts/BuchhwinFluentIcons.ttf is a 21-glyph subset
    // made here, and a setting pointing anywhere else would draw replacement
    // boxes. Rule 6 says every value on screen gets a key — this is not a value
    // on screen, it is the name of a file this repository ships.
    readonly property string fontFluent: "Buchhwin Fluent Icons"    // literal-ok: the family name of a file this repo ships
    readonly property int fontSizePt:  Config.look.fontSize
    // pt -> px at the 96dpi Qt assumes; the compositor handles real scaling.
    readonly property int fontSize:    Math.round(fontSizePt * 4 / 3 * root.scale)
    readonly property int fontSizeSm:  Math.round(fontSize * 0.86)
    // ⚠️ ONE STEP BELOW `Sm`, AND IT HAS EXACTLY ONE READER ON PURPOSE. The week
    // strip in the hovered notch sits beside a clock that is the thing you are
    // looking at, and he asked for it smaller: "mach links im hover … die       // english-ok: the request, quoted
    // anzeige vom tag etwas kleiner". Everything else that needs "small" means  // english-ok: the request, quoted
    // `Sm`; a scale with two neighbouring steps used interchangeably stops
    // being a scale.
    readonly property int fontSizeXs:  Math.round(fontSize * 0.74)
    readonly property int fontSizeLg:  Math.round(fontSize * 1.15)
    readonly property int fontSizeXl:  Math.round(fontSize * 1.45)
    readonly property int fontSizeDisplay: Math.round(fontSize * 5.2)

    // Four weights, no interpolation. Fedora's quickshell has no
    // DropExpensiveFonts escape hatch, and every distinct variable-font axis
    // value materialises its own rasterised face in memory.
    readonly property int weightNormal:   400
    readonly property int weightMedium:   500
    readonly property int weightSemibold: 600
    readonly property int weightBold:     700

    // ---------------------------------------------------------------- motion
    // Calm: three durations, one curve, no overshoot anywhere. Motion explains
    // a state change; if there is no state change there is no motion.
    // Something that is still there but no longer the thing you are looking at
    // — the launcher's category column while a search is running. A token
    // rather than a number typed where it is needed, for the same reason every
    // colour is: one dimmed thing and another dimmed thing have to match.
    readonly property real dimmed: 0.45

    // ⚠️ THE FLOOR UNDER A FADE, and it exists because one went too far. The
    // week strip in the hovered island faded with distance from today down to
    // 0.15, which is a decoration on a surface people are meant to READ — he
    // reported it as "die textfarbe … beim tag … muss heller werden damit man   // english-ok: the report, quoted
    // den text besser lesen kann". A fade still has to leave something legible  // english-ok: the report, quoted
    // at its far end, and where that end is belongs here rather than typed into
    // whichever file happens to fade: two faded things have to match, the same
    // argument `dimmed` above makes for itself.
    readonly property real faded: 0.55

    readonly property bool animate: Config.look.profile !== "minimal"

    // ⚠️⚠️ THREE NUMBERS, AND THEY USED TO BE ONE MULTIPLIER. The paragraph
    // that stood here argued for the multiplier: 120/200/320 is not three
    // independent numbers, the fade being faster than the settle is what makes
    // content look like it arrives INSIDE a shape rather than after it, and a
    // multiplier cannot break that ratio while three settings can.
    //
    // The argument is still true. He asked for the three anyway, from a picture
    // of the page he wanted — Movement, Fades & colour, Hover response — with
    // the cost on the table. So the ratio is now a default rather than a
    // guarantee, and the defaults are his numbers: 400 / 200 / 150.
    //
    // ⚠️ `look.profile: minimal` and `motion.reduce` BOTH stop the movement,
    // and they are not the same switch. `minimal` is a machine decision (no
    // blur, no shadows, no glass either); `reduce` keeps the desktop looking
    // exactly as it does and only stops it moving.
    //
    // ⚠️ Clamped and guarded: the block reads as null during shell
    // construction, and a zero would put a division by zero into every
    // Behavior in the shell.
    function _ms(v, fallback) {
        var n = Config.motion ? Number(v) : NaN
        if (!(n >= 0))
            return fallback
        return Math.round(Math.max(0, Math.min(2000, n)))
    }

    readonly property bool reduceMotion: Config.motion ? Config.motion.reduce === true : false

    readonly property int durSlow: (animate && !reduceMotion)
                                   ? _ms(Config.motion ? Config.motion.durMove : 400, 400) : 0
    readonly property int durBase: (animate && !reduceMotion)
                                   ? _ms(Config.motion ? Config.motion.durFade : 200, 200) : 0
    readonly property int durFast: (animate && !reduceMotion)
                                   ? _ms(Config.motion ? Config.motion.durHover : 150, 150) : 0

    // ⚠️ KEPT, because tools/hypr.qml writes the compositor's `slowdown` from it and the
    // compositor has one number, not three. Derived from the movement duration
    // against its default rather than stored twice — the setting he sees is the
    // one that decides, and the compositor follows it.
    readonly property real motionSpeed: {
        var d = durSlow
        if (!(d > 0))
            return 1
        return Math.max(0.25, Math.min(4, 400 / d))
    }

    // ⚠️ THIS WAS OutExpo FOR ONE ROUND AND THAT WAS MY MISTAKE. The argument
    // was that the compositor opens windows with `ease-out-expo`, so matching it would
    // make the compositor and the shell move alike. The argument is fine and
    // the application was wrong: the compositor uses expo for a window's OPACITY AND
    // SCALE as it appears, and SPRINGS for anything that changes size.
    //
    // OutExpo puts about 99 % of the distance into the first third of the
    // duration and then crawls. On a fade that reads as decisive. On a SHAPE it
    // reads as a snap followed by a drift — and since every Behavior in this
    // shell inherits this one token, every panel, notch and card got the snap.
    // He reported it as the animations still being buggy after a commit whose
    // whole subject was fixing them.
    //
    // OutCubic lands. The snappiness comes from the duration being 150 ms
    // instead of 200, which is a number, rather than from a curve that arrives
    // early and then waits.
    readonly property int easing: Easing.OutCubic

    // ------------------------------------------------------------- the bounce
    //
    // His picture asks for a "Bounce" percentage, and a percentage has to mean
    // something or it is a slider that lies. It means the OVERSHOOT of the
    // movement curve: how far past its target a shape travels before settling.
    //
    // ⚠️ MOVEMENT ONLY, AND THAT IS DELIBERATE. Overshoot on a fade or a colour
    // means going past the target opacity, which is either invisible or a
    // flicker — so `easing` above stays OutCubic for those, and only geometry
    // uses this pair. The row says "movement" for the same reason.
    //
    // ⚠️ TWO TOKENS, because Qt needs both: `Easing.OutBack` is the curve and
    // `easing.overshoot` is how much. At bounce 0 the curve goes back to
    // OutCubic rather than to OutBack with overshoot 0 — the two are not the
    // same shape, and "no bounce" should be the curve the rest of the shell
    // uses, not a special case of the bouncy one.
    readonly property int bouncePercent:
        Config.motion ? Math.max(0, Math.min(100, Number(Config.motion.bounce) || 0)) : 0
    readonly property int easingMove:
        bouncePercent > 0 ? Easing.OutBack : easing
    // 100 % maps to Qt's own default overshoot (1.70158), which is the value
    // the curve was designed around — so the top of the slider is "the normal
    // bounce", not an invented maximum.
    readonly property real overshootMove: bouncePercent * 0.0170158

    readonly property bool effects: Config.look.profile !== "minimal"
    readonly property bool blur:    Config.look.blur && effects
    readonly property bool shadows: Config.look.shadows && effects
    readonly property bool glass:   Config.look.glass && effects

    // ------------------------------------------------------------------ misc
    // Hex without alpha, for the foreign config files that cannot take rgba.
    function hex(c) {
        var col = Qt.color(c)
        function h(v) { var s = Math.round(v * 255).toString(16); return s.length < 2 ? "0" + s : s }
        return "#" + h(col.r) + h(col.g) + h(col.b)
    }
    function hexNoHash(c) { return hex(c).substring(1) }
}
