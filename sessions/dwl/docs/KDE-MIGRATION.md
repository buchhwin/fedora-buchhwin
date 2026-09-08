# Moving from the GNOME base to KDE Plasma

The KDE edition is designed for a fresh Fedora 44 KDE installation. It keeps
the dwl/Quickshell desktop design but replaces its system integration and
default applications. It is not an in-place desktop conversion script.

1. Keep the current machine or a backup available until the new session has
   been tested.
2. Install Fedora KDE Plasma and complete the first Plasma login.
3. Clone the KDE branch and run the installer:

   ```bash
   git clone --branch kde-base https://github.com/buchhwin/fedora-dwl.git
   cd fedora-dwl
   ./install-fedora.sh --dry-run
   ./install-fedora.sh
   ```

4. In Plasma, add Google/cloud accounts in System Settings and open Merkuro
   once to configure its Akonadi calendars.
5. Log out and select the `buchhwin` session in SDDM.
6. Run `buchhwin-doctor` before copying any personal documents.

The installer does not copy accounts, KWallet contents, browser profiles,
Wi-Fi credentials, calendars, cloud files, personal wallpapers, display
profiles or documents. Plasma remains installed as the recovery session.
