# Contributing

Pull requests are welcome.

Principles:

- Keep window management inside dwl.
- Keep visible desktop UI inside Quickshell.
- Avoid compositor patches unless a feature cannot be implemented cleanly
  outside dwl.
- Fedora 44 KDE Plasma is the supported platform; the shell drives Wi-Fi,
  Bluetooth and audio itself instead of shipping extra configuration programs.
- Never overwrite user configuration without making a backup.

Run `make check` before opening a pull request.
