# Fedora dwl Desktop

## Choose your Fedora edition

This repository provides two separately installable variants of the same dwl
and Quickshell desktop. Choose the branch that matches the Fedora desktop
already installed on the computer:

| Fedora installation | Repository version | Command |
|---|---|---|
| Fedora Workstation with GNOME | [`main`](https://github.com/buchhwin/fedora-dwl/tree/main) | `git clone --branch main https://github.com/buchhwin/fedora-dwl.git` |
| Fedora KDE Plasma | [`kde-base`](https://github.com/buchhwin/fedora-dwl/tree/kde-base) | `git clone --branch kde-base https://github.com/buchhwin/fedora-dwl.git` |

The stable snapshot of the original GNOME setup is also preserved as the
[`gnome-final`](https://github.com/buchhwin/fedora-dwl/tree/gnome-final)
tag. Do not use either installer to convert an existing GNOME installation to
KDE, or vice versa. Install the matching Fedora edition first and then run its
installer. Both variants keep dwl, Quickshell, the visual design, keybindings,
Kitty, Starship and the settings application; only their desktop foundation
and default applications differ.

A complete, keyboard-first Wayland desktop for **Fedora 44 KDE Plasma**.
It is built from two main pieces:

- **dwl** handles the compositor, tiling, tags, focus and window rules.
- **Quickshell** handles the visible desktop shell: bar, launcher, notifications, control center, network, Bluetooth, sound, media and power UI.

The project is designed around a compact dwm-style workflow while keeping the desktop UI modern and Wayland-native.

The shell configures the desktop itself. There is no `blueman`, no `pavucontrol`
and no `nm-connection-editor` — Wi-Fi, Bluetooth and audio are managed in
Quickshell's own panels. Everything else comes from what Fedora and KDE
already ship.

> KDE Plasma is the required foundation. The installer adds a separate
> **buchhwin** session to SDDM while keeping Plasma as the fallback desktop.
> KAccounts/Akonadi, KWallet, NetworkManager and KDE applications provide the
> desktop infrastructure; dwl and Quickshell provide the visible session.

## Features

- pinned dwl `wlroots-next`, built against Fedora 44's wlroots 0.20.2
- a private pinned SceneFX build for terminal blur and visual effects
- native Wayland touchpad pinch/swipe/hold gesture forwarding
- XWayland support (required for Citrix Workspace, which is not a native Wayland client)
- German keyboard layout by default (`de`), configurable
- flat, acceleration-free libinput pointer profile
- 9 dwm-style tags
- master/stack tiling, floating and monocle layouts
- compact, attached grayscale Quickshell top bar
- one motion vocabulary across the shell: panels fade and lift, side panels
  slide, hover and state changes transition — all timed from `Theme.qml`
- consistent MesloLGS Nerd Font Mono typography and icon glyphs
- active tag / occupied tag / urgent tag state
- focused app/window title
- StatusNotifier system tray for background applications
- Quickshell app launcher
- Control Center
- **native Wi-Fi panel**: scan, connect, inline password entry, saved connections
- **native Bluetooth panel**: scan, pair, connect, forget
- **native sound panel**: output and input selection, per-application volume
- notification daemon, popups and notification center
- MPRIS media information and controls
- brightness controls
- UPower battery indicator
- screenshot workflow with Grim, Slurp and Swappy
- searchable local clipboard history with `cliphist`
- graphical persistent display layout, rotation and fractional scaling
- removable-drive automounting and GVfs integration
- Quickshell is supervised and restarts itself if it crashes
- bundled dark grayscale wallpaper with a solid-color fallback
- lock/suspend/logout/reboot/shutdown menu
- automatic idle lock, display power saving and suspend timers
- optional location-aware night light
- on-screen keybind viewer
- SDDM Wayland session entry alongside Plasma
- XDG desktop portal configuration for wlroots
- installer, updater, uninstaller and doctor script
- GitHub Actions repository checks

## Requirements

- Fedora 44 KDE Plasma installed as the fallback session
- Intel or AMD graphics — no NVIDIA-specific handling is included
- an internet connection during installation
- a normal user account with `sudo` access

## Installation

### Fedora 44

Clone this repository and enter it:

```bash
git clone --branch kde-base https://github.com/buchhwin/fedora-dwl.git
cd fedora-dwl
```

The installer uses Fedora's Quickshell and wlroots packages. It downloads
pinned dwl and SceneFX sources into a private user directory, builds
`dwl-buchhwin`, installs every required helper and adds a separate SDDM session.
No existing dwl checkout is required. Preview packages and destinations first:

```bash
./install-fedora.sh --dry-run
```

After reviewing the plan, install the separate **buchhwin** SDDM session with:

```bash
./install-fedora.sh
```

Plasma, its fonts, default browser and file associations are not changed.
MesloLGS Nerd Font is installed in the user's font directory and selected only by the dedicated
Quickshell, Kitty and terminal configurations. Existing `~/.config/quickshell/dwl`
and `/usr/local/bin/dwl` paths are not replaced.

The installer also installs Dolphin, Okular, Gwenview, Kate, VLC, Merkuro,
KWallet and the KDE account/calendar infrastructure, plus
Fastfetch, Kitty, Starship and OnlyOffice. OnlyOffice is installed from Flathub.
Install Brave and Visual Studio Code separately if you want to use their
dedicated shortcuts; the installer does not install either application.

After installation, log out. In SDDM select:

```text
buchhwin
```

This branch is intended for a Fedora KDE installation. Do not run it as an
in-place GNOME-to-KDE conversion. The preserved `gnome-final` tag remains the
recovery point for the previous GNOME-based installer.

Then verify the installation with:

```bash
buchhwin-doctor
```

The doctor verifies the compositor, SceneFX/wlroots runtime, XWayland support,
the Nerd Font, the KDE polkit agent and that a Plasma fallback session exists.

## What is not copied

The repository contains desktop code and neutral defaults only. It does not
contain or copy passwords, keyrings, browser profiles, SSH/GPG keys, Wi-Fi
credentials, KDE Online Accounts, KWallet data, calendar contents, clipboard history,
display profiles, personal wallpapers, documents or shell history. Sign into
your accounts and select machine-specific display/wallpaper settings after a
fresh installation.

## KDE accounts and calendars

Open **Settings → Hardware → Online accounts** to add Google and other cloud
accounts through KDE. Open Merkuro once to select or add its Akonadi calendar
resources. The calendar popup in the top bar reads and edits those same
calendars through KDE's `konsolekalendar`; it does not keep a second calendar
database. Dolphin accesses Google Drive through KDE's `kio-gdrive` integration.

## Main keybindings

| Shortcut | Action |
|---|---|
| `Super + Enter` | Terminal (Kitty) |
| `Super + D` | Application launcher |
| `Super + B` | Brave browser |
| `Super + E` | Files (Dolphin) |
| `Super + C` | Visual Studio Code |
| `Super + Shift + C` | Control Center |
| `Super + S` | Region screenshot |
| `Super + Shift + S` | Settings |
| `Super + V` | Clipboard history |
| `Super + N` | Notification center |
| `Super + M` | Power menu |
| `Super + L` | Lock screen |
| `Super + F1` | Keybind viewer |
| `Super + Q` | Close focused window |
| `Super + J / K` | Focus next / previous window |
| `Super + Left / Right` | Shrink / grow master area |
| `Super + Up / Down` | Top/bottom layout; move its divider |
| `Super + Shift + Enter` | Promote focused window to master |
| `Super + T` | Tiled layout |
| `Super + F` | Floating layout |
| `Super + Shift + M` | Monocle layout |
| `Super + Space` | Cycle layout |
| `Super + Alt + Space` | Switch side-by-side / top-and-bottom tiling |
| `Super + Shift + Space` | Toggle focused window floating |
| `Super + Shift + F` | Fullscreen |
| `Super + 1..9` | Switch tag |
| `Super + Shift + 1..9` | Move window to tag |
| `Super + Ctrl + 1..9` | Toggle tag |
| `Super + , / .` | Focus left / right monitor |
| `Super + Shift + , / .` | Move window to monitor |
| `Super + Print` | Region screenshot |
| `Super + Shift + Print` | Full-screen screenshot |
| `Super + Ctrl + Print` | Screenshot editor |
| `Super + Shift + Q` | Exit compositor |

Full list: [`docs/KEYBINDS.md`](docs/KEYBINDS.md)

## Window resizing with the mouse

The normal dwl mouse workflow remains available:

- `Super + Left Mouse` — move floating window
- `Super + Right Mouse` — resize floating window
- `Super + Middle Mouse` — toggle floating

For tiled windows, `Super+Left` shrinks and `Super+Right` grows the master area.

## Settings without external programs

`Super+Shift+S` opens Settings; `Super+Shift+C` opens the Control Center.
Both lead into panels the shell implements itself:

| Panel | Backed by | Replaces |
|---|---|---|
| Network | `nmcli` | `nm-connection-editor` |
| Bluetooth | `buchhwin-btctl` → `bluetoothctl` | `blueman` |
| Sound | `buchhwin-audioctl` → `pactl` | `pavucontrol` |
| Displays | `buchhwin-displays` → `wdisplays` | — |

**Enterprise Wi-Fi (eduroam and similar)** is the one deliberate exception.
Creating an 802.1X profile needs certificate and identity handling that belongs
in a full editor, so create it once in the Plasma session. NetworkManager stores
it system-wide, and it then appears under *Saved connections* in the Wi-Fi
panel, one click from connecting.

## Configuration

User settings live here after installation:

```text
~/.config/buchhwin-dwl/settings.env
```

Defaults:

```bash
BROWSER=brave
WALLPAPER_COLOR=#11111b
WALLPAPER=$HOME/.config/buchhwin-dwl/wallpapers/buchhwin-default.png
SCREENSHOT_DIR=$HOME/Pictures/Screenshots
KEYBOARD_LAYOUT=de
LOAD_ZSH_CONFIG=1
```

`BROWSER=brave` selects a separately installed Brave. The helper supports both
native and Flatpak installations and falls back to other available browsers.

`WALLPAPER` accepts an absolute image path or a path beginning with `$HOME`.
When that image cannot be read, `WALLPAPER_COLOR` is used instead. Run the
update installer after changing repository defaults; personal values in
`settings.env` remain preserved.

Kitty is launched with buchhwin's separate configuration at
`~/.config/buchhwin-dwl/kitty.conf`. This gives the dwl session its gray
theme, transparency and MesloLGS Nerd Font Mono without modifying `~/.config/kitty` or
Plasma's terminal and font settings.

The session uses a dedicated Zsh configuration in
`~/.config/buchhwin-dwl/zsh`. Personal shell files and secrets are not loaded.

Open **Settings → Appearance → Fastfetch image → Choose image** to select
the terminal's Fastfetch image independently of the wallpaper. The preview
shows your selection; open a new terminal to see it in Fastfetch. Updates
preserve this choice. Keep the selected image file at its saved location.

The same Appearance page controls dwl-only theme presets, accent/background/
bar/text colors, the shell Nerd Font and top/bottom/left/right bar position.
These values are isolated from Plasma and do not modify KDE's theme or fonts.

The Terminal settings include common 12/24-hour clock formats and a switch for
showing Fastfetch when a terminal opens. Manual `fastfetch` and `ff` remain
available when the startup display is disabled.

The Hardware page controls automatic locking, display power saving, suspend
and a location-aware night light. These services run only in the buchhwin dwl
session. The notification centre includes a do-not-disturb switch, and the bar
shows StatusNotifier tray icons from applications such as Citrix or KDE tools.

After changing a setting that affects the compositor, rebuild/install it with:

```bash
./update.sh
```

### Displays and scaling

Open **Settings → Displays** with `Super+Shift+S`. Arrange screens, select their
rotation and set fractional scaling in the graphical editor, then close it.
buchhwin saves the resulting per-computer layout in:

```text
~/.config/buchhwin-dwl/display-profile.json
```

The profile is restored at login. On another computer buchhwin first uses a
safe automatic layout because output names and modes vary between machines;
create a profile there from Settings. If a dock profile is used without its
external screens, its safety check leaves the available laptop panel enabled.

### Clipboard history

`Super+V` opens searchable clipboard history. Text and images are stored
locally by `cliphist`; nothing is uploaded. Clear the history from that window
after copying passwords or other confidential values.

## File layout

```text
fedora-dwl/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   └── workflows/
├── bin/
│   └── buchhwin-session
├── config/
│   ├── quickshell/
│   │   └── buchhwin/
│   │       ├── shell.qml
│   │       ├── Theme.qml
│   │       ├── Bar.qml
│   │       ├── Launcher.qml
│   │       ├── ControlCenter.qml
│   │       ├── NetworkPanel.qml
│   │       ├── BluetoothPanel.qml
│   │       ├── AudioPanel.qml
│   │       ├── NotificationService.qml
│   │       ├── NotificationCenter.qml
│   │       ├── NotificationPopups.qml
│   │       ├── PowerMenu.qml
│   │       ├── Keybinds.qml
│   │       ├── ClipboardHistory.qml
│   │       └── Settings.qml
│   ├── xdg-desktop-portal/
│   │   └── buchhwin-portals.conf
│   ├── alacritty.toml
│   └── settings.env
├── assets/
│   └── wallpapers/
│       └── buchhwin-default.png
├── docs/
│   ├── KEYBINDS.md
│   └── TROUBLESHOOTING.md
├── scripts/
│   ├── session.py
│   ├── display_profile.py
│   ├── patch-dwl-config.py
│   ├── build-dwl-fedora.sh
│   ├── check-repo.sh
│   ├── check-qml.py
│   └── buchhwin-*
├── session/
│   └── buchhwin.desktop
├── install-fedora.sh
├── update.sh
├── uninstall.sh
├── Makefile
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
├── NOTICE.md
└── LICENSE
```

## How the dwl / Quickshell integration works

No old dwl IPC patch is required for the bar state.

The compositor is started as:

```bash
dwl-buchhwin -s ~/.config/buchhwin-dwl/session.py
```

Modern dwl sends monitor state to the process supplied via `-s`. `session.py` continuously consumes that stream and writes a tiny JSON state file to:

```text
$XDG_RUNTIME_DIR/buchhwin-dwl-state.json
```

Quickshell watches that file and uses it for:

- active tags
- occupied tags
- urgent tags
- active layout
- focused app ID
- focused window title

This keeps the compositor side small and avoids carrying a stale IPC patch just to render the panel.

`session.py` also supervises Quickshell. If the shell crashes, dwl keeps
handling windows and keybindings but nothing is visible — so the shell is
restarted automatically, with a crash-loop cap that stops retrying and prints
the command to run by hand.

## Current limitations

- The tag pills in the Quickshell bar are status indicators. Switch tags with the native dwl shortcuts (`Super + 1..9`). This intentionally avoids carrying a stale compositor IPC patch just for mouse clicks.
- Enterprise (802.1X) Wi-Fi profiles are created in Plasma, not in the shell.
- The repository is statically checked in CI, but a real Wayland session still has to be tested on the target machine because GPU/input/display behavior cannot be reproduced in GitHub Actions.

## Update

From the repository directory:

```bash
./update.sh
```

If the repo has a clean Git working tree and an `origin`, the script first runs a fast-forward-only pull. User `settings.env` is preserved.

## Uninstall

```bash
./uninstall.sh
```

The uninstaller removes project-owned files and installed compositor/session
binaries. It intentionally does **not** remove shared Fedora packages,
application data, accounts or the Nerd Font.

## Backups

On a normal first install, conflicting project-owned config paths are backed up under:

```text
~/.local/state/buchhwin-dwl/backups/
```

## Development

Run repository checks with:

```bash
make check
```

The checks validate shell syntax, Python syntax, QML delimiter structure and
font usage, required QML files, shell references, the Fedora package set, the
absence of reintroduced external configuration programs, branding, and the dwl
config patcher against a v0.8-shaped fixture.

## Troubleshooting

See [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md).

## Upstream projects and inspiration

- [dwl](https://codeberg.org/dwl/dwl) — Wayland compositor
- [Quickshell](https://quickshell.org/) — desktop shell toolkit
- The workflow/visual direction was inspired in part by ChrisTitusTech's `dwm-titus`, while the code and Wayland architecture in this repository are independently implemented.

See [`NOTICE.md`](NOTICE.md) for details.

## License

Original code in this repository is available under the MIT License. Upstream projects retain their own licenses.
