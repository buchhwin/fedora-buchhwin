pragma Singleton

// Build a palette out of a wallpaper.
//
// The output is an ordinary palette — the same 26 semantic names every
// hand-written one has — so nothing downstream needs to know where it came
// from. That is the whole reason this is cheap to add: Theme.qml, the renderer,
// GTK, Qt, kitty and niri all keep working unchanged.
//
// Three decisions, each of which is the difference between a scheme you would
// use and one you would switch off after a day:
//
//  * The seed is the most CHROMATIC colour, not the most frequent. Measured on
//    a real photograph: the frequent colours come back as #6f5848, #4e4037,
//    #baaa9c — near-grey browns, because most of a photo is sky, wall or
//    shadow. A scheme built on those is mud.
//  * Surfaces are a tonal ramp at the seed's HUE with the seed's chroma cut
//    hard. Tinted greys read as "themed"; the seed colour used as a background
//    reads as a mistake.
//  * Meaning stays put. Error is red, warning is yellow, success is green —
//    pulled a little towards the image so they belong, never replaced by it.
//    A forest wallpaper must not make the error colour green.
//
// Whether the result is READABLE is decided by `usable()` below — the same
// SANITY checks a hand-written palette faces (bg == fg, contrast, missing
// accent). It lives here rather than in the caller because there are now two
// callers, the shell and the headless tool, and a readability rule that exists
// twice is a readability rule that will disagree with itself.

import QtQuick
import Quickshell

Singleton {
    id: root

    // --------------------------------------------------------------- colour
    // Hue in degrees, saturation and lightness 0..1. Qt.hsla() takes 0..1 hue.
    function _hsl(c) {
        var r = c.r, g = c.g, b = c.b
        var max = Math.max(r, g, b), min = Math.min(r, g, b)
        var l = (max + min) / 2
        var d = max - min
        if (d === 0)
            return { h: 0, s: 0, l: l }
        var s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
        var h
        if (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6
        else if (max === g) h = ((b - r) / d + 2) / 6
        else h = ((r - g) / d + 4) / 6
        return { h: h, s: s, l: l }
    }

    function _mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, 1)
    }

    function _hex(c) {
        function h(v) {
            var s = Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16)
            return s.length < 2 ? "0" + s : s
        }
        return h(c.r) + h(c.g) + h(c.b)
    }

    // A tone at the seed's hue: chroma deliberately low for surfaces, higher
    // for anything meant to be looked at.
    function _tone(hue, sat, light) {
        return Qt.hsla(hue, Math.max(0, Math.min(1, sat)),
                       Math.max(0, Math.min(1, light)), 1)
    }

    // --------------------------------------------------------------- seeding
    // The most chromatic colour that is not nearly black or nearly white.
    // Extremes carry a hue but no usable one — a highlight's hue is noise.
    function seedOf(colors) {
        var best = null, bestScore = -1
        for (var i = 0; i < colors.length; i++) {
            var hsl = _hsl(colors[i])
            if (hsl.l < 0.12 || hsl.l > 0.9)
                continue
            // Prefer saturation, but do not chase a single neon pixel: a mid
            // lightness is worth something too.
            var score = hsl.s * (1 - Math.abs(hsl.l - 0.5))
            if (score > bestScore) { bestScore = score; best = hsl }
        }
        // Every candidate was black, white or grey: fall back to a neutral hue
        // rather than inventing one.
        return best ? best : { h: 0, s: 0, l: 0.5 }
    }

    // ----------------------------------------------------------- readability
    // Relative luminance, the one number that decides whether text on a
    // surface can be read at all.
    function luminance(hex) {
        function ch(v) {
            v = v / 255
            return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
        }
        var r = ch(parseInt(hex.substring(0, 2), 16))
        var g = ch(parseInt(hex.substring(2, 4), 16))
        var b = ch(parseInt(hex.substring(4, 6), 16))
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    // "" when the palette is fit to use, otherwise the reason it is not.
    //
    // A wallpaper that cannot produce a readable scheme must leave the current
    // one alone. An unreadable desktop is worse than one that did not change,
    // and it is worse still when it comes back that way after a restart.
    function usable(pal) {
        if (!pal || !pal.colors)
            return "no palette was built"
        var c = pal.colors
        if (c.base === c.text)
            return "background and text are the same colour"
        if (Math.abs(luminance(c.base) - luminance(c.text)) < 0.25)
            return "background and text do not contrast enough"
        if (!c.blue || !c.red || !c.green)
            return "the palette is missing a colour"
        return ""
    }

    // ---------------------------------------------------------------- build
    // `dark` decides the direction of the ramp. It is the USER's setting, not
    // the image's: a bright photo must not turn a dark desktop light.
    function build(colors, dark, name, source) {
        if (!colors || colors.length === 0)
            return null
        return fromSeed(seedOf(colors), dark, name, source,
                        "Wallpaper", "From the wallpaper")
    }

    // A whole palette from ONE colour the user picked.
    //
    // ⚠️ This is not a second palette generator. Everything below `seedOf()`
    // was already a pure function of (h, s, dark) — the image only ever
    // contributed those two numbers — so an entry point that supplies them
    // directly reuses the identical code. Two ways in, one way through; a
    // second generator would be a second look, which is the whole thing this
    // project exists to avoid.
    function fromColour(c, dark, name) {
        if (!c) return null
        return fromSeed(_hsl(c), dark, name, "",
                        "Custom", "From your own colour")
    }

    // The neutral scheme: themed, but colourless.
    //
    // Saturation zero, so the ramps come out grey — and the `achromatic` guard
    // below then keeps the accent grey too instead of inventing one. The
    // SEMANTIC colours stay anchored and therefore stay coloured, which is
    // correct: an error has to read as an error in a grey scheme as well.
    //
    // The hue is kept rather than zeroed: at saturation 0 it makes no
    // difference to the output, and keeping it means "neutral" and "colour" are
    // the same call with one number changed.
    function neutral(dark, hue) {
        return fromSeed({ h: hue || 0, s: 0, l: 0.5 }, dark, "neutral", "",
                        "Neutral", "Neutral grey")
    }

    // The shared body. `seed` is {h, s, l} with all three in 0..1.
    function fromSeed(seed, dark, name, source, family, displayName) {
        if (!seed) return null
        var h = seed.h

        // ⚠️ An image with no colour in it must not be handed one.
        //
        // seedOf falls back to hue 0 when every candidate is grey, and its
        // comment calls that "a neutral hue" — but hue 0 with a saturation
        // FLOOR of 0.45 is not neutral, it is red. Measured on a flat grey
        // image: the accent came out #ca7272, a pink invented from a picture
        // that contained nothing but grey. The floor is right for a photograph
        // whose colours are washed out; it is wrong when there are none.
        var achromatic = seed.s < 0.08

        // Surfaces keep a trace of the hue and almost none of the chroma.
        var sSurface = Math.min(seed.s, 0.18)
        var sMuted = Math.min(seed.s, 0.30)
        var sAccent = achromatic ? seed.s : Math.max(seed.s, 0.45)

        var out = {}
        function put(key, c) { out[key] = _hex(c) }

        if (dark) {
            put("crust",    _tone(h, sSurface, 0.07))
            put("mantle",   _tone(h, sSurface, 0.10))
            put("base",     _tone(h, sSurface, 0.13))
            put("surface0", _tone(h, sSurface, 0.18))
            put("surface1", _tone(h, sSurface, 0.23))
            put("surface2", _tone(h, sSurface, 0.28))
            put("overlay0", _tone(h, sMuted,   0.36))
            put("overlay1", _tone(h, sMuted,   0.45))
            put("overlay2", _tone(h, sMuted,   0.55))
            put("subtext0", _tone(h, sMuted,   0.68))
            put("subtext1", _tone(h, sMuted,   0.78))
            put("text",     _tone(h, 0.10,     0.90))
        } else {
            put("crust",    _tone(h, sSurface, 0.96))
            put("mantle",   _tone(h, sSurface, 0.93))
            put("base",     _tone(h, sSurface, 0.90))
            put("surface0", _tone(h, sSurface, 0.85))
            put("surface1", _tone(h, sSurface, 0.79))
            put("surface2", _tone(h, sSurface, 0.72))
            put("overlay0", _tone(h, sMuted,   0.62))
            put("overlay1", _tone(h, sMuted,   0.52))
            put("overlay2", _tone(h, sMuted,   0.44))
            put("subtext0", _tone(h, sMuted,   0.34))
            put("subtext1", _tone(h, sMuted,   0.26))
            put("text",     _tone(h, 0.12,     0.15))
        }

        var accentL = dark ? 0.62 : 0.42
        put("blue",      _tone(h, sAccent, accentL))
        put("sapphire",  _tone(h, sAccent, accentL + (dark ? 0.06 : -0.06)))
        put("sky",       _tone((h + 0.04) % 1, sAccent, accentL + 0.04))
        put("teal",      _tone((h + 0.08) % 1, sAccent, accentL))
        put("lavender",  _tone((h + 0.94) % 1, sAccent, accentL + 0.06))
        put("mauve",     _tone((h + 0.88) % 1, sAccent, accentL))
        put("pink",      _tone((h + 0.92) % 1, sAccent, accentL + 0.08))
        put("flamingo",  _tone((h + 0.96) % 1, Math.min(sAccent, 0.5), accentL + 0.1))
        put("rosewater", _tone(h, Math.min(sAccent, 0.35), accentL + 0.18))

        // Meaning first, image second. Each anchor is pulled a sixth of the way
        // towards the seed hue — enough to belong, not enough to lie.
        //
        // ⚠️ Hue is a CIRCLE. Subtracting two hues gives the wrong answer
        // whenever the shorter way round crosses zero: a pink seed at 0.94
        // against the red anchor at 0.0 is 0.06 away, not 0.94, and treating it
        // as 0.94 moved "red" a sixth of the way to 0.157 — which is yellow.
        // Measured on a real wallpaper, where the error colour came out
        // yellow-green.
        function _towards(from, to, amount) {
            var d = to - from
            if (d > 0.5) d -= 1
            if (d < -0.5) d += 1
            var out = from + d * amount
            return (out % 1 + 1) % 1
        }

        function anchored(anchorHue, sat, light) {
            return _tone(_towards(anchorHue, h, 1 / 6), sat, light)
        }
        put("red",    anchored(0.00, 0.65, dark ? 0.62 : 0.45))
        put("maroon", anchored(0.02, 0.55, dark ? 0.58 : 0.42))
        put("peach",  anchored(0.07, 0.65, dark ? 0.65 : 0.48))
        put("yellow", anchored(0.13, 0.65, dark ? 0.70 : 0.45))
        put("green",  anchored(0.30, 0.50, dark ? 0.60 : 0.40))

        return {
            name: name,
            family: family || "Derived",
            // What this came from — an image path, or the colour that was
            // picked. It is what lets a cached derived palette be trusted
            // across a restart: the file on disk is only still valid while it
            // names the source that is actually set.
            source: source || "",
            display_name: displayName || "Derived",
            dark: dark,
            // The accent the shell picks by default. `blue` is the seed itself
            // — the name is inherited from the palette schema, not a claim
            // about the colour.
            accents: ["blue", "mauve", "teal", "peach", "green"],
            colors: out
        }
    }
}
