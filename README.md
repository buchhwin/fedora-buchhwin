# Fedora Buchhwin

One KDE-based home for the Buchhwin `dwl` and Hyprland sessions.

## Design

- Fedora KDE Plasma is the required base and remains the fallback desktop.
- SDDM remains the only display manager; this project only adds sessions.
- KDE provides Dolphin, Kate, Gwenview, Okular, KWallet, portals, network and
  Bluetooth management.
- Buchhwin does not install a greeter and does not install a second Wi-Fi or
  Bluetooth **application**. The Hyprland shell has its own network and
  Bluetooth panels in its quick panel — they drive NetworkManager and bluez
  directly, which is what makes the second application unnecessary rather than
  a duplication of it.
- The calendar is KDE's own. Appointments come from Akonadi through
  `konsolekalendar`, so whatever calendars you set up in KDE Settings are what
  the month shows — there is no second account manager.
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

## Documentation

| File | What it covers |
|---|---|
| `sessions/hyprland/docs/CONFIG.md` | every group in `shell.json`, and why the defaults are what they are |
| `sessions/hyprland/docs/HYPRLAND.md` | the compositor: Lua config, what is generated, what is hand-written |
| `sessions/hyprland/docs/KEYBINDS.md` | the shortcut list — **generated** from the bindings, and checked against them |
| `sessions/hyprland/docs/VPN.md` | the VPN tile and what it can and cannot do |
| `sessions/hyprland/CHANGELOG.md` | what changed, and what was measured to decide it |

## Checking a change

```bash
cd sessions/hyprland
bash tests/run.sh            # the whole suite; 0 = ok, 1 = failed, 2 = skipped
bash tests/run.sh pages lock # or just these
cd ../.. && bash tests/check-repo.sh
```

⚠️ **A skip is not a pass.** `tests/run.sh` prints the skipped checks by name at
the end, because a suite that skips nine of its checks and reports "0 failed" is
telling the truth in a way that reads like a lie. Most skips are honest: a check
that needs a Wayland session, a GPU or a program that is not installed cannot
ask its question in a container.
