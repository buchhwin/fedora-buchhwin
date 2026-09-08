# Fedora Buchhwin

One KDE-based home for the Buchhwin `dwl` and Hyprland sessions.

## Design

- Fedora KDE Plasma is the required base and remains the fallback desktop.
- SDDM remains the only display manager; this project only adds sessions.
- KDE provides Dolphin, Kate, Gwenview, Okular, KWallet, portals, network and
  Bluetooth management.
- Buchhwin does not install a greeter and does not provide a second Wi-Fi or
  Bluetooth manager.
- Compositor and shell settings use dedicated Buchhwin paths. The installer
  does not change Plasma's fonts, theme, MIME defaults or desktop settings.
- Hyprland state lives under
  `~/.config/buchhwin-sessions/hyprland`; `overrides.lua` and `shell.json` are
  user-owned and are never overwritten by an update.

## Install

Start on a regular Fedora KDE installation as your normal user:

```bash
git clone https://github.com/buchhwin/fedora-buchhwin.git
cd fedora-buchhwin
./install.sh
```

The menu offers:

1. dwl
2. Hyprland
3. both

For an unattended install:

```bash
./install.sh --session dwl
./install.sh --session hyprland
./install.sh --session both
```

After installation, log out and select `buchhwin` or `Buchhwin Hyprland` in
SDDM. Plasma remains available.

## Repository layout

```text
install.sh                 session selector
sessions/dwl/              simple dwl profile and its own shell/config
sessions/hyprland/         extensive Hyprland profile and its own shell/config
```

The two original repositories are upstream references and are not modified by
this combined repository.
