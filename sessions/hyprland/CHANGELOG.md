# Changelog

## v0.2.0-alpha — 10.08.2026

The alpha named five things as unfinished. Four are done, one is his to do. On
top of that, six parallel reviews went through the code, the shell scripts, the
look, the documentation and the test suite itself — and a fresh machine was
installed from nothing, which found something no test did for the fourth time.

### ⚠️⚠️ Nothing private is in this repository any more

The history carried a home town and its coordinates through 170 commits, a
plain-text password for the lab VM through 41, a hypervisor address, a test-VM
address, a hostname and a home path. All of it is gone from the working tree and
from every commit; `tests/no-secrets.sh` runs in CI and can go red.

The old guard had four patterns and holes in all of them — `/home/[a-z]+/`
needed a trailing slash, so the very line that leaked walked past it. The new
one lives in the repository, so it can be read, argued with and run before a
push.

⚠️ **A published password is a burnt password.** The lab credentials were
changed rather than only deleted, and the test VM now gets a random one that
appears nowhere.

### The faults that were found

| | |
|---|---|
| **`bhctl greeter enable` had lost its refusal** | `bin/bhctl` called `die`, `warn` and `ok` twenty-one times and defined none of them. Without `set -e` each was a `command not found` that the script walked past — so the one command that can leave a machine nobody can log into disabled sddm, enabled greetd and exited 0 on a machine where the greeter had never been tested |
| **Every settings change wrote the file twice** | `location.lat/lon` defaulted to `NaN`, JSON has no NaN, the adapter wrote `null`, the migration read those nulls as damage and rewrote the file. 31 warnings a boot, and `nulledKeys` permanently reporting damage this file had just invented |
| **Two search boxes could not receive a keystroke** | the emoji picker and the task manager were never added to the keyboard whitelist, so their fields and their Escape handlers were unreachable |
| **Half the Super+Tab card was invisible** | an unfocused tile was drawn in exactly the colour of the box behind it — measured at 1.000:1 |
| **The window icons were not icons** | `AppIcon` asked the icon theme for the compositor's `app_id`, which answers for nine of the twenty programs here. It goes through the `.desktop` entry now — fifteen — which fixes the switcher, the dock and the task manager at once |
| **Two icons drew nothing at all** | `bolt` and `balance` are not in Material Icons Round, so the power tile had no icon in its DEFAULT profile. `tests/icons.sh` said "all 86 resolve" because both sat on the continuation lines of a ternary it never read |
| **HEIC could not be opened** | Fedora's libheif ships no decoders; every phone photo was a file nothing could open |
| **ffmpeg would not install on a clean machine** | RPM Fusion's package conflicts with Fedora's `libswscale-free`, which is already there as a dependency. Found by installing from nothing, which is why that is a step and not a formality |

### What he asked for while it was being built

- **Our own surfaces can be plain black and opaque** (`look.surfaceStyle`, and
  black is the default). The notch, the quick settings, the settings window, the
  launcher, the dock and the toasts. ⚠️ Applications are structurally outside it:
  their themes are written from the palette by `tools/render.qml`, which never
  reads the shell's tokens. ⚠️ And black is the BACKGROUND, not every surface —
  the elevation ladder stays, because a sweep the same day found eight places
  where an element already had exactly its parent's colour.
- **The Motion page he drew**: reduce motion, movement, fades and colour, hover
  response, bounce. Migration 14 → 15 turns an existing `motion.speed` into the
  three durations rather than dropping it. ⚠️ The cost, stated when it was
  chosen: one multiplier guaranteed the ratio between the three; five controls
  make it a default.
- **Reset one page of settings**, not one row — and it needs no second copy of
  the schema, because a missing key already resolves to its default. Deleting is
  setting back.
- **The calendar speaks CalDAV**: `REPORT` leaves the machine now, measured
  against a real server. ⚠️ Appointments still do not appear — the Google token
  carries no calendar scope, and only reconnecting the account can change that.
- **Discord and Spotify follow the palette.** Discord is `dev.vencord.Vesktop`,
  because the Discord flatpak's `app.asar` is hardlinked into OSTree's object
  store and cannot honestly be patched; Spotify is a `--user` flatpak so
  spicetify needs no root.

### ⚠️ What the reviews found and this release does NOT fix

Named here rather than left to be discovered:

- **17 of 49 test suites could not go red at the fault they were written for.**
  Two hang on a comment inside the file they check; one reports "ok" after every
  Escape handler in the shell is deleted. Each is small; there are seventeen.
- **Eight places draw an element in its parent's colour** — measured contrast
  1.000:1 to 1.031:1, in all eleven palettes. The cause is structural
  (`opacityPanel: 1.0` makes two role colours identical), so it wants one
  decision about the ladder rather than eight patches. The black style avoids it.
- **The suites are not order-independent**: three pass alone and fail in a batch.
- **19 of 49 suites never run in CI**, only five of them for a stated reason.
- **M10 has still never touched a battery**, and nothing here has run on a second
  monitor, on HiDPI or on hybrid graphics. `docs/LAPTOP.md` is the list.

### The detail of those four, from the first half of the day

Four of the things the alpha named as unfinished. Each was measured before it
was built, and two of the measurements changed what got built.

### Reset one page of settings

He asked for the whole tab rather than the single row the old plan carried. It
turned out to be the cheaper half as well: `Config.qml` already resolves a
missing key to its default, so **deleting a key IS setting it back** — no second
copy of the schema, and the file that has segfaulted quickshell twice is not
touched. One row serves all twenty-two pages, and it asks before it fires.

⚠️ **It found a fault in the button that shipped.** `Backup._replace` writes
through a `FileView` that keeps the text it last wrote, and `setText` with equal
content is a no-op — so *reset, change something, reset again* wrote nothing the
second time and said it had. Import had the same shape. Fixed, with the case
that reproduces it in `tests/backup.sh`.

### The calendar speaks CalDAV at last

QML's `XMLHttpRequest` has no `REPORT`, which is the only way CalDAV asks for
events — so the calendar could never have fetched an appointment however good
the token was. Every request goes through `curl` now, measured against a real
server that answers a real REPORT.

⚠️ **The token never reaches a command line.** `/proc/<pid>/cmdline` is
world-readable, so the whole request goes in over stdin. Measured with a control
that can fail: the same token passed as `-H` is found in argv, through the
config it is not.

⚠️ **Appointments still do not appear**, and no code can change that: the Google
token carries no calendar scope. The account has to be removed and added again
with Calendar ticked. Every surface that asks says the 403 on screen.

### Discord and Spotify follow the palette

Approved on 06.08.; the measurement on 10.08. changed how.

- **Discord is `dev.vencord.Vesktop`** instead of `com.discordapp.Discord`. The
  Discord flatpak's `app.asar` is root-owned with a **link count of 2** — it is
  hardlinked into OSTree's object store, so patching it in place rewrites a
  shared object, and an update would discard the patch anyway. Vesktop has
  Vencord inside it: nothing to patch. ⚠️ The theme has to be ticked once.
- **Spotify is a `--user` flatpak** so spicetify can write without root, with
  the binary pinned to 2.44.0 and its checksum computed here rather than copied.
  ⚠️ A Spotify update undoes the patch; `bhctl theme spotify` puts it back.

Fourteen colour files now follow a palette switch, up from twelve.

### `docs/LAPTOP.md`

The acceptance list for the real machine, written before the install: what to
read off it, with which command, and the one step that can lose data (the
BitLocker key, before Secure Boot).

### ⚠️ Two of our own checks could not go red

Both found by deliberately breaking the code they guard, which is the only way
this keeps being found:

- `tests/backup.sh` and the new `tests/reset-page.sh` compared a file 250 ms
  after the action — but `_report` runs before the bytes land, so a broken run
  reported "refused" as FAIL and "nothing was written" as ok, about the same
  write. Both wait for the file to stop changing now instead of sleeping at it.
- The first argv scan for the calendar token matched its own `grep` and found a
  hit in both cases. The same trap `tests/xwayland.sh` fell into in the alpha.

49 suites.

## v0.1.0-alpha — 10.08.2026

The first tag. M0 through M12 are built; what is not finished is named at the
bottom rather than left to be discovered, which is the point of an alpha.

### What this is

A Fedora desktop built on the compositor and Quickshell, where one palette of 26 colours
drives everything: the shell draws itself from it, and one renderer writes the
same tokens out to GTK 3, GTK 4/libadwaita, Qt, kitty, alacritty, btop, bat,
tmux, lazygit, git-delta, fastfetch, VS Code and the compositor. Change the palette and
the applications follow, with no second source of truth.

Everything above the installer is QML. The installer is bash because it runs on
a machine with no desktop yet. There is no Lua, no Python at runtime, and no
GTK in anything this project draws itself.

### The milestones

| | |
|---|---|
| **M0** | The measurement gate — is Quickshell on the compositor viable at all |
| **M1** | Repository, installer phases, package lists, CI |
| **M2** | `shell.json` to `config.kdl`, migrations, `Hyprland --verify-config` in CI |
| **M3** | Shell scaffold, compositor layer, `Theme.qml`, the bar |
| **M4** | The notch: silhouette, flare, mask, blur |
| **M5** | Notifications, OSD, session menu |
| **M6** | Launcher with a two-column category list |
| **M7** | The dock, and per-application volume |
| **M8** | The settings window — 22 pages, 183 settings, every one with a row |
| **M9** | Lock screen **and the greeter**: greetd plus our own Quickshell login screen |
| **M10** | Laptop tuning: power report, profiles, charge thresholds, lid |
| **M11** | Borderless, and XWayland measured rather than asserted |
| **M12** | This |

⚠️ **M9 changed meaning twice and the handovers did not follow.** The original
plan says "lock screen + an SDDM theme from the palette". On 04.08. that was
overturned — sddm out, greetd and our own greeter in — and the greeter never
got a number, so four handovers called it "M9 Greeter" while the other half of
M9 sat unbuilt and unmentioned. The SDDM theme is deliberately not built: it
would be a second login screen to keep in the palette, for a screen the greeter
replaces.

### The last round, in short

- **The greeter** — greetd plus `shell/ui/greeter/`, accepted by logging in
  through it on a freshly built VM. sddm stays installed and disabled;
  `bhctl greeter disable` is the way back, and `enable` refuses until `test`
  has passed on that machine.
- **A spinning Fedora logo in the terminal greeting**, rendered by the palette
  renderer and played by `bin/buchhwin-fetch` — fastfetch cannot animate, which
  was measured before anything was built.
- **fastfetch has a configuration**, in the shape of his own from the
  predecessor: a glyph and a word as the key, one palette colour per row.
- **H.265** — it was never switched on. Both conditional steps were guarded on
  the package they replace, so on a machine with neither, nothing ran.
- **The dock could not be switched off**, and seven other surfaces had the same
  fault: a Config block is `null` while shell.json is being read, a binding that
  throws keeps its last value, and its last value was the default.
- **VPN, Google Drive, the emoji picker and the task manager.**

### ⚠️ What is NOT finished

- **The calendar does not show Google events.** QML's XHR cannot send `REPORT`,
  so CalDAV is unreachable. It is also blocked upstream of that: the account's
  token carries no calendar scope and has to be reconnected before anything can
  be measured.
- **"Reset to default" on a single settings row.** A global reset exists.
- **Vencord and spicetify.** Approved, not built.
- **M10 has never touched a battery.** The charge thresholds, the lid, docking
  and our own idle draw need real hardware — `/sys/class/power_supply` is empty
  on the test VM. The settings page says so on screen rather than showing a
  dead slider.
- **Not run on a second monitor, on HiDPI, or on hybrid graphics.**

### Known ways to hurt yourself

- The login screen is the one failure that cannot be fixed from inside the
  desktop. `Ctrl+Alt+F3`, then `bhctl greeter disable`.
- `theme.palette: "wallpaper"` recomputes the whole scheme when the wallpaper
  changes, so a slideshow repaints every application at every change. There are
  two separate switches for exactly that reason.
- The desktop is Wayland-only by design. Brave is started with
  `--ozone-platform=wayland`, which means it will not start on an X11 session.
