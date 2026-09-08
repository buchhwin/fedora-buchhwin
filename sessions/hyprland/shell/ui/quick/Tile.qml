// One switch in the quick settings, with the state it is in written on it.
//
// ⚠️ WIDE, NOT A SMALL SQUARE. The first sketch was a row of icon-sized squares
// with a word under each. Two things were wrong with that: the state was not on
// it — a wifi tile that does not say which network is not answering the question
// anybody opens the panel to ask — and the target was the size of a glyph, which
// is the mistake that had already been found and fixed once in common/Pill.
//
// So: an icon, a name, the current state under the name, and, where there is a
// list behind it, a chevron with a target of its own. Two of these fit side by
// side inside the island's reference width.
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../common"

Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    // What it is doing right now. Empty is allowed and simply leaves the line
    // out rather than reserving a blank one.
    property string subtitle: ""
    property bool active: false
    // ⚠️ NOT `enabled`. Item already has one, and shadowing it made Qt warn
    // that "Member enabled of the object Tile overrides a member of the base
    // object" — the same trap as naming a function `state`. The inherited
    // `enabled` governs input delivery, so overriding it would have changed
    // whether the handlers below fire, quietly and by accident.
    property bool usable: true
    // Does anything open when the chevron is pressed?
    property bool expandable: false
    property bool expanded: false

    signal clicked
    signal expandClicked

    // This tile is the network one, so its symbol comes from
    // common/NetIcon — the single answer the island uses as well. See
    // the note beside the NetIcon below for why this is a flag and not
    // another magic name in the icon string.
    property bool network: false

    implicitHeight: body.implicitHeight + Theme.space3 * 2
    radius: Theme.radiusMd

    color: !root.usable ? Theme.surface
         : root.active ? Theme.accent
         : hover.hovered ? Theme.pillHover
         : Theme.pillBg

    Behavior on color {
        enabled: Theme.animate
        ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
    }

    readonly property color content: !root.usable ? Theme.fgDisabled
                                   : root.active ? Theme.accentFg : Theme.fg

    HoverHandler { id: hover; enabled: root.usable }
    TapHandler {
        enabled: root.usable
        onTapped: root.clicked()
    }

    RowLayout {
        id: body
        anchors.fill: parent
        anchors.margins: Theme.space3
        spacing: Theme.space3

        // ⚠️ THE SYMBOL SITS IN A FILLED CIRCLE — from the reference
        // (2026-08-06/vorlage-control-center.png), and it is not decoration.
        // A bare glyph on an accent-filled tile and the same glyph on a dark
        // one are two different weights of mark, so a row of tiles read as
        // unevenly emphasised even when nothing was. The disc gives every
        // symbol the same footprint whatever the tile is doing.
        //
        // ⚠️ The disc is DARKER on an active tile and LIGHTER on an inactive
        // one — it always steps away from its background rather than always in
        // one direction. On an accent tile a lighter disc would disappear into
        // the accent; on a dark tile a darker one would disappear into the
        // dark. Same idea as the subtitle below, which follows the content
        // colour and loses opacity instead of being a fixed grey.
        Rectangle {
            implicitWidth: Theme.space6
            implicitHeight: Theme.space6
            radius: width / 2      // literal-ok: a circle is half its width
            color: !root.usable ? Theme.surface
                 : root.active ? Theme.accentActive
                 : Theme.surfaceHigh

            Behavior on color {
                enabled: Theme.animate
                ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
            }

            // The colour rule, once, for whichever of the two draws: on a dark
            // disc the symbol carries the accent, which is what makes an off
            // tile still say what colour the desktop is; on an accent tile it
            // goes back to the readable-on-accent colour.
            readonly property color mark: !root.usable ? Theme.fgDisabled
                                        : root.active ? Theme.accentFg
                                        : Theme.accent

            // ⚠️ A DRAWN ICON IS ADDRESSED BY A NAME THAT IS NOT A LIGATURE, and
            // `@wired` is deliberately not a name any font could have — the same
            // trick ui/Shell.qml uses with `@primary`, for the same reason: one
            // state rather than a value plus a flag saying how to read it.
            //
            // It exists because Material Icons Round has no ethernet glyph worth
            // showing; `settings_ethernet` draws `‹···›`, which is what he asked
            // to have taken off the notch. See common/WiredIcon.qml.
            Icon {
                anchors.centerIn: parent
                visible: !root.network && root.icon !== "@wired"
                text: root.icon
                size: Theme.fontSizeLg
                color: parent.mark
            }
            WiredIcon {
                anchors.centerIn: parent
                visible: !root.network && root.icon === "@wired"
                size: Theme.fontSizeLg
                colour: parent.mark
            }
            // ⚠️ B62 · THE NETWORK TILE DRAWS THE SAME SYMBOL THE ISLAND DRAWS.
            // Reported as "das wifi icon ist voll komisch das soll da typische  // english-ok: the report, quoted
            // icon sein das jeder kennt" — and he was right twice over: it was  // english-ok: the report, quoted
            // Material's `wifi` here while the island had been on Fluent since
            // B37, so one desktop was answering one question two ways.
            //
            // ⚠️ A FLAG RATHER THAN ANOTHER `@name` STRING. The `@wired` trick
            // above works because exactly one caller reads it; a second magic
            // name would also have to be understood by the BAR, which draws
            // `Services.Net.icon` too and would have painted the word. A
            // property says which tile this is without changing what the
            // service means.
            NetIcon {
                anchors.centerIn: parent
                visible: root.network
                size: Theme.fontSizeLg
                colour: parent.mark
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0   // literal-ok: absence of a gap — name and state are one
                         // label on two lines, not two separate things

            BarText {
                Layout.fillWidth: true
                text: root.title
                color: root.content
                font.weight: Theme.weightMedium
                elide: Text.ElideRight
            }

            BarText {
                Layout.fillWidth: true
                visible: root.subtitle.length > 0
                text: root.subtitle
                font.pixelSize: Theme.fontSizeSm
                // Dimmed against whatever the tile is: on an accent tile the
                // muted grey would vanish, so it follows the content colour and
                // loses opacity instead.
                color: root.content
                opacity: Theme.dimmed
                elide: Text.ElideRight
            }
        }

        // Its own target rather than a corner of the tile — the whole reason
        // Pill grew a `clicked` signal was a target smaller than the thing that
        // lit up under the pointer.
        Rectangle {
            visible: root.expandable
            implicitWidth: Theme.space5
            implicitHeight: Theme.space5
            radius: Theme.radiusSm
            color: chevHover.hovered ? Theme.pillHover : "transparent"  // literal-ok: absence of colour

            Icon {
                anchors.centerIn: parent
                text: root.expanded ? "expand_less" : "expand_more"
                size: Theme.fontSizeLg
                color: root.content
            }

            HoverHandler { id: chevHover; enabled: root.usable }
            // ⚠️⚠️ `WithinBounds`, AND WITHOUT IT THIS ARROW ALSO FLIPPED THE
            // SWITCH. Reported as "wenn ich auf den pfeil bei wlan oder          // english-ok: the report, quoted
            // bluetooth clicke … es schaltet sich aus und sucht danach es soll   // english-ok: the report, quoted
            // beim pfeil aber nur suchen".                                       // english-ok: the report, quoted
            //
            // A TapHandler's default `gesturePolicy` is `DragThreshold`, which
            // takes a PASSIVE grab: the press keeps travelling, so the handler
            // on the whole tile — the one that toggles the radio — answered the
            // same press. Two things happened from one click, in the order he
            // described: the list opened AND the wifi went off.
            //
            // `WithinBounds` takes an EXCLUSIVE grab on press, so the tile below
            // never sees it. The tile's own handler stays exactly as it was;
            // this is the inner control keeping what belongs to it.
            //
            // ⚠️ THE SAME FAULT WAS IN TWO MORE PLACES with the same shape —
            // play in the island and the icon on a level row. Searched for
            // rather than waited for; tests/nested-taps.sh keeps the pattern
            // shut from now on.
            TapHandler {
                enabled: root.usable
                gesturePolicy: TapHandler.WithinBounds
                onTapped: root.expandClicked()
            }
        }
    }
}
