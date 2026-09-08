// The microphone page: whether you are muted, shown at the moment you change it.
//
// ⚠️ THIS EXISTS BECAUSE THE KEY HAD NO ANSWER. XF86AudioMicMute was bound
// straight to `wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle` — the mute worked
// and nothing on screen said so, which on a laptop means finding out mid-call
// by being asked to say it again. Volume and brightness both had a readout;
// this was the one hardware key that answered with silence.
//
// Compact for the same reason VolumePage is: it is glanced at, not read.
import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../services" as Services
import "../../common"

RowLayout {
    id: root

    property bool compact: true

    implicitWidth: Theme.space6 * 8
    spacing: Theme.space3

    Icon {
        text: Services.Audio.micMuted ? "mic_off" : "mic"
        size: Theme.fontSizeXl
        // Muted is not an error, so it is not the error colour — it is simply
        // the quiet state, and the word beside it says which.
        color: Services.Audio.micMuted ? Theme.fgDim : Theme.fg
    }

    BarText {
        Layout.fillWidth: true
        text: !Services.Audio.micAvailable ? "No microphone"
            : Services.Audio.micMuted ? "Microphone muted" : "Microphone on"
        font.weight: Theme.weightMedium
    }
}
