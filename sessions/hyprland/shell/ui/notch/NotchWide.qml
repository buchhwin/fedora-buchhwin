// The notch with the pointer on it: what is playing, what time it is, and how
// the machine is doing.
//
// Straight from the reference screenshot
// (shots/2026-08-06/vorlage-notch-ausgefahren.png): a square of album art with
// the title and artist beside it on the LEFT, the time large with the date
// small under it in the MIDDLE, and a rounded pill on the RIGHT holding the
// network and battery icons in the accent colour.
//
// ⚠️ NOTHING IN HERE ANSWERS A CLICK, ON PURPOSE. There was once a status pill
// that was the only way to open the quick panel; the brief that replaced it is
// "wenn man auf die Notch gehovert hat, soll es egal sein, wo man in dem          english-ok: quoted brief
// Fenster hinklickt — das Quick-Panel soll immer aufgehen". A row of readouts    english-ok: quoted brief
// with its own tap target inside a shape that already answers everywhere is a
// smaller target inside a bigger one doing the same thing, so the handler lives
// on the island instead — surface/ShellSurface.qml. Anything added here that
// takes a click takes it AWAY from the whole-notch gesture.
//
// ⚠️ NOTHING EMPTY IS DRAWN. No player means no artwork and no title, not a
// placeholder; no timer means no timer; a machine with no battery shows no
// battery. The shape is sized from what survives that, so a quiet desktop gets
// a smaller notch rather than a wide one full of nothing.
//
// ⚠️ AND THE ARTWORK IS LOADED AT THE SIZE IT IS DRAWN. `sourceSize` on a cover
// that arrives as a 1400 px JPEG is the difference between one thumbnail and a
// full-resolution decode every time a track changes.

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../config"
import "../../ipc"
import "../../services" as Services
import "../common"
import "../../common"

Item {
    id: root

    // The clock is handed in rather than read again: NotchContent already has
    // one SystemClock, and two of them on one screen can disagree by a minute
    // at the wrong moment.
    //
    // ⚠️ THE WHOLE DATE, not the hour and the minute. It used to be two ints,
    // and the date line underneath had to fake a dependency on `minutes` to be
    // rebuilt at all — a `new Date()` with nothing to depend on is evaluated
    // once and then shows yesterday until the shell restarts. One Date is the
    // dependency, so the trick is gone with the thing that needed it.
    property var now: null

    // ⚠️ ANCHORS, NOT A ROW LAYOUT, and it is the clock that decides it. In a
    // row the middle column sits wherever the two beside it leave room — so with
    // nothing playing the clock drifted off centre (measured: shape centre 960,
    // clock centre 930), and it would move again the moment a track started.
    // The reference has the time in the MIDDLE of the shape, full stop.
    //
    // So the three groups are anchored — left, centre, right — and the width is
    // computed to keep the centre actually central: whichever side is wider sets
    // the margin on BOTH sides. That is what makes the clock hold still while
    // music starts and stops.
    // ⚠️⚠️ THE BATTERY LANDED ON TOP OF THE CLOCK, and this is why. The three
    // groups are anchored independently — media on the left, the clock on the
    // horizontal centre, the status on the right — so nothing STOPS them from
    // overlapping; the only thing keeping them apart is this width being big
    // enough. It was, until upower started answering and the right-hand group
    // grew by a battery icon and a percentage on a machine that had never shown
    // one. He saw it within minutes.
    //
    // ⚠️ `Math.ceil` and the extra gap are not decoration: implicit widths of
    // text are fractional, and half a pixel short on each side is exactly the
    // kind of overlap that only appears with certain content — which is the
    // worst kind to hunt.
    // ⚠️⚠️ THE LEFT SLOT HOLDS ONE OF TWO THINGS NOW, and only one is ever
    // visible — so the width has to ask WHICH, not take the larger. An invisible
    // RowLayout still reports an implicit width, and `max` over both would
    // reserve room for a media card that is not on screen.
    readonly property real leftWidth: media.visible ? media.implicitWidth
                                                    : week.implicitWidth
    readonly property real sideWidth: Math.ceil(Math.max(root.leftWidth,
                                                         right.implicitWidth))
    implicitWidth: root.sideWidth * 2 + centre.implicitWidth + Theme.space5 * 3
    implicitHeight: Math.max(media.implicitHeight, week.implicitHeight,
                             centre.implicitHeight, right.implicitHeight)

    // ------------------------------------------------------------- the week
    // ⚠️⚠️ THIS IS WHAT USED TO BE THE MEDIA CARD. His instruction: "kannst du    // english-ok: the request, quoted
    // links das medien dings mit sowas wie im screenshot austauschen also ne     // english-ok: the request, quoted
    // uhr und drunter der wochentag".                                            // english-ok: the request, quoted
    //
    // ⚠️ AND ONLY THE WEEK, NOT A SECOND CLOCK, although his reference shows a
    // time above the strip. The time is already here — bigger, and in the middle
    // where the reference for this whole shape puts it. Two clocks in one pill
    // is the noise he himself argued against when the notch was cut down to one
    // monitor: "es gibt für fast alles eh hotkey".                               // english-ok: his words, quoted
    //
    // The distinctive half of his picture is the strip, and that is what moved.
    WeekStrip {
        id: week
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        // ⚠️ ALWAYS THERE NOW. It used to stand down whenever the media card
        // took this slot; the card moved to the right on his instruction, so
        // there is nothing left to yield to and the strip is simply the left
        // half of the hovered row.
        now: root.now
    }

    // ------------------------------------------------------------ clock, date
    ColumnLayout {
        id: centre
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0   // literal-ok: absence of a gap — the time and its date are
                     // one label on two lines

        BarText {
            Layout.alignment: Qt.AlignHCenter
            font.pixelSize: Theme.fontSizeXl
            font.weight: Theme.weightSemibold
            color: Theme.fg
            text: Clock.time(root.now)
        }

        BarText {
            Layout.alignment: Qt.AlignHCenter
            font.pixelSize: Theme.fontSizeSm
            color: Theme.fgMuted
            // The SHORT form: this is a pill, not a screen. The lock screen's
            // long form is a separate setting for that reason.
            text: Clock.dateShort(root.now)
        }
    }

    // --------------------------------------------------------- timer + pill
    RowLayout {
        id: right
        // ⚠️ RIGHT-ALIGNED, BUT INSIDE A ROW THAT RESERVES ITS WIDTH — see the
        // note beside `centre`. Anchoring it to the parent's right edge is what
        // let it grow into the clock the moment a battery reading appeared.
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space3

        // Only while one is running or has just rung. This is what the separate
        // pill beside the notch used to be — it lives in here now, so a hover
        // shows everything at once instead of two surfaces appearing side by
        // side.
        RowLayout {
            visible: Services.Countdown.active || Services.Countdown.rang
            spacing: Theme.space1
            Layout.alignment: Qt.AlignVCenter

            Icon {
                text: "timer"
                size: Theme.fontSize
                color: Services.Countdown.rang ? Theme.warn : Theme.fgMuted
            }
            BarText {
                text: Services.Countdown.label
                font.pixelSize: Theme.fontSize
                color: Services.Countdown.rang ? Theme.warn : Theme.fg
            }
        }

    // ------------------------------------------------------------------ media
    // ⚠️ ALWAYS, WHENEVER SOMETHING IS PLAYING. `media.showInIsland` was cut
    // with the Media page on 09.09.2026, and this is the value it actually
    // shipped as: `true`. The comment that stood here said "off by default",
    // which had been untrue since the schema was last changed — a note that
    // contradicts the file three lines below it is worse than none, and it is
    // recorded here rather than quietly corrected.
        RowLayout {
            id: media
            Layout.alignment: Qt.AlignVCenter
            visible: Services.Media.available
            spacing: Theme.space2

            // ⚠️⚠️ A FIXED WIDTH, AND IT IS THE REAL WORK OF MOVING THIS. A card
            // that is as wide as its title is a surface sized by its CONTENTS —
            // rule 7's own example — and here it would push the status symbols
            // sideways every time a track changed. That is precisely the
            // "everything wobbles from left to right" this shell has already
            // paid for once. On the left it did not matter, because nothing sat
            // beyond it; on the right everything does.
            //
            // ⚠️⚠️ AND FOR A WHILE THIS PARAGRAPH WAS THE ONLY THING HOLDING IT.
            // `Layout.preferredWidth` is a WISH, not a bound: a layout never goes
            // below the sum of its children's minimums, so a long title simply
            // won and the block grew anyway. He reported exactly the failure the
            // paragraph describes — "je nach dem wie lang der text ist im hover   // english-ok: the report, quoted
            // über der notch ist der play button dast bei den icons".             // english-ok: the report, quoted
            //
            // A comment that argues for the right thing beside code that does not
            // do it is worse than no comment: it is read, believed, and stops
            // anybody from looking. So the wish is a LIMIT now — the same number
            // as a maximum — and the title is allowed to shrink inside it, which
            // is what finally lets its `elide` do anything.
            Layout.preferredWidth: Theme.space6 * 8
            Layout.maximumWidth: Theme.space6 * 8

            Rectangle {
                implicitWidth: Theme.space6 * 2
                implicitHeight: Theme.space6 * 2
                radius: Theme.radiusSm
                color: Theme.surface
                clip: true

                Image {
                    anchors.fill: parent
                    source: Services.Media.artUrl
                    sourceSize.width: parent.width
                    sourceSize.height: parent.height
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: Services.Media.artUrl.length > 0
                }

                Icon {
                    anchors.centerIn: parent
                    visible: Services.Media.artUrl.length === 0
                    text: "music_note"
                    size: Theme.fontSizeLg
                    color: Theme.fgDim
                }
            }

            ColumnLayout {
                spacing: 0   // literal-ok: absence of a gap — title and artist are
                             // one label on two lines, not two things
                Layout.alignment: Qt.AlignVCenter
                // ⚠️ THE ONE THAT IS ALLOWED TO SHRINK. Without this the texts
                // keep their full implicit width, the row's minimum is that
                // width, and the maximum above can never be honoured — the
                // block grows and the status symbols move. `elide` only ever
                // runs on a label that was actually made narrower.
                Layout.fillWidth: true

                RowLayout {
                    spacing: Theme.space1
                    Icon {
                        text: "graphic_eq"
                        size: Theme.fontSizeSm
                        color: Theme.accent
                        visible: Services.Media.playing
                    }
                    BarText {
                        text: Services.Media.title
                        font.pixelSize: Theme.fontSize
                        font.weight: Theme.weightSemibold
                        elide: Text.ElideRight
                        Layout.maximumWidth: Theme.space6 * 5
                    }
                }

                BarText {
                    text: Services.Media.artist
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.fgMuted
                    elide: Text.ElideRight
                    visible: text.length > 0
                    Layout.maximumWidth: Theme.space6 * 5
                }
            }

            // ⚠️ PLAY/PAUSE, AND IT IS WHAT HE ASKED FOR ALONGSIDE THE MOVE:
            // "soll rechts neben de[m] medi[en] play sein hinkommen der davor    // english-ok: the request, quoted
            // links war". The glyph pair is the one pages/MediaPage.qml:168      // english-ok: the request, quoted
            // already uses, so it is measured and in Material Icons Round.
            //
            // ⚠️ ITS OWN TAP, INSIDE A SURFACE WHOSE WHOLE ISLAND ALSO ANSWERS.
            // The island's handler opens the quick panel; this one must not do
            // both, so it takes the press. That is the opposite arrangement to
            // the settings rows — there the ROW is the only writer because it is
            // bigger; here the button is the smaller, more specific meaning.
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Theme.space6
                implicitHeight: Theme.space6
                radius: width / 2   // literal-ok: a circle is half its width
                color: playHover.hovered ? Theme.surfaceHigh : "transparent"   // literal-ok: absence of colour

                Behavior on color {
                    enabled: Theme.animate
                    ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                }

                HoverHandler { id: playHover; cursorShape: Qt.PointingHandCursor }
                // ⚠️⚠️ `WithinBounds`, OR THIS BUTTON OPENS THE QUICK PANEL TOO.
                // Reported as "wenn ich im hover auf der notch bin und im       // english-ok: the report, quoted
                // medien player auf play drücke öffnet sich das quickpanel es   // english-ok: the report, quoted
                // soll aber nur die aktion vom playbutton machen".              // english-ok: the report, quoted
                //
                // The island carries a TapHandler over its whole shape — his own
                // instruction, "es soll egal sein, wo man in dem Fenster  // english-ok: the instruction, quoted
                // hinklickt" — and a TapHandler's default grab is passive, so
                // the press reached both. The outer one is right and stays; this
                // one takes an exclusive grab so the press stops here.
                //
                // Same fault, same fix, in ui/quick/Tile.qml and
                // ui/common/LevelRow.qml. tests/nested-taps.sh guards all three.
                TapHandler {
                    gesturePolicy: TapHandler.WithinBounds
                    onTapped: Services.Media.toggle()
                }

                Icon {
                    anchors.centerIn: parent
                    text: Services.Media.playing ? "pause" : "play_arrow"
                    size: Theme.fontSizeLg
                    color: Theme.accent
                }
            }
        }

        // ----------------------------------------------------------- status
        // ⚠️ THIS WAS A PILL AND IT IS NOT ANY MORE — his decision, and it wins
        // twice. The pill was "the one thing on the notch that answers a
        // click"; now the WHOLE hovered notch answers, so a button inside it
        // was a smaller target inside a bigger one that does the same thing.
        // Dropping it also gives back its padding, which is width this row did
        // not have to spare — see the layout note at the top.
        // ⚠️ THE SPACING HERE WAS NOT A TOKEN. The network group used to sit in
        // a wrapper of its own carrying `Theme.space2`, while the battery was a
        // sibling one level up — so the gap between the two was RowLayout's
        // built-in default, not a value from the theme. Nothing catches that:
        // no-literals.sh looks for numbers that were written down, and this one
        // never was. The wrapper held exactly one child, so removing it puts
        // both groups on the same token.
        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.space2

            RowLayout {
                spacing: Theme.space1
                visible: Services.Net.available

                // ⚠️⚠️ FLUENT HERE, MATERIAL EVERYWHERE ELSE — B37, and the
                // scope is his: "nimm bitte die windows symbole her, das ist     // english-ok: the report, quoted
                // echt kacke", narrowed on being asked to WLAN, Ethernet and
                // battery only. The real Windows font is Segoe Fluent Icons and
                // may not be redistributed; this is Microsoft's own open set
                // under MIT. See docs/CREDITS.md and common/FluentIcon.qml.
                //
                // ⚠️ WHAT THIS REPLACES WAS DRAWN BY HAND, AND FOR GOOD REASON
                // AT THE TIME. common/SignalBars.qml and common/WiredIcon.qml
                // exist because Material Icons Round has no graded wifi glyph
                // and no ethernet glyph anybody recognises — both files carry
                // the measured list of names that are not in it. Fluent has
                // both, so the drawings are no longer the only way.
                //
                // ⚠️⚠️ AND THE WIFI GRADES ARE NUMBERED THE OTHER WAY ROUND.
                // Rendered and looked at rather than inferred from the names:
                // `wifi_1` is the FULL symbol and `wifi_4` is a single dot. A
                // reading of "level 1 is one bar" would have shown a strong
                // signal as almost nothing, on every machine, and looked like a
                // driver problem rather than an off-by-one.
                // ⚠️ B62 · ONE COMPONENT, TWO CALLERS. This block used to
                // carry the wired glyph, the four wifi grades and the Material
                // fallback inline — and the quick panel's tile drew Material's
                // `wifi` for the same state, which he reported as "das wifi     // english-ok: the report, quoted
                // icon ist voll komisch". Two answers to one question is the    // english-ok: the report, quoted
                // drift this project checks for everywhere else, so the drawing
                // moved to common/NetIcon.qml and both sides ask it.
                //
                // ⚠️ The measured facts went with it, not away: the grades are
                // numbered the other way round (`wifi_1` is FULL), and anything
                // that is neither wired nor wifi keeps the Material glyph the
                // service names.
                NetIcon {
                    size: Theme.fontSize
                    colour: Theme.accent
                }
            }

            RowLayout {
                id: batteryRow
                spacing: Theme.space1
                visible: Services.Power.available
                // ⚠️ CHARGING IS ITS OWN GLYPH, and the rest is a level. The
                // Material version had exactly two states — full or charging —
                // so a battery at 20% looked the same as one at 100%.
                //
                // ⚠️⚠️ A TABLE, NOT ARITHMETIC, AND THE ARITHMETIC WAS WRITTEN
                // FIRST AND WAS WRONG. `battery_0` … `battery_9` really are two
                // code points apart, so `0xF1BC + step * 2` looks right and
                // survives nine of eleven cases — but `battery_10` is U+E144,
                // nowhere near the others, and U+F1D0 (where the sum lands) is
                // `battery_charge`. A full battery would have drawn the charging
                // symbol. Found by asking the font's own map instead of trusting
                // a pattern that held for the cases that were easy to check.
                readonly property var batterySteps: [
                    "\uF1BC", "\uF1BE", "\uF1C0", "\uF1C2", "\uF1C4", "\uF1C6",
                    "\uF1C8", "\uF1CA", "\uF1CC", "\uF1CE", "\uE144"
                ]   // literal-ok: glyph points, read out of the font's own name map

                FluentIcon {
                    text: {
                        if (Services.Power.charging)
                            return "\uF1D0"    // literal-ok: battery_charge
                        var step = Math.max(0, Math.min(10,
                                   Math.round(Services.Power.percent / 10)))
                        return batteryRow.batterySteps[step]
                    }
                    size: Theme.fontSize
                    // Accent is the resting colour here — the pill is the accent
                    // element on the reference. A battery in trouble still
                    // outranks it, because that is the one time the colour is
                    // carrying information rather than style.
                    color: Services.Power.critical ? Theme.error
                         : Services.Power.low ? Theme.warn
                         : Theme.accent
                }
                BarText {
                    text: Math.round(Services.Power.percent) + "%"
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.accent
                }
            }

            // An `expand_more` chevron used to sit here, shown only when the
            // machine had neither network nor battery, so that the hovered
            // notch was not empty on such a machine. Taken out: hovering the
            // notch is how you got here, so nothing needs to say it can be
            // opened.
            //
            // ⚠️⚠️ IT IS NOT WHAT HE COMPLAINED ABOUT, and the first version of
            // this comment said it was — which would have sent the next reader
            // to the wrong element. His report was "wenn man auf die notch      // english-ok: his report, quoted
            // hovert ist da recht auch ein komisches symol". The symbol he saw  // english-ok: his report, quoted
            // is the WIRED NETWORK icon a few lines above: `settings_ethernet`,
            // which Material Icons Round draws as `‹···›`. Photographed at the
            // notch, magnified, and then found again on the Network tile in the
            // quick panel — the same glyph in the same accent colour.
            //
            // The chevron could never have been it: its own condition is
            // `!Net.available && !Power.available`, and his laptop has both.
        }
    }
}
