// Headless: print every token for the active palette.
//
//   QT_QPA_PLATFORM=offscreen qs -p shell/tools/dump-tokens.qml
//
// Used by CI ("every token resolves for every palette") and by anyone asking
// "where does this colour come from". Writes to /tmp/buchhwin-tokens.txt
// because console.log does not reach stdout under quickshell's default log
// rules — a tool that logs its findings reports nothing at all.

import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
import "../config"
import "../common"

Scope {
    id: root
    property string buf: ""
    function say(s) { buf += s + "\n"; out.setText(buf) }

    FileView { id: out; path: "/tmp/buchhwin-tokens.txt" }

    function row(name, value) {
        var pad = "                        ".substring(0, Math.max(0, 22 - name.length))
        say("  " + name + pad + value)
    }

    // Wait for the data, not for a duration. The previous fixed 600 ms timer
    // was the bug: it touched Scheme for the FIRST time inside itself, so the
    // palette only started loading in the line that read it, `ready` was always
    // false, and every palette silently reported the built-in fallback. See
    // WaitFor.qml.
    WaitFor {
        condition: Config.settled && Scheme.ready

        onTimedOut: {
            // A dump that cannot see its palette must fail, not print the
            // fallback under the palette's name. tests/all-palettes.sh greps
            // for this line.
            say("  FAIL: palette did not load — " +
                (Scheme.failure.length ? Scheme.failure : "no reason reported"))
            Qt.callLater(Qt.quit)
        }

        onReady: {
            say("palette      " + Scheme.name + "  (" + Scheme.displayName + ", family " +
                Scheme.family + ", dark=" + Scheme.dark + ", ready=" + Scheme.ready + ")")
            say("accent       " + Config.theme.accent)
            say("")
            say("SURFACE")
            row("bg", Theme.hex(Theme.bg));                 row("bgDim", Theme.hex(Theme.bgDim))
            row("bgDeep", Theme.hex(Theme.bgDeep));         row("surface", Theme.hex(Theme.surface))
            row("surfaceHigh", Theme.hex(Theme.surfaceHigh))
            row("surfaceHigher", Theme.hex(Theme.surfaceHigher))
            row("overlay", Theme.hex(Theme.overlay));       row("outline", Theme.hex(Theme.outline))
            say("")
            say("CONTENT")
            row("fg", Theme.hex(Theme.fg));                 row("fgMuted", Theme.hex(Theme.fgMuted))
            row("fgDim", Theme.hex(Theme.fgDim));           row("fgDisabled", Theme.hex(Theme.fgDisabled))
            say("")
            say("ACCENT + STATUS")
            row("accent", Theme.hex(Theme.accent));         row("accentFg", Theme.hex(Theme.accentFg))
            row("accentHover", Theme.hex(Theme.accentHover))
            row("accentActive", Theme.hex(Theme.accentActive))
            row("ok", Theme.hex(Theme.ok));                 row("warn", Theme.hex(Theme.warn))
            row("error", Theme.hex(Theme.error));           row("info", Theme.hex(Theme.info))
            row("errorFg", Theme.hex(Theme.errorFg));       row("warnFg", Theme.hex(Theme.warnFg))
            say("")
            say("ROLES (with alpha)")
            row("barBg", String(Theme.barBg));              row("panelBg", String(Theme.panelBg))
            row("pillBg", String(Theme.pillBg));            row("pillHover", String(Theme.pillHover))
            row("cardBg", String(Theme.cardBg));            row("scrim", String(Theme.scrim))
            row("shadow", String(Theme.shadow))
            say("")
            say("SHAPE / SPACING")
            row("radius xs..pill", [Theme.radiusXs, Theme.radiusSm, Theme.radiusMd,
                                    Theme.radiusLg, Theme.radiusXl, Theme.radiusPill].join(" "))
            row("borderWidth", Theme.borderWidth)
            row("space 1..6", [Theme.space1, Theme.space2, Theme.space3,
                               Theme.space4, Theme.space5, Theme.space6].join(" "))
            say("")
            say("TYPOGRAPHY / MOTION")
            row("fontUi", Theme.fontUi);                    row("fontMono", Theme.fontMono)
            row("fontIcon", Theme.fontIcon)
            row("sizes sm/base/lg/xl", [Theme.fontSizeSm, Theme.fontSize,
                                        Theme.fontSizeLg, Theme.fontSizeXl].join(" "))
            row("display size", Theme.fontSizeDisplay)
            row("weights", [Theme.weightNormal, Theme.weightMedium,
                            Theme.weightSemibold, Theme.weightBold].join(" "))
            row("durations", [Theme.durFast, Theme.durBase, Theme.durSlow].join(" "))
            row("effects/blur/shadow", [Theme.effects, Theme.blur, Theme.shadows].join(" "))
            say("")
            say("SANITY")
            // Two things that must never be true, checked here so a bad palette
            // fails a test instead of just looking slightly wrong.
            var bad = []
            // The palette must be the one that was asked for. Without this the
            // test cannot tell eleven palettes apart from one palette eleven
            // times — which is precisely what it failed to tell for all of M1.
            if (!Scheme.ready) bad.push("palette not loaded")
            // All 26 semantic names, not just the ones printed above. The
            // header of tests/all-palettes.sh promises that "a palette that is
            // missing a key has to fail here" — it did not, because a name
            // nothing happened to render was never looked at. The built-in
            // fallback is the schema: it is the one place every name exists.
            var missing = []
            for (var key in Scheme.fallback)
                if (!Scheme.colors[key]) missing.push(key)
            if (missing.length) bad.push("palette is missing " + missing.length +
                                         " colour(s): " + missing.join(", "))
            if (Scheme.name !== Config.theme.palette)
                bad.push("wrong palette: asked for " + Config.theme.palette +
                         ", got " + Scheme.name)
            if (Theme.hex(Theme.bg) === Theme.hex(Theme.fg)) bad.push("bg == fg")
            if (Math.abs(Theme.luminance(Theme.bg) - Theme.luminance(Theme.fg)) < 0.25)
                bad.push("bg/fg contrast too low")
            // Scheme's "colour not found" sentinel, compared against — not drawn.
            if (Theme.hex(Theme.accent) === "#ff00ff") bad.push("accent missing")  // literal-ok: sentinel comparison
            say(bad.length ? "  FAIL: " + bad.join(", ") : "  ok: contrast and accent resolve")
            Qt.callLater(Qt.quit)
        }
    }
}
