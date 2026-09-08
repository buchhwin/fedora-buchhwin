pragma Singleton

// The palettes you can switch to: the ones that ship, plus the three the shell
// calculates for itself.
//
// ⚠️ THE SHIPPED LIST IS READ, NOT WRITTEN DOWN. Eleven names in a QML array
// would be eleven names to forget when a twelfth JSON arrives — and the whole
// promise of theme/palettes/ is "drop a file in and it appears", which a
// hard-coded list quietly cancels. FolderListModel, the same as Wallpaper.qml
// uses: pure QML, no shell command, no process per keystroke.
//
// ⚠️ AND THREE THAT ARE NOT IN THAT FOLDER, which is why this is not simply the
// folder listing. `wallpaper`, `custom` and `neutral` are calculated rather than
// shipped, and they live in XDG_STATE_HOME instead — theme/Scheme.qml says at
// length why they are not repository files (an rsync --delete of shell/ wiped
// the derived palette during development and the next start came up on the
// fallback). A menu that offered only the folder would leave out the mode the
// desktop is most likely to already be in: on the test VM `theme.palette` is
// "wallpaper", so every card would have read as "not the current one".
//
// ⚠️ WHAT IS DELIBERATELY NOT HERE: the colours. A card in the theme menu draws
// itself in the palette it offers, so it needs all 26 names of a palette that is
// NOT the active one — and a service holding them all would keep fourteen
// palettes' worth of state alive for the seconds a menu is open. Each card loads
// its own file while it exists. See ui/notch/pages/ThemePage.qml.
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import "../config"
import "../theme"

Singleton {
    id: root

    // ⚠️ `shellPath`, not a literal. Quickshell loads through a virtual
    // filesystem, and the shell may be running from /usr/share, from a git
    // checkout, or from ~/repo on the test VM. Scheme.qml resolves palettes the
    // same way and the two must not disagree about where they are.
    readonly property string folder: Quickshell.shellPath("theme/palettes")

    // ⚠️ Scheme owns where the derived ones live, and it stays that way. Copying
    // the XDG_STATE_HOME expression here would be a second place to fix when it
    // moves — and it has moved once already, out of the source tree.
    readonly property string stateDir: Scheme.stateDir

    // The three the shell calculates. Named here rather than discovered,
    // because unlike the folder these are MODES the code implements: Scheme.qml
    // has a `derivedFromImage`, a `derivedFromColour` and a `derivedNeutral`,
    // and a fourth name in the state folder would be a leftover, not a palette.
    readonly property var derivedNames: ["wallpaper", "custom", "neutral"]

    // One entry per offer: { name, path, derived }. A plain array rather than
    // the FolderListModel itself, because the menu shows more than the folder.
    readonly property var entries: {
        var out = []
        for (var d = 0; d < root.derivedNames.length; d++)
            out.push({ name: root.derivedNames[d],
                       path: root.stateDir + "/" + root.derivedNames[d] + ".json",
                       derived: true })
        for (var i = 0; i < dir.count; i++) {
            var f = String(dir.get(i, "fileName"))
            out.push({ name: f.endsWith(".json") ? f.slice(0, -5) : f,
                       path: String(dir.get(i, "filePath")),
                       derived: false })
        }
        return out
    }

    readonly property int count: root.entries.length
    readonly property bool available: root.count > 0

    // The palette in force right now, by name.
    readonly property string current: Config.theme ? Config.theme.palette : ""

    readonly property int currentIndex: {
        for (var i = 0; i < root.entries.length; i++)
            if (root.entries[i].name === root.current)
                return i
        return 0
    }

    // Choosing writes ONE key, exactly as choosing a wallpaper does. The shell's
    // own colours, GTK, Qt, kitty, btop and niri are all downstream of it, on
    // this start and on the next — see theme/Scheme.qml and services/Theming.qml.
    function choose(name) {
        if (!name || name === Config.theme.palette) return
        Config.theme.palette = String(name)
        Config.save()
    }

    FolderListModel {
        id: dir
        folder: "file://" + root.folder
        nameFilters: ["*.json"]
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Name
    }
}
