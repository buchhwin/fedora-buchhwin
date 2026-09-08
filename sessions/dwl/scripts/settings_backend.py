#!/usr/bin/env python3
"""Backend for integrated application, defaults, and Starship settings."""
from __future__ import annotations

import configparser
import json
import os
import re
import subprocess
import sys
from pathlib import Path

home = Path.home()
config_home = Path(os.environ.get("XDG_CONFIG_HOME", home / ".config"))
state_dir = config_home / "buchhwin-dwl"
starship_file = state_dir / "starship.toml"
fastfetch_startup_file = state_dir / "fastfetch-on-start"
keybind_file = state_dir / "keybinds.json"

MIMES = {
    "Text": "text/plain", "Web": "x-scheme-handler/https",
    "Images": "image/png", "PDF": "application/pdf",
    "Audio": "audio/mpeg", "Video": "video/mp4",
}

KEYBINDS = [
    ("terminal", "Terminal", "Super", "Return"), ("launcher", "App launcher", "Super", "d"),
    ("browser", "Web browser", "Super", "b"), ("files", "Files", "Super", "e"),
    ("code", "VS Code", "Super", "c"), ("settings", "Settings", "Super+Shift", "s"),
    ("notifications", "Notifications", "Super", "n"), ("power", "Power menu", "Super", "m"),
    ("lock", "Lock screen", "Super", "l"), ("clipboard", "Clipboard", "Super", "v"),
    ("screenshot", "Region screenshot", "Super", "Print"), ("close", "Close window", "Super", "q"),
    ("focus_next", "Focus next window", "Super", "j"), ("focus_previous", "Focus previous window", "Super", "k"),
    ("resize_left", "Resize left", "Super", "Left"), ("resize_right", "Resize right", "Super", "Right"),
    ("resize_up", "Horizontal layout / resize up", "Super", "Up"), ("resize_down", "Horizontal layout / resize down", "Super", "Down"),
    ("tile", "Tiled layout", "Super", "t"), ("monocle", "Monocle layout", "Super", "f"),
    ("layout_orientation", "Switch side-by-side / top-and-bottom", "Super+Alt", "space"),
    ("floating", "Toggle floating", "Super+Shift", "space"), ("fullscreen", "Toggle fullscreen", "Super+Shift", "f"),
]
VALID_MODIFIERS = {"Super", "Super+Shift", "Super+Ctrl", "Super+Alt"}

# Bindings which are compiled into the buchhwin dwl profile but are not yet
# safe to rewrite independently (workspace bindings are generated as a macro,
# while media/brightness and VT keys are deliberately kept unmodified).
FIXED_KEYBINDS = [
    ("control_center", "Control Center", "Super+Shift", "c"),
    ("keybind_viewer", "Keybind viewer", "Super", "F1"),
    ("master_more", "Increase master window count", "Super", "i"),
    ("master_less", "Decrease master window count", "Super+Shift", "i"),
    ("promote_master", "Promote focused window to master", "Super+Shift", "Return"),
    ("previous_workspace", "Return to previous workspace view", "Super", "Tab"),
    ("all_workspaces", "Show all workspaces", "Super", "0"),
    ("move_all_workspaces", "Show window on all workspaces", "Super+Shift", "0"),
    ("cycle_layout", "Cycle layout", "Super", "space"),
    ("focus_monitor_left", "Focus monitor to the left", "Super", ","),
    ("focus_monitor_right", "Focus monitor to the right", "Super", "."),
    ("move_monitor_left", "Move window to monitor on the left", "Super+Shift", ","),
    ("move_monitor_right", "Move window to monitor on the right", "Super+Shift", "."),
    ("screenshot_print", "Region screenshot", "Super", "Print"),
    ("screenshot_full", "Full-screen screenshot", "Super+Shift", "Print"),
    ("screenshot_edit", "Screenshot editor", "Super+Ctrl", "Print"),
    ("audio_mute", "Mute audio", "None", "AudioMute"),
    ("audio_down", "Lower volume", "None", "AudioLowerVolume"),
    ("audio_up", "Raise volume", "None", "AudioRaiseVolume"),
    ("media_play", "Play or pause media", "None", "AudioPlay"),
    ("media_previous", "Previous track", "None", "AudioPrev"),
    ("media_next", "Next track", "None", "AudioNext"),
    ("brightness_down", "Lower display brightness", "None", "BrightnessDown"),
    ("brightness_up", "Raise display brightness", "None", "BrightnessUp"),
    ("quit_dwl", "Exit dwl-buchhwin", "Super+Shift", "q"),
    ("terminate_server", "Emergency compositor exit", "Ctrl+Alt", "TerminateServer"),
]


def desktop_files() -> dict[str, dict]:
    result: dict[str, dict] = {}
    roots = [Path("/usr/share/applications"), Path("/var/lib/flatpak/exports/share/applications"),
             home / ".local/share/applications"]
    for root in roots:
        if not root.is_dir():
            continue
        for path in root.glob("*.desktop"):
            parser = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                parser.read(path, encoding="utf-8")
                entry = parser["Desktop Entry"]
                if entry.get("NoDisplay", "false").lower() == "true":
                    continue
                result[path.name] = {"id": path.name, "name": entry.get("Name", path.stem),
                                     "mimes": entry.get("MimeType", "").split(";")}
            except Exception:
                continue
    return result


def applications() -> list[dict]:
    proc = subprocess.run(["flatpak", "list", "--app", "--columns=application,name,origin"],
                          text=True, capture_output=True, check=True)
    apps = []
    for line in proc.stdout.splitlines():
        fields = line.split("\t")
        if len(fields) >= 2:
            apps.append({"id": fields[0], "name": fields[1], "source": "Flatpak",
                         "origin": fields[2] if len(fields) > 2 else ""})
    protected = {"plasma-desktop", "plasma-workspace", "dolphin", "quickshell", "systemd", "NetworkManager"}
    seen = set()
    for desktop in Path("/usr/share/applications").glob("*.desktop"):
        try:
            parser = configparser.ConfigParser(interpolation=None, strict=False); parser.read(desktop)
            if parser.getboolean("Desktop Entry", "NoDisplay", fallback=False): continue
            name = parser.get("Desktop Entry", "Name", fallback=desktop.stem)
            query = subprocess.run(["rpm", "-qf", str(desktop), "--qf", "%{NAME}"], text=True, capture_output=True)
            package = query.stdout.strip()
            if query.returncode or not package or package in seen: continue
            seen.add(package)
            apps.append({"id": package, "name": name, "source": "RPM", "origin": "Fedora",
                         "protected": package in protected or package.startswith(("plasma-", "systemd", "NetworkManager", "dwl", "quickshell", "akonadi"))})
        except Exception: continue
    return sorted(apps, key=lambda app: app["name"].lower())


def keybinds() -> list[dict]:
    saved = {}
    if keybind_file.exists():
        try: saved = json.loads(keybind_file.read_text(encoding="utf-8"))
        except Exception: pass
    result = [{"id": ident, "label": label,
               "modifier": saved.get(ident, {}).get("modifier", modifier),
               "key": saved.get(ident, {}).get("key", key), "editable": True,
               "group": "Desktop"} for ident, label, modifier, key in KEYBINDS]
    result.extend({"id": ident, "label": label, "modifier": modifier,
                   "key": key, "editable": False, "group": "Desktop"}
                  for ident, label, modifier, key in FIXED_KEYBINDS)
    for number in range(1, 10):
        result.extend([
            {"id": f"workspace_{number}", "label": f"Switch to workspace {number}",
             "modifier": "Super", "key": str(number), "editable": False, "group": "Workspaces"},
            {"id": f"move_workspace_{number}", "label": f"Move window to workspace {number}",
             "modifier": "Super+Shift", "key": str(number), "editable": False, "group": "Workspaces"},
            {"id": f"toggle_workspace_{number}", "label": f"Toggle workspace {number}",
             "modifier": "Super+Ctrl", "key": str(number), "editable": False, "group": "Workspaces"},
            {"id": f"toggle_window_workspace_{number}", "label": f"Toggle window on workspace {number}",
             "modifier": "Super+Ctrl+Shift", "key": str(number), "editable": False, "group": "Workspaces"},
        ])
    result.extend({"id": f"vt_{number}", "label": f"Switch to virtual terminal {number}",
                   "modifier": "Ctrl+Alt", "key": f"F{number}", "editable": False,
                   "group": "System"} for number in range(1, 13))
    return result


def save_keybind(ident: str, modifier: str, key: str) -> None:
    if ident not in {row[0] for row in KEYBINDS} or modifier not in VALID_MODIFIERS or not re.fullmatch(r"[A-Za-z0-9_]+", key):
        raise ValueError("Invalid key binding")
    values = {row["id"]: {"modifier": row["modifier"], "key": row["key"]} for row in keybinds()}
    wanted = (modifier.lower(), key.lower())
    for other, value in values.items():
        if other != ident and (value["modifier"].lower(), value["key"].lower()) == wanted:
            raise ValueError(f"Conflict with {next(row[1] for row in KEYBINDS if row[0] == other)}")
    values[ident] = {"modifier": modifier, "key": key}
    state_dir.mkdir(parents=True, exist_ok=True)
    keybind_file.write_text(json.dumps(values, indent=2) + "\n", encoding="utf-8")


def defaults() -> list[dict]:
    entries = desktop_files()
    result = []
    for label, mime in MIMES.items():
        current = subprocess.run(["xdg-mime", "query", "default", mime], text=True,
                                 capture_output=True).stdout.strip()
        candidates = [entry for entry in entries.values() if mime in entry["mimes"]]
        candidates.sort(key=lambda entry: entry["name"].lower())
        result.append({"label": label, "mime": mime, "current": current,
                       "currentName": entries.get(current, {}).get("name", current or "Not set"),
                       "candidates": candidates})
    return result


def starship_state() -> dict:
    state = {
        "color": "#d0d0d0", "errorColor": "#f38ba8",
        "symbol": "❯", "errorSymbol": "❯", "directory": True,
        "directoryTruncation": 3, "git": True, "gitSymbol": "󰊢 ",
        "gitStatus": True, "python": False, "nodejs": False,
        "docker": False, "commandDuration": True, "durationMin": 1500,
        "jobs": True, "time": False, "timeFormat": "%H:%M",
        "username": False, "hostname": False, "twoLine": False,
        "newline": False, "previewGit": True, "startupFastfetch": True,
    }
    path = state_dir / "starship.json"
    if path.exists():
        try: state.update(json.loads(path.read_text()))
        except Exception: pass
    if fastfetch_startup_file.exists():
        state["startupFastfetch"] = fastfetch_startup_file.read_text().strip() != "0"
    return state


def write_starship(state: dict) -> None:
    state_dir.mkdir(parents=True, exist_ok=True)
    (state_dir / "starship.json").write_text(json.dumps(state, indent=2) + "\n")
    fastfetch_startup_file.write_text("1\n" if state["startupFastfetch"] else "0\n")
    modules = []
    if state["username"]: modules.append("$username")
    if state["hostname"]: modules.append("$hostname")
    if state["directory"]: modules.append("$directory")
    if state["git"]: modules.append("$git_branch")
    if state["gitStatus"]: modules.append("$git_status")
    if state["python"]: modules.append("$python")
    if state["nodejs"]: modules.append("$nodejs")
    if state["docker"]: modules.append("$docker_context")
    if state["commandDuration"]: modules.append("$cmd_duration")
    if state["jobs"]: modules.append("$jobs")
    if state["time"]: modules.append("$time")
    if state["twoLine"]: modules.append("$line_break")
    modules.append("$character")
    # Starship modules already include their own intentional trailing spacing.
    # Adding another separator here doubled or tripled the gap before the
    # character, especially when optional modules were disabled.
    format_value = "".join(modules)
    quote = lambda value: json.dumps(str(value), ensure_ascii=False)
    starship_file.write_text(
        f'add_newline = {str(bool(state["newline"])).lower()}\n'
        f'format = "{format_value}"\n\n'
        f'[character]\nsuccess_symbol = {quote(f"[{state["symbol"]}](bold {state["color"]})")}\n'
        f'error_symbol = {quote(f"[{state["errorSymbol"]}](bold {state["errorColor"]})")}\n\n'
        f'[directory]\nstyle = "bold {state["color"]}"\ntruncation_length = {int(state["directoryTruncation"])}\n\n'
        f'[git_branch]\nsymbol = {quote(state["gitSymbol"])}\nstyle = "bold {state["color"]}"\n\n'
        f'[git_status]\nstyle = "bold {state["errorColor"]}"\n\n'
        f'[cmd_duration]\nmin_time = {int(state["durationMin"])}\nstyle = "bold {state["color"]}"\n\n'
        f'[time]\ndisabled = false\ntime_format = {quote(state["timeFormat"])}\nstyle = "bold {state["color"]}"\n\n'
        f'[username]\nshow_always = true\nstyle_user = "bold {state["color"]}"\n\n'
        f'[hostname]\nssh_only = false\nstyle = "bold {state["color"]}"\n', encoding="utf-8")


def main() -> int:
    args = sys.argv[1:]
    if args == ["apps"]:
        print(json.dumps(applications(), ensure_ascii=False)); return 0
    if args == ["defaults"]:
        print(json.dumps(defaults(), ensure_ascii=False)); return 0
    if len(args) == 3 and args[0] == "default":
        subprocess.run(["xdg-mime", "default", args[2], args[1]], check=True); return 0
    if len(args) == 2 and args[0] == "uninstall-flatpak":
        subprocess.run(["flatpak", "uninstall", "--noninteractive", "--delete-data", args[1]], check=True); return 0
    if len(args) == 2 and args[0] == "uninstall-rpm":
        subprocess.run(["pkexec", "dnf", "remove", "-y", args[1]], check=True); return 0
    if args == ["keybinds"]:
        print(json.dumps(keybinds(), ensure_ascii=False)); return 0
    if len(args) == 4 and args[0] == "keybind-set":
        try: save_keybind(args[1], args[2], args[3])
        except ValueError as error: print(str(error), file=sys.stderr); return 2
        subprocess.run(["buchhwin-rebuild-keybinds"], check=True)
        print("Saved — active after the next dwl login"); return 0
    if args == ["starship"]:
        print(json.dumps(starship_state(), ensure_ascii=False)); return 0
    if len(args) == 3 and args[0] == "starship-set":
        state = starship_state(); key, raw = args[1], args[2]
        if key not in state: return 2
        if isinstance(state[key], bool):
            state[key] = raw == "true"
        elif isinstance(state[key], int):
            state[key] = max(1, min(999999, int(raw)))
        else:
            state[key] = raw.replace("\n", " ")[:32]
        write_starship(state); print(json.dumps(state)); return 0
    if args == ["starship-preview"]:
        env = os.environ.copy(); env["STARSHIP_CONFIG"] = str(starship_file)
        if not starship_file.exists(): write_starship(starship_state())
        preview_path = home / "Projects/fedora-dwl" if starship_state()["previewGit"] else home
        proc = subprocess.run(["starship", "prompt", "--path", str(preview_path),
                               "--logical-path", str(preview_path),
                               "--status", "0", "--terminal-width", "60"], env=env,
                              text=True, capture_output=True, check=True)
        # When the session shell is zsh, Starship wraps non-printing ANSI
        # sequences in `%{` and `%}`. Removing only ANSI left those wrappers
        # visibly scattered across the graphical preview.
        clean = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', proc.stdout)
        clean = clean.replace('%{', '').replace('%}', '').replace('\\[', '').replace('\\]', '')
        print(clean.strip("\n")); return 0
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
