# shellcheck shell=bash
# Sourced by install.sh, never executed — so there is no shebang, and the
# directive above is how shellcheck is told which shell to assume.
# Phase: services — four units, down from the previous project's thirteen.
# Everything else that used to need a daemon is inside the shell.
phase_services() {
    section "Services"
    local u="$CONFIG_HOME/systemd/user"
    mkdir -p "$u"

    # ⚠️ SYSTEM SERVICES THE SHELL ALREADY HAS AN INTERFACE FOR. Each of these
    # was found by comparing against the predecessor, and each is the same
    # shape: a panel in the shell, and nothing running behind it.
    #
    #   bluetooth  services/Bt.qml and ui/quick/BluetoothList.qml have shipped
    #              since M4. Fedora Workstation starts bluez; Server does not.
    #   udisks2    mounting a USB stick without a password. ⚠️ NOT automount:
    #              that needs a client sitting in the session, and the two that
    #              exist are GTK or Python, both of which this project does not
    #              take. The file manager mounts on click, which is the honest
    #              half — said here rather than left to be discovered.
    #   oomd       kills the one runaway process instead of letting the machine
    #              swap itself to a standstill. On a laptop that is the
    #              difference between a lost tab and a lost session.
    #   tuned-ppd  Fedora's power profiles since F41 — it replaced
    #              power-profiles-daemon, and the desktop's own power menu talks
    #              to that D-Bus name. Not tlp: the two collide, and which one
    #              wins is not decided here but measured on the laptop (M10).
    step "system services"
    # ⚠️ cups AND avahi WERE ENABLED HERE AND ARE NOT ANY MORE. Neither package
    # is installed now — printing and .local name resolution are things a person
    # adds, not things a window manager decides. The guard below would have
    # skipped them silently, which is worse than removing them: a list naming
    # units that can never exist reads as a promise the installer is keeping.
    for unit in udisks2.service systemd-oomd.service tuned-ppd.service; do
        if systemctl list-unit-files "$unit" >/dev/null 2>&1 \
           && ! systemctl is-enabled --quiet "$unit" 2>/dev/null; then
            sudo systemctl enable --now "$unit" >/dev/null 2>&1 \
                && ok "$unit enabled" || warn "$unit could not be enabled"
        fi
    done

    # ⚠️ THERE IS EXACTLY ONE KEYRING ON THIS MACHINE AND IT IS KWallet.
    #
    # The comment that stood here said gnome-keyring was installed and needed
    # wiring into PAM. It is not installed, it is forbidden by the repository
    # checks, and wiring a second secret service into PAM next to KWallet is how
    # you get two password prompts at login and half your credentials in each.
    #
    # Fedora KDE owns SDDM's PAM stack and KWallet unlocks with the login
    # password through it. This session adds nothing: no PAM file is patched, no
    # second secret service is started. KeePassXC, if you install it, must have
    # its own Secret Service integration left switched OFF for the same reason.

    # ------------------------------------------------------ privileges, none
    #
    # WARNING: THIS SECTION USED TO INSTALL A ROOT BINARY AND TWO POLKIT FILES,
    # AND ALL THREE ARE GONE.
    #
    #   /usr/libexec/buchhwin-charge         a setuid-adjacent helper that wrote
    #                                        battery charge thresholds into sysfs
    #   /etc/polkit-1/rules.d/49-buchhwin.rules
    #   /usr/share/polkit-1/actions/org.buchhwin.policy
    #                                        the rule that let it run without a
    #                                        password prompt
    #
    # They existed for one feature: setting a laptop's charge start/stop
    # thresholds from the settings window. That is a nice feature. It is not
    # worth a root-owned executable and a password-free polkit rule on a machine
    # somebody works on, installed by a window manager, and the dwl session has
    # never had anything like it.
    #
    # The thresholds are still reachable, by the route that does not need any of
    # this — three files in sysfs, written with sudo when you actually want them:
    #
    #     echo 75 | sudo tee /sys/class/power_supply/BAT*/charge_control_start_threshold
    #     echo 80 | sudo tee /sys/class/power_supply/BAT*/charge_control_end_threshold
    #
    # The VPN switch shared the same polkit rule. It does not need it either:
    # NetworkManager already lets an active local session bring a connection up
    # and down, which is what services/Vpn.qml calls.

    # WARNING: THE JOURNAL CAP WENT WITH THEM. Capping the journal at 500M is a
    # sensible default and it is also a machine-wide decision about every log on
    # the system, taken while installing a desktop. If you want it:
    #
    #     sudo mkdir -p /etc/systemd/journald.conf.d
    #     sudoedit /etc/systemd/journald.conf.d/00-cap.conf
    #     ... containing a [Journal] section with SystemMaxUse=500M


    # ⚠️ THE LID IS THE ONE POWER SETTING THE SHELL CANNOT CARRY OUT. Idle,
    # locking and suspend are the shell's own, over ext-idle-notify — but the lid
    # has to work when the shell has crashed, is restarting, or was never
    # started, so logind owns it and logind is configured in /etc.
    #
    # Written here rather than left to the settings window, because a Power page
    # whose lid row only takes effect after somebody types `bhctl power apply`
    # is a row that does nothing on a fresh machine. `bhctl` is the one writer,
    # so the file has exactly one shape no matter who asked for it.
    if [[ -x "$REPO_DIR/bin/bhctl" ]]; then
        if "$REPO_DIR/bin/bhctl" power apply >/dev/null 2>&1; then
            ok "lid behaviour written for logind"
        else
            # Not fatal: a first install has no shell.json yet, and the defaults
            # in it are logind's own anyway.
            warn "could not write the lid behaviour — run: bhctl power apply"
        fi
    fi

    # ⚠️ THE KEYBOARD LAYOUT REACHES THE COMPOSITOR AND NOTHING ELSE. `input.keyboard.layout`
    # goes into the generated compositor config, which is the session — but the LOGIN
    # SCREEN and the TTY are not the session, and the login screen is where you
    # type your password FIRST. A German user on a US-layout greeter types the
    # password wrong before the desktop has started.
    # The Hyprland profile owns its keyboard layout. SDDM and the TTY keep the
    # layout selected by Fedora KDE; session installation never calls localectl.

    cat > "$u/buchhwin-shell.service" <<UNIT
[Unit]
Description=buchhwin shell (quickshell)
PartOf=graphical-session.target
After=graphical-session.target
# ⚠️ THESE THREE BELONG IN [Unit] AND WERE IN [Service], WHERE SYSTEMD IGNORES
# THEM. Measured on his laptop, in the journal at every start:
#   buchhwin-shell.service:27: Unknown key 'StartLimitIntervalSec' in section
#   [Service], ignoring.   ... and the same for 'OnFailure'.
# So the restart brake was OFF — a shell that crashes on startup would have
# looped for ever instead of stopping after five tries — and
# buchhwin-shell-failed.service, the terminal window whose whole job is to
# explain why the shell died, could NEVER fire. A unit with a handler nothing
# can reach is the same fault this project keeps finding one layer up.
StartLimitIntervalSec=60
StartLimitBurst=5
OnFailure=buchhwin-shell-failed.service

[Service]
Type=simple
# The backslash on the next line is load-bearing. This heredoc is unquoted,
# because ExecStartPre below needs REPO_DIR expanded — so an unescaped variable
# here is expanded by the INSTALLER, and two things go wrong at once: under
# `set -u` an unset one aborts the whole phase, and a set one bakes the
# installer's value into the unit so the condition can never change. The name
# has to reach the file literally and be evaluated when the unit starts.
#
# And this comment is inside the heredoc too, which is why it does not spell the
# variable out: writing it here unescaped reproduces the exact fault it warns
# about, and did.
ExecCondition=/bin/sh -c '[ "\$XDG_CURRENT_DESKTOP" = Hyprland ]'
# Quickshell never removes the instance directory a run leaves behind, and they
# live in a tmpfs. 407 of them, 15 MB of RAM, had accumulated on the test
# machine. Pruning here rather than on shutdown is deliberate: at this moment
# the previous instance is already gone, so "qs list" names only what is really
# alive. The leading minus means a failed cleanup can never stop the desktop
# from starting.
#
# NOTE for whoever edits this comment: it is inside an UNQUOTED heredoc, so
# backticks here are command substitution and would be RUN at install time.
# This very line used to say "qs list" in backticks and the installer executed
# it, printing "sh: -: command not found" and writing the empty result into the
# unit. Quotes here, never backticks -- and the delimiter stays unquoted
# because the ExecStartPre line below needs $REPO_DIR expanded.
ExecStartPre=-$REPO_DIR/bin/bhctl prune
ExecStart=/usr/bin/qs -c buchhwin
# A shell that dies takes the bar, the notch and every menu with it, so it
# comes back on its own — but not in a tight loop that would hide the cause.
Restart=always
RestartSec=2

[Install]
WantedBy=graphical-session.target
UNIT

    # When the shell is dead, notify-send is useless: the notification server
    # IS the dead thing. A terminal always works.
    cat > "$u/buchhwin-shell-failed.service" <<UNIT
[Unit]
Description=Explain why the buchhwin shell stopped

[Service]
Type=oneshot
ExecStart=/usr/bin/kitty --title "buchhwin shell failed" -- \
    sh -c "journalctl --user -u buchhwin-shell -n 60 --no-pager; echo; echo 'Press enter to close.'; read _"
UNIT

    # ⚠️ NOT ENABLED, ONLY WRITTEN. A mount that starts with the session on a
    # machine where nobody has signed in yet is a unit that fails at every
    # login and fills the journal with it. The tile starts it, and once it has
    # been started by hand `systemctl --user enable buchhwin-drive` is the
    # user's decision to make.
    #
    # ⚠️ `--vfs-cache-mode writes` IS NOT A TUNING KNOB, IT IS WHAT MAKES
    # EDITING WORK. Without it rclone cannot serve a file that is opened for
    # both reading and writing, which is what every editor and every office
    # program does — the mount looks fine and then refuses to save.
    cat > "$u/buchhwin-drive.service" <<UNIT
[Unit]
Description=Google Drive (rclone)
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStartPre=/usr/bin/mkdir -p %h/Drive
ExecStart=/usr/bin/rclone mount gdrive: %h/Drive \\
    --vfs-cache-mode writes \\
    --dir-cache-time 24h \\
    --umask 077
ExecStop=/bin/fusermount3 -uz %h/Drive
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
UNIT

    cat > "$u/buchhwin-clipboard.service" <<UNIT
[Unit]
Description=Clipboard history (cliphist), text
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=simple
ExecStart=/bin/sh -c '/usr/bin/wl-paste --type text --watch /usr/bin/cliphist store'
Restart=always

[Install]
WantedBy=graphical-session.target
UNIT

    # ⚠️⚠️ A SECOND WATCHER, AND IT IS NOT A NICETY. `wl-paste --watch` takes ONE
    # mime type, so the text watcher above is deaf to everything else — and what
    # it was deaf to is every screenshot.
    #
    # He asked for "kann man das auch so machen das man wenn man einen           # english-ok: the request, quoted
    # screenshot macht den direkt kopiert das wäre super", and the surprising    # english-ok: the request, quoted
    # half of the answer is that the compositor ALREADY DOES: its own wiki, in
    # Configuration:-Key-Bindings.md, says "The screenshot is both stored to the
    # clipboard and saved to disk". Pasting straight after Mod+S works today.
    #
    # What did not work is the part he would notice next: the screenshot never
    # reached OUR clipboard history, so it vanished from the panel the moment he
    # copied a line of text. One missing watcher, invisible from either side.
    cat > "$u/buchhwin-clipboard-image.service" <<UNIT
[Unit]
Description=Clipboard history (cliphist), images
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=simple
ExecStart=/bin/sh -c '/usr/bin/wl-paste --type image --watch /usr/bin/cliphist store'
Restart=always

[Install]
WantedBy=graphical-session.target
UNIT

    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable buchhwin-shell.service buchhwin-clipboard.service \
                            buchhwin-clipboard-image.service >/dev/null 2>&1 \
        || warn "could not enable the user services (no session yet is normal)"
    ok "5 user units written; the drive mount is written but not enabled"
}
