# The compositor

Hyprland, configured in **Lua**, generated in part and hand-written in part.
This file is about the compositor side; `docs/CONFIG.md` is about the shell's
own settings and `docs/KEYBINDS.md` is the shortcut list.

## Lua, not hyprlang

⚠️ **Hyprland 0.55 replaced hyprlang with Lua** (May 2026). That matters more
than it sounds, and it has already misled one reading of this repository: a
review reported `config/hypr/hyprland.lua` as using an *invented* API, because
`hl.bind`, `hl.window_rule` and `hl.on` look nothing like the `bind = SUPER, …`
lines every guide on the internet still shows. They are the official API. The
guides are older than the release.

The COPR is **`sachesi/hyprland`**, which carries 0.55.4 and above for Fedora 44
— `solopasha/hyprland` is still on 0.49 and could not run this configuration at
all. `lib/30-desktop.sh` enables it.

⚠️ **`Hyprland --verify-config` is the truth, not the documentation.** Field
names cannot be guessed: `blur` is not a window-rule field but `no_blur` is,
`no_border` does not exist but `border_size` does. Before writing one:

```
printf 'hl.window_rule({ name="a", match={class="^x$"}, FIELD = true })\n' > /tmp/p.lua
Hyprland --verify-config --config /tmp/p.lua
```

An invented field there answers `hl.window_rule: unknown field 'FIELD'` and
exits 1. Measured on 0.56.2, against a control that passes.

⚠️⚠️ **There is one thing it does NOT check, and it is worth knowing before you
trust a green run: the OPTION TABLE of `hl.bind`.**

```
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })      config ok
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { invented = true })   config ok
```

Both pass. So `{ mouse = true }` — which the upstream example config uses and
the typed stubs do not mention — being accepted proves only that the file
parses. Whether Hyprland honours it can be answered by exactly one thing:
holding Super and dragging a window on a real session.

Everything else is caught: an unknown top-level function, an unknown dispatcher,
an unknown config key and a Lua syntax error all exit 1 with the line number.
That is why the generator's validate-and-roll-back is worth having — it just
does not cover this one corner.

## What is a file, and what is generated

```
config/hypr/
  hyprland.lua                 the entry point; requires everything below
  buchhwin/env.lua             environment for the session
  buchhwin/monitors.lua        fallbacks, when nothing has been arranged
  buchhwin/input.lua           keyboard and pointer defaults
  buchhwin/look.lua            gaps, borders, blur, shadows
  buchhwin/rules.lua           window and layer rules
  buchhwin/binds.lua           the shipped bindings
  buchhwin/autostart.lua       hl.on("hyprland.start", …)
  generated/settings.lua       ← written from shell.json
  generated/binds.lua          ← written from shell.json
  generated/colors.lua         ← written by the theme renderer
  overrides.lua                yours; loaded last, never touched
```

⚠️ **The generated files are loaded after the shipped ones and before
`overrides.lua`.** So a setting in the shell wins over a default, and anything
you write by hand wins over both. `overrides.lua` is the only file here the
installer will not overwrite.

⚠️ **`hl.exec_cmd` at the top level runs at PARSE time**, not at session start —
there is no Wayland socket yet, so anything started that way fails silently.
Everything that has to start with the session goes inside
`hl.on("hyprland.start", …)`, which is what `buchhwin/autostart.lua` and the
generator both do.

## The generator

`shell/tools/hypr.qml` turns `shell.json` into `generated/settings.lua` and
`generated/binds.lua`. It exists because the settings window would otherwise be
a set of controls that write to a file nothing reads.

⚠️ **This is the piece the migration deleted rather than ported.** For a while
`Theming.applyHyprland()` was three lines that ran `hyprctl reload`, so
rebinding a key updated the settings window and changed nothing at all — the
UI moved, the compositor did not. It is measured now: `tests/rebind.sh`.

Four protections, taken from the generator this replaced:

- **wait for the config to settle** before writing anything;
- **clear the `FileView` path** before reassigning it, because a `FileView`
  hands back what it already holds for a path it already has;
- **compare before writing**, so an unchanged run touches no file and triggers
  no reload;
- **an ABORT protocol** — a target that throws is named, and the others are
  still written.

And one it did not have: **validation**. The generated file is checked with
`Hyprland --verify-config` before it is adopted, and a file the compositor
refuses is rolled back to the previous one. A broken config must never be able
to take the session down.

## The layout is master, not dwindle

`general.layout = "master"`, and that is a precondition rather than a
preference: the bindings are dwl's, and `mfact`, `addmaster` and
`swapwithmaster` are meaningless under a dwindle layout. `docs/KEYBINDS.md`
lists what that buys.

## Layer rules and our own surfaces

The shell's surfaces are layer-shell namespaces — `buchhwin-notch`,
`buchhwin-overlay`, `buchhwin-bar` and the rest — and `buchhwin/rules.lua`
gives each the blur, shadow and animation it should have. ⚠️ **The notch asks
for neither blur nor shadow**: both apply to the whole layer surface, and the
notch's surface spans the screen with the shape drawn inside it, so a blur would
band across the top of the display and cost a full-screen GPU read per frame.

## What is deliberately NOT here

- **No compositor-side keyboard-shortcut overlay of our own.** Hyprland has one
  and the descriptions in `binds` feed it.
- **No screen-recording and no clipboard manager in the compositor.** The shell
  has the clipboard; screenshots go through `buchhwin-screenshot`, the same
  wrapper the dwl session uses — `grim` and `slurp` take them, and `swappy`
  annotates a region shot **if it is installed**, which the profile does install.
  ⚠️ This paragraph said "no screenshot annotation" for a day, which was simply
  untrue: the wrapper has called swappy since it was written.
- **No second network, Bluetooth or account manager**, which is the rule the
  whole profile is built on. See `docs/CONFIG.md`.

## Where to look when something is wrong

```
bhctl doctor                       what is installed, what is missing
Hyprland --verify-config           is the config even loadable
hyprctl -j monitors                what the screens really are
qs -c buchhwin ipc call settings   is the shell listening
journalctl --user -u buchhwin-shell -n 100
```

⚠️ **A palette change that does not arrive is almost always the fingerprint.**
`services/Theming.qml` holds one string of every value a generator reads;
a key that is not in it changes nothing until something else happens to move
the string. That contract has been broken twenty-eight times, which is why
`tests/fingerprint.sh` exists and why it checks both directions.

## The first run on real hardware

⚠️⚠️ **Nothing below has been verified.** The whole test suite runs headless, in
a container or a WSL, and there is no Wayland session there: no compositor, no
SDDM, no radio, no screen. Every check that could be written against a fixture
has been, and `tests/run.sh` names the ones it had to skip — but a green suite
says the code is consistent, not that the desktop comes up.

This is the list, in the order it can be worked through. Nothing here is a
formality; each line is something no check in this repository can answer.

**Before installing anything**

```bash
./install.sh --session hyprland --dry-run
```

It prints the plan and changes nothing. Read it: everything it says it will
touch should be under `~/.config/buchhwin-sessions/hyprland`, plus the packages
it names.

**Installing**

```bash
./install.sh --session hyprland --skip shellenv
```

⚠️ `--skip shellenv` leaves your shell alone on the first run. Add it back once
the session itself works — one new thing at a time is the difference between a
fault you can name and an evening. The session runs without it: `shellenv`
installs five command-line tools and links a zsh config into the session's own
`ZDOTDIR`, and nothing on screen depends on either.

⚠️⚠️ **This line said `--skip base` as well, until 10.09.2026, and that was
install-breaking advice.** It was written when `base` also edited
`/etc/dnf/dnf.conf` and installed a hundred and fifty packages, so skipping it
meant "leave my dnf alone". Those edits are gone and what `base` installs now is
twenty packages the session needs — including **`jq`**, which `bhctl` and
`buchhwin-browser` both refuse to run without and which Fedora KDE does not
ship, and **`dnf-plugins-core`**, without which `dnf copr enable` cannot run at
all. On a Fedora release where Hyprland is not in the base repositories,
skipping `base` means there is no compositor either.

**Then, in order**

1. **SDDM offers "Buchhwin Hyprland"**, and Plasma is still in the list. If the
   entry is missing, the `.desktop` file did not land; if Plasma is missing,
   stop and say so, because that is the fallback.
2. **The session starts.** A black screen with a cursor means the compositor
   came up and the shell did not — `journalctl --user -u buchhwin-shell -n 100`.
3. **The bar and the notch appear.** Only the notch is on by default;
   `bar.enabled` is false.
4. **The keybindings work**, starting with `Super+Return` for a terminal and
   `Super+D` for the launcher. The full list is `docs/KEYBINDS.md`.
5. **Wi-Fi connects from the quick panel** — press the Network tile, pick a
   network, type a password. ⚠️ This is the one that has never run: the panel is
   new, and `tests/netpanel.sh` only proves it draws the right number of rows
   against a fixture.
6. **Bluetooth connects**, the same way, same caveat.
7. **The lock screen** — `Super+L`. Have another way back in ready the first
   time: another TTY, or an SSH session.
8. **A palette change reaches everything.** Open the theme picker
   (`Super+Shift+T`), move to another palette, press Enter. GTK applications,
   Qt applications, Dolphin's file list, the terminal and the compositor's own
   borders should all follow. Dolphin's list is the new part — that is
   `kdeglobals`.
9. **The calendar shows real appointments** (`Super+Shift+K`). If it says "No
   calendars found", set one up in KDE Settings first — this session reads
   KDE's store and adds no account manager of its own.
10. **Plasma still works.** Log out, log into Plasma, and check that its
    colours, fonts and panel are exactly as they were. Everything this session
    writes is under its own config home, and this is where that claim is tested
    rather than argued.

**Going back**

```bash
./uninstall.sh --dry-run     # read it first
./uninstall.sh
```
