#!/usr/bin/env python3
"""Create and modify events in KDE's Akonadi calendar store."""
from __future__ import annotations

import datetime as dt
import json
import os
import re
import subprocess
import sys


def run(arguments: list[str]) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["LC_ALL"] = "C.UTF-8"
    return subprocess.run(["konsolekalendar", *arguments],
                          text=True, capture_output=True, env=env)


def calendars() -> list[dict]:
    proc = run(["--list-calendars"])
    if proc.returncode:
        raise RuntimeError(proc.stderr.strip() or "Could not list Akonadi calendars")
    result = []
    # KDE releases vary the decoration around these two fields, so accept
    # either "Calendar 8: Personal" or the simpler "8 - Personal" form.
    for line in proc.stdout.splitlines():
        if "(Read only)" in line:
            continue
        match = re.search(r"(?:Calendar\s*)?(\d+)\s*[:\-]\s*(.+)", line, re.I)
        if match:
            result.append({"uid": match.group(1), "name": match.group(2).strip(), "online": True})
    if not result:
        result.append({"uid": "", "name": "Default calendar", "online": True})
    return result


def event_arguments(summary: str, start: str, end: str) -> list[str]:
    begin = dt.datetime.fromtimestamp(int(start))
    finish = dt.datetime.fromtimestamp(int(end))
    return ["--date", begin.strftime("%Y-%m-%d"), "--time", begin.strftime("%H:%M"),
            "--end-date", finish.strftime("%Y-%m-%d"), "--end-time", finish.strftime("%H:%M"),
            "--summary", summary]


def checked(arguments: list[str]) -> None:
    proc = run(arguments)
    if proc.returncode:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip() or "Calendar operation failed")


def main() -> int:
    if len(sys.argv) == 2 and sys.argv[1] == "calendars":
        print(json.dumps(calendars(), ensure_ascii=False))
        return 0
    if len(sys.argv) == 6 and sys.argv[1] == "create":
        _, _, calendar_id, summary, start, end = sys.argv
        arguments = ["--add"]
        if calendar_id:
            arguments += ["--calendar", calendar_id]
        checked(arguments + event_arguments(summary, start, end))
        return 0
    if len(sys.argv) == 6 and sys.argv[1] == "update":
        _, _, uid, summary, start, end = sys.argv
        checked(["--change", "--uid", uid] + event_arguments(summary, start, end))
        return 0
    print("usage: calendar_manage.py calendars|create|update ...", file=sys.stderr)
    return 2


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"Calendar: {error}", file=sys.stderr)
        raise SystemExit(1)
