pragma ComponentBehavior: Bound

// The week around today: a letter per day over its date, today spelled out.
//
//     T   F  SAT  S   M
//    30  31   1   2   3
//
// ⚠️ HIS REFERENCE, DESCRIBED IN WORDS because the picture is not there next
// time (rule 11): a near-black upright panel, the day letters dimmed above their
// dates, TODAY carrying its three-letter name instead of one letter, and the
// strip fading out towards both edges rather than ending at a hard border.
//
// ⚠️⚠️ AND TODAY IS A FILLED PILL, NOT JUST BRIGHTER — nachgemeldet after he saw
// the first build: "wenn man auf die notch hovert, dann sieht die tagesanzeige  // english-ok: the report, quoted
// nicht so gut aus wie aufm screenshot". Three shapes were put to him (a pill,  // english-ok: the report, quoted
// a dot underneath, a ring) and he took the pill.
//
// ⚠️ ONE STEP SMALLER THAN THE REST OF THE HOVERED ROW, on his second look:
// "mach links im hover wenn man auf die notch geht die anzeige vom tag etwas    // english-ok: the request, quoted
// kleiner". The clock beside it is what you read; this is what you glance at.   // english-ok: the request, quoted
// `Theme.fontSizeXs` exists for exactly this and has exactly this reader.
//
// ⚠️ THE CELL WIDTH FOLLOWS BY ITSELF, because it is measured from `sizer`
// rather than typed in — which is the whole reason the ruler is there.
//
// ⚠️ IT IS CENTRED ON TODAY, NOT A MONDAY-TO-SUNDAY WEEK, and the reference says
// so plainly: it reads 30 · 31 · 1 · 2 · 3 around a Saturday. A calendar week
// would put the 1st at the end of one row and start a new one; this rolls, so
// today is always in the middle and the month boundary is simply passed over.
// That is why it does not use Clock.mondayFirst — there is no week start here to
// get wrong.
//
// ⚠️ THE FADE IS OPACITY PER COLUMN, not a mask. An OpacityMask needs
// Qt5Compat.GraphicalEffects, which is a dependency for a gradient — and a
// shader over seven labels is work the GPU does every frame on a machine this
// project exists to be gentle to. Distance from the centre is the same picture
// for nothing.
//
// ⚠️ AND IT IS LIVE, which he asked for in as many words: "der muss auch immer   // english-ok: the request, quoted
// aktuell sein also nicht statisch". Everything here hangs off `now`, which the  // english-ok: the request, quoted
// island already drives from the one SystemClock — so midnight moves the
// highlight along without anything here owning a timer.
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../common"

RowLayout {
    id: root

    // The moment to draw. Passed in rather than read here: two clocks on one
    // screen can disagree by a minute, and the island already owns the one.
    property var now: null

    // How many days either side of today. Three gives the seven columns of the
    // reference, of which the outermost pair is nearly faded out.
    readonly property int reach: 3

    // ⚠️⚠️ EVERY COLUMN IS THE SAME WIDTH, AND IT IS NOT COSMETIC. Today carries
    // a THREE-letter name and every other day carries one, so columns sized by
    // their contents are all different widths — and at midnight the wide one
    // moves to the next column and the whole strip shuffles sideways. That is
    // rule 7's "what decides the layout comes from the content" in its purest
    // form, and this file would have hit it exactly once a day.
    //
    // Sized from the widest thing a column can hold — a three-letter weekday at
    // the small size — measured once by the hidden text below rather than typed
    // in as a number, so a font change carries it.
    readonly property real cellWidth: sizer.implicitWidth + Theme.space2

    BarText {
        id: sizer
        visible: false
        // The widest three-letter day name is what has to fit. "WED" in most
        // locales, but it is not ours to guess — Qt's own short name for a
        // Wednesday, upper-cased the way the real ones are.
        text: root.now ? Qt.formatDate(new Date(2026, 0, 7), "ddd").toUpperCase()
                       : "WWW"
        font.pixelSize: Theme.fontSizeXs
        font.weight: Theme.weightSemibold
    }

    spacing: Theme.space1

    Repeater {
        model: root.reach * 2 + 1

        // ⚠️ AN Item, NOT A ColumnLayout, AND THAT IS NOT A STYLE CHOICE. The
        // pill has to sit BEHIND the two labels and fill the cell, which means
        // anchors — and anchors on a direct child of a Layout are refused by
        // QML with "Cannot specify anchors for items inside Layout". So the
        // cell is a plain Item the layout sizes, and everything inside it
        // anchors freely.
        Item {
            id: col
            required property int index

            // -3 … 0 … +3, where 0 is today.
            readonly property int offset: col.index - root.reach

            readonly property var day: {
                if (!root.now)
                    return null
                // ⚠️ A COPY, THEN setDate. Date is mutable in JS and `now` is
                // shared with the clock beside this — advancing it in place
                // would move the time the island is showing.
                //
                // ⚠️ AND setDate CARRIES ACROSS MONTHS AND YEARS on its own:
                // day 0 is the last of the previous month, day 32 of a 31-day
                // month is the 1st of the next. That is exactly the roll the
                // reference shows, and doing the arithmetic by hand is how it
                // would be got wrong in February.
                var d = new Date(root.now.getTime())
                d.setDate(d.getDate() + col.offset)
                return d
            }

            readonly property bool today: col.offset === 0

            Layout.preferredWidth: root.cellWidth
            Layout.preferredHeight: stack.implicitHeight + Theme.space2

            // Fading at the edges, full in the middle. Not a hard cut: the
            // reference fades, and a strip that simply stops looks clipped.
            //
            // ⚠️⚠️ IT USED TO FADE TO 0.15, WHICH IS NOT READABLE, and he said
            // so: "die textfarbe von hover auf der notch beim tag … muss heller  // english-ok: the report, quoted
            // werden damit man den text besser lesen kann". The far column was   // english-ok: the report, quoted
            // a decoration on a surface whose whole job is to be read at a
            // glance.
            //
            // ⚠️ THE FADE STAYS — the argument above for it is still right, and
            // removing it would trade one complaint for another. What changes is
            // where it ends: `Theme.faded` is the floor, and the step per column
            // comes off the same scale instead of being a typed 0.1. Two numbers
            // in a formula are still two numbers nobody can tune from one place.
            opacity: col.today
                     ? 1
                     : Math.max(Theme.faded,
                                1 - Math.abs(col.offset) * (1 - Theme.dimmed) / 3)

            // ⚠️⚠️ A FILLED PILL IN THE ACCENT COLOUR, AND IT IS HIS CHOICE OF
            // THREE. What was built first was "brighter and bolder", and he saw  // english-ok: the earlier build, described
            // it and said so: "wenn man auf die notch hovert, dann sieht die     // english-ok: the report, quoted
            // tagesanzeige nicht so gut aus wie aufm screenshot". Offered a      // english-ok: the report, quoted
            // pill, a dot underneath and a ring, he took the pill — the loudest
            // of the three, which is the right answer for the one thing on this
            // strip you are actually looking for.
            //
            // ⚠️ IT DECIDES NOTHING ABOUT THE LAYOUT. It fills a cell whose size
            // comes from `cellWidth` and from the labels, so the highlight can
            // move to another column at midnight without anything resizing.
            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusPill
                color: Theme.accent
                visible: col.today
            }

            ColumnLayout {
                id: stack
                anchors.centerIn: parent
                width: parent.width
                spacing: 0   // literal-ok: the letter and its date are one label
                             // on two lines, as in the reference

                BarText {
                    Layout.alignment: Qt.AlignHCenter
                    // ⚠️ THREE LETTERS FOR TODAY, ONE FOR THE REST. It is what
                    // the reference uses to say which day it is; the pill behind
                    // it is what he asked for on top of that. `ddd` is Qt's own
                    // short day name, so it follows the system locale rather
                    // than a hand-written list of seven strings.
                    text: col.day === null ? ""
                        : col.today ? Qt.formatDate(col.day, "ddd").toUpperCase()
                                    : Qt.formatDate(col.day, "ddd").charAt(0)
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: col.today ? Theme.weightSemibold : Theme.weightNormal
                    // Dark on the accent, the same pair Dropdown uses for a
                    // chosen entry. The accent is a light colour in every
                    // palette, so Theme.fg on it would be the invisible pairing
                    // tests/contrast.sh exists to catch.
                    color: col.today ? Theme.accentFg : Theme.fgMuted
                }

                BarText {
                    Layout.alignment: Qt.AlignHCenter
                    text: col.day === null ? "" : String(col.day.getDate())
                    font.pixelSize: Theme.fontSizeSm
                    font.weight: col.today ? Theme.weightSemibold : Theme.weightNormal
                    color: col.today ? Theme.accentFg : Theme.fgDim
                }
            }
        }
    }
}
