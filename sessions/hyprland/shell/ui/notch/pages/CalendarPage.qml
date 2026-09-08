pragma ComponentBehavior: Bound

// The month, as a page of the island.
//
// The month itself is pure arithmetic: no service, no network, nothing that can
// be unavailable. The clock it reads is the same SystemClock the collapsed
// island shows, so the two can never disagree about what day it is.
//
// Appointments come from services/Calendar.qml — Google, over CalDAV, using the
// account in gnome-online-accounts. They are ADDED to the month rather than
// required by it: with no account, no network or a refused token, the grid is
// still a working calendar and one line of text says why there are no entries.
//
// Weather belongs on this page and is deliberately absent. It needs a location,
// and the place to type a location in is the settings window, which M8 builds.
// A weather line with nowhere to set the location would be a decoration that
// lies on someone else's machine.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../theme"
import "../../../ipc"
import "../../../services" as Services
import "../../common"
import "../../../common"

ColumnLayout {
    id: root
    spacing: Theme.space3
    implicitWidth: Theme.space6 * 18

    SystemClock { id: clock; precision: Clock.precision }

    // The month on display. Kept as year+month rather than a Date so that
    // stepping over a year boundary is arithmetic instead of a special case.
    property int shownYear: clock.date.getFullYear()
    property int shownMonth: clock.date.getMonth()      // 0-11

    readonly property bool onToday: shownYear === clock.date.getFullYear()
                                    && shownMonth === clock.date.getMonth()

    // ⚠️ NOT A TYPED-OUT LIST OF MONTH NAMES.
    //
    // Twelve hand-written names are twelve translations to maintain, and they
    // were German while the rest of the interface was becoming English. Qt
    // already knows the names in whatever language the machine is set to, and
    // the lock screen has done it this way from the start. One source, no list.
    function monthName(m) {
        return Qt.formatDate(new Date(root.shownYear, m, 1), "MMMM")
    }

    // ⚠️ THE HEADINGS AND THE BLANK CELLS ARE ONE DECISION, and the comment
    // that used to be here said so as a warning: "the grid below is built on a
    // fixed Monday offset, so changing it here without changing that is how a
    // calendar quietly shows the wrong weekday." It is a setting now, so both
    // read `Clock.mondayFirst` — this list and `leading` below — and neither can
    // be changed without the other.
    //
    // The NAMES still come from Qt in whatever language the machine is set to;
    // only the order is ours.
    readonly property var dayNames: {
        var out = []
        var first = Clock.mondayFirst ? 1 : 0
        for (var i = 0; i < 7; i++)
            out.push(Qt.locale().dayName((first + i) % 7, Locale.ShortFormat))
        return out
    }

    // Which day's appointments are listed below the grid. -1 = today's, so the
    // page opens on the question you actually had.
    property int selectedDay: onToday ? clock.date.getDate() : 1

    function step(months) {
        var m = shownMonth + months
        shownYear += Math.floor(m / 12)
        shownMonth = ((m % 12) + 12) % 12
        selectedDay = onToday ? clock.date.getDate() : 1
    }

    // Ask for the month being shown, and again whenever something was written.
    // ⚠️ The service is a singleton, and QML builds those on FIRST ACCESS —
    // touching it here is what starts it. A load triggered from inside the
    // handler that reads the result would find it empty every time.
    Component.onCompleted: Services.Calendar.loadMonth(shownYear, shownMonth)
    onShownMonthChanged: Services.Calendar.loadMonth(shownYear, shownMonth)
    onShownYearChanged: Services.Calendar.loadMonth(shownYear, shownMonth)

    Connections {
        target: Services.Calendar
        function onChanged() {
            Services.Calendar.loadMonth(root.shownYear, root.shownMonth)
        }
    }

    readonly property var dayEvents:
        Services.Calendar.pickDay(Services.Calendar.events,
                                  shownYear, shownMonth, selectedDay)

    // Hand the day being looked at to the new-appointment page before switching
    // to it. Otherwise "new appointment" would always mean today, which is
    // almost never the day you were pointing at.
    function newEvent() {
        Services.Calendar.draftDate = new Date(shownYear, shownMonth, selectedDay)
        Ipc.show("event")
    }

    function timeLabel(e) {
        if (e.allDay)
            return "all day"
        function p(n) { return n < 10 ? "0" + n : "" + n }
        return p(e.start.getHours()) + ":" + p(e.start.getMinutes())
    }

    // Blank cells before the 1st. getDay() is 0=Sunday, so Monday-first needs
    // the shift — the classic off-by-one that puts every date on the wrong day.
    // Sunday-first needs none, which is the whole difference between the two.
    readonly property int leading: {
        var d = new Date(root.shownYear, root.shownMonth, 1).getDay()
        return Clock.mondayFirst ? (d + 6) % 7 : d
    }
    readonly property int daysInMonth: new Date(shownYear, shownMonth + 1, 0).getDate()

    Keys.onLeftPressed: root.step(-1)
    Keys.onRightPressed: root.step(1)
    Keys.onEscapePressed: root.step(0)      // consumed; the island handles closing

    // ------------------------------------------------------------ month head
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space2

        Pill {
            interactive: true
            Icon { text: "chevron_left"; size: Theme.fontSizeLg }
            onClicked: root.step(-1)
        }

        BarText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            font.weight: Theme.weightSemibold
            text: root.monthName(root.shownMonth) + " " + root.shownYear
        }

        // Only offered when it would do something. A button that is already
        // where it takes you is noise.
        Pill {
            interactive: true
            visible: !root.onToday
            BarText { text: "today"; font.pixelSize: Theme.fontSizeSm }
            onClicked: {
                root.shownYear = clock.date.getFullYear()
                root.shownMonth = clock.date.getMonth()
            }
        }

        Pill {
            interactive: true
            Icon { text: "chevron_right"; size: Theme.fontSizeLg }
            onClicked: root.step(1)
        }

        // Only where it can do something. Without a connected calendar there is
        // nowhere to put an appointment, and a button that opens a form which
        // cannot save is worse than no button.
        Pill {
            interactive: true
            visible: Services.Calendar.available
            Icon { text: "add"; size: Theme.fontSizeLg }
            onClicked: root.newEvent()
        }
    }

    // --------------------------------------------------------------- weekdays
    GridLayout {
        Layout.fillWidth: true
        columns: 7
        columnSpacing: 0
        rowSpacing: Theme.space1

        Repeater {
            model: root.dayNames
            BarText {
                required property string modelData
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.fontSizeSm
                color: Theme.fgMuted
                text: modelData
            }
        }
    }

    // ------------------------------------------------------------------ grid
    GridLayout {
        Layout.fillWidth: true
        columns: 7
        columnSpacing: 0
        rowSpacing: Theme.space1

        Repeater {
            // Six rows always: a month that needs five must not make the island
            // change height as you page through it.
            model: 42

            Item {
                id: cellItem
                required property int index

                readonly property int day: index - root.leading + 1
                readonly property bool inMonth: day >= 1 && day <= root.daysInMonth
                readonly property bool isToday:
                    inMonth && root.onToday && day === clock.date.getDate()
                readonly property bool isSelected: inMonth && day === root.selectedDay
                // O(1): the index is built once per load, not scanned per cell.
                readonly property bool hasEvents:
                    inMonth && Services.Calendar.anyOn(Services.Calendar.dayIndex,
                                                       root.shownYear, root.shownMonth, day)

                Layout.fillWidth: true
                implicitHeight: Theme.space5 + Theme.space2

                Rectangle {
                    id: pill
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top }
                    width: Math.min(parent.width, Theme.space5)
                    height: width
                    radius: Theme.radiusPill
                    // Accent is today. The day you are LOOKING at is marked by
                    // surface, not by a second accent — two accents on one grid
                    // and neither means anything any more.
                    color: cellItem.isToday ? Theme.accent
                         : cellItem.isSelected ? Theme.surfaceHigh
                         : "transparent"                     // literal-ok: absence of colour

                    BarText {
                        anchors.centerIn: parent
                        visible: cellItem.inMonth
                        text: cellItem.day
                        font.pixelSize: Theme.fontSizeSm
                        font.weight: cellItem.isToday ? Theme.weightSemibold : Theme.weightNormal
                        color: cellItem.isToday ? Theme.accentFg : Theme.fg
                    }

                    TapHandler {
                        enabled: cellItem.inMonth
                        onTapped: root.selectedDay = cellItem.day
                    }
                }

                // A day with appointments carries a dot. It is the smallest
                // mark that answers "is anything on" without reading anything.
                Rectangle {
                    anchors { horizontalCenter: parent.horizontalCenter; top: pill.bottom
                              topMargin: Theme.space1 / 2 }
                    visible: cellItem.hasEvents
                    width: Theme.space1
                    height: width
                    radius: Theme.radiusPill
                    color: cellItem.isToday ? Theme.accent : Theme.fgMuted
                }
            }
        }
    }

    // --------------------------------------------------------- the day's list
    // Under the grid, and only when there is something to say. An empty box
    // under every day would make the island taller for nothing.
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.space1
        visible: root.dayEvents.length > 0 || root.calendarNote.length > 0

        BarText {
            Layout.fillWidth: true
            visible: root.calendarNote.length > 0
            text: root.calendarNote
            color: Theme.fgMuted
            font.pixelSize: Theme.fontSizeSm
            wrapMode: Text.WordWrap
        }

        Repeater {
            // Four at most: the island is for a glance. The fifth line would be
            // the one that makes it a window.
            model: Math.min(root.dayEvents.length, 4)

            RowLayout {
                id: line
                required property int index
                readonly property var ev: root.dayEvents[index]

                Layout.fillWidth: true
                spacing: Theme.space2

                BarText {
                    text: root.timeLabel(line.ev)
                    color: Theme.fgMuted
                    font.pixelSize: Theme.fontSizeSm
                    Layout.minimumWidth: Theme.space6 * 2
                }

                BarText {
                    Layout.fillWidth: true
                    text: line.ev.summary.length ? line.ev.summary : "(no title)"
                    font.pixelSize: Theme.fontSizeSm
                    elide: Text.ElideRight
                }
            }
        }

        BarText {
            Layout.fillWidth: true
            visible: root.dayEvents.length > 4
            text: "and " + (root.dayEvents.length - 4) + " more"
            color: Theme.fgMuted
            font.pixelSize: Theme.fontSizeSm
        }
    }

    // Why there are no appointments, when that is the interesting part. Empty
    // while everything works — a calendar with nothing on Tuesday should say
    // nothing, not "0 Termine".
    readonly property string calendarNote:
        Services.Calendar.status.length > 0 ? Services.Calendar.status
      : (Services.Calendar.busy ? "Loading events …" : "")
}
