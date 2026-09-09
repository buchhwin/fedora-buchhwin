pragma Singleton

// generated/binds.lua — every keybinding, with the user's rebinds resolved.
//
// ⚠️ THIS FILE IS WHY REBINDING WORKS AT ALL. Before it existed the settings
// window wrote a rebind into shell.json, called `hyprctl reload`, and reloaded a
// config that contained none of the bindings. The row moved on screen and
// nothing else happened — the worst kind of broken, because it looked fine.
//
// The output REPLACES buchhwin/binds.lua rather than adding to it. hyprland.lua
// loads one or the other, never both, because two binds on one key leave the
// person pressing it guessing which one ran.
//
// The action names in config/Binds.qml are this file's vocabulary, not
// Hyprland's. That indirection earns its keep: `hl.dsp.window.fullscreen` moving
// or being renamed upstream is one edit here instead of sixty in the table.

import QtQuick
import "../../config"

QtObject {
    id: root

    // action name -> a function turning its argument into Lua source.
    //
    // Anything not in here is dropped with a warning rather than written out
    // and left for Hyprland to refuse: one unknown action must not cost the
    // whole config, because a config Hyprland rejects is a desktop with no keys.
    readonly property var actions: ({
        "spawn":              function (a) { return "hl.dsp.exec_cmd(" + Lua.str(a) + ")" },
        "spawn-sh":           function (a) { return "hl.dsp.exec_cmd(" + Lua.str(a) + ")" },

        "close-window":       function ()  { return "hl.dsp.window.close()" },
        "focus-next":         function ()  { return "hl.dsp.window.cycle_next({ next = true })" },
        "focus-previous":     function ()  { return "hl.dsp.window.cycle_next({ next = false })" },
        "toggle-floating":    function ()  { return "hl.dsp.window.float({ action = \"toggle\" })" },
        "toggle-fullscreen":  function ()  { return "hl.dsp.window.fullscreen({ action = \"toggle\" })" },
        // ⚠️ "maximized", NOT "maximize". Hyprland accepts fullscreen/maximized
        // and refuses the whole config otherwise — which it did, once.
        "maximize":           function ()  { return "hl.dsp.window.fullscreen({ mode = \"maximized\" })" },
        "toggle-pin":         function ()  { return "hl.dsp.window.pin({ action = \"toggle\" })" },
        "drag-window":        function ()  { return "hl.dsp.window.drag()" },
        "resize-window":      function ()  { return "hl.dsp.window.resize()" },

        "focus-direction":    function (a) { return "hl.dsp.focus({ direction = " + Lua.str(a) + " })" },
        "focus-monitor":      function (a) { return "hl.dsp.focus({ monitor = " + Lua.str(a) + " })" },
        "move-to-monitor":    function (a) { return "hl.dsp.window.move({ monitor = " + Lua.str(a) + " })" },
        "focus-workspace":    function (a) { return "hl.dsp.focus({ workspace = " + Lua.num(a, 1) + " })" },
        "move-to-workspace":  function (a) { return "hl.dsp.window.move({ workspace = " + Lua.num(a, 1) + " })" },
        "previous-workspace": function ()  { return "hl.dsp.focus({ workspace = \"previous\" })" },

        "layout":             function (a) { return "hl.dsp.layout(" + Lua.str(a) + ")" },
        "mfact":              function (a) { return "hl.dsp.layout(" + Lua.str("mfact " + a) + ")" },

        "exit":               function ()  { return "hl.dsp.exit()" },

        // The two that are Lua FUNCTIONS rather than dispatchers, because one
        // key has to do two things. They are emitted as named locals at the top
        // of the file so the binding line stays one line.
        "horizontal-mfact":   function (a) { return "horizontalMfact(" + Lua.str(a) + ")" },
        "float-workspace":    function ()  { return "toggleWorkspaceFloating" }
    })

    // The helpers the two function-actions above refer to. Emitted only when
    // something actually uses them, so a config with neither stays clean.
    readonly property string preamble:
'-- dwl\'s sethorizontalmfact: switch to the bottom stack AND move the divider,\n' +
'-- in one key. A dispatcher does one thing, so this is a plain function —\n' +
'-- hl.bind accepts one, which is what makes the dwl bindings reproducible.\n' +
'local function horizontalMfact(delta)\n' +
'    return function()\n' +
'        hl.dispatch(hl.dsp.layout("orientationtop"))\n' +
'        hl.dispatch(hl.dsp.layout("mfact " .. delta))\n' +
'    end\n' +
'end\n' +
'\n' +
'-- dwl\'s floating LAYOUT: every window on the workspace at once. Hyprland has\n' +
'-- no such layout, but it has a query API, so the effect is reproducible. Only\n' +
'-- "toggle" is used, and only on the windows in the wrong state, which makes\n' +
'-- pressing the key twice a no-op rather than a shuffle.\n' +
'local function toggleWorkspaceFloating()\n' +
'    local workspace = hl.get_active_workspace()\n' +
'    if workspace == nil then return end\n' +
'    local windows = hl.get_workspace_windows(workspace)\n' +
'    if windows == nil or #windows == 0 then return end\n' +
'\n' +
'    local anyTiled = false\n' +
'    for _, window in ipairs(windows) do\n' +
'        if not window.floating then\n' +
'            anyTiled = true\n' +
'            break\n' +
'        end\n' +
'    end\n' +
'\n' +
'    for _, window in ipairs(windows) do\n' +
'        if window.floating ~= anyTiled then\n' +
'            hl.dispatch(hl.dsp.window.float({ action = "toggle", window = window }))\n' +
'        end\n' +
'    end\n' +
'end\n'

    // Options table for one binding, or "" when every option is at its default.
    function options(b) {
        var parts = []
        if (b.repeat === true) parts.push("repeating = true")
        if (b.locked === true) parts.push("locked = true")
        if (b.mouse === true) parts.push("mouse = true")
        if (b.desc) parts.push("description = " + Lua.str(b.desc))
        return parts.length ? ", { " + parts.join(", ") + " }" : ""
    }

    // Resolve "@terminal" to the configured program. A binding whose program is
    // not configured is DROPPED rather than bound to an empty command: a key
    // that visibly does nothing is easier to report than one that silently does.
    function resolveSpawn(arg) {
        var text = String(arg === undefined || arg === null ? "" : arg)
        if (text.charAt(0) !== "@")
            return text

        var parts = text.split(/\s+/).filter(function (x) { return x.length })
        var argv = Config.program(parts[0])
        if (!argv.length)
            return ""
        for (var i = 1; i < parts.length; i++)
            argv.push(parts[i])
        return argv.join(" ")
    }

    property var warnings: []

    // The modifier the whole table hangs off.
    //
    // ⚠️ THIS SETTING HAD NO READER AND THEREFORE NO EFFECT. `keys.mod` has a
    // row in the settings window and sat in the theming fingerprint, so
    // changing it from Super to Alt rewrote thirteen colour files and left
    // every binding on Super. config/Binds.qml spells SUPER because a table has
    // to say something; this is where it becomes what was actually chosen.
    //
    // ⚠️ WORD-BOUNDARY, NOT A SUBSTRING. A plain replace would also rewrite the
    // letters inside a key NAME. There is no such key today, but the failure
    // would be a binding that silently never fires, which is the hardest kind
    // to notice.
    function withMod(key) {
        var mod = String(Config.keys.mod || "SUPER").toUpperCase()
        if (mod === "SUPER")
            return String(key)
        return String(key).replace(/SUPER/g, mod)
    }

    function line(b) {
        var action = String(b.action)
        var make = root.actions[action]
        if (make === undefined) {
            root.warnings.push("unknown action, binding dropped: " + action + " (" + b.key + ")")
            return ""
        }

        var arg = b.arg
        if (action === "spawn" || action === "spawn-sh") {
            arg = resolveSpawn(arg)
            if (!String(arg).length) {
                root.warnings.push("no program configured, binding dropped: " + b.key)
                return ""
            }
        }

        return "hl.bind(" + Lua.str(root.withMod(b.key)) + ", " + make(arg) + root.options(b) + ")\n"
    }

    function build() {
        root.warnings = []

        var binds = Config.binds
        var body = ""
        var seen = ({})
        var dropped = 0
        var usesHelpers = false

        for (var i = 0; i < binds.length; i++) {
            var b = binds[i]
            if (!b || !b.key)
                continue

            // ⚠️ FIRST WINS, AND THE SECOND IS REPORTED. Hyprland does not
            // refuse a duplicate the way the compositor's parser did — it quietly keeps
            // one of them, which is how a rebind onto an occupied key looks like
            // "the new binding does not work" with nothing in any log.
            var key = root.withMod(b.key)
            if (seen[key]) {
                root.warnings.push("duplicate key, later binding dropped: " + key)
                dropped++
                continue
            }

            var text = root.line(b)
            if (!text.length) {
                dropped++
                continue
            }

            if (b.action === "horizontal-mfact" || b.action === "float-workspace")
                usesHelpers = true

            seen[key] = true
            body += text
        }

        // Workspaces 1-9, generated rather than typed out eighteen times.
        //
        // ⚠️ THE DEDUPE APPLIES HERE TOO. In the compositor generator this loop
        // appended without consulting `seen`, so rebinding anything onto Mod+3
        // produced a duplicate that its own duplicate check could not see.
        var generated = ""
        for (var n = 1; n <= 9; n++) {
            var focusKey = root.withMod("SUPER + " + n)
            var moveKey = root.withMod("SUPER + SHIFT + " + n)
            if (!seen[focusKey]) {
                seen[focusKey] = true
                generated += "hl.bind(" + Lua.str(focusKey)
                          + ", hl.dsp.focus({ workspace = " + n + " })"
                          + ", { description = " + Lua.str("Workspace " + n) + " })\n"
            }
            if (!seen[moveKey]) {
                seen[moveKey] = true
                generated += "hl.bind(" + Lua.str(moveKey)
                          + ", hl.dsp.window.move({ workspace = " + n + " })"
                          + ", { description = " + Lua.str("Move to workspace " + n) + " })\n"
            }
        }

        var out = Lua.header("Keybindings")
        if (usesHelpers)
            out += root.preamble + "\n"
        out += body

        // ⚠️ WRITTEN OUT FLAT, NOT AS A LUA `for` LOOP. A rebind can take one of
        // these eighteen keys for something else, and the other seventeen still
        // have to be emitted — which a loop cannot express without carrying the
        // exception list into the generated file.
        if (generated.length) {
            out += "\n-- Workspaces 1-9. No shifted-keysym table is needed the way dwl needed\n"
            out += "-- one: Hyprland resolves against the live XKB map, so this is right on\n"
            out += "-- a German layout and on a US one.\n"
            out += generated
        }

        if (dropped)
            root.warnings.push(dropped + " binding(s) skipped")
        return out
    }
}
