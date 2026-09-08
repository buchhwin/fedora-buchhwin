pragma ComponentBehavior: Bound

// A new appointment, as a page of the island.
//
// This is the page that writes. What it produces goes to Google over CalDAV and
// is therefore on the phone a moment later — which is the whole point, and also
// the reason it is deliberately plain: four fields, no repetition rules, no
// guests, no reminders. Anything more belongs in a calendar application, and
// the island is not one.
//
// Typed with the keyboard from start to finish: Tab moves on, Enter saves,
// Escape leaves. Reaching for the mouse to type a date is how a quick note
// stops being quick.
//
// Dates are typed as 05.08.2026 and times as 14:00, in the order they are said
// out loud here. Both are checked as you type, and Save is simply not offered
// while anything does not parse — an error message after the fact is worse than
// a button that never lies.
import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../ipc"
import "../../../services" as Services
import "../../common"

ColumnLayout {
    id: root
    spacing: Theme.space3
    implicitWidth: Theme.space6 * 18

    // The day the calendar page was showing when this was opened, so "new
    // appointment" means the day you were looking at rather than today.
    readonly property date base: Services.Calendar.draftDate

    property string busyNote: ""

    function pad(n) { return n < 10 ? "0" + n : "" + n }

    Component.onCompleted: title.forceActiveFocus()

    // ------------------------------------------------------------ validation
    // "05.08.2026" → a Date, or null. Rejects the 31st of February by building
    // the date and checking it did not roll over, which is the only check that
    // does not need a table of month lengths.
    function parseDate(s) {
        var m = /^\s*(\d{1,2})\.(\d{1,2})\.(\d{4})\s*$/.exec(s)
        if (!m) return null
        var d = new Date(+m[3], +m[2] - 1, +m[1])
        if (d.getFullYear() !== +m[3] || d.getMonth() !== +m[2] - 1 || d.getDate() !== +m[1])
            return null
        return d
    }

    // "14:00" → minutes since midnight, or -1.
    function parseTime(s) {
        var m = /^\s*(\d{1,2})[:.](\d{2})\s*$/.exec(s)
        if (!m) return -1
        var h = +m[1], mi = +m[2]
        if (h > 23 || mi > 59) return -1
        return h * 60 + mi
    }

    readonly property var theDate: parseDate(dateField.text)
    readonly property int fromMin: allDay.on ? 0 : parseTime(fromField.text)
    readonly property int toMin: allDay.on ? 0 : parseTime(toField.text)

    readonly property bool valid:
        title.text.trim().length > 0 && theDate !== null &&
        (allDay.on || (fromMin >= 0 && toMin >= 0 && toMin > fromMin))

    function startDate() {
        var d = new Date(theDate.getTime())
        if (!allDay.on) d.setHours(Math.floor(fromMin / 60), fromMin % 60, 0, 0)
        return d
    }
    function endDate() {
        var d = new Date(theDate.getTime())
        if (allDay.on) d.setDate(d.getDate() + 1)
        else d.setHours(Math.floor(toMin / 60), toMin % 60, 0, 0)
        return d
    }

    function save() {
        if (!root.valid || root.busyNote.length) return
        root.busyNote = "saving …"
        Services.Calendar.create({
            summary: title.text.trim(),
            location: "",
            start: root.startDate(),
            end: root.endDate(),
            allDay: allDay.on
        }, function (ok, why) {
            if (ok) {
                root.busyNote = ""
                Ipc.show("calendar")      // back to the month, which reloads itself
            } else {
                root.busyNote = why
            }
        })
    }

    // ------------------------------------------------------------- the fields
    //
    // ⚠️ THE `component Field` THAT USED TO BE HERE IS NOW common/TextField.qml.
    // It was the first of five hand-drawn text fields in this shell and the
    // cleanest of them, so it is the one that got lifted when the settings
    // window needed a sixth. The sentence that justified drawing it at all is
    // now in that file's header, along with the reason it stays drawn:
    // QtQuick.Controls would bring a second styling vocabulary into a shell
    // whose whole point is having one.
    //
    // What is different here is only that Return and Escape are signals now
    // rather than being written inside the field — which is right, because what
    // Return MEANS belongs to the form, not to the box.
    //
    // The other four copies — the clipboard search, the launcher search, the
    // location picker and the wifi password box — are still their own. Each
    // wants something slightly different (key forwarding, an echo mode), and
    // moving four working surfaces over is its own change with its own
    // screenshots, not a footnote to this one.

    TextField {
        id: title
        Layout.fillWidth: true
        placeholder: "Title"
        KeyNavigation.tab: dateField.input
        onAccepted: root.save()
        onCancelled: Ipc.collapse()
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space2

        TextField {
            id: dateField
            Layout.fillWidth: true
            text: root.pad(root.base.getDate()) + "." +
                  root.pad(root.base.getMonth() + 1) + "." + root.base.getFullYear()
            placeholder: "TT.MM.JJJJ"
            bad: text.length > 0 && root.theDate === null
            KeyNavigation.tab: allDay.on ? title.input : fromField.input
            onAccepted: root.save()
            onCancelled: Ipc.collapse()
        }

        TextField {
            id: fromField
            Layout.preferredWidth: Theme.space6 * 3
            visible: !allDay.on
            text: "09:00"
            placeholder: "From"
            bad: text.length > 0 && root.parseTime(text) < 0
            KeyNavigation.tab: toField.input
            onAccepted: root.save()
            onCancelled: Ipc.collapse()
        }

        TextField {
            id: toField
            Layout.preferredWidth: Theme.space6 * 3
            visible: !allDay.on
            text: "10:00"
            placeholder: "To"
            // Also wrong when it is merely earlier than the start — an
            // appointment that ends before it begins is a typo, not a plan.
            bad: text.length > 0 &&
                 (root.parseTime(text) < 0 || root.parseTime(text) <= root.fromMin)
            KeyNavigation.tab: title.input
            onAccepted: root.save()
            onCancelled: Ipc.collapse()
        }

        Pill {
            id: allDay
            property bool on: false
            interactive: true
            active: on
            BarText {
                text: "all day"
                font.pixelSize: Theme.fontSizeSm
                color: allDay.on ? Theme.accentFg : Theme.fg
            }
            onClicked: allDay.on = !allDay.on
        }
    }

    // ------------------------------------------------------------ the footer
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space2

        BarText {
            Layout.fillWidth: true
            font.pixelSize: Theme.fontSizeSm
            color: root.busyNote.length && root.busyNote !== "saving …"
                   ? Theme.error : Theme.fgMuted
            wrapMode: Text.WordWrap
            text: root.busyNote.length ? root.busyNote
                : !Services.Calendar.available ? Services.Calendar.status
                : "Enter saves · Escape cancels"
        }

        Pill {
            interactive: true
            active: root.valid && Services.Calendar.available
            BarText {
                text: "Save"
                font.pixelSize: Theme.fontSizeSm
                color: parent.active ? Theme.accentFg : Theme.fgDim
            }
            onClicked: root.save()
        }
    }
}
