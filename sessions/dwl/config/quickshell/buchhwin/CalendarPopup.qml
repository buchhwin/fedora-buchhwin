import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    Theme { id: theme }
    property bool opened: false
    property date today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()
    property int selectedDay: today.getDate()
    property var events: []
    property var calendars: []
    property int selectedCalendar: 0
    property bool editing: false
    property string editingId: ""
    property string status: ""
    property real reveal: opened ? 1.0 : 0.0

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property int firstOffset: (new Date(viewYear, viewMonth, 1).getDay() + 6) % 7
    readonly property int daysInMonth: new Date(viewYear, viewMonth + 1, 0).getDate()

    function sameDay(timestamp, day) {
        const date = new Date(timestamp * 1000)
        return date.getFullYear() === viewYear && date.getMonth() === viewMonth && date.getDate() === day
    }
    function eventsForDay(day) {
        return events.filter(event => sameDay(event.start, day))
    }
    function loadEvents() {
        const since = Math.floor(new Date(viewYear, viewMonth, 1).getTime() / 1000)
        const until = Math.floor(new Date(viewYear, viewMonth + 1, 1).getTime() / 1000)
        eventProc.command = ["buchhwin-calendar-events", String(since), String(until)]
        if (!eventProc.running) eventProc.running = true
        if (!calendarProc.running) calendarProc.running = true
    }
    function beginNew() {
        editingId = ""; eventTitle.text = ""; startTime.text = "09:00"; endTime.text = "10:00"; editing = true
        eventTitle.forceActiveFocus()
    }
    function beginEdit(event) {
        editingId = event.id; eventTitle.text = event.summary
        startTime.text = Qt.formatTime(new Date(event.start * 1000), "HH:mm")
        endTime.text = Qt.formatTime(new Date(event.end * 1000), "HH:mm")
        editing = true
    }
    function saveEvent() {
        if (!eventTitle.text.trim().length) { status = "Please enter a title"; return }
        const startParts = startTime.text.split(":"), endParts = endTime.text.split(":")
        if (startParts.length !== 2 || endParts.length !== 2) { status = "Use time format HH:MM"; return }
        const start = Math.floor(new Date(viewYear, viewMonth, selectedDay, Number(startParts[0]), Number(startParts[1])).getTime() / 1000)
        const end = Math.floor(new Date(viewYear, viewMonth, selectedDay, Number(endParts[0]), Number(endParts[1])).getTime() / 1000)
        if (end <= start) { status = "End must be after start"; return }
        if (editingId.length)
            manageProc.command = ["buchhwin-calendar-manage", "update", editingId, eventTitle.text.trim(), String(start), String(end)]
        else {
            if (!calendars.length) { status = "No writable calendar available"; return }
            manageProc.command = ["buchhwin-calendar-manage", "create", calendars[selectedCalendar].uid, eventTitle.text.trim(), String(start), String(end)]
        }
        manageProc.running = true
    }
    function moveMonth(delta) {
        const date = new Date(viewYear, viewMonth + delta, 1)
        viewYear = date.getFullYear(); viewMonth = date.getMonth(); selectedDay = 1
        loadEvents()
    }

    Behavior on reveal { NumberAnimation { duration: theme.durationMedium; easing.type: root.opened ? theme.easingEnter : theme.easingExit } }
    visible: opened || reveal > 0.001
    focusable: opened
    color: Qt.rgba(0, 0, 0, 0.35 * reveal)
    exclusiveZone: 0
    aboveWindows: true
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.namespace: "buchhwin-calendar"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    onOpenedChanged: if (opened) { today = new Date(); loadEvents() }
    Shortcut { sequence: "Escape"; enabled: root.opened; onActivated: root.opened = false }
    MouseArea { anchors.fill: parent; onClicked: root.opened = false }

    Process {
        id: eventProc
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.events = JSON.parse(text); root.status = "" }
                catch (error) { root.events = []; root.status = "Calendar could not be read" }
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim().length) root.status = text.trim() }
    }
    Process {
        id: calendarProc
        command: ["buchhwin-calendar-manage", "calendars"]
        stdout: StdioCollector { onStreamFinished: { try { root.calendars = JSON.parse(text) } catch (error) { root.calendars = [] } } }
    }
    Process {
        id: manageProc
        stderr: StdioCollector { onStreamFinished: if (text.trim().length) root.status = text.trim() }
        onExited: code => {
            if (code === 0) { root.editing = false; root.status = "Saved"; refreshDelay.restart() }
            else if (!root.status.length) root.status = "Could not save appointment"
        }
    }
    Timer { id: refreshDelay; interval: 900; onTriggered: root.loadEvents() }

    Rectangle {
        anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: theme.barPosition === "top" ? theme.barSize : 12
        width: Math.min(720, parent.width - 24)
        height: Math.min(480, parent.height - 58)
        radius: 14; color: theme.surface; border.width: 1; border.color: theme.border
        opacity: root.reveal
        transform: Translate { y: -(1 - root.reveal) * theme.lift }
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton }

        RowLayout {
            anchors.fill: parent; anchors.margins: 16; spacing: 18
            ColumnLayout {
                Layout.preferredWidth: 390; Layout.fillHeight: true; spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    Text { font.family: theme.font; text: "‹"; color: theme.text; font.pixelSize: 25; MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: root.moveMonth(-1) } }
                    Item { Layout.fillWidth: true }
                    Text { font.family: theme.font; text: root.monthNames[root.viewMonth] + " " + root.viewYear; color: theme.text; font.pixelSize: 16; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { font.family: theme.font; text: "›"; color: theme.text; font.pixelSize: 25; MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: root.moveMonth(1) } }
                }
                GridLayout {
                    Layout.fillWidth: true; columns: 7; rowSpacing: 4; columnSpacing: 4
                    Repeater {
                        model: ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
                        Text { required property string modelData; Layout.preferredWidth: 50; horizontalAlignment: Text.AlignHCenter; text: modelData; color: theme.subtext; font.family: theme.font; font.pixelSize: 9 }
                    }
                    Repeater {
                        model: 42
                        delegate: Rectangle {
                            required property int index
                            readonly property int day: index - root.firstOffset + 1
                            readonly property bool valid: day >= 1 && day <= root.daysInMonth
                            readonly property bool selected: valid && day === root.selectedDay
                            readonly property bool isToday: valid && day === root.today.getDate() && root.viewMonth === root.today.getMonth() && root.viewYear === root.today.getFullYear()
                            Layout.preferredWidth: 50; Layout.preferredHeight: 44; radius: 8
                            color: selected ? theme.surface3 : dayMouse.containsMouse && valid ? theme.surface2 : "transparent"
                            border.width: isToday ? 1 : 0; border.color: theme.blue
                            Text { anchors.centerIn: parent; text: valid ? day : ""; color: selected || isToday ? theme.text : theme.subtext; font.family: theme.font; font.pixelSize: 11; font.bold: selected || isToday }
                            Rectangle { visible: valid && root.eventsForDay(day).length > 0; anchors.bottom: parent.bottom; anchors.bottomMargin: 5; anchors.horizontalCenter: parent.horizontalCenter; width: 4; height: 4; radius: 2; color: theme.blue }
                            MouseArea { id: dayMouse; anchors.fill: parent; hoverEnabled: true; enabled: valid; onClicked: root.selectedDay = day }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }
            Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: theme.border }
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 9
                RowLayout {
                    Layout.fillWidth: true
                    Text { font.family: theme.font; text: root.selectedDay + ". " + root.monthNames[root.viewMonth]; color: theme.text; font.pixelSize: 15; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Rectangle { width: 64; height: 28; radius: 7; color: newMouse.containsMouse ? theme.surface3 : theme.surface2
                        Text { anchors.centerIn: parent; text: "+ New"; color: theme.text; font.family: theme.font; font.pixelSize: 9 }
                        MouseArea { id: newMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.beginNew() }
                    }
                }
                Rectangle {
                    visible: root.editing; Layout.fillWidth: true; Layout.preferredHeight: visible ? 154 : 0
                    radius: 9; color: theme.surface2; border.width: 1; border.color: theme.border
                    ColumnLayout { anchors.fill: parent; anchors.margins: 9; spacing: 7
                        TextInput { id: eventTitle; Layout.fillWidth: true; color: theme.text; font.family: theme.font; font.pixelSize: 11; selectByMouse: true; clip: true }
                        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Start"; color: theme.subtext; font.family: theme.font; font.pixelSize: 9 }
                            TextInput { id: startTime; Layout.preferredWidth: 48; color: theme.text; font.family: theme.font; font.pixelSize: 10; selectByMouse: true }
                            Text { text: "End"; color: theme.subtext; font.family: theme.font; font.pixelSize: 9 }
                            TextInput { id: endTime; Layout.preferredWidth: 48; color: theme.text; font.family: theme.font; font.pixelSize: 10; selectByMouse: true }
                        }
                        Flow { Layout.fillWidth: true; visible: !root.editingId.length; spacing: 4
                            Repeater { model: root.calendars; delegate: Rectangle {
                                required property var modelData; required property int index
                                width: Math.min(120, calendarName.implicitWidth + 14); height: 24; radius: 6
                                color: root.selectedCalendar === index ? theme.blue : theme.bg
                                Text { id: calendarName; anchors.centerIn: parent; text: modelData.name; color: root.selectedCalendar === index ? theme.bg : theme.text; font.family: theme.font; font.pixelSize: 8 }
                                MouseArea { anchors.fill: parent; onClicked: root.selectedCalendar = index }
                            } }
                        }
                        RowLayout { Layout.fillWidth: true; Item { Layout.fillWidth: true }
                            Text { text: "Cancel"; color: theme.subtext; font.family: theme.font; font.pixelSize: 9; MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.editing = false } }
                            Rectangle { width: 58; height: 26; radius: 6; color: theme.blue
                                Text { anchors.centerIn: parent; text: "Save"; color: theme.bg; font.family: theme.font; font.pixelSize: 9; font.bold: true }
                                MouseArea { anchors.fill: parent; onClicked: root.saveEvent() }
                            }
                        }
                    }
                }
                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 6; clip: true
                    model: root.eventsForDay(root.selectedDay)
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width; height: 58; radius: 9; color: theme.surface2
                        Column { anchors.fill: parent; anchors.margins: 9; spacing: 4
                            Text { width: parent.width; text: modelData.summary; elide: Text.ElideRight; color: theme.text; font.family: theme.font; font.pixelSize: 11; font.bold: true }
                            Text { text: Qt.formatTime(new Date(modelData.start * 1000), "HH:mm") + " – " + Qt.formatTime(new Date(modelData.end * 1000), "HH:mm"); color: theme.subtext; font.family: theme.font; font.pixelSize: 9 }
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.beginEdit(modelData) }
                    }
                }
                Text { visible: root.eventsForDay(root.selectedDay).length === 0; text: root.status || "No appointments"; color: theme.subtext; font.family: theme.font; font.pixelSize: 10 }
                Rectangle {
                    Layout.fillWidth: true; height: 34; radius: 8; color: openCalendarMouse.containsMouse ? theme.surface3 : theme.surface2
                    Text { anchors.centerIn: parent; text: "Open Merkuro"; color: theme.text; font.family: theme.font; font.pixelSize: 10 }
                    MouseArea { id: openCalendarMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { root.opened = false; Quickshell.execDetached(["merkuro-calendar"]) } }
                }
            }
        }
    }
}
