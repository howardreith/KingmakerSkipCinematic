"""Align cutscene command starts (game time) between a normal and a skipped run to locate timing divergence.

Usage: python -I align_commands.py <normal-evidence> <skipped-evidence> [cutscene-name-filter]
Commands are matched by (cutscene, command asset, occurrence); times are relative to the first command of the cutscene.
"""
import json
import os
import sys
from collections import defaultdict


def starts(directory, name_filter):
    with open(os.path.join(directory, "timeline.json"), encoding="utf-8-sig") as handle:
        timeline = json.load(handle)
    result, seen, origin = [], defaultdict(int), {}
    for entry in timeline:
        if entry["kind"] != "cmd":
            continue
        detail = entry["detail"]
        if name_filter and name_filter not in detail["cutscene"]:
            continue
        key = (detail["cutscene"], detail["command"])
        seen[key] += 1
        origin.setdefault(detail["cutscene"], detail["game"])
        result.append(((detail["cutscene"], detail["command"], seen[key]), detail["type"], detail["game"] - origin[detail["cutscene"]]))
    return result


def main():
    name_filter = sys.argv[3] if len(sys.argv) > 3 else None
    normal = starts(sys.argv[1], name_filter)
    skipped = {key: time for key, _, time in starts(sys.argv[2], name_filter)}
    previous = 0.0
    for key, kind, time in normal:
        if key not in skipped:
            print("{0:>8.2f}  {1:<34} {2:<40} MISSING IN SKIPPED".format(time, kind, key[1]))
            continue
        drift = skipped[key] - time
        marker = " <-- +{0:.2f}".format(drift - previous) if drift - previous > 0.3 else ""
        print("{0:>8.2f} {1:>8.2f} {2:>+6.2f}  {3:<34} {4}{5}".format(time, skipped[key], drift, kind, key[1], marker))
        previous = drift


if __name__ == "__main__":
    main()
