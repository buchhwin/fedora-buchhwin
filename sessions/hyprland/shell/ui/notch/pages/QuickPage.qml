pragma ComponentBehavior: Bound

// The quick panel: the one surface that answers "what is going on".
//
// It is what clicking the notch opens, and it is deliberately the only page
// that gathers things rather than showing one: the month, the weather, the
// handful of sliders worth reaching for, and the way into the settings. Every
// other page is a single answer to a single question.
//
// FOUR TABS. It started with two, on the argument that a third column would
// stop the panel being a glance — and that argument was about COLUMNS, which is
// still right and is why none of this sits side by side. As tabs they cost
// nothing: only one is built at a time, and each stays as sparse as it was.
//
// Overview and Media were already here. Notifications is the same page Mod+N
// opens, and Settings is the switches — network, bluetooth, night light, do not
// disturb, microphone, the bar — with sound and brightness under them.
//
// ⚠️ NOT ONE COPY MORE. The month, the media transport and the notification
// list are the SAME components the standalone pages use, never a second one
// built to fit here. Two month grids would drift — different weekday order,
// different today marker — and disagree on one screen.
//
// Two columns inside the overview, because the island is wide and short. The
// calendar is the tall thing, so it takes the left side and sets the height;
// everything else stacks beside it.
//
// ⚠️ The calendar here is the SAME CalendarPage, not a copy of it. A second
// month grid would drift from the first — different weekday order, different
// today marker — and the two would sit on the same screen disagreeing.
import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../config"
import "../../../ipc"
import "../../../services" as Services
import "../../common"
import "../../quick"

RowLayout {
    id: root
    spacing: Theme.space4

    // ⚠️ ESC CLOSED EVERY OTHER PAGE AND NOT THIS ONE. OverlaySurface already
    // grants keyboard focus for "quick" — `wantsKeys` names it explicitly — but
    // nothing inside the panel ever TOOK that focus, so the key went nowhere.
    // The calculator, the clipboard, the theme grid, the wallpaper grid and the
    // session page all do exactly this; the panel you reach for most often was
    // the one you could not dismiss.
    focus: true
    // ⚠️ INNERMOST FIRST. With a WiFi or Bluetooth list open, Esc closes THAT and
    // leaves the panel — closing both at once throws away two steps of
    // navigation for one keypress, and there is no way back to where you were.
    // ⚠️ THIS HANDLER USED NOT TO RUN AT ALL, and the note that said so has been
    // replaced rather than deleted, because the finding was real and the fix is
    // somewhere else. Measured then: a `console.warn` as its first line printed
    // nothing with the panel open and Escape pressed. `card` in OverlaySurface
    // holds the focus and the two items between it and here — NotchContent and
    // the page Loader — never handed it on. `focus: true` on those two was tried
    // and measured and did not help; several items in one focus scope are not a
    // chain.
    //
    // What fixed it is an explicit chain of `Keys.forwardTo`, card → NotchContent
    // → the loaded page, so a key reaches the page BEFORE the surface and the
    // surface only sees what the page did not answer. The reasoning is written
    // out at the top of OverlaySurface.qml.
    //
    // ⚠️ WHAT MAKES THE ARMED SHUTDOWN SAFE IS STILL NOT THIS HANDLER: the panel
    // is rebuilt from scratch every time it opens, so an armed action cannot
    // survive a close. Measured, not assumed. That belt stays on now that this
    // brace works.
    Keys.onEscapePressed: {
        if (!quickSettings.closeDrawer())
            Ipc.collapse()
    }

    // Which view is showing. The value lives in Ipc, not here: the gear on the
    // bar opens this panel already on the settings view, and this page is built
    // afresh every time the surface opens, so a property of its own would
    // forget the tab between openings.
    readonly property int tab: Ipc.quickTab

    // ⚠️ ONE WIDTH FOR ALL FOUR TABS, and it is a bug fix rather than tidiness.
    // Measured on the running VM: the panel was 669 px wide on Overview and
    // 619 px on Settings, so it changed size by 50 px every time you touched a
    // tab. Each view was simply asking for whatever its own contents wanted,
    // and the surface follows the content on both axes (see NotchContent).
    //
    // ⚠️ It went from 20 to 24 grid units when the switches moved in beside the
    // calendar. Measured, one step at a time: at 20 the tile read "Do not
    // dis…", at 22 "Do not distu…", at 24 the whole name fits. A switch whose
    // name is cut off is a switch you have to guess at.
    //
    // ⚠️ Widening the PANEL is the fix rather than the tile, because the tile
    // cannot ask for what it needs: its label is `Layout.fillWidth` with
    // `elide: Text.ElideRight` (ui/quick/Tile.qml), so it silently accepts
    // whatever it is given and cuts the text. Making it demand its natural
    // width instead would break the grid on a narrow screen, where eliding is
    // the correct behaviour.
    // ⚠️ It is deliberately MORE than `notch.minExpandedWidth` (619): that key
    // is a FLOOR from the reference screenshot, not a ceiling, and the quick
    // panel is the one page whose job is to gather things rather than show one.
    //
    // ⚠️ Declared through `Layout.preferredWidth` rather than by assigning
    // `implicitWidth`. A Layout computes its own implicit size and writes it,
    // so assigning it means whoever writes last wins — which is a size that
    // changes on rearrange.
    // ⚠️ 608, NOT 768, AND THE OLD NUMBER WAS MEASURED WRONG. 768 came from
    // looking at the panel with the calendar and the tiles side by side — both
    // already cut down to fit — so it recorded what they had settled for rather
    // than what they asked for. With the calendar on its own tab the widest
    // thing here is QuickSettings, which wants exactly this.
    readonly property int contentWidth: Theme.space6 * 19

    // ⚠️⚠️ AND ONE HEIGHT FOR ALL FOUR TABS, WHICH IS THE OTHER HALF OF THE SAME
    // FIX AND WAS MISSING. The width above was pinned because the panel changed
    // by 50 px on every tab; the height was left following its contents, so it
    // still moved — and he saw it: "wenn ich links auf manche knöpfe in der      // english-ok: the report, quoted
    // leiste drücke springt das quickpanel immer so leicht aber nur bei den      // english-ok: the report, quoted
    // oberen". The upper buttons are exactly the tabs; the lower ones open       // english-ok: the report, quoted
    // another surface and cannot resize this one.
    //
    // Measured on the running VM, panel height per tab: 345 · 367 · 345 · 345 ·
    // 345. The calendar is 22 px taller than the other four, and the window
    // follows the card on both axes — so switching to it or away from it is a
    // real `set_size` on a Wayland surface, not a repaint.
    //
    // ⚠️ A FLOOR, NOT A FIXED SIZE. `Layout.minimumHeight` lets a tab that
    // genuinely needs more still have it — a notification list can grow — while
    // no tab is ever SMALLER than the tallest of them. Pinning it outright
    // would clip whatever came along next, which is the failure this project
    // dislikes more than a wobble.
    //
    // ⚠️ THE NUMBER IS DERIVED FROM A MEASUREMENT, NOT PICKED. With the floor
    // set deliberately huge (14 units = 448 px) the window came out 465, so the
    // card adds a constant 17 px of its own. The tallest tab wants 367 of
    // window, which is 350 of floor — and 11 grid units is 352, the first step
    // on the scale that clears it.
    // ⚠️⚠️ RE-MEASURED, AND THE OLD FLOOR WAS TOO LOW BY ONE STEP. He reported it
    // again — "bei den ersten drei punkten in der leiste links im quickpanel     // english-ok: the report, quoted
    // zittert das ganze panel" — and the three he means are exactly the first    // english-ok: the report, quoted
    // three entries of the rail: Overview, Calendar, Media. The calendar sits
    // between the other two, so switching to it and away from it is the only
    // move that changes anything, which is why it is "the top ones" and not all
    // of them, in both reports.
    //
    // ⚠️ THE FLOOR IS NOT THE WINDOW. The card adds a constant of its own, and
    // this is the arithmetic rather than a guess. Measured with the new
    // `ipc call notch size`, on the running shell, one reading per tab:
    //
    //     Overview 400 · Calendar 414 · Media 400 · Notifications 400 · Timer 400
    //
    // Every tab except the calendar sits exactly on the floor: 352 of floor
    // came out as 400 of card, so the card's own constant is 48. The calendar
    // wants 414, which is 366 of floor — above 352, so it grew and everything
    // moved. `space6 * 11 + space4` is 368, the first step on the scale that
    // clears it, and 368 + 48 = 416 for every tab.
    //
    // ⚠️ AND IT HAD TO BE RE-MEASURED AFTER B44, not before: making the three
    // sliders thin changed the height of the overview tab, so a number taken
    // before that change would have been wrong by the time it shipped.
    // ⚠️⚠️ AND IT DEPENDS ON THE FOLD, WHICH IS THE HALF I MISSED. The
    // measurement above was taken with "Show more" SHUT, so it pinned exactly
    // one of the two states. With the fold OPEN the overview carries four more
    // tiles and a second brightness row, and the reading says so:
    //
    //     shut    416 · 416 · 416 · 416 · 416
    //     open    519 · 416 · 416 · 416 · 416
    //
    // So with the fold open every tab change moved the surface by 103 px, and
    // that is what he reported: "wenn ich im quick panel auf more clicke dann   // english-ok: the report, quoted
    // buggt das quickpanel komisch rum". The panel was not misbehaving when he  // english-ok: the report, quoted
    // pressed the button — it was misbehaving on every press AFTER it.
    //
    // Two states, two floors. Same arithmetic as before: the card adds a
    // constant 48, so 519 of card wants 471 of floor, and `space6*3 + space2`
    // is the first step on the scale that clears the difference.
    //
    // ⚠️ HIS CHOICE, ASKED AND ANSWERED: the panel may grow when the fold is
    // opened — that is a button he pressed on purpose — and must not move when
    // he only changes tab. Pinning one height for both states would have made
    // the shut panel carry the open one's emptiness on every tab.
    //
    // ⚠️ AND THE GROWTH IS ONE STEP, NOT AN ANIMATION. Rule 7 is explicit that
    // nothing animates a layout size: a Wayland layer surface re-measures per
    // frame while such a number moves, which is protocol traffic rather than
    // drawing. The softness belongs to what appears INSIDE the new room.
    // ⚠️⚠️ B74 · IT READS THE PANEL'S LIVE FOLD, NOT THE STORED KEY. This used to
    // be `Config.quick.showMore`, which was the same value at the time because
    // the tiles read the setting too. Since B74 the fold is runtime state seeded
    // from the setting — so reading the key here would size the surface for the
    // fold he chose LAST TIME while the tiles show the one in front of him. That
    // is a card whose floor disagrees with its own contents, which is B67 with a
    // new cause, and it would have looked exactly like B67 in a report.
    readonly property int contentHeight:
        Theme.space6 * 11 + Theme.space4
        + (quickSettings.showMore ? Theme.space6 * 3 + Theme.space2 : 0)

    // ------------------------------------------------------------------- rail
    // ⚠️ SYMBOLS DOWN THE LEFT, NOT PILLS ACROSS THE TOP — his choice. The
    // component is `common/IconRail.qml` rather than something built here.
    // ⚠️ The reason given here used to be "the settings window has the same
    // strip", and it was wrong — that sidebar is SettingsRail, a different
    // control with named rows. See IconRail's header. The real reason to keep
    // the pill-and-tooltip mechanics in one file is that they are the part that
    // was expensive to get right, not that a second caller exists.
    //
    // ⚠️ The glyphs were chosen by `tests/icons.sh`, not by taste: `grid_view`
    // and `space_dashboard` are both MISSING from "Material Icons Round", which
    // is how "Overview" ended up as `dashboard`.
    // ⚠️ SIX ENTRIES, AND TWO OF THEM ARE DOORS RATHER THAN TABS. His request
    // of 07.08.2026: a button for the theme menu and one for the wallpapers,
    // beside the four views. Both already exist as their own surfaces, on
    // Mod+Shift+A and Mod+Shift+W — rebuilding either as a fifth and sixth tab
    // would be a second theme grid to drift from the first, which is the
    // mistake this file's header spends a paragraph on.
    //
    // So an entry may carry a `page`, and the rail opens that instead of
    // switching tab. Two behaviours in one strip, told apart by the DATA rather
    // than by the index — an index test would need correcting every time the
    // order changed.
    // ⚠️ THE TAB IS ON THE ENTRY NOW, not the position in this list. It used to
    // be `Ipc.quickTab = i` — the rail index WAS the tab number — so inserting
    // the calendar anywhere but the end would silently have renamed Media,
    // Notifications and Timer. That is the same reasoning the note above gives
    // for `page`, applied to the other half of the entry.
    readonly property var railEntries: [
        { icon: "dashboard",     tooltip: "Overview",      tab: Ipc.quickOverview },
        // ⚠️ `schedule` IS A CLOCK FACE, and this tab is the calendar. Time of day
        // and a date are not the same question, and the panel already has a clock
        // in the island above it. Enlarged from a screenshot it is unmistakably a
        // wall clock. `calendar_today` is in this font — checked, not assumed.
        { icon: "calendar_today", tooltip: "Calendar",      tab: Ipc.quickCalendar },
        { icon: "music_note",    tooltip: "Media",         tab: Ipc.quickMedia },
        { icon: "notifications", tooltip: "Notifications", tab: Ipc.quickNotifications },
        { icon: "timer",         tooltip: "Timer",         tab: Ipc.quickTimer },
        { icon: "palette",       tooltip: "Theme",     page: "theme" },
        { icon: "wallpaper",     tooltip: "Wallpaper", page: "wallpaper" }
    ]

    IconRail {
        // ⚠️⚠️ TOP-ALIGNED, AND THAT REVERSES AN EARLIER CHOICE OF HIS. This read
        // `Layout.fillHeight` + `centred` — the group sat in the MIDDLE of the
        // panel. On 06.08 he had asked for exactly that ("nicht über die ganze   // english-ok: the request, quoted
        // höhe aber gleiche größe alles schon mittig"), and centring is what     // english-ok: the request, quoted
        // that produced.
        //
        // The trouble is that the panel is a different height on every tab — the
        // calendar is a month grid, the timer is three rows — so a centred group
        // sits somewhere new each time you switch. He found it and named the
        // cause himself: "die leiste links am besten oben bündig machen damit    // english-ok: the request, quoted
        // die einzelnen punkte immer an der gleichen stelle sind".               // english-ok: the request, quoted
        //
        // So the requirement was never "middle" — it was "the same place every
        // time", and the middle of a changing height cannot deliver that. Top of
        // a strip that starts at the top can.
        Layout.alignment: Qt.AlignTop
        // Which POSITION shows as active, found from the tab rather than
        // assumed to be it. A door entry has no `tab`, so it can never match —
        // which is correct, and is why it is drawn dimmed instead.
        currentIndex: {
            for (var i = 0; i < root.railEntries.length; i++)
                if (root.railEntries[i].tab === root.tab)
                    return i
            return -1
        }
        entries: root.railEntries

        onActivated: function (i) {
            var e = root.railEntries[i]
            if (!e)
                return
            if (e.page)
                Ipc.toggle(String(e.page))
            else
                Ipc.quickTab = e.tab
        }
    }

    // Everything that is not the rail. It is its own column so the rail stays
    // the height of four symbols instead of stretching to the calendar.
    ColumnLayout {
        id: body
        Layout.alignment: Qt.AlignTop
        Layout.preferredWidth: root.contentWidth
        Layout.minimumHeight: root.contentHeight
        spacing: Theme.space4

    // The way out of the panel entirely — the full settings window. On its own
    // row now that the tabs have left the top, right-aligned so it does not
    // read as a fifth entry.
    //
    // ⚠️ AND THE SESSION BUTTONS JOIN THIS ROW RATHER THAN GET THEIR OWN. He
    // asked for them "ins rechte obere eck vom quickpanel", and there is        // english-ok: the request, quoted
    // already a right-aligned corner here. A second header row is precisely the
    // spacing fault this file spends a paragraph on further down — three loaders
    // each contributing their own `space4` is what "der abstand im               // english-ok: the report, quoted
    // quicksettings menu passt immer noch nicht" turned out to be.               // english-ok: the report, quoted
    RowLayout {
        Layout.fillWidth: true
        // ⚠️⚠️ AND EXPLICITLY NOT FILLING THE HEIGHT, WHICH IS B18 A SECOND TIME
        // ONE LEVEL DOWN. His report: "sind auf allen seiten die höhe der        // english-ok: the report, quoted
        // shutdown restart etc button unterschiedlich" — asked about, and he    // english-ok: the report, quoted
        // named the shape himself: "sie sitzen je Tab woanders".                // english-ok: his answer, quoted
        //
        // A child of a ColumnLayout that is ITSELF a layout has
        // `Layout.fillHeight` true by default. Everything below this row either
        // carries `Layout.alignment: Qt.AlignTop` or is a Loader, so this row
        // was the only thing absorbing the slack — and `body` has a minimum
        // height of eleven grid units while each tab wants a different amount.
        // The row therefore grew by a different number of pixels per tab, and
        // `SessionButtons` sits in the MIDDLE of it.
        //
        // That is exactly the fault the rail above this file's own comment
        // describes: the middle of a changing height is somewhere new every
        // time. The requirement was never "middle", it is "the same place every
        // time", and only a fixed edge delivers that.
        Layout.fillHeight: false
        spacing: Theme.space3

        // ⚠️ THE SPACER FIRST. He asked for "das rechte obere eck", and the      // english-ok: the request, quoted
        // first build put the five pills at the LEFT end of this row because
        // that is where a RowLayout starts. Measured on screen before it was
        // noticed, which is the only reason it was.
        Item { Layout.fillWidth: true }

        SessionButtons {
            id: session
            Layout.alignment: Qt.AlignVCenter
            // Closing the panel is the caller's job — the service knows nothing
            // about surfaces. Lock and suspend want it gone; the three that ask
            // have already had their second press by the time this runs.
            onRan: Ipc.collapse()
        }

        // ⚠️ A GEAR, AND IT WAS ASKED FOR TWICE. The brief has said so since the
        // panel was designed — "und auch ein zahnrad mit dem man auf die         // english-ok: the brief, quoted
        // settings generell kommt" — and it shipped as `open_in_new`, an arrow   // english-ok: the brief, quoted
        // leaving a box, which is a different sentence: it says "this opens
        // elsewhere", not "this is settings". He had to report it: "im           // english-ok: his report, quoted
        // quuickpanel menu hat der settingsbutton kein zahnrad".                 // english-ok: his report, quoted
        //
        // ⚠️ `settings` IS THE SAME NAME ui/bar/BarContent.qml ALREADY USES for
        // the same destination, so the two ways in now look like one thing.
        // Rendered and looked at rather than assumed: it is the gear.
        Pill {
            interactive: true
            Icon { text: "settings"; size: Theme.fontSizeLg }
            onClicked: root.openSettings()
        }
    }

    // ---------------------------------------------------------------- media
    // The same MediaPage the island uses on its own — artwork, title, transport.
    // A second one would drift, exactly as a second calendar would.
    MediaPage {
        Layout.fillWidth: true
        visible: root.tab === Ipc.quickMedia
        // B58 · it fills the tab now; see the spacer at the foot of this column.
        Layout.fillHeight: root.tab === Ipc.quickMedia
    }

    // ⚠️ `Loader`, not `visible: false`, for these two. The month and the media
    // transport are cheap and already built; a notification list and a settings
    // view that starts wifi scans are not, and building them to leave them
    // hidden is exactly the idle work this desktop is not allowed to do. Each
    // exists only while its tab is the one showing.
    //
    // ⚠️ AND EVERY ONE OF THEM NEEDS `visible: active`. This is "der abstand im  english-ok: the report, quoted
    // quicksettings menu passt immer noch nicht", and it is not a padding       english-ok: the report, quoted
    // problem at all. A Loader with `active: false` is 0 px tall — but it is
    // still VISIBLE, and QtQuick.Layouts gives every visible item its row
    // spacing whether or not it has any height. Three loaders sit between the
    // tab row and the content, so on Settings two of them were contributing
    // `space4` each for nothing.
    //
    // Measured on the VM before the fix, column x=700 through the Overview pill
    // and the Wi-Fi tile: pill bottom y=49, tile top y=98 — a 48 px gap where
    // `space4` is 16. Exactly three spacings where there should be one.
    Loader {
        Layout.fillWidth: true
        active: root.tab === Ipc.quickNotifications
        visible: active
        // ⚠️ SYNCHRONOUS ON PURPOSE. What this loader builds decides the size of
        // the card, and the card decides the size of the layer surface. Loading
        // it a frame late means the surface is configured at one size and then
        // re-configured when the content lands — a round trip with the compositor and a
        // new buffer, and on screen a panel that opens at the wrong size and
        // grows while you look at it. It is one small view, not the twenty-one
        // settings pages whose synchronous build was a real freeze.
        asynchronous: false
        sourceComponent: notificationsTab
    }

    // The same TimerPage that Mod+Shift+T opens, not a second one. A countdown
    // shown in two places that disagree about how long is left is worse than a
    // countdown in one place — the same reason the calendar and the media
    // transport are reused rather than rebuilt.
    Loader {
        Layout.fillWidth: true
        active: root.tab === Ipc.quickTimer
        visible: active
        // ⚠️ SYNCHRONOUS ON PURPOSE. What this loader builds decides the size of
        // the card, and the card decides the size of the layer surface. Loading
        // it a frame late means the surface is configured at one size and then
        // re-configured when the content lands — a round trip with the compositor and a
        // new buffer, and on screen a panel that opens at the wrong size and
        // grows while you look at it. It is one small view, not the twenty-one
        // settings pages whose synchronous build was a real freeze.
        asynchronous: false
        // ⚠️ `timerTab`, not `TimerPage {}`. This one was left behind when the
        // other two were fixed, in the same file, four lines above the comment
        // that explains why it is wrong — a recipe is what a Loader wants, and
        // an instance is built once and kept forever.
        sourceComponent: timerTab
    }

    // ⚠️ COMPONENTS, NOT INSTANCES — the same trap NotchContent.qml already
    // names, and it was walked into here anyway. `sourceComponent: QuickSettings
    // {}` writes an OBJECT into a property that wants a recipe: the object is
    // built at once and stays built, so the settings view and the notification
    // list existed the whole time the panel was open on some other tab. That is
    // the opposite of what the Loader is for — "a closed list does not exist" —
    // and it is the likeliest reason the panel sometimes came up far too tall,
    // reported as "sometimes the gap gets too big, down to the bottom of the
    // screen, but only sometimes".
    Component { id: notificationsTab; NotificationsPage {} }
    Component { id: timerTab; TimerPage {} }

    // --------------------------------------------------------------- calendar
    // ⚠️ A TAB OF ITS OWN, because side by side it never fitted. Measured:
    // CalendarPage asks for 576 px and QuickSettings for 608, which is 1208
    // before the gap — and `body` was pinned to 768. Both children were
    // permanently squeezed below their natural size, and that 768 had been
    // measured against the already-elided result rather than against what they
    // wanted. Two views that each get their width beat one view where both are
    // wrong.
    CalendarPage {
        visible: root.tab === Ipc.quickCalendar
        Layout.alignment: Qt.AlignTop
    }

    // --------------------------------------------------------------- overview
    ColumnLayout {
        visible: root.tab === Ipc.quickOverview
        Layout.alignment: Qt.AlignTop
        Layout.minimumWidth: Theme.space6 * 9
        spacing: Theme.space4

        // ------------------------------------------------------------ weather
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.space1

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space3
                visible: Services.Weather.available

                Icon {
                    text: Services.Weather.iconName
                    size: Theme.fontSizeXl
                    color: Theme.fg
                }

                ColumnLayout {
                    spacing: 0   // literal-ok: absence of a gap — the temperature and its
                                 // description are one label on two lines, not two things
                    BarText {
                        text: Math.round(Services.Weather.temperature) + "°"
                        font.pixelSize: Theme.fontSizeLg
                        font.weight: Theme.weightSemibold
                    }
                    BarText {
                        text: Services.Weather.description
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.fgMuted
                    }
                }

                Item { Layout.fillWidth: true }

                BarText {
                    text: Services.Location.name
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.fgMuted
                    elide: Text.ElideRight
                    Layout.maximumWidth: Theme.space6 * 4
                }
            }

            // The place is set through the shared picker, so the settings
            // window (M8) will use the same component rather than a second one
            // — and choosing "Berlin" anywhere shows up here in the same
            // instant, because both read one binding.
            LocationPicker {
                Layout.fillWidth: true
                compact: true
                visible: !Services.Weather.available || Services.Location.guessed
            }
        }

        // ------------------------------------------- the switches and levels
        // ⚠️ THE SAME QuickSettings THE SETTINGS TAB USED TO BE, PUT HERE —
        // not a copy. Two sets of tiles would drift: one would learn about a
        // new switch and the other would not, and they would sit on one screen
        // disagreeing about whether the wifi is on.
        //
        // It brings its own volume and brightness rows, which is why the two
        // this column used to carry are gone rather than kept: the panel would
        // otherwise have shown each slider twice.
        //
        // His decision on 06.08.2026 — the space beside the calendar was empty,
        // and the deep settings are going to M8 anyway. Five tabs became four.
        QuickSettings {
            id: quickSettings
            Layout.fillWidth: true
        }

    }

    // ⚠️ WHERE THE LEFTOVER HEIGHT GOES, NAMED RATHER THAN LEFT TO WHOEVER
    // DEFAULTS TO TAKING IT. `body` is at least eleven grid units tall and most
    // tabs want less, so some child absorbs the difference — and until this
    // existed that child was the header row, which put the session buttons at a
    // different height on every tab.
    //
    // An empty Item costs nothing to draw and says out loud that the slack
    // belongs at the BOTTOM. Anything added to this column later inherits the
    // right behaviour instead of quietly reopening B38.
    // ⚠️ EXCEPT ON THE MEDIA TAB, where the player takes the room instead —
    // B58, "mach den player größer das er perfekt auf die seite passt". The     // english-ok: the request, quoted
    // card was as tall as its contents and this spacer ate everything below it,
    // which on a panel pinned to one height for all tabs is most of the surface.
    // Two things cannot both absorb the slack, so the spacer stands down for the
    // one tab that wants it.
    Item { Layout.fillHeight: root.tab !== Ipc.quickMedia }

    // The everyday switches stay here: the panel is what you reach for while
    // working, and the window is where you go to change how the desktop is
    // built. Two places on purpose, not a duplication.
    }   // body

    // ⚠️ THE PLACEHOLDER IS GONE, AND SO IS EVERYTHING THAT SERVED IT. This used
    // to set a `note` property to "The settings window is still to come", show
    // it in a small line under the panel, and clear it again after four seconds
    // on a Timer. With a window to open, none of those three has a writer any
    // more — and a property nothing writes, a line nothing fills and a timer
    // nothing starts are the same debt as a config key nothing reads, which
    // this project has now found six times. They went out with the placeholder.
    //
    // Opening the window also shuts the panel: leaving both up would put two
    // ways to change the same setting on screen at once.
    function openSettings() {
        Ipc.collapse()
        Ipc.showSettings()
    }
}
