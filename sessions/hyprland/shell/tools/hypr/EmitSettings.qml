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
        out += "        },\n"

        out += "        shadow = {\n"
        out += Lua.field("            ", "enabled", Lua.bool(rich && L.shadows === true))
        out += Lua.field("            ", "range", Lua.num(L.shadowSoftness, 12))
        out += "        },\n"
        out += "    },\n"

        out += "    animations = {\n"
        out += Lua.field("        ", "enabled", Lua.bool(rich))
        out += "    },\n"

        out += "    input = {\n"
        out += inputBody()
        out += "    },\n"

        out += "})\n"

        out += monitors()
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
