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
    #   cups       costs nothing until the first print job, and its absence is
    #              only discovered when you need to print.
    #   udisks2    mounting a USB stick without a password. ⚠️ NOT automount:
    #              that needs a client sitting in the session, and the two that
    #              exist are GTK or Python, both of which this project does not
    #              take. The file manager mounts on click, which is the honest
    #              half — said here rather than left to be discovered.
    #   avahi      .local names. Without it `ssh nas.local` does not resolve on
    #              a network where everything else finds it.
    #   oomd       kills the one runaway process instead of letting the machine
    #              swap itself to a standstill. On a laptop that is the
    #              difference between a lost tab and a lost session.
    #   tuned-ppd  Fedora's power profiles since F41 — it replaced
    #              power-profiles-daemon, and the desktop's own power menu talks
    #              to that D-Bus name. Not tlp: the two collide, and which one
    #              wins is not decided here but measured on the laptop (M10).
    step "system services"
    for unit in cups.socket udisks2.service avahi-daemon.service \
                systemd-oomd.service tuned-ppd.service; do
        if systemctl list-unit-files "$unit" >/dev/null 2>&1 \
           && ! systemctl is-enabled --quiet "$unit" 2>/dev/null; then
            sudo systemctl enable --now "$unit" >/dev/null 2>&1 \
                && ok "$unit enabled" || warn "$unit could not be enabled"
        fi
    done

    # ⚠️ THE KEYRING IS NOT UNLOCKED AT LOGIN WITHOUT THIS, and the symptom is a
    # second password prompt after every single login — plus network and cloud
    # mounts that stay disconnected. gnome-keyring is installed
    # (packages/dnf-desktop.txt) and was never wired into PAM; the predecessor
    # did exactly this and the rewrite left it behind.
    #
    # Idempotent, and it takes a backup: editing a PAM file badly is how a
    # machine stops accepting logins at all.
    # Fedora KDE owns SDDM's PAM stack and KWallet. Do not patch PAM or start a
    # parallel GNOME secret service from the Buchhwin session.

    # ------------------------------------------------------- privileges, twice
    #
    # ⚠️ TWO THINGS ON THIS DESKTOP NEED ROOT AND BOTH ARE SWITCHES, which is
    # the worst combination: a switch that silently waits on an invisible
    # password prompt is a switch that appears broken. He was asked and chose a
    # narrow polkit rule for the group `wheel` without a password, so both act
    # immediately.
    #
    # ⚠️ THE VPN NEEDS NOTHING OF OURS. NetworkManager already ships the action
    # org.freedesktop.NetworkManager.network-control — checked in its own policy
    # file rather than assumed — and a WireGuard tunnel is just a connection to
    # NM 1.56. One privilege that already exists beats one we invent, so all we
    # do is stop it asking. The handover that said this needs `wg-quick` and a
    # helper of our own was out of date.
    #
    # ⚠️ THE CHARGE THRESHOLDS DO NEED A HELPER, and it is deliberately the
    # smallest one that can work: two integers, validated, written to the two
    # sysfs files and nowhere else. `pkexec` with a shell one-liner would have
    # been shorter and is how privilege escalation goes wrong — the rule below
    # names a program, and the program cannot be talked into writing anywhere
    # but where it was built to write.
    sudo install -m 0755 /dev/stdin /usr/libexec/buchhwin-charge <<'HELPER'
#!/usr/bin/env bash
# Battery charge thresholds. Installed by buchhwin; called through polkit.
#
#   buchhwin-charge <start 0-100> <end 0-100>
#
# ⚠️ IT VALIDATES BEFORE IT WRITES, AND IT WRITES ONLY THESE TWO PATHS. This
# runs as root on behalf of a desktop user, so its whole job is to be
# uninteresting: two integers, a range check, an order check, and a glob that
# cannot leave /sys/class/power_supply.
set -euo pipefail
[[ $# -eq 2 ]] || { echo "usage: buchhwin-charge <start> <end>" >&2; exit 2; }
[[ $1 =~ ^[0-9]{1,3}$ && $2 =~ ^[0-9]{1,3}$ ]] || { echo "not two integers" >&2; exit 2; }
(( $1 <= 100 && $2 <= 100 )) || { echo "out of range" >&2; exit 2; }
(( $1 < $2 )) || { echo "start must be below end" >&2; exit 2; }

wrote=0
for bat in /sys/class/power_supply/BAT*; do
    [[ -d "$bat" ]] || continue
    # ⚠️ THE END THRESHOLD FIRST. Some firmware rejects a start value that would
    # sit above the current end, so writing start first fails on exactly the
    # machines where the change matters most.
    [[ -w "$bat/charge_control_end_threshold"   ]] && { echo "$2" > "$bat/charge_control_end_threshold";   wrote=1; }
    [[ -w "$bat/charge_control_start_threshold" ]] && { echo "$1" > "$bat/charge_control_start_threshold"; wrote=1; }
done
# ⚠️ NOT SILENT WHEN THERE IS NOTHING TO WRITE. Plenty of laptops have no
# thresholds at all, and "nothing happened" has to be distinguishable from
# "it worked" by whatever called this.
(( wrote )) || { echo "this machine exposes no charge thresholds" >&2; exit 3; }
HELPER

    sudo mkdir -p /etc/polkit-1/rules.d
    sudo tee /etc/polkit-1/rules.d/49-buchhwin.rules >/dev/null <<'RULES'
// Written by the buchhwin installer.
//
// Two narrow permissions for members of `wheel`, and nothing else:
//
//   * NetworkManager's own network-control, so the VPN switch acts at once
//     instead of waiting on a password prompt the desktop cannot show.
//   * org.buchhwin.charge-threshold, which runs /usr/libexec/buchhwin-charge
//     and can write two integers to two sysfs files.
//
// ⚠️ 49-, so it sorts BEFORE Fedora's own 50-default.rules. A rule that sorts
// after the default never gets asked.
polkit.addRule(function (action, subject) {
    if (!subject.isInGroup("wheel"))
        return polkit.Result.NOT_HANDLED;
    if (action.id == "org.freedesktop.NetworkManager.network-control" ||
        action.id == "org.buchhwin.charge-threshold")
        return polkit.Result.YES;
    return polkit.Result.NOT_HANDLED;
});
RULES

    sudo mkdir -p /usr/share/polkit-1/actions
    sudo tee /usr/share/polkit-1/actions/org.buchhwin.policy >/dev/null <<'ACTION'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD polkit Policy Configuration 1.0//EN"
 "http://www.freedesktop.org/software/polkit/policyconfig-1.dtd">
<policyconfig>
  <vendor>buchhwin</vendor>
  <action id="org.buchhwin.charge-threshold">
    <description>Set the battery charge thresholds</description>
    <message>Authentication is required to change the battery charge thresholds</message>
    <defaults>
      <allow_any>no</allow_any>
      <allow_inactive>no</allow_inactive>
      <allow_active>auth_admin_keep</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">/usr/libexec/buchhwin-charge</annotate>
    <annotate key="org.freedesktop.policykit.exec.allow_gui">true</annotate>
  </action>
</policyconfig>
ACTION
    ok "polkit: the VPN switch and the charge thresholds act without a prompt"

    # ⚠️ THE JOURNAL GROWS TO 10 % OF THE PARTITION BY DEFAULT. The predecessor
    # capped it after measuring 3.9 GB on one machine; the rewrite did not carry
    # the file across. A laptop with a small root filesystem notices.
    if [[ ! -f /etc/systemd/journald.conf.d/buchhwin.conf ]]; then
        sudo mkdir -p /etc/systemd/journald.conf.d
        sudo tee /etc/systemd/journald.conf.d/buchhwin.conf >/dev/null <<'JOURNAL'
# Generated by buchhwin. Without a cap the journal takes 10% of the partition.
[Journal]
SystemMaxUse=500M
SystemMaxFileSize=50M
MaxRetentionSec=1month
JOURNAL
        ok "journal capped at 500M"
    fi

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

    # ⚠️ THE KEYBOARD LAYOUT REACHES niri AND NOTHING ELSE. `input.keyboard.layout`
    # goes into the generated niri config, which is the session — but the LOGIN
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
ExecCondition=/bin/sh -c '[ "$XDG_CURRENT_DESKTOP" = Hyprland ]'
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
    # half of the answer is that niri ALREADY DOES: its own wiki, in
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
