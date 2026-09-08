// The task manager — his, in Quickshell, on Ctrl+Shift+Escape.
//
// ⚠️ HE ASKED FOR THIS INSTEAD OF gnome-system-monitor AND INSTEAD OF btop
// ALONE, and the reason is in the request: "einen taskmanager der auch dem      // english-ok: the request, quoted
// farbschema und ohne titelleiste folgt". A GTK monitor follows neither. btop   // english-ok: the request, quoted
// follows the colours and is a terminal, which is the wrong shape for "what is
// eating my battery" at a glance.
//
// ⚠️ IT REUSES, IT DOES NOT REBUILD. The predecessor died of duplicate widgets,
// so the rail, the pills, the level bars and the card shape all come from
// ui/common — nothing here is a second version of something that exists.
//
// ⚠️ THE TIMER IS DOUBLY GATED. `Procs.active` follows this page's visibility,
// and nothing reads /proc when it is false. A process list is the single
// easiest way to put a laptop under permanent load.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../theme"
import "../../../services" as Services
import "../../common"

Item {
    id: root

    implicitWidth: 620
    implicitHeight: 380

    property string query: ""

    // ⚠️ VISIBILITY DRIVES THE SERVICE, and `visible` alone is not enough: a
    // page inside a Loader that has been swapped out still answers `true` for
    // one frame. `Component.onCompleted`/`onDestruction` is the pair that
    // matches what the surface actually does.
    Component.onCompleted: Services.Procs.active = true
    Component.onDestruction: Services.Procs.active = false
    onVisibleChanged: Services.Procs.active = visible

    Timer {
        // One second is what a person reads; anything faster is a number that
        // moves while you look at it. It runs only while the page is up.
        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: Services.Procs.refresh()
    }

    readonly property var shown: {
        var q = root.query.toLowerCase().trim()
        var all = Services.Procs.procs
        var out = []
        for (var i = 0; i < all.length && out.length < 120; i++) {
            if (q.length > 0 && all[i].name.toLowerCase().indexOf(q) < 0)
                continue
            out.push(all[i])
        }
        return out
    }

    readonly property real totalCpu: {
        var s = 0, all = Services.Procs.procs
        for (var i = 0; i < all.length; i++)
            if (all[i].cpu > 0) s += all[i].cpu
        return s
    }
    readonly property real totalMem: {
        var s = 0, all = Services.Procs.procs
        for (var i = 0; i < all.length; i++)
            s += all[i].mem
        return s
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space3

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space3

            TextField {
                Layout.fillWidth: true
                placeholder: "Filter by name"
                onTextChanged: root.query = text
                focus: true
            }

            BarText {
                text: Services.Procs.procs.length + " processes"
                font.pixelSize: Theme.fontSizeSm
                color: Theme.fgMuted
            }
        }

        // ⚠️ THE TOTAL IS A SUM OF WHAT IS LISTED, AND IT SAYS SO. It is not
        // /proc/stat's system-wide figure, and pretending otherwise would put a
        // number next to "CPU" that disagrees with btop by a few percent for
        // reasons nobody could see. Over 100 % is normal — there are three
        // cores.
        // ⚠️ NO `label:` AND NO `caption:` ON LevelRow — IT HAS NEITHER, and
        // assigning them made the whole page fail to load with "Cannot assign
        // to non-existent property", which arrives as "Target not found" from
        // the IPC call and looks like a missing verb rather than a broken file.
        // Its API is icon/value/live/fat/steps, read out of the file rather
        // than assumed from what a level row usually has.
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space4

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.space1
                BarText {
                    text: "CPU  " + (Services.Procs.settled
                          ? root.totalCpu.toFixed(0) + " %" : "measuring…")
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.fgMuted
                }
                LevelRow {
                    Layout.fillWidth: true
                    fat: true
                    icon: "memory"
                    wheel: false
                    value: Math.min(1, root.totalCpu / 100)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.space1
                BarText {
                    text: "Memory  " + (root.totalMem / 1024).toFixed(1) + " GiB"
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.fgMuted
                }
                LevelRow {
                    Layout.fillWidth: true
                    fat: true
                    icon: "sd_card"
                    wheel: false
                    // ⚠️ THE SUM OF WHAT IS LISTED, against this machine's RAM.
                    // Not /proc/meminfo's "used", which counts caches — a bar
                    // that sits at 90 % on a healthy machine teaches you to
                    // ignore it.
                    value: Math.min(1, root.totalMem / 4096)
                }
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: rows.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: rows
                width: parent.width
                spacing: Theme.space1

                Repeater {
                    model: root.shown

                    Rectangle {
                        id: line
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: Theme.space6
                        radius: Theme.radiusSm
                        color: hov.hovered ? Theme.pillHover : "transparent"   // literal-ok: absence of colour

                        Behavior on color {
                            enabled: Theme.animate
                            ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                        }
                        HoverHandler { id: hov }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.space3
                            anchors.rightMargin: Theme.space2
                            spacing: Theme.space3

                            BarText {
                                Layout.fillWidth: true
                                text: line.modelData.name
                                elide: Text.ElideRight
                                color: line.modelData.mine ? Theme.fg : Theme.fgMuted
                            }

                            BarText {
                                text: String(line.modelData.pid)
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.fgDim
                            }

                            BarText {
                                Layout.preferredWidth: Theme.space6 * 1.4
                                horizontalAlignment: Text.AlignRight
                                // ⚠️ A DASH UNTIL THERE ARE TWO READINGS. The
                                // first refresh cannot know a rate, and a zero
                                // there would be a measurement nobody took.
                                text: line.modelData.cpu < 0
                                      ? "—" : line.modelData.cpu.toFixed(1) + " %"
                                font.pixelSize: Theme.fontSizeSm
                                color: line.modelData.cpu > 20 ? Theme.warn : Theme.fgMuted
                            }

                            BarText {
                                Layout.preferredWidth: Theme.space6 * 1.6
                                horizontalAlignment: Text.AlignRight
                                text: line.modelData.mem >= 1024
                                      ? (line.modelData.mem / 1024).toFixed(1) + " GiB"
                                      : line.modelData.mem.toFixed(0) + " MiB"
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.fgMuted
                            }

                            // ⚠️ THE BUTTON IS ONLY THERE FOR YOUR OWN
                            // PROCESSES. His choice, and the honest one: a stop
                            // button on a root process would ask for a password
                            // this surface cannot show and would hang.
                            Pill {
                                visible: line.modelData.mine && hov.hovered
                                interactive: true
                                onClicked: Services.Procs.stop(line.modelData.pid, true)
                                Icon {
                                    text: "close"
                                    size: Theme.fontSizeSm
                                    color: Theme.error
                                }
                            }
                        }
                    }
                }
            }
        }

        BarText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSizeSm
            color: Services.Procs.status.length > 0 ? Theme.warn : Theme.fgMuted
            text: Services.Procs.status.length > 0
                  ? Services.Procs.status
                  : "Hover a line of your own to stop it — it is sent TERM, not KILL."
        }
    }
}
