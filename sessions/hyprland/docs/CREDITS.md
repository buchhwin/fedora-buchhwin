# Credits

Everything in this repository is MIT (see `LICENSE`) except the files listed
here, which come from somewhere else and carry their own terms.

⚠️ **Rule 10 of this project is "foreign repositories are inspiration, never a
template".** Nothing here is a copied implementation; what is listed is
*artwork* and *data* taken under a licence that permits it, with the notice that
licence requires. Anything that arrives in future gets a row here on the same
day it arrives, not afterwards.

---

## `assets/fonts/BuchhwinFluentIcons.ttf`

A **subset** of Microsoft's **Fluent UI System Icons**, cut down to the
twenty-one glyphs this shell draws.

| | |
|---|---|
| **Upstream** | https://github.com/microsoft/fluentui-system-icons |
| **Licence** | MIT — full text below |
| **What changed** | 9689 glyphs reduced to 21; hinting dropped; the family renamed to `Buchhwin Fluent Icons` |
| **How to reproduce** | `tools/subset-fluent.py`, which names every glyph it keeps |
| **Size** | 5 KB, from 2.81 MB |

⚠️ **Why it is here at all.** He asked for the Windows status symbols in the
notch: *"nimm bitte die windows symbole her"*. The real ones are **Segoe Fluent
Icons**, a Microsoft font that may **not** be redistributed — that was put to him
before anything was built. Fluent UI System Icons is Microsoft's own open set
under MIT: the same design language, freely redistributable. His choice, and the
scope is his too — only WLAN, Ethernet and battery, with the rest of the desktop
staying on Material Icons Round.

⚠️ **The family is renamed on purpose.** Keeping the upstream name would mean two
different fonts called the same thing the moment anybody installs the real one,
with this one shadowing it and most of its glyphs missing.

```
MIT License

Copyright (c) 2020 Microsoft Corporation

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Fetched at install time, not stored here

Both are in `lib/50-fonts.sh` rather than in the tree, because both exist
upstream as files and can be pinned there.

| | |
|---|---|
| **JetBrainsMono Nerd Font** | https://github.com/ryanoasis/nerd-fonts — SIL OFL 1.1 |
| **McMojave-cursors** | https://github.com/vinceliuice/McMojave-cursors — GPL-3.0, pinned to a commit and checked against a SHA-256 |
