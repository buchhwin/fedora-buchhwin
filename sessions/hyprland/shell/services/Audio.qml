pragma Singleton

// Sound: the output, the input, the devices behind both, and a level for every
// program making noise.
//
// The test VM has no audio hardware at all — Pipewire reports zero nodes — so
// `available` false is the normal state there, not a fault. A bar that renders
// a volume symbol on a machine with no sound card is lying.
//
// ⚠️ PwObjectTracker IS NOT OPTIONAL. Without it a node's volume and mute stay
// unbound and the value read is whatever it was when the object appeared. That
// is the classic Pipewire mistake, and it is why the tracker below takes a LIST
// that grows with what is on screen: every node whose level is displayed has to
// be in it, or its slider shows a frozen number and moves nothing.
//
// ⚠️ AND IT IS ONLY WHAT IS ON SCREEN. Binding every node in the graph would
// hold objects nobody is looking at, all session, on a battery. The panel calls
// watch(true) when the sound section opens and watch(false) when it closes; the
// default output and input stay bound always, because the bar shows one and the
// volume keys move the other with every panel shut.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property bool fake: !!Quickshell.env("BUCHHWIN_SHELL_FAKE")

    // ------------------------------------------------------------ the output
    readonly property var sink: root.fake ? null : Pipewire.defaultAudioSink
    readonly property bool available:
        root.fake || (Pipewire.ready && root.sink !== null && root.sink.ready)

    readonly property real volume: root.fake ? root._fakeVolume
        : root.available && root.sink.audio ? root.sink.audio.volume : 0
    readonly property bool muted: root.fake ? root._fakeMuted
        : root.available && root.sink.audio ? root.sink.audio.muted : true

    function setVolume(v) {
        if (root.fake) {
            root._fakeVolume = Math.max(0, Math.min(1, v))
            return
        }
        if (!root.available || !root.sink.audio) return
        root.sink.audio.volume = Math.max(0, Math.min(1, v))
    }

    function toggleMute() {
        if (root.fake) {
            root._fakeMuted = !root._fakeMuted
            return
        }
        if (!root.available || !root.sink.audio) return
        root.sink.audio.muted = !root.sink.audio.muted
    }

    // ------------------------------------------------------------- the input
    //
    // The microphone key went straight to `wpctl` and nothing displayed the
    // result, so the only way to find out whether you were muted was to talk
    // and be asked to say it again.
    readonly property var source: root.fake ? null : Pipewire.defaultAudioSource
    readonly property bool micAvailable:
        root.fake || (Pipewire.ready && root.source !== null && root.source.ready)

    readonly property bool micMuted: root.fake ? root._fakeMicMuted
        : root.micAvailable && root.source.audio ? root.source.audio.muted : true
    readonly property real micVolume: root.fake ? root._fakeMicVolume
        : root.micAvailable && root.source.audio ? root.source.audio.volume : 0

    function toggleMicMute() {
        if (root.fake) {
            root._fakeMicMuted = !root._fakeMicMuted
            return
        }
        if (!root.micAvailable || !root.source.audio) return
        root.source.audio.muted = !root.source.audio.muted
    }

    function setMicVolume(v) {
        if (root.fake) {
            root._fakeMicVolume = Math.max(0, Math.min(1, v))
            return
        }
        if (!root.micAvailable || !root.source.audio) return
        root.source.audio.volume = Math.max(0, Math.min(1, v))
    }

    // ----------------------------------------------------------- the devices
    //
    // ⚠️ `isSink && !isStream`, and the second half is the one that matters. A
    // stream is a program's own connection into the graph, and a playback
    // stream IS a sink as far as the graph is concerned — so without it every
    // open media player turns up in the list of speakers to choose from.
    readonly property var outputs: root.fake ? root._fakeOutputs : root.collect(true, false)
    readonly property var inputs: root.fake ? root._fakeInputs : root.collect(false, false)
    readonly property var streams: root.fake ? root._fakeStreams : root.collect(true, true)

    function collect(sinkSide, streamSide) {
        var raw = Pipewire.nodes ? Pipewire.nodes.values : []
        var out = []
        for (var i = 0; i < raw.length; i++) {
            var n = raw[i]
            if (!n.ready || n.isSink !== sinkSide || n.isStream !== streamSide) continue
            if (!n.audio) continue
            out.push({
                id: n.id,
                name: root.labelOf(n),
                muted: n.audio.muted,
                volume: n.audio.volume,
                isDefault: n === Pipewire.defaultAudioSink
                        || n === Pipewire.defaultAudioSource,
                icon: root.glyphFor(n),
                obj: n
            })
        }
        return out
    }

    // A device's `description` is the readable one ("Built-in Audio Analogue
    // Stereo"); `name` is the alsa path. For a stream the interesting label is
    // the program rather than the stream, so application.name comes first —
    // otherwise every row in the list says "playback".
    function labelOf(node) {
        var p = node.properties || ({})
        if (node.isStream)
            return p["application.name"] || p["media.name"]
                || node.description || node.name
        return node.description || node.nickname || node.name
    }

    readonly property var iconNames: ["headset", "speaker", "volume_up", "volume_down",
                                      "volume_off", "mic", "mic_off", "graphic_eq"]

    function glyphFor(node) {
        var p = node.properties || ({})
        var form = String(p["device.form-factor"] || "")
        if (form.indexOf("headset") >= 0 || form.indexOf("headphone") >= 0) return "headset"
        if (node.isStream) return "graphic_eq"
        return "speaker"
    }

    // ⚠️ `preferredDefaultAudioSink`, NOT `defaultAudioSink`. The second is
    // read-only and reports what the graph is doing; the first is the writable
    // wish that Pipewire then acts on. Assigning to the read-only one is a
    // switch that silently does nothing.
    function useOutput(entry) {
        if (root.fake) {
            root._fakeOutputId = entry.id
            return
        }
        Pipewire.preferredDefaultAudioSink = entry.obj
    }

    function useInput(entry) {
        if (root.fake) {
            root._fakeInputId = entry.id
            return
        }
        Pipewire.preferredDefaultAudioSource = entry.obj
    }

    function setNodeVolume(entry, v) {
        // Nothing to move in fake mode: the invented nodes have no audio object
        // behind them, and a slider that appears to work on a machine with no
        // sound card would be the lie the mode exists to avoid.
        if (root.fake) return
        if (!entry.obj || !entry.obj.audio) return
        entry.obj.audio.volume = Math.max(0, Math.min(1, v))
    }

    function toggleNodeMute(entry) {
        if (root.fake) return
        if (!entry.obj || !entry.obj.audio) return
        entry.obj.audio.muted = !entry.obj.audio.muted
    }

    // -------------------------------------------------------------- tracking
    //
    // What the panel is looking at. Empty while it is closed, which is the point.
    property var watched: []

    // ⚠️⚠️ IT ASKS PIPEWIRE, NOT OUR OWN LISTS, AND THAT IS THE WHOLE FIX. What
    // stood here built the watch list out of `outputs`, `inputs` and `streams` —
    // and those come from `collect()`, which skips every node that is not
    // `ready`. A node becomes ready by being tracked. So:
    //
    //     collect()  drops a node because it is not ready
    //          ↓
    //     watch()    never puts it in the tracker
    //          ↓
    //     PwObjectTracker  never makes it ready
    //
    // A closed circle, and it is exactly what he reported: "rechts davon ist ja  // english-ok: the report, quoted
    // ein pfeil der erkennt aber nichts obwohl spotify offen ist also ich kann   // english-ok: the report, quoted
    // den sound nicht individuell einstellen".                                   // english-ok: the report, quoted
    //
    // ⚠️ AND IT WAS MEASURED BEFORE IT WAS TOUCHED, on his machine, because the
    // lab VM has no audio hardware at all and cannot answer this question:
    //
    //     pw-dump | grep -o '"media.class": "[^"]*"' | sort | uniq -c
    //     →  2 "media.class": "Stream/Output/Audio"
    //
    // Two playback streams existed while the panel showed none. That rules out
    // Spotify, the flatpak sandbox and the D-Bus name — the gap was ours.
    //
    // The list therefore comes from the graph itself: every audio node that is a
    // sink, a source or a stream goes into the tracker while the sound section
    // is open, ready or not. `collect()` keeps its `ready` test, which is now
    // what it was always meant to be — "do not show a node whose values are not
    // bound yet" — rather than a filter that prevents them from ever binding.
    //
    // ⚠️ STILL ONLY WHILE SOMETHING IS ON SCREEN. The paragraph at the top of
    // this file argues against holding the whole graph bound all session on a
    // battery, and that argument is untouched: this list is built on
    // `watch(true)` and emptied on `watch(false)`.
    function watch(on) {
        if (!on) {
            root.watched = []
            return
        }
        var objs = []
        var raw = Pipewire.nodes ? Pipewire.nodes.values : []
        for (var i = 0; i < raw.length; i++) {
            var n = raw[i]
            // ⚠️ EVERY AUDIO NODE, not "sinks and streams". A capture device is
            // neither — `collect(false, false)` is what gathers the inputs — so
            // testing for the two would have left the microphone list with the
            // fault this function was rewritten to remove.
            if (!n || !n.audio)
                continue
            objs.push(n)
        }
        root.watched = objs
    }

    PwObjectTracker {
        objects: {
            var base = []
            if (root.sink) base.push(root.sink)
            if (root.source) base.push(root.source)
            return base.concat(root.watched)
        }
    }

    // ------------------------------------------------------------ fake data
    property real _fakeVolume: 0.62
    property bool _fakeMuted: false
    property bool _fakeMicMuted: true
    property real _fakeMicVolume: 0.8
    property int _fakeOutputId: 1
    property int _fakeInputId: 3
    readonly property var _fakeOutputs: [
        { id: 1, name: "Built-in Audio Analogue Stereo", muted: false, volume: 0.62,
          isDefault: root._fakeOutputId === 1, icon: "speaker", obj: null },
        { id: 2, name: "WH-1000XM4", muted: false, volume: 0.4,
          isDefault: root._fakeOutputId === 2, icon: "headset", obj: null }
    ]
    readonly property var _fakeInputs: [
        { id: 3, name: "Built-in Microphone", muted: root._fakeMicMuted, volume: 0.8,
          isDefault: root._fakeInputId === 3, icon: "mic", obj: null }
    ]
    readonly property var _fakeStreams: [
        { id: 10, name: "Brave", muted: false, volume: 0.8, isDefault: false,
          icon: "graphic_eq", obj: null },
        { id: 11, name: "Spotify", muted: false, volume: 0.35, isDefault: false,
          icon: "graphic_eq", obj: null }
    ]
}
