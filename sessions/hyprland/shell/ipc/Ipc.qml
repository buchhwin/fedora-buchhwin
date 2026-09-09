pragma Singleton

// What the island is showing, and the outside world's handle on it.
//
// One place, not one per screen: two monitors must not disagree about whether
// the notch is open, and a keybinding has no idea which screen you meant. The
// surfaces bind to this; nobody assigns to their own `page`.
//
// Keys live in the compositor (the compositor has no protocol for shell-owned shortcuts),
// so they reach us through `qs -c buchhwin ipc call notch media`. That
// also means the shortcuts keep working when this shell is dead — they simply
// fail to reach anyone, instead of the compositor swallowing them.

import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
// ⚠️ One direction only, and it is this one. services/ never imports ipc/ —
// checked, and services/qmldir exists to keep that boundary — so there is no
// cycle. This file needs exactly one fact from over there: which output the
// user is on when a page is opened.
import "../services" as Services

Singleton {
    id: root

    // "" = collapsed. Any other value names the page.
    property string page: ""
    readonly property bool expanded: page !== ""

    // Pages that close themselves after a moment, because they report
    // something rather than offering something to do.
    //
    // Not called "transient": that is a reserved word in QML, and the error it
    // produces names this file but surfaces two levels up as the useless
    // "Type ShellSurface unavailable".
    readonly property var autoClosing: ["volume", "brightness", "mic", "notifications"]

    // The two that are readouts rather than places: they appear on their own
    // when something changes, and `surfaces.osd` is what stops them doing that.
    // The setting existed with nothing reading it, so switching it off changed
    // nothing at all — which is worse than not having it.
    readonly property var osdPages: ["volume", "brightness", "mic"]

    // ------------------------------------------------------- which screen
    //
    // ⚠️ THE STATE STAYS GLOBAL; ONLY THE TARGET IS NEW. The paragraph at the
    // top of this file is still right — two monitors must not disagree about
    // whether the notch is open. What was missing is the other half: WHICH
    // screen the user meant when they opened it. Without it every screen that
    // passed the monitor filter built its own copy, so on his three-monitor
    // desk the quick panel and the launcher appeared three times at once. With
    // the launcher that is not just noise: it takes WlrKeyboardFocus.Exclusive,
    // so three surfaces grabbed the keyboard.
    //
    // A connector name (DP-2, HDMI-A-1) or "" for "no opinion, show everywhere".
    // Empty is the honest default, not a fallback to guessing: the compositor has no event
    // for focus moving between outputs without a workspace change, so
    // Compositor.activeOutput can legitimately be empty and the old
    // everywhere-behaviour is then exactly right.
    //
    // ⚠️ AND IT HAS ITS READER IN THE SAME COMMIT. `notchHover` sat here once,
    // named a screen, and nothing read it — see the note further down. That is
    // the debt this project has found five times, and tests/key-readers.sh is
    // the tripwire. Read by ui/Shell.qml on the overlay, the click catcher and
    // the launcher.
    property string target: ""

    function show(name) {
        if (root.osdPages.indexOf(name) >= 0 && !Config.surfaces.osd)
            return          // the key still works; it just says nothing about it
        // Set BEFORE the page, so a surface that reacts to `page` in the same
        // frame already sees where it was meant to open.
        root.target = Services.Compositor.activeOutput
        root.page = name
        if (root.autoClosing.indexOf(name) >= 0)
            idle.restart()
        else
            idle.stop()
    }

    function toggle(name) {
        if (root.page === name) root.collapse()
        else root.show(name)
    }

    function collapse() {
        idle.stop()
        root.page = ""
    }

    // ---------------------------------------------------- the quick panel's tab
    //
    // Which of the quick panel's four views is showing. It lives here rather
    // than in the page because things point at it from outside — the bar's
    // network, sound and gear pills all open the panel on the overview, where
    // the switches are — and the page itself is rebuilt every time the surface
    // opens, so a property of its own would forget which tab you were on
    // between openings.
    readonly property int quickOverview: 0
    readonly property int quickMedia: 1
    readonly property int quickNotifications: 2
    readonly property int quickTimer: 3
    // ⚠️ APPENDED, NOT INSERTED. The calendar became a tab of its own when it
    // stopped being squeezed in beside the tiles, and the obvious place for it
    // is second — but these numbers are written into shell.json by nothing and
    // read by the bar, the hot corner and two keybindings. Renumbering the
    // existing four to make the new one sit in the middle would move
    // `quickTimer` under everything that already names it. The RAIL decides the
    // order it is shown in; this is only an identity.
    readonly property int quickCalendar: 4
    // ⚠️ `quickSettings` IS GONE — the switches moved into the overview beside
    // the calendar on 06.08.2026, because the space there was empty and the
    // deep settings are going to M8 anyway. Five tabs became four.
    //
    // Named constants are what made that a small change: everything that used
    // to point at the settings tab now points at `quickOverview`, and the
    // compiler found every one of them. Numbers scattered through five files
    // would not have.
    property int quickTab: quickOverview

    // Open the panel on a named tab — or, if it is already open on that tab,
    // close it, so the gear behaves like every other toggle in the shell.
    function showQuick(tab) {
        if (root.page === "quick" && root.quickTab === tab) {
            root.collapse()
            return
        }
        root.quickTab = tab
        root.show("quick")
    }

    // ------------------------------------------------- the pointer on the notch
    //
    // ⚠️ `notchHover` IS GONE. It named the screen whose notch was under the
    // pointer, and it existed only so Shell.qml could create the pill beside it
    // on that screen. The notch now grows in place instead, so the state stayed
    // inside the one surface that owns it (ShellSurface's `mode`) and this key
    // had no reader left. A property nothing reads is the debt this project has
    // found five times.

    // ------------------------------------------------------------- launcher
    //
    // ⚠️ NOT A PAGE, AND THAT IS THE WHOLE POINT. Pages open AT the notch, so
    // the notch steps aside while one is up (see ui/surface/ShellSurface.qml's
    // `mode`). The launcher opens in the MIDDLE of the screen, and the brief is
    // explicit that a surface there leaves the notch alone. Making it a page
    // would hide the clock to show a program list on the other half of the
    // screen.
    //
    // It is also the one surface that can be open at the same time as a page,
    // which a single `page` string cannot express.
    property bool launcher: false

    // ⚠️ The launcher sets `target` too, and it is the surface that needed it
    // most: WlrKeyboardFocus.Exclusive on three screens at once is three
    // surfaces holding the keyboard.
    function showLauncher() {
        root.target = Services.Compositor.activeOutput
        root.launcher = true
    }
    function hideLauncher() { root.launcher = false }
    function toggleLauncher() {
        if (root.launcher) root.hideLauncher()
        else root.showLauncher()
    }

    // ------------------------------------------------------------- settings
    //
    // ⚠️ NOT A PAGE EITHER, AND FOR A STRONGER REASON THAN THE LAUNCHER'S. The
    // settings window is a REAL the compositor window: you move it, you push it to another
    // workspace, you leave it open beside the thing you are changing. A single
    // `page` string can express none of that.
    //
    // And it has to be a window rather than a surface floating over everything,
    // because half of what it sets is how OTHER windows look — opacity, corner
    // radius, gaps, blur. A pane on the overlay layer would cover the only
    // evidence that the setting did anything.
    property bool settingsOpen: false

    // ⚠️ WHICH PAGE, and it is a property rather than a call because the window
    // may not exist yet. `open` and a page name arrive together; the content is
    // built by a Loader on `settingsOpen`, so a function call into it would be
    // a call into nothing on the first open. A property the content watches is
    // the same shape `notch.page` already uses, and it works in both orders.
    property string settingsPage: ""

    // ⚠️⚠️ THE WINDOW SAYS WHERE ITS OWN CONTROLS ARE, AND THAT IS WHAT MAKES A
    // CHECKER ABLE TO PRESS ONE. Every checker in this project drives the
    // FUNCTION — call the verb, set the property, assert the file. None of them
    // pressed anything, and that blind spot kept B20 green for weeks and B39 for
    // three rounds: both were "the press never reaches the function", which a
    // checker that skips the press cannot see by construction. Both were found
    // by hand with ydotool in the end.
    //
    // A click needs a coordinate, and under Wayland a client does not know where
    // its window sits on the screen — so the two halves come from the two
    // parties that each know one: the compositor says where the WINDOW is
    // (`hyprctl -j clients`), and this says where the ROW is inside it.
    //
    // ⚠️ IT IS NOT TEST SCAFFOLDING IN PRODUCTION CODE, by this project's own
    // rule 5: every surface has to be reachable from outside, and "where is the
    // control for this key" is the same class of question as "open the settings
    // on Wallpaper", which is already a verb. tests/click.sh is its first
    // caller, not its only justification.
    property var settingsContent: null

    // The island's card, while one is up — see the note beside it in
    // ui/surface/OverlaySurface.qml. Null when the island is collapsed, which
    // is an honest answer and not an error.
    property var notchCard: null

    // The quick panel's tile grid, while the panel is up. Null otherwise.
    //
    // ⚠️ IT EXISTS BECAUSE A WHOLE CLASS OF FAULT WAS UNREACHABLE WITHOUT IT.
    // "wenn man WLAN oder Bluetooth ausklappen geht alles wenns man einklappt   // english-ok: the report, quoted
    // bleibt die neue Größe" is a claim about the card's height across a state  // english-ok: the report, quoted
    // this shell had no way to enter from outside: the drawer opens on a press
    // and on nothing else. `ipc call notch size` could read the height per TAB
    // and per fold, and both of those measured clean — the state he was
    // describing simply could not be reached by any check.
    //
    // Same justification as `settingsContent` above, by rule 5: a surface with
    // no way in from outside is a surface no tripwire can ever cover. The
    // drawer also needs hardware the lab VM does not have (no wifi, no
    // bluetooth, no sound card), so a verb is the ONLY way this is measurable
    // here at all.
    property var quickPanel: null

    // The overlay window itself, for the resize counter — see `chain`.
    property var notchHost: null

    function showSettings() { root.settingsOpen = true }
    function showSettingsPage(id) {
        root.settingsPage = id
        root.settingsOpen = true
    }
    function hideSettings() { root.settingsOpen = false }
    function toggleSettings() { root.settingsOpen = !root.settingsOpen }

    Timer {
        id: idle
        interval: 1600
        onTriggered: root.collapse()
    }

    // ⚠️ One function per page, with NO arguments — deliberately.
    //
    // `qs ipc show` happily lists `show(page: string)`, but `qs ipc call notch
    // show media` answers "The following argument was not expected: media" in
    // quickshell 0.2.1, whichever order the options are given in. Parameterless
    // calls work. So the interface is shaped to what the tool can actually do
    // rather than to what its own listing suggests.
    //
    // ⚠️ AND THE ARGUMENT WAS ONLY HALF OF IT. Measured on 06.08.2026 against
    // the launcher, which had a parameterless `show()`: it printed the target's
    // function list and did nothing, while `toggle` and `hide` on the same
    // handler worked. So the NAME `show` is unusable on its own — it collides
    // with the `qs ipc show` subcommand. Nothing here is called `show` any
    // more, and tests/ipc-names.sh keeps it that way.
    //
    //     qs -c buchhwin ipc call notch media
    //     qs -c buchhwin ipc call notch collapse
    // ⚠️ THE HANDLERS THEMSELVES, BY TARGET NAME — so a checker can ASK one
    // whether it has a verb instead of being handed a list of verbs to trust.
    //
    // tools/smoke.qml used to carry that list, typed out by hand, and its own
    // comment admitted the flaw: "it goes stale in one direction only: a verb
    // that exists and is missing here." That is exactly what happened the first
    // time a verb was added after it was written — the check went red at a key
    // that worked perfectly, which is worse than not checking, because a
    // tripwire nobody believes gets edited until it is quiet.
    //
    // Three names instead of eighteen, and the three are the targets, which are
    // structural. A wrong one here fails loudly on the very first binding.
    readonly property var targets: ({
        "notch": notchIpc, "bar": barIpc,
        "launcher": launcherIpc, "settings": settingsIpc,
        // ⚠️ ADDED WITH THE HANDLER, not afterwards — tools/smoke.qml looks a
        // binding's verb up in THIS map, so a target missing here reads as "the
        // key calls something that does not exist". It caught exactly that on
        // the first run of `windows halve`, which is what the check is for.
        "windows": windowsIpc
    })

    IpcHandler {
        id: notchIpc
        target: "notch"

        function media(): void { root.toggle("media") }
        function volume(): void { root.toggle("volume") }
        function quick(): void { root.toggle("quick") }

        // Open the quick panel on a numbered tab. `quick` alone toggles it and
        // leaves the tab where it was, so there was no way in from outside to
        // say WHICH view — the bar's pills do it through showQuick() and
        // nothing else could.
        //
        // ⚠️ IT SETS RATHER THAN TOGGLES. showQuick() closes the panel when you
        // ask for the tab already in front, which is right for a pill you click
        // twice and wrong for anything measuring: "open it on tab 2" would then
        // sometimes mean "close it".
        //
        // ⚠️ AN ARGUMENT WORKS. A note elsewhere in this file says an argument
        // was rejected by `qs ipc call` — that was about the page verbs, and it
        // is not true of a typed parameter: measured on quickshell 0.2.1,
        // `ipc call settings probe bar.enabled` answers correctly.
        function tab(i: int): void {
            root.quickTab = i
            root.show("quick")
        }
        function notifications(): void { root.toggle("notifications") }
        // None of these three closes itself: they are places you look around
        // in or choose from, not reports that have finished being read.
        function calendar(): void { root.toggle("calendar") }
        function tray(): void { root.toggle("tray") }
        // The workspace map. Like the calendar and the tray it is a place
        // you look around in, so it does not close itself.
        function workspaces(): void { root.toggle("workspaces") }

        // B33 · one column per MONITOR, and windows dragged between them.
        // Like the workspace map it is a place you look around in, so it does
        // not close itself.
        function monitors(): void { root.toggle("monitors") }
        function wallpaper(): void { root.toggle("wallpaper") }
        // The palette grid. A place you look around in, so it stays open
        // until you choose or leave — same as the wallpaper grid beside it.
        function theme(): void { root.toggle("theme") }
        function event(): void { root.toggle("event") }
        function brightness(): void { root.toggle("brightness") }
        // ⚠️ `show`, not `toggle`. It is fired by the mute key right after the
        // state changed, so pressing the key twice in a row must show the new
        // state twice — a toggle would close the readout on the second press,
        // exactly when there is something new to read.
        function mic(): void { root.show("mic") }
        function session(): void { root.toggle("session") }
        function clipboard(): void { root.toggle("clipboard") }
        function calculator(): void { root.toggle("calculator") }
        function emoji(): void { root.toggle("emoji") }
        function tasks(): void { root.toggle("tasks") }
        function timer(): void { root.toggle("timer") }
        // ⚠️ `settings` USED TO BE HERE AND IS NOW ITS OWN TARGET. It opened the
        // quick panel on its overview tab, because there was no settings window
        // to open — the placeholder in QuickPage.qml said as much in words. M8
        // is that window, and a real the compositor window is not one of the notch's
        // pages, so `qs -c buchhwin ipc call settings toggle` is where it went.
        //
        // The history is worth keeping, because it is why tests/ipc-names.sh
        // exists: this verb pointed at the `quickSettings` property for a day
        // after that property was deleted. QML does not complain about reading
        // a property that is not there — it hands back `undefined` — so it
        // passed every check and shipped. The gear on the bar and the settings
        // key both did nothing, and the only trace was one journal line,
        // "Cannot assign [undefined] to int". The comment beside the deletion
        // had said "the compiler found every one of them". There is no compiler
        // here.
        //
        // ⚠️ And writing it as `quickSettings` rather than with the `root.`
        // in front is not tidiness: ipc-names.sh reads comments too, on
        // purpose, so a sentence ABOUT a dead name would fail as though it were
        // a reader of one. Rewording the sentence is the right answer; making
        // the check skip comments would be quieting the one tripwire whose
        // whole subject is a name nobody noticed.
        function collapse(): void { root.collapse() }
        function state(): string { return root.page }

        // "w h" of the open card, or empty when nothing is open. The unit is
        // layout pixels — the same ones every Theme token is in.
        //
        // ⚠️ THIS IS WHAT "es zittert" IS MEASURED IN. A tab that makes the
        // card a different height moves a Wayland surface, which is protocol
        // rather than repainting; the reading below is the difference between
        // "it looks steady to me" and a number that is the same on every tab.
        function size(): string {
            var c = root.notchCard
            if (!c || c.width <= 0 || c.height <= 0)
                return ""
            return Math.round(c.width) + " " + Math.round(c.height)
        }

        // Open one of the quick panel's drawers by name, or close it with "".
        // Answers with the drawer that is open afterwards, so a caller can tell
        // "it did nothing" from "it closed" without a second round trip.
        //
        // ⚠️ NAMES ARE THE ONES THE PANEL ITSELF USES — wifi, bt, sound, disks.
        // An unknown name closes the drawer rather than being ignored, because
        // a silent no-op here would read exactly like the bug being measured.
        function drawer(which: string): string {
            var p = root.quickPanel
            if (!p)
                return ""
            p.show(which)
            return p.open
        }

        // Flip the quick panel's "Show more" fold, exactly as the button does,
        // and answer with the state it landed in ("open" / "shut").
        //
        // ⚠️ B74 NEEDS THIS TO BE CHECKABLE AT ALL. The requirement is that the
        // fold does NOT survive a reopen — which is a statement about two
        // openings and the state in between, and the state in between could
        // only be reached with a pointer. `tests/quick-fold.sh` opens, folds,
        // closes, reopens and reads the card height at each step; without a
        // verb it would have to click, and a check that needs ydotool cannot
        // run in CI.
        // The size of every link in the chain that decides how big the card is,
        // in one reading: window ← card ← content ← page.
        //
        // ⚠️ IT EXISTS BECAUSE "THE PANEL KEEPS ITS SIZE" NAMES A SYMPTOM AND NOT
        // A LINK. `notch size` reports the window, so a value that fails to
        // shrink could be any of four things, and guessing which cost one wrong
        // fix already. Four numbers say which one is stuck.
        //
        // ⚠️⚠️ AND IT USED TO BE UNABLE TO ANSWER THE ONE QUESTION IT WAS BUILT
        // FOR. It reported `card`, `content` and `page` and called that the
        // chain — but the first link, the WINDOW, was never in it, and every
        // number was an `implicitHeight`. Both omissions hide the same thing:
        //
        //   card.implicitHeight   what the card wants     — updates immediately
        //   card.height           what is being drawn     — follows in the same frame
        //   window                what the surface is     — settleSize() publishes
        //                                                   it two event loop turns later
        //
        // "the window goes big for about a millisecond and small again" is a gap
        // between those. `resizes` cannot see it: that counter is incremented
        // AFTER the settle wait (OverlaySurface.qml), so one `set_size` per press
        // is true and rules the gap out not at all. A measurement that cannot
        // resolve the fault does not prove its absence — so this verb now reads
        // both geometries and the window, and the difference is the reading.
        function chain(): string {
            var c = root.notchCard
            if (!c)
                return ""
            var content = null
            for (var i = 0; c.children && i < c.children.length; i++) {
                var ch = c.children[i]
                if (ch && ch.pageHeightProbe !== undefined) { content = ch; break }
            }
            var box = function (w, h) { return Math.round(w) + "x" + Math.round(h) }
            var parts = []
            var host = root.notchHost
            // ⚠️ TWO NUMBERS, NOT ONE, and calling either of them "the window"
            // is how a reading gets misread. `asked` is what settleSize()
            // published; `window` is what the surface actually is once the compositor has
            // acknowledged it. They differ for the length of that round trip,
            // which is the window in which the flash used to live.
            if (host) {
                parts.push("asked=" + box(host.implicitWidth, host.implicitHeight))
                parts.push("window=" + box(host.width, host.height))
            }
            // What the card asks for, and what it is actually drawn at. Equal in
            // a steady state; a difference is a frame at the wrong size.
            parts.push("card=" + box(c.implicitWidth, c.implicitHeight))
            parts.push("cardnow=" + box(c.width, c.height))
            if (host && host.resizes !== undefined)
                parts.push("resizes=" + host.resizes)
            // The per-frame sampler. `off` is the number of RENDERED frames in
            // which the card was drawn at a size the surface did not have, and
            // `worst` is the largest such difference. Those two are the flash:
            // a number here with `resizes=1` beside it is exactly the shape the
            // old counter was blind to.
            if (host && host.offFrames !== undefined) {
                parts.push("frames=" + host.frames)
                parts.push("off=" + host.offFrames)
                parts.push("worst=" + host.worstW + "x" + host.worstH)
                // B81: how far the page slid inside the card over this press.
                // Zero at rest; anything else is the icons visibly moving.
                parts.push("shift=" + (host.shiftMax - host.shiftMin))
                parts.push("pageshift=" + (host.pageShiftMax - host.pageShiftMin))
            }
            if (content) {
                parts.push("content=" + box(content.implicitWidth, content.implicitHeight))
                parts.push("page=" + Math.round(content.pageHeightProbe))
            }
            return parts.join(" ")
        }

        // Zero the frame sampler, so a reading describes ONE press rather than
        // everything since the panel opened. Answers "0" so a caller can tell it
        // from a verb that is not there.
        function probe(): string {
            var host = root.notchHost
            if (!host || host.resetFrameProbe === undefined)
                return ""
            host.resetFrameProbe()
            return "0"
        }

        function fold(): string {
            var p = root.quickPanel
            if (!p)
                return ""
            p.showMore = !p.showMore
            return p.showMore ? "open" : "shut"
        }
    }

    // ⚠️ Lower case, no digits, in both the target and the verb. The smoke test
    // reads every keybinding with /ipc call ([a-z]+) ([a-z]+)/ and checks the
    // pair exists; a name like `barToggle` would not match the expression at
    // all, so the binding would go unchecked rather than fail.
    IpcHandler {
        id: barIpc
        target: "bar"

        // The bar is built and off by default — the notch is the surface. This
        // is how it gets tried out without editing shell.json, which was the
        // only way until now.
        function toggle(): void {
            Config.bar.enabled = !Config.bar.enabled
            Config.save()
        }
        function state(): string { return Config.bar.enabled ? "on" : "off" }
    }

    // Its own target rather than a verb on `notch`, because it is not one:
    // `qs -c buchhwin ipc call launcher toggle` says what it does, and the
    // notch's verb list stays a list of the notch's pages.
    IpcHandler {
        id: launcherIpc
        target: "launcher"

        function toggle(): void { root.toggleLauncher() }
        // ⚠️ `open`, NOT `show`. An IPC function called `show` cannot be called
        // from the command line at all: `qs ipc show` is quickshell's own
        // subcommand, so `qs -c buchhwin ipc call launcher show` prints the
        // target's function list and returns without doing anything. Measured —
        // `toggle` and `hide` both worked, `show` left the launcher `closed`
        // and printed the list. Nothing user-facing depended on it (the two key
        // bindings use `toggle`), which is exactly why it could sit there
        // broken: a function nobody can call is the same debt as a key nobody
        // reads. tests/ipc-names.sh keeps the name from coming back.
        function open(): void { root.showLauncher() }
        function hide(): void { root.hideLauncher() }
        function state(): string { return root.launcher ? "open" : "closed" }
    }

    // The settings window. Same four verbs as the launcher, and the same
    // reasoning: `open` rather than `show`, because the command line cannot
    // reach a function of that name.
    // ⚠️ B64 · TILING TWO FULL WINDOWS SIDE BY SIDE, from outside. The compositor can only
    // size the FOCUSED column, so the sequence lives in services/Hyprland.qml — this
    // is the way in, and it is what the key binding calls.
    //
    // ⚠️ IT ANSWERS. A key that silently does nothing when there are three
    // windows is the shape rule 5 forbids, so the verb returns what happened and
    // `bhctl` or a script can read it.
    IpcHandler {
        id: windowsIpc
        target: "windows"

        function halve(): string {
            Services.Hyprland.run(["resizeactive", "exact 50% 100%"])
            Services.Hyprland.run(["moveactive", "exact 0 0"])
            return "focused window moved to the left half"
        }
    }

    IpcHandler {
        id: settingsIpc
        target: "settings"

        function toggle(): void { root.toggleSettings() }
        function open(): void { root.showSettings() }
        function hide(): void { root.hideSettings() }
        function state(): string { return root.settingsOpen ? "open" : "closed" }

        // ⚠️ ONE PARAMETERLESS FUNCTION PER PAGE, exactly like the notch above,
        // and for the same measured reason: `qs ipc call settings page theming`
        // answers "The following argument was not expected" in quickshell 0.2.1
        // whichever order the options come in. The interface is shaped to what
        // the tool can do rather than to what its own listing suggests.
        //
        // It is not scaffolding. Every page of this window is now reachable from
        // a key binding or a script — "open the settings on Wallpaper" was
        // impossible before, and a surface you can only reach by clicking
        // through another one is the same debt as a themed tool with no key,
        // which this project has paid twice.
        function currentPage(): string { return root.settingsPage }

        // Where the control for a dotted key sits INSIDE the window, as
        // "x y w h" in window pixels. Empty when the window is shut or the page
        // in front of you does not carry that key — both are honest answers and
        // the caller has to tell them apart from a coordinate.
        //
        // ⚠️ `mapToItem(null)` — window coordinates, NOT screen ones. There is
        // no such thing as a screen coordinate for a Wayland client; asking for
        // one returns something that looks right and is not. The caller adds the
        // window's position, which it gets from the compositor.
        function probe(key: string): string {
            var c = root.settingsContent
            if (!c)
                return ""
            // ⚠️ EITHER a dotted key OR an objectName, because not every control
            // worth pressing owns a setting. "Reset this page" acts on the whole
            // page and has no key at all — and it is the two-stage button whose
            // FIRST press only arms it, which is precisely the shape no checker
            // that calls the function directly can see.
            var hit = null
            c.walk(c, function (o) {
                if (hit !== null || o.width <= 0 || o.height <= 0)
                    return
                var isRow = o.key !== undefined && String(o.key) === key
                            && o.label !== undefined
                var isNamed = o.objectName !== undefined
                              && String(o.objectName) === key
                if (isRow || isNamed)
                    hit = o
            })
            if (hit === null)
                return ""
            var p = hit.mapToItem(null, 0, 0)

            // ⚠️⚠️ A ROW THAT IS SCROLLED AWAY HAS A POSITION AND NO PLACE ON THE
            // SCREEN, and answering with it is worse than answering nothing.
            // Measured: "Reset this page" sits 993 px down a page inside a window
            // 704 px tall, so the honest arithmetic put the pointer at y=1079 on
            // an 800 px screen. The click landed on the wallpaper and the reading
            // came back unchanged — which reads exactly like the fault the caller
            // is hunting. Anything not inside the window is "not visible", and
            // the caller has to scroll first.
            if (p.x < 0 || p.y < 0
                || p.x + hit.width > root.settingsContent.width
                || p.y + hit.height > root.settingsContent.height)
                return ""

            return Math.round(p.x) + " " + Math.round(p.y) + " "
                 + Math.round(hit.width) + " " + Math.round(hit.height)
        }

        // Scroll a control into view, then answer where it ended up — the same
        // string `probe` returns, or empty if it is not on this page at all.
        //
        // ⚠️ THE SCROLLING ALREADY EXISTED. `SettingsContent.revealRow` is what
        // the search box uses to land on a found row, and it matches on
        // `objectName`, which every SettingRow already sets to its own key. So
        // this is a way IN to a behaviour the window has, not a second copy of
        // it — the alternative was a scrolling implementation living in a test,
        // which is the shape this project keeps finding and deleting.
        function reveal(key: string): string {
            var c = root.settingsContent
            if (!c)
                return ""
            if (typeof c.revealRow === "function")
                c.revealRow(key)
            return probe(key)
        }
        function colours(): void { root.showSettingsPage("colours") }
        function wallpaper(): void { root.showSettingsPage("wallpaper") }
        function shape(): void { root.showSettingsPage("shape") }
        function effects(): void { root.showSettingsPage("effects") }
        function type(): void { root.showSettingsPage("type") }
        function theming(): void { root.showSettingsPage("theming") }
        function bar(): void { root.showSettingsPage("bar") }
        function control(): void { root.showSettingsPage("control") }
        function launcher(): void { root.showSettingsPage("launcher") }
        function notify(): void { root.showSettingsPage("notify") }
        function clock(): void { root.showSettingsPage("clock") }
        // ⚠️ B70 · A NEW PAGE NEEDS A VERB IN THE SAME COMMIT. The verbs here are
        // a hand-written list, not generated from the pages, and the System page
        // shipped without one — `ipc call settings system` answered "Function
        // not found", which is rule 5's "a surface with no way in from outside".
        // Noticed then by trying it, not by reading; tests/ipc-names.sh is why
        // it cannot be noticed that way twice.
        function sound(): void { root.showSettingsPage("sound") }
        function media(): void { root.showSettingsPage("media") }
        function lock(): void { root.showSettingsPage("lock") }
        function motion(): void { root.showSettingsPage("motion") }
        function keyboard(): void { root.showSettingsPage("keyboard") }
        function keys(): void { root.showSettingsPage("keys") }
        function pointing(): void { root.showSettingsPage("pointing") }
        function windows(): void { root.showSettingsPage("windows") }
        function power(): void { root.showSettingsPage("power") }
        function programs(): void { root.showSettingsPage("programs") }
        function machine(): void { root.showSettingsPage("machine") }
        // ⚠️ EVERY PAGE HAS A VERB, and a new page without one is a surface with
        // no way to reach it from outside — rule 5's "a tool without a way to it".
        // It was noticed by trying: `ipc call settings system` answered
        // "Function not found" the first time the page existed.
        function system(): void { root.showSettingsPage("system") }
        // ⚠️ IT HAS TO BE HERE, not because every page happens to have one, but
        // because this is the page you need when a screen is missing — and a
        // screen missing is exactly when clicking your way through a window on
        // the screen that IS there is worst. It is also the only way a check
        // harness can put this page on screen at all.
        function displays(): void { root.showSettingsPage("displays") }
    }
}
