# Troubleshooting

## Start from a TTY

For the first test, log into a TTY and run:

```bash
/usr/local/bin/buchhwin-session
```

If the compositor fails, the error remains visible in the terminal.

## Run the doctor

```bash
buchhwin-doctor
```

## Zsh configuration

The session imports `.zshenv`, `.zprofile`, and `.zshrc` by default. If a
prompt or terminal-only plugin prevents the graphical session from starting,
set the following in `~/.config/buchhwin-dwl/settings.env`:

```bash
LOAD_ZSH_CONFIG=0
```

Environment variables needed by graphical applications should ideally be
exported from `.zprofile`; aliases and prompt configuration can stay in
`.zshrc`.

## Quickshell only

Inside any working Wayland session you can inspect the shell configuration with:

```bash
qs -c buchhwin
```

## Quickshell logs

```bash
qs log -c buchhwin
```

## Status bridge

While a buchhwin session is running, dwl status is converted to:

```bash
cat "$XDG_RUNTIME_DIR/buchhwin-dwl-state.json"
```

Changing tags or focus should update this file.

## Browser hotkey

`Super+B` first uses `BROWSER` from `~/.config/buchhwin-dwl/settings.env`, then the XDG default browser, then common browser executable names.

Example:

```bash
BROWSER=brave
```

## German keyboard

The default is `KEYBOARD_LAYOUT=de`. Change the setting and rerun:

```bash
./update.sh
```

## Black screen

Test from a TTY and inspect the compositor output. wlroots/NVIDIA behavior can depend on the installed driver generation and kernel. Do not blindly add environment variables from old guides; verify them for your current driver first.

## Portals / screen sharing

The install adds a desktop-specific portal preference using `xdg-desktop-portal-wlr` for screenshot/screencast and KDE for generic portals. Log out and back in after installation so user services receive the new desktop environment.

## Bar shows empty boxes instead of icons

The MesloLGS Nerd Font is missing. Check and reinstall it with:

```bash
fc-list | grep -i 'MesloLGS Nerd Font'
./install-fedora.sh
```

## No authentication dialogs

Mounting a USB stick does nothing, or NetworkManager refuses to save a system
connection: the polkit agent is not running. `buchhwin-doctor` reports this,
and `session.py` warns on stderr at session start. Install it with:

```bash
sudo dnf install polkit-kde
```

## Super+V shows an empty list

`cliphist` is missing. It is installed from Fedora's package repositories;
verify with:

```bash
command -v cliphist
```

## Citrix Workspace will not start

Citrix is not a native Wayland client and needs XWayland. Verify that the
compositor was built with it:

```bash
buchhwin-doctor | grep XWayland
```

If it is missing, rerun `./update.sh` so dwl is rebuilt with XWayland enabled.
Note that Citrix keeps its own certificate store; a university CA has to be
placed in `/opt/Citrix/ICAClient/keystore/cacerts/` followed by
`/opt/Citrix/ICAClient/util/ctx_rehash`.

## The shell disappeared but windows still work

Quickshell crashed. `session.py` restarts it automatically; if it crashed
repeatedly in a short window, the supervisor gives up and prints the command
to run by hand. Check the session's stderr, then:

```bash
qs -c buchhwin
```

## eduroam or another enterprise network

802.1X profiles are not created in the shell. Log into the Plasma session once
and add the connection there. NetworkManager stores it system-wide, and it
then appears under *Saved connections* in the Wi-Fi panel.

## Falling back to Plasma

dwl is an additional session, never the only one. If a buchhwin session will
not start, pick **Plasma (Wayland)** in SDDM and fix things from there. Keeping a working
fallback is the point of the setup.

## Recovering the desktop

Select Plasma in SDDM, open a terminal and run `./uninstall.sh` from the cloned
repository. Installer backups remain below
`~/.local/state/buchhwin-dwl/backups/`; the installer never removes Plasma.
