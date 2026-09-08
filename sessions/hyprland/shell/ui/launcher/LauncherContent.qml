pragma ComponentBehavior: Bound

// The launcher: categories on the left, programs on the right.
//
// Straight from the brief: "Starter, zwei Spalten, links Kategorien,   english-ok: quoted brief
// rechts die Apps" — with All and Frequent pinned above the categories.   english-ok: quoted brief
// What goes in which column is decided by services/Apps.qml; this file is
// only how it looks and how the keyboard moves through it.
//
// ⚠️ TYPING TAKES PRECEDENCE OVER THE COLUMNS. The search field has the focus
// from the moment the surface opens, so the fastest path — type three letters,
// press Enter — never requires touching the mouse or the categories. While a
// query is present the left column is dimmed rather than hidden: a list that
// jumps between one and two columns as you type is harder to aim at than one
// that stays put.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../config"
import "../../ipc"
import "../../services" as Services
import "../common"

FocusScope {
    id: root

    // A fixed size, unlike the notch pages. Those are as big as their content
    // because their content is short; a program list is not, and a launcher
    // that changes shape while you type is a moving target.
    implicitWidth: Config.launcher.width
    implicitHeight: Config.launcher.height

    property string query: ""
    property string category: "all"

    // The list on the right: search results while typing, otherwise whatever
    // the selected category holds.
    readonly property var shown:
        root.query.trim().length ? Services.Apps.search(root.query)
                                 : Services.Apps.inCategory(root.category)

    // Reset when the surface closes, so it never reopens mid-search.
    function reset() {
        root.query = ""
        root.category = "all"
        list.currentIndex = 0
        field.forceActiveFocus()
    }

    // One way in for both the mouse and Tab, so the two can never drift.
    function choose(key) {
        root.category = key
        root.query = ""
        field.text = ""
        list.currentIndex = 0
        field.forceActiveFocus()
    }

    function launch(index) {
        var app = root.shown[index]
        if (!app)
            return
        // Close first: launching takes a moment, and a launcher still standing
        // open over the window that just appeared is the thing everyone hates
        // about launchers.
        Ipc.hideLauncher()
        Services.Apps.launch(app.id)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.space4
        spacing: Theme.space3

        // ------------------------------------------------------------ search
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: field.implicitHeight + Theme.space3
            radius: Theme.radiusMd
            color: Theme.pillBg

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.space3
                anchors.rightMargin: Theme.space3
                spacing: Theme.space2

                Icon { text: "search"; color: Theme.fgMuted }

                TextInput {
                    id: field
                    Layout.fillWidth: true
                    focus: true
                    color: Theme.fg
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fontSize
                    selectByMouse: true
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentFg
                    clip: true

                    onTextChanged: {
                        root.query = text
                        list.currentIndex = 0
                    }

                    // The four keys a list needs, handled here rather than on
                    // the list: the field owns the focus, so the list would
                    // never see them.
                    Keys.onDownPressed: list.incrementCurrentIndex()
                    Keys.onUpPressed: list.decrementCurrentIndex()
                    Keys.onReturnPressed: root.launch(list.currentIndex)
                    Keys.onEnterPressed: root.launch(list.currentIndex)
                    Keys.onEscapePressed: Ipc.hideLauncher()
                    // Tab steps through the categories without leaving the
                    // keyboard — the one thing the mouse could do that typing
                    // could not.
                    Keys.onTabPressed: cats.step(1)
                    Keys.onBacktabPressed: cats.step(-1)

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: !field.text.length
                        text: "Search programs"
                        font: field.font
                        color: Theme.fgDim
                    }
                }

                // Says what the list is showing, so a short result set never
                // looks like a broken search.
                BarText {
                    text: root.shown.length + ""
                    color: Theme.fgDim
                    font.pixelSize: Theme.fontSizeSm
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.space3

            // ------------------------------------------------- categories
            ListView {
                id: cats
                Layout.preferredWidth: Math.round(root.implicitWidth * 0.28)
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                spacing: Theme.space1

                // All and Frequent are pinned above the real categories, in
                // that order, exactly as the brief asks.
                model: ["all", "frequent"].concat(Services.Apps.categories)

                // Dimmed, not hidden, while a search is running: the column
                // keeps its width so the list beside it does not move.
                opacity: root.query.trim().length ? Theme.dimmed : 1
                Behavior on opacity {
                    enabled: Theme.animate
                    NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                }

                function step(d) {
                    var n = count
                    if (!n)
                        return
                    var i = model.indexOf(root.category)
                    root.choose(model[((i + d) % n + n) % n])
                }

                delegate: Rectangle {
                    id: cat
                    required property string modelData
                    readonly property bool chosen: cat.modelData === root.category

                    width: cats.width
                    height: catRow.implicitHeight + Theme.space2
                    radius: Theme.radiusSm
                    color: cat.chosen ? Theme.accent
                         : catHover.hovered ? Theme.pillHover
                         : "transparent"          // literal-ok: absence of colour

                    Behavior on color {
                        enabled: Theme.animate
                        ColorAnimation { duration: Theme.durFast }
                    }

                    RowLayout {
                        id: catRow
                        anchors.fill: parent
                        anchors.leftMargin: Theme.space2
                        anchors.rightMargin: Theme.space2
                        spacing: Theme.space2

                        Icon {
                            text: Services.Apps.icon(cat.modelData)
                            size: Theme.fontSize
                            color: cat.chosen ? Theme.accentFg : Theme.fgMuted
                        }
                        BarText {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: Services.Apps.label(cat.modelData)
                            color: cat.chosen ? Theme.accentFg : Theme.fg
                        }
                    }

                    HoverHandler { id: catHover }
                    TapHandler { onTapped: root.choose(cat.modelData) }
                }
            }

            // ---------------------------------------------------- programs
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                spacing: Theme.space1
                model: root.shown
                // Keep the selected row on screen when the arrows move it past
                // the edge — otherwise the keyboard walks into nothing.
                highlightFollowsCurrentItem: true
                preferredHighlightBegin: Theme.space6
                preferredHighlightEnd: height - Theme.space6
                highlightRangeMode: ListView.ApplyRange

                delegate: Rectangle {
                    id: appRowItem
                    required property var modelData
                    required property int index

                    width: list.width
                    height: appRow.implicitHeight + Theme.space2
                    radius: Theme.radiusSm
                    color: appRowItem.index === list.currentIndex
                           ? Theme.pillHover
                           : "transparent"        // literal-ok: absence of colour

                    RowLayout {
                        id: appRow
                        anchors.fill: parent
                        anchors.leftMargin: Theme.space2
                        anchors.rightMargin: Theme.space3
                        spacing: Theme.space3

                        AppIcon {
                            source: appRowItem.modelData.icon
                            appName: appRowItem.modelData.name
                            size: Theme.fontSizeXl
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            // The name and its description are one label on two
                            // lines, not two things in a list.
                            spacing: 0   // literal-ok: one label, not a gap

                            BarText {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: appRowItem.modelData.name
                            }
                            // The one-line description, where the program has
                            // one. Two rows that both say "Terminal" are two
                            // rows you have to try to tell apart.
                            BarText {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                elide: Text.ElideRight
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.fgDim
                                // The binary joins the description only when
                                // two programs share a name — see Apps.qml.
                                text: (appRowItem.modelData.ambiguous
                                       ? appRowItem.modelData.binary + " · " : "")
                                      + (appRowItem.modelData.generic.length
                                         ? appRowItem.modelData.generic
                                         : appRowItem.modelData.comment)
                            }
                        }
                    }

                    HoverHandler {
                        onHoveredChanged: if (hovered) list.currentIndex = appRowItem.index
                    }
                    TapHandler { onTapped: root.launch(appRowItem.index) }
                }

                // Three different nothings, and they mean different things.
                BarText {
                    anchors.centerIn: parent
                    width: parent.width - Theme.space6
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: Theme.fgDim
                    visible: list.count === 0
                    text: !Services.Apps.available
                          ? "No programs found — nothing on this machine has a desktop entry"
                          : root.query.trim().length
                            ? "Nothing matches \"" + root.query.trim() + "\""
                            : root.category === "frequent"
                              ? "Nothing started from here yet"
                              : "This category is empty"
                }
            }
        }
    }
}
