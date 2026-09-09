// The media page: what the island becomes when you ask it about music.
//
// Bigger than the bar pill on purpose — this is the expanded form, so it can
// afford the artwork at a readable size and the transport controls the pill
// deliberately leaves out.
//
// ⚠️ A CARD WITH THE ARTWORK BEHIND IT, from the reference
// (2026-08-06/vorlage-control-center.png): the cover fills the whole card, the
// output device sits small along the top, the title and artist sit on it, a
// round button holds the right, and a progress bar with skip buttons runs along
// the bottom.
//
// ⚠️ THE COVER IS DIMMED, NOT BLURRED. A live blur is a full-screen shader pass
// every frame the card is visible, on a laptop, for a decoration — and the
// reference's cover is dark and low-contrast, which a scrim reproduces for the
// cost of one rectangle. Album art is also not chosen to have text read off it,
// so the scrim is doing legibility work rather than only style work.
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../../../theme"
import "../../../services" as Services
import "../../../config"
import "../../common"

// ⚠️⚠️ `ClippingRectangle`, NOT `Rectangle` + `clip: true`, AND THE OLD COMMENT
// HERE WAS WRONG IN A WAY THAT COST HIM A REPORT. It said "the cover is cropped
// to the card, so the corners have to actually cut" — and `clip` cuts to the
// BOUNDING RECTANGLE, never to the radius. So the artwork painted the rounded
// corners back in as square ones, the radius was there and invisible, and he
// asked for what the code already claimed to do: "die ecken abrunden".         // english-ok: the request, quoted
//
// Quickshell.Widgets.ClippingRectangle clips to the border including the
// rounding. Checked in the installed package rather than assumed —
// /usr/lib64/qt6/qml/Quickshell/Widgets/ClippingRectangle.qml — and its own
// documentation says it costs more than a plain Rectangle, which is why it is
// here and not everywhere: this is the one card with a full-bleed image on it.
ClippingRectangle {
    id: root

    implicitWidth: Theme.space6 * 16
    // ⚠️ A FLOOR, NOT THE HEIGHT. The card used to be exactly as tall as its
    // contents, which on the quick panel's media tab left most of the surface
    // empty — "mach den player größer das er perfekt auf die seite passt".      // english-ok: the request, quoted
    // The tab gives it the room now (see QuickPage), and this keeps it from
    // collapsing where nothing does: the island draws the same card on its own.
    implicitHeight: body.implicitHeight + Theme.space4 * 2
    radius: Theme.radiusMd
    color: Theme.surfaceHigh

    // ⚠️ TWO CONDITIONS, AND THE SETTING IS THE SECOND. The reference draws
    // the cover filling the card behind the words, which is right on the dark
    // covers it was drawn from and wrong on a bright one — the scrim below
    // carries a lot of contrast on its own. Off puts the card back to its own
    // surface colour; the cover still exists, it simply is not the background.
    readonly property bool hasArt:
        Services.Media.artUrl.length > 0
        // `media.artworkAsBackground` was cut on 09.09.2026; it shipped on.

    Image {
        anchors.fill: parent
        visible: root.hasArt
        source: Services.Media.artUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        // ⚠️ `sourceSize` — cover art arrives at whatever size the player felt
        // like, and Spotify's is routinely 640×640 where this card is a couple
        // of hundred pixels wide. Without it the full image is decoded and kept
        // in memory to be drawn at a fraction of its size.
        sourceSize.width: root.width
        opacity: Theme.dimmed
    }

    // Always there, art or not: on a card with no cover it is what keeps the
    // surface from being a flat grey rectangle, and with one it is what makes
    // the words readable over whatever the cover happens to be.
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
    }

    // ---------------------------------------------------------------- position
    // ⚠️ THE TIMER LIVES HERE AND IT IS GATED TWICE. `root.visible` is false
    // whenever the media tab is not the one showing, and `playing` is false
    // while the track is paused — so the second the card is off screen or the
    // music stops, this stops. That is the difference between "a bar that
    // updates" and the brightness poll that was deleted for running 21 600
    // times a day to re-read a number nobody had asked for.
    //
    // One second, not sixteen: the bar is a few hundred pixels wide, so a finer
    // interval would redraw the same pixel over and over.
    property real pos: 0
    Timer {
        interval: 1000    // literal-ok: one second, and the comment above is why
        repeat: true
        running: root.visible && Services.Media.playing
                 && Services.Media.positionSupported
        onTriggered: root.pos = Services.Media.position
    }
    // Read once on becoming visible too, or the bar sits at zero for up to a
    // second every time the tab is opened.
    onVisibleChanged: if (visible) root.pos = Services.Media.position

    readonly property real fraction:
        Services.Media.lengthSupported && Services.Media.length > 0
        ? Math.max(0, Math.min(1, root.pos / Services.Media.length)) : 0

    function clock(seconds) {
        if (!(seconds > 0)) return "0:00"
        var s = Math.floor(seconds % 60)
        return Math.floor(seconds / 60) + ":" + (s < 10 ? "0" + s : String(s))
    }

    ColumnLayout {
        id: body
        anchors.fill: parent
        anchors.margins: Theme.space4
        spacing: Theme.space2

        // ------------------------------------------------- the output device
        // Small, along the top, exactly as in the reference — and it earns the
        // line: "why is there no sound" is nearly always "it is going somewhere
        // else", and this is the one place the answer is already on screen.
        RowLayout {
            Layout.fillWidth: true
            visible: Services.Audio.available && Services.Media.available
            spacing: Theme.space2

            Icon { text: "volume_up"; size: Theme.fontSizeSm; color: Theme.fgMuted }

            BarText {
                Layout.fillWidth: true
                // `labelOf`, the same helper the output list uses — a device
                // named one way here and another way in the picker is two
                // names for one thing on one screen.
                text: Services.Audio.sink ? Services.Audio.labelOf(Services.Audio.sink) : ""
                font.pixelSize: Theme.fontSizeSm
                color: Theme.fgMuted
                elide: Text.ElideRight
            }
        }

        // ------------------------------------------------ title, artist, play
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space3

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0   // literal-ok: absence of a gap — title and artist
                             // are one label on two lines, not two things

                BarText {
                    Layout.fillWidth: true
                    text: Services.Media.available ? Services.Media.title
                                                   : "Nothing is playing"
                    font.pixelSize: Theme.fontSizeLg
                    font.weight: Theme.weightSemibold
                    elide: Text.ElideRight
                }

                BarText {
                    Layout.fillWidth: true
                    visible: Services.Media.artist.length > 0
                    text: Services.Media.artist
                    color: Theme.fgMuted
                    elide: Text.ElideRight
                }
            }

            // ⚠️ ROUND, AND BIGGER THAN THE OTHERS. It is the one control on
            // this card anybody reaches for without looking, so it gets the
            // shape and the size that make it findable by feel. `Pill` is
            // already pill-shaped; a fixed square with a pill radius is a
            // circle, which is what the reference draws.
            Pill {
                Layout.alignment: Qt.AlignVCenter
                interactive: Services.Media.canToggle
                visible: Services.Media.available
                implicitWidth: Theme.space6 * 2
                implicitHeight: Theme.space6 * 2

                Icon {
                    text: Services.Media.playing ? "pause" : "play_arrow"
                    size: Theme.fontSizeXl
                }

                onClicked: Services.Media.toggle()
            }
        }

        // ------------------------------------------------------- the progress
        // Hidden entirely when the player will not say where it is, rather than
        // shown empty. A bar that never moves reads as a broken player, and
        // plenty of MPRIS sources genuinely do not report a position.
        RowLayout {
            Layout.fillWidth: true
            visible: Services.Media.available && Services.Media.positionSupported
                     && Services.Media.lengthSupported
            spacing: Theme.space3

            Pill {
                interactive: Services.Media.canPrevious
                Icon { text: "skip_previous"; size: Theme.fontSizeLg }
                onClicked: Services.Media.previous()
            }

            BarText {
                text: root.clock(root.pos)
                font.pixelSize: Theme.fontSizeSm
                color: Theme.fgMuted
            }

            // The same LevelRow the volume uses, in its thin shape and with the
            // symbol left off — a track position IS a level, and a second
            // slider built for it would drift from the first exactly as the
            // second calendar would have.
            LevelRow {
                Layout.fillWidth: true
                value: root.fraction
                live: Services.Media.available
                // No symbol and no percentage: the two clocks either side
                // already say where the track is, and "43 %" of a song is not
                // a number anybody wants.
                showValue: false
                onMoved: function (f) { Services.Media.seek(f) }
                onNudged: function (d) {
                    Services.Media.seek(root.fraction + d / steps)
                }
            }

            BarText {
                text: root.clock(Services.Media.length)
                font.pixelSize: Theme.fontSizeSm
                color: Theme.fgMuted
            }

            Pill {
                interactive: Services.Media.canNext
                Icon { text: "skip_next"; size: Theme.fontSizeLg }
                onClicked: Services.Media.next()
            }
        }
    }
}
