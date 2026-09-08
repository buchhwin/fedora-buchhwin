// A program's own icon, from the icon theme — the one place in this shell
// where an icon is a picture rather than a glyph.
//
// ⚠️ AND IT IS THE EXCEPTION, NOT A NEW RULE. common/Icon.qml argues for an
// icon font, and that argument stands for everything the shell draws itself: a
// glyph inherits the palette, so it can never be the one element that did not
// follow a theme change. A program's icon is different in kind — it is Firefox's
// own mark, not our decoration, and recolouring it would make it unrecognisable.
//
// Quickshell.iconPath() resolves a freedesktop icon name against the current
// icon theme (Papirus here, installed by packages/dnf-desktop.txt). Two things
// it does not do: guarantee the name exists, or invent one when the .desktop
// file has none. Both are ordinary — a program with no icon is not broken — so
// the fallback is a glyph and the first letter, never an empty box.
import QtQuick
import Quickshell
// ⚠️ Through our own singleton, not `Quickshell.Services.*` — the rule
// tests/ui-imports.sh holds shut. Apps owns DesktopEntries and the index built
// from it; a second reader here would be a second source of truth.
import "../../services" as Services
import "../../theme"

Item {
    id: root

    // The freedesktop icon name out of the .desktop file, possibly empty.
    property string source: ""
    // The program's name, for the initial in the fallback.
    property string appName: ""
    property int size: Theme.fontSizeXl

    implicitWidth: size
    implicitHeight: size

    // ⚠️⚠️ THE .desktop ENTRY FIRST, THE NAME ONLY AS A FALLBACK — and getting
    // that order wrong is what he reported: every window in the Super+Tab card
    // drawn as a circle with a letter in it, instead of its own icon.
    // This used to ask the icon theme for the compositor's `app_id`
    // directly, which is not an icon name and only happens to agree for some
    // programs. Measured over the twenty this desktop ships: the .desktop route
    // answers for fifteen, the old route for one that it did not already cover.
    //
    // The lookup itself is an index in Services.Apps — see the note there for
    // why it is three maps and why it is not a scan per tile.
    //
    // ⚠️ Asked before it is used, in both branches. `iconPath()` on an unknown
    // name returns an empty string and Image would then draw nothing with no
    // error — the same silent-empty failure as a missing glyph, and the reason
    // tests/icons.sh exists for the font side.
    readonly property string resolved: {
        if (!root.source.length)
            return ""
        var name = Services.Apps.iconFor(root.source)
        // ⚠️ AN ABSOLUTE PATH IS A VALID `Icon=` VALUE and a handful of
        // programs ship one. Handing it to hasThemeIcon() asks the icon theme
        // for a file name, which is always no — so the picture would vanish for
        // exactly the programs that told us precisely where it is.
        if (name.length && name.charAt(0) === "/")
            return "file://" + name
        if (name.length && Quickshell.hasThemeIcon(name))
            return Quickshell.iconPath(name)
        // Nothing claimed the app_id: try it as an icon name after all. Our own
        // windows (`org.quickshell`) are the case this still catches.
        if (Quickshell.hasThemeIcon(root.source))
            return Quickshell.iconPath(root.source)
        return ""
    }

    Image {
        anchors.fill: parent
        visible: root.resolved.length > 0
        source: root.resolved
        // Decode at the size actually drawn. A 512-pixel PNG scaled into 28
        // logical pixels costs the full decode and the memory of the original,
        // for every program in the list at once.
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        cache: true
    }

    // No icon: the first letter on a plain tile. Recognisable enough to tell
    // two rows apart, and honest about being a stand-in.
    Rectangle {
        anchors.fill: parent
        visible: root.resolved.length === 0
        radius: Theme.radiusSm
        color: Theme.surfaceHigh

        Text {
            anchors.centerIn: parent
            text: root.appName.length ? root.appName.charAt(0).toUpperCase() : "?"
            font.family: Theme.fontUi
            font.pixelSize: Math.round(root.size * 0.55)
            font.weight: Theme.weightSemibold
            color: Theme.fgMuted
        }
    }
}
