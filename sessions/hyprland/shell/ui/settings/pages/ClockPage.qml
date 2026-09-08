// Clock & Date — how the time and the date are written, everywhere they are.
//
// ⚠️ THE SECTION BEHIND THIS PAGE DID NOT EXIST, and that is why the page was
// empty for a round. Four places built the time by hand with their own copy of
// the same pad helper — the collapsed island, the widened island, the bar and
// the lock screen — so there was nothing to offer here that would have reached
// all four. common/Clock.qml is now the single reader, and these settings are
// what it reads. A row over a key nothing reads is a control you can move that
// does nothing, and the audit found five of those.
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../../common"
import "../../../common"
import "../../../services" as Services
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    // ⚠️ TAKEN ONCE, WHEN THE PAGE OPENS, and not bound to a running clock. The
    // two rows below preview a date pattern by writing today out in it, and a
    // binding on the time would rebuild ten formatted strings every minute for
    // a preview that changes once a day. The honest cost of taking it once is
    // that a settings window left open past midnight shows yesterday in the
    // examples; the honest cost of the other way is work in an idle window,
    // which is the thing this desktop is measured on.
    property var today: new Date()
    Component.onCompleted: root.today = new Date()

    readonly property var dateFormats: Services.Suggest.dateFormats(root.today)

    SettingGroup {
        Layout.fillWidth: true
        title: "Time"

        SettingRow {
            Layout.fillWidth: true
            key: "clock.format"
            label: "Clock"
            hint: "The island, the bar and the lock screen, all from one setting."
            kind: "choice"
            choices: [
                { value: "24h", label: "24 hour" },
                { value: "12h", label: "12 hour" }
            ]
        }
        SettingRow {
            Layout.fillWidth: true
            key: "clock.showSeconds"
            label: "Show seconds"
            // Why it is this way: Every clock in the shell normally wakes on
            // the minute boundary and sleeps in between — on a laptop with the
            // lid shut, that is the difference between a clock that sleeps and
            // one that does not.
            hint: "It costs a redraw every second."
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Date"

        // ⚠️ TWO PATTERNS, AND THE SECOND IS NOT A DUPLICATE. The lock screen
        // has a whole screen; the widened island has a pill. A long month name
        // in there pushes the shape wider than the reference every day of the
        // week. Two places with two amounts of room, each with one reader.
        SettingRow {
            Layout.fillWidth: true
            key: "clock.dateFormat"
            advanced: true
            label: "Date on the lock screen"
            // Why it is this way: The names come from your system language.
            hint: "A Qt pattern: d day, ddd short weekday, dddd weekday, M month, MMM short month, MMMM month, yyyy year."
            kind: "pick"
            options: root.dateFormats
            placeholder: "dddd, d MMMM"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "clock.dateFormatShort"
            advanced: true
            label: "Date on the island"
            hint: "The same patterns, in a pill rather than on a screen."
            kind: "pick"
            options: root.dateFormats
            placeholder: "ddd, d MMM"
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Calendar"

        SettingRow {
            Layout.fillWidth: true
            key: "clock.weekStart"
            label: "Week starts on"
            // Why it is this way: Changing one without the other is the
            // off-by-one that puts every date on the wrong weekday, which is
            // why it is one setting and not two.
            hint: "Moves the column headings and the blank cells before the 1st together."
            kind: "choice"
            choices: [
                { value: "monday", label: "Monday" },
                { value: "sunday", label: "Sunday" }
            ]
        }
    }

    // ⚠️ A LIVE PREVIEW NEEDS A DEPENDENCY, and `new Date()` is not one. A
    // binding with nothing to depend on is evaluated once and then shows the
    // moment the page opened, for as long as it stays open — which for a date
    // format field is worse than showing nothing, because you would edit the
    // pattern and watch a frozen line refuse to follow. NotchWide.qml carried a
    // hand-written fake dependency for exactly this reason until today.
    SystemClock { id: preview; precision: Clock.precision }

    BarText {
        Layout.fillWidth: true
        text: "Right now: " + Clock.time(preview.date)
            + " · lock screen: " + Clock.date(preview.date)
            + " · island: " + Clock.dateShort(preview.date)
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
        wrapMode: Text.WordWrap
    }
}
