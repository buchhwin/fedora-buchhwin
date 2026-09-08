// Press a key, get the name niri calls it.
//
// ⚠️ IT REFUSES WHAT IT DOES NOT KNOW, and that is the whole design. niri takes
// XKB key names, Qt hands out Qt key codes, and the two only line up through a
// table. A guess that gets through here becomes a line in config.kdl, and a
// config.kdl niri cannot parse means niri does not start — on the machine of
// somebody who was in the middle of changing a shortcut. So an unmapped key
// says so and changes nothing.
//
// ⚠️ MODIFIERS ALONE ARE NOT A BINDING. Holding Mod sends a key event for Mod
// itself, and capturing that would write `Mod+` — which is a parse error rather
// than a shortcut. They are ignored until a real key arrives, which is also what
// makes "hold Mod, then press T" work the way anybody expects.
import QtQuick
import QtQuick.Layouts
import "../common"
import "../../theme"

FocusScope {
    id: root

    // Set while waiting for a key. The caller turns this on and listens.
    property bool capturing: false

    // What went wrong with the last attempt, for the row to show.
    property string refusal: ""

    signal captured(string key)
    signal cancelled

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    // The names below are XKB keysyms. Letters and digits are their own name,
    // which is why they are computed rather than listed.
    //
    // ⚠️ The project's own defaults already mix cases — `Space` and `Slash` next
    // to `comma` and `odiaeresis` — and both spellings validate, because
    // xkbcommon falls back to a case-insensitive lookup. Canonical XKB is what
    // is emitted here: lower case for punctuation, capitalised for named keys.
    readonly property var named: ({
        [Qt.Key_Return]:    "Return",
        [Qt.Key_Enter]:     "KP_Enter",
        [Qt.Key_Escape]:    "Escape",
        [Qt.Key_Tab]:       "Tab",
        [Qt.Key_Space]:     "space",
        [Qt.Key_Backspace]: "BackSpace",
        [Qt.Key_Delete]:    "Delete",
        [Qt.Key_Insert]:    "Insert",
        [Qt.Key_Home]:      "Home",
        [Qt.Key_End]:       "End",
        [Qt.Key_PageUp]:    "Page_Up",
        [Qt.Key_PageDown]:  "Page_Down",
        [Qt.Key_Left]:      "Left",
        [Qt.Key_Right]:     "Right",
        [Qt.Key_Up]:        "Up",
        [Qt.Key_Down]:      "Down",
        [Qt.Key_Print]:     "Print",
        [Qt.Key_Menu]:      "Menu",
        [Qt.Key_Comma]:     "comma",
        [Qt.Key_Period]:    "period",
        [Qt.Key_Slash]:     "slash",
        [Qt.Key_Backslash]: "backslash",
        [Qt.Key_Minus]:     "minus",
        [Qt.Key_Equal]:     "equal",
        [Qt.Key_Semicolon]: "semicolon",
        [Qt.Key_Apostrophe]: "apostrophe",
        [Qt.Key_BracketLeft]:  "bracketleft",
        [Qt.Key_BracketRight]: "bracketright",
        [Qt.Key_QuoteLeft]:    "grave",
        // The media keys, so the volume and brightness bindings can be moved
        // like any other. These are the names niri already has in the defaults.
        [Qt.Key_VolumeUp]:     "XF86AudioRaiseVolume",
        [Qt.Key_VolumeDown]:   "XF86AudioLowerVolume",
        [Qt.Key_VolumeMute]:   "XF86AudioMute",
        [Qt.Key_MicMute]:      "XF86AudioMicMute",
        [Qt.Key_MonBrightnessUp]:   "XF86MonBrightnessUp",
        [Qt.Key_MonBrightnessDown]: "XF86MonBrightnessDown",
        [Qt.Key_Calculator]:   "XF86Calculator"
    })

    // ⚠️ Mod, Ctrl, Alt, Shift, in that order and always that order. niri does
    // not care, but the defaults are written this way and a list where half the
    // rows say `Mod+Shift+C` and half say `Shift+Mod+C` cannot be read down.
    function nameFor(event) {
        var base = ""
        if (event.key >= Qt.Key_A && event.key <= Qt.Key_Z)
            base = String.fromCharCode("A".charCodeAt(0) + (event.key - Qt.Key_A))
        else if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9)
            base = String.fromCharCode("0".charCodeAt(0) + (event.key - Qt.Key_0))
        else if (event.key >= Qt.Key_F1 && event.key <= Qt.Key_F12)
            base = "F" + (1 + event.key - Qt.Key_F1)
        else
            base = root.named[event.key] || ""

        if (base === "")
            return ""

        var mods = []
        if (event.modifiers & Qt.MetaModifier)    mods.push("Mod")
        if (event.modifiers & Qt.ControlModifier) mods.push("Ctrl")
        if (event.modifiers & Qt.AltModifier)     mods.push("Alt")
        if (event.modifiers & Qt.ShiftModifier)   mods.push("Shift")
        mods.push(base)
        return mods.join("+")
    }

    function isModifierOnly(key) {
        return key === Qt.Key_Shift || key === Qt.Key_Control
            || key === Qt.Key_Alt || key === Qt.Key_Meta
            || key === Qt.Key_AltGr || key === Qt.Key_CapsLock
            || key === Qt.Key_Super_L || key === Qt.Key_Super_R
    }

    focus: root.capturing
    Keys.onPressed: function (event) {
        if (!root.capturing)
            return
        event.accepted = true

        // Escape on its own leaves without changing anything. It is the one key
        // that cannot be captured, and losing it would mean a row you can only
        // get out of by binding something.
        if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) {
            root.refusal = ""
            root.cancelled()
            return
        }

        if (root.isModifierOnly(event.key))
            return                          // still waiting for the real key

        var name = root.nameFor(event)
        if (name === "") {
            // ⚠️ Named rather than silently dropped. A capture box that ignores
            // a key looks broken; one that says it does not know the key is
            // merely limited, and the difference is whether anybody reports it.
            root.refusal = "That key has no name here yet — pick another one."
            return
        }
        root.refusal = ""
        root.captured(name)
    }

    BarText {
        id: label
        anchors.centerIn: parent
        text: root.capturing ? "Press a key…  (Esc to cancel)" : ""
        font.pixelSize: Theme.fontSizeSm
        color: Theme.accent
    }
}
