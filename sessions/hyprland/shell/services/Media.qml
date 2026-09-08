pragma Singleton

// The player you are actually listening to, or the honest absence of one.
//
// MPRIS reports every player on the bus, including ones that are merely open.
// Picking "the first" gives you a browser tab that has been paused since
// Tuesday. So the choice is: a playing player wins; otherwise the last one that
// played; otherwise nothing at all — and `available` false means the media pill
// is not drawn, rather than drawn empty.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../config"

Singleton {
    id: root

    property var player: null
    readonly property bool available: player !== null

    readonly property string title: available ? player.trackTitle : ""
    readonly property string artist: available ? player.trackArtist : ""
    readonly property string artUrl: available ? player.trackArtUrl : ""
    readonly property bool playing: available && player.isPlaying
    readonly property bool canToggle: available && player.canTogglePlaying

    // "lulu. - Mrs. GREEN APPLE" — title first, then artist, as in the
    // reference screenshot.
    readonly property string label: {
        if (!available) return ""
        if (title.length && artist.length) return title + " - " + artist
        return title.length ? title : artist
    }

    readonly property bool canNext: available && player.canGoNext
    readonly property bool canPrevious: available && player.canGoPrevious

    // ───────────────────────────────────────────────── where we are in the track
    // Read from the type description on the machine rather than from memory
    // (Quickshell/Services/Mpris/quickshell-service-mpris.qmltypes): `position`
    // is a read/write double with a `positionChanged` notify, `length` is
    // read-only, and each has its own `…Supported` flag because plenty of
    // players implement neither.
    //
    // ⚠️ NOTHING POLLS THIS HERE, and that is the whole design. A progress bar
    // wants a new number every second, and a service that fetched one every
    // second would be doing it for the twenty-three hours a day nobody is
    // looking at it — the same idle work the brightness poll was deleted for.
    // So the service only exposes the values; whichever surface DRAWS the bar
    // owns the timer and runs it while it is on screen and the track is moving.
    // See MediaPage.qml, which states the same rule from the other side.
    readonly property bool positionSupported: available && player.positionSupported
    readonly property bool lengthSupported: available && player.lengthSupported
    readonly property real position: available ? player.position : 0
    readonly property real length: available ? player.length : 0
    readonly property bool canSeek: available && player.canSeek

    // 0..1, and 0 when there is nothing to divide by — a bar that jumps to full
    // because the length came back as zero is worse than one that stays empty.
    readonly property real progress:
        root.positionSupported && root.lengthSupported && root.length > 0
        ? Math.max(0, Math.min(1, root.position / root.length)) : 0

    function seek(f) {
        if (!root.canSeek || root.length <= 0) return
        root.player.position = Math.max(0, Math.min(1, f)) * root.length
    }

    function next() { if (root.canNext) root.player.next() }
    function previous() { if (root.canPrevious) root.player.previous() }

    function toggle() {
        if (!available || !player.canTogglePlaying) return
        if (player.isPlaying) player.pause()
        else player.play()
    }

    function pick() {
        var list = Mpris.players ? Mpris.players.values : null
        if (!list || !list.length) { root.player = null; return }

        // ⚠️ A NAMED PREFERENCE WINS OVER "WHATEVER IS PLAYING", and it has to.
        // Anyone with a browser open has a second MPRIS player that starts
        // playing whenever a page decides to — so without this the pill jumps
        // from the music to an advert and back. Matched loosely against the
        // player's own identity, because that is the string a person can
        // actually type: "Spotify", "Brave".
        var want = Config.media ? String(Config.media.preferredPlayer).trim().toLowerCase() : ""
        if (want.length > 0) {
            for (var w = 0; w < list.length; w++) {
                var c = list[w]
                if (!c) continue
                var id = String(c.identity || "").toLowerCase()
                if (id.length > 0 && id.indexOf(want) >= 0) { root.player = c; return }
            }
            // Named and not here: fall through rather than showing nothing. A
            // preference is a preference, not a filter — a player that is not
            // running should not silence the one that is.
        }

        var fallback = null
        for (var i = 0; i < list.length; i++) {
            var p = list[i]
            if (!p) continue
            if (p.isPlaying) { root.player = p; return }
            if (!fallback) fallback = p
        }
        // Keep the current one if it is still on the bus: a pause should not
        // make the pill jump to a different application.
        for (var j = 0; j < list.length; j++)
            if (list[j] === root.player) return
        root.player = fallback
    }

    Component.onCompleted: pick()

    Connections {
        target: Mpris.players
        function onValuesChanged() { root.pick() }
    }

    // A player that starts playing takes over; one that stops hands back.
    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onIsPlayingChanged() { root.pick() }
    }
}
