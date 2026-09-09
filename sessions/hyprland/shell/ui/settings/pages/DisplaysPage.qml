pragma ComponentBehavior: Bound

// The monitors — his B3, "eine Monitor-Seite wie in Windows".                    // english-ok: the brief, quoted
//
// One card per screen: which one is the main one, resolution, refresh rate and
// scale, with a drag-to-arrange picture above them. He chose "alles auf einmal"  // english-ok: the brief, quoted
// when offered it in pieces.
//
// ⚠️ NONE OF THESE ARE SettingRows, AND THAT IS STRUCTURAL RATHER THAN LAZY.
// `outputs` is a list of objects, one per monitor, so no dotted path names "the
// refresh rate of DP-2" — see the note at the top of OutputRow.qml, and the
// exemption `outputs` already has in tests/setting-rows.sh. Every control here
// writes through config/Outputs.qml, which is the only place that knows how to
// edit that list.
//
// ⚠️ THE MODE LIST IS NOT INVENTED. It comes from `hyprctl -j monitors`, which
// is the only thing that knows what a monitor advertises. A resolution list
// assembled from the usual suspects would offer modes the screen does not have
// and hide the one it prefers.
//
// ⚠️ AND THE PAGE ASKS FOR IT. Compositor.outputs is empty until
// `refreshOutputs()` has been called: services/Hyprland.qml deliberately runs no
// query at startup, because this page is the only consumer and a process at
// every boot for a page opened twice a year is what rule 8 is about.
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../../common"
import "../../../config"
import "../../../services" as Services
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    // ⚠️ WHAT "RESET THIS PAGE" HAS TO REMOVE, declared here because nothing
    // else can know it. The reset gathers dotted paths from the SettingRows on
    // a page, and this page has none — so without this line the button would
    // report that it had reset a page on which it changed nothing at all. A
    // switch that lies is the fault this whole window is built against;
    // tests/reset-page.sh fails if this disappears.
    readonly property var resetKeys: ["outputs"]

    Component.onCompleted: {
        Services.Compositor.refreshOutputs()
        Services.Connectors.probe()
    }

    // The screens as the arrangement picture wants them: logical pixels, and a
    // position for every one — falling back to what the compositor has them at now when
    // nothing has been chosen.
    //
    // ⚠️ `logical` RATHER THAN THE MODE SIZE. A 3840x2160 screen at scale 2 is
    // logically 1920x1080, and the compositor counts positions in logical pixels. Using
    // the mode would be wrong by exactly the scale factor.
    // The arrangement control, so its geometry rules can be checked without a
    // pointer — see the note on its `id`.
    readonly property alias arrangement: arrangement

    readonly property var placed: {
        var out = []
        var o = Services.Compositor.outputs
        for (var name in o) {
            var s = o[name]
            var lg = s.logical
            if (!lg)
                continue
            var e = Outputs.entry(name)
            out.push({
                name: name,
                w: lg.width, h: lg.height,
                x: (e && e.x !== undefined && e.x !== null) ? Number(e.x) : lg.x,
                y: (e && e.y !== undefined && e.y !== null) ? Number(e.y) : lg.y
            })
        }
        return out
    }

    // Distinct resolutions, biggest first, each once. Measured on real hardware:
    // the same resolution appears several times with different refresh rates —
    // 3840x2160 at 60.000, 59.940 and 50.000 — so a list built straight from
    // `modes` would offer the same line three times.
    function _resolutions(name) {
        var o = Services.Compositor.outputs[name]
        var seen = {}
        var out = []
        if (!o || !o.modes)
            return out
        for (var i = 0; i < o.modes.length; i++) {
            var m = o.modes[i]
            var key = m.width + "x" + m.height
            if (seen[key])
                continue
            seen[key] = true
            out.push({ value: key, label: key + (m.is_preferred ? "  (preferred)" : ""),
                       px: m.width * m.height })
        }
        out.sort(function (a, b) { return b.px - a.px })
        return out
    }

    // The rates this screen offers AT that resolution, highest first.
    function _rates(name, res) {
        var o = Services.Compositor.outputs[name]
        var out = []
        if (!o || !o.modes)
            return out
        for (var i = 0; i < o.modes.length; i++) {
            var m = o.modes[i]
            if (m.width + "x" + m.height !== res)
                continue
            var hz = (m.refresh_rate / 1000).toFixed(3)
            out.push({ value: hz, label: hz + " Hz", n: m.refresh_rate })
        }
        out.sort(function (a, b) { return b.n - a.n })
        return out
    }

    // What the screen is doing now, as "1920x1080" — the fallback for both
    // dropdowns when nothing has been chosen, so they never show an empty box
    // next to a screen that is plainly working.
    function _currentRes(name) {
        var chosen = Outputs.field(name, "mode")
        if (chosen !== undefined)
            return String(chosen).split("@")[0]
        var o = Services.Compositor.outputs[name]
        if (!o || !o.modes || o.current_mode === undefined || o.current_mode === null)
            return ""
        var m = o.modes[o.current_mode]
        return m ? (m.width + "x" + m.height) : ""
    }

    function _currentRate(name) {
        var chosen = Outputs.field(name, "mode")
        if (chosen !== undefined) {
            var parts = String(chosen).split("@")
            if (parts.length > 1)
                return parts[1]
        }
        var o = Services.Compositor.outputs[name]
        if (!o || !o.modes || o.current_mode === undefined || o.current_mode === null)
            return ""
        var m = o.modes[o.current_mode]
        return m ? (m.refresh_rate / 1000).toFixed(3) : ""
    }

    // ⚠️ CHANGING THE RESOLUTION KEEPS THE RATE ONLY IF THAT RATE EXISTS THERE.
    // the compositor's wiki: with no rate given it "will pick the highest refresh rate for
    // the resolution" — so silently dropping the rate is a defined outcome, not
    // a failure. What is NOT acceptable is writing a rate the new resolution
    // does not have: the wiki says the value "must match exactly, down to the
    // three decimal digits", and a mode the compositor cannot parse means it picks one
    // itself and the page shows a choice that never took.
    // ⚠️⚠️ AND IT DROPS THE SCALE, ON HIS INSTRUCTION. "wenn man die auflösung    // english-ok: the request, quoted
    // von einem monitor ändert geht das aber er müsste dann automatisch mit      // english-ok: the request, quoted
    // skalieren z.b wenn man von 2k und 2 scaling auf 1920 umstellt soll das     // english-ok: the request, quoted
    // scaling nicht bei 2 bleiben sondern auf eins gehen".                       // english-ok: the request, quoted
    //
    // ⚠️ IT DELETES THE KEY RATHER THAN COMPUTING A NEW NUMBER, and that is the
    // whole design decision. the compositor's own wiki: "If scale is unset, the compositor will
    // guess an appropriate scale based on the physical dimensions and the
    // resolution." Writing our own heuristic would be a second automation
    // arguing with one that already exists and knows the physical size of the
    // panel, which we do not.
    //
    // It is also rule 6 in its plainest form: an entry EXISTS = you decided;
    // no entry = the compositor decides. One state, not a value plus a flag that can
    // contradict it.
    //
    // ⚠️ AND IT DOES NOT CONTRADICT THE OLDER RULE that a hand-set scale must
    // not be undone by an automation. Changing the resolution IS a new decision
    // — the old scale was chosen for a resolution that is no longer there. This
    // is not the automation overriding him; it is his own later choice
    // superseding his earlier one.
    function _setResolution(name, res) {
        var want = root._currentRate(name)
        var rates = root._rates(name, res)
        var keep = ""
        for (var i = 0; i < rates.length; i++)
            if (rates[i].value === want) { keep = want; break }
        // ⚠️ `false` on both, then one flush. Two writes that each flush would
        // serialise the whole of shell.json twice for one action.
        Outputs.setField(name, "mode", keep.length ? (res + "@" + keep) : res, false)
        Outputs.clearField(name, "scale", false)
        Config.flush()
    }

    function _setRate(name, hz) {
        var res = root._currentRes(name)
        if (!res.length)
            return
        Outputs.setField(name, "mode", res + "@" + hz)
    }

    // ------------------------------------------------------------ arrangement
    SettingGroup {
        Layout.fillWidth: true
        title: "Arrangement"

        OutputArrangement {
            // ⚠️ NAMED SO IT CAN BE CHECKED. B71 is arithmetic — "does this
            // layout leave a screen with no edge to cross" — and arithmetic is
            // the half of a drag that can be measured on a one-screen lab VM.
            // Without a handle on the control, displays-check.qml would have to
            // copy the functions to test them, and a copy of a rule is the one
            // thing that cannot catch the rule changing.
            id: arrangement
            Layout.fillWidth: true
            screens: root.placed
            onMoved: function (placements) {
                // Every screen is written, not only the dragged one — Hyprland
                // re-places all of them from scratch on any change, so a
                // half-positioned set moves screens nobody touched.
                for (var i = 0; i < placements.length; i++) {
                    Outputs.setField(placements[i].name, "x", placements[i].x, false)
                    Outputs.setField(placements[i].name, "y", placements[i].y, false)
                }
                Config.flush()
            }
        }

        BarText {
            Layout.fillWidth: true
            text: "Drag a screen to say where it is. They snap together: the compositor "
                + "ignores a position that overlaps another screen, so there is "
                + "no gap or overlap to get wrong."
            font.pixelSize: Theme.fontSizeSm
            color: Theme.fgMuted
            wrapMode: Text.WordWrap
        }
    }

    // ------------------------------------------------------------ one per screen
    Repeater {
        model: root.placed

        SettingGroup {
            id: card
            required property var modelData

            readonly property string name: String(card.modelData.name)
            readonly property var info: Services.Compositor.outputs[card.name] || ({})

            Layout.fillWidth: true
            // The connector name is what the compositor and `bhctl doctor` both call it,
            // and the model is what is written on the bezel. Both, because
            // matching "DP-2" to the screen on your left is guesswork otherwise.
            title: card.name + (card.info.model ? "  ·  " + card.info.model : "")

            OutputRow {
                Layout.fillWidth: true
                label: "Main screen"
                hint: "The notch sits here, and new windows open here first."
                kind: "switch"
                checked: Outputs.primary === card.name
                     || (Outputs.primary === "" && root.placed.length > 0
                         && String(root.placed[0].name) === card.name)
                // ⚠️ NO WAY TO SWITCH IT OFF, and that is deliberate: some screen
                // is always the main one. Turning this off would leave `@primary`
                // resolving against whichever entry happens to come first.
                usable: Outputs.primary !== card.name
                onChanged: function () { Outputs.setPrimary(card.name) }
            }

            OutputRow {
                Layout.fillWidth: true
                label: "Resolution"
                kind: "choice"
                choices: root._resolutions(card.name)
                current: root._currentRes(card.name)
                onChanged: function (v) { root._setResolution(card.name, String(v)) }
            }

            OutputRow {
                Layout.fillWidth: true
                label: "Refresh rate"
                hint: "What this screen offers at that resolution."
                kind: "choice"
                choices: root._rates(card.name, root._currentRes(card.name))
                current: root._currentRate(card.name)
                onChanged: function (v) { root._setRate(card.name, String(v)) }
            }

            // ⚠️ THE SCALE SWITCH AND ITS SLIDER, MOVED HERE FROM Size & Shape.
            // It was the only control on that page that was not a SettingRow,
            // and a scale belongs beside a resolution — which is where anybody
            // looks for it.
            //
            // ⚠️ AND THERE IS STILL NO AUTOMATIC MODE, which is the whole point.
            // The compositor already guesses: "If scale is unset, the compositor will guess an
            // appropriate scale based on the physical dimensions and the
            // resolution of the monitor". A heuristic of ours beside that would
            // be two automatic systems fighting, and the loser would be whichever
            // ran last. What he asked for — the automatic proposes, the slider
            // overrides, and once set by hand the automatic may not turn it back
            // — needs no code beyond a switch: the MARK for "set by hand" is the
            // entry existing.
            OutputRow {
                Layout.fillWidth: true
                label: "Set the scale myself"
                hint: "Off means the compositor chooses, from the screen's size and resolution."
                kind: "switch"
                checked: Outputs.has(card.name, "scale")
                onChanged: function (v) {
                    if (v)
                        // Start from what the compositor chose, so the first drag moves
                        // from where you already are rather than jumping.
                        Outputs.setField(card.name, "scale",
                                         Number((card.info.logical && card.info.logical.scale) || 1))
                    else
                        Outputs.clearField(card.name, "scale")
                }
            }

            OutputRow {
                Layout.fillWidth: true
                label: "Scale"
                kind: "slider"
                usable: Outputs.has(card.name, "scale")
                current: Outputs.has(card.name, "scale")
                       ? Number(Outputs.field(card.name, "scale")) : 1.0
                from: 0.5; to: 3.0; step: 0.05; decimals: 2; unit: "×"
                onChanged: function (v) {
                    // `settled` is the end of the gesture; everything before it
                    // goes through the debounced writer rather than rewriting
                    // shell.json once per frame.
                    Outputs.setField(card.name, "scale", v.value, v.settled === true)
                }
            }

            OutputRow {
                Layout.fillWidth: true
                advanced: true
                label: "Variable refresh rate"
                // ⚠️ THE HARDWARE ANSWERS THIS, not us. `vrr_supported` comes
                // from the compositor, and a switch offered on a screen that cannot do it
                // is a switch that does nothing — the exact class of fault his
                // B10 report is about.
                usable: card.info.vrr_supported === true
                hint: card.info.vrr_supported === true
                      ? "Also called FreeSync or G-Sync."
                      : "This screen does not support it."
                kind: "switch"
                checked: Outputs.field(card.name, "vrr") === true
                onChanged: function (v) {
                    if (v)
                        Outputs.setField(card.name, "vrr", true)
                    else
                        Outputs.clearField(card.name, "vrr")
                }
            }

            OutputRow {
                Layout.fillWidth: true
                advanced: true
                label: "Rotation"
                kind: "choice"
                // ⚠️ LOWERCASE, AND THAT IS NOT COSMETIC. `hyprctl -j monitors`
                // reports the transform capitalised ("Normal"), and the config
                // wants it lowercase ("normal"). Writing back what was read
                // produces a config the compositor rejects, and it looks correct.
                choices: [
                    { value: "normal", label: "None" },
                    { value: "90",     label: "90° left" },
                    { value: "180",    label: "Upside down" },
                    { value: "270",    label: "90° right" }
                ]
                current: Outputs.field(card.name, "transform") !== undefined
                       ? String(Outputs.field(card.name, "transform")) : "normal"
                onChanged: function (v) {
                    if (String(v) === "normal")
                        Outputs.clearField(card.name, "transform")
                    else
                        Outputs.setField(card.name, "transform", String(v))
                }
            }
        }
    }

    // ------------------------------------------------------------- B2, the gap
    //
    // ⚠️ A SCREEN THAT IS PLUGGED IN AND NOT IN THE LIST ABOVE IS THE WHOLE OF
    // HIS B2 REPORT: "HDMI is not detected, DisplayPort is". Without this block
    // the page would simply not mention it, and "my monitor is missing" would be
    // answered by a page showing two monitors and no explanation.
    //
    // ⚠️ `bhctl doctor` KEEPS ITS COPY. Whoever needs this has a screen that is
    // not there and may have no desktop to open — that was the reason the
    // diagnosis went into bhctl in the first place, and it has not changed.
    SettingGroup {
        Layout.fillWidth: true
        title: "Connections"
        visible: Services.Connectors.available

        Repeater {
            model: Services.Connectors.entries

            RowLayout {
                id: conn
                required property var modelData
                Layout.fillWidth: true
                spacing: Theme.space3

                readonly property bool inCompositor:
                    Services.Compositor.outputs[String(conn.modelData.name)] !== undefined

                BarText {
                    Layout.fillWidth: true
                    text: String(conn.modelData.name)
                    color: Theme.fg
                }
                BarText {
                    // The four-way verdict, the same one bhctl doctor makes, so
                    // the two can never disagree about what the gap means.
                    text: conn.modelData.connected
                          ? (conn.inThe compositor ? "in use" : "plugged in, not picked up")
                          : "nothing plugged in"
                    font.pixelSize: Theme.fontSizeSm
                    color: (conn.modelData.connected && !conn.inCompositor)
                           ? Theme.warn : Theme.fgMuted
                }
            }
        }

        BarText {
            Layout.fillWidth: true
            text: "A screen that is plugged in but not picked up is a compositor "
                + "problem, and it can be addressed here. A screen missing from "
                + "this list altogether is the cable, the port, or a dock that "
                + "needs a driver — run bhctl doctor."
            font.pixelSize: Theme.fontSizeSm
            color: Theme.fgMuted
            wrapMode: Text.WordWrap
        }
    }
}
