pragma ComponentBehavior: Bound

// An open field with the machine's own answers behind a ▾.
//
// ⚠️ IT EXISTS BECAUSE THE SUGGESTIONS WERE PILLS, AND PILLS ARE A WALL. His
// words about the settings window, twice now: "das ist alles zu viel", and then  // english-ok: the brief, quoted
// about seven pages by name, "dort ist alles so unübersichtlich mit den         // english-ok: the brief, quoted
// bubbles". Dropdown.qml already fixed the CLOSED lists — `choice` rows with
// four or more options. This fixes the OPEN ones, which were never touched:
// `pick`, `picks` and `command` each drew up to eight suggestion pills in a
// Flow, plus a chip row, plus an "and 101 more" line.
//
// Measured, because the height is the whole complaint: a row with a list is
// 55 px (`pick`), 63 px (`picks`) and 89 px (`command`) taller than one
// without. On the Type page four of six rows were that shape — two thirds of
// the page was suggestions for settings you touch once.
//
// ⚠️ OPEN, NOT CLOSED, AND THAT IS THE WHOLE DIFFERENCE FROM Dropdown. A font
// that is not installed here is still a legal value: the config file gets
// copied to another machine, and that machine may have it. So the field stays
// typeable, the list only SUGGESTS, and a value the machine does not know is
// marked rather than refused.
//
// ⚠️ THE POPUP IS A `PopupWindow`, and the reason is written out in
// Dropdown.qml: a menu drawn as a child of the row is cut off by the group
// card's `clip`, and `z` only orders siblings. Two attempts failed in his hands
// before that was understood. This one uses the same part rather than a sixth
// idea of what a menu is.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"

Item {
    id: root

    // Entries may be plain strings or { value, label } — the same two shapes
    // SettingRow accepts, because these lists come straight from it.
    property var options: []

    // One value, or a set of them. `multi` is what `picks` needs: the field
    // shows what is set, and the menu ticks rather than replaces.
    property bool multi: false
    property string current: ""
    property var values: []

    property string placeholder: ""
    property bool usable: true

    // Marked, not refused. Empty means "say nothing".
    property string note: ""

    // ⚠️ WHAT THE VALUE MEANS, when the value is not readable. `timer.soundFile`
    // is 55 characters of directory and one word that matters. The box has to
    // keep showing the value — it is what gets written — so the reading goes
    // BESIDE it. It used to be a line underneath, and a line underneath is one
    // of the five elements that made these rows a wall.
    property string caption: ""

    signal committed(string value)   // single: this is the value now
    signal toggled(string value)     // multi: add it, or take it away

    implicitWidth: line.implicitWidth
    implicitHeight: line.implicitHeight

    // ---------------------------------------------------------------- reading
    function _value(o) {
        return (o !== null && typeof o === "object" && o.value !== undefined)
            ? String(o.value) : String(o)
    }
    function _label(o) {
        if (o !== null && typeof o === "object")
            return String(o.label !== undefined ? o.label : o.value)
        return String(o)
    }
    function _labelOf(v) {
        for (var i = 0; i < root.options.length; i++)
            if (root._value(root.options[i]) === String(v))
                return root._label(root.options[i])
        return String(v)
    }
    function _has(v) {
        for (var i = 0; i < root.values.length; i++)
            if (String(root.values[i]) === String(v))
                return true
        return false
    }

    // What the field shows when it is not being typed into.
    readonly property string shown: {
        if (!root.multi)
            return root.current
        if (root.values.length === 0)
            return ""
        var out = []
        for (var i = 0; i < root.values.length; i++)
            out.push(root._labelOf(root.values[i]))
        return out.join(", ")
    }

    // ⚠️ THE QUERY IS MATCHED AGAINST BOTH HALVES. With `{value,label}` the two
    // say different things — a sound file is a path and a name — and searching
    // only one of them makes half of what is on screen unfindable by what is on
    // screen. That rule came from the pill version and is worth keeping.
    readonly property var matches: {
        var q = search.text.trim().toLowerCase()
        var out = []
        for (var i = 0; i < root.options.length; i++) {
            var o = root.options[i]
            var hay = (root._value(o) + " " + root._label(o)).toLowerCase()
            if (q.length === 0 || hay.indexOf(q) >= 0)
                out.push(o)
        }
        return out
    }

    // Something typed into the search box that is not in the list. For an open
    // field that is a legal answer, so it gets an entry of its own rather than
    // an empty menu — otherwise "add an app-id the machine has never seen" has
    // nowhere to happen.
    readonly property string typed: search.text.trim()
    readonly property bool typedIsNew: {
        if (root.typed.length === 0)
            return false
        for (var i = 0; i < root.options.length; i++)
            if (root._value(root.options[i]) === root.typed)
                return false
        return true
    }

    // ⚠️⚠️ AN ALIAS, NOT A FLAG WITH A BINDING — the fault common/Dropdown.qml
    // records in full. This popup KEEPS its keyboard grab (see the note beside
    // `grabFocus` below), so the compositor really does dismiss it on a click
    // beside it, and quickshell then WRITES `visible = false`. A written value
    // destroys a binding rather than being stopped by it, so the old
    // `property bool menuOpen` and `visible: root.menuOpen` came apart at the
    // first dismissal — flag true, surface gone, and the list could never be
    // shown again. That is what "I cannot click anywhere until I have really    // english-ok: the report, paraphrased
    // chosen something" was.
    property alias menuOpen: popup.visible

    function close() { root.menuOpen = false }

    function _take(v) {
        if (root.multi) {
            root.toggled(String(v))
            // ⚠️ THE MENU STAYS OPEN ON A SET. Picking three app-ids should not
            // mean opening the same menu three times; a single value has
            // nothing left to do and closes.
            search.text = ""
        } else {
            root.committed(String(v))
            root.menuOpen = false
        }
    }

    // ------------------------------------------------------------- the field
    RowLayout {
        id: line
        anchors.fill: parent
        spacing: Theme.space2

        // Single: a real text box, because the value is typeable. Multi: a
        // reading of the set, because "kitty, org.gnome.Nautilus" is not
        // something you edit as one string — you add and remove members.
        TextField {
            id: box
            Layout.fillWidth: true
            visible: !root.multi
            enabled: root.usable
            placeholder: root.placeholder

            function commit() { root.committed(box.text) }
            onAccepted: box.commit()

            Connections {
                target: box.input
                function onActiveFocusChanged() {
                    if (!box.input.activeFocus)
                        box.commit()
                }
            }
        }

        Rectangle {
            id: reading
            Layout.fillWidth: true
            visible: root.multi
            implicitHeight: Theme.space6
            radius: Theme.radiusSm
            color: readingHover.hovered && root.usable ? Theme.cardHover : Theme.surface
            opacity: root.usable ? 1 : Theme.dimmed

            Behavior on color {
                enabled: Theme.animate
                ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
            }

            HoverHandler { id: readingHover; enabled: root.usable }
            TapHandler {
                enabled: root.usable
                onTapped: root.menuOpen = !root.menuOpen
            }

            BarText {
                anchors { left: parent.left; right: parent.right
                          leftMargin: Theme.space2; rightMargin: Theme.space2
                          verticalCenter: parent.verticalCenter }
                // ⚠️ AN EMPTY SET IS A REAL ANSWER AND HAS TO SAY SO. For half
                // these keys empty means "every screen", not "no screens" — the
                // placeholder carries that, exactly as it did on the chip row
                // this replaces. A blank line reads as a broken control.
                text: root.values.length > 0 ? root.shown
                    : root.placeholder.length > 0 ? root.placeholder : "Nothing"
                color: root.values.length > 0 ? Theme.fg : Theme.fgDim
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // Beside the value rather than under it, and it gives way first: the
        // value is what gets written, the reading is a courtesy.
        BarText {
            visible: root.caption.length > 0
            text: root.caption
            font.pixelSize: Theme.fontSizeSm
            color: Theme.fgDim
            elide: Text.ElideRight
            maximumLineCount: 1
            Layout.maximumWidth: line.width / 3
        }

        // ⚠️ THE NOTE IS AN ICON, NOT A SECOND LINE. It used to be a line of its
        // own reading "Not installed here", and a line that appears and
        // disappears under a field changes the row's height while you use it.
        // The whole sentence is in the tooltip, which lives outside this layout
        // — see below.
        Icon {
            id: mark
            visible: root.note.length > 0
            text: "error_outline"
            size: Theme.fontSizeSm
            color: Theme.warn
            HoverHandler { id: markHover }
        }

        // The handle. It is a control rather than decoration, so it says so by
        // reacting — and it turns, which is the one movement a menu button has.
        Rectangle {
            id: handle
            implicitWidth: Theme.space6
            implicitHeight: Theme.space6
            radius: Theme.radiusSm
            color: handleHover.hovered && root.usable ? Theme.cardHover : Theme.surfaceHigh
            opacity: root.usable ? 1 : Theme.dimmed

            Behavior on color {
                enabled: Theme.animate
                ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
            }

            HoverHandler { id: handleHover; enabled: root.usable }
            TapHandler {
                enabled: root.usable
                onTapped: root.menuOpen = !root.menuOpen
            }

            Icon {
                anchors.centerIn: parent
                text: "expand_more"
                size: Theme.fontSizeSm
                color: Theme.fgMuted
                rotation: root.menuOpen ? 180 : 0
                Behavior on rotation {
                    enabled: Theme.animate
                    NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                }
            }
        }
    }

    // ⚠️ OUTSIDE THE RowLayout ABOVE, AND THAT IS NOT TIDINESS. A Tooltip
    // positions itself from `target` by writing its own x and y; inside a
    // layout the layout writes them too, and the two take turns — which this
    // project has already paid for once as a tooltip that flickered under the
    // pointer. `root` is a plain Item and does not position its children.
    Tooltip {
        target: mark
        active: markHover.hovered && root.note.length > 0
        text: root.note
    }

    // Whatever is set arrives from outside; the box only argues with it while
    // you are typing in it.
    onCurrentChanged: if (!box.input.activeFocus) box.text = root.current
    Component.onCompleted: box.text = root.current

    // -------------------------------------------------------------- the menu
    PopupWindow {
        id: popup

        color: "transparent"            // literal-ok: absence of colour

        anchor.item: line
        anchor.rect.y: line.height + Theme.space1
        anchor.edges: Edges.Bottom | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.adjustment: PopupAdjustment.All

        // ⚠️⚠️ THE ONE POPUP THAT KEEPS ITS GRAB, AND THE ONE THAT PAYS FOR IT.
        // Dropdown and FolderPicker gave theirs up, because a grabbing xdg-popup
        // is torn down by the COMPOSITOR on the press, and the same press then
        // reaches the row underneath and acts — measured, with the sidebar
        // reporting its own tap. Without a grab the window's catcher gets the
        // press first and swallows it, which is what he asked for.
        //
        // This one cannot follow them: there is a SEARCH BOX inside this
        // surface, and without a keyboard grab it cannot be typed into at all.
        // So here a click beside the menu closes it AND does whatever it landed
        // on. That is the trade, it is stated rather than discovered later, and
        // it is the right way round: a menu you can search is worth more than a
        // click that does nothing.
        grabFocus: true

        implicitWidth: Math.max(root.width, Theme.space6 * 8)
        implicitHeight: Math.min(body.implicitHeight + Theme.space2 * 2,
                                 Theme.space6 * 10)

        // ⚠️⚠️ THE `!popup.visible` BRANCH CANNOT CLOSE ANYTHING, and that is the
        // same dead shape Dropdown and FolderPicker carried: `visible` is bound
        // to `menuOpen`, so it only drops after the flag has. It still does real
        // work — clearing the search text on the way down — so it stays, but it
        // is not what shuts the menu when you click elsewhere. Nothing is.
        //
        // ⚠️ AND THE FIX THE OTHER TWO GOT DOES NOT TRANSFER UNEXAMINED. There
        // the sheet itself carries `focus: true`, so "the keyboard left" is one
        // property on one item. Here focus is pushed into the search input, and
        // clicking a suggestion row may move it again — a close-on-focus-loss
        // written the same way would fire on the very click that chooses
        // something. Guessing at this file is exactly how Dropdown was
        // "repaired" twice and reported broken twice.
        //
        // ⚠️⚠️ IT HAS BEEN WATCHED SINCE, AND THE ANSWER WAS "NEITHER". Measured
        // in tools/popup-close-check.qml over a full open-click-away cycle: the
        // sheet's `activeFocus` never changed, `closed` never fired, and
        // `backingWindowVisible` only followed our own `visible`. So the concern
        // above — that a close-on-focus-loss would fire on the click that chooses
        // It still registers with common/OpenMenu.qml, so Escape from the window
        // closes the list before the window — see settings/SettingsContent.qml.
        //
        // ⚠️ NO `root.menuOpen = false` IN HERE ANY MORE. With the alias that is
        // an assignment to the property this handler is reacting to, which is
        // either a no-op or a loop depending on the day. The search text is real
        // work and stays.
        onVisibleChanged: {
            if (!popup.visible) {
                search.text = ""
                OpenMenu.release(root)
            } else {
                search.input.forceActiveFocus()
                OpenMenu.claim(root)
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusMd
            color: Theme.menuBg

            ColumnLayout {
                id: body
                anchors.fill: parent
                anchors.margins: Theme.space2
                spacing: Theme.space2

                // ⚠️ A SEARCH BOX, BECAUSE 109 FONTS IS NOT A LIST YOU SCROLL.
                // The pill version said "and 101 more — type to narrow it down"
                // and the box it meant was the value field, so narrowing the
                // list meant destroying the value first.
                TextField {
                    id: search
                    Layout.fillWidth: true
                    placeholder: "Search"
                    onCancelled: root.close()
                    // Return takes the first match — the fastest path through
                    // a long list, and the one a keyboard expects.
                    onAccepted: {
                        if (root.matches.length > 0)
                            root._take(root._value(root.matches[0]))
                        else if (root.typedIsNew)
                            root._take(root.typed)
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    // ⚠️⚠️ A Flickable HAS NO IMPLICIT HEIGHT OF ITS OWN, and
                    // that is the whole of "wenn ich das dropdown menu bei den   // english-ok: his report, quoted
                    // mauszeigern aufmache wird mir nicht angezeigt welche       // english-ok: his report, quoted
                    // zeigerpacks ich habe".                                     // english-ok: his report, quoted
                    //
                    // `contentHeight` says how tall the CONTENT is; it does not
                    // make the item ask for that much room. With only
                    // `fillHeight` here, this contributed ZERO to the column's
                    // implicit height — and the popup above is sized
                    // `Math.min(body.implicitHeight + …)`. So the popup came out
                    // exactly as tall as the search box, the list was clipped to
                    // nothing, and every entry was drawn into a strip zero
                    // pixels high.
                    //
                    // ⚠️ IT LOOKED LIKE AN EMPTY LIST, WHICH IS A DIFFERENT
                    // FAULT ENTIRELY. Measured before touching this: the machine
                    // has four cursor themes, and Services.Installed hands back
                    // all four (`cursorThemes 4 ["Adwaita","Breeze_Light",
                    // "McMojave-cursors","breeze_cursors"]`), plus 138 fonts and
                    // 99 layouts. Nothing was missing from the model; there was
                    // nowhere to draw it.
                    //
                    // ⚠️ And it is EVERY dropdown, not the cursor one — he said
                    // so himself: "das soll nicht nur bei den zeigern angezeigt   // english-ok: his request, quoted
                    // werden sondern in jedem drop down menu". Every `pick` row   // english-ok: his request, quoted
                    // in the settings window is this component.
                    //
                    // `preferredHeight` asks for what the content wants; the
                    // popup's own `Math.min` still caps the whole thing at ten
                    // grid units, so a 138-entry font list scrolls rather than
                    // covering the screen.
                    Layout.preferredHeight: list.implicitHeight
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: list.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    ColumnLayout {
                        id: list
                        width: parent.width
                        spacing: 0      // literal-ok: entries meet, separated by their own padding

                        // What you typed, when the machine has never heard of
                        // it. Offered rather than assumed: an open field with
                        // no way to enter an unknown value is a closed one.
                        Rectangle {
                            Layout.fillWidth: true
                            visible: root.typedIsNew
                            implicitHeight: newLine.implicitHeight + Theme.space2 * 2
                            radius: Theme.radiusSm
                            color: newHover.hovered ? Theme.pillHover
                                 : "transparent"      // literal-ok: absence of colour

                            HoverHandler { id: newHover }
                            TapHandler { onTapped: root._take(root.typed) }

                            RowLayout {
                                id: newLine
                                anchors { left: parent.left; right: parent.right
                                          verticalCenter: parent.verticalCenter
                                          leftMargin: Theme.space3
                                          rightMargin: Theme.space3 }
                                spacing: Theme.space2

                                Icon {
                                    text: "add"
                                    size: Theme.fontSizeSm
                                    color: Theme.fgMuted
                                }
                                BarText {
                                    Layout.fillWidth: true
                                    text: "Use \"" + root.typed + "\""
                                    color: Theme.fg
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Repeater {
                            model: root.menuOpen ? root.matches : []

                            Rectangle {
                                id: entry
                                required property var modelData

                                readonly property string val: root._value(entry.modelData)
                                readonly property bool chosen:
                                    root.multi ? root._has(entry.val)
                                               : String(root.current) === entry.val

                                Layout.fillWidth: true
                                implicitHeight: entryLine.implicitHeight + Theme.space2 * 2
                                radius: Theme.radiusSm
                                // ⚠️ In a set, "chosen" is a tick rather than a
                                // filled row: with six of forty ticked, six
                                // accent-coloured bars is a menu that looks
                                // like it is doing something.
                                color: (!root.multi && entry.chosen) ? Theme.accent
                                     : entryHover.hovered ? Theme.pillHover
                                     : "transparent"     // literal-ok: absence of colour

                                Behavior on color {
                                    enabled: Theme.animate
                                    ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                                }

                                HoverHandler { id: entryHover }
                                TapHandler { onTapped: root._take(entry.val) }

                                RowLayout {
                                    id: entryLine
                                    anchors { left: parent.left; right: parent.right
                                              verticalCenter: parent.verticalCenter
                                              leftMargin: Theme.space3
                                              rightMargin: Theme.space3 }
                                    spacing: Theme.space2

                                    Icon {
                                        visible: root.multi
                                        text: entry.chosen ? "check_box"
                                                           : "check_box_outline_blank"
                                        size: Theme.fontSizeSm
                                        color: entry.chosen ? Theme.accent : Theme.fgMuted
                                    }
                                    BarText {
                                        Layout.fillWidth: true
                                        text: root._label(entry.modelData)
                                        color: (!root.multi && entry.chosen)
                                             ? Theme.accentFg : Theme.fg
                                        elide: Text.ElideRight
                                    }
                                    // The value behind a label that is not it —
                                    // a sound file's name says nothing about
                                    // which of four directories it is in.
                                    BarText {
                                        visible: root._label(entry.modelData) !== entry.val
                                        text: entry.val
                                        font.pixelSize: Theme.fontSizeSm
                                        color: (!root.multi && entry.chosen)
                                             ? Theme.accentFg : Theme.fgDim
                                        elide: Text.ElideLeft
                                        maximumLineCount: 1
                                        Layout.maximumWidth: parent.width / 2
                                    }
                                }
                            }
                        }

                        // An empty menu has to say it is empty rather than look
                        // like a menu that failed to draw.
                        BarText {
                            Layout.fillWidth: true
                            Layout.margins: Theme.space3
                            visible: root.matches.length === 0 && !root.typedIsNew
                            text: root.options.length === 0
                                ? "Nothing to suggest on this machine"
                                : "No match"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.fgMuted
                        }
                    }
                }
            }
        }
    }
}
