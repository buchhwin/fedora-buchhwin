# Checklist M2 — what only you, at a screen, can tell

Everything here is **built and machine-checked**, but has not been seen with
eyes. The VM can check correctness, not appearance — and it has no sound, no
battery and no real graphics.

Test VM: **<hypervisor> VM `<test-vm>`**. Its address and credentials are not written
here — this repository is public. The working tree lives in `~/repo`.

---

## Already proven by machine (nothing for you to do)

| | Evidence |
|---|---|
| `config.kdl` is generated and valid | `tests/niri-config.sh`, 10 cases, exit 0 |
| Settings really take effect | `gapsOut 24 → gaps 24`, `borderWidth 3 → border { on; width 3 }`, `profile minimal → blur { off }` |
| A second run writes nothing | `0 written, 2 unchanged` |
| A fresh machine with no `shell.json` | produces valid defaults |
| Colours separate from structure | `colors.kdl` holds colours only, `config.kdl` keeps `border { off }` |
| All 11 palettes really load | `tests/all-palettes.sh`, 60 differing lines per palette pair |
| Broken palettes are refused | missing key, broken JSON, `bg == fg` — all three FAIL |

---

## 1. Log in and look (the important one)

```
ssh $USER@<test-vm>
cd ~/repo && bash install.sh      # or just: bhctl niri apply
```

- [ ] **niri starts and no waybar appears.** If a foreign bar shows up:
      `rpm -q waybar` — then it was installed with recommendations.
- [ ] `niri msg -j windows` returns windows, and no Xwayland process
      (`pgrep Xwayland`)
- [ ] The island and the bar **are** there (since M3, see below). If you only
      want to check M2: `bhctl shell reset` restores the defaults — then only
      the island is on and the bar is off.

## 2. Walk through the keys

⚠️ **Do not test over VNC.** Keys injected through VNC never reach niri's
bindings — measured: not with `Super`, not with `Alt`, not even a bare `F9`,
although the configuration is loaded. The pointer works, the keyboard does not.
On top of that many VNC viewers swallow the Super key on your own machine
already. Testing that way makes working shortcuts look broken.

**Use the hypervisor console** (`https://<hypervisor>:8006` → VM <vmid> → Console) — its
emulated USB keyboard looks like a real device to niri. Or remotely from the
host:

```
<hypervisor-ssh> "qm sendkey <vmid> meta_l-ret"   # Super+Return
<hypervisor-ssh> "qm sendkey <vmid> meta_l-e"     # Super+E
```

Already proven that way: **Super+Return starts kitty, Super+E Nautilus,
Super+O opens the overview.** The remaining spot checks:

- [ ] `Super+Return` opens kitty
- [ ] `Super+E` opens Nautilus, `Super+B` the browser
- [ ] `Super+←/→` moves the **focus**, `Super+Shift+←/→` the **window**
- [ ] `Super+Ctrl+←/→` makes the column narrower/wider (this was snap on the
      predecessor)
- [ ] `Super+Ö` jumps to the scratch workspace, `Super+Shift+Ö` moves a window
      there
- [ ] `Super+1…9` switches workspaces
- [ ] `Print` takes a screenshot
- [ ] `Super+Shift+Slash` shows the keyboard shortcuts — **this is where you see
      at a glance whether every label is right**
- [ ] ⚠️ **Rescue keys**: stop the shell on purpose
      (`systemctl --user stop buchhwin-shell`), then `Super+Shift+Return` must
      still open a terminal and `Super+Ctrl+Shift+R` must restart the shell

## 3. No window buttons — on real windows

Open one window of each and look at the **top right**: minimise, maximise and
close have to be gone, the header bar itself stays (that is intended, see
NIRI.md).

- [ ] Nautilus (GTK4/libadwaita) — should look like your screenshot
- [ ] kitty
- [ ] a Qt window (`vlc`, for instance)
- [ ] VS Code and Brave (Electron — the most stubborn ones in practice)

Whatever does not work: **write it down, do not argue it away.** The Electron
part is deliberately not measured until M11.

## 4. Nautilus, network shares, Google Drive

- [ ] Start `gnome-online-accounts-gtk` and **actually add a Google account**.
      ⚠️ The package is at 3.50.10 while GOA itself is at 3.58 — that version
      gap is why this is not claimed rather than checked.
- [ ] Afterwards: does Google Drive appear in Nautilus's sidebar?
- [ ] Connect an SMB target (`Other Locations` → `smb://…`)
- [ ] Counter-check for non-GTK programs: is the mount under
      `/run/user/1000/gvfs/`, and can `ls` see it? (that is what `gvfs-fuse` is
      for)
- [ ] **The file-open dialog in any program** — it should be the Nautilus
      dialog. That is the reason Nautilus is the one chosen.

## 5. When something goes wrong

```
bhctl doctor                       versions, unit, config, XWayland, start time
bhctl niri diff                    what a regeneration would change
niri validate -c ~/.config/niri/config.kdl
cat /tmp/buchhwin-niri.log         the generator's report
cat /tmp/buchhwin-render.log       the theme renderer's report
```

A broken `config.kdl` is not a disaster: the keys live in the compositor, and
`bhctl niri apply` tells you with exit 1 rather than failing quietly.

---

## Open from earlier milestones (not M2, but still unseen)

- [ ] Whether the four test-addon decisions still hold
- [ ] niri #2519 (dragging out of a GTK4 popover) — **not reproduced in M0, but
      not disproved either**

## Deliberately not built yet

**Nothing from M0–M12 as a whole.** The dock (M7) shipped on 09.08.2026 and the
greeter (M9) on 10.08.2026 — the latter with the acceptance this file has asked
for since M2, below.

What is genuinely still open, named rather than left to be discovered:

- **M10 on real hardware, and everything else only a laptop can answer.** The
  charge thresholds, the lid, docking, a second screen, HiDPI, hybrid graphics,
  H.265 in hardware and our own idle cost. ⚠️ The WRITING end of the charge
  thresholds has never run: neither the VM nor the build host has a battery, and
  `/sys/class/power_supply` is empty on the VM. **`docs/LAPTOP.md` is the list**
  — written before the install so the findings are collected rather than
  improvised.
- **The Google calendar account.** ⚠️ Only he can do this: remove it in Online
  Accounts and add it again with Calendar ticked. The token carries no calendar
  scope, so Google answers 403 and no amount of code changes that.
- **The picture debt.** `tests/surfaces.sh` proves every surface opens and
  closes, and `tests/palette-reach.sh` proves fourteen colour files follow a
  palette switch — both structurally. What is still missing is the *look*: a
  before/after pair per surface, the seven rebuilt settings pages, and the dock.

⚠️ Three lines that used to sit here are done, and are named so nobody builds
them twice:

- ✅ **The calendar transport.** QML's XHR could not send `REPORT`; every request
  goes through `curl` now, with the token off the command line. The 403 above is
  what remains, and it is his to clear.
- ✅ **"Reset to default" per page.** Not per row, which is what the old plan
  said — he asked for the whole page instead, and it needs no second copy of the
  schema: deleting a key IS setting it back. A global reset still exists too.
- ✅ **Vencord and spicetify.** Discord is `dev.vencord.Vesktop` (Vencord already
  inside, nothing to patch) and Spotify is a `--user` flatpak so spicetify can
  write without root. ⚠️ Both can be undone by the program's own update — see
  docs/CONFIG.md.

⚠️ The settings window used to be on this line and it is BUILT: ten pages under
`shell/ui/settings/`, opened by `Ipc.settingsOpen`, and `tests/setting-rows.sh`
runs in CI asserting that every one of the settings in `shell.json` has exactly
one row in it. A checklist that says a finished thing does not exist is how the
next person spends an afternoon building it twice.
Bar and island have been there since M3; notifications, the lock screen and the
wallpaper picker with its derived scheme are done.

**SDDM is still installed, and now deliberately so.** The condition this line
carried since M2 — "only once our own greetd greeter demonstrably reaches a
desktop" — was met on 10.08.2026 on a freshly built VM: greetd active, the
greeter drawn, a password typed, and `loginctl` reporting a session on seat0
with `niri --session` and `qs -c buchhwin` running as the user. Screenshots
`2026-08-09/greeter-erster-anblick.png` and `greeter-desktop-erreicht.png`.

He was asked what should happen to sddm and chose to keep it: installed and
disabled. About 40 MB buys the one thing that cannot be improvised from a
machine with no login screen. The way back is `bhctl greeter disable`, and from
a TTY if it comes to that — Ctrl+Alt+F3.

---

# Checklist M3 — shell, bar and island

## Already proven on screen (VM, with real screenshots)

| | |
|---|---|
| Bar and island are **one** silhouette | the island sits centred in the bar, shoulders merged |
| The island at rest | nearly black, rounded below, concave shoulders, clock inside |
| Volume transforms the island | speaker, filled track, "80 %" — as in your reference |
| The strut reserves exactly 34 px | counted against the tile height |
| A palette change takes effect live | `bhctl theme nord`, same process id |
| The clock appears exactly once | in the bar when it is on, otherwise in the island |

## What only you can check

- [ ] **The media pill.** The VM has no MPRIS player installed, so it correctly
      stays invisible there. On your machine: start Spotify or Discord — **album
      art, title and a play/pause button** must appear, and nothing else.
      Counter-check: quit the player → the pill disappears rather than going
      empty.
- [ ] **Tray.** No tray program was running on the VM. Check: the icon appears,
      left click activates, right click opens the menu.
- [ ] **Battery.** The VM has none. On the laptop: the percentage is right, the
      icon changes when you plug in, below 15 % it turns yellow, below 5 % red.
- [ ] **How does the motion feel?** The VM has a virtio GPU — smooth there means
      nothing. On real hardware: does the island open softly, without
      overshooting?
- [ ] **Blur behind the island.** The layer rule is in `config.kdl`; it only
      becomes visible with a wallpaper behind it.
- [ ] **Two screens.** Does each screen get its own silhouette?

---

# Checklist M4 — the island as a host for pages

## Proven on screen

| | |
|---|---|
| Volume | the island becomes the slider: speaker · track · percentage |
| Media | album art, title, play/pause — the empty state is one line of text |
| Notifications | `notify-send` transforms the island, entry with a close button |
| Quick settings | volume slider; the brightness row is correctly absent because the VM has no backlight |
| Opening and closing | click the island, click beside it, `ipc call notch …` |

## What only you can check

- [ ] **Brightness** on the laptop: the row appears, dragging really changes the
      screen. ⚠️ Without `-c backlight`, `brightnessctl` grabbed the **numlock
      LED** on the VM — please confirm on your hardware that it is the screen.
- [ ] **How do the transitions feel?** Does the island grow softly into the
      page, without overshooting? The VM's virtio GPU says nothing about this.
- [ ] **The size of the island** against your screenshot — 150×34 collapsed,
      135 high expanded. Measure it on real hardware.
- [ ] **Media** with Spotify or Discord: album art and title correct,
      play/pause works.

---

# Checklist M3.5 — the wallpaper and the scheme derived from it

## Proven on screen (VM, real screenshots)

| | |
|---|---|
| The image is drawn | its own surface on the `background` layer |
| The picker is an **island page** | the island grows into the row of images, not a second window |
| The active image is marked | a tick; the outline is the keyboard cursor |
| The scheme follows the image | Desert1 → `#f5b648`, Lake3 → `#f88844` — the measured seed tones |
| It follows into foreign programs | `gtk.css` carries the same value |
| **Restart** | a real reboot: image **and** scheme come back unchanged |
| Everforest is no longer the default | a fresh installation seeds `palette: "wallpaper"` |

## What only you can check

- [ ] **`Super+Shift+W`** opens the picker — through the hypervisor console, not
      over VNC.
- [ ] **Do you like the derived scheme?** Go through all twelve images. If one
      looks unpleasant: say which and why — the derivation has knobs.
- [ ] **The transitions:** does the island grow softly into the row of images,
      without overshooting?
- [ ] **On real hardware**: does the image look sharp at HiDPI, and how long
      does a change take on a real disk?

# Checklist M4 remainder — calendar and tray

## Proven on screen

| | |
|---|---|
| Calendar | a whole month, six weeks, today in the accent, weekdays correct |
| The island grows for it | The WIDTH has a lower bound (`minExpandedWidth`); the HEIGHT follows the contents, floored only at `collapsedHeight`. `expandedHeight` is the reference size the wallpaper row is drawn against, not a minimum for every page — it used to be, and three pages sat on it being padded with dead space. |
| Tray | the page opens, the empty state is one line of text |
| All seven pages | reachable through `ipc` and through keys, no warning in the log |

## What only you can check

- [ ] **Tray with a real program** (the VM had none): the icon appears, left
      click activates, **right click opens the menu — with the bar switched
      off**. That is the real test, because the bar is off by default.
- [ ] **Page through the calendar** with ‹ › and with the arrow keys, and
      "today" jumps back.

---

# Checklist — Google Calendar

**This cannot be checked without your account.** It was tested against fixed
sample files (23 checks, all green, with no network); the interplay with Google
is yours to check. No credentials are needed for that — you create the account,
and the shell fetches the token from Online Accounts at runtime.

## Already proven (without an account)

| | |
|---|---|
| Without an account the page says so | "No Google account with the calendar switched on" — one sentence, not an empty grid |
| The **+** is then absent | a button opening a form that cannot save would be worse than no button |
| The create page | title · date · from–to · all day; "Save" stays grey while anything is wrong |
| Time zones | 14:00 Berlin = 12:00 UTC in August, 13:00 UTC in January — out of the `VTIMEZONE` |
| Recurrences | a weekly rule appears on **every** occurrence, exceptions are missing, moved single occurrences win |
| Month arithmetic | February 2028 = 29, February 2100 = 28, February 2400 = 29 |

## What you have to check

1. [ ] Start `gnome-online-accounts-gtk`, **add a Google account and switch the
       calendar on**.
2. [ ] `bhctl calendar` → account, remaining token lifetime, `HTTP 207` and
       "reachable". ⚠️ The token itself is deliberately **not** printed.
3. [ ] `Super+C`: are this month's events there? Hold it against
       calendar.google.com.
4. [ ] A **weekly** event must appear on every occurrence, not only once.
5. [ ] An **all-day** event must sit on its day — not the one next to it.
6. [ ] A dot under the days with events; tap a day → the list below is right.
7. [ ] **The acceptance test:** `Super+Shift+N`, create an event → **look at it
       on your phone**.
8. [ ] The other way round: create an event on the phone → reopen the island →
       it is there.
9. [ ] Counter-check with no network (`nmcli networking off`): one line of text,
       no hang.

## Not built yet

**Changing and deleting** events. The service can do it (`remove()` with
`If-Match`); the interface for it is deliberately still missing: a wrong
deletion hits a real appointment, and for that the display has to be
demonstrably right first — points 3 to 6 above.

---

# Checklist M5 — session, brightness, volume

## Proven on screen

| | |
|---|---|
| Session menu | five tiles, every icon correct, keyboard hint underneath |
| Volume is discreet again | ~256 × 34 instead of 619 × 135, thin track |
| The blur follows the island | no more blurred fifth of the screen |
| Windows are bubbles | space all round, rounded corners, top edge visible |
| All 21 icon names resolve | `tests/icons.sh` measures them in the real font |
| No key bound twice | `tests/niri-config.sh` checks it now |

## What only you can check

- [ ] **The scroll wheel over the volume page** changes it in 5 % steps, and the
      page stays open while you scroll.
- [ ] **`Super+Shift+E`** → the menu. Tap one of the three tiles on the right:
      it has to **ask**, not act immediately. Escape withdraws the question, a
      second press carries it out. ⚠️ Careful when trying "power off".
- [ ] **`Super+Ctrl+L`** locks immediately (not `Super+L`, which is navigation).
- [ ] **The brightness keys on the laptop**: the screen gets brighter **and**
      the island shows the value. ⚠️ Counter-check: with the shell stopped
      (`systemctl --user stop buchhwin-shell`) the keys must **still** brighten
      the screen — only without the readout.
- [ ] **How do the transitions feel?** The content should settle *into* the
      shape rather than fade in over it — and never overshoot.
- [ ] **Are the gaps between windows right?** `look.gapsOut` is 16.

---

# Checklist — notch behaviour, windows, weather

## Proven on screen (VM, real screenshots)

| | |
|---|---|
| The coloured fringe around the notch | **gone** — the surface is now exactly as large as what is drawn |
| The notch disappears | as soon as a surface opens at it, and comes back afterwards |
| Fullscreen | the notch becomes a discreet strip and moves to the `overlay` layer |
| Quick panel | calendar · weather · sliders · gear, as its own floating surface |
| Weather | Frankfurt: 27°, clear — place search and fetch both work |
| Shadows | notch, surface and windows share the same three numbers |
| Terminal | translucent in the palette's colours, blur behind it |

## What only you can check

- [ ] **Hover over the strip** in fullscreen: does the full notch come back, and
      does it go again when you move away?
- [ ] **`Super+F`** turns fullscreen on **and off again**. (`Super+Shift+F` is
      "maximise column" now — the two swapped.)
- [ ] **The scroll wheel** over the volume slider.
- [ ] **Type a place into the weather field** (from three letters) and click a
      result — then restart: the place has to still be there.
- [ ] **Do the shadows look right?** `look.shadowSoftness/Spread/OffsetY` are the
      three knobs; say so if it is too much or too little.
- [ ] **Is the blur behind the terminal enough for you?** `look.opacityTerminal`
      decides how much of it is visible at all — more transparency shows more
      blur.
- [ ] **The gear opens the settings window**, and so does `Mod+Shift+comma` and
      the arrow in the quick panel. It is a real niri window: move it, push it to
      another workspace, leave it open beside what you are changing.
      **All ten pages are there, and between them every one of the 135
      settings in shell.json has exactly one row** — `bash tests/setting-rows.sh`
      counts it, so "everything is settable" is a number rather than a belief.
- [ ] ⚠️ **Two things need `bhctl niri apply` before they show**, and the rows
      say so: the screen scale, and the motion speed's effect on niri's OWN
      window animations. Everything else takes effect as you change it.
- [ ] **Key bindings are a list you can read and search**, with "use the
      built-in bindings" for a machine whose shell.json froze its own copy.
      ✅ Rebinding a key is BUILT (09.08.2026): press the row, press the key,
      the clash check runs before anything is written. This line said "still
      to come" for two days after it shipped.
- [ ] **Does the settings window look like your reference?** Sidebar with a
      search field over ten named rows, the active one filled; back and forward
      at the top right-hand side; the page's symbol, heading and one line; then
      rows with the switch at the far right and the slider's value at the top
      right in the form `14 px`. Say what is wrong with the shape now, while
      changing it is cheap.

---

# Checklist — one state per program, and eight more programs

## Proven on screen and by measurement

| | |
|---|---|
| Every program can be themed on its own | `colour`, `neutral` grey, or `off` |
| Neutral is colourless, not unstyled | transparency, fonts and corners stay; red, green and yellow stay coloured |
| `off` takes our file back | a stub that overrides nothing and says why; no file of yours is touched |
| qt6ct really receives the colours | measured with a QApplication: one colour list gave Qt's default palette, three give ours |
| bat, tmux, delta, alacritty | asked of the programs themselves, not of the filesystem |
| Every generated theme is pointed at | `bhctl doctor` checks it on the machine you are on |

## What only you can check

- [ ] **Does the grey actually look good?** Set one program to `neutral` while
      the rest stay in colour — `theming.kitty = "neutral"` in `shell.json` —
      and see whether the mix reads as one system or as an accident.
- [ ] **A Qt program**, now that its colours arrive for the first time: does it
      match the rest, or does the palette need different roles?
- [ ] **btop, lazygit and starship in a terminal.** btop needs a real terminal,
      so nothing about it has been seen; the same goes for the prompt.
- [ ] **fastfetch and starship take their colours from the terminal's sixteen
      ANSI colours** — neither has an include mechanism. If you would rather
      they had real colours of their own, say so: that means we take over their
      config files, and you lose the ability to edit them freely.

---

# Checklist M6 — the launcher

## Proven on screen, and end to end

| | |
|---|---|
| Two columns | categories left, programs right, All and Frequent pinned above them |
| It opens in the middle | and the notch stays where it is — the clock is still readable behind it |
| `Super+D` opens it | sent through the hypervisor console, not over VNC |
| Typing filters | "alac" → one result, the category column dims, the count says 1 |
| Enter starts it | Alacritty ran, the launcher closed itself, and Frequent counted it |
| Icons come from the icon theme | with the first letter on a tile where a program has none |
| Two programs may share a name | nemo and Nautilus are both "Files" — the binary is shown to tell them apart, rather than one of them being dropped |
| Empty categories are not offered | Media and Office are absent because nothing on the machine is in them |

## What only you can check

- [ ] **Does it feel fast enough to replace the terminal?** The test is not the
      animation, it is whether you stop typing `alacritty &` into a shell.
- [ ] **`Super+Space`** as well as `Super+D` — both are bound, and one of them is
      probably the one your hands already know.
- [ ] **A program with no icon in the theme**: does the letter tile read as a
      stand-in, or does it look broken?
- [ ] **Frequent, after a week.** It is counted from zero on the machine you use,
      so it means nothing until you have used it.
- [ ] **A machine with a lot of programs.** The test VM has sixteen; a laptop
      with a full Fedora has several hundred, and scrolling and search behave
      differently at that size.

---

# Hybrid graphics, Secure Boot, and the second monitor

The target machine is a hybrid laptop: an AMD APU with its integrated
Radeon, plus an NVIDIA discrete card.
niri draws on the integrated one — `amdgpu` is in the kernel and needs no
signature — so
**the desktop does not depend on any of this**. What depends on it is offloading
and any monitor wired to the discrete card.

## Proven on the test VM

| | |
|---|---|
| The detector | six fake `/sys` trees in `tests/gpu-detect.sh`, including an NVIDIA HDMI audio function that must NOT count as a GPU. Removing the class test makes exactly that fixture red |
| The branch skips, and can run | `--only gpu` on the VM says "no NVIDIA GPU — nothing to install"; the same code with a hybrid fixture reaches RPM Fusion. Without the second half, "installed nothing" and "does nothing" are the same output |
| A failing GPU phase exits 0 | nothing in `phase_gpu` may `die` — an abort trades a working desktop for a card the desktop does not use |
| `debug { render-drm-device }` | accepted by niri 26.04. An invented key inside the block **is** rejected, so the name is real |
| ⚠️ A device that does not exist | **validates without a warning.** `niri validate` cannot tell a working device from a wrong one |
| An empty value | writes no `debug` block at all — measured, not assumed |
| The device list | `/dev/dri/by-path/pci-0000:00:01.0-render` + `virtio-pci`, by-path form preferred |
| The Secure Boot card | drawn under `BUCHHWIN_GPU_FAKE=needs-enrolment`, text read off the screenshot; **absent** without it, which is the control |
| `bhctl doctor` | prints the graphics block on a machine with no NVIDIA too — a doctor that goes quiet is indistinguishable from one that forgot the check |

⚠️ **Not verified: the "Show steps" button.** `ydotool` clicks do not reach
Quickshell windows on this VM — hover arrives, the button press does not, with
the settings window focused and with press and release sent separately. Proven
with a control: clicking a sidebar entry, which certainly works for a human,
does nothing either. So this is the instrument, not the card. **Press it once by
hand on the laptop.**

## What only you can check

- [ ] **`mokutil --test-key …` before and after the blue screen.** Paste both
      outputs here. "is not enrolled" then "already enrolled" is the whole proof.
- [ ] **`sudo modprobe nvidia` before enrolment fails, and `dmesg | grep -i
      'Key was rejected'` says why.** ⚠️ This is the control that separates
      "Secure Boot blocked it" from "the module was never built" — from
      userspace the two look identical.
- [ ] **The safety claim itself.** With the module NOT loaded: niri starts, the
      shell runs, `bhctl doctor` is green apart from the graphics block. Then the
      same session with it loaded. If anything else differs, "the desktop does
      not depend on NVIDIA" is wrong and the Secure Boot design changes.
- [ ] **The card disappears after enrolment.** A condition that is narrow going
      in and sticky coming out is not narrow.
- [ ] **`render-drm-device` on the external monitor.** `wf-recorder` for ten
      seconds against a fixed animation, `ffprobe -count_frames`, with the key
      set and cleared. Frame counts, not impressions.
- [ ] **What that costs.** `upower … energy-rate`, five minutes idle, both ways.
      It has to be a number, not "it uses more".
- [ ] **`vainfo` before and after the codec swap.** ⚠️ If the two lists are the
      same, the mesa swap bought nothing and comes back out — Fedora has been
      re-enabling codecs as patents expire.
- [ ] **Lid close and resume with the module loaded**, and again with
      `nvidia-suspend.service` disabled. That is what
      `xorg-x11-drv-nvidia-power` is in the package list for.
- [ ] **The MUX switch in the firmware stays on Hybrid.** "Discrete" costs
      battery and is only the fallback if the external monitor stutters.

## Before every push — the two checkers this machine does not have

⚠️⚠️ **`shellcheck` is not installed on the development machine**, and `grep`
there is **ugrep** rather than GNU grep. Both mean the same thing: *green here is
not green in CI*. The `shell` lane was once entirely red while every suite was
green — over a single unused variable name (SC2034) — and it stops at the first
finding, so `bash -n` never ran either.

The lab VM has `ShellCheck` on it. Run **exactly the CI command** there:

```sh
mapfile -t files < <(git ls-files '*.sh' 'bin/*' | grep -vE '\.(qml|json|md)$')
shellcheck -S warning "${files[@]}"
for f in "${files[@]}"; do bash -n "$f" || echo "Syntax: $f"; done
```

⚠️ **That list has to come from a real checkout.** Outside one, `git ls-files`
answers with nothing and prints no error — the working copy on the VM is an
rsync without `.git`, and the same trap has already had `tests/english.sh`
check zero files while reporting success. Read the file count before you read
the findings: "71 files, 0 findings" and "0 files" look alike in a hurry.

⚠️ And the suites belong there too, not here, for the same reason.

⚠️ **`mapfile` does not exist in zsh**, and after `install.sh` the login shell on
the VM is zsh. Over ssh, wrap it: `ssh … "bash -lc '…'"`. Otherwise the list is
empty, shellcheck gets no files, and the run looks like a success.

### And the check over the checks

```sh
bash tests/tripwires.sh          # never beside the suites: it mutates files
```

⚠️⚠️ **This was missing from this list, while the file's own header said "it is
the thing you run before believing the other fifty-five".** A step nobody is
asked to take is a step nobody takes: the last full run got as far as 21 of the
cases before an SSH drop took it, and nothing noticed for a round.

It answers in three states rather than two, and the middle one matters:

| exit | means |
|---|---|
| 0 | every case in the table proved its suite can go red |
| 1 | a case failed — a blind checker, or a stale case |
| 2 | **nothing was proved here** — no suite in the table could run |

⚠️ **Run it detached.** It restarts a shell for some cases and takes minutes, and
a dropped connection is exactly how the last run died:

```sh
ssh … 'setsid nohup bash ~/repo/tests/tripwires.sh > /tmp/tw.log 2>&1 < /dev/null &'
```

⚠️ It restores every file it touches, on any exit including Ctrl-C. Read
`git status` afterwards anyway — a checker's promise about itself is the one
claim it cannot make.

⚠️⚠️ **This very section shipped in German once and turned the CI red** — the
paragraph telling you to run the checkers was what the checker caught. The repo
is English everywhere, prose included.
