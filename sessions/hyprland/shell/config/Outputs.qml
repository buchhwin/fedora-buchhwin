pragma Singleton

// Writing to `outputs`, and nothing else.
//
// `outputs` is the one setting in this shell that is a LIST OF OBJECTS rather
// than a value at a dotted path, so `Config.set("dock.enabled", …)` has no
// equivalent for "the scale of DP-2". Four controls on the displays page all
// need to reach into the same list, and four copies of the same loop is exactly
// the drift rule 6 forbids — a list must not exist twice.
//
// ⚠️⚠️ THE LIST IS REBUILT, NEVER EDITED IN PLACE. JsonAdapter hands back a
// WRAPPER, and mutating that wrapper is the shape this project has watched
// segfault — `_write` in the old OutputScales.qml carries the same warning, and
// it is repeated here rather than referenced because the next person to add a
// setter will read this file and not that one.
//
// ⚠️ AN ENTRY EXISTING IS THE MARK FOR "SET BY HAND". No entry means Hyprland
// decides. That is one state instead of a value plus a flag that can disagree
// with it, and it is why `clearField` removes an entry that has nothing left in
// it: an entry carrying only a name is a claim with no content, and it would
// make the page say "you chose this" about a screen nobody touched.

import QtQuick
// ⚠️ `Singleton` COMES FROM Quickshell, and leaving this out does not fail
// quietly: the type is unresolvable, qmldir cannot register it, and every OTHER
// singleton in this directory becomes unavailable with it. The shell then
// starts with no Config at all and a headless tool reports "no such tool",
// which reads as a missing file rather than a missing import.
import Quickshell
import "." as Cfg

Singleton {
    id: root

    // The entry for a connector, or null. Callers read through this rather than
    // indexing, because the list is unordered and its length changes.
    function entry(name) {
        var outs = Cfg.Config.outputs
        if (!outs)
            return null
        for (var i = 0; i < outs.length; i++)
            if (String(outs[i].name) === String(name))
                return outs[i]
        return null
    }

    function field(name, key) {
        var e = root.entry(name)
        if (!e || e[key] === undefined || e[key] === null)
            return undefined
        return e[key]
    }

    function has(name, key) { return root.field(name, key) !== undefined }

    // A plain copy. `for (var k in wrapper)` is the only way to get an ordinary
    // object out of the adapter's wrapper, and everything below works on copies
    // for the reason at the top of this file.
    function _copy(o) {
        var c = {}
        for (var k in o)
            c[k] = o[k]
        return c
    }

    // Rebuild the whole list, applying `edit` to the entry named `name`. If no
    // entry exists and `create` is true, one is appended.
    //
    // ⚠️ AN ENTRY THAT ENDS UP WITH NOTHING BUT A NAME IS DROPPED, and only
    // then. Dropping the whole object whenever one field is cleared would take
    // a mode or a position with it — a setting the same page also writes,
    // silently deleted by a control that says "scale".
    function _rewrite(name, create, edit) {
        var out = []
        var found = false
        var src = Cfg.Config.outputs || []
        for (var i = 0; i < src.length; i++) {
            var o = root._copy(src[i])
            if (String(o.name) === String(name)) {
                found = true
                edit(o)
                var keys = Object.keys(o)
                if (keys.length <= 1 && keys[0] === "name")
                    continue
            }
            out.push(o)
        }
        if (!found && create) {
            var fresh = { name: String(name) }
            edit(fresh)
            if (Object.keys(fresh).length > 1)
                out.push(fresh)
        }
        Cfg.Config.set("outputs", out)
        return out
    }

    // Set one field. `flush` is for the end of a gesture — a drag writes on
    // release, not per frame, and Config.set is debounced for the frames in
    // between.
    function setField(name, key, value, flush) {
        root._rewrite(name, true, function (o) { o[key] = value })
        if (flush !== false)
            Cfg.Config.flush()
    }

    function clearField(name, key, flush) {
        root._rewrite(name, false, function (o) { delete o[key] })
        if (flush !== false)
            Cfg.Config.flush()
    }

    // ⚠️ THE ONLY SETTER THAT TOUCHES EVERY ENTRY, and it has to. `@primary` is
    // resolved in ui/Shell.qml by looking for the ONE entry carrying
    // `primary: true`; leaving an old mark behind means the placeholder
    // resolves against whichever comes first in the list, and the notch lands
    // on the wrong screen. There is no "unset primary" — some screen is always
    // the main one, and an empty answer falls back to the first screen anyway.
    function setPrimary(name) {
        var out = []
        var src = Cfg.Config.outputs || []
        var found = false
        for (var i = 0; i < src.length; i++) {
            var o = root._copy(src[i])
            if (String(o.name) === String(name)) {
                o.primary = true
                found = true
            } else {
                delete o.primary
                var keys = Object.keys(o)
                if (keys.length <= 1 && keys[0] === "name")
                    continue
            }
            out.push(o)
        }
        if (!found)
            out.push({ name: String(name), primary: true })
        Cfg.Config.set("outputs", out)
        Cfg.Config.flush()
    }

    // Which connector currently carries the mark, or "" when none does.
    // ui/Shell.qml falls back to the first screen in that case; the page says
    // so rather than showing every switch off.
    readonly property string primary: {
        var outs = Cfg.Config.outputs || []
        for (var i = 0; i < outs.length; i++)
            if (outs[i] && outs[i].primary === true && outs[i].name)
                return String(outs[i].name)
        return ""
    }
}
