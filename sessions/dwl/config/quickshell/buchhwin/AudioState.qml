import Quickshell
import Quickshell.Io
import QtQuick

// One audio source of truth for the bar, Control Center and device panel.
Scope {
    id: root
    property string volumeText: "--"
    property int volumePercent: 0
    property bool muted: false
    property bool ready: false
    property var pendingCommand: null

    function refresh() {
        if (!statusProc.running) statusProc.running = true
    }

    function run(command) {
        pendingCommand = command
        actionDelay.restart()
    }

    function flushAction() {
        if (actionProc.running) { actionDelay.restart(); return }
        if (!pendingCommand) return
        actionProc.command = pendingCommand
        pendingCommand = null
        actionProc.running = true
    }

    Process {
        id: statusProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim()
                const match = line.match(/Volume:\s+([0-9.]+)/)
                if (!match) return
                root.volumePercent = Math.max(0, Math.round(Number(match[1]) * 100))
                root.muted = line.indexOf("[MUTED]") >= 0
                root.volumeText = root.muted ? "mute" : root.volumePercent + "%"
                root.ready = true
            }
        }
    }

    Process { id: actionProc; onExited: { root.refresh(); if (root.pendingCommand) actionDelay.restart() } }
    Timer { id: actionDelay; interval: 70; onTriggered: root.flushAction() }
    Timer { id: refreshDelay; interval: 120; onTriggered: root.refresh() }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
}
