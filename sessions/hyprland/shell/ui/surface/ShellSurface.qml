// The notch itself: one window per screen, carrying the silhouette, the bar
// contents on it, and the island in it.
//
// Bar and island are ONE drawn shape — the plan says so directly, and building
// them as two windows failed exactly as it predicted: with the bar on, the
// island vanished behind it and the concave shoulder had nothing to blend into.
//
// What is NOT here any more are the pages. The island used to become each of
// them, which was right for the volume readout it was drawn from and wrong for
// everything after: a calendar is not a notch that got bigger. They live in
// surface/OverlaySurface.qml now, and this window has three states instead —
// full, hidden, strip. See `mode`.
//
// It reserves no space; a separate Strut does that, which is the whole reason
// the two are separate windows.

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../config"
import "../../services" as Services
import "../../ipc"
import "../bar"
import "../notch"

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    property bool barEnabled: true
    property bool notchEnabled: true

    // Public interface: config.kdl attaches the blur rule to this namespace.
    // Renaming it here without renaming it there loses the blur silently.
    WlrLayershell.namespace: "buchhwin-notch"

    // ⚠️ A FULLSCREEN WINDOW IS DRAWN ABOVE THE `top` LAYER. Measured: with the
    // terminal fullscreen, the strip was simply not on screen — not mis-sized,
    // not transparent, gone. `top` is the right home the rest of the time
    // (below fullscreen content, above ordinary windows), so the surface moves
    // to `overlay` exactly while it is needed there and back afterwards.
    //
    // That is also why the strip is a hairline rather than the whole notch: it
    // is the one thing allowed to sit over a fullscreen video, so it has to
    // earn the space, and hovering is what asks for more.
    WlrLayershell.layer: root.fullscreenHere ? WlrLayer.Overlay : WlrLayer.Top

    // ⚠️ THE WINDOW IS EXACTLY AS BIG AS WHAT IS DRAWN IN IT. Nothing here is
    // cosmetic — niri's blur rule applies to the whole LAYER SURFACE, not to
    // the shape painted on it.
    //
    // This was full width and a constant `expandedHeight + flare` = 149 px, so
    // the top fifth of the screen was permanently blurred while the island
    // itself was 150×34, and every window's upper edge sat behind that band.
    // Reported as "the blur is a fifth of the screen but the notch is not" —
    // which is exactly what it was.
    //
    // It is also the cheapest thing in the shell to get right: blurring
    // 1280×149 instead of 174×48 is roughly twenty-five times the full-screen
    // GPU reads, every frame, on a laptop.
    //
    // With the bar on, full width is correct — the bar really does span the
    // screen. With it off, the surface is the island plus its shoulders.
    // ⚠️⚠️ FULL WIDTH, ALWAYS — AND THIS IS THE WOBBLE HE REPORTED.
    //
    // It used to be `left: root.barEnabled; right: root.barEnabled`, so with the
    // bar off the surface was only as wide as its own content:
    //
    //     implicitWidth : max(collapsedWidth, notch.implicitWidth)   ← CONTENT
    //     island.x      : (parent.width - islandW) / 2               ← WINDOW
    //
    // The island is centred in the WINDOW, and the window is sized by the
    // CONTENT. So every time the content changed width — the clock, a media
    // title, the timer counting down, an icon resolving — the window resized AND
    // the island slid sideways to stay centred in it. Fast, repeated, horizontal.
    // That is "alles wackelt ganz schnell von links nach rechts".               // english-ok: quoted brief
    //
    // ⚠️ tests/motion.sh did NOT catch it, and that is worth writing down: it
    // checks that no surface size follows an ANIMATED property. This one
    // followed a CONTENT property, which is a different sentence with the same
    // consequence — a Wayland surface re-sized out from under a running
    // animation. The check has been widened.
    //
    // Anchored to both edges the width is the SCREEN's, so it is constant: the
    // centre never moves, the window is never re-sized, and the shape animates
    // inside a surface that genuinely stays put. That is the rule this shell
    // already had — what decides layout is SET, what moves is ANIMATED — applied
    // to the one place that was still breaking it.
    //
    // ⚠️ AND IT IS SAFE HERE, for the reason the note below spells out: niri
    // draws blur and shadow behind the WHOLE surface, so spare room usually
    // comes out as a halo — but this is the one surface with both switched off
    // (tools/niri.qml: `surface("buchhwin-notch", notchRadius, false, false)`).
    // The input region already follows the drawn shape rather than the window,
    // and Silhouette paints around `width / 2`, so a wider surface changes
    // nothing about what is painted or what answers a click.
    anchors { top: true; left: true; right: true }

    //
    // ⚠️ AND IT HAS NO INVISIBLE MARGIN. From niri's own layer-rule docs:
    // "niri has no way of knowing about invisible margins, and will draw the
    // shadow behind the entire surface." Blur is the same. The window used to
    // carry `flare` px of transparent border for the shoulders to curve into —
    // and that border came out as a blurred, colour-fringed halo around the
    // pill. Reported as "the colours bug out around it", and that was it.
    //
    // The shoulders now curve within the island's own width instead, so what
    // the surface covers and what it paints are the same rectangle.
    // ⚠️⚠️ THE SURFACE IS SIZED TO THE LARGEST SHAPE IT WILL EVER HOLD, AND IT
    // DOES NOT FOLLOW THE ANIMATION. This is the single biggest thing in the
    // shell for how the animations FEEL, and it was wrong for a long time
    // behind a comment that called it a feature: `implicitHeight` used to read
    // `root.islandH`, which is animated, so the window "followed the shape
    // down".
    //
    // Following the shape means re-sizing a WAYLAND LAYER SURFACE once per
    // frame, and that is not drawing — it is protocol. Every frame paid for a
    // `set_size` plus an `ack_configure` round trip with niri, a buffer of a new
    // size (so the swapchain is thrown away every frame), a fresh corner-radius
    // calculation, and a new input region. Measured on the VM at 60 Hz, ONE
    // opening of the quick panel: 11 × `set_size`, 9 × `ack_configure` — one per
    // frame. On his 144 Hz laptop that is about 21.
    //
    // That is why two rounds of tuning durations and easing curves changed
    // nothing and he reported it as still stuttering both times: the cost was
    // never in the numbers.
    //
    // ⚠️ AND IT IS ONLY SAFE HERE. The rule the rest of this shell lives by —
    // a surface must be exactly as big as what it draws — exists because niri
    // draws blur and shadow behind the WHOLE surface, so spare room comes out
    // as a halo. The notch is the one surface with both switched off:
    // tools/niri.qml calls `surface("buchhwin-notch", notchRadius, false, false)`
    // and the signature is `(ns, radius, blur, shadow)`. No blur, no shadow, no
    // halo to mis-size. OverlaySurface.qml is translucent and blurred, so it
    // solves the same problem a different way — see the note there.
    //
    // The shape still animates; it just animates INSIDE a surface that stays
    // put. `Silhouette` paints from y=0 downwards and takes the island's size as
    // parameters, so a taller surface changes nothing about what is drawn.
    readonly property real maxIslandHeight:
        Math.max(Config.notch.hoverHeight, Config.notch.collapsedHeight, root.barH)

    // ⚠️ NO `implicitWidth` ANY MORE, deliberately. The anchors above give the
    // surface the screen's width; an implicitWidth derived from the content is
    // exactly what made the window follow the content and the island slide with
    // it. The height stays, and every term in it is a CONFIG value — nothing
    // animated, nothing measured from a child.
    implicitHeight: Math.max(1, root.maxIslandHeight)

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"            // literal-ok: absence of colour, not a colour

    // ⚠️ The mask is the INPUT region, and it must follow the drawn shape, not
    // the window. Masking the whole window turns the entire top strip of the
    // screen into a click trap even where nothing is painted.
    //
    // ⚠️ AND IT KEEPS ITS REGION WHILE THE NOTCH IS HIDDEN, deliberately. The
    // first attempt emptied the mask when `mode` is "hidden" — and that made it
    // WORSE rather than better: the click went straight through to the
    // fullscreen ClickCatcher underneath, which closed the page just the same.
    // Measured both ways with a real pointer. What is wanted is a click that
    // does NOTHING there, so the region stays and the handler stands down —
    // see the island's TapHandler below.
    // ⚠️ AND BECAUSE THE SURFACE IS NOW BIGGER THAN THE SHAPE, THE MASK HAS TO
    // FOLLOW THE SHAPE RATHER THAN THE WINDOW. It used to be `item: hitArea`,
    // and `hitArea` fills the window — which was the same rectangle back when
    // the window tracked the island. It is not any more: masking the window
    // would turn the whole reserved box into a click trap, and would make the
    // HoverHandler below fire anywhere in it, so the notch would open while the
    // pointer was over empty space beside it.
    //
    // The mask is the surface's INPUT REGION, so this is also what keeps the
    // hover honest: pointer events outside it are never delivered to this
    // window at all. Shape in, shape out.
    //
    // `Region` combines its children by default — verified in the type
    // description shipped with quickshell (`PendingRegion`, defaultProperty
    // "regions", Intersection.Combine first), not assumed.
    readonly property real hitW:
        root.mode === "hidden" ? Config.notch.collapsedWidth : root.islandW
    readonly property real hitH:
        root.mode === "hidden" ? Config.notch.collapsedHeight : root.islandH

    mask: Region {
        // The bar spans the screen when it is on and is zero-height when it is
        // not, so this needs no condition of its own.
        Region { item: barStrip }

        // ⚠️ NEVER EMPTY, and that is a bug fix rather than caution. An earlier
        // attempt emptied the region while the notch is hidden and it made
        // things WORSE, measured both ways with a real pointer: the click fell
        // through to the fullscreen ClickCatcher underneath, which closed the
        // page just the same. What is wanted there is a click that does
        // NOTHING, so the region stays at the collapsed size and the island's
        // TapHandler stands down instead.
        //
        // The floor is deliberately NOT applied in "strip" mode. The strip is a
        // hairline over fullscreen content and hovering it brings the notch
        // back; a 34 px invisible band there would pop the notch out whenever
        // the pointer went near the top of a video.
        Region {
            x: Math.round((root.width - root.hitW) / 2)
            y: 0
            width: Math.round(root.hitW)
            height: Math.round(root.hitH)
        }
    }

    // ---------------------------------------------------------------- state
    // Which page is open is held in one place, not per screen: two monitors
    // must not disagree, and a keybinding cannot say which screen it meant.
    // See ipc/Ipc.qml — that is what `qs ipc call notch …` drives. The pages
    // themselves are drawn by surface/OverlaySurface.qml.
    readonly property real barH: root.barEnabled ? Config.bar.height : 0

    // ------------------------------------------------------------------ mode
    // The notch does not become the pages any more; it gets out of their way.
    //
    //   full    the pill with the clock — the resting state
    //   wide    the pointer is on it: media, clock and date, timer, status pill
    //   hidden  something is open AT the notch, and that surface has the stage
    //   strip   a window is fullscreen: a discreet dark bar, nothing more
    //
    // Hovering the strip brings the full notch back, and leaving returns it —
    // so the clock is never more than a pointer away, even in fullscreen.
    //
    // ⚠️ `wide` IS THE SAME SURFACE GROWING, not a second one, and that is
    // allowed here for a reason that does not hold anywhere else in this shell:
    // the notch has `background-effect` OFF and fills opaquely, so it has no
    // blur and no halo to mis-size. Every translucent surface still has to be
    // exactly as big as what it draws — see OverlaySurface.qml.
    //
    // ⚠️ AND NOT IN THE STRIP. Hovering there already means "bring the notch
    // back"; a gesture may not mean two things, and the one you wanted would be
    // the other one.
    //
    // ⚠️ Only surfaces that open AT the notch hide it. A launcher in the middle
    // of the screen leaves it alone; that is a property of the surface, not a
    // special case here.
    readonly property bool fullscreenHere:
        root.screen ? Services.Compositor.focusedIsFullscreen(root.screen.width,
                                                              root.screen.height)
                    : false

    readonly property string mode:
        !root.notchEnabled ? "full"
      : Ipc.expanded ? "hidden"
      : root.fullscreenHere ? (hover.hovered ? "full" : "strip")
      : hover.hovered ? "wide"
      : "full"

    // The strip is deliberately thin and deliberately still THERE: a fullscreen
    // window with a hairline above it reads as fullscreen, while nothing at all
    // reads as a screen with a missing edge.
    readonly property real stripHeight:
        Math.max(2, Math.round(Config.notch.collapsedHeight / 8))

    // ⚠️ The wide width comes from the CONTENT, so a desktop with nothing
    // playing and no timer gets a narrower shape rather than a wide one with
    // holes in it. `notch.hoverMinWidth` is the floor inside NotchContent.
    readonly property real targetIslandWidth:
        root.mode === "hidden" ? 0
      : root.mode === "strip" ? Config.notch.collapsedWidth * 0.55
      : root.mode === "wide" ? Math.max(Config.notch.collapsedWidth,
                                        notch.implicitWidth)
      : Config.notch.collapsedWidth

    // The island has its OWN height. It used to read `bar.height`, so resizing a
    // bar that was switched off resized the notch — two things that look
    // unrelated moving together is the kind of surprise that costs an evening.
    // With the bar on, the island still cannot be shorter than the bar, or the
    // one shared silhouette would have a step in it.
    readonly property real targetIslandHeight:
        root.mode === "hidden" ? 0
      : root.mode === "strip" ? root.stripHeight
      : root.mode === "wide" ? Math.max(Config.notch.hoverHeight, root.barH)
      : Math.max(Config.notch.collapsedHeight, root.barH)

    // One pair of animated numbers drives the shape, the hit area and the
    // contents, so they cannot disagree about how far open the island is.
    property real islandW: Config.notch.collapsedWidth
    property real islandH: Config.notch.collapsedHeight

    Binding on islandW { value: root.targetIslandWidth }
    Binding on islandH { value: root.targetIslandHeight }

    // Soft, and deliberately not springy: the brief rules out overshoot.
    Behavior on islandW {
        enabled: Theme.animate
        NumberAnimation { duration: Theme.durBase; easing.type: Theme.easingMove
            easing.overshoot: Theme.overshootMove }
    }
    Behavior on islandH {
        enabled: Theme.animate
        NumberAnimation { duration: Theme.durBase; easing.type: Theme.easingMove
            easing.overshoot: Theme.overshootMove }
    }

    // Brings the full notch back while the pointer is on the strip, and opens
    // the wide shape the rest of the time. On the window rather than on the
    // island, so the thin strip is easy to find.
    //
    // ⚠️ THE HIT REGION GROWS WITH THE SHAPE, which is what keeps the wide state
    // stable: the mask is built from `hitW`/`hitH` above, and those track the
    // animated island. If it did not, the pointer would leave the collapsed
    // rectangle the moment the shape opened past it and the notch would flicker
    // between the two sizes.
    //
    // It used to say `hitArea` here, and that was the same rectangle only
    // because the window tracked the island. The window is fixed now — see the
    // note on `implicitWidth` — so the region is built from the shape directly.
    HoverHandler { id: hover }

    Silhouette {
        anchors.fill: parent
        barHeight: root.barH
        islandWidth: root.islandW
        islandHeight: root.islandH
        // Passed whole; Silhouette clamps it against its own geometry, which is
        // the only place that knows how much room is left. Clamping twice, with
        // two different limits, is how the two ended up disagreeing before.
        // The shoulders curve INSIDE `islandWidth`, so they never need room
        // outside the surface — see the note on implicitWidth above.
        flare: root.notchEnabled ? Config.notch.flare : 0
        // ⚠️ Follows the MODE, not one fixed number. A corner is a proportion of
        // the shape, and the hovered shape is three times as tall — the
        // collapsed 9 px on a 96 px pill reads as a box with the edges knocked
        // off. Silhouette clamps whatever it is given against its own geometry,
        // so this only ever asks.
        cornerRadius: root.mode === "wide" ? Config.notch.hoverCornerRadius
                                           : Config.notch.cornerRadius
        Behavior on cornerRadius {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
        }
        // The reference calls for a near-black island that stands clearly
        // apart from what is behind it — panelBg sat so close to the desktop
        // backdrop that the shape was invisible on screen.
        fill: Theme.bgDeep
    }

    // The clickable region: the bar strip plus the island. Kept as plain items
    // so the mask follows the same geometry the shape does.
    Item {
        id: hitArea
        anchors.fill: parent

        Item {
            id: barStrip
            width: parent.width
            height: root.barH
            visible: root.barEnabled

            BarContent {
                anchors.fill: parent
                hostWindow: root
            }
        }

        Item {
            id: island
            x: (parent.width - root.islandW) / 2
            y: 0
            width: root.islandW
            height: root.islandH
            visible: root.notchEnabled
            clip: true

            // ⚠️ THE WHOLE ISLAND ANSWERS, and it has to be said here because it
            // has now been wrong in both directions. For a while a single status
            // pill inside the hovered row was the only thing that opened the
            // quick panel; the brief that replaced it is "wenn man auf die Notch  english-ok: quoted brief
            // gehovert hat, soll es egal sein, wo man in dem Fenster hinklickt". english-ok: quoted brief
            // The pill was then deleted — and nothing took over, so for one
            // release a click on the notch did nothing at all. A handler on the
            // island is the shape that cannot rot that way: it is the drawn
            // shape itself, so it cannot be narrower than what is lit.
            //
            // `enabled` rather than a mask change, for the reason spelled out at
            // the top of this file: the region stays put in every mode, because
            // emptying it makes the click fall through to the fullscreen
            // ClickCatcher, which closes whatever is open. Standing the handler
            // down leaves a click that does nothing, which is what "hidden" and
            // "strip" want. "full" is included as well as "wide": in fullscreen
            // a hover yields "full", not "wide", and on a touchscreen there is
            // no hover to yield anything.
            TapHandler {
                enabled: root.mode === "wide" || root.mode === "full"
                onTapped: Ipc.toggle("quick")
            }

            // What the notch shows: the clock at rest, and the wide row while
            // the pointer is on it. The pages moved to
            // surface/OverlaySurface.qml — see the note there for why the island
            // stopped morphing into them.
            NotchContent {
                id: notch
                anchors.fill: parent
                // Nothing but the clock and the hovered row live here, so `page`
                // stays empty.
                page: ""
                // The clock moves into the island exactly when the bar is not
                // there to hold it — and never while the notch is a strip,
                // where there is no room for it.
                showClock: !root.barEnabled && root.mode === "full"
                wide: root.mode === "wide"
                hostWindow: root
                opacity: (root.mode === "full" || root.mode === "wide") ? 1 : 0
                Behavior on opacity {
                    enabled: Theme.animate
                    NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                }
            }
        }
    }

    // ------------------------------------------------------------- triggers
    // A volume change opens the volume page; a notification opens that one.
    // Both then float under the notch, and the notch steps aside while they
    // are up — see `mode` above.
    //
    // ⚠️ A NOTIFICATION NO LONGER OPENS THE NOTCH. It used to: an arriving
    // message called Ipc.show("notifications"), which took over whatever the
    // notch was showing and then closed again after 1.6 s, so the message was
    // both an interruption and gone before it could be acted on. Toasts have
    // their own surface now (ui/notif/ToastSurface.qml), in the top-right,
    // where they leave the notch alone — which is also the stated rule: only
    // surfaces that open AT the notch displace it.
    //
    // The reference that STARTS the notification server moved with it, into
    // Shell.qml. It used to live here, which quietly meant there was no
    // notification daemon at all on a machine with the notch switched off.

    // The on-screen readouts for volume and brightness. `surfaces.osd` is what
    // switches them off — it had been sitting in the config with nothing
    // reading it since M4, so turning it off changed nothing and the setting
    // was a lie. The keys still work; they just stop showing a panel about it.
    //
    // ⚠️ AND NOT WHILE A SURFACE IS ALREADY SHOWING THAT SLIDER. This is his
    // report of 07.08.2026: "wenn ich den lautstärke regler bewege soll man im   english-ok: the report, quoted
    // quickpanel bleiben". Dragging the volume row inside the quick panel        english-ok: the report, quoted
    // changed the volume, which fired this, which replaced the whole panel with
    // the one-slider readout — the page vanished from under the finger.
    //
    // The condition is not "who changed it" but "is something already showing
    // it". Tracking the origin would mean a flag set by every caller and
    // cleared by hand, and the first one to forget it brings the bug back. The
    // quick panel HAS a volume row, so the readout has nothing to add there.
    //
    // ⚠️ `Ipc.page`, not a property of this surface: the quick panel and this
    // readout are two pages of the same notch, and which one is up is the
    // notch's business. Reading it here is reading the same value the page
    // switch reads.
    readonly property bool sliderAlreadyVisible: Ipc.page === "quick"

    // ⚠️⚠️ THE FIRST VALUE IS NOT A CHANGE, AND THAT IS WHY THE DESKTOP CAME UP
    // SHOWING A VOLUME SLIDER. His report: "wenn ich den laptop neu starte       // english-ok: the report, quoted
    // startet sich nicht als erstes die shell sondern oben ein audio regler …    // english-ok: the report, quoted
    // so ein mini audio dings statt der notch".                                  // english-ok: the report, quoted
    //
    // Nothing was wrong with the readout. PipeWire reports the current volume
    // once when it connects, `volume` goes from its initial default to the real
    // level, and that is a change by every measure QML has — so the OSD did
    // exactly what it was built to do, at the one moment nobody asked it
    // anything. And because an OSD page DISPLACES the notch, the first thing on
    // the screen after a boot was a slider where the clock belongs.
    //
    // ⚠️ ONE FLAG PER PROPERTY, not one for both. `volume` and `muted` each
    // arrive once at connect; a single flag would swallow the first and let the
    // second through, so a boot would still flash the panel.
    //
    // ⚠️ NOT A TIMER. "Ignore anything in the first second" is a guessed
    // duration, and the rule here is to wait for the thing rather than for a
    // number — on a slow machine the initial value can arrive later than any
    // window worth choosing, and then the fault is back and only sometimes.
    //
    // ⚠️ WHAT THIS DOES NOT COVER, said rather than hidden: if the service is
    // already `available` and has already delivered its level before this
    // surface exists, the first signal we see is a real change and is swallowed.
    // That costs one missing OSD directly after a shell restart, which is the
    // cheaper of the two failures by a distance.
    property bool volumeSeen: false
    property bool mutedSeen: false

    Connections {
        target: Services.Audio
        enabled: Services.Audio.available && root.notchEnabled
                 && Config.surfaces.osd && !root.sliderAlreadyVisible
        function onVolumeChanged() {
            if (!root.volumeSeen) { root.volumeSeen = true; return }
            Ipc.show("volume")
        }
        function onMutedChanged() {
            if (!root.mutedSeen) { root.mutedSeen = true; return }
            Ipc.show("volume")
        }
    }
}
