// A closed list that opens: the current value, and a menu of the rest.
//
// ⚠️ IT EXISTS BECAUSE PILLS DO NOT SCALE. Every `choice` row drew one pill per
// option in a Flow, which is right for two and unreadable for fourteen — his
// words: "überall wo es ne auswahl wie bei color auswahl gibt, da sind ganz    // english-ok: quoted brief
// viele bubble, das ist unübersichtlich". Fourteen palettes wrapped over three  // english-ok: quoted brief
// lines and the chosen one had to be hunted for.
//
// The rule the row applies is by COUNT, not by taste: two or three options stay
// pills (one click beats opening a menu to pick between two), four or more come
// here. Colours are the deliberate exception and stay visible as swatches,
// because a menu entry reading "Mauve" does not tell you what Mauve looks like.
//
// ⚠️ IT OPENS, IT DOES NOT APPEAR. The standing rule for this shell is that
// nothing arrives without moving, and a menu that blinks into place is the
// clearest possible violation of it.
import QtQuick
import QtQuick.Layouts
// ⚠️ Quickshell, not QtQuick.Window. The old version needed the `Window`
// attached property to find something to reparent into; PopupWindow needs no
// parent of its own, only an anchor.
import Quickshell
import "../../theme"

Item {
    id: root

    // [{ value: "24h", label: "24 hour" }, …]
    property var options: []
    property string current: ""
    property bool usable: true

    signal picked(var value)

    readonly property bool open: root.menuOpen

    function labelFor(v) {
        for (var i = 0; i < root.options.length; i++)
            if (String(root.options[i].value) === String(v))
                return root.options[i].label !== undefined
                     ? String(root.options[i].label) : String(v)
        return String(v)
    }

    implicitWidth: field.implicitWidth
    implicitHeight: field.implicitHeight

    // ------------------------------------------------------------- the field
    Rectangle {
        id: field
        anchors.fill: parent
        implicitWidth: line.implicitWidth + Theme.space3 * 2
        implicitHeight: line.implicitHeight + Theme.space2 * 2
        radius: Theme.radiusSm
        color: hover.hovered && root.usable ? Theme.cardHover : Theme.surfaceHigh
        opacity: root.usable ? 1 : Theme.dimmed

        Behavior on color {
            enabled: Theme.animate
            ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }

        HoverHandler { id: hover; enabled: root.usable }
        TapHandler {
            enabled: root.usable
            onTapped: root.menuOpen = !root.menuOpen
        }

        RowLayout {
            id: line
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Theme.space3
            anchors.rightMargin: Theme.space3
            spacing: Theme.space2

            BarText {
                Layout.fillWidth: true
                text: root.labelFor(root.current)
                color: Theme.fg
                elide: Text.ElideRight
            }
            Icon {
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

    // -------------------------------------------------------------- the menu
    // ⚠️⚠️ ITS OWN WINDOW, AND THE TWO ATTEMPTS BEFORE THIS ONE BOTH FAILED IN
    // HIS HANDS. Reported the first time as "das dropdown menu ist unter dem     // english-ok: quoted brief
    // rest, man kann nichts auswählen und es lässt sich nicht schließen", and    // english-ok: quoted brief
    // the second time, after a fix that was reported as done, as still broken.
    //
    // Attempt one was a child of the row. That could never work: the group card
    // sets `clip: true` so it can fold, which cuts the menu off at the card's
    // edge, and `z` only orders SIBLINGS, so a menu in row three is painted
    // before rows four and five whatever its z says.
    //
    // Attempt two reparented it to `root.Window.contentItem`. That was a guess
    // dressed as a fix — the construct appears exactly ONCE in this whole
    // project, it was never proven anywhere, and the settings window is a
    // `FloatingWindow` rather than the `PanelWindow` everything else here uses.
    // It was reported as still broken, which is the only evidence that counts.
    //
    // ⚠️ AND QUICKSHELL HAD THE RIGHT PART ALL ALONG. `PopupWindow` is a real
    // popup surface — the compositor places it, so no `clip`, no z-order and no
    // layout anywhere in the shell can reach it, and there is nothing to
    // reparent and no coordinates to map. Verified in the type description
    // shipped with quickshell rather than assumed: `ProxyPopupWindow`, exported
    // as `Quickshell._Window/PopupWindow`, with `anchor` (a `PopupAnchor`
    // carrying `item`, `rect`, `edges`, `gravity`, `adjustment`) and
    // `grabFocus`.
    //
    // ⚠️⚠️ AN ALIAS, NOT A FLAG WITH A BINDING — AND THIS IS THE REAL FAULT
    // BEHIND B25, MEASURED AT LAST. It used to read
    // `property bool menuOpen: false` with `visible: root.menuOpen` on the
    // popup, and the note below claimed the compositor could never close this
    // menu. It can, and it does: `grabFocus` made this an xdg-popup WITH A GRAB,
    // so a click beside it is dismissed by the compositor, quickshell WRITES
    // `visible = false` — and a written value destroys the binding. Read off the
    // running shell: `visible=false` arrived with nothing in this project having
    // asked for it.
    //
    // ⚠️ AND THAT IS WHY IT WAS REPORTED AS "you cannot click anywhere until you  // english-ok: the report, paraphrased
    // have really chosen something". After one dismissal the binding is gone:
    // `menuOpen` still says true, `visible` says false and is no longer
    // following anything, so the list can never be shown again. It is not that
    // the click was swallowed — it is that the menu was already dead.
    //
    // With an alias there is no binding to destroy. The popup's own visibility
    // IS the state, so whoever writes it — us or quickshell — it stays true.
    property alias menuOpen: popup.visible

    // ------------------------------------------------------------ the search
    //
    // ⚠️⚠️ IT EXISTS BECAUSE A CLOSED LIST STILL HAS TO BE SEARCHABLE. His words:
    // "da wo es eine auswahl gibt wie z.b. bei den coursen … soll es auch          // english-ok: the request, quoted
    // vorschläge geben, andres weiß man nicht wonach man suchen soll … erst wenn    // english-ok: the request, quoted
    // man das dropdown menu öffnet dann sieht man sag ma mal 5 zeilen die ersten    // english-ok: the request, quoted
    // 5 geordnet und wenn man z.b m eingibt sucht man nach m".                      // english-ok: the request, quoted
    //
    // ⚠️ "NICHT WIE ZUVOR" IS PART OF THE BRIEF. The old shape put the options in   // english-ok: his phrase, quoted
    // the ROW as a Flow of pills, which is the wall he asked to have taken away.
    // This lives only inside the surface you open.
    property string query: ""

    // ⚠️⚠️ THE TYPING ARRIVES FROM THE WINDOW, NOT FROM A FIELD IN HERE, and that
    // is the whole reason B25 survives this feature. A text box inside the popup
    // needs the keyboard, the keyboard needs `grabFocus`, and a grab is exactly
    // what makes the compositor tear this surface down on a click beside it —
    // measured, with the row underneath then acting on the same press.
    //
    // The settings window has the keyboard anyway. Measured before this was
    // built, on the running shell: a letter typed with a list open arrives at
    // settings/SettingsContent.qml as `text="m" key=77`, with `OpenMenu.current`
    // already set. So the window forwards it here and this stays grab-free.
    function type(t) { root.query += t }
    function backspace() { root.query = root.query.slice(0, -1) }

    // What one entry is tall, measured rather than assumed — see the note beside
    // the popup's height.
    readonly property real rowHeight: sizer.implicitHeight + Theme.space2 * 2
    BarText { id: sizer; visible: false; text: "Xg" }   // literal-ok: a ruler, never drawn

    // ⚠️ MATCHED AGAINST BOTH HALVES, the same rule common/SuggestField.qml
    // arrived at and for the same reason: with `{value,label}` the two say
    // different things — `beam` and "Beam" agree, but a palette's id and its
    // name need not — and searching only one makes half of what is on screen
    // unfindable by what is on screen.
    readonly property var matches: {
        var q = root.query.trim().toLowerCase()
        if (q.length === 0)
            return root.options
        var out = []
        for (var i = 0; i < root.options.length; i++) {
            var o = root.options[i]
            var hay = (String(o.value) + " "
                       + String(o.label !== undefined ? o.label : o.value)).toLowerCase()
            if (hay.indexOf(q) >= 0)
                out.push(o)
        }
        return out
    }

    PopupWindow {
        id: popup

        color: "transparent"            // literal-ok: absence of colour

        // Under the field, aligned with its left edge. `adjustment` is what
        // keeps it on screen for a row near the bottom without any of the
        // min/max arithmetic the previous version needed.
        anchor.item: field
        anchor.rect.y: field.height + Theme.space1
        anchor.edges: Edges.Bottom | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.adjustment: PopupAdjustment.All

        grabFocus: false

        implicitWidth: Math.max(root.width, list.implicitWidth + Theme.space2 * 2)

        // ⚠️ FIVE ROWS, AND THE NUMBER IS HIS: "dann sieht man sag ma mal 5      // english-ok: the request, quoted
        // zeilen die ersten 5 geordnet". It used to be eight, which for the      // english-ok: the request, quoted
        // fourteen-entry palette list is a wall you scroll rather than a list you
        // read.
        //
        // ⚠️ THE ROW HEIGHT IS MEASURED, NOT TYPED. `sizer` below is one entry's
        // label with the same font, so a font or scale change carries this — a
        // hard number would show four and a half rows on the next machine.
        implicitHeight: Math.min(root.matches.length, 5) * root.rowHeight
                        + searchRow.implicitHeight
                        + Theme.space2 * 3

        // ⚠️⚠️ `grabFocus: false`, AND IT IS THE OTHER HALF OF THE FIX. With a
        // grab this is an xdg-popup the COMPOSITOR dismisses, and that loses the
        // race every time: on the press niri tears the popup down, quickshell
        // writes `visible = false`, this handler runs, the list lets go of
        // OpenMenu — and only THEN is the same press delivered to the window,
        // where the catcher is already disabled and the row underneath acts.
        // Read out of the running shell, in that order, with the sidebar entry
        // reporting its own tap at the end.
        //
        // Without the grab the press arrives at the window first. Measured
        // immediately after the change, same click, same page: the catcher
        // fired, the list closed, the sidebar did NOT report a tap, and the
        // screenshot after was byte-identical to the one before. That is his
        // sentence exactly — the menu closes "ohne was zu tun".                  // english-ok: the request, quoted
        //
        // ⚠️ WHAT IT COSTS, AND WHY IT IS AFFORDABLE HERE: no grab means no
        // keyboard, so Escape cannot be answered inside this surface. It does not
        // need to be — settings/SettingsContent.qml takes Escape for the whole
        // window and closes the open list first. A list of values needs no typing.
        // common/SuggestField.qml is the one that DOES, and it keeps its grab for
        // that reason; the note there says what that costs it.
        //
        // ⚠️ AND TWO EARLIER ACCOUNTS IN THIS FILE WERE WRONG. Nothing here
        // "could never fire" for the reason once written down: `visible` was
        // bound to a local flag, and quickshell overwrites it, which destroys the
        // binding rather than being blocked by it. And the focus version that
        // replaced it was measured dead in tools/popup-close-check.qml —
        // `activeFocus` on the sheet did not change once over a whole
        // open-click-away cycle, and `closed` never fired either. Both are gone.
        onVisibleChanged: {
            // ⚠️ CLEARED ON THE WAY UP AS WELL AS DOWN. A list that opened still
            // holding the last search would show a filtered set with no visible
            // reason, and the entry you came for would appear to be missing.
            root.query = ""
            if (popup.visible) OpenMenu.claim(root)
            else OpenMenu.release(root)
        }

        Rectangle {
            id: sheet
            anchors.fill: parent
            radius: Theme.radiusMd
            color: Theme.menuBg

            // ⚠️ NO `focus` AND NO ESCAPE HANDLER HERE, DELIBERATELY. Without
            // `grabFocus` this surface never receives the keyboard, so both
            // would be handlers that can only ever sit there looking answered —
            // the same silent-dead shape the `everFocused` latch had, and rule 5
            // says a key without a reader gets finished or removed. Escape is
            // answered for the whole window in settings/SettingsContent.qml,
            // which closes the open list before it closes anything else.

            // ⚠️⚠️ A READOUT, NOT A TEXT BOX, and the difference is honesty. This
            // surface has no keyboard on purpose (see `grabFocus` above), so a
            // TextField here would be a control you cannot put a cursor in — a
            // thing that looks answerable and is not, which is the shape rule 5
            // exists against. It shows what the WINDOW has collected.
            RowLayout {
                id: searchRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.space2
                spacing: Theme.space2

                Icon {
                    text: "search"
                    size: Theme.fontSizeSm
                    color: Theme.fgMuted
                }
                BarText {
                    Layout.fillWidth: true
                    text: root.query.length > 0 ? root.query : "Type to search"
                    color: root.query.length > 0 ? Theme.fg : Theme.fgDim
                    font.pixelSize: Theme.fontSizeSm
                    elide: Text.ElideRight
                }
                // How much of the list is hidden by what has been typed. Silent
                // when nothing is filtered — a counter that always shows is one
                // more number to ignore.
                BarText {
                    visible: root.query.length > 0
                    text: root.matches.length + "/" + root.options.length
                    color: Theme.fgDim
                    font.pixelSize: Theme.fontSizeSm
                }
            }

            Flickable {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: searchRow.bottom
                anchors.bottom: parent.bottom
                anchors.margins: Theme.space2
                anchors.topMargin: Theme.space1
                contentWidth: width
                contentHeight: list.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ColumnLayout {
                    id: list
                    width: parent.width
                    spacing: 0      // literal-ok: rows meet, separated by their own padding

                    Repeater {
                        model: root.menuOpen ? root.matches : []

                        Rectangle {
                            id: entry
                            required property var modelData

                            readonly property bool chosen:
                                String(root.current) === String(entry.modelData.value)

                            Layout.fillWidth: true
                            implicitHeight: label.implicitHeight + Theme.space2 * 2
                            radius: Theme.radiusSm
                            color: entry.chosen ? Theme.accent
                                 : entryHover.hovered ? Theme.pillHover
                                 : "transparent"       // literal-ok: absence of colour

                            Behavior on color {
                                enabled: Theme.animate
                                ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                            }

                            HoverHandler { id: entryHover }
                            TapHandler {
                                onTapped: {
                                    root.picked(entry.modelData.value)
                                    root.menuOpen = false
                                }
                            }

                            BarText {
                                id: label
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Theme.space3
                                anchors.rightMargin: Theme.space3
                                text: entry.modelData.label !== undefined
                                    ? entry.modelData.label : entry.modelData.value
                                color: entry.chosen ? Theme.accentFg : Theme.fg
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }

    function close() { root.menuOpen = false }
}
