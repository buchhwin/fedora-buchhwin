#!/usr/bin/env python3
"""Read events from KDE's Akonadi calendar store via KonsoleKalendar."""
from __future__ import annotations

import csv
import datetime as dt
import json
import os
import subprocess
import sys


def parse_date(value: str, value_time: str) -> int:
    raw = value.strip()
    try:
        parsed = dt.datetime.strptime(raw, "%Y-%m-%d")
    except ValueError:
        # Older KonsoleKalendar releases emitted an English long date.
        parsed = dt.datetime.strptime(raw, "%A, %B %d, %Y")
    if value_time.strip() and value_time.strip().lower() != "float":
        parts = [int(part) for part in value_time.split(":")]
        parsed = parsed.replace(hour=parts[0], minute=parts[1],
                                second=parts[2] if len(parts) > 2 else 0)
    return int(parsed.astimezone().timestamp())


def main() -> int:
    if len(sys.argv) != 3:
        print("[]")
        return 2
    since, until = map(int, sys.argv[1:])
    start = dt.datetime.fromtimestamp(since).strftime("%Y-%m-%d")
    end = dt.datetime.fromtimestamp(until - 1).strftime("%Y-%m-%d")
    env = os.environ.copy()
    env["LC_ALL"] = "C.UTF-8"
    proc = subprocess.run(
        ["konsolekalendar", "--view", "--date", start,
         "--end-date", end, "--time", "00:00", "--end-time", "23:59",
         "--export-type", "CSV"], text=True, capture_output=True, env=env)
    if proc.returncode:
        print(proc.stderr.strip(), file=sys.stderr)
        print("[]")
        return proc.returncode
    events = []
    for row in csv.reader(proc.stdout.splitlines()):
        if len(row) < 8:
            continue
        try:
            event_start = parse_date(row[0], row[1])
            event_end = parse_date(row[2], row[3])
        except ValueError:
            continue
        all_day = not row[1].strip() or row[1].strip().lower() == "float"
        events.append({"id": row[7], "summary": row[4] or "Untitled event",
                       "start": event_start, "end": event_end,
                       "allDay": all_day, "color": ""})
    print(json.dumps(sorted(events, key=lambda event: event["start"]), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
