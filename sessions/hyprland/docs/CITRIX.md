# Citrix Workspace App

Citrix is the one place this desktop knowingly gives up its "Wayland only"
rule. That is a vendor constraint, not a design choice, and this page says
exactly what it costs so nobody discovers it during a work call.

## The constraint, in Citrix's own words

> **X11 or X.Org (Wayland isn't supported)**
> — [System requirements, Citrix Workspace app for Linux](https://docs.citrix.com/en-us/citrix-workspace-app-for-linux/system-requirements.html)

There is no Wayland backend and none announced. On this desktop Citrix
therefore runs under **XWayland**, and XWayland is installed **for Citrix
alone**. `bhctl doctor` lists every window still using XWayland, so the
exception stays visible rather than quietly spreading.

Two further facts worth knowing before you rely on it:

- **Fedora is not a supported platform.** Citrix supports RHEL, Ubuntu,
  Debian, openSUSE and Raspberry Pi OS. It installs and runs on Fedora, but
  you are outside the tested matrix.
- **Teams optimization is documented as "supported only on Ubuntu 20.04 or
  later".** It generally works elsewhere; it is simply not promised.

## Installation — by hand, on purpose

**The installer does not do this and will not.** Citrix is a normal RPM, so it
installs natively — but it is not *in a repository*: it lives only on
citrix.com behind an Akamai-signed URL that is regenerated on every page load
and expires after about an hour. There is no stable link a script can hardcode,
and `dnf install icaclient` will never work. An `--with citrix` option that
could only print "download it yourself" was a promise the installer did not
keep, so it was removed rather than left standing.

The four steps, in order:

    # 1. the real dependencies, all of them in Fedora 44 (see below)
    sudo dnf install gtk2 libcanberra-gtk2 libXaw libXp libsoup speex \
        libcxx libcxxabi libunwind libsecret libvorbis libxml2 \
        gstreamer1 gstreamer1-plugins-base gstreamer1-plugins-good \
        libva alsa-lib pulseaudio-libs wget

    # 2. the client itself — --nodeps for the reason given below
    sudo rpm -i --nodeps ~/Downloads/ICAClient-rhel-gcc-8-*.rpm

    # 3. unpack the bundled WebKit the Self-Service GUI needs
    sudo /opt/Citrix/ICAClient/util/integrate.sh install

    # 4. check what is now going through XWayland
    bhctl doctor

Current package, verified 2026-08-04:

    ICAClient-rhel-gcc-8-26.04.0.105-0.x86_64.rpm     ~405 MB   the client
    ctxusb-gcc-8-26.04.0.105-1.x86_64.rpm                       USB redirection
    ctxappprotection-gcc-8-26.04.0.105-0.x86_64.rpm             App Protection

Download page:
<https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html>

### Why it must be installed with `--nodeps`

Fedora 44 no longer ships `webkit2gtk4.0`; only `webkit2gtk4.1` exists, and
the RPM asks for `libwebkit2gtk-4.0.so.37`. Citrix bundles its own copy at
`/opt/Citrix/ICAClient/Webkit2gtk4.0/webkit2gtk-4.0.tar.gz`, which
`integrate.sh` unpacks — so installing with `rpm -i --nodeps` and letting the
bundled WebKit serve the Self-Service GUI is the clean route, not a hack
around a broken package. Only `selfservice` and the `wfica` dialog use WebKit
at all; sessions launched from a browser never touch it.

This is why step 1 above exists: the real dependencies are installed normally
first, and `--nodeps` then skips only the one requirement Fedora genuinely
cannot satisfy. Installing with `--nodeps` and nothing else would give you a
client that starts and then fails somewhere less obvious.

## Teams optimization

`HdxRtcEngine` is the media engine that runs on this machine and takes Teams
audio and video out of the remote session. It ships **inside** the Workspace
App — there is nothing extra to install. Minimum client version is 2006; 2604
is far past that.

## What to expect, honestly

| | |
|---|---|
| **Multi-monitor** | Known broken under Wayland: the first screen is shown on both monitors. Works on X11. |
| **Clipboard** | Unreliable. Citrix writes the clipboard on focus loss, and an X11 client under Wayland is not always told it lost focus. Switching windows manually usually flushes it. |
| **HiDPI** | Citrix's DPI matching supports GNOME, KDE and Xfce only. niri is none of those, so expect XWayland's upscale on a HiDPI screen. |
| **Sharing your local screen from an optimized Teams call** | **Unverified, and structurally doubtful.** An X11 client under XWayland cannot see native Wayland surfaces. Citrix's documentation says nothing either way. Test it before you need it in a meeting. Sharing content from *inside* the Citrix session is unaffected. |

## The lighter alternative: Workspace for Web (HTML5)

If your Citrix environment exposes **Workspace for Web**, the HTML5 client in
Chrome is the better fit for this desktop: Chrome runs Wayland-native, screen
capture goes through `xdg-desktop-portal` and PipeWire — so sharing a Wayland
window actually works — and **Teams optimization is supported there too**
(Chrome m97+).

Its limits: no USB redirection (that needs the `ctxusbd` system daemon, which
has no browser equivalent), and multi-monitor is weaker than the native
client.

Whether it is available is **not a local decision** — your IT has to enable it
on StoreFront or the Gateway. Worth asking, because if the answer is yes, this
machine can stay almost entirely free of XWayland.
