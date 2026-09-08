// The volume page: what the notch becomes while you are changing the volume.
//
// Laid out from the reference screenshot: speaker on the left, a track that
// fills, the percentage on the right — a small dark pill, and nothing more.
//
// ⚠️ It declares itself COMPACT, and that is the whole point of the flag. The
// island's reference geometry (619 × 135, from the settings screenshot) belongs
// to pages you READ. Forced onto a volume readout it produced a slab covering a
// sixth of the screen for three pieces of information. A page you GLANCE at is
// as small as its contents.
import QtQuick
import "../../../theme"
import "../../../ipc"
import "../../../services" as Services
import "../../common"

LevelRow {
    id: root

    // Read by NotchContent. See the comment there for what it changes.
    property bool compact: true

    implicitWidth: Theme.space6 * 8

    icon: Services.Audio.muted ? "volume_off"
        : Services.Audio.volume > 0.5 ? "volume_up" : "volume_down"
    value: Services.Audio.volume
    live: !Services.Audio.muted

    onMoved: function (f) { if (Services.Audio.available) Services.Audio.setVolume(f) }

    // 5 % a notch — the same amount the hardware keys use. The same gesture
    // must not mean two different things depending on how it was made.
    onNudged: function (dir) {
        if (!Services.Audio.available)
            return
        Services.Audio.setVolume(Math.max(0, Math.min(1, Services.Audio.volume + dir / root.steps)))
        // Keep the page up while the wheel is turning: it closes itself after a
        // moment, and vanishing mid-gesture is what makes an OSD feel like it is
        // fighting you.
        Ipc.show("volume")
    }
}
