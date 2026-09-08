// The lock screen. Its own process — see shell.qml for why that is a safety
// property and not a layout choice.
//
// ⚠️ WHAT HAPPENS IF THIS CRASHES. The ext-session-lock protocol says a
// compositor must keep the session locked behind a blank screen when the
// locking client disappears without unlocking. So a fault here leaves you at a
// blank locked screen and needing a TTY — inconvenient, and the correct
// direction to fail in. The opposite, a crash that unlocks, is what running
// this inside the shell would have risked.
//
// ⚠️ IT LOCKS ON STARTUP AND EXITS ON UNLOCK. There is no "hide" state. A lock
// screen that is running but not locking is a process that looks like security
// and is not.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../config"

Scope {
    id: root

    WlSessionLock {
        id: session

        // Locked the moment the process exists. Nothing waits for a signal,
        // because between "process started" and "signal handled" is a window
        // where the desktop is visible and unlocked.
        locked: true

        WlSessionLockSurface {
            // Behind the face, and drawn even before it: a lock surface that
            // starts transparent shows the desktop through it for as long as
            // the first frame takes.
            //
            // ⚠️ THE OPAQUE COLOUR STAYS EVEN WITH A WALLPAPER ON TOP. The
            // image loads asynchronously — it has to, a 4K photo decoded
            // synchronously is a visibly late lock — so for those frames this
            // colour is the only thing between the screen and the desktop
            // underneath. It is not a fallback; it is the floor.
            color: Theme.bgDeep

            // The wallpaper, on by default and blurred — his reference for this
            // screen asks for exactly that. ⚠️ This is a SEPARATE PROCESS
            // (BUCHHWIN_MODE=lock): it reads shell.json itself and learns
            // nothing from the running shell, so it reads the same key the
            // desktop wallpaper does rather than being told.
            Image {
                id: shot
                anchors.fill: parent
                // ⚠️ DRAWN BY THE EFFECT BELOW, NOT DIRECTLY. A MultiEffect
                // source that is also visible itself is painted twice — the
                // sharp copy underneath and the soft one on top.
                visible: false
                source: (Config.lock && Config.lock.wallpaper && Config.wallpaper)
                        ? Config.wallpaper.current : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                // Read at screen size, not at whatever the file happens to be.
                sourceSize.width: width
                sourceSize.height: height
            }

            // ⚠️ THE BLUR HIS REFERENCE ASKS FOR, and it has to happen here
            // rather than in the compositor: niri blurs LAYER surfaces, and this
            // is an ext-session-lock surface. `blurMax` is the radius cap and
            // `blur` is how much of it is used — at 1.0 the number in the
            // setting is the radius.
            MultiEffect {
                anchors.fill: parent
                source: shot
                visible: shot.status === Image.Ready
                autoPaddingEnabled: false
                blurEnabled: (Config.lock ? Config.lock.wallpaperBlur : 0) > 0
                blur: 1.0
                blurMax: Config.lock ? Config.lock.wallpaperBlur : 0
            }

            // Over the picture, under the face. A photograph is not a
            // background for a clock until something takes the contrast out of
            // it — and the same scrim over the plain colour costs nothing,
            // because `scrim` is transparent enough to leave it alone.
            Rectangle {
                anchors.fill: parent
                color: Theme.scrim
            }

            LockFace {
                anchors.fill: parent
                onUnlocked: {
                    session.locked = false
                    // The process has one job and it is done. Staying alive
                    // would leave a second copy holding PAM state the next time
                    // the screen locks.
                    Qt.quit()
                }
            }
        }
    }
}
