pragma ComponentBehavior: Bound

// One setting, one row — and ONE path.
//
// ⚠️ THE `key` IS THE WHOLE DESIGN. A row does not get handed a value and a
// callback; it gets the dotted path of the setting and does both halves through
// it. That closes the failure tests/key-readers.sh cannot see: its subject is
// "a row that writes a key nothing reads is a switch that lies", and the other
// half of that sentence is a row that READS one key and WRITES another. Both
// would be real keys with real readers, the label would name one of them, and
// no text check anywhere could tell. With a single path there is nothing to get
// out of step.
//
// It is also what makes tests/setting-rows.sh possible: every row declares its
// key as a literal string, so the promise "every setting has a row" is
// countable rather than a thing somebody believes.
//
// ⚠️ THE ROW DOES NOT MOVE ITSELF. A switch shows `Config.get(key)`, and
// pressing it asks `Config.set` for a change. If the write is refused — an
// unknown path, a value the adapter will not take — the control stays where it
// was, which is the truth. A control that flips first and reconciles later is
// how you end up looking at a setting that is not set.
//
// Shape is from his reference: label at the left, value at the RIGHT of the same
// line in the form "14 px", the track full width underneath. Switches sit at the
// right-hand end of the label line. No dividing lines anywhere — rows are
// separated by space, which is rule three of the brief.
import QtQuick
import QtQuick.Layouts
import "../common"
import "../../config"
import "../../ipc"
import "../../theme"

ColumnLayout {
    id: root

    // The dotted path into shell.json: "notch.flare", "input.touchpad.tap".
    property string key: ""
    property string label: ""

    // ⚠️ WHICH OF THE TWO LEVELS THIS ROW LIVES ON, and it is declared HERE, on
    // the row, rather than in a list somewhere else. A list would let a new row
    // land on neither level and nobody would notice; a property on the row
    // cannot be forgotten without tests/setting-rows.sh counting it.
    //
    // He asked for both things at once and they look contradictory. 05.08.:
    // "merk dir für später notch größe und so soll man alles in den settings    // english-ok: the brief, quoted
    // einstellen können". 08.08.: "ich habe das gefühl das ist alles zu viel    // english-ok: the brief, quoted
    // irgendwie zu viel settings". Given three ways out he chose the one where
    // both stay true: nothing is deleted, and a page opens showing only the
    // rows you actually reach for.
    //
    // The line between them is not taste, or it would move every time somebody
    // edits a page:
    //
    //   simple        you touch it once when setting the machine up —
    //                 the palette, the wallpaper, the terminal, whether the
    //                 island is on, AND ITS SIZE. He named the notch size
    //                 himself, so a size is not automatically fine-tuning.
    //   advanced      a fine adjustment of something already working: a
    //                 shoulder radius, a blur pass, a dwell in milliseconds, a
    //                 protocol flag, the second half of a symmetric pair.
    property bool advanced: false

    // ⚠️ `parent`, and it is exact rather than lazy: rows are direct children of
    // SettingGroup's `holder`, which publishes `showAdvanced`. Anything else —
    // an attached property, a singleton, walking up the tree — would be a
    // second place for the two to disagree. A row with no such parent (the
    // check harnesses build rows on their own) shows itself.
    visible: !root.advanced
             || parent === null
             || parent.showAdvanced === undefined
             || parent.showAdvanced
    // One short line under the label. Empty means no line — an explanation that
    // only repeats the label is noise with a smaller font.
    property string hint: ""

    // ⚠️ A STRING, NOT A QML ENUM, AND THE TRIPWIRE IS THE REASON. A typo in an
    // enum is caught by the engine but an enum cannot be grepped out of the
    // file; tests/setting-rows.sh checks the spelling of every `kind:` against
    // the eight below, which catches the same typo AND keeps the row table
    // readable from outside QML.
    // switch | slider | choice | field | strings | pick | picks | command
    //        | time | colour | folder | image
    //
    // ⚠️ THE LAST FOUR ARE NOT "MORE OF THE SAME". Each exists because its value
    // has a shape that suggestions cannot express: a time of day is checked
    // rather than offered, a colour is chosen rather than listed, and a folder
    // and an image are looked for rather than named.
    property string kind: "switch"

    // --- pick / picks / command: the values this machine actually has. These
    // SUGGEST rather than forbid — you can still type something that is not
    // installed yet, which matters for a config file that may be copied to
    // another machine before that machine has the font.
    //
    // ⚠️ AN ENTRY MAY BE A PLAIN STRING OR `{ value, label }`, and the second
    // form earns itself on exactly the rows that needed it most: a sound file
    // is a path nobody can read as a pill, and a date format is a row of letter
    // codes that says nothing about the date it produces. The VALUE is what
    // lands in the file either way — a label that could be stored by accident
    // would be a setting that reads well and does nothing.
    property var options: []

    function _optValue(o) {
        return (o !== null && typeof o === "object" && o.value !== undefined)
            ? String(o.value) : String(o)
    }
    function _optLabel(o) {
        if (o !== null && typeof o === "object")
            return String(o.label !== undefined ? o.label : o.value)
        return String(o)
    }
    // The label for a value that is already set — so "Not installed here" and
    // the field itself can speak in the same words the suggestions use.
    function _labelOf(value) {
        for (var i = 0; i < root.options.length; i++)
            if (root._optValue(root.options[i]) === String(value))
                return root._optLabel(root.options[i])
        return String(value)
    }
    function _known(value) {
        for (var i = 0; i < root.options.length; i++)
            if (root._optValue(root.options[i]) === String(value))
                return true
        return false
    }

    // --- slider
    property real from: 0
    property real to: 100
    property real step: 1
    property int decimals: 0
    property string unit: ""

    // --- choice: [{ value: "off", label: "Off" }, …]
    property var choices: []

    // ⚠️ Colours are shown as colours, not as words. Set on the accent row,
    // where a dropdown listing "Mauve" tells you nothing about Mauve. It is a
    // property rather than a guess from the key name, because guessing would
    // break the day somebody names a non-colour setting "accent".
    property bool swatch: false

    // --- field / strings: what an EMPTY value means. A blank box reads as
    // "unset", and for half these keys empty is a real answer with a meaning —
    // an empty monitor list is "every screen", not "no screens".
    property string placeholder: ""

    // Whether this row can do anything right now — a bar height while the bar
    // is switched off cannot. Dimmed rather than hidden: a setting you cannot
    // find is worse than one that is visibly inert, and hiding it would leave
    // the tripwire green while the promise was broken.
    property bool usable: true

    // ⚠️ Read through Config.get, not through a section alias, so that the path
    // in `key` is the only place the setting is named. Measured that a QML
    // binding does track a property read made by dynamic lookup inside a called
    // function, with the same value read directly as the control — so this
    // re-evaluates when the file changes underneath it.
    readonly property var current: root.key.length > 0 ? Config.get(root.key) : undefined

    readonly property real fraction: {
        var span = root.to - root.from
        if (span <= 0)
            return 0
        return Math.max(0, Math.min(1, (Number(root.current) - root.from) / span))
    }

    readonly property string valueText: {
        var v = root.current
        if (v === undefined || v === null)
            return ""
        var n = Number(v)
        if (isNaN(n))
            return String(v)
        return n.toFixed(root.decimals) + (root.unit.length > 0 ? " " + root.unit : "")
    }

    function _snap(raw) {
        var s = root.step > 0 ? root.step : 1
        var v = root.from + Math.round((raw - root.from) / s) * s
        return Math.max(root.from, Math.min(root.to, v))
    }

    // A `list<string>` comes back as a QJSValue wrapper rather than a JS Array —
    // Array.isArray() says false for it, which is why Config.program() walks it
    // by length and index too.
    function _listText(v) {
        if (v === undefined || v === null)
            return ""
        var out = []
        for (var i = 0; i < v.length; i++)
            out.push(String(v[i]))
        return out.join(", ")
    }

    // The same walk as _listText, but keeping the entries apart. `picks` and
    // `command` both need the items rather than a joined line, and both need
    // the walk-by-index: a `list<string>` comes back as a QJSValue wrapper,
    // so `Array.isArray` says false and `.map` is not there.
    function _textArray(v) {
        var out = []
        if (v === undefined || v === null)
            return out
        for (var i = 0; i < v.length; i++)
            out.push(String(v[i]))
        return out
    }

    function _textList(s) {
        var parts = String(s).split(",")
        var out = []
        for (var i = 0; i < parts.length; i++) {
            var p = parts[i].trim()
            if (p.length > 0)
                out.push(p)
        }
        return out
    }

    spacing: Theme.space1
    opacity: root.usable ? 1 : Theme.dimmed

    // ⚠️ THE NAME IS THE KEY, and it is how the search finds this row again
    // after navigating to its page. Rows only exist once their page is built,
    // so there is nothing to hold on to between "you searched for blur" and
    // "the Effects page has finished loading" except a string.
    objectName: root.key

    // Being found should be visible. Landing on a page of seventeen rows with
    // the right one somewhere in it is barely better than not searching — so
    // the row says which one it is, once, and then stops.
    property bool found: false
    function flash() {
        root.found = true
        forget.restart()
    }
    Timer {
        id: forget
        interval: Theme.durSlow * 6
        onTriggered: root.found = false
    }

    // ⚠️ THE LABEL CHANGES COLOUR RATHER THAN GAINING A BACKGROUND. A Rectangle
    // here would be a LAYOUT ITEM — this root is a ColumnLayout, and anchoring a
    // child inside a layout is ignored with a warning — so the highlight would
    // have appeared as an extra empty row pushing everything down. Colour costs
    // no space and cannot move anything.

    // ------------------------------------------------------------- label line
    RowLayout {
        id: labelLine
        Layout.fillWidth: true
        spacing: Theme.space3

        // ⚠️ THE WHOLE ROW IS THE TARGET FOR A SWITCH. It used to be the switch
        // itself — 44 x 24 px at the far right of a row several hundred wide.
        // Both references let you press anywhere on the row, and this shell has
        // already paid once for a hit area smaller than the thing it looked
        // like (the "every pill was half dead" bug, 68x29 lit and 44x21
        // answering).
        HoverHandler { id: rowHover }
        TapHandler {
            enabled: root.kind === "switch" && root.usable
            onTapped: {
                Config.set(root.key, !(root.current === true))
                Config.flush()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0      // literal-ok: absence of a gap — label and its hint are one block

            BarText {
                Layout.fillWidth: true
                text: root.label
                // Accent while the search has just brought you here, then back.
                // The fade out is the point: a highlight that stays is a row
                // that looks permanently special.
                color: root.found ? Theme.accent : Theme.fg
                font.weight: root.found ? Theme.weightSemibold : Theme.weightNormal

                Behavior on color {
                    enabled: Theme.animate
                    ColorAnimation { duration: Theme.durSlow; easing.type: Theme.easing }
                }
            }

            // ⚠️ ONE LINE, AND THE REST IN A TOOLTIP. These explanations are
            // mine and they are long; wrapped, almost every row was three lines
            // tall, and fifty-five of those is the wall he called hard to scan.
            //
            // ⚠️ AND IT IS ELIDED RATHER THAN HIDDEN ON HOVER. Showing it only
            // under the pointer would change the row's HEIGHT as the mouse
            // moves, so the page would shift under you while you read it. One
            // line always, the whole thing in a tooltip: no layout moves at all.
            BarText {
                id: hintLine
                Layout.fillWidth: true
                visible: root.hint.length > 0
                text: root.hint
                font.pixelSize: Theme.fontSizeSm
                color: Theme.fgMuted
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // ⚠️ THE NUMBER USED TO BE HERE, at the right-hand end of the label
        // line, and it is gone because the slider now carries it in a box you
        // can type into. Two readings of one number, one above the other, is how
        // they start to disagree — and the box is the one you can act on.

        // ⚠️ NO `onToggled` HERE, AND ITS ABSENCE IS THE FIX. The switch used to
        // answer the press as well, so pressing the SWITCH ran both handlers and
        // the second undid the first — measured in the running shell, both lines
        // in the journal, one press. Pressing the label worked and pressing the
        // switch did nothing, which is exactly the shape of "manche switches      // english-ok: the report, quoted
        // gehen nicht". The row above is now the only writer.                     // english-ok: the report, quoted
        Toggle {
            visible: root.kind === "switch"
            usable: root.usable
            checked: root.current === true
        }
    }

    // ----------------------------------------------------------- the control
    // ⚠️ `visible: active`, and it is load-bearing. A Loader with `active:
    // false` is zero pixels tall but STILL VISIBLE, and QtQuick.Layouts gives
    // every visible child its row spacing — ghost gaps, measured at 48 px where
    // 16 was meant. With eighteen rows on a page that is the difference between
    // a layout and a mess.
    Loader {
        Layout.fillWidth: true
        active: root.kind !== "switch"
        visible: active
        sourceComponent: root.kind === "slider" ? sliderControl
                       : root.kind === "choice" ? choiceControl
                       : root.kind === "strings" ? stringsControl
                       : root.kind === "field" ? fieldControl
                       : root.kind === "pick" ? pickControl
                       : root.kind === "picks" ? picksControl
                       : root.kind === "command" ? commandControl
                       : root.kind === "time" ? timeControl
                       : root.kind === "colour" ? colourControl
                       : root.kind === "folder" ? folderControl
                       : root.kind === "image" ? imageControl
                       : null
    }

    // ⚠️ `sourceComponent` needs a Component, never an instance. QML accepts an
    // instance without a word of complaint and then never builds the thing.
    // The whole explanation, only while the pointer is on the row. It is the
    // same Tooltip the icon rail uses, so there is one definition of what a
    // tooltip looks like rather than two that drift.
    Tooltip {
        target: labelLine
        active: rowHover.hovered && hintLine.truncated
        text: root.hint
    }

    Component {
        id: sliderControl

        // ⚠️⚠️ THIS NOTE USED TO SAY "NOT `common/LevelRow` ANY MORE", AND THAT
        // IS NO LONGER TRUE — SettingSlider is built ON LevelRow now, and the
        // history is worth keeping because both directions came from him.
        //
        // First: "die slider sehen kacke aus", which is what split them apart —  // english-ok: the report, quoted
        // a thin track with a round handle here, the thick fill-is-the-handle
        // track in the quick panel. Then, after using it: "kannst du die slider  // english-ok: the request, quoted
        // im settingsmenu so machen wie die im quickpanel evtl nicht so groß     // english-ok: the request, quoted
        // aber vom style das es einheitlich ist".                                // english-ok: the request, quoted
        //
        // So the track is shared and the box is not: the values here are exact —
        // 14 px of flare, a scroll factor of 1.00 — and those are typed, not
        // dragged. A volume is neither.
        //
        // ⚠️ THE VALUE IS SHOWN HERE, so the row's own `display` text is off.
        // Two readings of the same number, one above the other, is how they
        // start to disagree.
        SettingSlider {
            value: Number(root.current)
            from: root.from
            to: root.to
            step: root.step
            decimals: root.decimals
            unit: root.unit
            usable: root.usable
            onMoved: function (v) { Config.set(root.key, v) }
            // Config.set only schedules a write; a decision lands it now rather
            // than in 250 ms.
            onDecided: function (v) { Config.set(root.key, v); Config.flush() }
        }
    }

    Component {
        id: choiceControl

        // ⚠️ THE FORM IS CHOSEN BY THE NUMBER OF OPTIONS, not by a seventh
        // `kind`. His complaint was exact: "überall wo es ne auswahl wie bei     // english-ok: quoted brief
        // color auswahl gibt, da sind ganz viele bubble, das ist                // english-ok: quoted brief
        // unübersichtlich" — fourteen palettes as a Flow of pills wrap over      // english-ok: quoted brief
        // three lines and the chosen one has to be hunted for.
        //
        // Deriving it from `choices.length` rather than adding a `kind` keeps
        // one declaration per row: a page says what the options ARE, and the
        // control decides how to show them. A seventh kind would mean every row
        // stating the same fact twice, and tests/setting-rows.sh checks `kind`
        // against a fixed list.
        //
        //   2–4 options   a segmented track.
        //   5 or more     a dropdown.
        //   colours       swatches, whatever the count — see `swatch`.
        //
        // ⚠️ IT WAS PILLS AT 2–3, AND HE THREW THEM OUT: "das mit den bubbles    // english-ok: the report, quoted
        // auch das alles ist null meins". Free-standing pills say neither that   // english-ok: the report, quoted
        // the choices belong together nor which one is true — the fill that
        // marks the chosen one is the same gesture as a hover. A track says
        // both, and the geometry already existed in ThemingRow, which is why
        // Segmented is now one file that both use.
        //
        // ⚠️ AND THE BOUNDARY MOVED FROM 3 TO 4. A track of four fits the row
        // where four pills wrapped; the dropdown starts where the words stop
        // fitting side by side, not one earlier.
        Item {
            implicitWidth: swatches.visible ? swatches.implicitWidth
                         : track.visible ? track.implicitWidth
                         : menu.implicitWidth
            implicitHeight: swatches.visible ? swatches.implicitHeight
                          : track.visible ? track.implicitHeight
                          : menu.implicitHeight

            readonly property bool few: root.choices.length <= 4

            // --------------------------------------------- 2–4: one track
            Segmented {
                id: track
                anchors.right: parent.right
                visible: !root.swatch && parent.few
                usable: root.usable
                options: track.visible ? root.choices : []
                current: root.current
                onChosen: function (v) {
                    Config.set(root.key, v)
                    Config.flush()
                }
            }

            // ------------------------------------------------- 5+: a dropdown
            Dropdown {
                id: menu
                width: parent.width
                visible: !root.swatch && !parent.few
                options: menu.visible ? root.choices : []
                current: String(root.current)
                usable: root.usable
                onPicked: function (v) {
                    Config.set(root.key, v)
                    Config.flush()
                }
            }

            // --------------------------------------------- colours: swatches
            // ⚠️ THE ONE EXCEPTION, and it earns itself. A dropdown entry
            // reading "Mauve" does not tell you what Mauve looks like, so the
            // list would be fourteen words you have to try one at a time. The
            // colour IS the label.
            Flow {
                id: swatches
                width: parent.width
                visible: root.swatch
                spacing: Theme.space2

                Repeater {
                    model: swatches.visible ? root.choices : []

                    Rectangle {
                        id: dot
                        required property var modelData

                        readonly property bool chosen:
                            String(root.current) === String(dot.modelData.value)

                        implicitWidth: Theme.space5
                        implicitHeight: Theme.space5
                        radius: width / 2
                        color: Scheme.color(String(dot.modelData.value))
                        opacity: root.usable ? 1 : Theme.dimmed

                        // The ring, drawn outside the fill so the colour is
                        // never covered by the thing marking it.
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width + Theme.space2
                            height: width
                            radius: width / 2
                            color: "transparent"          // literal-ok: absence of colour
                            border.width: dot.chosen ? Theme.hairline * 2 : 0
                            border.color: Theme.fg

                            Behavior on border.width {
                                enabled: Theme.animate
                                NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                            }
                        }

                        HoverHandler { id: dotHover; enabled: root.usable }
                        TapHandler {
                            enabled: root.usable
                            onTapped: {
                                Config.set(root.key, dot.modelData.value)
                                Config.flush()
                            }
                        }

                        scale: dotHover.hovered ? 1.15 : 1
                        Behavior on scale {
                            enabled: Theme.animate
                            NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                        }

                        // ⚠️ `target` and `active`, which is Tooltip's actual
                        // API — the name of a colour has to be reachable, or
                        // swatches are fourteen dots you have to guess at.
                        Tooltip {
                            target: dot
                            active: dotHover.hovered
                            text: dot.modelData.label !== undefined
                                ? String(dot.modelData.label) : String(dot.modelData.value)
                        }
                    }
                }
            }
        }
    }

    // A comma-separated line for a `list<string>`.
    Component {
        id: stringsControl

        TextField {
            id: listField
            enabled: root.usable
            text: root._listText(root.current)
            placeholder: root.placeholder

            function commit() {
                Config.set(root.key, root._textList(listField.text))
                Config.flush()
            }

            onAccepted: listField.commit()
            // Leaving the field is also a decision. Requiring Return is how a
            // typed value gets lost by clicking somewhere else.
            Connections {
                target: listField.input
                function onActiveFocusChanged() {
                    if (!listField.input.activeFocus)
                        listField.commit()
                }
            }
        }
    }

    // ⚠️ A FIELD WITH SUGGESTIONS, NOT A DROPDOWN. There are 133 font families
    // on the test machine and 99 keyboard layouts — as pills that is a wall, and
    // as a closed list it would refuse a name this machine does not have yet.
    // Typing filters; clicking picks; leaving it alone keeps what you typed.
    //
    // ⚠️⚠️ TWO FAULTS LIVED HERE AND TOGETHER THEY MADE EVERY LIST LOOK EMPTY.
    // He reported it as "wherever there should be a choice you cannot change
    // anything", and the service was innocent: a headless probe
    // (tools/installed-check.qml) reports 4 cursor themes, 109 fonts and 99
    // layouts on the same machine, at the same moment.
    //
    //   1. the suggestions were gated on `activeFocus`, so nothing was visible
    //      until the field already had the keyboard. You could not see that
    //      there WAS a choice, which is the one thing a list has to do.
    //   2. the field shows the current value, and that value was used as the
    //      search query. `cursor.theme` was "Breeze_Dark"; the four installed
    //      themes are Adwaita, Breeze_Light, McMojave-cursors, breeze_cursors —
    //      none of them contains that string. Zero matches, exactly when the
    //      list was needed most, and it got worse the more wrong the current
    //      value was.
    // ⚠️⚠️ THE PILLS ARE GONE, AND THE WORD IS HIS: seven pages by name, and
    // "dort ist alles so unübersichtlich mit den bubbles". Dropdown.qml fixed   // english-ok: the report, quoted
    // the CLOSED lists in August; these open ones were never touched, and they
    // are where most of the pills actually were — two thirds of the Type page.
    //
    // What stood here was SIX elements for one setting: a text box, an "Apply"
    // pill, a "Not installed here" line, a reading of the value, a Flow of up
    // to eight suggestion pills, and an "and 101 more" line. Measured, that is
    // 55 px taller than a plain row.
    //
    // All of it is now `common/SuggestField`: one line, with the machine's
    // answers behind a ▾ and a search box of their own. Nothing is lost, and
    // two things are gained — the list is COMPLETE rather than its first eight,
    // and it can be searched without destroying the value to do it.
    Component {
        id: pickControl

        SuggestField {
            options: root.options
            current: root.current === undefined || root.current === null
                   ? "" : String(root.current)
            placeholder: root.placeholder
            usable: root.usable

            // ⚠️ The one truth a text box cannot tell: the value in the file is
            // not on this machine. `cursor.theme` ships as "Breeze_Dark" and
            // the test machine has no such theme. Kept rather than corrected —
            // a config copied here from another machine keeps its answer.
            note: root.options.length > 0
                  && String(root.current).length > 0
                  && !root._known(root.current)
                ? "Not on this machine. The value is kept as it is."
                : ""

            // What the value means, when it is a path rather than a name.
            caption: String(root.current).length > 0
                     && root._labelOf(root.current) !== String(root.current)
                   ? root._labelOf(root.current) : ""

            // ⚠️ THE VALUE, NEVER THE LABEL — the two differ on exactly the
            // rows this form was added for, and writing the label would be a
            // setting that reads perfectly and points at nothing. SuggestField
            // hands back values for that reason.
            onCommitted: function (value) {
                Config.set(root.key, value)
                Config.flush()
            }
        }
    }

    // ⚠️ WHEN A TYPED VALUE IS TAKEN, and it is not "when you leave the field".
    // He reported "typing works but is not taken over", and the mechanism was
    // this: the only thing that committed was losing keyboard focus, and in a
    // window whose other controls are sliders and menus there is nothing that
    // TAKES focus — so the field kept it until the window closed, and closing
    // destroyed the value.
    //
    // SuggestField answers it three ways and all of them fire: Return, picking
    // an entry from the menu, and the focus-loss handler for the case where
    // something does take focus. The "Apply" pill that used to sit beside the
    // box went with the rest of the pills — a button that is present and
    // usually does nothing teaches people to ignore it.
    // ⚠️⚠️ A SET, NOT A LINE OF TEXT — and nine rows were the wrong shape.
    //
    // Which screens a surface appears on, which app-ids get blurred or float,
    // what starts with the session: the order means nothing, and every entry is
    // a name this machine can produce. As comma-separated boxes they were nine
    // invitations to mistype an app-id — and a mistyped app-id is not an error
    // anywhere. niri simply never matches the rule, and the window you wanted
    // blurred is not blurred, with nothing in any log to say why.
    //
    // ⚠️ TICKS RATHER THAN CHIPS, since the pills went. The chip row said what
    // was set, a second box added your own, a Flow underneath offered the
    // machine's answers and a line under THAT admitted it was only showing
    // eight of them — four elements, 63 px taller than a plain row. One menu
    // does all four: what is set is ticked, and ticking is also how it comes
    // off again.
    Component {
        id: picksControl

        SuggestField {
            id: picks

            multi: true
            options: root.options
            values: root._textArray(root.current)
            placeholder: root.placeholder
            usable: root.usable

            function write(list) {
                Config.set(root.key, list)
                Config.flush()
            }

            // ⚠️ NAMED FUNCTIONS, NOT LOGIC INSIDE THE HANDLER — and the reason
            // is that tests/row-writes.sh calls them. It reaches one function
            // below where a click lands, because synthetic input into this
            // window was MEASURED not to arrive (pointer motion does, clicks and
            // keystrokes do not). The first version of this rewrite buried both
            // in `onToggled`, the harness could not find `add`, and it said so
            // on the next run — which is the check doing exactly its job.
            //
            // ⚠️ The set is re-read from the config each time rather than kept
            // alongside it. A local copy of a list the file also owns is two
            // answers to one question, and the one on screen goes stale.
            function add(v) {
                var s = String(v).trim()
                if (s.length === 0)
                    return
                var cur = root._textArray(root.current)
                if (cur.indexOf(s) >= 0)
                    return
                var out = cur.slice()
                out.push(s)
                picks.write(out)
            }
            function drop(v) {
                var s = String(v)
                var cur = root._textArray(root.current)
                var out = []
                for (var i = 0; i < cur.length; i++)
                    if (cur[i] !== s)
                        out.push(cur[i])
                picks.write(out)
            }

            // Ticking is both directions: the menu shows what is set, so the
            // same entry has to be able to take itself away.
            onToggled: function (value) {
                if (root._textArray(root.current).indexOf(String(value)) >= 0)
                    picks.drop(value)
                else
                    picks.add(value)
            }
        }
    }

    // ⚠️⚠️ AN ARGUMENT LIST, WHICH IS WHY IT IS NOT `picks`. `programs.terminal`
    // is ["kitty", "-e", "btop"]: the first entry is the program and the rest
    // are its arguments, in order. A chip field would have made them a set you
    // can shuffle, and `spawn` with the arguments in the wrong order fails with
    // a message that does not mention the reason.
    //
    // So the two halves are separated and each gets the control it deserves:
    // the program is a name this machine knows and gets suggestions, the
    // arguments are free text and stay untouched when a suggestion is clicked.
    Component {
        id: commandControl

        ColumnLayout {
            id: cmd
            spacing: Theme.space2

            readonly property var argv: root._textArray(root.current)
            readonly property string program: cmd.argv.length > 0 ? cmd.argv[0] : ""
            readonly property string args:
                cmd.argv.length > 1 ? cmd.argv.slice(1).join(", ") : ""

            function write(prog, argsText) {
                var out = []
                var p = String(prog).trim()
                if (p.length > 0)
                    out.push(p)
                var rest = root._textList(argsText)
                // ⚠️ ARGUMENTS WITHOUT A PROGRAM ARE DROPPED, not kept. A list
                // whose first entry is "-e" is a spawn that looks for a binary
                // called "-e"; keeping them would turn an empty program box
                // into a key binding that fails at the moment it is pressed.
                if (out.length > 0)
                    for (var i = 0; i < rest.length; i++)
                        out.push(rest[i])
                Config.set(root.key, out)
                Config.flush()
            }

            // The program: a name this machine knows, so it gets the menu.
            SuggestField {
                Layout.fillWidth: true
                options: root.options
                current: cmd.program
                placeholder: root.placeholder
                usable: root.usable

                note: root.options.length > 0 && cmd.program.length > 0
                      && !root._known(cmd.program)
                    ? "Not on this machine. The value is kept as it is."
                    : ""

                // ⚠️ THE ARGUMENTS SURVIVE. Picking a different terminal must
                // not silently drop the `-e btop` that made the binding worth
                // having — which is why this writes both halves, every time.
                onCommitted: function (value) { cmd.write(value, argsField.text) }
            }

            // The arguments: free text, and they stay free. A chip field would
            // have made them a set you can shuffle, and `spawn` with the
            // arguments in the wrong order fails with a message that does not
            // mention the reason.
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space2

                TextField {
                    id: argsField
                    Layout.fillWidth: true
                    enabled: root.usable
                    text: cmd.args
                    // One string per argument, which is what niri's `spawn`
                    // takes — a whole command line in one string makes it look
                    // for a binary with spaces in its name.
                    placeholder: "No arguments — separate them with commas"
                    onAccepted: cmd.write(cmd.program, argsField.text)
                }

                // ⚠️ THIS ONE KEEPS ITS APPLY PILL, and it is the only field in
                // the window that still needs one. The program box commits
                // through the menu; this box has nothing that takes focus away
                // from it, so without a button a typed argument list lives
                // until the window closes and then does not.
                Pill {
                    interactive: true
                    visible: argsField.text !== cmd.args
                    active: true
                    BarText { text: "Apply"; color: Theme.accentFg }
                    onClicked: cmd.write(cmd.program, argsField.text)
                }
            }
        }
    }

    // ⚠️ A TIME THAT IS CHECKED, because the reader does not check and does not
    // complain. Scheme.qml turns these two into minutes with a split on ":" and
    // a Number(); "7pm" gives NaN, the comparison is then false in both
    // directions, and the light palette simply never arrives. No warning, no
    // log line — a setting that looks set and does nothing, which is the exact
    // fault this project has now found six times.
    //
    // So an unreadable value is REFUSED and the old one stays, and the row says
    // why while you are still typing it.
    Component {
        id: timeControl

        RowLayout {
            id: time
            spacing: Theme.space2

            readonly property string stored:
                root.current === undefined || root.current === null ? "" : String(root.current)
            // 00:00 to 23:59, one or two digits for the hour, because 7:00 is
            // what a person types.
            function valid(s) { return /^([01]?\d|2[0-3]):[0-5]\d$/.test(String(s).trim()) }

            TextField {
                id: timeField
                Layout.fillWidth: true
                enabled: root.usable
                text: time.stored
                placeholder: root.placeholder.length > 0 ? root.placeholder : "07:00"

                function commit() {
                    if (time.valid(timeField.text)) {
                        Config.set(root.key, timeField.text.trim())
                        Config.flush()
                    }
                }
                onAccepted: timeField.commit()
                Connections {
                    target: timeField.input
                    function onActiveFocusChanged() {
                        if (!timeField.input.activeFocus)
                            timeField.commit()
                    }
                }
            }

            BarText {
                visible: !time.valid(timeField.text)
                text: "Needs HH:MM"
                font.pixelSize: Theme.fontSizeSm
                color: Theme.warn
            }

            Pill {
                interactive: true
                visible: timeField.text !== time.stored && time.valid(timeField.text)
                active: true
                BarText { text: "Apply"; color: Theme.accentFg }
                onClicked: timeField.commit()
            }
        }
    }

    Component {
        id: colourControl

        ColourPicker {
            usable: root.usable
            value: root.current === undefined || root.current === null
                       ? "" : String(root.current)
            onPicked: function (hex) {
                // ⚠️ NOT flushed on every drag step. Config.save writes the WHOLE
                // file, and a finger on the saturation square moves once per
                // frame — sixty full writes a second on a laptop. Config.set
                // debounces at 250 ms, which is what that debounce is for; the
                // colour is settled long before anybody looks away.
                Config.set(root.key, hex)
            }
        }
    }

    // ⚠️ THE PATH IS SHOWN, NOT TYPED. A folder is looked for, not remembered —
    // and the box that was here asked you to know the spelling of a path before
    // you could use it. It stays readable rather than editable because the
    // picker can reach anywhere the box could.
    Component {
        id: folderControl

        RowLayout {
            id: folderRow
            spacing: Theme.space2

            readonly property string stored:
                root.current === undefined || root.current === null ? "" : String(root.current)

            Rectangle {
                id: pathBox
                Layout.fillWidth: true
                implicitHeight: pathText.implicitHeight + Theme.space2 * 2
                radius: Theme.radiusSm
                color: Theme.surfaceHigh
                opacity: root.usable ? 1 : Theme.dimmed

                BarText {
                    id: pathText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.space3
                    anchors.rightMargin: Theme.space3
                    text: folderRow.stored.length > 0 ? folderRow.stored
                                                      : (root.placeholder.length > 0
                                                         ? root.placeholder : "Not set")
                    color: folderRow.stored.length > 0 ? Theme.fg : Theme.fgMuted
                    // Elided from the LEFT: a path is identified by its end.
                    elide: Text.ElideLeft
                    maximumLineCount: 1
                }
            }

            Pill {
                interactive: root.usable
                BarText { text: "Browse"; color: Theme.fg }
                onClicked: picker.show()
            }

            FolderPicker {
                id: picker
                current: folderRow.stored
                anchorItem: pathBox
                onChosen: function (path) {
                    Config.set(root.key, path)
                    Config.flush()
                }
            }
        }
    }

    // ⚠️ IT OPENS THE CHOOSER THAT EXISTS RATHER THAN GROWING A SECOND ONE.
    // The wallpaper grid is already a notch page on Mod+Shift+W, with the
    // thumbnails, the sourceSize work and the palette preview in it. A second
    // grid here would be a second thing to keep in step, and the two would
    // disagree about which folder they read within a month.
    Component {
        id: imageControl

        RowLayout {
            id: imageRow
            spacing: Theme.space3

            readonly property string stored:
                root.current === undefined || root.current === null ? "" : String(root.current)

            // ⚠️ THE VALUE IS ALREADY A file:// URL — services/Wallpaper.qml
            // stores what the picker hands it, and the row's own hint says so.
            // Prepending a scheme produced "file://file:///…", which Image
            // cannot open: the preview box stayed empty and the name read
            // "file:///…". Seen on a screenshot, not by any check, because an
            // Image that cannot load is silent by design.
            //
            // A bare path is still accepted: somebody editing shell.json by hand
            // writes one, and refusing it would be a row that only understands
            // its own output.
            readonly property string url: {
                if (imageRow.stored.length === 0)
                    return ""
                return imageRow.stored.indexOf("file://") === 0
                     ? imageRow.stored : "file://" + imageRow.stored
            }
            readonly property string fileName: {
                var parts = imageRow.stored.split("/")
                var last = parts[parts.length - 1]
                // A trailing slash, or the "file:///…" placeholder, leaves
                // nothing useful — better to say nothing than to draw a stub.
                return last === "…" ? "" : decodeURIComponent(last)
            }

            Rectangle {
                implicitWidth: Theme.space6 * 2
                implicitHeight: Theme.space6
                radius: Theme.radiusSm
                clip: true
                color: Theme.surfaceHigh
                opacity: root.usable ? 1 : Theme.dimmed

                Image {
                    anchors.fill: parent
                    visible: imageRow.url.length > 0
                    source: imageRow.url
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    // ⚠️ READ AT THE SIZE IT IS DRAWN. The wallpapers here are
                    // 4–6 MB PNGs and this is a thumbnail; without sourceSize
                    // the full image is decoded into memory to be shown at
                    // sixty pixels tall. WallpaperPage learned this already.
                    sourceSize.width: Theme.space6 * 2
                    sourceSize.height: Theme.space6
                }
            }

            BarText {
                Layout.fillWidth: true
                text: imageRow.fileName.length > 0 ? imageRow.fileName
                                                   : (root.placeholder.length > 0
                                                      ? root.placeholder : "Not set")
                color: imageRow.fileName.length > 0 ? Theme.fg : Theme.fgMuted
                elide: Text.ElideMiddle
                maximumLineCount: 1
            }

            Pill {
                interactive: root.usable
                BarText { text: "Choose"; color: Theme.fg }
                onClicked: Ipc.show("wallpaper")
            }
        }
    }

    Component {
        id: fieldControl

        RowLayout {
            spacing: Theme.space2

            readonly property string stored:
                root.current === undefined || root.current === null ? "" : String(root.current)

            TextField {
                id: plainField
                Layout.fillWidth: true
                enabled: root.usable
                placeholder: root.placeholder
                text: parent.stored

                function commit() {
                    Config.set(root.key, plainField.text)
                    Config.flush()
                }

                onAccepted: plainField.commit()
                Connections {
                    target: plainField.input
                    function onActiveFocusChanged() {
                        if (!plainField.input.activeFocus)
                            plainField.commit()
                    }
                }
            }

            Pill {
                interactive: true
                visible: plainField.text !== plainField.parent.stored
                active: true
                BarText { text: "Apply"; color: Theme.accentFg }
                onClicked: plainField.commit()
            }
        }
    }
}
