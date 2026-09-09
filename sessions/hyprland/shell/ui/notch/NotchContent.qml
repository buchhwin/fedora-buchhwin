// What is inside the island: the clock when collapsed, a page when open.
//
// Collapsed content comes straight from the reference screenshot — the clock,
// one line, centred, and nothing else. It is not a widget strip.
import QtQuick
import Quickshell
import "../../theme"
import "../../config"
import "../common"
import "../../common"
import "pages"

Item {
    id: root

    property string page: ""

    // The island's own window, handed down so a tray menu has somewhere to
    // open. Without it a right-click in the tray page does nothing and says
    // nothing — see pages/TrayPage.qml.
    property var hostWindow: null

    // With the bar on, the clock lives out on the strip and the island stays
    // empty. From the plan: "Bar aus: nur Notch — Uhr · Media · Status wandern  english-ok: quoted brief
    // in die Notch." So it is one clock that moves, never two on one screen.
    property bool showClock: true

    // The pointer is on the notch and nothing is open: it grows and shows what
    // is playing, the time with the date, a running timer and the status pill.
    // See NotchWide.qml. Only ever true in the resting state — ShellSurface owns
    // that decision, because it is the one that knows about fullscreen.
    property bool wide: false

    readonly property bool expanded: page !== ""

    // The island asks the content how big it wants to be, never the reverse —
    // on BOTH axes. The page must never read the island's current size back, or
    // the two would chase each other; pages that need a reference size use the
    // configured number instead (see pages/WallpaperPage.qml).
    //
    // ⚠️ A page may call itself COMPACT, and then the reference geometry from
    // the settings screenshot (619 × 135) does not apply to it. That geometry
    // describes a page you read; the volume readout is a page you glance at,
    // and forcing it to 619 × 135 turned a discreet pill into a slab that
    // covered a sixth of the screen. Two floors, chosen by the page:
    //
    //   normal   minExpandedWidth × expandedHeight   calendar, wallpaper, tray
    //   compact  collapsedWidth   × bar.height       volume, and anything else
    //                                                that is a readout
    readonly property bool pageIsCompact:
        loader.item && loader.item.compact === true

    readonly property real floorWidth:
        pageIsCompact ? Config.notch.collapsedWidth : Config.notch.minExpandedWidth

    // ⚠️ THE HEIGHT FLOOR IS THE COLLAPSED HEIGHT FOR EVERY PAGE, NOT
    // `expandedHeight`, and that is the second half of "der abstand passt nicht".  english-ok: the report, quoted
    //
    // `expandedHeight` (135) was being applied as a MINIMUM to every page you
    // read, and the loader is centred — so a page whose contents are shorter got
    // the difference split above and below it as dead space. Measured on the VM,
    // panel height from an image diff against the empty desktop:
    //
    //   media 161   tray 161   calculator 161      <- all three on the floor
    //   wallpaper 165   session 168   timer 218
    //   notifications 232   clipboard 324   calendar 383
    //
    // Three pages sat exactly on it (161 = 135 plus the shadow the diff also
    // sees). The 135 in the reference describes a page with something ON it, not
    // a rule that a page with three lines must be as tall as one with a month
    // grid — the WIDTH floor is what keeps the shape recognisable, and that one
    // stays.
    //
    // The collapsed height remains as a floor so a page can never come out
    // shorter than the notch it grew from.
    readonly property real floorHeight: Config.notch.collapsedHeight

    // What the loaded page asks for, before this item's floor and padding are
    // applied — read by `ipc call notch chain` so a height that fails to shrink
    // can be traced to the link that is holding it.
    readonly property real pageHeightProbe:
        (loader.item && loader.item.implicitHeight) ? loader.item.implicitHeight : 0

    // ⚠️ B81 · WHERE the page sits, not only how tall it is. The same vertical
    // slide that moved the whole page inside the card can happen again one level
    // in, because this loader is centred too — and a reading that only has
    // heights cannot tell the two apart. Sampled per drawn frame by the surface.
    readonly property real pageYProbe: loader.y

    readonly property real pagePadding:
        pageIsCompact ? Theme.space3 : Theme.space5

    // The hovered shape asks its own content how wide it wants to be, exactly
    // as a page does — so a desktop with no music and no timer gets a narrower
    // notch instead of a wide one with gaps in it. `hoverMinWidth` is the floor
    // from the reference screenshot, not the width.
    readonly property real wideWidth:
        wideLoader.item
            ? Math.max(Config.notch.hoverMinWidth,
                       wideLoader.item.implicitWidth + Theme.space5 * 2)
            : Config.notch.hoverMinWidth

    implicitWidth: expanded && loader.item
        ? Math.max(floorWidth, loader.item.implicitWidth + pagePadding * 2)
        : wide ? wideWidth
        : Config.notch.collapsedWidth

    implicitHeight: expanded && loader.item
        ? Math.max(floorHeight, loader.item.implicitHeight + pagePadding * 2)
        : wide ? Config.notch.hoverHeight
        : Config.notch.collapsedHeight

    // Collapsed: the clock — but only when the bar is not already showing one.
    //
    // ⚠️ THE CLOCK, AND ONLY THE CLOCK. A running timer used to take its place
    // here, on the argument that a countdown you cannot see is an alarm you
    // forget you set. That argument was mine and it was wrong twice over.
    // The brief: "eingeklappt steht die UHR darin … eine Zeile, sonst nichts".  // english-ok: the specification, quoted
    // The answer when it shipped: "am besten sollte die Notch immer die Uhrzeit anzeigen".  // english-ok: quoted
    // A surface with one line has room for one meaning, and this one's meaning
    // is the time of day.
    //
    // What a running timer gets instead is a place in the WIDE shape below,
    // which the notch grows into while the pointer is on it — see NotchWide.qml.
    // It used to be a separate pill in its own window beside the notch; that
    // surface is gone, and with it the awkwardness that moving the pointer onto
    // the pill ended the hover and took the pill away.
    BarText {
        anchors.centerIn: parent
        visible: !root.expanded && !root.wide && root.showClock
        opacity: (root.expanded || root.wide) ? 0 : 1
        color: Theme.fg
        text: Clock.time(clock.date)
        Behavior on opacity {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }
    }

    // ⚠️ The precision comes from the same singleton as the format, and that is
    // not tidiness. Minutes means this wakes on the minute boundary and sleeps
    // in between; asking for a seconds digit while keeping minute precision
    // would show one that changes once a minute, which is worse than not
    // offering it at all.
    SystemClock { id: clock; precision: Clock.precision }

    // The hovered contents. A Loader for the same reason the pages are: a
    // desktop nobody is pointing at should not be holding an album cover, a
    // network icon and a battery reading in memory.
    //
    // ⚠️ It fades and settles like a page rather than appearing, so the notch
    // reads as one shape opening rather than as a box that filled up.
    Loader {
        id: wideLoader
        anchors.centerIn: parent
        width: parent.width - Theme.space5 * 2
        // ⚠️ ALWAYS LOADED, AND THIS IS THE NOTCH'S "BUGGY ANIMATION". It used
        // to be `active: root.wide` with `asynchronous: true`, and the island's
        // width is `max(collapsedWidth, notch.implicitWidth)` — so on hover:
        //
        //   1. mode becomes "wide" and the width animation STARTS
        //   2. …toward a width that does not include this content, because it
        //      does not exist yet — asynchronous means "next frame at the
        //      earliest"
        //   3. the content arrives, implicitWidth jumps
        //   4. the running animation is re-targeted mid-flight and goes again
        //
        // Two stages, every single time. And again whenever album art, the
        // battery or the network icon resolve, because each of those changes
        // implicitWidth once more.
        //
        // No amount of tuning durations or easing curves could fix that — it is
        // a load ORDER, not a motion. Keeping it built means the width is known
        // before the first hover, so the animation has one target and runs once.
        // The cost is one NotchWide per screen held in memory; the services it
        // reads are singletons that are running anyway.
        active: true
        visible: root.wide && !root.expanded
        sourceComponent: wideContent

        opacity: root.wide && !root.expanded ? 1 : 0
        scale: root.wide && !root.expanded ? 1 : 0.94
        transformOrigin: Item.Center

        Behavior on opacity {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }
        Behavior on scale {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
        }
    }

    Component {
        id: wideContent
        NotchWide { now: clock.date }
    }

    // ⚠️ THE MIDDLE LINK OF THE KEY CHAIN, and without it the page below is not
    // in it. OverlaySurface forwards keys to this item; this forwards them to
    // whatever page the loader is holding. Both hops are needed — `card` holds
    // the focus and neither of the items under it ever will, which is why
    // setting `focus: true` on them was tried and measured and changed nothing.
    //
    // An empty list while nothing is loaded rather than a null entry: QML walks
    // this list and a null in it is a warning per key press.
    Keys.forwardTo: loader.item ? [loader.item] : []

    Loader {
        id: loader
        anchors.centerIn: parent


        // ⚠️ THIS IS A CIRCLE, AND IT IS THE CHEAPER END OF ONE. `implicitWidth`
        // above measures the card FROM this loader's content, and this line
        // hands the loader a width derived from the card. So a page is measured
        // inside a width that came from the page's own measurement, and the two
        // only agree after a second pass.
        //
        // The cost is real and it is measured: opening the quick panel produces
        // `set_size(672, 306)` immediately followed by `set_size(712, 376)`, and
        // the 40 px is exactly `pagePadding * 2` — the circle written out in
        // numbers. Two layer-surface re-sizes for one opening instead of one.
        //
        // ⚠️ AND THE OBVIOUS FIX IS WORSE. Reading this loader's own
        // `implicitWidth` here instead closes the loop the other way — the page
        // fills the loader, so the loader's implicit width depends on the width
        // it is being given. `tests/surfaces.sh` caught it in the journal on the
        // first run: `QML Loader: Binding loop detected for property "width"`.
        // A binding loop is unbounded work every frame; a second layout pass is
        // bounded work twice per opening. Kept deliberately, with the number
        // written down rather than the intent.
        //
        // Doing better means pages that declare a natural width instead of
        // filling one, which is a change to every page and not to this line.
        width: parent.width - root.pagePadding * 2

        active: root.expanded

        // ⚠️ SYNCHRONOUS, AND IT IS THE SAME FAULT THE COMMENT ABOVE DESCRIBES —
        // it was fixed for the hovered content and this one was left behind.
        //
        // The page decides the card's size, and the card decides the layer
        // surface's size. Loading it asynchronously means the surface is first
        // told the collapsed size, then a partial size, then the real one, as
        // the page assembles. Measured on the VM, opening the quick panel:
        // `set_size(150, 34)` → `set_size(672, 306)` → `set_size(712, 376)`.
        // Three re-sizes for one opening, and each one is a round trip with
        // The compositor plus a new buffer.
        //
        // It is also what it LOOKS like: the panel arrives at the wrong size and
        // grows twice while you watch. Synchronous costs one page build on the
        // main thread at open time — one page, not the twenty-one that made the
        // settings search freeze, which is a different thing entirely.
        asynchronous: false
        sourceComponent: root.page === "volume" ? volumePage
                       : root.page === "media" ? mediaPage
                       : root.page === "notifications" ? notificationsPage
                       : root.page === "quick" ? quickPage
                       : root.page === "calendar" ? calendarPage
                       : root.page === "tray" ? trayPage
                       : root.page === "workspaces" ? workspacesPage
                       : root.page === "monitors" ? monitorsPage
                       : root.page === "wallpaper" ? wallpaperPage
                       : root.page === "theme" ? themePage
                       : root.page === "event" ? eventPage
                       : root.page === "brightness" ? brightnessPage
                       : root.page === "mic" ? micPage
                       : root.page === "tasks" ? tasksPage
                       : root.page === "emoji" ? emojiPage
                       : root.page === "calculator" ? calculatorPage
                       : root.page === "timer" ? timerPage
                       : root.page === "session" ? sessionPage
                       : root.page === "clipboard" ? clipboardPage
                       : null

        // The shape leads, the contents follow — that is what makes the change
        // read as one movement rather than two things happening at once.
        //
        // Fading alone read as a slideshow: the shape moved, then a picture
        // appeared inside it. The content now settles INTO the shape — it comes
        // up from very slightly small and very slightly low, so the growing
        // island appears to carry it. Both numbers are deliberately tiny; the
        // brief rules out anything that draws attention to itself, and there is
        // no overshoot anywhere, which is the difference between "fluid" and
        // "springy".
        opacity: root.expanded ? 1 : 0
        scale: root.expanded ? 1 : 0.94
        transformOrigin: Item.Center
        y: root.expanded ? 0 : Theme.space2

        Behavior on opacity {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }
        // Slower than the fade, so the content is fully visible while it is
        // still settling rather than arriving already at rest.
        Behavior on scale {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
        }
        Behavior on y {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durBase; easing.type: Theme.easingMove
            easing.overshoot: Theme.overshootMove }
        }
    }

    // ⚠️ `sourceComponent` needs a Component, never an instance. QML accepts an
    // instance without a word of complaint and then never builds the thing.
    Component { id: volumePage; VolumePage {} }
    Component { id: mediaPage; MediaPage {} }
    Component { id: notificationsPage; NotificationsPage {} }
    Component { id: quickPage; QuickPage {} }
    Component { id: calendarPage; CalendarPage {} }
    Component { id: trayPage; TrayPage { hostWindow: root.hostWindow } }
    Component { id: workspacesPage; WorkspacesPage {} }
    Component { id: monitorsPage; MonitorsPage {} }
    Component { id: wallpaperPage; WallpaperPage {} }
    Component { id: themePage; ThemePage {} }
    Component { id: eventPage; EventPage {} }
    Component { id: brightnessPage; BrightnessPage {} }
    Component { id: micPage; MicPage {} }
    Component { id: calculatorPage; CalculatorPage {} }
    Component { id: emojiPage; EmojiPage {} }
    Component { id: tasksPage; TasksPage {} }
    Component { id: timerPage; TimerPage {} }
    Component { id: sessionPage; SessionPage {} }
    Component { id: clipboardPage; ClipboardPage {} }
}
