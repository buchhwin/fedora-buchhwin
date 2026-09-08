//@ pragma IconTheme Adwaita
import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    property var dwlState: ({ "outputs": {} })
    property string statePath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/buchhwin-dwl-state.json"

    function reloadState() {
        try {
            const raw = stateFile.text()
            if (raw && raw.trim().length > 0)
                root.dwlState = JSON.parse(raw)
        } catch (error) {
            console.warn("buchhwin: could not parse dwl state:", error)
        }
    }

    // The bar popovers form one mutually exclusive group.
    function closeSmallPanels(exceptPanel) {
        if (exceptPanel !== controlCenter) controlCenter.opened = false
        if (exceptPanel !== networkPanel) networkPanel.opened = false
        if (exceptPanel !== bluetoothPanel) bluetoothPanel.opened = false
        if (exceptPanel !== audioPanel) audioPanel.opened = false
        if (exceptPanel !== calendarPopup) calendarPopup.opened = false
        if (exceptPanel !== mediaPopup) mediaPopup.opened = false
    }

    function toggleSmallPanel(panel) {
        const shouldOpen = !panel.opened
        closeSmallPanels(panel)
        panel.opened = shouldOpen
    }

    FileView {
        id: stateFile
        path: root.statePath
        watchChanges: true
        printErrors: false
        onLoaded: root.reloadState()
        onFileChanged: reload()
        onTextChanged: root.reloadState()
    }

    NotificationService { id: notificationService }
    AudioState { id: audioState }
    MediaState { id: mediaState }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcher.opened = !launcher.opened }
        function open(): void { launcher.opened = true }
        function close(): void { launcher.opened = false }
    }
    IpcHandler {
        target: "controlCenter"
        function toggle(): void { root.toggleSmallPanel(controlCenter) }
    }
    IpcHandler {
        target: "notifications"
        function toggle(): void { notificationCenter.opened = !notificationCenter.opened }
    }
    IpcHandler {
        target: "powerMenu"
        function toggle(): void { powerMenu.opened = !powerMenu.opened }
    }
    IpcHandler {
        target: "keybinds"
        function toggle(): void { keybinds.opened = !keybinds.opened }
    }
    IpcHandler {
        target: "clipboard"
        function toggle(): void { clipboard.opened = !clipboard.opened }
    }
    IpcHandler {
        target: "settings"
        function toggle(): void { settings.opened = !settings.opened }
    }
    IpcHandler {
        target: "network"
        function toggle(): void { root.toggleSmallPanel(networkPanel) }
    }
    IpcHandler {
        target: "bluetooth"
        function toggle(): void { root.toggleSmallPanel(bluetoothPanel) }
    }
    IpcHandler {
        target: "audio"
        function toggle(): void { root.toggleSmallPanel(audioPanel) }
    }
    IpcHandler {
        target: "calendar"
        function toggle(): void { root.toggleSmallPanel(calendarPopup) }
    }
    IpcHandler {
        target: "media"
        function toggle(): void { root.toggleSmallPanel(mediaPopup) }
    }

    Bar {
        dwlState: root.dwlState
        audioState: audioState
        mediaState: mediaState
    }
    Launcher { id: launcher }
    ControlCenter {
        id: controlCenter
        networkPanel: networkPanel
        bluetoothPanel: bluetoothPanel
        audioPanel: audioPanel
        audioState: audioState
        mediaState: mediaState
    }
    NotificationCenter { id: notificationCenter; service: notificationService }
    NotificationPopups { service: notificationService }
    PowerMenu { id: powerMenu }
    Keybinds { id: keybinds }
    ClipboardHistory { id: clipboard }
    Settings {
        id: settings
        audioState: audioState
        networkPanel: networkPanel
        bluetoothPanel: bluetoothPanel
        audioPanel: audioPanel
    }
    NetworkPanel { id: networkPanel }
    BluetoothPanel { id: bluetoothPanel }
    AudioPanel { id: audioPanel; audioState: audioState }
    CalendarPopup { id: calendarPopup }
    MediaPopup { id: mediaPopup; mediaState: mediaState }
}
