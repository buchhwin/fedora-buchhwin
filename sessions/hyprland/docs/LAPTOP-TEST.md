# The live test on real hardware — 08.08.2026

Everything below was measured on `<laptop>` (a hybrid AMD + NVIDIA machine,
Fedora 44, eDP-1 1920×1080 @ 144 Hz), reached through a reverse SSH tunnel from
the build host. It is written down because a laptop is not always available and because
half of what follows contradicts something that was previously believed.

The VM is the next place work happens. **These findings do not reproduce there**
— the VM has no battery, no NVIDIA, no Secure Boot and no Google account — so
this file is the record of what only the real machine could say.

---

## ⚠️ THE ROOT PARTITION WAS 100 % FULL, AND IT EXPLAINED A CHAIN

`/` had **22 MB free of 15 GB**. The installer had assigned 15 GB of a 95.7 GB
LVM partition and left **80.65 GB unallocated in the volume group** — the space
was always there, it had simply never been handed to the filesystem.

```
sudo lvextend -l +100%FREE /dev/fedora/root
sudo xfs_growfs /
```

XFS grows online: no reboot, no unmount, no risk to what is on it. Result: 96 GB,
79 GB free.

**What that one fault was holding up:**

- Every `dnf install` failed with `Curl error (23): Failed writing received data
  to disk`, which reads like a network fault and is not one.
- **akmods could not build the NVIDIA modules**, so they were never signed, so
  Secure Boot refused them, so the driver never loaded. Five layers, one cause.
- Very likely the "occasional graphics glitches" (B4), which never had a repro.

⚠️ It was NOT the cause of slow application starts. Brave measured 5.2 s before
the fix and 5.2 s after. Saying so matters more than the tidy story.

## ⚠️ NVIDIA: the key was never the problem

Reported as: his NVIDIA key is enrolled, an error is still shown, and he thought
he had done something wrong. He had not.

| | before | after |
|---|---|---|
| MOK keys enrolled | 3 (incl. akmods) | unchanged |
| `mokutil --list-new` | empty | empty |
| `modinfo nvidia \| grep -c '^sig'` | **0** | **5** |
| `modprobe nvidia` | `Key was rejected by service` | loads |
| loaded modules | none | nvidia, nvidia_modeset, nvidia_drm, nvidia_uvm |

The fix was `sudo akmods --force --rebuild` — which only succeeded once there was
disk space. `Services.Gpu` now separates the two faults (`needsEnrolment` vs
`needsResigning`) so the card can never again send somebody to check the one
thing that is already correct.

## ⚠️ The calendar has TWO walls, and either alone is fatal

1. **The token carries no calendar scope.** Google's tokeninfo endpoint returns
   exactly `email, profile, userinfo.email, userinfo.profile, openid`. Every
   CalDAV request therefore answers 403, which is the correct answer to the
   question being asked. GOA reports `CalendarEnabled=true`, which is GOA's own
   flag and not a grant.
2. **QML's XMLHttpRequest has no `REPORT` method** — the one CalDAV uses to ask
   for events. It throws "Unsupported HTTP method type" on every refresh. So even
   with a perfect token, `Calendar.qml` could never have fetched an appointment.

`evolution-data-server` was **not installed**, and EDS is what GOA hands calendars
to — with nothing to hand them to, nothing ever requests the scope. It is
installed now (3.60.2). ⚠️ **The account still has to be removed and re-added**
before a scope can appear; that is a step only he can do.

`bhctl calendar` now prints the token's scopes and probes three endpoints, so the
next person does not have to rediscover any of this.

## ⚠️ Google Drive in Nautilus is not possible on Fedora 44

`gvfs-goa`, `nautilus` and `gnome-online-accounts-gtk` are installed;
**`gvfs-google` does not exist as a package**, and `dnf repoquery -l gvfs | grep
google` is empty — the Google backend has been removed from gvfs. That is why the
account offers Mail, Calendar and Contacts but no "Files".

The working alternative is **rclone** (1.74.3 in the repos) with a mount.
✅ **BUILT on 10.08.2026** — `shell/services/Drive.qml`, `bhctl drive setup`, the
`buchhwin-drive.service` unit and a `drive` config group. ⚠️ This line still read
"not built" afterwards, while docs/CONFIG.md described it as finished — two
documents contradicting each other about the same feature.

## Startup times, measured properly

| | |
|---|---|
| kitty | **0.31 s** |
| Nautilus (cold) | **3.0 s** |
| Brave | **5.2 s** |

⚠️ **Four earlier measurements of this were wrong and three were reported as
fact.** The numbers 23.3 s, 35.2 s, 79.7 s and 119.5 s were all just the polling
loop reaching its own limit. Two independent causes:

- `NIRI_SOCKET` is **not set in an SSH session**, so every `niri msg windows`
  failed silently and the window counter never moved.
- Nautilus was already running. It is a single-instance GApplication, so a second
  invocation focuses the existing window and creates no new one — the counter
  could not have moved even with a working socket.

The rule this cost: **prove the instrument moves before trusting a number from
it.** The working version checks `count()` before and after starting kitty and
refuses to measure anything if it did not change.

## ⚠️ Never `pkill -f "$var"`

A measurement helper did `pkill -f "$2"` where `$2` could be empty. An empty
pattern matches every process. It killed his session and the machine came back
having lost the desktop. Kill the PID you started, and guard it:

```bash
if [ -n "$pid" ] && [ "$pid" -gt 1 ] 2>/dev/null; then kill "$pid"; fi
```

## Other facts only this machine could give

- **The login shell is zsh.** Remote scripts must be `ssh … 'bash -s' <<'EOF'`.
- `qs ipc call` needs `WAYLAND_DISPLAY` **and** `XDG_RUNTIME_DIR`.
- `DesktopEntries.applications` read imperatively inside a Timer returns an empty
  list. It must be a BINDING — `Apps.qml` documents why, and two probes reported
  "0 entries" before that was remembered.
- A `.desktop` file written six minutes after the shell started appears in the
  launcher **without a restart**. A6 does not reproduce; Quickshell reads
  `XDG_DATA_HOME` independently of `XDG_DATA_DIRS`.
- `~/.config/brave-flags.conf` does **nothing**. That convention is Arch's;
  Fedora's `/opt/brave.com/brave/brave-browser` is a bash wrapper with zero
  occurrences of `flags.conf`.
- niri ships its entire manual at `/usr/share/doc/niri/wiki/` plus
  `default-config.kdl`. Both are better sources than memory — see NIRI.md.

---

# What the test found in the desktop itself

All fixed, all pushed. Listed because the *class* of each is worth carrying.

| what he saw | what it was |
|---|---|
| Clicking the notch did nothing | A commit removed the status pill and never added a replacement handler. `tests/tap-targets.sh` now also asks whether a target EXISTS, not only whether it is big enough |
| Windows still transparent | Migration 10→11 lifted `opacityPanel`/`opacityApp` — our own panels. The two that make a WINDOW see-through are `opacityActive`/`opacityInactive`, and they were untouched |
| Animations "still buggy" | The notch's hover content loaded `asynchronous: true`, so the width animation started toward a width that did not include content which did not exist yet, then re-targeted mid-flight |
| Animations still not clean | `Easing.OutExpo` was the wrong curve for SIZE — niri uses expo for opacity/scale and springs for geometry. Expo puts 99 % of the distance in the first third and crawls |
| Sliders froze the page | `WheelHandler` with `accepted = true` over the whole row: the wheel never reached the Flickable, **and silently changed whichever setting it passed over** |
| Cards unfolded on every page change | A `Behavior` on a height derived from content, which grows from 0 during layout — it animated every build, not the collapse |
| Sliders jittered when dragged | The press feedback grew `implicitHeight`, a LAYOUT size, relaying out the whole page |
| Search froze on first keystroke | It built all 21 pages synchronously |
| Esc closed some things and not others | `wantsKeys` is a whitelist; five pages could never receive the key at all |
| Expired timer kept coming back | `acknowledge()` cleared `rang` in memory and never wrote it, so every start restored `true` from disk |
| Dropdown opened under everything | The group card sets `clip: true`, and `z` orders only siblings — a menu inside a row cannot escape either |

**The thread through four of them:** a `Behavior` on a layout size animates every
change to that size, not the one gesture that was meant.

---

# Still open after the live test

Nothing below was started. Ordered by size.

| | |
|---|---|
| ~~**G6 rebinding keys**~~ | ✅ **BUILT on 09.08.2026** — key capture, the clash check BEFORE anything is written, `rebinds` as overrides rather than a full copy, and `tests/rebind.sh`. Every condition this line laid down was met; it went on saying "deliberately not begun" for two more days. | Key capture + niri's 142 actions + ⚠️ **conflict check BEFORE writing** (two bindings on one key = niri does not start) + `binds` as OVERRIDES rather than a full copy (otherwise the first rebind freezes all 63) + a migration. Deliberately not begun: half-built here means a desktop that will not come up |
| **A2b** | `programs.*` as a choice rather than a text field (the category is in the `.desktop`). Also: `kind: "strings"` is the only text kind without an Apply pill |
| **D2** | The WiFi list should be its own window; today it is a drawer inside the panel |
| ~~**D4**~~ | ✅ Back and forward are in the settings window (`SettingsContent.qml`). This line offered as its evidence that `arrow_back` "appears nowhere in the project" — it appears exactly there. |
| **One UI elsewhere** | Launcher, toasts, lock screen and bar have not had the treatment (`radiusLg` appears in none of them) |
| **Super+Tab** | The switcher is too small to use |
| **Scroll speed** | Ours reads shorter than Electron's for the same gesture. Foreign toolkits cannot be unified; our own Flickables can be matched |
| **A4** | A folder picker in the window, without GTK |
| **Calendar app** | Depends on the calendar syncing at all — see the two walls above |
| **`switch-events`** | niri can handle the lid itself, which would beat the logind detour. Described in NIRI.md, not built |
| **B4** | Graphics glitches — may well have been the full disk. Wait for a recurrence before hunting |
