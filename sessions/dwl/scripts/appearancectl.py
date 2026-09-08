#!/usr/bin/env python3
"""Manage appearance values only for the isolated buchhwin session."""
from __future__ import annotations

import json
import configparser
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path

home = Path.home()
config = Path(os.environ.get("XDG_CONFIG_HOME", home / ".config"))
settings = config / "buchhwin-dwl" / "appearance.json"
shell = config / "quickshell" / "buchhwin" / "shell.qml"


def packs(kind: str) -> list[str]:
    roots = [home / ".local/share/icons", home / ".icons", Path("/usr/share/icons")]
    found = set()
    for root in roots:
        if not root.is_dir():
            continue
        for entry in root.iterdir():
            if not entry.is_dir() or not (entry / "index.theme").exists():
                continue
            if kind == "cursors" and not (entry / "cursors").is_dir():
                continue
            if kind == "icons":
                try:
                    parser = configparser.ConfigParser(interpolation=None, strict=False)
                    parser.read(entry / "index.theme", encoding="utf-8")
                    directories = parser.get("Icon Theme", "Directories", fallback="")
                    icon_dirs = [name.strip() for name in directories.split(",") if name.strip()]
                except Exception:
                    icon_dirs = []
                if not icon_dirs:
                    continue
            found.add(entry.name)
    return sorted(found, key=str.lower)


def state() -> dict:
    value = {"icons": "breeze-dark", "cursor": "breeze_cursors", "cursorSize": 24,
             "gaps": 8, "border": 1, "font": "MesloLGS Nerd Font Mono",
             "theme": "graphite", "accent": "#d0d0d0", "background": "#181818",
             "bar": "#242424", "text": "#eeeeee", "barPosition": "top", "barSize": 38}
    if settings.exists():
        value.update(json.loads(settings.read_text()))
    return value


def save(value: dict) -> None:
    settings.parent.mkdir(parents=True, exist_ok=True)
    settings.write_text(json.dumps(value, indent=2) + "\n")


def fonts() -> list[str]:
    """Return installed Nerd Font families so shell glyphs remain available."""
    try:
        output = subprocess.run(["fc-list", ":", "family"], text=True,
                                capture_output=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return ["MesloLGS Nerd Font Mono"]
    families = {name.strip() for line in output.splitlines() for name in line.split(",")
                if "Nerd Font" in name and name.strip()}
    return sorted(families, key=str.lower)


def main() -> int:
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "list":
        print(json.dumps({"state": state(), "icons": packs("icons"),
                          "cursors": packs("cursors"), "fonts": fonts()}, ensure_ascii=False))
        return 0
    if command == "env":
        value = state()
        print("export XCURSOR_THEME=" + shlex.quote(str(value["cursor"])))
        print("export XCURSOR_SIZE=" + shlex.quote(str(value["cursorSize"])))
        return 0
    if command == "set" and len(sys.argv) == 4:
        key, raw = sys.argv[2], sys.argv[3]
        value = state()
        if key not in ("icons", "cursor", "cursorSize", "gaps", "border", "font",
                       "theme", "accent", "background", "bar", "text", "barPosition", "barSize"):
            return 2
        if key in ("accent", "background", "bar", "text") and not re.fullmatch(r"#[0-9a-fA-F]{6}", raw):
            print("Use a color in #RRGGBB format", file=sys.stderr)
            return 2
        if key == "barPosition" and raw not in ("top", "bottom", "left", "right"):
            return 2
        presets = {
            "graphite": {"accent": "#d0d0d0", "background": "#181818", "bar": "#242424", "text": "#eeeeee"},
            "blue": {"accent": "#89b4fa", "background": "#11111b", "bar": "#181825", "text": "#cdd6f4"},
            "purple": {"accent": "#cba6f7", "background": "#11111b", "bar": "#1e1e2e", "text": "#cdd6f4"},
            "green": {"accent": "#a6e3a1", "background": "#101512", "bar": "#19201b", "text": "#e4ebe6"},
        }
        if key == "theme" and raw in presets:
            value.update(presets[raw])
        value[key] = int(raw) if key in ("cursorSize", "gaps", "border", "barSize") else raw
        save(value)
        if key == "icons" and shell.exists():
            text = shell.read_text()
            text = re.sub(r"^//@ pragma IconTheme .*?$", f"//@ pragma IconTheme {raw}", text, count=1, flags=re.M)
            shell.write_text(text)
            # IconTheme is a QML pragma and is evaluated when Quickshell loads
            # the configuration. session.py supervises Quickshell, so killing
            # this one instance gives us a safe, automatic hot restart.
            subprocess.Popen(
                ["pkill", "-TERM", "-f", "^qs -c buchhwin$"],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
        if key in ("gaps", "border"):
            subprocess.run(["buchhwin-rebuild-appearance"], check=True)
        if key in ("font", "theme", "accent", "background", "bar", "text", "barPosition", "barSize"):
            subprocess.run(["pkill", "-TERM", "-f", "^qs -c buchhwin$"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
            print("Appearance saved — the shell is reloading")
        elif key == "icons":
            print("Icon pack applied — the shell is reloading")
        elif key in ("cursor", "cursorSize"):
            print("Cursor saved — log out of dwl once to apply it everywhere")
        else:
            print("Applied")
        return 0
    print("usage: buchhwin-appearance list | set KEY VALUE", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
