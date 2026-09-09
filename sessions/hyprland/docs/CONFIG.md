# shell.json — the one place settings live

`~/.config/buchhwin/shell.json`. Everything else is generated from it: niri's
`config.kdl`, the GTK/Qt/kitty themes, `environment.d`. There is no second
store and no intermediate format.

Every key has a default in `shell/config/Config.qml`. A missing file, a
truncated file or a key that does not exist yet all resolve to the same working
desktop — which is what makes it safe to add settings without a migration.

## Groups

Every group below has a row in the settings window, and `tests/setting-rows.sh`
checks that in both directions — a setting with no row fails, and a row with no
setting fails too. This table used to list eighteen of the twenty-nine, so nine
groups were settable and undocumented.

| Group | What |
|---|---|
| `version` | migration marker; bumped only on a rename or removal |
| `theme` | `palette`, `accent`, `lightPalette`, `customColor` |
| `theming` | which programs we colour, and how — one state each, see below. `vscode` also sets `window.titleBarStyle: native`, which is what removes its title bar |
| `look` | `uiScale` (one number for the size of everything), `rounding`, `borderWidth`, `gapsIn/Out`, opacities, `blur`, `blurPasses`, `shadows`, fonts, `fontSize`, `profile` |
| `surfaces` | `notifications`, `osd`, `wallpaper` — each on its own |
| `notifications` | `dnd` (silences toasts, never critical ones — the quick panel tile counts what it took), `corner` (`topRight`/`topLeft`/`bottomRight`/`bottomLeft`), `timeoutMs`, `maxVisible`, `monitors` |
| `nightlight` | `on` and `temperature` in kelvin — 6500 is neutral, lower is warmer |
| `timer` | `presets` in minutes, `sound`, `soundFile` — the work timer on Mod+Shift+Z (Mod+Shift+T opens the themes) |
| `quick` | `showMore` — the quick panel keeps four tiles out and folds the other six away. Off by default: all ten on one surface was reported as cluttered and too much. The fold lives in the panel itself; the settings row is the same switch reached the long way round |
| `bar` / `notch` / `launcher` | geometry, and a monitor list (empty = all) |
| `dock` | `enabled`, `mode` (`dock`/`taskbar`), `floating`, `position` (`bottom`/`left`/`right`), `size`, `iconSize`, `pinned` (desktop entry ids), `showRunning`, `autohide`, `monitors` |
| `programs` | argument **lists**: `terminal`, `browser`, `fileManager`, `editor`, `imageViewer`, `video` |
| `keys` | `mod`, and **only** `mod` |
| `binds` `rebinds` | ⚠️ **TOP LEVEL, NOT UNDER `keys`**, and this table said otherwise until 10.08.2026. Both are `var` lists, and a `var` inside a nested `JsonObject` is what segfaulted quickshell twice — the note beside them in `Config.qml` spells it out. Rebuilding the schema from the old line would have reproduced that crash. `binds` is `{ key, action, arg, desc }`; `rebinds` is `{ from, to }` overrides, with `to: ""` meaning unbound |
| `input` | `keyboard`, `touchpad`, `mouse`, `focusFollowsMouse`, `warpMouseToFocus` |
| `windows` | `noCsd`, `floating`, `blockFromScreencast` |
| `outputs` | per-monitor overrides; empty = let the compositor decide |
| `autostart` | extra programs — **not** the shell or the clipboard watcher |
| `workspaces` | named workspaces |
| `wallpaper` | `folder`, `current` image, `monitors`, and the slideshow: `slideshow`, `intervalMinutes`, `shuffle`, `slideshowRecolour`, `paletteFrom`. ⚠️ `slideshowRecolour` is OFF by default and that is deliberate — with the palette set to follow the wallpaper, every picture change recalculates all 26 colours and rewrites every foreign application's config (measured: a forest picture gives base `27201b`, a desert one `1b2027`), so a slideshow would repaint the whole desktop on every slide. `paletteFrom` is the pin that keeps the scheme still; choosing a wallpaper by hand clears it |
| `session` | `restore` and `apps`. ⚠️ The PROGRAMS come back, not what was in them — Brave and VS Code restore their own tabs, kitty does not, and nothing outside a program can know what it had open. The list is kept while you work rather than written at shutdown, so it survives a machine that went down without asking, and it is applied once per SESSION rather than once per shell start (the marker lives in `$XDG_RUNTIME_DIR`) |
| `location` | `name` (display only), `lat`, `lon` — set from the quick panel |
| `cursor` | `theme` and `size`. ⚠️ TWO writers need it: niri draws the pointer over the desktop, GTK programs read `org.gnome.desktop.interface` and ignore the compositor. Setting one leaves the other wrong, which shows as a pointer that changes shape at a window edge |
| `gpu` | `renderDevice` — which GPU niri draws with. Empty means niri chooses, which is right everywhere except a hybrid laptop with a monitor on the second card. ⚠️ `Hyprland --verify-config` accepts a device that does not exist; see docs/HYPRLAND.md for the way back out |
| `brightness` | `external` (talk to monitors over DDC/CI at all), `externalLive` (send while dragging, or once on release), `step` |
| `clock` | `format`, `seconds`, `dateFormat`, `weekStart`, `precision` — read by `shell/common/Clock.qml`, which is the single formatter four places used to each have their own copy of |
| `motion` | `speed`, one multiplier over `Theme.durFast/durBase/durSlow` so the RATIO between them survives. It reaches the compositor's own window animations too |
| `media` | `preferred` player, and where the track is shown |
| `lock` | what the lock screen shows: date, avatar, wallpaper |
| `drive` | Google Drive through rclone: `remote` (the name of the rclone remote, default `gdrive`) and `mountPoint`. The mount is a user unit, `buchhwin-drive.service`, and the switch reads `systemctl --user is-active` rather than remembering its own position. `bhctl drive setup` opens the browser sign-in |
| `fetch` | the terminal greeting: `onNewTerminal`. ⚠️ It held four keys until the spinning logo was removed — `spin`, `fps` and `stopAfter` went with the player they configured. fastfetch draws its own builtin logo now |
| `power` | when the screen goes off, locks and suspends — battery and mains kept apart — plus the lid action, the tuned-ppd profile, and the two battery warning thresholds |
| `terminal` | the terminal's own cursor: `cursorShape`, `cursorBlinkInterval`, `cursorTrail`, `scrollbackLines`. ⚠️ Not the same thing as `programs.terminal`, which is WHICH terminal |
| `clipboard` | history length and what is never kept |
| `disks` | `automount` — whether a removable drive is mounted the moment it appears. **Off by default**, and that is a decision: a disk that mounts itself is a disk anything running can write to, and on a machine you carry around "what did that stick just do" is worth being able to answer with "nothing yet" |

## One state per program

```json
"theming": { "enabled": true, "mode": "colour", "kitty": "neutral", "qt": "off" }
```

`mode` is the house rule, and every program follows it unless it says otherwise.
The per-program keys are flat (`"kitty"`, not `"targets": {"kitty": …}`) — two
levels of `JsonObject` do not come back from the file, so the block would parse
and every switch would silently do nothing.

| State | What it means |
|---|---|
| `colour` | the system's colours, whatever `theme.palette` says |
| `neutral` | a grey scheme: themed, but colourless. **Colourless, not unstyled** — transparency, fonts and corners stay, and red, green and yellow stay coloured, because an error has to read as an error in a grey scheme too |
| `off` | we take our file back: it is left in place as a stub that overrides nothing, so the `include` that reads it does not point at nothing |
| `inherit` | follow `mode` — the default, so switching everything at once is one edit rather than twelve |

`enabled: false` is the master switch: every program behaves as `off`, files and
all. Setting it back to `true` fills them again — `off` is not a one-way door.

### ⚠️ Two of them can be undone by the program's own update

Thirteen of the targets read a file we write and nothing else touches it.
`vesktop` and `spicetify` colour a program whose files we do not own, and that
costs something the other thirteen do not. It was chosen with that on the table,
and it is written here rather than carried quietly.

| | |
|---|---|
| **`vesktop`** (Discord) | The theme is a CSS file in `~/.var/app/dev.vencord.Vesktop/config/vesktop/themes/`. ⚠️ **It has to be ticked once** under Settings → Themes: Vencord is downloaded by Vesktop at first start, so the list of enabled themes does not exist until you have logged in. After that it sticks |
| **`spicetify`** (Spotify) | The colours are `~/.config/spicetify/Themes/buchhwin/color.ini`, injected into Spotify's own bundle by the spicetify binary. ⚠️ **A Spotify update replaces the patched files and the theming is gone.** `bhctl theme spotify` renders and re-injects, in that order |

⚠️ **Discord is `dev.vencord.Vesktop`, not `com.discordapp.Discord`**, and that
was measured rather than preferred: the Discord flatpak's `app.asar` is
root-owned with a link count of 2, so it is hardlinked into OSTree's object
store — patching it in place rewrites a shared object, and an update would throw
the patch away anyway. Vesktop is Discord with Vencord already in it.

⚠️ **Spotify is installed as a `--user` flatpak** so spicetify can write without
root. In a system install the directory it has to patch is root-owned, which
would mean a theming step that only `sudo install.sh` could ever repeat.

⚠️ **`off` for `gtk` is visible, and that is the point.** Theme name, icon theme,
font and `gtk-decoration-layout=:` all come out of the same generated file, so a
GTK window gets its three title-bar buttons back and turns light. That is what
"the way it would look without us" means here.

### What each program gets, and what points at it

| Key | Generated file | What names it |
|---|---|---|
| `gtk` | `gtk-3.0/gtk.css`, `gtk-4.0/gtk.css` + both `settings.ini` | nothing — GTK reads them itself |
| `qt` | `qt6ct/colors/buchhwin.conf` | `color_scheme_path` in `qt6ct.conf` |
| `kitty` | `kitty/theme.conf` | `include theme.conf` in `kitty.conf` |
| `niri` | `niri/colors.kdl` | `include optional=true` in the generated `config.kdl` |
| `btop` | `btop/themes/buchhwin.theme` (37 keys) | `color_theme = "buchhwin"` in `btop.conf` |
| `alacritty` | `alacritty/buchhwin.toml` | `[general] import` in `alacritty.toml` |
| `tmux` | `tmux/buchhwin.conf` | `source-file` in `tmux.conf` |
| `bat` | `bat/themes/buchhwin.tmTheme` | `--theme` in `bat/config` **plus `bat cache --build`** |
| `delta` | `git/buchhwin-delta.gitconfig` | `[include]` in `~/.config/git/config` |
| `lazygit` | `lazygit/buchhwin.yml` | `LG_CONFIG_FILE` in `environment.d` |

Every pointer is seeded once by the installer and never edited again. If one of
these files already exists without its pointer, the installer says so rather
than reaching into it — and `bhctl doctor` keeps saying so.

⚠️ **bat is the one with two steps.** A `.tmTheme` in the right folder is
invisible to bat until `bat cache --build` compiles it. The renderer runs that
itself, and only when the theme actually changed.

⚠️ **`delta` is written into `~/.config/git/config`, never into `~/.gitconfig`.**
Git reads both global files, so the include takes effect while a hand-written
`~/.gitconfig` stays exactly as it was.

**`fastfetch` and `starship` have no file of their own**, and that is not an
omission: neither program has any include mechanism — each reads a single
config file that belongs to you. Their colours come from the terminal's sixteen
ANSI colours, which the kitty and alacritty themes above already set, so they
follow the palette without us writing anything. The renderer says so on every
run.

**Only our own files are ever touched.** `kitty.conf`, `qt6ct.conf`, `btop.conf`
and `~/.gitconfig` belong to you; the pointer lines in them are seeded once by
the installer and never edited afterwards, not even by `off`.

## The dock, and why its surface is the whole edge

Three shapes out of two switches: `mode` says how long it is (`dock` = as long
as its contents, `taskbar` = the full edge, and only the taskbar reserves space
so windows tile up to it), `floating` says whether it is detached from the edge.
`position` picks the edge. The default is a floating dock centred at the bottom
with `autohide` off.

⚠️ **The layer surface spans the entire edge and never changes size**, whatever
mode it is in — the strip is drawn inside it. That is not tidiness. A
`PanelWindow` sized by its contents re-measures the Wayland surface every time
the contents change, and a dock's contents change every time a program opens;
the notch was built that way once and it was reported as "everything wobbles
from left to right". `tests/motion.sh` fails a surface whose size comes from a
child.

⚠️ **Therefore the dock asks niri for no blur and no shadow.** Both apply to the
whole layer surface, so on a full-width surface they would band across the
screen and cost a full-screen GPU read per frame. The strip paints its own
opaque background instead, exactly as the notch does. The input region is masked
to the strip, so the empty part of the surface swallows no clicks.

`pinned` holds **desktop entry ids** (`org.gnome.Nautilus`), not binaries: an id
is stable where a name is a translation. A pin for something that is not
installed stays visible rather than disappearing, and window matching is done on
the last dotted component, lower-cased, because an `app_id` and an entry id
agree often enough to look identical and then do not.

## The launcher

```json
"launcher": { "enabled": true, "width": 720, "height": 460, "monitors": [] }
```

`Super+D` or `Super+Space`. Type to search, arrow keys to move, Enter to start,
Escape to close; Tab steps through the categories without leaving the keyboard.

⚠️ **It is the one surface that opens in the MIDDLE of the screen**, and the only
one that leaves the notch where it is — everything else opens at the notch, and
the notch steps aside for it. That is why it is not a notch page and has its own
ipc target: `qs -c buchhwin ipc call launcher toggle`.

A fixed size, unlike the notch pages: those are as big as their content because
their content is short, and a program list is not. A launcher that changes shape
while you type is a moving target.

**Where the list comes from.** Quickshell's `DesktopEntries` — the same
freedesktop database every desktop reads, so a newly installed program appears
without anything being rescanned. Three things are dropped or ignored, each of
them a fault the predecessor had: `NoDisplay=true` entries (they exist to own a
MIME type, not to be picked), `Actions` (one program is one row — listing them
turned Evolution into twenty lines), and everything in `Categories` that is not
a freedesktop **main** category, first match winning. `GTK`, `Qt`, `KDE` and
`X-*` are not categories, however often they appear in that field.

A program whose categories say nothing usable lands in **Other**, and a category
with nothing in it is never offered.

**Frequent** counts what you start from here, in
`~/.local/state/buchhwin/app-usage.json`. It is data rather than a setting, so
it is deliberately not in `shell.json` — and writing it there would mean
rewriting your whole configuration every time you started a program.

## The wallpaper, and what survives a restart

```json
"theme":     { "palette": "wallpaper", "accent": "blue" },
"wallpaper": { "folder": "~/Pictures/Wallpaper",
               "current": "file:///home/USER/Pictures/Wallpaper/Lake_Color1.png" }
```

**`wallpaper.current` is the only thing that is remembered**, and it is written
the moment you choose an image (`Super+Shift+W`, or `bhctl wallpaper <file>`).
Everything else is downstream of it:

- `theme.palette` set to **`"wallpaper"`** means the colour scheme is derived
  from that image. **There is no second switch** — a `wallpaper.derive` key
  existed until config version 1 and was removed, because two keys for one
  decision can disagree.
- The derived scheme is cached in `shell/theme/palettes/wallpaper.json`, an
  ordinary palette file with one extra field, `source`. On the next start the
  colours load from there instantly; the image is only read again when `source`
  no longer matches `wallpaper.current`. The file is generated, never committed.
- A wallpaper that cannot be decoded is **refused** and the previous scheme
  stays. An unreadable desktop is worse than one that did not change — and much
  worse if it comes back that way after every restart.
- Light or dark is yours, not the image's: a bright photo does not turn a dark
  desktop light. The image supplies hue, nothing else. **Meaning colours stay
  put** — error is red on a forest wallpaper too. An image with no colour in it
  yields a grey scheme rather than an invented one.

Wallpapers are **not** in this repository — they are photographs and this
repository is public. `install.sh --wallpapers <dir>` copies them to
`~/Bilder/Wallpaper`; without it the installer falls back to
`/usr/share/backgrounds`, and with no images anywhere it seeds Everforest Dark.

## Defaults worth knowing

**Only the notch is on by default.** `bar.enabled` is `false`, and `dock.enabled`
is `false` too — ⚠️ the dock EXISTS (this same file describes it above); it is
switched off, which is a different sentence and used to read "there is no dock at all
yet. The notch is the surface, not an ornament — so anything the bar would have
carried needs a key and an ipc verb as well, or it is unreachable.

**`look.profile: "minimal"`** is the one switch that turns the expensive things
off everywhere: `blur { off }`, no shadows, shorter motion. It is the first
thing to reach for on a slow machine, ahead of tuning individual effects.

**`look.blurPasses`** is the most expensive single number in the desktop —
every pass is another full-screen GPU read per frame.

## Programs are argument lists, not command lines

```json
"programs": { "terminal": ["kitty", "-e", "fish"] }
```

niri's `spawn` takes one string per argument. A single `"kitty -e fish"` makes
it look for a binary with spaces in its name. A binding refers to a program as
`"@terminal"`, so changing your terminal is one edit rather than a hunt through
the bindings. An **empty** list means the binding is dropped entirely — better
than a key that looks like a feature and does nothing.

## Migrations

`shell/config/Migrations.qml`. Adding a key needs nothing; renaming or removing
one needs a step, because the old name is already in somebody's file.

The chain runs on the **raw JSON**, deliberately: `JsonAdapter` drops every key
it does not declare, so by the time the adapter has parsed the file the old
field it exists to rescue is already gone. A config written by a *newer* build
is refused rather than downgraded by guesswork.

## Two traps in the QML

**`Array.isArray()` says `false`** for a list that came out of `JsonAdapter` —
it is a QJSValue wrapper, not a JS array. Use `.length` and indexing.

**`FileView.loaded` is not "the values are here".** It turns true one event-loop
step before the adapter applies them, so a one-shot read in the same tick
returns the defaults — silently. That deferral lives in `common/WaitFor.qml`;
wait on it rather than on `loaded`.

## The calendar, and Google

Appointments come from your Google account over CalDAV, using the account that
lives in `gnome-online-accounts` — the same one that puts Google Drive in
Nautilus. There is deliberately **no setting for it in `shell.json`**: the
account IS the setting.

```
gnome-online-accounts-gtk        # add the account, switch the calendar on
bhctl calendar                   # check that it arrived
```

`Super+C` shows the month. A dot under a day means something is on; the
appointments of the day you tap are listed under the grid. The **+** creates one
— on the day you are looking at, not on today.

**What is written here goes to Google, and therefore to your phone.** This is
real CalDAV, not a local scratch copy.

### Why not evolution-data-server

EDS is the usual route. It was measured and it cannot work from here: EDS ties
an opened calendar to the **calling D-Bus connection**, and since Quickshell
ships no DBus module the only door is `busctl` — where every invocation is a new
connection, so the object is gone before it can be queried
(`Object does not exist at path …`). Rescuing that would take a permanently
running helper in C, with a build step. GOA hands out a token in **one** short
call instead, and Google's CalDAV endpoint is already baked into GOA. The
difference is 32 packages and a build system.

### Limits, stated plainly

- **Time zones come from the `VTIMEZONE` inside the appointment**, not from the
  system. Quickshell's JS engine has **no `Intl`** — measured, `typeof Intl` is
  `undefined` — so there is no way to ask what offset a named zone had on a
  given day. Reading VTIMEZONE has the side benefit of not depending on this
  machine's zone database agreeing with Google's.
- **Recurrences** are expanded for `FREQ=DAILY|WEEKLY|MONTHLY|YEARLY` with
  `INTERVAL`, `COUNT`, `UNTIL` and `BYDAY`, plus `EXDATE` and moved instances.
  Anything more exotic (`BYSETPOS`, `BYWEEKNO`) is **not** expanded rather than
  half-guessed.
- No invitations, no attendees, no reminders, no attachments.
- **No offline queue.** With no network the page says so. Collecting changes to
  send later is the worse promise.

### ⚠️ The transport is `curl`, and the account still has to be reconnected

There were two walls and only one is down.

**Down (10.08.2026):** QML's `XMLHttpRequest` has no `REPORT` method —
`open("REPORT", …)` throws "Unsupported HTTP method type" — and REPORT is the
only way CalDAV asks for events. So the calendar could never have fetched an
appointment however good the token was, and `PUT`/`DELETE` had the same ceiling.
Every request now goes through `curl`, measured against a real server.

⚠️ **The token never touches a command line.** It is a bearer credential and
`/proc/<pid>/cmdline` is world-readable, so the whole request — headers and body
— is fed to `curl --config -` on standard input. `tests/caldav-transport.sh`
measures that with a control that can fail: the same token passed as `-H` is
found in argv, passed through the config it is not.

**⚠️ Still standing, and only you can take it down:** the Google token carries
**no calendar scope**. `bhctl calendar` prints exactly `email, profile,
userinfo.email, userinfo.profile, openid`, so Google answers 403 — the correct
answer to the question being asked. **Remove the account in Online Accounts and
add it again with Calendar ticked.** Until then every surface that asks says the
403 on screen rather than showing an empty month.


## The notch has three states

It used to BECOME each page. It does not any more — a calendar is not a notch
that got bigger. The pages float below it (`buchhwin-overlay`) and the notch
gets out of the way:

| State | When | What you see |
|---|---|---|
| full | resting | the pill with the clock |
| hidden | a page is open at the notch | nothing — the page has the stage |
| strip | the focused window is fullscreen | a hairline at the top; **hover it for the full notch** |

Two things had to be measured for this, and both are worth knowing:

- **niri does not report `is_fullscreen`.** The only signal is the size, and it
  arrives in the `WindowLayoutsChanged` event: a fullscreen window's
  `window_size` is exactly the output's logical size. The honest limit is that
  with `gaps 0` and no reserved strip an ordinary tiled window would measure the
  same — with the shipped defaults it cannot.
- **A fullscreen window is drawn above the `top` layer.** The strip was not
  mis-sized, it was simply not on screen. The notch moves to `overlay` while
  fullscreen and back afterwards, which is also why the strip is a hairline: it
  is the one thing allowed over a fullscreen video.

## Shadows, blur, and one rule that explains both

From niri's own layer-rule documentation:

> niri has no way of knowing about invisible margins, and will draw the shadow
> behind the **entire surface**.

Blur behaves the same. So **every surface this shell creates is exactly the size
of what it draws** — the notch used to carry a transparent border for its
shoulders, and that border came back as a blurred, colour-fringed halo around
the pill.

- `look.shadowSoftness` / `shadowSpread` / `shadowOffsetY` are CSS box-shadow
  semantics and apply to **windows and to our own surfaces alike**, so nothing
  floats at a different height from anything else.
- Layer surfaces need their shadow enabled **per rule** — the `layout` section
  does not reach them.
- `windows.blurred` lists the applications that get the wallpaper blurred behind
  them. ⚠️ Blur is only visible where a window is **translucent**; an opaque one
  covers it completely and the GPU work is wasted. niri turns on *xray*
  alongside blur, which blurs the wallpaper once and reuses it rather than
  recomputing per window per frame — that is what makes this affordable on a
  battery.
- **No blur behind the notch.** It is near-black and opaque: there was never
  anything to see through it.
