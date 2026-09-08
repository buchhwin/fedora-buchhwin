// What the island used to become: a surface of its own, floating under the notch.
//
// The island morphing into every page was the original design, and it was right
// for the volume readout it was drawn from. It stopped being right once the
// pages grew: a calendar is not a notch that got bigger, and asking one shape to
// be both meant the notch could never simply be a notch.
//
// So the pages live here now, and the notch gets out of the way while one is
// open (see ShellSurface's `mode`). Three things fall out of that, all of them
// improvements rather than compromises:
//
//   * The notch is only ever notch-sized, so its blur and shadow are too.
//   * This surface is only ever page-sized, for the same reason.
//   * Neither has to animate into a shape the other needs.
//
// ⚠️ THE SURFACE IS EXACTLY AS BIG AS WHAT IT DRAWS. From niri's own docs on
// layer rules: "niri has no way of knowing about invisible margins, and will
// draw the shadow behind the entire surface." Blur behaves the same way. A
// surface with a transparent border therefore gets a blurred, colour-fringed
// halo — which is precisely the "the colours bug out around it" that was
// reported for the notch.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../config"
import "../../ipc"
import "../common"
import "../notch"

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    // Public interface: config.kdl attaches the blur, shadow and corner radius
    // rules to this namespace. Renaming it here without renaming it there
    // loses all three silently.
    WlrLayershell.namespace: "buchhwin-overlay"
    // ⚠️ `Overlay`, NOT `Top`, AND THAT IS THE WHOLE PANEL'S USABILITY. The
    // click-catcher — a fullscreen surface whose entire job is to swallow a
    // click and close the panel — was also on `Top`, and Shell.qml creates it
    // AFTER this one. wlr-layer-shell stacks within a layer by creation order,
    // so the catcher sat on top of the panel and ate every click meant for it —
    // "ich geh z. B. auf Medien oder auf Settings, schließt sich das Fenster und ich komme nicht in die Tab".  // english-ok: the report, quoted
    // Measured with `niri msg layers`: both namespaces in the Top layer, with
    // nothing deciding between them but the order they were made in.
    //
    // Raising the panel a layer is the fix rather than reordering the loaders,
    // because order is an accident and a layer is a promise. ShellSurface
    // already does exactly this when a window goes fullscreen.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.wantsKeys ? WlrKeyboardFocus.OnDemand
                                                : WlrKeyboardFocus.None

    // Pages that are typed into need the keyboard; the rest must not steal it,
    // or opening the volume readout would take focus away from your editor.
    // ⚠️ THIS WHITELIST IS WHY ESC WORKED ON SOME PAGES AND NOT OTHERS, and it
    // was reported exactly that way: "bei manchen nur Esc, bei manchen nix".      // english-ok: quoted brief
    // A page that is not named here never receives keyboard focus, so its Esc
    // handler — if it even had one — could never fire. Nine of sixteen pages had
    // no handler and five of those could not have used one.
    //
    // The split is not "which page has a text field" but "did you OPEN this, or
    // did it appear at you". Volume, brightness and the microphone readout are
    // raised BY a key you just pressed and dismiss themselves; taking the
    // keyboard for them would pull focus out of the editor mid-sentence, which
    // is the fault the original comment is guarding against. Everything you open
    // on purpose can be closed with Esc.
    // ⚠️⚠️ AND IT DRIFTED AGAIN, IN EXACTLY THE WAY THE PARAGRAPH ABOVE
    // DESCRIBES. `emoji` and `tasks` were added as pages, given a key each
    // (`Mod+period` and `Ctrl+Shift+Escape`) and given a TEXT FIELD each with
    // `focus: true` — and neither was added here. So the emoji search box and
    // the task filter could not receive a single keystroke, and their Escape
    // handlers could never fire. Found on 10.08.2026 by comparing the eighteen
    // verbs in Ipc.qml against the thirteen names in this list.
    //
    // Both are unambiguously in the "did you OPEN this" half of the split: you
    // press a key to summon them and then type into them.
    readonly property bool wantsKeys:
        Ipc.page === "event" || Ipc.page === "wallpaper" || Ipc.page === "session"
        || Ipc.page === "theme"
        || Ipc.page === "calendar" || Ipc.page === "quick"
        || Ipc.page === "clipboard" || Ipc.page === "calculator"
        || Ipc.page === "notifications" || Ipc.page === "timer"
        || Ipc.page === "tray" || Ipc.page === "workspaces"
        || Ipc.page === "monitors"
        || Ipc.page === "media"
        || Ipc.page === "emoji" || Ipc.page === "tasks"

    anchors { top: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"                    // literal-ok: absence of colour

    // ⚠️ AT THE TOP EDGE, WITH NO GAP — and this is a bug fix, not a style
    // choice. It used to sit below the notch with the island's own gap under
    // it, which left a band at the top of the screen that belonged to the
    // fullscreen ClickCatcher. Measured with a real pointer, one row at a time:
    // a click at y=41 closed the panel and a click at y=44 did not. The tab row
    // is at y=79. So aiming at a tab and landing a few pixels high shut the
    // window — which is exactly the "I click on Media or Settings and it
    // closes" that was reported, and it was nothing to do with the tabs.
    //
    // With the panel at the edge there is no dead band left to miss into, and
    // it also gives what the brief asks for: the surface grows out of the notch
    // rather than appearing under it. The notch is hidden while a page is open,
    // so nothing is covered that anybody is looking at.
    margins.top: 0

    // ⚠️⚠️ THE SIZE IS TAKEN ONCE THE LAYOUT HAS STOPPED MOVING, not on every
    // measurement — and this is the last visible step of the stutter.
    //
    // Bound straight to `card.implicitWidth` the window followed the layout
    // through BOTH of its passes. Measured with WAYLAND_DEBUG on one opening of
    // the quick panel:
    //
    //     set_size(150, 34)     the idle shape
    //     set_size(672, 306)    first pass
    //     set_size(712, 376)    second pass — exactly pagePadding * 2 wider
    //
    // The 40 px is the circle NotchContent's loader documents: a page is
    // measured inside a width that came from the page's own measurement, so the
    // two only agree after a second pass. That second `set_size` lands WHILE the
    // scale-and-fade is running, so the card visibly grows a second time in the
    // middle of its own animation. Not a stutter in the numbers — a re-target.
    //
    // `Qt.callLater` collapses repeated calls in the same turn of the event
    // loop into one, so both passes are absorbed and the window is told the
    // final size once. It does NOT fix the circle — that needs pages with a
    // natural width, which is a change to every page — it stops the circle from
    // reaching the compositor.
    //
    // ⚠️ NOT a Timer with a duration. Guessing a number that is "long enough for
    // the layout" is the flake that comes back on a slower machine; callLater is
    // ordering, and ordering is what the fault is made of.
    property real settledW: 1
    property real settledH: 1

    // ⚠️⚠️ B68 · IT KEEPS LOOKING UNTIL THE NUMBER STOPS MOVING, and that loop is
    // the fix. His report: "wenn man WLAN oder Bluetooth ausklappen geht alles   // english-ok: the report, quoted
    // wenns man einklappt bleibt die neue Größe und das Fenster geht nicht       // english-ok: the report, quoted
    // wieder auf die ursprungsgröße zurück".                                     // english-ok: the report, quoted
    //
    // `Qt.callLater` runs at the end of the current event-loop turn. A QML layout
    // re-measures in its POLISH pass, which is later than that — so this used to
    // sample a height the layout had not finished computing.
    //
    // ⚠️ AND THAT IS WHY IT WAS ASYMMETRIC, which is the part that made it look
    // like a drawer bug rather than a timing one. OPENING a drawer is followed by
    // more changes — the list builds, rows arrive — and each one schedules
    // another settle, so a stale first reading gets corrected on its own. CLOSING
    // one is the LAST change there is: nothing follows to correct it, so the
    // window kept the size it had while the drawer was still up.
    //
    // Measured on the lab VM with BUCHHWIN_SHELL_FAKE giving the sound drawer
    // real entries — the lab VM has no sound card, which is why this could not be
    // reproduced here for a whole round:
    //
    //     drawer shut   712 416
    //     drawer open   712 604
    //     shut again    712 604      <- stuck, exactly as reported
    //
    // ⚠️⚠️ IT WATCHES UNTIL THE NUMBER STOPS MOVING AND THEN WRITES ONCE. The
    // order of those two matters more than anything else in this file, and
    // getting it backwards is what "das fenster wird so ne 1ms groß und dann     // english-ok: the report, quoted
    // sofort wieder klein" was.                                                  // english-ok: the report, quoted
    //
    // `pending` is what the last reading saw. Two readings that agree mean the
    // layout has finished, and only then does the window hear about it. Rule 4's
    // "wait until nothing changes any more", with the write on the far side of
    // the wait rather than inside it.
    //
    // ⚠️⚠️ AND WHAT THIS DOES **NOT** FIX, said plainly because the obvious
    // assumption is wrong. It was written against his report that the panel
    // "wird so ne 1ms groß und dann sofort wieder klein" on every button —      // english-ok: the report, quoted
    // on the theory that a half-settled size was reaching the compositor.
    //
    // MEASURED, with the `resizes` counter below and the previous version as a
    // control: ONE resize per press, before and after. The theory was wrong and
    // the flash is not a second `set_size`. This shape is kept because it states
    // its intent honestly — publish a number once it has stopped moving.
    //
    // ⚠️⚠️ AND THE SENTENCE THAT USED TO FOLLOW WAS WRONG, WHICH COST A ROUND.
    // It read: "whatever he is seeing is therefore somewhere else: the card's
    // own scale/opacity behaviours, or a layout inside the page." It went into
    // the handover as the next lead, and it could not have been either:
    //
    //   · those behaviours are bound to `Ipc.expanded`, which does NOT change
    //     when a drawer arrow or Show more is pressed — they never run for the
    //     press being complained about;
    //   · the page was innocent too. The card was drawn from its own request
    //     while the surface was still the old size, so the pane changed size
    //     under the content for the length of a Wayland round trip. Fifty-five
    //     rendered frames on the worst press, measured per frame; see the note
    //     on `anchors.fill` at the card itself.
    //
    // The reasoning error is worth more than the fix: "one `set_size` per press"
    // was a true measurement, and it was read as "the size is not involved".
    // `resizes` is incremented on the FAR SIDE of the wait above, so it cannot
    // see anything that happens during it. A number that cannot fall in the
    // presence of the fault does not rule the fault out.
    property real pendingW: 0
    property real pendingH: 0
    function settleSize() {
        var w = Math.max(1, card.implicitWidth)
        var h = Math.max(1, card.implicitHeight)
        if (w !== root.pendingW || h !== root.pendingH) {
            // Still moving. Remember it, look again, publish nothing.
            root.pendingW = w
            root.pendingH = h
            Qt.callLater(root.settleSize)
            return
        }
        root.settledW = w
        root.settledH = h
        root.resizes++
    }

    // ⚠️ HOW MANY TIMES THE WINDOW WAS TOLD A NEW SIZE. One per press is right;
    // more than one is a frame at the wrong size, which is what a flash IS.
    //
    // It is a counter rather than a screenshot because the thing being measured
    // lives for one frame: sampling the size over IPC takes ~100 ms per reading
    // and cannot see it at all — measured, with the old code as a control, and
    // both came back identical. A check that cannot tell the two apart is not a
    // check, and this one replaced it.
    property int resizes: 0

    // ⚠️⚠️ AND `resizes` CANNOT SEE THE FLASH EITHER — it is incremented on the
    // far side of the settle wait above, so "one resize per press" is true and
    // rules out nothing. The paragraph further up concluded from it that the
    // flash "is not here" and pointed at the card's scale/opacity behaviours
    // instead. That conclusion was wrong twice over, and both halves are
    // measured:
    //
    //   · those two behaviours are bound to `Ipc.expanded`, which does not
    //     change when a drawer arrow or Show more is pressed. They do not run.
    //   · what DOES happen is that `card.implicitWidth/Height` follow the page
    //     immediately while this window's size follows two event-loop turns
    //     later. In between there is at least one rendered frame in which the
    //     card — and `GlassPane`, which fills it — is drawn at the new size
    //     inside a surface that is still the old one, and `anchors.centerIn`
    //     shifts it by half the difference on top of that.
    //
    // So: a per-frame sampler, which is the instrument this project wrote down
    // as missing ("ein FrameAnimation-Abtaster in QML, der je gezeichnetem Bild // english-ok: the note, quoted
    // mitschreibt") and never built. `grim` manages ~10 frames a second and an  // english-ok: the note, quoted
    // IPC round trip ~10; a frame callback sees every one of them.
    property int frames: 0
    property int offFrames: 0
    property int worstW: 0
    property int worstH: 0

    // ⚠️⚠️ B81 · AND THE SECOND THING THAT MOVES, which the size counters above
    // cannot see at all. His report: "wenn ich auf show more oder show less      // english-ok: the report, quoted
    // clicke buggen alle icons aus dem quickpanel nach unten und dann ganz       // english-ok: the report, quoted
    // schnell wieder nach oben". The card can be exactly the right size in every // english-ok: the report, quoted
    // frame and the CONTENT still slide inside it — so `off` stays 0 and the
    // page visibly jumps.
    //
    // The range of the content's y over one press is that jump, in pixels. At
    // rest it is 0, and that is the control every reading here is measured
    // against.
    property int shiftMin: 0
    property int shiftMax: 0
    // ...and the same question one level in: the page loader inside the content
    // is centred as well, so it can slide even when the content does not.
    property int pageShiftMin: 0
    property int pageShiftMax: 0
    function resetFrameProbe() {
        root.frames = 0; root.offFrames = 0; root.worstW = 0; root.worstH = 0
        var y = Math.round(content.y)
        root.shiftMin = y; root.shiftMax = y
        var py = Math.round(content.pageYProbe)
        root.pageShiftMin = py; root.pageShiftMax = py
    }

    FrameAnimation {
        // Only while something is open. A sampler that runs on an idle desktop
        // is the polling rule 8 exists to forbid.
        running: Ipc.expanded && root.visible
        onTriggered: {
            root.frames++
            var y = Math.round(content.y)
            if (y < root.shiftMin) root.shiftMin = y
            if (y > root.shiftMax) root.shiftMax = y
            var py = Math.round(content.pageYProbe)
            if (py < root.pageShiftMin) root.pageShiftMin = py
            if (py > root.pageShiftMax) root.pageShiftMax = py
            var dw = Math.round(card.width) - Math.round(root.width)
            var dh = Math.round(card.height) - Math.round(root.height)
            if (dw === 0 && dh === 0)
                return
            root.offFrames++
            if (Math.abs(dw) > Math.abs(root.worstW)) root.worstW = dw
            if (Math.abs(dh) > Math.abs(root.worstH)) root.worstH = dh
        }
    }

    Connections {
        target: card
        function onImplicitWidthChanged() { Qt.callLater(root.settleSize) }
        function onImplicitHeightChanged() { Qt.callLater(root.settleSize) }
    }

    implicitWidth: root.settledW
    implicitHeight: root.settledH

    mask: Region { item: card }

    // ⚠️ ESC LIVES HERE, ONCE, rather than in every page. Seven of sixteen pages
    // carried their own handler and nine did not, so closing a surface depended
    // on which surface it was — and every new page would have had to remember.
    // The host knows how to close itself; a page does not need to.
    //
    // Pages keep their own handlers where Esc means something ELSE first (the
    // calculator clears, the calendar returns to today). Those consume it and
    // this never sees it, which is the correct precedence: the innermost thing
    // that has an answer wins.
    //
    // ⚠️⚠️ AND UNTIL TODAY THAT PARAGRAPH WAS FALSE FOR EVERY PAGE. Measured: a
    // `console.warn` as the first line of QuickPage's Esc handler printed
    // NOTHING with the panel open and Escape pressed. `card` takes the focus and
    // nothing hands it on — NotchContent and the page Loader are plain Items, so
    // the page was never in the key chain at all. Seven pages had a handler and
    // not one of them could fire; the comment above described an intention.
    //
    // ⚠️ `focus: true` ON THE TWO ITEMS IN BETWEEN WAS TRIED AND MEASURED AND DID
    // NOT HELP. Several items in one focus scope are not a chain — exactly one
    // of them holds focus, and it stays `card`, because `card` is the one that
    // asked for it.
    //
    // The chain is explicit instead. `Keys.forwardTo` walks a list BEFORE the
    // item's own handlers run, so a key goes page → card, and `card` only sees
    // what the page did not answer. That is the precedence the paragraph above
    // promised, and now it is a mechanism rather than a hope.
    //
    // ⚠️ It also means a page that answers Escape STOPS the panel closing, which
    // is what the calendar (jump to today) and the session page (back out of an
    // armed shutdown) actually want.
    //
    // ⚠️ AND THE BREAK WAS NOT AS TOTAL AS IT FIRST LOOKED — checked page by page
    // rather than generalised from the one that was measured. Four pages call
    // `forceActiveFocus()` on something inside themselves (the calculator's
    // input, the wallpaper and theme grids, the clipboard search), so those had
    // focus all along and their Esc handlers did fire. What could never fire was
    // any page that does NOT grab focus for itself: QuickPage, the calendar, the
    // session page. That is what this chain fixes, and it is why those four
    // handlers stay where they are — they work, and removing a working handler
    // to make a story tidier is how a regression gets committed.
    Item {
        id: card

        focus: true
        Keys.forwardTo: [content]
        Keys.onEscapePressed: Ipc.collapse()

        // ⚠️⚠️ B69 · WHAT IT ASKS FOR AND WHAT IT IS DRAWN AT ARE TWO NUMBERS,
        // AND THIS IS THE LINE THAT SEPARATES THEM.
        //
        // `implicit*` below is the request: it follows the page immediately and
        // is what `settleSize()` watches. `anchors.fill` is the drawing: it can
        // never be anything but the surface's own size.
        //
        // It used to be `anchors.centerIn: parent` with no width or height, so
        // the card sized ITSELF from the request — and `GlassPane` fills the
        // card. Between the page growing and the compositor acknowledging the
        // new surface size there is a Wayland round trip, and for every frame of
        // it the pane was painted at the new size inside a surface that still
        // had the old one, shifted by half the difference on top (centerIn).
        //
        // MEASURED with the per-frame sampler above, one press each, the resting
        // panel as the control that proves the sampler can report zero:
        //
        //     at rest        frames=120  off=0    worst=0x0
        //     sound drawer   frames=102  off=55   worst=0x188
        //     wifi drawer    frames=102  off=46   worst=0x117
        //     show more      frames=101  off=33   worst=0x140
        //
        // Fifty-five painted frames at a size the surface did not have, with
        // `resizes` going up by exactly one each time. That is his "das fenster  // english-ok: the report, quoted
        // wird so ne 1ms groß und dann sofort wieder klein", and it is why the   // english-ok: the report, quoted
        // old counter could say "one resize per press" and be no defence.
        //
        // ⚠️ The content still overflows for those frames — it is simply not
        // rendered, because it is outside the surface. Clipped for two frames
        // and then settling is what "der Inhalt setzt sich in die Form hinein"   // english-ok: the note, quoted
        // means; a pane that changes size underneath it is not.
        anchors.fill: parent

        implicitWidth: content.implicitWidth
        implicitHeight: content.implicitHeight

        // ⚠️ THE CARD SAYS HOW BIG IT IS, and that is a measuring instrument
        // rather than a feature. "The panel jumps a little when I press some of
        // the buttons on the left" is a claim about a NUMBER, and until now that
        // number could only be got at by photographing the screen and counting
        // pixels — which is how the last fix ended up with a floor derived from
        // one hand measurement. `ipc call notch size` per tab turns it into a
        // reading anybody can repeat, before and after.
        Component.onCompleted: { Ipc.notchCard = card; Ipc.notchHost = root }
        Component.onDestruction: if (Ipc.notchCard === card) { Ipc.notchCard = null; Ipc.notchHost = null }

        // The pane, drawn behind the page rather than as the page's own
        // background: a lit rim has to sit on top of the fill, and a Rectangle
        // can only have one flat border colour.
        GlassPane {
            anchors.fill: parent
            radius: Theme.radiusLg
            fill: Theme.panelBg
        }

        // Grows out of nothing rather than appearing: slightly small and
        // slightly high, so it reads as coming from the notch above it. No
        // overshoot — the brief rules out anything springy.
        scale: Ipc.expanded ? 1 : 0.92
        opacity: Ipc.expanded ? 1 : 0
        transformOrigin: Item.Top

        Behavior on scale {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durBase; easing.type: Theme.easingMove
            easing.overshoot: Theme.overshootMove }
        }
        Behavior on opacity {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }
        // ⚠️⚠️ THE SIZE IS SET, NOT ANIMATED, AND THAT IS THE WHOLE REASON THIS
        // SURFACE FEELS DIFFERENT NOW. There used to be a `Behavior` on
        // `implicitWidth` and one on `implicitHeight` here — and this window's
        // own `implicitWidth`/`implicitHeight` are bound to them, so every frame
        // of every open re-sized a Wayland layer surface.
        //
        // That is protocol, not drawing: `set_size` plus an `ack_configure`
        // round trip with niri, a buffer of a new size (the swapchain discarded
        // every frame), a fresh blur and corner-radius calculation for the new
        // geometry, and a new input region. Measured on the VM at 60 Hz, ONE
        // opening of the quick panel: 11 × `set_size`, 9 × `ack_configure`.
        // One per frame. At 144 Hz, about 21.
        //
        // ⚠️ AND UNLIKE THE NOTCH THIS SURFACE CANNOT SIMPLY BE OVERSIZED. The
        // notch has blur and shadow switched off (`surface("buchhwin-notch",
        // notchRadius, false, false)`) so spare room costs nothing there; this
        // one is translucent and blurred, and niri applies both to the WHOLE
        // surface, so a surface bigger than what it draws comes out as the
        // blurred, colour-fringed halo described at the top of this file.
        //
        // So the size lands on the target immediately — ONE re-size per page
        // instead of one per frame — and the motion is carried by `scale` and
        // `opacity` above, which are GPU transforms the compositor never hears
        // about. The card growing from 0.92 while fading in is what "grows out
        // of the notch" actually looks like; the surface underneath it was never
        // the part anybody could see.

        NotchContent {
            id: content
            // ⚠️⚠️ B81 · TOP, NOT CENTRED, AND THE PIXELS SAY WHY. His report:
            // "wenn ich auf show more oder show less clicke buggen alle icons    // english-ok: the report, quoted
            // aus dem quickpanel nach unten und dann ganz schnell wieder nach    // english-ok: the report, quoted
            // oben" — and, the part that names the cause, "das ist ein bug der   // english-ok: the report, quoted
            // davor auch schon links bei der leiste war im quick panel".         // english-ok: the report, quoted
            //
            // `anchors.centerIn` puts this at (card.height - height) / 2. The
            // card is correct in every frame (B69 above), so the size counters
            // see nothing — but while the height is on its way from one value to
            // the other, half of that difference is a vertical slide of the
            // WHOLE page, icon rail included. Measured per drawn frame, with the
            // resting panel as the control that proves the probe can read zero:
            //
            //     at rest            height change 0     shift 0
            //     show more          height change 140    shift 70
            //     sound drawer       height change 188    shift 94
            //     wifi drawer        height change 117    shift 59
            //
            // Exactly half, every time. That is not a symptom that resembles
            // centring, it IS centring, written in pixels.
            //
            // ⚠️ THIS IS THE FOURTH TIME THIS SHAPE HAS SHIPPED — B18 (the icon
            // rail centred in a per-tab height), B38 (the header, one level up),
            // B45 (the panel floor), and now the page inside the card. His own
            // reason from the first one still holds and is the rule:
            // "damit die einzelnen punkte immer an der gleichen stelle sind".    // english-ok: the request, quoted
            //
            // ⚠️ Horizontally it stays centred, and that is not an oversight: the
            // surface itself is centred on screen, so both edges move outward
            // together and nothing slides relative to anything. Only the
            // vertical axis has a fixed edge — the notch above — and content
            // that grows downward from it is what "grows out of the notch" is.
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            page: Ipc.page
            // The clock belongs to the notch, never to a page.
            showClock: false
            hostWindow: root
        }
    }
}
