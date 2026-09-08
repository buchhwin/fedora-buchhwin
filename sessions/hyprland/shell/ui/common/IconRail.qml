pragma ComponentBehavior: Bound

// The vertical strip of symbols down the left of a panel.
//
// His choice, in his words: "symbolleiste links statt tab-pillen, nur symbole   english-ok: the request, quoted
// mit tooltip". The tooltip is not decoration — a symbol on its own explains     english-ok: the request, quoted
// less than the word it replaced, and "übersichtlicher" has to mean easier to    english-ok: quoted brief
// read, not merely emptier.
//
// ⚠️⚠️ THIS NOTE USED TO SAY "BUILT ONCE AND USED TWICE — the settings window
// has the same strip", AND THAT WAS NEVER TRUE. The settings sidebar is
// ui/settings/SettingsRail.qml, a different control, and its own header spells
// out why it cannot be this one: it draws NAMED ROWS, and a tooltip standing in
// for a label that is right there is nothing.
//
// The claim survived because it was a comment, and a comment reads as a source.
// It reached the handouts, where it became "the same rail is in the settings
// window, in the un-centred form" — a sentence that would have sent the next
// round to fix a component the report was not about. Rule 3: a comment is not a
// source.
//
// What IS true, and is the useful half: this is used in ONE place, and anything
// belonging to that caller — which entries, which is current — comes in from
// outside rather than being decided here.
//
// ⚠️ IT SITS ON `Pill`, not on a bare Rectangle with a TapHandler. Pill carries
// its own hit area sized to the whole shape; a handler added at the call site
// lands in Pill's inner Item, which is only as big as its contents. That was
// the "every pill was half dead" bug — 68x29 lit, 44x21 answering — and reusing
// Pill is what keeps it closed.

import QtQuick
import QtQuick.Layouts
import "../../theme"

// ⚠️ AN `Item`, NOT A `RowLayout`, AND THAT IS A BUG FIX. As a layout the
// tooltip was a layout CHILD, so the layout wrote its `x` while the tooltip's
// own binding wrote it too. The two took turns, the pane jumped under the
// pointer, and the hover flickered — measured in the log as
// `true 1 … false 1 … true 1 … false 1` several times a second, which is why
// the tooltip never stayed up long enough to be seen.
//
// The rail is laid out; the tooltip floats over it. Those are two different
// jobs and they do not belong in one layout.
Item {
    id: root

    // One entry per row: { icon: "dashboard", tooltip: "Overview" }.
    // ⚠️ Every icon name goes through tests/icons.sh first. "Material Icons
    // Round" is missing more names than anyone expects — `grid_view` and
    // `space_dashboard` are both absent, which is how `dashboard` was chosen.
    property var entries: []
    property int currentIndex: 0
    signal activated(int index)

    // ⚠️⚠️ IT USED TO HAVE A `centred` MODE, AND IT IS GONE ON HIS INSTRUCTION.
    // The history is worth keeping because the two requests read like opposites
    // and are not. On 06.08 he asked for the group to sit in the middle ("nicht  english-ok: the request, quoted
    // über die ganze höhe aber gleiche größe alles schon mittig"), which is      english-ok: the request, quoted
    // where `centred` came from. Later he asked for the opposite: "die leiste    english-ok: the request, quoted
    // links am besten oben bündig machen damit die einzelnen punkte immer an     english-ok: the request, quoted
    // der gleichen stelle sind".                                                 english-ok: the request, quoted
    //
    // Both sentences are the same requirement. The quick panel is a different
    // height on every tab, so a group centred in it lands somewhere new each
    // time you switch — the middle of a moving box is not a place. Top-aligned
    // is the only one of the two that is.
    //
    // ⚠️ The property is REMOVED rather than defaulted to false: nothing reads
    // it any more, and rule 5 says a key with no reader is finished or deleted,
    // not left lying. The old note claiming the settings window would take this
    // component was wrong on its own terms — see below.

    implicitWidth: rail.implicitWidth
    // ⚠️ The NATURAL height, which is now also the only one — the rail is as
    // tall as its symbols and sits at the top of whatever it is given. Asking
    // for the height back from the parent would be a layout sizing itself from
    // itself, which is what the centred form had to be careful about.
    implicitHeight: rail.implicitHeight

    // ⚠️ STACKED ABOVE ITS SIBLINGS, and that belongs to the component rather
    // than to the caller. `z: 100` inside the rail only orders the tooltip
    // against the pills; between SIBLINGS the later one wins, and the rail is
    // the first child of every panel that uses it. Measured on screen: the
    // tooltip drew opaque and correct, and the calendar's "Mon"/"Tue" drew on
    // top of the word anyway.
    z: 1

    ColumnLayout {
        id: rail
        anchors.left: parent.left
        anchors.top: parent.top
        spacing: Theme.space2

        Repeater {
            model: root.entries

            Pill {
                id: railPill
                required property int index
                required property var modelData

                // ⚠️ EVERY CELL THE SAME SIZE, and nothing used to say so. The
                // brief is exact: "beim Quicksettings soll jeder Tab gleich        // english-ok: quoted brief
                // groß sein, ist aktuell auch nicht". It was not, and the        // english-ok: quoted brief
                // reason is worth writing down because it is invisible in the
                // source: a Pill takes its width from `childrenRect`, its only
                // child here is an Icon, and an Icon is a bare Text. So each
                // cell was as wide as its LIGATURE — `notifications` wider than
                // `timer`, with NativeRendering giving fractional metrics on top
                // — and the column came out ragged with nothing in the code
                // naming a single width.
                //
                // A square from a token, the same trick SettingsRail already
                // uses for its symbols, and the Icon centres inside it.
                //
                // ⚠️ AND IT IS MEASURED, not assumed. He reported the rail as
                // uneven — "hab immer eine unterschiedliche höche und nicht den   // english-ok: the report, quoted
                // gleichen platz" — before this fixed square existed. Read off   // english-ok: the report, quoted
                // the running panel afterwards, the six symbol centres sit at
                // 44 · 91 · 139 · 187 · 234 · 283: five gaps of exactly 48 px.
                // The report is answered; the note is here so nobody "fixes" it
                // a second time from the old sentence in a handout.
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Theme.space6 + Theme.space2
                Layout.preferredHeight: Theme.space6 + Theme.space2
                interactive: true
                active: root.currentIndex === railPill.index

                Icon {
                    // ⚠️ NO `anchors.centerIn` HERE. Pill's inner Item already
                    // centres itself in the pill AND takes its size from
                    // `childrenRect` — anchoring the icon to that parent is a
                    // size that depends on a position that depends on the size.
                    // The fixed square above is what does the centring now.
                    text: railPill.modelData.icon
                    size: Theme.fontSizeLg
                    // ⚠️ A DOOR IS NOT A TAB. Two of the six entries in the quick
                    // panel's rail carry a `page:` and open a different surface
                    // entirely — they can never be the current index, so drawing
                    // them exactly like the four that can was a rail that lied
                    // about its own state. They are dimmed, which is the same
                    // language the rest of the shell uses for "this leads
                    // elsewhere".
                    opacity: railPill.modelData.page === undefined ? 1 : Theme.dimmed
                    color: railPill.active ? Theme.accentFg : Theme.fgMuted
                }

                onClicked: root.activated(railPill.index)

                // Handing the hovered pill up rather than each row owning a
                // tooltip: one tooltip for the whole rail cannot end up with two
                // on screen at once, which is what a per-row one does the moment
                // the pointer crosses between them.
                onHoveredChanged: {
                    if (hovered) {
                        root.hoveredPill = railPill
                        root.hoveredIndex = railPill.index
                    } else if (root.hoveredPill === railPill) {
                        root.hoveredPill = null
                        root.hoveredIndex = -1
                    }
                }
            }
        }
    }

    // ⚠️ TWO PROPERTIES, NOT ONE, AND THE TYPE IS WHY. `hoveredPill` has to be
    // an `Item` because the tooltip positions itself against it — but a property
    // declared as `Item` exposes only Item's own members, so `hoveredPill.index`
    // came back UNDEFINED and the tooltip appeared with no text in it. Measured
    // on screen: the pane was there, the word was not. The index therefore
    // travels on its own rather than being read back off a narrowed type.
    property Item hoveredPill: null
    property int hoveredIndex: -1

    Tooltip {
        target: root.hoveredPill
        // Never an empty box. A pane with no word in it looks like something
        // that failed rather than like a tooltip.
        active: root.hoveredPill !== null && text.length > 0
        text: {
            var e = root.hoveredIndex >= 0 ? root.entries[root.hoveredIndex] : null
            return e ? String(e.tooltip) : ""
        }
    }
}
