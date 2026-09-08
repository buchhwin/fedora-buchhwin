# The generated niri configuration

`~/.config/niri/config.kdl` is **generated**. Editing it edits a file that is
overwritten the next time a setting changes. The source is
`~/.config/buchhwin/shell.json`; the generator is `shell/tools/niri.qml`.

```
~/.config/buchhwin/shell.json     you edit this
        │
        ├── tools/niri.qml   ──▶  ~/.config/niri/config.kdl
        │                    ──▶  ~/.config/environment.d/50-buchhwin.conf
        └── tools/render.qml ──▶  ~/.config/niri/colors.kdl   (colours only)
                             ──▶  gtk-3.0, gtk-4.0, kitty, qt6ct
```

Regenerate with `bhctl niri apply`. See what would change with `bhctl niri diff`.

## Why two files

`config.kdl` includes `colors.kdl`, so switching palette rewrites the colours
and leaves the keybindings untouched. Three rules make that split work, all
taken from niri's own documentation:

* `include` is **top level only** and **positional** — what comes *after* an
  include overrides it. The include therefore sits after our `layout` block.
* Sections **merge property by property**, so a colours file that sets only
  `border { active-color … }` does not disturb `gaps` or `width`.
* ⚠️ `layout { border {} }` means "enable the border" in the main config and
  **nothing at all** in an included file. Visibility (`on`/`off`/`width`) is
  therefore written **only** into `config.kdl`, and `colors.kdl` carries
  colours and nothing else.

## What is deliberately not generated

**No `spawn-at-startup` for our own shell.** The shell and the clipboard
watcher are systemd user units under `graphical-session.target`. Listing them
here as well would start a second copy of each — which is exactly what Fedora's
shipped niri config does with waybar.

**No colours.** See above.

## The `debug` block, and the one setting that can stop niri from starting

`gpu.renderDevice` is the only key in `shell.json` that generates a `debug {}`
block, and it is empty by default. Set, it writes:

```kdl
debug {
    render-drm-device "/dev/dri/by-path/pci-0000:01:00.0-render"
}
```

**What it is for.** On a hybrid laptop the external display sockets are usually
wired to the discrete GPU. niri renders on the integrated one and copies each
frame across for that screen, which costs frames — niri's own `FAQ.md:43-55`
names both the effect and this remedy. It also costs battery, because the card
named here then never idles. That is why the default is *let niri choose*.

**An empty value writes no block at all**, not an empty one. `debug` is a
section niri documents as unsupported and subject to change; sitting inside it
on every machine that has no opinion would be a standing risk taken for nothing.

### ⚠️ If niri does not start after setting it

`niri validate` **cannot** catch a bad value here. Measured on niri 26.04 with
two controls: an invented key inside the block *is* rejected, so the name is
real — but a device path that does not exist validates perfectly happily. A
config that parses is therefore not the same as a compositor that can start.

The way out, from a TTY (`Ctrl+Alt+F3`):

```sh
# clear the key, then regenerate
sed -i 's|"renderDevice": *"[^"]*"|"renderDevice": ""|' ~/.config/buchhwin/shell.json
bhctl niri apply
```

The settings row is a **closed list** built from the render nodes this machine
actually has — every entry in it is a device that exists and whose driver is
loaded, so the failure above cannot be reached from the window. Editing
`shell.json` by hand can still reach it, and so can moving the settings file to
a different machine.

`bhctl doctor` prints the same list with each device's driver beside it, which
is also how to find the right value over SSH.

## Environment variables are written twice, on purpose

niri's `environment {}` block does **not** reach the systemd and D-Bus
activation environment. Our shell runs as a systemd user unit, and every
program launched from it is its child — so a variable set only in `config.kdl`
would never reach them. The same list is therefore also written to
`~/.config/environment.d/50-buchhwin.conf`, which the systemd user manager
reads at login.

⚠️ `GDK_BACKEND` is deliberately **not** among them. From niri's documentation:
*"Do not set the `GDK_BACKEND` environment variable globally as this will break
the screencast portal."* GTK applications choose Wayland by themselves here.

## No window buttons — what that does and does not mean

| Toolkit | How |
|---|---|
| niri | `prefer-no-csd`, `border { off }`, `focus-ring { off }` |
| GTK 3 / GTK 4 / libadwaita | `gtk-decoration-layout=:` in the generated `settings.ini` |
| Qt | `QT_WAYLAND_DISABLE_WINDOWDECORATION=1` |
| Electron | `--ozone-platform=wayland` flags in `~/.config/*-flags.conf` |

**The header bar itself stays.** In a libadwaita application the header bar is
application *content*, not decoration: minimise, maximise and close disappear,
while search fields and path bars remain. No setting removes it, and pretending
otherwise would be a promise the desktop cannot keep.

## Keys

Every binding is generated from `keys.binds` in `shell.json`. They live in the
compositor rather than in the shell because niri has no protocol for
shell-owned shortcuts — which also means **they keep working when the shell is
dead**. Two are reserved for exactly that case:

| Key | Action |
|---|---|
| `Super+Shift+Return` | terminal |
| `Super+Ctrl+Shift+R` | restart the shell unit |

### Changed compared with the Hyprland predecessor

niri is scrolling column tiling. Four groups of keys had no equivalent and were
remapped to the nearest real meaning rather than silently dropped:

| Key | Was (Hyprland) | Now (niri) |
|---|---|---|
| `Super+Ctrl+←/→` | snap to left/right half | column narrower / wider (±10 %) |
| `Super+Ctrl+↑` | snap maximise | `maximize-column` |
| `Super+Ctrl+↓` | snap restore | cycle preset column widths |
| `Super+Shift+J/K` | toggle split direction | consume / expel window from column |
| `Super+P` | pin window | toggle floating |
| `Super+Ö` | scratchpad | focus the named workspace `scratch` |

Also different from the predecessor: `Super+arrow` moves **focus** and
`Super+Shift+arrow` moves the **window**, following niri's own convention.

**Minimising does not exist** in niri. Workspaces and the overview replace it.

### Reaching the island

Every page has a key, without exception — the bar is **off** in the default
setup, so a page you could only click on the bar would not be reachable at all.

| Key | What |
|---|---|
| `Super+M` | media |
| `Super+N` | notifications |
| `Super+,` | quick settings |
| `Super+C` | calendar |
| `Super+Shift+N` | new appointment |
| `Super+T` | the system tray |
| `Super+Shift+E` | the session menu — lock, suspend, log out, restart, shut down |
| `Super+Ctrl+L` | lock straight away |
| `Super+Shift+W` | choose a wallpaper |
| `Super+Escape` | close the island |

⚠️ **`Super+Shift+E` used to be niri's `quit`, directly.** One keystroke, no
question, every unsaved thing gone. It opens the session menu now, and the menu
asks before anything irreversible — the second press is the feature, not the
list of buttons. Locking and suspending skip the question because both are
reversible, and a question people learn to dismiss without reading is what makes
the shutdown question useless too.

⚠️ **Lock is `Super+Ctrl+L`, not `Super+L`.** `Super+L` is already
focus-column-right in the vim group, and niri silently takes the last binding
for a key — so a duplicate is a shortcut that quietly stopped working.
`tests/niri-config.sh` fails on one now.

⚠️ **The brightness keys run `brightnessctl` first and tell the shell second**,
joined with `;` rather than `&&`. The screen has to brighten even when the shell
is dead, which is the one moment when not seeing the screen is worst.

⚠️ **Tray menus need a window to open against.** With the bar off, that window
is the island's own — which is why the tray page is a page and not a popup. If
you switch the notch off *and* the bar off, there is no tray at all, and that is
the honest consequence rather than a bug.

⚠️ These go through the shell's ipc socket, and `qs ipc call` takes **no
arguments** in quickshell 0.2.1 — `qs ipc show` lists `show(page: string)`
happily, but calling it with a page answers "The following argument was not
expected". So each page is its own parameterless verb:

```
qs -c buchhwin ipc call notch media
qs -c buchhwin ipc call notch collapse
```

`Super+M` was the predecessor's power menu. Nothing had to move in the end: the
session menu took `Super+Shift+E`, the key that used to log you out without
asking.

### The launcher, and the key that used to be missing

`programs.launcher` is gone. It was an empty argument list waiting to be filled
with the name of some other launcher, and the generator dropped the binding
rather than write a key that did nothing. The shell has its own launcher now, so
the key points at the shell instead of at a program:

    Super+D      qs -c buchhwin ipc call launcher toggle
    Super+Space  the same thing

Two keys for one surface, on purpose: `Super+D` is what niri's own default
config binds a launcher to, and `Super+Space` is what somebody coming from a Mac
will press. Neither is used for anything else.

## Traps that cost a debugging round

* **`spawn` takes one string per argument.** `spawn "kitty -e fish"` makes niri
  look for a binary with spaces in its name. Commands are argument *lists*
  everywhere in `shell.json`.
* **On the top level the node is `spawn-sh-at-startup`**, not `spawn-sh` —
  `spawn-sh` is a bind action. The wrong one is rejected outright, and a config
  that does not parse means a desktop with **no keys at all**.
* **libinput flags reject `false`.** `natural-scroll false` is a hard error,
  unlike most other niri flags. The generator omits a flag rather than writing
  it false.
* **KDL needs a terminator.** `layout { gaps 16 }` on one line fails; anything
  inline gets a `;`.
* **`binds {}` is not defaulted.** Leave it out and the desktop has zero
  keybindings — and `niri validate` still says the config is valid.
* **`niri validate` exits 0 on warnings.** Deprecated keys and out-of-range
  values pass silently, which is why `tests/niri-config.sh` also greps stderr.
* **niri writes its own default config if none exists** — the one that starts
  waybar. The installer must generate ours before the first login.

## What niri can do that we have never made a setting

⚠️ **The whole niri manual is on the machine**, and this section exists because
nobody had read it against our schema. `/usr/share/doc/niri/wiki/` carries a page
per configuration area, and `/usr/share/doc/niri/default-config.kdl` is the
tuned starting point its author ships. Both are better sources than memory, and
they are why the animations section stopped restating what niri already knew.

The question worth asking is not "which key is missing from our schema" —
`tests/setting-rows.sh` already proves every key has a row. It is **which
capability of niri we never turned into a key at all.** Held against the wiki's
own list of sections, we generate: animations, binds, debug, environment, input,
layout, layer-rules, misc, outputs, window-rules, workspaces.

Four areas are untouched:

| niri section | what it is | worth having? |
|---|---|---|
| **`switch-events`** | `lid-close`, `lid-open`, `tablet-mode-on/off` → run a command. **Executed even while the session is locked.** | ⚠️ **Yes, and it changes the Power page.** See below |
| `gestures` | `hot-corners` (which corners, or `off`), `dnd-edge-view-scroll`, `dnd-edge-workspace-switch` with `trigger-width`, `delay-ms`, `max-speed` | Probably. We have our own hot corners in the shell, so the two need reconciling rather than adding blindly |
| `overview` | zoom level, backdrop colour, workspace shadow | Cosmetic, and it is a surface he has not asked about |
| `recent-windows` | the Alt-Tab-style switcher's own settings | Only if we bind it |

### ⚠️ `switch-events` is a better home for the lid than logind

The Power page currently sends the lid through
`/etc/systemd/logind.conf.d/50-buchhwin.conf`, written by `bhctl power apply`.
That works, and it has two costs: it needs root, and it only takes effect after a
reboot or a logind restart.

niri can do it itself:

```kdl
switch-events {
    lid-close { spawn "systemctl" "suspend"; }
    lid-open  { spawn "true"; }
}
```

Which would make the lid setting behave like every other setting — regenerate
`config.kdl` and it is live, no password, no reboot.

Three things to know before building it:

1. **Only `spawn` is supported**, not `spawn-sh`. Anything conditional has to be
   spelled `spawn "sh" "-c" "…"` by hand.
2. **niri cannot tell mains from battery**, and our schema keeps those apart on
   purpose. The spawned command would have to ask — which is what the `sh -c`
   form is for.
3. ⚠️ **logind would still act too.** Its default is `HandleLidSwitch=suspend`,
   so without setting it to `ignore` the lid would be handled twice. That is
   still one `/etc` write — but **once**, instead of on every change.

So the shape is: logind gets `ignore` at install time, and the behaviour itself
lives in `config.kdl` where a settings change can reach it. The current design is
not wrong, it is just the version that pays root on every change instead of once.
