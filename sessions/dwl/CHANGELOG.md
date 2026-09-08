# Changelog

## Unreleased

- Add a StatusNotifier system tray for background applications.
- Add dwl-only idle locking, display power, suspend and night-light controls.
- Add notification do-not-disturb and improve Settings sizing and scrolling.
- Stop hidden Settings pages from polling devices and serialize audio/network actions.
- Keep Wi-Fi passwords out of process arguments by sending them through stdin.
- Pin and verify downloaded Nerd Font and Starship archives, and fix the ARM64 Starship asset.
- Avoid unnecessary KonsoleKalendar portal registration warnings.
- Complete embedded sound settings with outputs, inputs and application streams.
- Add Super+Alt+Space to switch directly between side-by-side and top-and-bottom tiling.
- Remove the cryptic dwl layout symbol (such as `TTT`) from the bar while keeping all layout shortcuts available.
- Parse Fedora 44 KonsoleKalendar's ISO dates so Merkuro events appear.
- Embed Wi-Fi, Bluetooth and audio management directly in Settings → Connections.
- Increase launcher typography, spacing and app icon size for clearer scanning.
- Polish the Control Center battery card and remove duplicate connectivity shortcuts.
- Add a terminal-start Fastfetch switch and clearer clock-format presets.
- Make manual `fastfetch` use the dwl profile and add the `ff` shortcut.
- Add dwl-only theme presets, custom colors, Nerd Font selection and all four
  bar positions; improve weather alignment/location naming and battery hover.
- Add a Fastfetch image chooser and preview to Appearance settings, preserving
  the selected image when updating the installation.
- Enable Zsh completion, persistent history, autosuggestions and syntax highlighting.
- Start the dedicated Zsh/Starship profile explicitly in buchhwin terminals.
- Stop installing Brave and Visual Studio Code as Flatpaks; OnlyOffice remains.
- Fixed Fedora KDE 6 polkit agent discovery in the session and doctor.
- Fixed the KWallet Manager settings action to use Fedora's executable name.
- Recognize the Brave Flatpak in the doctor and launch it for `BROWSER=brave`.
- Preserve the user's Plasma default browser and file associations on install.

## 1.1.0 - 2026-09-07

- Added the Fedora KDE Plasma base and SDDM integration.
- Replaced GNOME applications, portals, accounts, keyring and calendar APIs
  with Dolphin, Okular, Gwenview, Kate, KWallet, KAccounts and Akonadi.
- Added Merkuro integration for the bar calendar.
- Made VLC the default audio and video player.
- Kept dwl, Quickshell and all existing shell panels and visual behavior.

## 1.0.0 - 2026-09-05

- Reproducible Fedora 44 / GNOME 50 installation from a clean checkout.
- Pinned dwl, SceneFX and compositor-patch source revisions.
- Separate GDM session which leaves the GNOME desktop configuration intact.
- Complete Quickshell bar, launcher, panels, calendar, media and settings UI.
- Native Wayland touchpad gestures, SceneFX blur and XWayland support.
- Dedicated Kitty, Fastfetch, Starship and Zsh profiles.
- GNOME default applications plus Brave, Visual Studio Code and OnlyOffice.
- No passwords, accounts, histories, device profiles or personal files.
