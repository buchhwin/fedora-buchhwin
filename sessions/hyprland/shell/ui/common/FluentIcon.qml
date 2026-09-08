// A status symbol in Microsoft's open Fluent set, for the three the notch shows.
//
// ⚠️⚠️ IT EXISTS FOR EXACTLY THREE SYMBOLS AND NOT AS A SECOND ICON SYSTEM. His
// report was about the notch alone — "das symbol, was kommt, wenn man auf die    // english-ok: the report, quoted
// notch drauf hovert, ist echt hässlich, nimm bitte die windows symbole her" —   // english-ok: the report, quoted
// and his answer when asked how far it should go was WLAN, Ethernet and battery
// only. Everything else on this desktop stays on Material Icons Round, which is
// what `common/Icon.qml` draws.
//
// ⚠️ THE REAL WINDOWS FONT IS SEGOE FLUENT ICONS AND WE MAY NOT SHIP IT. That
// was put to him before anything was built. Fluent UI System Icons is
// Microsoft's own open set under MIT — same design language, redistributable.
// docs/CREDITS.md carries the notice, and the file in the tree is a 5 KB subset
// of twenty-one glyphs cut by tools/subset-fluent.py.
//
// ⚠️ AND IT IS A SEPARATE COMPONENT RATHER THAN A `family` PROPERTY ON Icon,
// because tests/icons.sh measures every glyph name against Material Icons Round.
// A second family reached through the same component would walk straight past
// that check — the blind spot that cost B14 — where a type of its own is
// something the checker can find and measure against the right font.
import QtQuick
import "../../theme"

Text {
    property int size: Theme.fontSizeLg

    font.family: Theme.fontFluent
    font.pixelSize: size
    // Icon fonts carry their own metrics; letting Qt hint them moves the shape
    // off the pixel grid at these sizes. Same reasoning as common/Icon.qml.
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
