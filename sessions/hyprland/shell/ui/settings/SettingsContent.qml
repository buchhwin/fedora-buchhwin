pragma ComponentBehavior: Bound

// The inside of the settings window, laid out from his reference.
//
// Left: a search field over named rows gathered under headings. Right: back and
// forward, then the page's symbol, heading and one explaining line, then the
// settings themselves as rows separated by space rather than by lines.
//
// ⚠️ THE TEN PAGES OF THE REFERENCE BECAME TWENTY-ONE, and that is the fix
// rather than a departure. The reference named ten; two of them then grew to 55
// and 43 rows, which is two thirds of every setting in the shell sitting in two
// unstructured columns. "aktuell ist alles unübersichtlich und echt schlecht"    // english-ok: quoted brief
// was about those two pages. Nothing here is longer than seventeen rows now.
//
// Between them every setting in shell.json still has exactly one row — which is
// what tests/setting-rows.sh counts by reading and tests/pages.sh counts by
// building, so "everything is settable" is two numbers that have to agree
// rather than a belief.
import QtQuick
import QtQuick.Layouts
// ⚠️ NO `import "pages"`. The pages are reached by URL now, not by type name,
// so importing the folder would be importing something for nothing — and an
// import that is there for no reason is the one nobody dares remove later.
import "../common"
import "../../config"
import "../../ipc"
import "../../services" as Services
import "../../theme"

FocusScope {
    id: root

    // ⚠️ THE WINDOW ANNOUNCES ITSELF so `ipc call settings probe <key>` can ask
    // where a control is — see the note beside `Ipc.settingsContent`. Cleared on
    // the way out, and only if it is still us: this content is behind a Loader,
    // and a rebuild can construct the new one before destroying the old, which
    // would otherwise leave the property pointing at a dead item.
    Component.onDestruction: if (Ipc.settingsContent === root) Ipc.settingsContent = null

    // ⚠️ ONE PROCESS, THE FIRST TIME THIS WINDOW OPENS, AND NEVER AT STARTUP.
    // Services.Gpu answers a question that changes at most twice in a machine's
    // life — is Secure Boot standing in the way of the NVIDIA module — so
    // asking on every login would be a fork on the start path for nothing, and
    // `bhctl doctor` measures that path. The service guards itself against a
    // second run, so opening the window ten times still costs one.
    //
    // The other two routes to the same answer already exist: the installer says
    // it on the terminal, and `bhctl doctor` says it over SSH.
    Component.onCompleted: {
        Services.Gpu.probe()
        // The row index, built between frames from now on — see `buildIndex`.
        root.buildIndex()
        // A page asked for before this window existed — see `takePage`.
        root.takePage()
        // ⚠️ HERE, NOT IN A SECOND `Component.onCompleted`. QML allows one
        // handler per signal on an object and answers a second one with
        // "Property value set multiple times" — which makes the whole TYPE
        // unavailable, so the settings window did not exist at all. The journal
        // named it in one line; the symptom from outside was `ipc call settings`
        // answering "Target not found", which reads like a missing handler
        // rather than a file that would not compile.
        Ipc.settingsContent = root
    }

    // ⚠️ ONE ENTRY IS THE WHOLE REGISTRATION, and it used to be three. A page
    // needed a line here, a `Component { id: fooPage; FooPage {} }` further
    // down, AND a branch in a ten-way ternary on `currentId`. Forgetting the
    // third produced a page that drew nothing, which is why there was a
    // hand-written placeholder explaining that exact mistake.
    //
    // `source` is a relative URL, which quickshell resolves through its virtual
    // filesystem — proven by shell.qml, which boots the entire shell that way
    // (`source: "ui/Shell.qml"`). A wrong path is now loud: Loader.status goes
    // to Error and says so on screen, instead of drawing an empty page.
    //
    // ⚠️ TEN PAGES BECAME TWENTY-FIVE AND ARE NOW SEVENTEEN, and the two moves
    // are opposites for the same reason. The split happened because Appearance
    // carried 55 rows and System 43 — two pages holding two thirds of every
    // setting, each an unstructured column. The cut back is his: eight pages
    // held settings nobody changes, so their defaults are the behaviour now and
    // the keys went with the pages. `section` is what keeps either count
    // navigable, and it gathers these under three headings.
    //
    // ⚠️ ONE PAGE IS LONG AGAIN, and deliberately: Appearance carries the 31
    // rows of the three pages it replaces. What stops it being the wall the
    // split was made to end is `advanced: true` — six rows are open and the
    // rest are behind "Show more", which tests/setting-rows.sh enforces at six.
    //
    // ⚠️ Every icon name goes through tests/icons.sh, which MEASURES THE GLYPH
    // rather than trusting the name: "Material Icons Round" is missing more
    // names than anyone expects, and a missing one renders as an 800 px
    // fallback box instead of failing.
    readonly property var pages: [
        { id: "colours", section: "Look", icon: "palette",
          title: "Colours", source: "pages/ColoursPage.qml",
          blurb: "The palette, the accent, and when the light one takes over." },
        { id: "wallpaper", section: "Look", icon: "wallpaper",
          title: "Wallpaper", source: "pages/WallpaperSettingsPage.qml",
          blurb: "Which picture, from where, and how it is fitted." },
        { id: "appearance", section: "Look", icon: "straighten",
          title: "Appearance", source: "pages/AppearancePage.qml",
          blurb: "Size and shape, transparency and effects, the fonts and the pointer." },
        { id: "theming", section: "Look", icon: "format_paint",
          title: "App Theming", source: "pages/AppThemingPage.qml",
          blurb: "One state per program we colour: follow the scheme, neutral grey, or leave it alone." },
        { id: "bar", section: "Shell", icon: "view_agenda",
          title: "Bar & Island", source: "pages/BarIslandPage.qml",
          blurb: "Shape and size of the island, the notch, and the bar." },
        { id: "notify", section: "Shell", icon: "notifications",
          title: "Notifications", source: "pages/NotifyPage.qml",
          blurb: "Arriving messages, how long they stay, and where." },
        // B70 · his request for a sound tab. Next to Media because the two are
        // the same subject from two sides: Media is which player the island
        // follows, Sound is where the noise actually goes.
        { id: "sound", section: "Shell", icon: "volume_up",
          title: "Sound", source: "pages/SoundPage.qml",
          blurb: "Which device plays and records, and how loud." },
        { id: "lock", section: "Shell", icon: "lock",
          title: "Lock Screen", source: "pages/LockPage.qml",
          blurb: "What the screen shows while the session is locked." },
        // ⚠️ `desktop_windows`, AND THE TWO OBVIOUS NAMES DO NOT EXIST. Fedora
        // ships "Material Icons Round", the older set; `monitor` measures 600 px
        // and `display_settings` 891 px against ~70 for a real glyph, which is
        // the substitute box. Measured with tests/icons.sh's own tool, with an
        // invented name as the control, and then LOOKED AT: `desktop_windows` is
        // a monitor on a stand, `tv` is a television and `devices` is a laptop
        // with a phone beside it.
        { id: "displays", section: "System", icon: "desktop_windows",
          title: "Displays", source: "pages/DisplaysPage.qml",
          blurb: "Which screen is the main one, where each one is, and what it runs at." },
        { id: "keyboard", section: "System", icon: "keyboard",
          title: "Keyboard", source: "pages/KeyboardPage.qml",
          blurb: "Layout, variant, options, and how fast a held key repeats." },
        { id: "keys", section: "System", icon: "vpn_key",
          title: "Shortcuts", source: "pages/KeysPage.qml",
          // ⚠️ THE NUMBER COUNTS ITSELF. It read "All sixty-three key bindings"
          // while there were seventy-four — a figure written out in words in
          // five places and true in none of them. This is the only one of the
          // five that is DRAWN ON SCREEN, so it is the one that had to stop
          // being a copy.
          blurb: "All " + Config.binds.length
                 + " key bindings, and the way back to the built-in set." },
        { id: "pointing", section: "System", icon: "mouse",
          title: "Mouse & Touchpad", source: "pages/PointingPage.qml",
          blurb: "Tapping, scrolling, and pointer speed." },
        { id: "windows", section: "System", icon: "web_asset",
          title: "Windows", source: "pages/WindowsPage.qml",
          blurb: "How focus follows the pointer, and which windows float." },
        { id: "power", section: "System", icon: "battery_full",
          title: "Power", source: "pages/PowerPage.qml",
          blurb: "When the screen goes off, when the session locks, when it sleeps, and what the lid does." },
        { id: "programs", section: "System", icon: "widgets",
          title: "Programs", source: "pages/ProgramsPage.qml",
          blurb: "Which terminal, browser and editor the keys reach for, and how the terminal behaves." },
        { id: "machine", section: "System", icon: "computer",
          title: "This Machine", source: "pages/MachinePage.qml",
          blurb: "The graphics card, what the session does, and where it is." },
        // ⚠️ LAST, AND THAT IS THE REQUEST RATHER THAN A PLACEMENT DECISION:
        // "es soll ganz unten in einem evtl nueen tab mit systeninfos".        // english-ok: his request, quoted
        // "Reset everything" moved onto it out of This Machine — he went
        // looking for it and did not find it, and two reset buttons in two
        // places is the duplication rule 6 forbids.
        // ⚠️ THE GLYPH IS MEASURED BEFORE IT SHIPS, NOT CHOSEN. `monitor` and
        // `display_settings` are NOT in "Material Icons Round" at all — that is
        // a measurement this project already paid for. `memory` is the
        // candidate here and it is checked by tests/icons.sh, which every push
        // runs; and because a glyph that exists can still be the wrong picture
        // (B14 shipped `settings_ethernet` that way), it is rendered and looked
        // at as well.
        { id: "system", section: "System", icon: "memory",
          title: "System", source: "pages/SystemPage.qml",
          blurb: "What this machine is, and the button that puts every setting back." }
    ]
    // ⚠️ SIX PAGES USED TO BE FILTERED OUT OF THIS LIST HERE, and the filter is
    // gone because the condition it named has been met.
    //
    // The migration hid Displays, Keyboard, Shortcuts, Mouse & Touchpad, Windows
    // and This Machine "until a Hyprland writer exists for them" — honest at the
    // time, because the same commit deleted the config generator instead of
    // porting it, and a control that writes to nothing is worse than no control.
    // tools/hypr/EmitSettings.qml is that writer: `mode`, `position`, `scale`,
    // `transform` and `vrr` through `hl.monitor()`, `kb_layout`, `kb_variant`,
    // `kb_options`, `repeat_delay`, `repeat_rate`, every touchpad and mouse
    // field, `follow_mouse`, `no_warps` and the window rules. EmitBinds.qml is
    // the one behind Shortcuts.
    //
    // ⚠️ SHORTCUTS IS THE ONE THAT MATTERED. Rebinding was the whole point of
    // rebuilding the generator, and the editor for it was sitting behind this
    // filter the entire time — reachable by nothing, from anywhere.
    //
    // ⚠️ AND THE FILTER WAS INVISIBLE TO EVERY CHECK BUT ONE. It hid 33 of the
    // 185 rows the schema declares, which is exactly the gap tests/pages.sh
    // reported as "152 built, 185 declared". That number was the only thing in
    // the suite that could see it: tests/setting-rows.sh greps the page files
    // and they were all still there, being greppable and unreachable.

    // ---------------------------------------------------------------- history
    // Back and forward, which the reference puts at the top of the content.
    // A plain stack: everything after the current position is dropped when you
    // go somewhere new, which is what makes forward mean "where I came back
    // from" rather than "somewhere I have been at some point".
    property var history: ["colours"]
    property int historyIndex: 0

    readonly property string currentId: root.history[root.historyIndex]
    readonly property var currentPage: {
        for (var i = 0; i < root.pages.length; i++)
            if (root.pages[i].id === root.currentId)
                return root.pages[i]
        return root.pages[0]
    }

    function navigate(id) {
        if (id === root.currentId)
            return
        var h = root.history.slice(0, root.historyIndex + 1)
        h.push(id)
        root.history = h
        root.historyIndex = h.length - 1
    }

    // ⚠️ THE PAGE ASKED FOR FROM OUTSIDE, and it is watched rather than called.
    // `Ipc.settingsPage` is set by the twenty-one verbs on the `settings` target
    // and may be set BEFORE this content exists — the window is behind a Loader
    // on `Ipc.settingsOpen`, so the first `ipc call settings theming` sets the
    // property and builds the window in the same breath. Reading it on
    // completion as well as on change is what makes both orders work.
    //
    // ⚠️ AND IT IS CLEARED AFTER USE. Left standing, the next plain `settings
    // open` would jump to whatever page was asked for last time, which is a
    // window that remembers something nobody told it to.
    function takePage() {
        var want = Ipc.settingsPage
        if (!want.length)
            return
        Ipc.settingsPage = ""
        for (var i = 0; i < root.pages.length; i++)
            if (root.pages[i].id === want) {
                root.navigate(want)
                return
            }
    }

    Connections {
        target: Ipc
        function onSettingsPageChanged() { root.takePage() }
    }

    function back() { if (root.historyIndex > 0) root.historyIndex-- }
    function forward() { if (root.historyIndex < root.history.length - 1) root.historyIndex++ }

    // The paths the page currently on screen writes, and whether its reset is
    // armed. Filled when the page finishes loading rather than bound to
    // `pageLoader.item`: a binding would not re-run when the item's CHILDREN
    // appear, which is where every one of these keys lives.
    //
    // ⚠️ BOTH ARE CLEARED ON THE WAY OUT. An armed reset that survived
    // navigation would go off on the wrong page, and a stale key list would
    // reset the page you just left — the same fault, one frame apart.
    property var currentKeys: []
    property bool resetArmed: false

    onCurrentIdChanged: {
        root.resetArmed = false
        root.currentKeys = []
    }

    // ----------------------------------------------------------------- search
    // ⚠️ TITLES AND THE EXPLAINING LINES, NOT ROW LABELS — and with 135 rows
    // that is now a real limit rather than a note. Typing "blur" finds nothing,
    // because the word is on a row inside Appearance and not in any page's own
    // description. Searching rows means every page building its list without
    // being open, which is a change to how a page is declared; saying what the
    // box does beats a box that quietly finds a tenth of what you asked for.
    // ⚠️ IT SEARCHED TEN TITLES AND TEN BLURBS, and with 157 rows that was a box
    // that quietly found a tenth of what you asked it for. Typing "blur" found
    // nothing, because the word is on a row and not in any page's description —
    // which is exactly the case that matters, since a page title is the thing
    // you can already see in the sidebar.
    //
    // The obstacle was never the matching. It is that a page's rows do not exist
    // until the page is built, and the settings window builds one page at a
    // time. Keeping a second list of every row beside the real ones would be
    // double bookkeeping that drifts — the fault this repo spends most of its
    // checks preventing.
    //
    // So: build all twenty-one pages once, off-screen, on the FIRST keystroke,
    // read their rows, and throw the pages away. One cost, paid by someone who
    // has just shown they want to search, and no second source of truth.
    property var rowIndex: null

    // Rows are found by asking for the properties rather than by matching the
    // type name — a row is something with a `key` and a control. Matching
    // `SettingRow` by name would go blind the day one gets wrapped.
    //
    // ⚠️ AND THERE ARE TWO SPELLINGS OF "A CONTROL". The App Theming page lays
    // its thirteen programs out as a table of ThemingRows, which carry `states`
    // instead of `kind`. Asking only for `kind` dropped all thirteen from the
    // index — so searching for "kitty" or "lazygit" would have found nothing,
    // silently, on a page where they are plainly written. Caught by
    // tools/pages-check.qml, which counts the index against the rows it built:
    // 151 against 164.
    // ⚠️ THE WALK IS ITS OWN FUNCTION because two things need it now — the
    // search index below and the per-page reset further down. A second copy of
    // this traversal is precisely where the ThemingRow blind spot would grow
    // back, and that one silently dropped thirteen rows from the index until
    // tools/pages-check.qml counted 151 against 164.
    function walk(obj, visit) {
        if (!obj)
            return
        visit(obj)
        var kids = obj.children === undefined ? [] : obj.children
        for (var i = 0; i < kids.length; i++)
            root.walk(kids[i], visit)
        var d = obj.data === undefined ? [] : obj.data
        for (var j = 0; j < d.length; j++)
            if (d[j] !== undefined && kids.indexOf(d[j]) < 0)
                root.walk(d[j], visit)
    }

    function harvest(obj, page, into) {
        root.walk(obj, function (o) {
            if (o.key !== undefined && String(o.key).length
                && o.label !== undefined)
                into.push({ key: String(o.key),
                            label: String(o.label === undefined ? "" : o.label),
                            hint: String(o.hint === undefined ? "" : o.hint),
                            page: page })
        })
    }

    // ---------------------------------------------------- reset ONE page
    // Every dotted path the page in front of you writes, gathered from the page
    // itself rather than from a list kept beside it. A list would be the second
    // source of truth this window spends most of its checks avoiding: add a row,
    // forget the list, and "Reset this page" quietly leaves that one setting
    // standing.
    //
    // ⚠️ TWO PLACES OWN KEYS THAT NO ROW CAN NAME, and they are the same two
    // that are named exceptions in tests/setting-rows.sh: DisplaysPage writes
    // `outputs` (a list of objects — a dotted path cannot say "the refresh rate
    // of DP-2") and BindsList writes `binds` and `rebinds`. Both declare what
    // they own in `resetKeys`, so the knowledge sits on the component the way
    // `advanced:` sits on a row. tests/reset-page.sh holds that shut in both
    // directions.
    //
    // ⚠️ THE DECLARATION MOVED WITH THE CONTROLS. It used to be on
    // OutputScales, which was a component ON Size & Shape; it is now on the
    // Displays page itself, because that page has no SettingRows at all — so
    // without it "Reset this page" would report success having changed nothing.
    function pageKeys(item) {
        var out = []
        function add(k) {
            var s = String(k)
            if (s.length && out.indexOf(s) < 0)
                out.push(s)
        }
        root.walk(item, function (o) {
            if (o.key !== undefined && String(o.key).length
                && o.label !== undefined)
                add(o.key)
            var extra = o.resetKeys === undefined ? null : o.resetKeys
            if (extra)
                for (var i = 0; i < extra.length; i++)
                    add(extra[i])
        })
        return out
    }

    // ⚠️ ONE PAGE PER TICK, NOT ALL TWENTY-ONE AT ONCE. The first version built
    // the whole index in a single call on the first keystroke, and that is a
    // visible freeze in the middle of typing — reported as the search hanging.
    // Twenty-one pages is not a small amount of work; doing it between frames
    // costs the same total and blocks nothing.
    //
    // ⚠️ AND IT STARTS WHEN THE WINDOW OPENS, not when he types. By the time
    // anyone reaches the search box it is finished, and a partial index is
    // still useful — `shown` reads whatever is there.
    property var rowIndexBuilding: null
    property int rowIndexAt: 0

    function buildIndex() {
        if (root.rowIndex !== null || indexer.running)
            return
        root.rowIndexBuilding = []
        root.rowIndexAt = 0
        indexer.start()
    }

    Timer {
        id: indexer
        interval: 1          // literal-ok: "the next tick", not a duration
        repeat: true
        onTriggered: {
            if (root.rowIndexAt >= root.pages.length) {
                indexer.stop()
                root.rowIndex = root.rowIndexBuilding
                return
            }
            var p = root.pages[root.rowIndexAt++]
            var comp = Qt.createComponent(p.source)
            if (comp.status !== Component.Ready)
                return
            // ⚠️ `null` AS THE PARENT, deliberately. Given `root` the page would
            // be a child of this FocusScope with no layout to place it — drawn
            // at the top left, over the real one. Parentless is what "build it
            // to look at it" means.
            var obj = comp.createObject(null)
            if (obj === null)
                return
            root.harvest(obj, p, root.rowIndexBuilding)
            obj.destroy()
        }
    }

    // What the sidebar lists. With an empty box that is the pages, in their own
    // sections; with a query it is matches, and a matching ROW is offered as
    // itself rather than as the page it happens to live on.
    readonly property var shown: {
        var q = search.text.trim().toLowerCase()
        if (q.length === 0)
            return root.pages

        var out = []
        var i, p
        for (i = 0; i < root.pages.length; i++) {
            p = root.pages[i]
            if (p.title.toLowerCase().indexOf(q) >= 0
                || p.blurb.toLowerCase().indexOf(q) >= 0)
                out.push({ id: p.id, icon: p.icon, title: p.title,
                           section: "Pages", source: p.source, blurb: p.blurb })
        }

        var idx = root.rowIndex
        if (idx !== null) {
            for (i = 0; i < idx.length; i++) {
                var r = idx[i]
                if (r.label.toLowerCase().indexOf(q) < 0
                    && r.hint.toLowerCase().indexOf(q) < 0
                    && r.key.toLowerCase().indexOf(q) < 0)
                    continue
                out.push({ id: r.page.id, icon: r.page.icon,
                           title: r.label.length ? r.label : r.key,
                           // The page is named on the entry, because "Blur" on
                           // its own does not say where you are about to go.
                           section: "Settings", rowKey: r.key,
                           source: r.page.source, blurb: r.page.title })
            }
        }
        return out
    }

    // ------------------------------------------------- getting to a found row
    // Landing on a page of seventeen rows with the right one somewhere in it is
    // barely better than not having searched, so the row is scrolled to and says
    // once that it is the one.
    property string pendingRow: ""

    function findByName(item, name) {
        if (!item)
            return null
        if (item.objectName === name)
            return item
        var kids = item.children === undefined ? [] : item.children
        for (var i = 0; i < kids.length; i++) {
            var hit = root.findByName(kids[i], name)
            if (hit)
                return hit
        }
        return null
    }

    function revealRow(key) {
        // ⚠️ THE PAGE FIRST, THEN THE WHOLE BODY. Not everything worth scrolling
        // to lives inside the page: "Reset this page" is part of this window's
        // own chrome, sits BELOW the loader and is a long way down on a tall
        // page — 993 px into a window 704 px tall, measured. Searching only the
        // page answered "no such row" for a control that was plainly there.
        var item = root.findByName(pageLoader.item, key)
                   || root.findByName(pageBody, key)
        if (!item)
            return
        var y = item.mapToItem(pageBody, 0, 0).y
        scroller.contentY = Math.max(0, Math.min(y - Theme.space5,
                                     Math.max(0, scroller.contentHeight - scroller.height)))
        if (typeof item.flash === "function")
            item.flash()
    }

    function goTo(entry) {
        var wasThere = entry.id === root.currentId
        root.pendingRow = entry.rowKey === undefined ? "" : entry.rowKey
        root.navigate(entry.id)
        // ⚠️ A row on the page already open never fires `onLoaded`, because
        // `navigate` returns early when the id has not changed. Without this the
        // search silently does nothing for exactly the rows you are closest to.
        if (wasThere && root.pendingRow.length) {
            var k = root.pendingRow
            root.pendingRow = ""
            Qt.callLater(function () { root.revealRow(k) })
        }
    }

    // ⚠️ AN OPEN LIST TAKES ESCAPE FIRST. Every popup list in here carries its
    // own Escape handler, and in the stand the keyboard never reached the popup
    // at all — so without this, Escape with a dropdown up would shut the whole
    // settings window and leave the person wondering what they pressed. The list
    // is the innermost thing on screen; it is what Escape means.
    // ⚠️⚠️ AND ESCAPE DOES NOT CLOSE THIS WINDOW — B57, and it is his reason
    // rather than a preference: "das settings fenster aber nur das               // english-ok: the request, quoted
    // settingsfenster soll man nicht mit esc schließen können da man das für     // english-ok: the request, quoted
    // z.b hotkey setzten braucht also beim abbrechen".                           // english-ok: the request, quoted
    //
    // Escape is the cancel key WHILE CAPTURING A KEY (settings/KeyCapture.qml
    // takes it for exactly that), and a window that also treats it as "shut"
    // makes the two meanings race. The narrower meaning wins here.
    //
    // ⚠️ IT STILL CLOSES AN OPEN LIST, which is the innermost thing on screen
    // and what Escape means there — that half is unchanged.
    //
    // ⚠️ AND THE WINDOW IS STILL CLOSABLE, checked rather than assumed: it is a
    // real window, so the compositor's own close reaches `onClosed` in
    // SettingsWindow.qml, the gear toggles it, and `ipc call settings hide`
    // exists. Rule 5 is about a way out existing, not about which key it is.
    //
    // ⚠️ ONLY THIS WINDOW. The island, the quick panel, the launcher and the
    // lock screen keep Escape; tests/notch-keys.sh checks that something over
    // there still answers it.
    Keys.onEscapePressed: {
        if (OpenMenu.current !== null)
            OpenMenu.closeCurrent()
    }

    // ⚠️⚠️ THE WINDOW TYPES FOR THE OPEN LIST, and that is what lets a dropdown
    // be searchable without a keyboard of its own. His request: "wenn man z.b m  // english-ok: the request, quoted
    // eingibt sucht man nach m und dann werden die sachen mit m angezeigt".      // english-ok: the request, quoted
    //
    // A list that had its own text box would need `grabFocus`, and a grab is
    // exactly what makes the compositor dismiss the surface on a click beside it
    // — the whole of B25, measured twice. This window already holds the
    // keyboard, so the characters are simply passed along.
    //
    // ⚠️ MEASURED BEFORE IT WAS BUILT, because "Escape arrives" does not prove
    // "letters arrive": a text field on the page could have held them. A probe
    // on this handler, a dropdown open, and a typed `m` produced
    // `text="m" key=77 menu=true` in the journal.
    //
    // ⚠️ AND THE FIRST RUN OF THAT MEASUREMENT WAS WORTHLESS — the session had
    // locked itself in the meantime and the probe was typing at the lock screen.
    // The screenshot size gave it away (735 kB, not 3.1 MB), which is why every
    // measurement here reads the size before it reads anything else.
    Keys.onPressed: function (event) {
        if (OpenMenu.current === null || !OpenMenu.wantsTyping())
            return
        if (event.key === Qt.Key_Backspace) {
            OpenMenu.backspace()
            event.accepted = true
            return
        }
        // ⚠️ PRINTABLE ONLY. `event.text` is not empty for Return, Tab and the
        // control characters — they carry "\r", "\t", "\u0000" — and appending
        // those to a search would filter everything away for a keypress that
        // looks like nothing happened.
        if (event.text.length === 1 && event.text.charCodeAt(0) >= 0x20) {
            OpenMenu.type(event.text)
            event.accepted = true
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.space4
        spacing: Theme.space4

        // ------------------------------------------------------------ sidebar
        //
        // ⚠️ PINNED, AND MEASURED BEFORE IT WAS. `Layout.preferredWidth` alone
        // is only a WISH: the content beside it has `fillWidth`, so a wide page
        // took room from the sidebar and a narrow one gave it back. The active
        // row was 312 px on Bar & Island, 282 on Clock & Date, 243 on System and
        // 208 on Appearance — the sidebar breathed with whichever page was open,
        // which is what he reported as wasted space.
        //
        // Pinned on all three, so the layout has nothing to negotiate. And the
        // number comes from the LONGEST ENTRY rather than from an invented
        // multiple of the grid: "Control Center" decides how wide this is, not
        // me. The floor only covers the case where the search field is the
        // widest thing in here.
        ColumnLayout {
            id: sidebar

            readonly property int pinned:
                Math.max(rail.implicitWidth, Theme.space6 * 5)

            Layout.fillHeight: true
            Layout.preferredWidth: sidebar.pinned
            Layout.minimumWidth: sidebar.pinned
            Layout.maximumWidth: sidebar.pinned
            spacing: Theme.space3

            TextField {
                id: search
                Layout.fillWidth: true
                placeholder: "Search Settings"
                onCancelled: {
                    if (search.text.length > 0)
                        search.text = ""
                    else
                        Ipc.hideSettings()
                }
                // The first match, so typing three letters and pressing Return
                // is a way to get somewhere rather than only a way to filter.
                onAccepted: if (root.shown.length > 0) root.goTo(root.shown[0])

                // Still a backstop: if the window was opened and closed fast
                // enough that the indexer never finished, typing restarts it.
                onTextChanged: if (search.text.length > 0) root.buildIndex()
            }

            // ⚠️ THE SIDEBAR HAS TO SCROLL NOW, and it did not before. Ten rows
            // fitted; twenty-one under three headings do not, and the first
            // screenshot after the split showed the list cut off at "Keyboard"
            // with everything below it — Shortcuts, Mouse, Windows, Power,
            // Programs, This Machine — simply unreachable. Splitting the pages
            // to make things findable, and hiding a third of them in the doing,
            // would have been a worse state than the one it replaced.
            // ⚠️⚠️ THIS IS THE BAR HE REPORTED, and it was not missing — it was
            // INSIDE the Flickable. A direct child of a Flickable is handed to
            // its contentItem, the thing that moves, so this bar's on-screen
            // position was `y - contentY`. With `y: contentY * ratio` that comes
            // to `contentY * (ratio - 1)`: negative and falling, so it climbed
            // out of the top of the view rather than tracking the scroll.
            // "die slider links im settings menu bei den tabs … der strich da   // english-ok: the report, quoted
            // bewegt sich nicht der geht noch nicht".                           // english-ok: the report, quoted
            //
            // ⚠️ Both bars had it, written the same way twice — which is why the
            // replacement is ONE component in common/ rather than a corrected
            // copy on each side.
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Flickable {
                    id: railScroll
                    anchors.fill: parent
                    clip: true
                    contentWidth: width
                    contentHeight: rail.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    SettingsRail {
                        id: rail
                        // ⚠️ `width`, not `Layout.fillWidth` — a Flickable is not a
                        // layout and silently ignores attached Layout properties, so
                        // the rail would have kept its implicit width and the rows
                        // would no longer reach the edge.
                        width: railScroll.width
                        entries: root.shown
                        currentIndex: {
                            for (var i = 0; i < root.shown.length; i++)
                                if (root.shown[i].id === root.currentId)
                                    return i
                            return -1
                        }
                        onActivated: function (i) { root.goTo(root.shown[i]) }
                    }
                }

                ScrollIndicator { flickable: railScroll }
            }

            // Nothing matched. One sentence, per the brief — not an empty box
            // and not a spinner.
            BarText {
                Layout.fillWidth: true
                visible: root.shown.length === 0
                text: root.rowIndex === null
                      ? "No page by that name"
                      : "Nothing by that name, in any page or setting"
                color: Theme.fgMuted
                wrapMode: Text.WordWrap
            }
        }

        // ------------------------------------------------------------ content
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.space4

            // ⚠️ THE ONE PLACE A REFUSED SETTING BECOMES VISIBLE, and it is
            // here because this is where the setting was made. The generator
            // will not install a config.kdl that the compositor rejects — an invalid one
            // means the compositor does not start at all — so a bad value leaves the
            // desktop working and the change simply not applied. Without this
            // banner that is indistinguishable from a control that does
            // nothing, which is the exact failure this whole window exists to
            // stop. It was also `Theming.lastError`'s first reader: the
            // property had none.
            Rectangle {
                Layout.fillWidth: true
                visible: Services.Theming.lastError.length > 0
                implicitHeight: refusal.implicitHeight + Theme.space3 * 2
                radius: Theme.radiusSm
                color: Theme.pillBg

                ColumnLayout {
                    id: refusal
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.space3
                    anchors.rightMargin: Theme.space3
                    spacing: Theme.space1

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space2
                        Icon { text: "warning"; size: Theme.fontSize; color: Theme.warn }
                        BarText {
                            Layout.fillWidth: true
                            text: "The last change was not applied"
                            color: Theme.warn
                            font.weight: Theme.weightMedium
                        }
                    }
                    BarText {
                        Layout.fillWidth: true
                        text: Services.Theming.lastError
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.fgMuted
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                    }
                    BarText {
                        Layout.fillWidth: true
                        text: "The desktop still boots — the previous configuration was kept. "
                            + "Details in /tmp/buchhwin-the compositor.log."
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.fgMuted
                        wrapMode: Text.WordWrap
                    }

                    // ⚠️ Not decoration. Putting the offending setting back does
                    // not move the fingerprint, so nothing regenerates and this
                    // banner would keep reporting a failure that is already
                    // repaired. This is the door out.
                    Pill {
                        interactive: !Services.Theming.busy
                        opacity: Services.Theming.busy ? Theme.dimmed : 1
                        BarText {
                            text: Services.Theming.busy ? "Trying…" : "Try again"
                            color: Theme.fg
                        }
                        onClicked: Services.Theming.retry()
                    }
                }
            }

            // ⚠️ THE ONE HARDWARE STATE THE DESKTOP CAN SEE AND THE USER CANNOT.
            // Four conditions at once, deliberately: an NVIDIA card is here, its
            // module has been built, Secure Boot is on, and the module is not
            // loaded. That combination has exactly one cause — the akmods
            // signing key was never enrolled, because the blue firmware screen
            // at the next boot has a short timeout and is easy to miss.
            //
            // ⚠️ AND THE FIRST LINE OF THE TEXT IS THAT IT DOES NOT MATTER MUCH.
            // A warning that reads like a broken machine, on a machine that is
            // working perfectly, is how people learn to click warnings away.
            // The compositor draws on the integrated GPU; this costs the second card.
            //
            // Same shape as the banner above rather than a new one: same
            // rounded pill background, same `warning` glyph — which tests/
            // icons.sh has already proven exists in the font.
            Rectangle {
                Layout.fillWidth: true
                visible: Services.Gpu.needsEnrolment || Services.Gpu.needsResigning
                implicitHeight: mok.implicitHeight + Theme.space3 * 2
                radius: Theme.radiusSm
                color: Theme.pillBg

                ColumnLayout {
                    id: mok
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.space3
                    anchors.rightMargin: Theme.space3
                    spacing: Theme.space1

                    // Local state, not an IPC verb: nothing outside this card
                    // needs to know whether the steps are open, and a verb
                    // nobody calls is a verb that rots.
                    property bool stepsOpen: false

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space2
                        Icon { text: "warning"; size: Theme.fontSize; color: Theme.warn }
                        BarText {
                            Layout.fillWidth: true
                            // ⚠️ TWO FAULTS, TWO SENTENCES. Both end with the
                            // module not loading, and saying "Secure Boot is
                            // blocking it" to somebody who has already enrolled
                            // his key sends him to check the one thing that is
                            // fine. Measured on this machine: three keys
                            // enrolled, nothing pending, module unsigned.
                            text: Services.Gpu.needsResigning
                                  ? "The NVIDIA driver was never signed"
                                  : "Secure Boot is blocking the NVIDIA driver"
                            color: Theme.warn
                            font.weight: Theme.weightMedium
                        }
                    }
                    BarText {
                        Layout.fillWidth: true
                        text: "Nothing on this desktop depends on it: the compositor draws with the built-in "
                            + "graphics. Only offloading and any monitor wired to the second card "
                            + "are affected."
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.fgMuted
                        wrapMode: Text.WordWrap
                    }
                    BarText {
                        Layout.fillWidth: true
                        visible: mok.stepsOpen
                        // ⚠️ TWO DIFFERENT ANSWERS, because the useful one
                        // depends on whether an enrolment is already waiting.
                        // Telling somebody to run a command they ran an hour ago
                        // is how a correct message becomes a useless one.
                        text: Services.Gpu.needsResigning
                            ? "Your key is enrolled — the modules are the problem. "
                              + "They were built before the key existed, so they "
                              + "carry no signature and the kernel refuses them "
                              + "(\"Key was rejected by service\").\n\n"
                              + "In a terminal:\n\n"
                              + "    sudo akmods --force --rebuild\n\n"
                              + "Then reboot. No blue screen this time: the key is "
                              + "already where it needs to be."
                            : Services.Gpu.enrolmentPending
                            ? "An enrolment is already scheduled.\n\n"
                              + "1. Reboot.\n"
                              + "2. A blue screen appears: choose Enroll MOK, Continue, Yes.\n"
                              + "3. Type the one-time password you chose during installation.\n\n"
                              + "The screen times out, so answer it when it appears."
                            : "In a terminal:\n\n"
                              // The trailing marker sits on the string's own line because
                              // tests/english.sh reads line by line. Safe here: the next
                              // line begins with `+`, so no semicolon can be inferred.
                              + "    sudo mokutil --import /etc/pki/akmods/certs/public_key.der\n\n"   // english-ok: .der is the certificate encoding
                              + "It asks for a one-time password twice. Then reboot: a blue screen "
                              + "appears, choose Enroll MOK, Continue, Yes, and type that password.\n\n"
                              + "The screen times out, so answer it when it appears."
                        font.pixelSize: Theme.fontSizeSm
                        font.family: Theme.fontMono
                        color: Theme.fgMuted
                        wrapMode: Text.WordWrap
                    }
                    Pill {
                        interactive: true
                        BarText {
                            text: mok.stepsOpen ? "Hide steps" : "Show steps"
                            color: Theme.fg
                        }
                        onClicked: mok.stepsOpen = !mok.stepsOpen
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space2

                Pill {
                    interactive: root.historyIndex > 0
                    opacity: root.historyIndex > 0 ? 1 : Theme.dimmed
                    Icon { text: "arrow_back"; size: Theme.fontSize; color: Theme.fg }
                    onClicked: root.back()
                }
                Pill {
                    interactive: root.historyIndex < root.history.length - 1
                    opacity: root.historyIndex < root.history.length - 1 ? 1 : Theme.dimmed
                    Icon { text: "arrow_forward"; size: Theme.fontSize; color: Theme.fg }
                    onClicked: root.forward()
                }
                Item { Layout.fillWidth: true }
            }

            // The page's own head: symbol in a rounded square, heading, and one
            // muted line under it. Centred, as the reference has it.
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.space2

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: Theme.space6 + Theme.space3
                    implicitHeight: Theme.space6 + Theme.space3
                    radius: Theme.radiusMd
                    color: Theme.surfaceHigh

                    Icon {
                        anchors.centerIn: parent
                        text: root.currentPage.icon
                        size: Theme.fontSizeXl
                        color: Theme.accent
                    }
                }

                BarText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.currentPage.title
                    font.pixelSize: Theme.fontSizeLg
                    font.weight: Theme.weightSemibold
                }

                BarText {
                    Layout.fillWidth: true
                    text: root.currentPage.blurb
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.fgMuted
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
            }

            // ------------------------------------------------------- the rows
            // ⚠️ AN Item AROUND THE FLICKABLE, and it is not decoration. The
            // scroll indicator has to be a SIBLING of the Flickable: a direct
            // child is handed to the contentItem, which is the thing that
            // moves, so the bar travelled at `contentY * (ratio - 1)` and slid
            // out of the top of the view. It shipped that way and was reported
            // as "der strich da bewegt sich nicht".                          // english-ok: the report, quoted
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Flickable {
                    id: scroller
                    anchors.fill: parent
                    clip: true
                    contentWidth: width
                    contentHeight: pageLoader.status === Loader.Error
                                 ? broken.implicitHeight : pageBody.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    // ⚠️ A NEW PAGE STARTS AT THE TOP. The Flickable lives OUTSIDE
                    // the Loader, so its scroll position survived the page change:
                    // opening System from a scrolled Appearance dropped you into the
                    // middle of the touchpad settings, with the group heading above
                    // the fold. Both references reset — and so does every browser.
                    Connections {
                        target: root
                        function onCurrentIdChanged() { scroller.contentY = 0 }
                    }

                    ColumnLayout {
                        id: pageBody
                        // Room for the scrollbar, so a row's right edge and the bar
                        // are not fighting over the same pixels.
                        width: scroller.width - Theme.space3
                        spacing: Theme.space4

                        Loader {
                            id: pageLoader
                            Layout.fillWidth: true
                            Layout.preferredHeight: pageLoader.implicitHeight

                            source: root.currentPage.source

                            // The page exists now, so the row inside it can be
                            // found. `onLoaded` rather than a timer: there is
                            // nothing to wait for beyond this, and a timer would be
                            // a guess at how long a page takes on a machine nobody
                            // has measured.
                            onLoaded: {
                                root.currentKeys = root.pageKeys(pageLoader.item)
                                if (!root.pendingRow.length)
                                    return
                                var k = root.pendingRow
                                root.pendingRow = ""
                                Qt.callLater(function () { root.revealRow(k) })
                            }
                        }

                        // ------------------------------------------- reset this page
                        //
                        // ⚠️ ONE ROW HERE RATHER THAN TWENTY-TWO IN THE PAGES. Every
                        // page would have needed the same block, the twenty-third
                        // would have been written without it, and nothing would have
                        // said so — the shape of fault this window keeps paying for.
                        // The keys come from the page itself, so a page that gains a
                        // row gains it here too, on the same frame.
                        //
                        // ⚠️ IT ASKS. First press arms, second does it, and moving
                        // to another page disarms — exactly the session buttons in
                        // the quick panel, and for the same reason: what keeps that
                        // safe is not the wording but that an armed action cannot
                        // survive going somewhere else. Measured there by arming,
                        // closing and reopening.
                        SettingGroup {
                            Layout.fillWidth: true
                            // ⚠️⚠️ NOT GATED ON `currentKeys` ANY MORE, AND THAT WAS
                            // A HEIGHT THAT ARRIVED LATE. `currentKeys` is filled in
                            // `onLoaded` rather than bound — deliberately, see the
                            // note where it is declared — so this group appeared a
                            // frame after the page had already been laid out, and
                            // the column grew under the cursor. That is the shape
                            // this project has paid for as "es zuckt" three times    // english-ok: his report, quoted
                            // already, and the last two fixes were guesses.
                            //
                            // The row is always here and simply cannot be pressed
                            // when the page has nothing of its own, which is also
                            // more honest than a control that comes and goes: the
                            // page did not gain a feature when its keys arrived.
                            visible: pageLoader.status === Loader.Ready
                            title: "Reset"

                            ActionRow {
                                Layout.fillWidth: true
                                usable: root.currentKeys.length > 0
                                // ⚠️ A NAME SO IT CAN BE PRESSED FROM OUTSIDE.
                                // `ipc call settings probe` finds a control by
                                // dotted key, and this one has none — it acts on
                                // the whole page. tests/click.sh presses it for
                                // real, which is the only way to measure a
                                // TWO-STAGE button: the first press only arms it,
                                // and every checker that called the function
                                // directly skipped straight past that.
                                objectName: "reset-page"
                                label: "Reset this page"
                                // ⚠️ ONE LINE, ALWAYS, AND THE SAME LENGTH OF LINE.
                                // A hint that grows from "no settings" to "eleven
                                // settings on Colours…" reflows the row, which is
                                // the same late height the group itself used to
                                // have — one frame lower down.
                                hint: root.currentKeys.length === 0
                                      ? "This page has no settings of its own to reset."
                                      : root.currentKeys.length
                                        + (root.currentKeys.length === 1
                                           ? " setting on " : " settings on ")
                                        + root.currentPage.title
                                        + " back to the defaults. The file you have now is kept as shell.json.bak."
                                button: root.resetArmed
                                        ? "Again to confirm" : "Reset page"
                                destructive: true
                                // ⚠️ THE ARMED STATE SAYS SO IN WORDS, and it did
                                // not before. The only sign of a first press was
                                // the button's own caption changing from "Reset
                                // page" to "Again to confirm" — four words in the
                                // one place your finger is covering. He pressed it
                                // and reported "die reset taste geht nicht", which  // english-ok: his report, quoted
                                // is exactly what a working two-stage button looks
                                // like when stage one is invisible.
                                //
                                // The quick panel's power buttons already do this:
                                // they print "Power off? Again to confirm" beside
                                // themselves. Same pattern, same reason.
                                status: root.resetArmed
                                        ? "Press again to reset " + root.currentPage.title
                                          + ". Going to another page cancels it."
                                        : (Backup.lastAction === "page" ? Backup.status : "")
                                failed: Backup.failed && !root.resetArmed
                                onTriggered: {
                                    if (!root.resetArmed) {
                                        root.resetArmed = true
                                        return
                                    }
                                    root.resetArmed = false
                                    Backup.resetPaths(root.currentKeys,
                                                      root.currentPage.title)
                                }
                            }
                        }
                    }

                    // ⚠️ NOT DEAD CODE, though every entry above names a file that
                    // exists. This is what a mistyped or deleted page looks like now
                    // — and it is the same fault the old placeholder was for, caught
                    // one step earlier: a Loader whose source will not load reports
                    // Error, where a Loader with a null component simply drew
                    // nothing and read as a page that happened to be empty.
                    ColumnLayout {
                        id: broken
                        width: pageLoader.width
                        visible: pageLoader.status === Loader.Error
                        spacing: Theme.space2

                        BarText {
                            Layout.fillWidth: true
                            text: root.currentPage.title + " did not load."
                            color: Theme.error
                            wrapMode: Text.WordWrap
                        }
                        BarText {
                            Layout.fillWidth: true
                            text: "Its file is " + root.currentPage.source
                                + " — check the path in the page list, and the log "
                                + "for what QML made of it."
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.fgMuted
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // ⚠️ ON THE RIGHT, and OUTSIDE the Flickable — see the note on
                // the Item above for what the inside costs.
                ScrollIndicator { flickable: scroller }
            }
        }
    }

    // ---------------------------------------------------------------- refused
    // ⚠️⚠️ WHEN A SETTING REFUSES TO BE WRITTEN, THE WINDOW SAYS SO.
    //
    // His report was "manche switches gehen nicht wie z.b. der dock switch",     // english-ok: the report, quoted
    // later "die slider egal welcher macht nix … ich weiß nicht ob das optisch   // english-ok: the report, quoted
    // ist oder nicht", and that last clause is the point: he could not tell      // english-ok: the report, quoted a
    // control that had not written from one that had written and not taken
    // effect. `Config.set` warned to the journal and returned false, the row
    // re-read the unchanged value and snapped back, and the screen said nothing.
    //
    // ⚠️ THIS DOES NOT FIX THE WRITE. Every one of the rows writes correctly on
    // the machines it has been measured on, so the cause is still open and still
    // on his. What this does is turn a silent failure into a named one — which
    // is what rule 5 asks for, and what would have shortened the last three
    // rounds of guessing at it.
    //
    // ⚠️ IT SITS OVER THE CONTENT, not in the column. In the layout it would add
    // a row, so the page would move under the pointer at the moment something
    // went wrong — which is the fault B6 was about.
    Rectangle {
        id: writeRefusal

        property string path: ""
        property string reason: ""

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.space4
        implicitHeight: writeRefusalText.implicitHeight + Theme.space3 * 2
        radius: Theme.radiusMd
        color: Theme.surfaceHigher
        visible: opacity > 0
        opacity: writeRefusal.path.length > 0 ? 1 : 0

        Behavior on opacity {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
        }

        BarText {
            id: writeRefusalText
            anchors.fill: parent
            anchors.margins: Theme.space3
            // Named, not "something went wrong". The key is the one thing that
            // makes the next step obvious, and it is what the journal line says
            // too, so the two can be lined up.
            text: writeRefusal.path.length > 0
                ? "This setting was not written: " + writeRefusal.path
                  + " (" + writeRefusal.reason + "). Your shell.json is missing it — "
                  + "run bhctl doctor."
                : ""
            font.pixelSize: Theme.fontSizeSm
            color: Theme.warn
            wrapMode: Text.WordWrap
        }

        Timer {
            id: writeRefusalClear
            interval: 8000
            onTriggered: { writeRefusal.path = ""; writeRefusal.reason = "" }
        }

        Connections {
            target: Config
            function onRefused(path, reason) {
                writeRefusal.path = path
                writeRefusal.reason = reason
                writeRefusalClear.restart()
            }
        }
    }
    // ⚠️⚠️ "Reset everything" ASKS ON A SURFACE THAT COVERS THE WHOLE WINDOW, so
    // it lives HERE rather than on the page that offers it. A page is inside a
    // Layout, and an item that fills its own window from inside a layout is
    // "anchors on an item that is managed by a layout" — undefined behaviour,
    // and tests/pages.sh caught exactly that on the first build.
    //
    // ⚠️ The page could have reached up through `Window.contentItem` instead.
    // It must not: that expression appears once in this project's history, as
    // the cause of a dropdown that was "fixed" twice before anybody read the
    // note. A signal upward and an owner at the top is the shape that does not
    // need to know where it is.
    //
    // ⚠️ `ignoreUnknownSignals` because twenty-two of the twenty-three pages do
    // not have this signal and must not warn about it.
    Connections {
        target: pageLoader.item
        ignoreUnknownSignals: true
        function onAskReset() { resetSheet.open = true }
    }

    ResetSheet {
        id: resetSheet
        anchors.fill: parent
        z: 100     // literal-ok: stacking order, not a measurement
    }

}
