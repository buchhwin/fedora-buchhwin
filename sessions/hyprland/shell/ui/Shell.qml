// The desktop: one set of surfaces per screen.
//
// Two rules that decide how this file is shaped, both from hard-won practice:
//
//  * Filter monitors in the DELEGATE, never in the model. A model that only
//    contains the screens a surface wants makes the surface's own identity
//    depend on which screens exist — plug in a monitor and everything below it
//    is recreated. Filtering in the delegate means one instance per screen,
//    which either draws or does not.
//
//  * `activeAsync`, not `active`. A configuration change should destroy the
//    window; briefly hiding something should keep the window and drop its
//    contents. Loading synchronously in a property change handler stalls the
//    compositor for as long as the component takes to build.

import QtQuick
import Quickshell
import "../config"
import "../theme"
import "../ipc"
import "../services" as Services
import "surface"
import "dock"
import "launcher"
import "wallpaper"
import "notif"
import "settings"
import "common"

Scope {
    id: root

    // ⚠️ THIS IS WHAT STARTS THE LOCATION SERVICE. QML builds a singleton on
    // FIRST ACCESS, so one that nothing references never runs — and without
    // this line the timezone guess only happened the first time the quick
    // panel was opened, which is exactly the moment you would rather it were
    // already done. Measured: the guess simply never happened. The project has
    // now paid for this lesson four times.
    //
    // ⚠️ AND THE WEATHER IS DELIBERATELY *NOT* STARTED HERE.
    //
    // Creating it at shell construction crashes quickshell. Not a guess — the
    // backtrace is inside `JsonAdapter::deserializeRec` → `QMetaProperty::write`
    // → `QObjectWrapper::wrap`, SIGSEGV, and it was isolated to this by adding
    // and removing this one term: without it, zero crashes across many
    // restarts; with it, a crash loop and then intermittent crashes even after
    // the obvious causes (a Connections on a half-built singleton, an
    // XMLHttpRequest during construction) were fixed. It is a race inside
    // Quickshell's adapter, not something this file can hold correctly.
    //
    // So Weather is created when the quick panel first opens, exactly as it was
    // before. The cost is one second before the first temperature appears. The
    // alternative is a desktop that segfaults, which is not a trade.
    // ⚠️ AND THE COUNTDOWN, WHICH I BROKE TODAY AND MEASURED WITHIN THE HOUR.
    //
    // The tick timer runs on `Countdown.running`, so the service has to exist
    // for a timer to count at all. Until today it existed by accident: the
    // collapsed notch read `Countdown.active` to decide whether to show the
    // countdown instead of the clock, and that reference built the singleton.
    // Then the notch went back to showing only the clock — correctly — and the
    // only remaining reference was inside a `&&` chain in the aside's loader,
    // where it is never evaluated unless the pointer is on the notch.
    //
    // Measured, not reasoned: a timer restored with twelve seconds left rang
    // never, the state file still said `rang: false`, and `notify-send` by hand
    // produced a toast a second later — so the notification path was fine and
    // the countdown had simply never started. A timer that only runs while you
    // are hovering the notch is worse than no timer.
    //
    // Two names, one line each, and a comment that is longer than both because
    // the failure is invisible and the fix looks like nothing.
    readonly property string startServices: Services.Location.timezone
    readonly property bool startCountdown: Services.Countdown.active

    // ⚠️ AND THE SAME TRAP WOULD HAVE SWALLOWED THE IDLE WATCHER WHOLE. It owns
    // four IdleMonitors and nothing else in the shell asks it anything — it has
    // no readout, no icon, no page. A singleton nobody references is never
    // built, so the screen would simply never have gone off, and the settings
    // page would have been a set of numbers that did nothing at all.
    //
    // That is the failure the countdown had, and it is worth one line here to
    // not have it twice.
    readonly property int startIdle: Services.Idle.screenOffAfter

    // ⚠️ AND THE THIRD ONE, for exactly the same reason. Restore has no readout,
    // no icon and no page either: it watches the window list and opens things
    // once at login. Unreferenced it would never be built, and "restore my
    // session" would be a switch in the settings window that did nothing —
    // which is the same fault as the countdown and the idle watcher, now three
    // times in one file. Anything that only acts on a timer needs a line here.
    readonly property bool startRestore: Services.Restore.settled

    // ⚠️ AND THE THEMING WATCHER IS STARTED LATE, FOR THE SAME REASON AS
    // WEATHER — but it must be started, because without it changing the palette
    // recolours the shell and nothing else. That was the state until today:
    // tools/render.qml's header claimed the running shell re-rendered on a
    // palette change, and nothing in shell/ ever launched it. Pick a wallpaper,
    // and GTK, Qt, kitty and the compositor kept the old colours until somebody typed
    // `bhctl theme apply` by hand.
    //
    // A Timer rather than a property reference: the service reads two dozen
    // JsonAdapter values, and doing that during shell construction is the shape
    // that segfaults quickshell. It also guards itself on `Config.settled`, so
    // this is the belt to that file's braces — the crash cost this project a
    // whole debugging round once, and one line of deferral is cheap insurance.
    Timer {
        running: true
        interval: Theme.durSlow
        onTriggered: root.themingStarted = Services.Theming.available
    }
    property bool themingStarted: false

    // Whether a surface belongs on this screen. An empty list means all of
    // them, which is the only sane default for a machine whose monitor names
    // nobody has typed in yet.
    //
    // ⚠️ `@primary` IS A NAME NO CONNECTOR HAS, and that is deliberate. The
    // notch defaults to the main monitor only, and writing the connector name
    // into the default would mean shipping a default that is wrong on every
    // machine but one. A resolvable placeholder keeps ONE state — the list —
    // instead of a list plus a "primary?" flag that can disagree with it, the
    // same rule settings/OutputScales.qml states for `outputs`.
    function wants(monitors, screen) {
        if (!monitors || monitors.length === 0)
            return true
        for (var i = 0; i < monitors.length; i++) {
            var m = String(monitors[i])
            if (m === "@primary") {
                if (screen.name === root.primaryOutput)
                    return true
                continue
            }
            if (m === screen.name)
                return true
        }
        return false
    }

    // Which output counts as the main one.
    //
    // ⚠️ RESOLVED HERE AND NOT IN A SERVICE, on purpose. It needs both halves
    // of the answer — what the user marked in `outputs`, and what screens
    // actually exist — and services/Compositor.qml says in as many words that
    // the screen comes from the caller. This is the caller.
    //
    // The mark is an entry in `outputs` carrying `primary: true`, which is the
    // same key the Displays page writes as the compositor's `focus-at-startup`. One
    // state: marked, or not marked and then it is simply the first screen the compositor
    // reports. No second "is this automatic?" flag to drift out of step.
    readonly property string primaryOutput: {
        var outs = Config.outputs
        if (outs)
            for (var i = 0; i < outs.length; i++)
                if (outs[i] && outs[i].primary === true && outs[i].name)
                    return String(outs[i].name)
        var screens = Quickshell.screens
        return (screens && screens.length > 0) ? String(screens[0].name) : ""
    }

    // Whether a surface that was opened by the user belongs on this screen.
    //
    // ⚠️ NOT THE SAME QUESTION AS `wants`. `wants` answers "is this surface
    // configured for this monitor" — a standing decision. This answers "is this
    // the monitor it was just opened on" — a per-opening one. The quick panel
    // is configured for every screen and still has to appear on exactly one.
    //
    // An empty target means the compositor had no opinion (the compositor has no event
    // for focus moving between outputs without a workspace change), and then
    // the honest answer is the old behaviour: show it, rather than hide it
    // everywhere and leave a keypress with no answer at all.
    function opensHere(screen) {
        return Ipc.target.length === 0 || Ipc.target === screen.name
    }

    // ⚠️ THE SETTINGS WINDOW IS OUTSIDE `Variants`, AND THAT IS THE POINT OF IT
    // BEING A WINDOW. Everything below is a layer surface and therefore belongs
    // to one screen, so it is built once per screen and each copy decides
    // whether to draw. A window belongs to no screen: the compositor places it, you move
    // it, and one per monitor would mean three settings windows opening at once
    // on a docked laptop.
    //
    // Loaded on `Ipc.settingsOpen` the same way the launcher is, so closing it
    // destroys it — and the window's own `closed` signal turns the flag back
    // off when the compositor is what closed it.
    LazyLoader {
        activeAsync: Ipc.settingsOpen
        component: SettingsWindow {}
    }

    Variants {
        model: Quickshell.screens

        delegate: Scope {
            id: perScreen
            required property var modelData

            // ⚠️⚠️ EVERY ONE OF THESE IS NULL-GUARDED, AND IT IS NOT DEFENSIVE
            // STYLE — IT IS THE REASON A SWITCHED-OFF SURFACE APPEARED ANYWAY.
            //
            // He reported "ich kann das dock mit dem slider nicht ausschalten".   // english-ok: the report, quoted
            // Measured on the VM, three runs, and the answer was the opposite of
            // the report's shape:
            //
            //   restart with dock.enabled = false   the dock is THERE   ← the bug
            //   set it true at runtime              it appears          correct
            //   set it false at runtime             it goes away        correct
            //
            // So the switch works. What does not work is STARTUP. Config.qml
            // says it in as many words a hundred lines up: during the load
            // window `adapter.<block>` is NULL — not "still the defaults", null.
            // `Config.dock.enabled` on a null therefore THROWS, and a binding
            // that throws keeps whatever it last evaluated to. What it last
            // evaluated to is the schema default, which for the dock was `true`.
            // The surface comes up, and nothing ever re-evaluates it because the
            // binding is dead. Toggling any OTHER key rebuilt the delegate,
            // which is why the dock then vanished and stayed away — the
            // behaviour that made this look like an intermittent fault.
            //
            // The guard is the pattern this project already uses at every other
            // Config read that can run during that window — ui/lock/
            // LockScreen.qml has had `Config.lock ? Config.lock.wallpaper : false`
            // since it was written, for exactly this reason. These five never
            // got it because they were written before the window was understood,
            // and because a surface that is supposed to be ON hides the fault
            // completely: the notch, the bar and the launcher were all wrong in
            // the same way and nobody could have seen it.
            //
            // ⚠️ FALSE IS THE RIGHT ANSWER WHILE THE CONFIG IS UNKNOWN. A
            // surface that flashes on and then leaves is worse than one that
            // arrives a frame late, and on this list "unknown" lasts about one
            // event-loop step.
            readonly property bool barHere: Config.bar
                ? Config.bar.enabled && root.wants(Config.bar.monitors, modelData)
                : false

            readonly property bool notchHere: Config.notch
                ? Config.notch.enabled && root.wants(Config.notch.monitors, modelData)
                : false

            readonly property bool launcherHere: Config.launcher
                ? Config.launcher.enabled
                  && root.wants(Config.launcher.monitors, modelData)
                : false

            readonly property bool dockHere: Config.dock
                ? Config.dock.enabled && root.wants(Config.dock.monitors, modelData)
                : false

            // Was this the screen the user opened something on?
            readonly property bool openedHere: root.opensHere(modelData)

            // Where the notch's PAGES go — and it is deliberately not
            // `notchHere`.
            //
            // ⚠️ THE TWO CAME APART WHEN THE NOTCH MOVED TO ONE MONITOR. The
            // notch is a readout: three clocks, three battery pills and three
            // copies of the same media title are noise, and each one is a real
            // layer surface that repaints — measurable on the 2018 iGPU this
            // also has to run on. So it defaults to `@primary`.
            //
            // The quick panel is not a readout, it is the thing you are using,
            // and it belongs under your eyes. His words on being asked: it
            // should appear where you open it. Tying the pages to `notchHere`
            // would have put them two screens away from the keypress.
            //
            // `notch.enabled` still gates it: switching the notch off switches
            // its pages off, which is what that switch has always meant.
            readonly property bool overlayHere: Config.notch
                ? Config.notch.enabled && openedHere
                : false

            // No image, no surface — an empty black layer over the compositor's
            // own background is not a wallpaper, it is a bug that looks like one.
            readonly property bool wallpaperHere:
                (Config.surfaces ? Config.surfaces.wallpaper : false)
                && String(Services.Wallpaper.current).length > 0
                && (Config.wallpaper
                    ? root.wants(Config.wallpaper.monitors, modelData) : false)

            // Furthest back, under everything including the bar's own strut.
            // The compositor zooms the background layer along with the overview, which is
            // the correct behaviour rather than a side effect: the wallpaper
            // belongs to the workspace you are looking at.
            LazyLoader {
                activeAsync: perScreen.wallpaperHere
                component: WallpaperSurface { modelData: perScreen.modelData }
            }

            // ONE window carries both. They are one drawn silhouette, so two
            // windows would mean two shapes that overlap and hide each other —
            // which is exactly what happened before this was merged.
            LazyLoader {
                activeAsync: perScreen.barHere || perScreen.notchHere
                component: ShellSurface {
                    modelData: perScreen.modelData
                    barEnabled: perScreen.barHere
                    notchEnabled: perScreen.notchHere
                }
            }

            // The pages, floating under the notch. Its own window so that both
            // it and the notch are exactly the size of what they draw — the compositor
            // blurs and shadows the whole surface, invisible margins included.
            LazyLoader {
                activeAsync: perScreen.overlayHere && Ipc.expanded
                component: OverlaySurface { modelData: perScreen.modelData }
            }

            // ⚠️ THE DOCK IS THE OPPOSITE CASE TO THE TWO ABOVE, and that is
            // deliberate rather than inconsistent. Those two are exactly the
            // size of what they draw, because the compositor blurs and shadows the whole
            // surface. The dock spans its entire edge and switches blur off
            // instead — because its contents change every time a program opens,
            // and a surface that follows its contents is the horizontal wobble
            // this shell already fixed once. The strip is drawn inside it and
            // the input region follows the strip, so the empty half of the
            // surface swallows nothing.
            LazyLoader {
                activeAsync: perScreen.dockHere
                component: DockSurface { modelData: perScreen.modelData }
            }

            // ⚠️ THE PILL BESIDE THE NOTCH IS GONE, and so is its surface. It
            // existed because the collapsed notch had room for one meaning and
            // that meaning was the time, so a running timer needed somewhere
            // else to live. It has somewhere else now: the notch grows when the
            // pointer is on it and shows the timer inside itself, along with
            // what is playing and the status pill — see notch/NotchWide.qml.
            //
            // That removes a window, a layer namespace and the awkwardness the
            // old file admitted to in its own header: moving the pointer onto
            // the pill ended the hover on the notch and took the pill away.

            // The hot corners. Two tiny surfaces, each with its own dwell.
            //
            // ⚠️ `hotCorners` defaults to "right" and NOT "both", because the compositor
            // already owns the top-left corner and has it switched on — its own
            // docs say so. Choosing "left" or "both" also switches the compositor's off;
            // that happens in tools/hypr.qml, so the two can never both answer
            // the same corner.
            LazyLoader {
                // Same null guard as the five above — see the note there.
                activeAsync: Config.surfaces
                             && (Config.surfaces.hotCorners === "left"
                                 || Config.surfaces.hotCorners === "both")
                component: HotCorner {
                    modelData: perScreen.modelData
                    corner: "left"
                    onTriggered: Ipc.toggle("workspaces")
                }
            }

            LazyLoader {
                activeAsync: Config.surfaces
                             && (Config.surfaces.hotCorners === "right"
                                 || Config.surfaces.hotCorners === "both")
                // ⚠️ THE PANEL'S NOTIFICATION TAB, NOT the `notifications`
                // page — and the difference is 1.6 seconds. That page is in
                // Ipc's `autoClosing` list because it is a REPORT: it appears
                // when something arrives and takes itself away again. Measured
                // with the corner working: rest the pointer, the page opens,
                // and it is gone before you have read it. What he asked for is
                // a notification CENTRE, which is somewhere you look — so the
                // corner opens the panel on that tab, and it stays until you
                // close it.
                component: HotCorner {
                    modelData: perScreen.modelData
                    corner: "right"
                    onTriggered: Ipc.showQuick(Ipc.quickNotifications)
                }
            }

            // The four rounded screen corners. ⚠️ One LazyLoader each rather
            // than one surface with four corners drawn on it: the compositor blurs and
            // shadows the WHOLE surface, so a fullscreen one would put both
            // behind the entire display. Four r × r textures instead.
            //
            // A radius of 0 creates nothing at all — not a surface drawing
            // nothing, no surface.
            //
            // ⚠️ WRITTEN OUT, NOT A `Repeater`, AND THE FIRST ATTEMPT WAS THE
            // Repeater. It instantiates delegates into an ITEM, and this
            // delegate is a `Scope` — so it built nothing, said nothing, and
            // `hyprctl -j layers` answered "0 corner surfaces" while the
            // journal stayed clean. The two hot corners above are written out
            // for the same reason.
            LazyLoader {
                activeAsync: Config.surfaces && Config.surfaces.screenCornerRadius > 0
                component: ScreenCorner {
                    modelData: perScreen.modelData
                    corner: "top-left"
                }
            }
            LazyLoader {
                activeAsync: Config.surfaces && Config.surfaces.screenCornerRadius > 0
                component: ScreenCorner {
                    modelData: perScreen.modelData
                    corner: "top-right"
                }
            }
            LazyLoader {
                activeAsync: Config.surfaces && Config.surfaces.screenCornerRadius > 0
                component: ScreenCorner {
                    modelData: perScreen.modelData
                    corner: "bottom-left"
                }
            }
            LazyLoader {
                activeAsync: Config.surfaces && Config.surfaces.screenCornerRadius > 0
                component: ScreenCorner {
                    modelData: perScreen.modelData
                    corner: "bottom-right"
                }
            }

            // Only while a page is open. A permanent fullscreen surface that
            // swallows clicks is the kind of bug nobody suspects.
            LazyLoader {
                activeAsync: perScreen.overlayHere && Ipc.expanded
                component: ClickCatcher { modelData: perScreen.modelData }
            }

            // The launcher, in the middle of the screen. Its own surface and
            // NOT a notch page: it is the one thing the brief says may be open
            // without the notch stepping aside, so it cannot go through
            // `Ipc.page`.
            //
            // ⚠️ It does not need `notchHere`. A machine with the notch turned
            // off still has to be able to start a program — tying the launcher
            // to the notch would make one setting quietly disable the other.
            LazyLoader {
                activeAsync: perScreen.launcherHere && perScreen.openedHere
                             && Ipc.launcher
                component: LauncherSurface { modelData: perScreen.modelData }
            }

            // Arriving messages, top-right, on their own surface. Not a page of
            // the notch — see notif/ToastSurface.qml for why that was wrong.
            //
            // ⚠️ THIS IS ALSO WHAT STARTS THE NOTIFICATION SERVER. QML builds a
            // singleton on first access, so a service nothing references never
            // runs, and a daemon that never registers answers notify-send with
            // "The name is not activatable" — which reads like a D-Bus fault
            // rather than "nothing asked for it". The reference used to sit in
            // ShellSurface, which meant the server only existed if the notch
            // did.
            LazyLoader {
                // ⚠️ FOUND BY tests/surfaces.sh ON ITS FIRST RUN, after the
                // other seven had been guarded by hand — which is the whole
                // argument for writing the wire rather than fixing the
                // instances. Two blocks read here, so two guards.
                activeAsync: Config.surfaces && Config.notifications
                             && Config.surfaces.notifications
                             && root.wants(Config.notifications.monitors,
                                           perScreen.modelData)
                component: ToastSurface { modelData: perScreen.modelData }
            }

            // Space is reserved by its own window, so the visible surface can
            // be taller than the room it takes. In notch-only mode this is
            // simply not created — not hidden, not zero-height.
            LazyLoader {
                activeAsync: perScreen.barHere || perScreen.notchHere
                component: Strut {
                    modelData: perScreen.modelData
                    edge: "top"
                    // The COLLAPSED height, never the expanded one. Reserving
                    // the expanded size would push every window 135 px down and
                    // leave a permanent empty band under the notch.
                    //
                    // Whichever of the two is actually on screen: with the bar
                    // off, reserving the bar's height was reserving room for
                    // something that is not there.
                    reserve: Math.max(perScreen.notchHere
                                      ? Config.notch.collapsedHeight : 0,
                                      perScreen.barHere ? Config.bar.height : 0)
                }
            }
        }
    }
}
