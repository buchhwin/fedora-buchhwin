// Wallpaper — which picture, from where, and how it is fitted.
//
// ⚠️ `WallpaperSettingsPage`, not `WallpaperPage`: the notch already has a page
// by that name. Two QML types with one name in two folders resolve correctly
// and read as a mistake forever after — the same reason NotifyPage is not
// called NotificationsPage.
import QtQuick
import QtQuick.Layouts
import ".."
import "../../../config"
import "../../../services" as Services
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    SettingGroup {
        Layout.fillWidth: true
        title: "Wallpaper"

        SettingRow {
            Layout.fillWidth: true
            key: "surfaces.wallpaper"
            label: "Draw the wallpaper"
            hint: "The shell draws it rather than a second daemon. Off leaves whatever the compositor puts there."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "wallpaper.folder"
            label: "Folder"
            hint: "Where Mod+Shift+W looks for pictures."
            kind: "folder"
            placeholder: "~/Pictures/Wallpapers"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "wallpaper.current"
            label: "Current picture"
            hint: "A file:// address. Easier to choose with Mod+Shift+W."
            kind: "image"
            placeholder: "file:///…"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "wallpaper.monitors"
            advanced: true
            label: "Screens"
            kind: "picks"
            options: Services.Suggest.monitors
            placeholder: "Every screen"
        }
    }

    // ---------------------------------------------------- B75 · per screen
    //
    // His request: "soll man wallpaper für jeden screen auch einzeln            // english-ok: the request, quoted
    // einstellen können" — and he had no shape in mind ("ich weiß auch noch    // english-ok: the request, quoted
    // nicht wie"), so it was put to him as a choice and he picked this one:     // english-ok: the request, quoted
    // a segmented switch over the whole thing, with a row per monitor below it.
    //
    // ⚠️ THE SWITCH IS NOT A KEY. It reads "is the assignment list empty", and
    // pressing it writes or clears that list. A `perScreenEnabled` boolean
    // beside the list is exactly the pair rule 6 forbids: the two can disagree,
    // and then what hangs on the wall depends on which one a given file read.
    // Same reasoning as `notch.monitors` with its `@primary` placeholder.
    SettingGroup {
        Layout.fillWidth: true
        title: "Per screen"

        // Only worth showing where there is more than one screen to tell apart.
        // ⚠️ AND IT SAYS SO rather than vanishing — a group that disappears on a
        // laptop reads as a missing feature, which is the fault rule 5 was
        // written for and the one the brightness slider already committed.
        Text {
            Layout.fillWidth: true
            visible: Services.Suggest.monitors.length < 2
            text: "One screen — there is nothing to tell apart yet."
            wrapMode: Text.WordWrap
            color: Theme.fgMuted
            font.family: Theme.fontUi
            font.pixelSize: Theme.fontSizeSm
        }

        RowLayout {
            Layout.fillWidth: true
            visible: Services.Suggest.monitors.length > 1
            spacing: Theme.space3

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.space1
                Text {
                    text: "Same picture everywhere"
                    color: Theme.fg
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fontSize
                }
                Text {
                    Layout.fillWidth: true
                    text: "Per screen lets each monitor keep its own."
                    color: Theme.fgMuted
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fontSizeSm
                    wrapMode: Text.WordWrap
                }
            }

            Segmented {
                readonly property bool perScreen:
                    (Config.wallpaperPerScreen || []).length > 0
                options: [{ value: "all", label: "All screens" },
                          { value: "each", label: "Per screen" }]
                current: perScreen ? "each" : "all"
                onChosen: function (v) {
                    if (v === "all") {
                        Services.Wallpaper.clearPerScreen()
                        return
                    }
                    // ⚠️ TURNING IT ON SEEDS EVERY SCREEN WITH WHAT IS ALREADY
                    // THERE. An empty list means "all screens", so writing one
                    // empty entry would be indistinguishable from off — and the
                    // switch would appear not to work. Seeding also means the
                    // wall does not change at the moment he flips it, which is
                    // what "per screen" should mean: now they can differ, not
                    // now they do.
                    var ms = Services.Suggest.monitors
                    for (var i = 0; i < ms.length; i++)
                        Services.Wallpaper.setForScreen(
                            String(ms[i].value !== undefined ? ms[i].value : ms[i]),
                            Services.Wallpaper.current)
                }
            }
        }

        // ⚠️ A READOUT, NOT A SECOND PICKER. Assigning happens with Mod+Shift+W
        // on the screen you are standing on — see the note on
        // `Services.Wallpaper.choose`. Building a per-monitor grid here as well
        // would be two ways to do one thing, and the two would drift.
        //
        // What this list is for is the question the gesture cannot answer:
        // WHICH picture is on WHICH screen, all at once.
        Repeater {
            model: (Config.wallpaperPerScreen || []).length > 0
                   ? Services.Suggest.monitors : []

            RowLayout {
                id: screenRow
                required property var modelData
                readonly property string screenName:
                    String(modelData.value !== undefined ? modelData.value : modelData)
                readonly property string picture:
                    Services.Wallpaper.forScreen(screenRow.screenName)
                Layout.fillWidth: true
                spacing: Theme.space3

                Text {
                    Layout.preferredWidth: Theme.space6 * 4
                    text: screenRow.screenName
                    elide: Text.ElideRight
                    color: Theme.fg
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fontSize
                }

                Text {
                    Layout.fillWidth: true
                    // The file name, not the URL: a row of identical
                    // `file:///home/…/Pictures/Wallpapers/` prefixes tells you
                    // nothing, and the part that differs is at the far end where
                    // eliding cuts it off.
                    text: {
                        var p = screenRow.picture
                        if (!p.length)
                            return "—"        // literal-ok: an em dash for "nothing set"
                        var slash = p.lastIndexOf("/")
                        return slash >= 0 ? p.substring(slash + 1) : p
                    }
                    elide: Text.ElideRight
                    color: Theme.fgMuted
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fontSizeSm
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: (Config.wallpaperPerScreen || []).length > 0
            text: "Mod+Shift+W assigns to the screen the pointer is on."
            wrapMode: Text.WordWrap
            color: Theme.fgMuted
            font.family: Theme.fontUi
            font.pixelSize: Theme.fontSizeSm
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Slideshow"

        SettingRow {
            Layout.fillWidth: true
            key: "wallpaper.slideshow"
            label: "Change the picture by itself"
            hint: "Walks the folder above. With this off nothing runs — there is no timer at all."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "wallpaper.intervalMinutes"
            label: "Every"
            hint: "Minutes between pictures."
            kind: "slider"
            from: 1
            to: 240
            step: 1
            unit: " min"
            usable: Config.wallpaper.slideshow
        }
        SettingRow {
            Layout.fillWidth: true
            key: "wallpaper.shuffle"
            advanced: true
            label: "In a random order"
            hint: "Off walks the folder in name order. On never picks the picture already showing."
            usable: Config.wallpaper.slideshow
        }
        // ⚠️ THE SECOND SWITCH, AND IT IS THE POINT OF THE GROUP. With the
        // palette set to "wallpaper" every picture change recalculates all 26
        // colours and rewrites every foreign application's config — measured,
        // a forest picture gives base 27201b and a desert one 1b2027. A
        // slideshow every fifteen minutes would then repaint the whole desktop
        // every fifteen minutes. Changing the picture and changing the colours
        // are two different wishes.
        SettingRow {
            Layout.fillWidth: true
            key: "wallpaper.slideshowRecolour"
            label: "Take the colours along"
            // Why it is this way: Only matters while the palette is set to
            // follow the wallpaper.
            hint: "Off keeps the scheme the desktop had when the slideshow started."
            usable: Config.wallpaper.slideshow
        }
    }
}
