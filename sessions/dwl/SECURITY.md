# Security

This is a desktop configuration and installer, not a security boundary.
Review `install-fedora.sh` before running it. The installer uses `sudo` for Fedora
package installation and for files installed under `/usr/local` and
`/usr/share/wayland-sessions`.

## Third-party sources

The installer downloads software from outside Fedora's archive. Each of these
is a trust decision worth making consciously:

- **Flathub** supplies Brave, Visual Studio Code and OnlyOffice as user-local
  Flatpaks. Their application data is not part of this repository.
- **MesloLGS Nerd Font** is downloaded from the `ryanoasis/nerd-fonts` GitHub
  release and unpacked into `~/.local/share/fonts`. Fedora does not package
  Nerd Fonts, and the shell's icons depend on it.
- **dwl**, **SceneFX** and the dwl SceneFX patch collection are cloned at pinned
  commits and built locally.
- **Starship** is downloaded as a pinned release archive and installed into
  `~/.local/bin`.

Weather information requires network access at runtime. Clipboard history and
all shell settings stay local; no personal data is committed by the installer.

For security-sensitive issues, contact the repository owner privately rather
than posting exploit details publicly.
