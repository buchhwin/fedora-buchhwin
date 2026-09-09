// The fourth view of the quick panel: the switches and levels you reach for
// without thinking — network, bluetooth, night light, do not disturb, the
// microphone, the bar — and the sound and brightness underneath them.
//
// ⚠️ ONE THING OPENS AT A TIME. Wifi, bluetooth and sound each have a list
// behind them, and letting all three stand open would make a panel taller than
// the screen out of a surface that is supposed to be glanced at. `open` names
// the one that is out; pressing another chevron swaps them.
//
// ⚠️ AND A CLOSED LIST DOES NOT EXIST. The Loader below has no component while
// `open` is empty, so the wifi scan, the bluetooth discovery and the pipewire
// node tracking are not merely hidden — they were never started. Each list
// switches its own service on in onCompleted and off in onDestruction, which is
// why that policy needs no bookkeeping here.
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../config"
import "../../ipc"
import "../../services" as Services
import "../common"

ColumnLayout {
    id: root

    spacing: Theme.space3
    implicitWidth: Theme.space6 * 19

    // "", or one of `drawers` below.
    property string open: ""
    // ⚠️ A NAMED PROPERTY RATHER THAN THE COMPARISON INLINE, and the reason is
    // the icon tripwire: tests/icons.sh takes every quoted string on an
    // `Icon { text: … }` line as an icon name, so `root.open === "sound" ?
    // "expand_less" : "expand_more"` asks the font for a glyph called "sound".
    // It is also easier to read.
    readonly property bool soundOpen: root.open === "sound"

    // ⚠️⚠️ TWO LEVELS, on his instruction: "im quickpanel alles              // english-ok: the report, quoted
    // unübersichtlich und zu viel … das muss man anders machen". Ten tiles,  // english-ok: the report, quoted
    // a drawer and three sliders were one surface. Put to him as a choice he
    // picked the shape he had already chosen for the settings window: the
    // four he reaches for stay out, the rest fold away.
    //
    // ⚠️⚠️ B74 · THE SETTING IS THE STARTING POSITION, NOT THE LIVE STATE — and
    // that reverses what this comment used to say. It read "it reads the setting
    // rather than holding panel state", on the argument that the panel is
    // rebuilt on every open so local state would make a man who wants all ten
    // tiles open the fold ten times a day.
    //
    // He asked for exactly the behaviour that argument was avoiding: "der Show   // english-ok: the request, quoted
    // more Button soll nicht gespeichert werden … dann das quickpanel erneut     // english-ok: the request, quoted
    // öffnen soll das wieder automatisch geschlossen sein". Fair enough — the    // english-ok: the request, quoted
    // fold is a glance, not a preference, and a panel that reopens the way you
    // left it hours ago is a panel that remembers something you did not mean.
    //
    // So: a WRITABLE property seeded from the setting. Writing it breaks the
    // binding, which is normally this project's most expensive mistake — here
    // it is the mechanism. The panel is destroyed and rebuilt on every open, so
    // the next build evaluates the seed again and the fold starts closed (or
    // open, if he sets it that way). Measured rather than assumed: see
    // tests/quick-fold.sh, which opens, folds, closes and reopens.
    //
    // ⚠️ AND THE HEIGHT MUST READ THIS, NOT THE SETTING. QuickPage's floor has
    // two steps and picks between them by the fold; pointing it at the stored
    // key while the tiles follow this one would make the panel a different size
    // than its own contents — a fresh instance of the very fault B67 is about.
    property bool showMore: Config.quick ? Config.quick.showMore : false

    // ⚠️ GUARDED, and the guard is not superstition: while shell.json is
    // being read `Config.<block>` is NULL — not "still the defaults" — and a
    // binding that throws keeps its last value for ever. That fault reached
    // eight surfaces once; tests/surfaces.sh is the tripwire.


    // ⚠️ SO ESC CAN CLOSE THE DRAWER BEFORE THE PANEL. "auch bei allen             // english-ok: quoted brief
    // unterfenstern" — with a WiFi list open, Esc closing the whole panel throws
    // away two steps of navigation at once, and there is no way back to where
    // you were. Returns whether it had anything to close, so the caller knows
    // whether to keep going.
    function closeDrawer() {
        if (root.open.length === 0)
            return false
        root.open = ""
        return true
    }

    // The drawers this panel can open, by name. One list, because there are now
    // two callers — the tiles below and `ipc call notch drawer` — and rule 6 is
    // explicit that a list two surfaces read lives in one place.
    //
    // ⚠️ IT IS ALSO A GUARD, and not a decorative one: the loader below is
    // `active: root.open !== ""` with a ternary for the component, so a name
    // that is not in the ternary opens an ACTIVE loader holding NOTHING. On
    // screen that is a panel that grew by a few pixels and shows an empty band
    // — indistinguishable from the fault being measured. tests/quick-drawers.sh
    // holds this list and the ternary to the same five names.
    readonly property var drawers: ["wifi", "bt", "sound", "mic", "disks"]

    function show(which) {
        if (which.length > 0 && root.drawers.indexOf(which) < 0)
            which = ""
        root.open = root.open === which ? "" : which
    }

    // ⚠️ THE PANEL HANDS ITSELF TO Ipc so the drawer can be reached from
    // outside — see the note on `Ipc.quickPanel`. Cleared on destruction: the
    // panel is rebuilt every time it opens, so a stale reference here would be
    // a verb that answers about a card nobody can see.
    Component.onDestruction: if (Ipc.quickPanel === root) Ipc.quickPanel = null

    // ------------------------------------------------------------- the tiles
    // ⚠️ ON DEMAND, ONCE, WHEN THE PANEL IS BUILT. The panel is rebuilt every
    // time it opens, so this is "whenever you look at it" without a timer —
    // and a poll for a value that only changes when somebody presses
    // something is the idle drain M10 exists to remove.
    // ⚠️ ONE `Component.onCompleted`, AND THAT IS NOT STYLE. Setting a property
    // twice on one object is not an override in QML — it refuses to build the
    // component, and the refusal travels UP through every type that contains
    // it. That fault once took the whole shell's surfaces away with nothing in
    // the journal but "Property value set multiple times"; surface-build.sh and
    // duplicate-props.sh exist because of it. A second handler belongs in this
    // body, not in a second block.
    Component.onCompleted: {
        Services.Power.refreshProfile()
        Ipc.quickPanel = root
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Theme.space2
        rowSpacing: Theme.space2

        // ⚠️⚠️ THESE TWO TILES OPENED KDE'S SYSTEM SETTINGS UNTIL 09.09.2026,
        // and that was the duplication the whole profile is built against —
        // "nirgends Doppelungen". Not because it started another program, but    // english-ok: the brief, quoted
        // because services/Net.qml and services/Bt.qml were COMPLETE the whole
        // time and had zero callers: connect, disconnect, forget, the password
        // path, the adapter switch. A second interface for something this shell
        // already knew how to do is the definition of the fault.
        //
        // ⚠️ THE SUBTITLE IS THE STATE, and that is the point of the change
        // rather than a decoration. "KDE settings" told you where the tile went;
        // the network's name tells you what you are on, which is the question
        // anybody opening this panel actually has.
        Tile {
            Layout.fillWidth: true
            // ⚠️ NO `icon:` HERE, and that is not an omission. With
            // `network: true` the tile draws common/NetIcon itself — the same
            // symbol the island shows — and the `icon` string is not read at
            // all. Setting one would be a value nothing looks at, which is the
            // shape of half the faults this project keeps finding.
            title: "Network"
            subtitle: Services.Net.kind === "wired" ? Services.Net.wiredName
                    : Services.Net.ssid.length > 0 ? Services.Net.ssid
                    : Services.Net.wifiEnabled ? "not connected"
                    : "off"
            active: Services.Net.online
            network: true
            expandable: true
            expanded: root.open === "wifi"
            onClicked: root.show("wifi")
            onExpandClicked: root.show("wifi")
        }

        Tile {
            Layout.fillWidth: true
            icon: Services.Bt.icon
            title: "Bluetooth"
            subtitle: Services.Bt.connectedDevices.length > 0
                    ? Services.Bt.connectedDevices[0].name
                    : Services.Bt.enabled ? "on" : "off"
            active: Services.Bt.enabled
            expandable: true
            expanded: root.open === "bt"
            onClicked: root.show("bt")
            onExpandClicked: root.show("bt")
        }


        // ⚠️ THE ONE PART OF M10 THAT PAYS OFF WITHOUT A SINGLE MEASUREMENT, and
        // that is why it is here rather than waiting for the rest of it: the
        // setting and its writer both existed already (Config.power.profile,
        // written to DBus by services/Idle.qml) and there was no way to reach it
        // except the settings window. A key with a reader and no way to press it
        // is half of the same fault as a key with no reader.
        //
        // ⚠️ IT SHOWS WHAT THE MACHINE IS ON, NOT WHAT shell.json ASKS FOR.
        // Services.Power reads ActiveProfile back over busctl; the two can
        // disagree — another session, a laptop vendor's own tool, a profile the
        // machine does not offer — and the tile is the place that would tell you.
        Tile {
            Layout.fillWidth: true
            visible: Services.Power.profilesAvailable
            // ⚠️ ASKED THE FONT, AND THE FIRST CHOICE DID NOT EXIST.
            // `battery_saver` is a Material SYMBOLS name; Fedora ships Material
            // Icons ROUND, and tests/icons.sh measured it at 900 px — the
            // fallback box, not a glyph. `savings` is missing too.
            //
            // ⚠️⚠️ AND THE SENTENCE THAT USED TO END THIS PARAGRAPH — "`eco` and
            // `bolt` are both really there" — WAS WRONG ABOUT BOLT, AND ABOUT
            // `balance` BESIDE IT. Measured on 10.08.2026 with the same tool
            // that caught `battery_saver`: `bolt` 300 px, `balance` 600 px, a
            // real glyph ~70. So this tile drew NOTHING in `performance` and
            // nothing in `balanced` — which is the DEFAULT profile, so on most
            // machines the power tile simply had no icon at all.
            //
            // ⚠️ tests/icons.sh said "all 86 icon names resolve" throughout,
            // because it scrapes `icon:` lines and these two sat on the
            // CONTINUATION lines of a ternary. The check was right about every
            // name it saw; it never saw these.
            //
            // Replacements measured the same way: `flash_on` ok, `tonality` ok
            // (a half-filled circle — the one shape in this font that reads as
            // "in the middle"), `eco` ok.
            // ⚠️ Existing is still not the same as being right, and that half
            // is the eye test this comment has owed since it was written.
            icon: Services.Power.activeProfile === "power-saver" ? "eco"
                : Services.Power.activeProfile === "performance" ? "flash_on"
                : "tonality"
            title: "Power profile"
            subtitle: Services.Power.activeProfile === "power-saver" ? "Power saver"
                    : Services.Power.activeProfile === "performance" ? "Performance"
                    : Services.Power.activeProfile === "balanced" ? "Balanced"
                    : Services.Power.activeProfile
            // Only "not balanced" is a state worth lighting up: balanced is the
            // default, and a tile that is always lit says nothing.
            active: Services.Power.activeProfile.length > 0
                    && Services.Power.activeProfile !== "balanced"
            onClicked: {
                // Through the list the machine reported, in its own order, so a
                // machine without a power-saver cannot be asked for one.
                var l = Services.Power.profiles
                if (l.length === 0)
                    return
                var i = l.indexOf(Services.Power.activeProfile)
                Services.Power.setProfile(l[(i + 1) % l.length])
            }
        }

        Tile {
            // ⚠️ SECOND LEVEL — see `quick.showMore`. The mark is ON THE TILE,
            // not in a list somewhere else: a list would let a new tile land in
            // neither level with nothing noticing. Same rule the settings rows
            // follow.
            visible: root.showMore
            Layout.fillWidth: true
            icon: "nights_stay"
            title: "Night light"
            // The one case where the subtitle is a warning: gammastep starts,
            // says the screen has no gamma control and then does nothing. A
            // switch that lights up and changes nothing is what this avoids.
            subtitle: !Services.Nightlight.supported ? Services.Nightlight.status
                    : !Services.Nightlight.available ? "gammastep is missing"
                    : Services.Nightlight.on
                      ? Services.Nightlight.temperature + " K" : "off"
            active: Services.Nightlight.on && Services.Nightlight.supported
            usable: Services.Nightlight.available && Services.Nightlight.supported
            onClicked: Services.Nightlight.toggle()
        }

        Tile {
            // ⚠️ SECOND LEVEL — see `quick.showMore`. The mark is ON THE TILE,
            // not in a list somewhere else: a list would let a new tile land in
            // neither level with nothing noticing. Same rule the settings rows
            // follow.
            // ⚠️ BOTH CONDITIONS ON ONE LINE. Two `visible:` declarations on the
            // same object is not an override — QML calls it "Property value set
            // multiple times", refuses to build the component, and the failure
            // travels: QuickSettings → QuickPage → NotchContent → ShellSurface, so
            // the entire shell surface and every IPC target went with it.
            visible: root.showMore && Services.Drive.installed
            Layout.fillWidth: true
            // ⚠️ VISIBLE EVEN WHEN IT CANNOT MOUNT, unlike the VPN tile next
            // door, and the difference is that the fix is on this machine. No
            // tunnel configured means somebody else's server; no rclone remote
            // means a browser sign-in, and hiding the tile would hide the only
            // place that says so.
            icon: Services.Drive.mounted ? "cloud_done" : "cloud"
            title: "Drive"
            subtitle: Services.Drive.status.length > 0 ? Services.Drive.status
                    : !Services.Drive.configured ? "no remote — bhctl drive setup"
                    : Services.Drive.mounted ? Services.Drive.mountPoint : "off"
            active: Services.Drive.mounted
            usable: Services.Drive.available
            onClicked: Services.Drive.toggle()
        }

        Tile {
            // ⚠️ SECOND LEVEL — see `quick.showMore`. The mark is ON THE TILE,
            // not in a list somewhere else: a list would let a new tile land in
            // neither level with nothing noticing. Same rule the settings rows
            // follow.
            visible: root.showMore
            Layout.fillWidth: true
            // ⚠️⚠️ IT USED TO DISAPPEAR WHEN THERE WAS NO TUNNEL, and the note
            // here argued for that: "a control that can never do anything is the
            // fault this project keeps removing". The argument was sound and the
            // conclusion was wrong, and HE is the one who found out — he asked
            // for a VPN toggle in the quick panel that had been sitting there for
            // weeks: "gibt es glaub ich eh schon aber das man das auch toggeln   // english-ok: his report, quoted
            // kann im quick panel".                                              // english-ok: his report, quoted
            //
            // On a machine with no tunnel the tile was invisible, so "no VPN is
            // set up" and "this desktop has no VPN support" looked exactly the
            // same. That is the OTHER half of the same rule — what does not work
            // has to say so — and a silent absence is the version of it that
            // costs somebody an evening looking for a feature they already have.
            //
            // So it is always there, and it says which of the two it is. Not
            // pressable without a tunnel: a switch that flips and does nothing
            // would be worse than either.
            icon: Services.Vpn.connected ? "vpn_lock" : "vpn_key"
            title: "VPN"
            usable: Services.Vpn.available
            subtitle: !Services.Vpn.available ? "none set up — see docs/VPN.md"
                    : Services.Vpn.status.length > 0 ? Services.Vpn.status
                    : Services.Vpn.connected ? Services.Vpn.name : "off"
            active: Services.Vpn.connected
            onClicked: Services.Vpn.toggle()
        }

        Tile {
            Layout.fillWidth: true
            icon: Config.notifications.dnd ? "notifications_off" : "notifications"
            title: "Do not disturb"
            // ⚠️ THE NUMBER, not the word. "toasts silenced" is a claim; a
            // count is the evidence, and it is what tells him the quiet screen
            // is this switch and not a broken daemon.
            subtitle: !Config.notifications.dnd ? "off"
                    : Services.Notifications.silenced === 0 ? "silencing"
                    : Services.Notifications.silenced + " silenced"
            active: Config.notifications.dnd
            onClicked: {
                Config.notifications.dnd = !Config.notifications.dnd
                Config.save()
            }
        }

        Tile {
            // ⚠️ SECOND LEVEL — see `quick.showMore`. The mark is ON THE TILE,
            // not in a list somewhere else: a list would let a new tile land in
            // neither level with nothing noticing. Same rule the settings rows
            // follow.
            // ⚠️ BOTH CONDITIONS ON ONE LINE. Two `visible:` declarations on the
            // same object is not an override — QML calls it "Property value set
            // multiple times", refuses to build the component, and the failure
            // travels: QuickSettings → QuickPage → NotchContent → ShellSurface, so
            // the entire shell surface and every IPC target went with it.
            visible: root.showMore && Services.Audio.micAvailable
            Layout.fillWidth: true
            icon: Services.Audio.micMuted ? "mic_off" : "mic"
            title: "Microphone"
            subtitle: Services.Audio.micMuted ? "muted" : "on"
            // ⚠️ Accent means MUTED here, which is the opposite of the other
            // tiles, and it is deliberate: the state worth marking is the one
            // that surprises you in a meeting.
            active: Services.Audio.micMuted
            onClicked: Services.Audio.toggleMicMute()

            // ⚠️ B73 · THE CHEVRON PICKS THE INPUT, and the tile still mutes.
            // His request: "im quickpanel soll es auch bei Mikrofone einen      // english-ok: the request, quoted
            // Pfeil nach unten geben wo man wie bei Sound den default input     // english-ok: the request, quoted
            // festlegen kann" — the same shape the volume row already has, in   // english-ok: the request, quoted
            // the place he went looking for it.
            //
            // ⚠️ AND `expandClicked` IS A SEPARATE SIGNAL FROM `clicked` FOR THE
            // REASON B49 COST A ROUND: a chevron inside a surface that itself
            // answers presses fires BOTH unless the inner grip is exclusive.
            // Tile keeps that grip; this side only has to use the right signal.
            // Getting it wrong here would mute the microphone every time he
            // went to choose one, which is precisely what he reported for wifi.
            expandable: true
            expanded: root.open === "mic"
            onExpandClicked: root.show("mic")
        }

        // ⚠️ ONLY WHEN THERE IS ONE. A "Drives" tile on a laptop with nothing
        // plugged in is a permanent square saying "nothing" — and this grid is
        // the one surface whose whole job is to be readable at a glance.
        Tile {
            // ⚠️ SECOND LEVEL — see `quick.showMore`. The mark is ON THE TILE,
            // not in a list somewhere else: a list would let a new tile land in
            // neither level with nothing noticing. Same rule the settings rows
            // follow.
            // ⚠️ BOTH CONDITIONS ON ONE LINE. Two `visible:` declarations on the
            // same object is not an override — QML calls it "Property value set
            // multiple times", refuses to build the component, and the failure
            // travels: QuickSettings → QuickPage → NotchContent → ShellSurface, so
            // the entire shell surface and every IPC target went with it.
            visible: root.showMore && Services.Disks.available
            Layout.fillWidth: true
            icon: "usb"
            title: "Drives"
            subtitle: Services.Disks.mountedCount > 0
                ? Services.Disks.mountedCount + " of "
                  + Services.Disks.drives.length + " mounted"
                : Services.Disks.drives.length + " connected"
            active: Services.Disks.mountedCount > 0
            expandable: true
            expanded: root.open === "disks"
            onClicked: root.show("disks")
            onExpandClicked: root.show("disks")
        }

        Tile {
            // ⚠️ SECOND LEVEL — see `quick.showMore`. The mark is ON THE TILE,
            // not in a list somewhere else: a list would let a new tile land in
            // neither level with nothing noticing. Same rule the settings rows
            // follow.
            visible: root.showMore
            Layout.fillWidth: true
            icon: "view_agenda"
            title: "Top bar"
            subtitle: Config.bar.enabled ? "on" : "off"
            active: Config.bar.enabled
            onClicked: {
                Config.bar.enabled = !Config.bar.enabled
                Config.save()
            }
        }
    }

    // ⚠️ THE FOLD ITSELF. One row, the full width, and it says which way it
    // goes — a chevron on its own is a shape people have to have learned.
    //
    // ⚠️ B74 · IT WRITES THE PANEL, NOT THE SETTING — reversed on his request.
    // It used to write `Config.quick.showMore` and call `Config.save()`, so the
    // fold survived the panel being rebuilt; that is precisely what he asked to
    // stop. The stored key is now the STARTING position and keeps its own row in
    // the settings window; this press moves only the panel in front of him.
    //
    // Nothing is saved here on purpose: there is no decision to persist, so
    // there is also no write to debounce and no file touched by glancing at a
    // panel.
    Pill {
        Layout.fillWidth: true
        interactive: true
        onClicked: root.showMore = !root.showMore

        RowLayout {
            spacing: Theme.space2

            BarText {
                text: root.showMore ? "Show less" : "Show more"
                font.pixelSize: Theme.fontSizeSm
                color: Theme.fgMuted
            }

            Icon {
                text: root.showMore ? "expand_less" : "expand_more"
                size: Theme.fontSizeLg
                color: Theme.fgMuted
            }
        }
    }

    // ------------------------------------------------------------ the drawer
    Loader {
        id: drawer
        Layout.fillWidth: true
        active: root.open !== ""

        // ⚠️⚠️ B68 · A DEACTIVATED LOADER KEEPS ITS LAST HEIGHT, and that one
        // line is the whole of "wenns man einklappt bleibt die neue Größe".     // english-ok: the report, quoted
        //
        // Setting `active: false` destroys the item, but the Loader's own
        // implicit size is NOT reset with it — so the column above went on
        // reserving room for a list that no longer existed. Traced link by link
        // with `ipc call notch chain`, which is why it took a probe rather than
        // a guess:
        //
        //     drawer shut   card=416 content=416 page=368
        //     drawer open   card=604 content=604 page=556
        //     shut again    card=604 content=604 page=556   <- the PAGE is stuck
        //
        // Every link above the page was faithfully reporting what it was told.
        // ⚠️ An earlier attempt blamed the settle loop in OverlaySurface and
        // changed nothing, because the number it re-read was already correct at
        // that level. Four numbers ended a wrong theory in one reading.
        Layout.preferredHeight: (drawer.active && drawer.item)
                                ? drawer.item.implicitHeight : 0
        // ⚠️ SYNCHRONOUS ON PURPOSE. What this loader builds decides the size of
        // the card, and the card decides the size of the layer surface. Loading
        // it a frame late means the surface is configured at one size and then
        // re-configured when the content lands — a round trip with the compositor and a
        // new buffer, and on screen a panel that opens at the wrong size and
        // grows while you look at it. It is one small view, not the twenty-one
        // settings pages whose synchronous build was a real freeze.
        asynchronous: false
        sourceComponent: root.open === "wifi" ? wifiList
                       : root.open === "bt" ? btList
                       : root.open === "sound" ? soundList
                       : root.open === "mic" ? micList
                       : root.open === "disks" ? diskList
                       : null

        // Comes down rather than appearing, at the same pace as everything else.
        //
        // ⚠️ THE SENTENCE THAT USED TO END THIS PARAGRAPH WAS FALSE. It said
        // "the surface around it is already animating its own height", and the
        // surface does the exact opposite on purpose: OverlaySurface sets its
        // size in one step and carries the motion on `scale` and `opacity`,
        // because animating a layer surface's size is `set_size` per frame —
        // 11 of them for one opening, measured. QuickPage's own header says the
        // same thing one file away ("the growth is one step, not an
        // animation"). Two comments, opposite claims, and this was the wrong
        // one; rule 3's worst shape is a reason that reads true beside code
        // that does something else.
        opacity: root.open !== "" ? 1 : 0
        Behavior on opacity {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }
    }

    Component { id: wifiList; NetworkList {} }
    Component { id: btList; BluetoothList {} }
    Component { id: soundList; SoundList {} }
    // B73 · the same list, asked for the input side instead.
    Component { id: micList; SoundList { inputsOnly: true } }
    Component { id: diskList; DiskList {} }

    // ----------------------------------------------------------- the levels
    RowLayout {
        Layout.fillWidth: true
        visible: Services.Audio.available
        spacing: Theme.space2

        LevelRow {
            // ⚠️ B44 · THE THIN SHAPE, THE ONE THE SETTINGS WINDOW USES. His words, and
            // the second sentence overrides the first: "der audio slider [soll]        // english-ok: the request, quoted
            // kleiner [sein] nicht so fett" … "ok dann mach beide slider kleiner       // english-ok: the request, quoted
            // weil die echt groß sind" … "also so wie in den settings die slider".     // english-ok: the request, quoted
            //
            // ⚠️ ALL THREE ROWS, not just the volume one he named. Two shapes side by
            // side is exactly the drift common/LevelRow warns about in its own header,
            // and settings/SettingSlider is built on the same control without `fat` —
            // so this is the shape he pointed at rather than a third one.
            Layout.fillWidth: true
            icon: Services.Audio.muted ? "volume_off"
                : Services.Audio.volume > 0.5 ? "volume_up" : "volume_down"
            value: Services.Audio.volume
            live: !Services.Audio.muted
            // ⚠️ B54 · THE ICON MUTES. His request: "im quick panel ist ja links   // english-ok: the request, quoted
            // beim lautstärke regler das icon also kopfhörer und wenn man da      // english-ok: the request, quoted
            // drauf clickt soll man den sound muten und entmuten können".         // english-ok: the request, quoted
            //
            // The bar's audio pill has done exactly this for months, so this is
            // the same gesture arriving where he looked for it — not a second
            // way to mute. `iconClickable` is what makes the icon take the press
            // instead of the track underneath; see the notes in common/LevelRow.
            iconClickable: true
            onIconTapped: Services.Audio.toggleMute()
            onMoved: function (f) { Services.Audio.setVolume(f) }
            onNudged: function (d) {
                Services.Audio.setVolume(Services.Audio.volume + d / steps)
            }
        }

        // The way to the outputs and the per-programme levels. It sits on the
        // volume row rather than being a seventh tile, because that is where
        // somebody looks when the sound is coming out of the wrong thing.
        Pill {
            interactive: true
            active: root.soundOpen
            Icon {
                text: root.soundOpen ? "expand_less" : "expand_more"
                size: Theme.fontSizeLg
                color: root.soundOpen ? Theme.accentFg : Theme.fg
            }
            onClicked: root.show("sound")
        }
    }

    LevelRow {
        Layout.fillWidth: true
        visible: Services.Brightness.available
        icon: "brightness_6"
        value: Services.Brightness.fraction
        onMoved: function (f) { Services.Brightness.set(f) }
        onNudged: function (d) {
            Services.Brightness.set(Math.max(0.01, Math.min(1,
                Services.Brightness.fraction + d / steps)))
        }
    }

    // The external monitor, and ONLY when one answered. It is a second row
    // rather than a mode on the first because both screens can be lit at once
    // and both are worth reaching — a single slider would have to pick one and
    // be wrong half the time. The symbol differs so the two rows are telling
    // apart at a glance rather than by position.
    //
    // ⚠️ `onReleased` when Config says not to send live: a DDC write is slow
    // and many monitors flash their own menu for each one. See the head of
    // services/Brightness.qml for what is measured here and what is not.
    LevelRow {
        Layout.fillWidth: true
        // ⚠️ SECOND LEVEL as well — his list put the external monitor there.
        // Both conditions, not one: a screen that is not there must stay
        // hidden even with the fold open.
        visible: root.showMore && Services.Brightness.externalAvailable
        icon: "desktop_windows"
        value: Services.Brightness.externalFraction
        onMoved: function (f) { Services.Brightness.setExternal(f) }
        onReleased: function (f) { Services.Brightness.commitExternal() }
        onNudged: function (d) {
            Services.Brightness.setExternal(Math.max(0, Math.min(1,
                Services.Brightness.externalFraction + d / steps)))
            // A wheel notch has no "release" of its own — it is a whole gesture
            // in one event, so it commits itself. Without this the monitor
            // would ignore the wheel entirely whenever live sending is off.
            Services.Brightness.commitExternal()
        }
    }

    BarText {
        Layout.fillWidth: true
        visible: !Services.Audio.available && !Services.Brightness.available
        text: "No sound or backlight on this machine"
        color: Theme.fgMuted
        font.pixelSize: Theme.fontSizeSm
    }

    // ⚠️ AND THE HALF CASE, WHICH IS THE ONE THAT ACTUALLY MISLEADS. The line
    // above only speaks when BOTH are missing. A machine with sound and no
    // backlight — every virtual machine, and any desktop with a monitor that
    // has no DDC — simply had the brightness row vanish, with nothing in its
    // place. He read that as a missing feature and asked for brightness to be
    // added: "dafür soll man die helligkeit des display einstellen können".    // english-ok: the request, quoted
    // It was there all along and had gone quiet, which rule 5 forbids in as
    // many words: what does not work has to say so.
    BarText {
        Layout.fillWidth: true
        visible: Services.Audio.available && !Services.Brightness.available
                 && !Services.Brightness.externalAvailable
        text: "No screen brightness to set here — this display has no backlight"
        color: Theme.fgMuted
        font.pixelSize: Theme.fontSizeSm
    }
}
