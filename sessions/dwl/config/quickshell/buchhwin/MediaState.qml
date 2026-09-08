import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
Scope {
    id: root
    property string selectedIdentity: ""
    property var players: Mpris.players.values
    property var player: choosePlayer()
    function choosePlayer() {
        const list = players
        let fallback = list.length ? list[0] : null
        for (let i = 0; i < list.length; i++) if (list[i].identity === selectedIdentity) return list[i]
        for (let i = 0; i < list.length; i++) if (list[i].isPlaying) return list[i]
        return fallback
    }
    function select(identity) { selectedIdentity = identity; writer.command = ["buchhwin-media-player", "set", identity]; if (!writer.running) writer.running = true }
    Component.onCompleted: reader.running = true
    Process { id: reader; command: ["buchhwin-media-player", "get"]; stdout: StdioCollector { onStreamFinished: root.selectedIdentity = text.trim() } }
    Process { id: writer }
}
