#!/usr/bin/env python3
"""Consume dwl's native status stream and launch the buchhwin Quickshell."""
from __future__ import annotations

import json
import os
import shutil
import shlex
import signal
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

runtime = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp"))
state_path = runtime / "buchhwin-dwl-state.json"
state = {"outputs": {}}
children: list[subprocess.Popen] = []
running = True


def warn(message: str) -> None:
    print(f"buchhwin-dwl: {message}", file=sys.stderr, flush=True)


def output_state(name: str) -> dict:
    return state["outputs"].setdefault(name, {
        "title": "", "appid": "", "fullscreen": False, "floating": False,
        "selectedMonitor": False, "occupied": 0, "selectedTags": 1,
        "focusedTags": 0, "urgent": 0, "layout": "[]=",
    })


def write_state() -> None:
    state_path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=".buchhwin-dwl-", dir=state_path.parent)
    tmp = Path(tmp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(state, handle, ensure_ascii=False, separators=(",", ":"))
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp, state_path)
    finally:
        try:
            tmp.unlink()
        except FileNotFoundError:
            pass


def parse_status(line: str) -> None:
    line = line.rstrip("\n")
    if not line:
        return
    parts = line.split(" ", 2)
    if len(parts) < 2:
        return
    monitor, key = parts[0], parts[1]
    value = parts[2] if len(parts) == 3 else ""
    out = output_state(monitor)
    if key == "title":
        out["title"] = value
    elif key == "appid":
        out["appid"] = value
    elif key == "fullscreen":
        out["fullscreen"] = value.strip() == "1"
    elif key == "floating":
        out["floating"] = value.strip() == "1"
    elif key == "selmon":
        out["selectedMonitor"] = value.strip() == "1"
    elif key == "layout":
        out["layout"] = value.strip()
    elif key == "tags":
        fields = value.split()
        if len(fields) >= 4:
            try:
                out["occupied"] = int(fields[0], 0)
                out["selectedTags"] = int(fields[1], 0)
                out["focusedTags"] = int(fields[2], 0)
                out["urgent"] = int(fields[3], 0)
            except ValueError:
                pass


def spawn(command: list[str], quiet: bool = False) -> None:
    try:
        children.append(subprocess.Popen(
            command,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL if quiet else None,
            stderr=subprocess.DEVNULL if quiet else None,
            start_new_session=True,
        ))
    except FileNotFoundError:
        warn(f"command not found: {command[0]}")


def supervise(command: list[str], label: str, max_restarts: int = 5,
              window: float = 60.0) -> None:
    """Keep a process alive, but give up on a crash loop.

    Without this a Quickshell crash leaves a usable but completely invisible
    desktop: dwl still handles windows and keybindings, yet there is no bar,
    no launcher and no way to tell what happened.
    """
    attempts: list[float] = []
    while running:
        try:
            process = subprocess.Popen(command, stdin=subprocess.DEVNULL,
                                       start_new_session=True)
        except FileNotFoundError:
            warn(f"command not found: {command[0]}; {label} will not run")
            return
        children.append(process)
        process.wait()
        if not running:
            return
        try:
            children.remove(process)
        except ValueError:
            pass

        now = time.monotonic()
        attempts = [stamp for stamp in attempts if now - stamp < window]
        attempts.append(now)
        if len(attempts) > max_restarts:
            warn(f"{label} crashed {len(attempts)} times in {window:.0f}s; giving up. "
                 f"Start it by hand with: {' '.join(command)}")
            return
        warn(f"{label} exited with code {process.returncode}; restarting")
        time.sleep(1.0)


def shutdown(*_args) -> None:
    global running
    running = False
    for child in children:
        if child.poll() is None:
            child.terminate()
    for child in children:
        if child.poll() is None:
            try:
                child.wait(timeout=2)
            except subprocess.TimeoutExpired:
                child.kill()
    raise SystemExit(0)


signal.signal(signal.SIGTERM, shutdown)
signal.signal(signal.SIGINT, shutdown)
write_state()

subprocess.run(
    ["dbus-update-activation-environment", "--systemd",
     "WAYLAND_DISPLAY", "XDG_CURRENT_DESKTOP", "XDG_SESSION_TYPE", "PATH",
     "KDE_FULL_SESSION", "KDE_SESSION_VERSION", "XDG_MENU_PREFIX"],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
    check=False,
)

# Fedora's portal unit has Requisite=graphical-session.target. Minimal
# compositors do not activate it automatically as Plasma does.
subprocess.run(["systemctl", "--user", "start", "buchhwin-session.target"],
               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
subprocess.run(["systemctl", "--user", "start", "xdg-desktop-portal.service"],
               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)

# Merkuro uses Akonadi even though plasmashell is intentionally not part of
# this session. Starting it here makes the bar calendar and its editor share
# exactly the same local/online calendars as Merkuro.
if shutil.which("akonadictl"):
    spawn(["akonadictl", "start"], quiet=True)

# Apply a profile saved by the graphical display tool. The helper waits until
# dwl has announced its outputs, so this remains safe on a new or undocked PC.
spawn(["buchhwin-display-profile", "apply"], quiet=True)

wallpaper_color = "#181818"
config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
wallpaper_path = config_home / "buchhwin-dwl" / "wallpapers" / "buchhwin-default.png"
settings_file = config_home / "buchhwin-dwl" / "settings.env"
if settings_file.exists():
    for raw in settings_file.read_text(encoding="utf-8").splitlines():
        if raw.startswith("WALLPAPER_COLOR="):
            wallpaper_color = raw.split("=", 1)[1].strip().strip("'\"") or wallpaper_color
        elif raw.startswith("WALLPAPER="):
            try:
                values = shlex.split(raw.split("=", 1)[1].strip())
            except ValueError:
                values = []
            if values:
                wallpaper_path = Path(os.path.expandvars(os.path.expanduser(values[0])))

if shutil.which("buchhwin-wallpaper"):
    spawn(["buchhwin-wallpaper", "watch"], quiet=True)
elif wallpaper_path.is_file():
    spawn(["swaybg", "-i", str(wallpaper_path), "-m", "fill"], quiet=True)
else:
    warn(f"wallpaper not found: {wallpaper_path}; using color fallback")
    spawn(["swaybg", "-c", wallpaper_color], quiet=True)

# Super+V is backed by cliphist. Without it the clipboard window silently shows
# an empty list, which reads as a broken shell rather than a missing package.
if shutil.which("cliphist"):
    spawn(["wl-paste", "--type", "text", "--watch", "cliphist", "store"], quiet=True)
    spawn(["wl-paste", "--type", "image", "--watch", "cliphist", "store"], quiet=True)
else:
    warn("cliphist not found; clipboard history (Super+V) will stay empty")

spawn(["udiskie", "--automount", "--no-notify"], quiet=True)
spawn(["buchhwin-sessionctl", "apply"], quiet=True)

# Authorize location-aware components (currently the weather widget). GeoClue
# still controls access and the weather helper falls back to coarse IP lookup.
geoclue_agent = "/usr/libexec/geoclue-2.0/demos/agent"
if Path(geoclue_agent).exists():
    spawn([geoclue_agent], quiet=True)

# The polkit agent lives in a different place on every distribution, and a
# missing one is invisible: no authentication dialogs ever appear, which shows
# up later as "udisks will not mount" or "NetworkManager will not save a
# system connection".
polkit_candidates = (
    "/usr/libexec/kf6/polkit-kde-authentication-agent-1",              # Fedora KDE 6
    "/usr/libexec/polkit-kde-authentication-agent-1",                  # compatibility
    "/usr/lib/polkit-kde-authentication-agent-1",                      # compatibility
    "/usr/bin/lxpolkit",                                               # fallback
)
for candidate in polkit_candidates:
    if Path(candidate).exists():
        spawn([candidate], quiet=True)
        break
else:
    warn("no polkit authentication agent found; privileged actions such as "
         "mounting drives or saving system network connections will fail "
         "without a prompt. Install polkit-kde.")

# Quickshell is the entire visible desktop, so it is supervised rather than
# spawned once.
threading.Thread(target=supervise, args=(["qs", "-c", "buchhwin"], "Quickshell"),
                 daemon=True).start()

# dwl sends status to the process started with -s. Keep consuming it so the
# compositor never blocks on a full pipe.
for status_line in sys.stdin:
    parse_status(status_line)
    write_state()

shutdown()
