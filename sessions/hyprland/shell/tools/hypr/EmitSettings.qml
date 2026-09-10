pragma Singleton

// generated/settings.lua — the compositor half of shell.json.
//
// Only settings Hyprland itself acts on are written here. Anything the shell
// draws with (panel radii, surface opacity, fonts) stays in the shell and never
// reaches the compositor, because a value in two places is a value that can
// disagree with itself.
//
// This file loads AFTER buchhwin/look.lua and buchhwin/input.lua, so every
// value below overrides the shipped default. That is why it can be sparse: the
// defaults are already correct, and this only restates what somebody changed.

import QtQuick
import "../../config"

QtObject {
    // dwl's border colours, which are what the shipped defaults use too. The
    // palette-driven ones arrive separately in generated/colors.lua, written by
    // the renderer — a keybinding change must not rewrite colours and a palette
    // change must not rewrite keys.

    function build() {
        var L = Config.look
        var out = Lua.header("Compositor settings")

        out += "hl.config({\n"

        out += "    general = {\n"
        out += Lua.field("        ", "gaps_in", Lua.num(L.gapsIn, 6))
        out += Lua.field("        ", "gaps_out", Lua.num(L.gapsOut, 12))
        out += Lua.field("        ", "border_size", Lua.num(L.borderWidth, 2))
        out += "    },\n"

        out += "    decoration = {\n"
        out += Lua.field("        ", "rounding", Lua.num(L.rounding, 12))
        out += Lua.field("        ", "active_opacity", Lua.num(L.opacityActive, 1.0))
        out += Lua.field("        ", "inactive_opacity", Lua.num(L.opacityInactive, 1.0))

        // ⚠️ "minimal" TURNS BOTH OFF, and it has to reach the compositor as
        // well as the shell. A profile that only quietened the shell's own
        // animations left Hyprland still blurring every layer behind them,
        // which is the expensive half on a laptop.
        var rich = String(L.profile) !== "minimal"

        out += "        blur = {\n"
        out += Lua.field("            ", "enabled", Lua.bool(rich && L.blur === true))
        out += Lua.field("            ", "passes", Lua.num(L.blurPasses, 2))
        // The shell calls it an offset; Hyprland calls the same thing size.
        out += Lua.field("            ", "size", Lua.num(L.blurOffset, 6))
        out += Lua.field("            ", "noise", Lua.num(L.blurNoise, 0.03))
        // Hyprland's name for what the shell calls saturation.
        out += Lua.field("            ", "vibrancy", Lua.num(L.blurSaturation, 1.2))
        out += "        },\n"

        out += "        shadow = {\n"
        out += Lua.field("            ", "enabled", Lua.bool(rich && L.shadows === true))
        out += Lua.field("            ", "range", Lua.num(L.shadowSoftness, 12))
        // ⚠️ `offset` IS A PAIR, and the shell only has a vertical one. Writing
        // a single number produces a config Hyprland refuses, which is the kind
        // of thing --verify-config catches and a reader does not.
        out += Lua.field("            ", "offset", Lua.str("0 " + Lua.num(L.shadowOffsetY, 8)))
        out += Lua.field("            ", "scale", Lua.num(L.shadowSpread, 1))
        out += "        },\n"
        out += "    },\n"

        // ⚠️ THE POINTER FOLLOWING FOCUS IS AN INVERSE, and getting the polarity
        // wrong is silent. The shell asks "warp the mouse to the focused
        // window"; Hyprland asks the opposite question, `no_warps`. A direct
        // copy would turn the setting upside down and look like it works.
        out += "    cursor = {\n"
        out += Lua.field("        ", "no_warps", Lua.bool(Config.input.warpMouseToFocus !== true))
        out += "    },\n"

        out += "    animations = {\n"
        out += Lua.field("        ", "enabled", Lua.bool(rich))
        out += "    },\n"

        out += "    input = {\n"
        out += inputBody()
        out += "    },\n"

        out += "})\n"

        out += environment()
        out += windowRules()
        out += workspaces()
        out += monitors()
        out += autostart()
        return out
    }

    // Environment variables that depend on a setting.
    //
    // ⚠️ TWO THINGS LIVE HERE BECAUSE HYPRLAND HAS NO CONFIG KEY FOR EITHER, and
    // both were written as something else first and rejected by --verify-config:
    //
    //   gpu.renderDevice   there is no `render_device` setting. Which card
    //                      Aquamarine opens is decided by AQ_DRM_DEVICES before
    //                      the compositor starts.
    //   windows.noCsd      `no_border` is not a window-rule field and
    //                      `general.no_border_on_floating` is not a config key.
    //                      What actually stops Qt drawing its own title bars is
    //                      a variable.
    //
    // An empty render device writes nothing at all rather than an empty
    // variable, which would tell Aquamarine to open no card.
    function environment() {
        var out = "\n"

        if (Config.windows.noCsd === true)
            out += "hl.env(\"QT_WAYLAND_DISABLE_WINDOWDECORATION\", \"1\")\n"

        // ⚠️⚠️ THE POINTER, WHICH REACHED THE COMPOSITOR THROUGH NOTHING AT ALL.
        // `cursor.theme` and `cursor.size` have a row in the settings window, a
        // place in the theming fingerprint and a writer in tools/render.qml that
        // sets the GTK side over gsettings — and no reader anywhere on this
        // side. config/hypr/buchhwin/env.lua carried breeze_cursors and 24 as
        // literals, so changing the size moved GTK's pointer and left the
        // compositor's where it was: two pointers on one desktop, changing shape
        // at a window edge, which is exactly what docs/CONFIG.md warns about
        // while promising that both writers exist.
        //
        // ⚠️ ONE WRITER, NOT TWO, AND THAT IS WHY env.lua NO LONGER SETS IT.
        // Emitting here while the shipped module also set the variable would
        // depend on which of two hl.env calls wins — something this machine
        // cannot measure and nothing should rest on. hyprland.lua carries the
        // fallback in the branch it already has for a missing generated file, so
        // exactly one of the two runs, always.
        //
        // ⚠️ IT TAKES EFFECT AT THE NEXT LOGIN, and saying so is part of the
        // fix. These are environment variables: they are handed to processes the
        // compositor starts AFTER them, so `hyprctl reload` re-reads the file
        // and changes nothing already running.
        var ctheme = String(Config.cursor.theme || "breeze_cursors")
        var csize = Math.max(1, Math.round(Number(Config.cursor.size) || 24))
        out += "hl.env(\"XCURSOR_THEME\", " + Lua.str(ctheme) + ")\n"
        out += "hl.env(\"XCURSOR_SIZE\", " + Lua.str(String(csize)) + ")\n"
        out += "hl.env(\"HYPRCURSOR_SIZE\", " + Lua.str(String(csize)) + ")\n"

        var device = String(Config.gpu.renderDevice || "")
        if (!device.length)
            return out + "-- No GPU override: Hyprland picks the card, which on a\n"
                       + "-- hybrid laptop is the integrated one and is what you want.\n"
        return out + "hl.env(\"AQ_DRM_DEVICES\", " + Lua.str(device) + ")\n"
    }

    // Window rules from the lists the settings window writes.
    //
    // ⚠️ THESE HAD NO GENERATOR AND THEREFORE NO EFFECT. All of them were in the
    // theming fingerprint — so editing one spawned a full render over every
    // generated file — while nothing turned them into a rule. Adding an app to
    // "always floating" moved a row, wrote shell.json, rebuilt thirteen colour
    // files and changed nothing about any window.
    function windowRules() {
        var W = Config.windows
        var out = ""

        function rules(list, name, body) {
            if (!list || !list.length)
                return ""
            var s = ""
            for (var i = 0; i < list.length; i++) {
                var app = String(list[i])
                if (!app.length)
                    continue
                s += "hl.window_rule({\n"
                s += Lua.field("    ", "name", Lua.str(name + "-" + app))
                // Anchored, so "kitty" does not also match "kitty-something".
                s += Lua.field("    ", "match", "{ class = " + Lua.str("^" + app + "$") + " }")
                s += body
                s += "})\n"
            }
            return s
        }

        out += rules(W.floating, "float", Lua.field("    ", "float", "true"))
        out += rules(W.blockFromScreencast, "no-screenshare",
                     Lua.field("    ", "no_screen_share", "true"))

        // ⚠️ BLUR IS INVERTED HERE, AND IT HAS TO BE.
        // The shell's list names the windows that SHOULD be blurred. Hyprland
        // has no per-window "blur this": blur is on for everything when
        // decoration.blur.enabled is set, and the only per-window field is
        // `no_blur`. Asked of the compositor with --verify-config rather than
        // guessed — a `blur` field on a window rule is rejected outright.
        //
        // So the list becomes: switch it off everywhere, then back on for the
        // named ones. A later rule wins, which is what makes the exception work.
        if (W.blurred && W.blurred.length) {
            out += "hl.window_rule({\n"
            out += Lua.field("    ", "name", Lua.str("blur-none-by-default"))
            out += Lua.field("    ", "match", "{ class = \".*\" }")
            out += Lua.field("    ", "no_blur", "true")
            out += "})\n"
            out += rules(W.blurred, "blur", Lua.field("    ", "no_blur", "false"))
        }

        if (!out.length)
            return "\n-- No window rules configured.\n"
        return "\n" + out
    }

    // What the compositor starts.
    //
    // ⚠️ INSIDE hl.on("hyprland.start"), like buchhwin/autostart.lua. At the top
    // level these would run while the config is being PARSED — before there is
    // a Wayland socket for them to connect to.
    function autostart() {
        var list = Config.autostart
        if (!list || !list.length)
            return "\n-- Nothing extra to start: the shell and the clipboard\n"
                 + "-- watchers are systemd user units, not spawned from here.\n"

        var out = "\nhl.on(\"hyprland.start\", function()\n"
        for (var i = 0; i < list.length; i++) {
            var cmd = String(list[i])
            if (!cmd.length)
                continue
            out += "    hl.exec_cmd(" + Lua.str(cmd) + ")\n"
        }
        out += "end)\n"
        return out
    }

    // Named workspaces.
    //
    // ⚠️ THIS KEY HAD NO READER AND tests/fingerprint.sh SAID SO. `workspaces`
    // was in the theming fingerprint — so changing it spawned a full render
    // over every generated file — while nothing generated anything from it. The
    // previous generator emitted a block for it and the replacement did not.
    //
    // A named workspace has to be `persistent`, or it exists only while
    // something is on it: the keybinding that focuses "scratch" would create it
    // on first use and lose it again the moment the last window closed, which
    // is not what a scratch workspace is for.
    function workspaces() {
        var names = Config.workspaces
        if (!names || !names.length)
            return "\n-- No named workspaces: the numbered ones are enough.\n"

        var out = "\n"
        for (var i = 0; i < names.length; i++) {
            var name = String(names[i])
            if (!name.length)
                continue
            out += "hl.workspace_rule({\n"
            // "name:" is the selector form for a workspace identified by name
            // rather than by number — without it the rule would apply to a
            // numbered workspace that happens to parse from the string.
            out += Lua.field("    ", "workspace", Lua.str("name:" + name))
            out += Lua.field("    ", "persistent", "true")
            out += "})\n"
        }
        return out
    }

    function inputBody() {
        var I = Config.input
        var k = I.keyboard
        var t = I.touchpad
        var m = I.mouse
        var out = ""

        out += Lua.field("        ", "kb_layout", Lua.str(k.layout))
        out += Lua.field("        ", "kb_variant", Lua.str(k.variant))
        out += Lua.field("        ", "kb_options", Lua.str(k.options))
        out += Lua.field("        ", "repeat_delay", Lua.num(k.repeatDelay, 400))
        out += Lua.field("        ", "repeat_rate", Lua.num(k.repeatRate, 40))
        out += Lua.field("        ", "follow_mouse", I.focusFollowsMouse === false ? "0" : "1")

        // ⚠️ THE MOUSE SETTINGS ARE THE TOP-LEVEL ONES. Hyprland has no
        // `input.mouse` block: a pointer is configured by input.sensitivity and
        // input.accel_profile, and only the touchpad gets its own table. Writing
        // input.mouse.* produces no error and no effect, which is worse.
        out += Lua.field("        ", "sensitivity", Lua.num(m.accelSpeed, 0))
        out += Lua.field("        ", "accel_profile", Lua.str(m.accelProfile))
        out += Lua.field("        ", "natural_scroll", Lua.bool(m.naturalScroll === true))
        out += Lua.field("        ", "scroll_factor", Lua.num(m.scrollFactor, 1.0))

        out += "        touchpad = {\n"
        out += Lua.field("            ", "tap_to_click", Lua.bool(t.tap === true))
        out += Lua.field("            ", "disable_while_typing", Lua.bool(t.dwt === true))
        out += Lua.field("            ", "natural_scroll", Lua.bool(t.naturalScroll === true))
        out += Lua.field("            ", "middle_button_emulation", Lua.bool(t.middleEmulation === true))
        out += Lua.field("            ", "clickfinger_behavior", Lua.bool(String(t.clickMethod) === "clickfinger"))
        out += Lua.field("            ", "scroll_factor", Lua.num(t.scrollFactor, 1.0))
        out += "        },\n"

        return out
    }

    // hl.monitor() per screen the user has actually arranged.
    //
    // ⚠️ AN ENTRY EXISTING IS THE MARK FOR "SET BY HAND" — the same rule
    // config/Outputs.qml states. No entry means Hyprland's own detection
    // decides, and its detection is better than any guess this could make. So
    // an empty list emits a comment and nothing else.
    function monitors() {
        var outs = Config.outputs
        if (!outs || !outs.length)
            return "\n-- No monitor overrides: Hyprland's own detection decides, which is\n"
                 + "-- better than a guess, and a screen layout is per-machine anyway.\n"

        var out = "\n"
        for (var i = 0; i < outs.length; i++) {
            var o = outs[i]
            if (!o || !o.name)
                continue

            out += "hl.monitor({\n"
            out += Lua.field("    ", "output", Lua.str(o.name))

            if (o.off === true) {
                // A disabled screen takes nothing else: Hyprland rejects a
                // mode on a monitor it has been told not to use.
                out += Lua.field("    ", "disabled", "true")
                out += "})\n"
                continue
            }

            out += Lua.field("    ", "mode", Lua.str(o.mode !== undefined && String(o.mode).length
                                                     ? o.mode : "preferred"))
            out += Lua.field("    ", "position",
                             (o.x !== undefined && o.y !== undefined)
                             ? Lua.str(String(Math.round(Number(o.x) || 0)) + "x"
                                       + String(Math.round(Number(o.y) || 0)))
                             : Lua.str("auto"))
            out += Lua.field("    ", "scale", o.scale !== undefined && o.scale !== null
                                              ? Lua.num(o.scale, 1) : Lua.str("auto"))
            if (o.transform !== undefined && o.transform !== null)
                out += Lua.field("    ", "transform", Lua.num(o.transform, 0))
            if (o.vrr === true)
                out += Lua.field("    ", "vrr", "1")
            out += "})\n"
        }
        return out
    }
}
