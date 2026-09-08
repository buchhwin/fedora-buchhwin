# Installing on the laptop — the acceptance list

Everything in this project that a virtual machine cannot answer, in the order it
can be answered on the real one. Written on 10.08.2026, before the install, so
that the findings are collected rather than improvised.

**The machine:** a hybrid laptop — an AMD APU with its integrated Radeon,
plus an NVIDIA discrete card. Fedora 44 as a dual boot beside Windows.

⚠️ Deliberately no model numbers, here or anywhere else in this repository.
This one is public, and an exact CPU/GPU pair beside a public account is a
fingerprint of somebody's hardware. Every finding below is about hybrid
graphics and Secure Boot, neither of which needs a part number to be true.

⚠️ **`docs/LAPTOP-TEST.md` is the RECORD of the last live test (08.08.2026), not
this file.** Read it first — it already answers several questions below, and the
four measurement mistakes it documents are the ones easiest to repeat.

---

## 0. Before touching Secure Boot — the only step that can lose data

⚠️⚠️ **Have the BitLocker recovery key in your hand.** Changing Secure Boot
settings can make Windows demand it at the next boot. Everything else in this
list is reversible; this one is not.

The NVIDIA driver needs its module signed and the key enrolled. On 08.08. the
key was already enrolled and the modules still refused to load — the modules had
been built before the key existed. `sudo akmods --force --rebuild` was the fix,
and the settings window now tells these two faults apart by itself
(`needsEnrolment` vs `needsResigning`), so read what it says rather than
assuming which one it is.

## 1. Two settings that will NOT arrive on their own

⚠️ A `shell.json` that already exists wins over the defaults, key by key. If you
are carrying settings over from the VM or from an earlier install, these two
have to go in **by hand**:

| | |
|---|---|
| `windows.blurred` | otherwise Nautilus is translucent with nothing behind it |
| `autostart` | otherwise the polkit agent never starts, and every password prompt is invisible |

The way to check is not to read the file: open the settings window, Windows and
This Machine, and look at the rows.

## 2. Read these off the machine, with the number

Nothing below can be answered here. Each line is a measurement, not a glance.

| | how |
|---|---|
| **Discharge rate, temperature, governor** | `bhctl power report 60`. ⚠️ It checks the counter is moving before it prints a wattage — on a machine with no battery it says so instead of printing 0.0 W |
| **Charge thresholds** | Settings → Power. ⚠️⚠️ **The writing end has never run.** `/sys/class/power_supply` is empty on the VM and the build host has no battery, so `/usr/libexec/buchhwin-charge` has been read but never obeyed. Set 75/80, then `cat /sys/class/power_supply/BAT*/charge_control_end_threshold` — the file, not the slider. ⚠️ The END threshold is written first, deliberately: some firmware refuses a start value above the current end |
| **The lid** | close it, open it. Then the same with an external screen attached |
| **Suspend and resume** | does the shell come back, does the lock screen come back, is the clock right |
| **A second screen** | does each screen get its own bar and its own island |
| **HiDPI** | Settings → Size & Shape → the per-monitor scale. ⚠️ There is no automatic mode and that is deliberate: niri already guesses, and a second guess of ours would fight it |
| **Hybrid graphics** | ⚠️ The external connectors are wired to the dGPU (niri's own FAQ), so niri renders on the integrated GPU and copies each frame across — the external screen can stutter. The fix is `gpu.renderDevice` in Settings → This Machine. ⚠️ It is a CLOSED list of the render nodes this machine really has, and the `by-path` form is offered first because `renderD128`/`129` are handed out in probe order. ⚠️ `niri validate` accepts a device that does not exist — the way back is a TTY, see `docs/NIRI.md` |
| **H.265 in hardware** | `vainfo \| grep VAProfileHEVCMain`. The software path is measured; a virtio GPU cannot answer the hardware one |
| **144 Hz** | the one thing no counter can say. Do the animations *feel* right — does the island open without overshooting? The protocol counters proved the cause of the old stutter, but "runs smoothly" is your eyes |
| **Tray** | no tray program ran on the VM. The icon appears, left click activates, right click opens the menu |
| **The media pill** | start a player: album art, title, play/pause. Counter-check — quit it, the pill disappears rather than going empty |
| **Battery icon** | right percentage, changes when plugged in, yellow under 15 %, red under 5 % |
| **Our own idle cost** | the target is **zero redraws at rest**. Leave it untouched for a minute on battery and watch `bhctl power report` |

## 3. The two programs whose theming an update can undo

Both were built on 10.08.2026 and both cost something the other thirteen do not.

- **Discord is Vesktop** (`dev.vencord.Vesktop`), not `com.discordapp.Discord`.
  ⚠️ The buchhwin theme has to be **ticked once** under Settings → Themes:
  Vencord is downloaded by Vesktop at first start, so its list of enabled themes
  does not exist until you have logged in.
- **Spotify is a `--user` flatpak** so that spicetify can write without root.
  ⚠️ After a Spotify update the patch is gone. `bhctl theme spotify` puts it
  back — it renders and injects in that order.

## 4. The calendar — one step only you can take

⚠️ The transport is fixed and the account is not. QML could not send `REPORT`;
that is `curl` now and measured. What remains is that the Google token carries
**no calendar scope** — `bhctl calendar` prints exactly `email, profile,
userinfo.email, userinfo.profile, openid`.

**Remove the Google account in Online Accounts and add it again with Calendar
ticked.** Nothing in the desktop can do this. Until then every request answers
403, and every surface that asks says so on screen rather than showing an empty
month.

## 5. When the login screen is the thing that is broken

It is the one failure that cannot be repaired from inside the desktop.

```
Ctrl+Alt+F3          a text console
bhctl greeter disable    back to sddm, which is installed and switched off
```

`bhctl greeter enable` refuses until `bhctl greeter test` has passed on this
machine, so the way in is checked before the way out is needed.

## 6. Finally

```
bhctl doctor
```

green, and `install.sh` run from nothing at least once — a fresh install has
found three faults that no test did.
