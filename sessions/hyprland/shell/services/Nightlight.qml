pragma Singleton

// Night light, over gammastep — quickshell has no gamma API, and this is one of
// the handful of programs the plan names as staying external for exactly that
// reason.
//
// ⚠️ THE PROCESS IS THE STATE. `gammastep -O TEMP` is documented as "one shot
// manual mode", which reads as though it sets the ramp and exits. It does not:
// measured on the VM, it stays alive, and under Wayland the gamma belongs to
// the client — so ending it puts the screen back. Night light on is therefore
// "this process is running" and night light off is "it is not", with `-x` after
// it to reset rather than trusting the compositor to notice.
//
// ⚠️ AND IT CAN FAIL WITH NOTHING TO SEE. On a screen whose driver has no gamma
// control, gammastep starts, prints "Zero outputs support gamma adjustment" and
// then does nothing at all — which is precisely what the VM does. A switch that
// lights up and changes nothing is the fault this project keeps finding, so the
// warning is read and `supported` goes false, and the panel says so.
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Singleton {
    id: root

    readonly property bool fake: !!Quickshell.env("BUCHHWIN_SHELL_FAKE")

    // The binary is there or it is not; nothing else about this is knowable
    // before it runs once.
    property bool available: root.fake
    // Set false the first time gammastep says the screen cannot do it.
    property bool supported: true
    property string status: ""

    readonly property bool on: Config.nightlight.on
    readonly property int temperature: Config.nightlight.temperature

    function setOn(value) {
        Config.nightlight.on = value
        Config.save()
    }

    function toggle() { root.setOn(!root.on) }

    function setTemperature(kelvin) {
        Config.nightlight.temperature = Math.max(1000, Math.min(6500, kelvin))
        Config.save()
        // A change while it is running has to be applied to the running one,
        // and gammastep has no way to be told — so it is restarted.
        if (root.on) {
            lamp.running = false
            restart.start()
        }
    }

    // ⚠️ `-m wayland` explicitly. Left to itself gammastep tries every method in
    // turn, including DRM, and on a Wayland session the first failure is the
    // one that gets printed — which reads like a broken installation rather
    // than like a method that was never going to apply.
    Process {
        id: lamp
        command: ["gammastep", "-m", "wayland", "-P", "-O",
                  String(Config.nightlight.temperature)]
        running: !root.fake && Config.nightlight.on
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: function (line) {
                if (line.indexOf("gamma adjustment") >= 0
                        && line.indexOf("Zero outputs") >= 0) {
                    root.supported = false
                    root.status = "This screen has no gamma control"
                }
            }
        }
        onExited: function (code) {
            // 127 is the shell's "no such command"; anything else that fails at
            // once means it started and gave up, which is worth saying too.
            if (code !== 0 && Config.nightlight.on)
                root.status = "Night light could not start"
        }
    }

    Timer {
        id: restart
        interval: 120
        onTriggered: lamp.running = Config.nightlight.on && !root.fake
    }

    // Put the screen back. gammastep under Wayland releases its own ramp when it
    // exits, but a crash does not, and `-x` costs one short-lived process.
    Process {
        id: reset
        command: ["gammastep", "-m", "wayland", "-x"]
    }

    onOnChanged: if (!root.on && !root.fake) reset.running = true

    // Is the binary installed at all? One run at startup, no polling — the
    // answer cannot change while the session is up.
    Process {
        id: probe
        command: ["gammastep", "-V"]
        running: true
        stdout: StdioCollector {}
        onExited: function (code) {
            root.available = root.fake || code === 0
            if (!root.available)
                root.status = "gammastep is not installed"
        }
    }
}
