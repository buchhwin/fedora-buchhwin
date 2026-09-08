# Palette schema

One JSON file per palette in this directory. Drop a file in and it appears in
the settings window and in `bhctl theme` — neither keeps a list of its own any
more. (There is no `install.sh --flavour`; that was the predecessor's, and
`install.sh -h` lists the four options this one has.)

```json
{
  "name":         "nord",          // must equal the file name without .json
  "family":       "Nord",          // grouping in the settings window
  "display_name": "Nord",          // what the settings window shows
  "dark":         true,            // drives light/dark GTK, Qt and icons
  "accents":      ["blue", "..."], // which of the colours below may be an accent
  "colors":       { ... }          // all 26 keys, "rrggbb" without '#'
}
```

## The 26 colour keys

`rosewater flamingo pink mauve red maroon peach yellow green teal sky sapphire
blue lavender text subtext1 subtext0 overlay2 overlay1 overlay0 surface2
surface1 surface0 base mantle crust`

They come from Catppuccin, which is where this started, but they are **semantic**
here: `mauve` means "this palette's purple accent", not "Catppuccin's mauve".
A family with fewer colours maps several keys onto the same value — Gruvbox has
one purple, so `pink`, `mauve` and `lavender` share it. That is what keeps all
17 templates working for every palette without a single conditional.

Roughly, darkest to lightest on a dark palette:
`crust` < `mantle` < `base` < `surface0..2` < `overlay0..2` < `subtext0..1` < `text`.
On a light palette the order reverses — `base` is the page, `text` is the ink.

## Accents

`accents` exists because they differ per family: Gruvbox has no `mauve`, and a
renderer given an accent its palette does not define has nothing to write. The
settings window offers exactly this list, so it cannot ask for one that will not
render. (The predecessor's `apply-theme.py` was named here; the renderer is
`shell/tools/render.qml`.)

## Nothing here is family-specific any more

The predecessor downloaded Catppuccin-only extras — recoloured Papirus folders,
a Kvantum widget theme, an SDDM theme — and skipped them for every other family.
None of that came across: Kvantum is in no package list, nothing downloads a
folder icon set, and `lib/50-fonts-theme.sh`, which this paragraph used to name,
does not exist (the file is `lib/50-fonts.sh`, and it fetches a font and a
cursor theme, neither of them palette-dependent).

Everything the renderer writes works for every palette, by construction:
`shell/tools/render.qml` reads the 26 names and nothing else.
