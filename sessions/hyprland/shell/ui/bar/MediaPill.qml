// The media pill, built to the screenshot: album art, title, play/pause.
//
// Exactly that and no more — no previous/next, no progress bar. The reference
// shows a small pill with the artwork on the left and "lulu. - Mrs. GREEN
// APPLE" beside it, and the one addition asked for was a button to start and
// stop. Anything else would be my idea rather than the specification.
//
// It is not drawn at all when no player is on the bus, rather than shown empty.
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services" as Services
import "../common"

Pill {
    id: root

    visible: Services.Media.available
    interactive: true

    RowLayout {
        spacing: Theme.space2

        // Album art. Rounded like everything else, and clipped rather than
        // scaled to fit, so a non-square cover is not distorted.
        Rectangle {
            implicitWidth: Theme.fontSizeXl
            implicitHeight: Theme.fontSizeXl
            radius: Theme.radiusSm
            color: Theme.surfaceHigh
            clip: true
            visible: Services.Media.artUrl.length > 0

            Image {
                anchors.fill: parent
                source: Services.Media.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }
        }

        BarText {
            text: Services.Media.label
            // A long track title must not push the clock off the bar.
            Layout.maximumWidth: Theme.space6 * 8
            color: Theme.fgMuted
        }

        Icon {
            text: Services.Media.playing ? "pause" : "play_arrow"
            size: Theme.fontSizeLg
            color: Services.Media.canToggle ? Theme.fg : Theme.fgDisabled
        }
    }

    onClicked: if (Services.Media.canToggle) Services.Media.toggle()
}
