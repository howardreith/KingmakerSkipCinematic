"""Compare the semantic state a normal run and a skipped run reached from the same save.

Usage: python -I compare_runs.py <normal-evidence-dir> <skipped-evidence-dir> [snapshot-label=boundary] [--position-tolerance=1.5]

Story state (quests, objectives, flags, party, inventory, money, dialogue position, unit presence and life state)
must match exactly. Positions are compared within a tolerance and reported; game-time elapsed since the "pre"
snapshot is reported for both runs so timing differences are visible rather than normalised away.
"""
import json
import os
import sys


def load(directory, label):
    with open(os.path.join(directory, "snapshot-" + label + ".json"), encoding="utf-8-sig") as handle:
        return json.load(handle)


def position(text):
    return [float(part) for part in text.split(",")]


def distance(a, b):
    pa, pb = position(a), position(b)
    return ((pa[0] - pb[0]) ** 2 + (pa[2] - pb[2]) ** 2) ** 0.5


def units_by_id(units):
    return {unit["id"]: unit for unit in units}


def main():
    normal_dir, skipped_dir = sys.argv[1], sys.argv[2]
    label = next((arg for arg in sys.argv[3:] if not arg.startswith("--")), "boundary")
    tolerance = 1.5
    for arg in sys.argv[3:]:
        if arg.startswith("--position-tolerance="):
            tolerance = float(arg.split("=", 1)[1])

    normal, skipped = load(normal_dir, label), load(skipped_dir, label)
    failures, notes = [], []

    for key in ("mode", "area", "cutsceneLock", "inCombat", "money", "quests", "flags", "inventory", "dialog"):
        if normal.get(key) != skipped.get(key):
            failures.append("{0}: normal={1} skipped={2}".format(key, json.dumps(normal.get(key)), json.dumps(skipped.get(key))))

    for group in ("party", "areaUnits"):
        a, b = units_by_id(normal.get(group, [])), units_by_id(skipped.get(group, []))
        for unit_id in sorted(set(a) | set(b)):
            if unit_id not in a or unit_id not in b:
                present = "skipped only" if unit_id in b else "normal only"
                failures.append("{0} {1} ({2}) present in {3}".format(group, (a.get(unit_id) or b.get(unit_id))["unit"], unit_id, present))
                continue
            ua, ub = a[unit_id], b[unit_id]
            if ua["dead"] != ub["dead"]:
                failures.append("{0} {1} dead: normal={2} skipped={3}".format(group, ua["unit"], ua["dead"], ub["dead"]))
            if ua["hp"] != ub["hp"]:
                failures.append("{0} {1} hp: normal={2} skipped={3}".format(group, ua["unit"], ua["hp"], ub["hp"]))
            if ua.get("inCombat") != ub.get("inCombat"):
                failures.append("{0} {1} inCombat: normal={2} skipped={3}".format(group, ua["unit"], ua.get("inCombat"), ub.get("inCombat")))
            moved = distance(ua["position"], ub["position"])
            if moved > tolerance:
                failures.append("{0} {1} position differs by {2:.1f}m: normal={3} skipped={4}".format(group, ua["unit"], moved, ua["position"], ub["position"]))
            elif moved > 0.25:
                notes.append("{0} {1} position differs by {2:.2f}m (within tolerance)".format(group, ua["unit"], moved))

    try:
        normal_pre, skipped_pre = load(normal_dir, "pre"), load(skipped_dir, "pre")
        normal_elapsed = normal["gameTimeSeconds"] - normal_pre["gameTimeSeconds"]
        skipped_elapsed = skipped["gameTimeSeconds"] - skipped_pre["gameTimeSeconds"]
        notes.append("game time pre->{0}: normal {1:.2f}s, skipped {2:.2f}s (difference {3:+.2f}s)".format(
            label, normal_elapsed, skipped_elapsed, skipped_elapsed - normal_elapsed))
        notes.append("real time pre->{0}: normal {1:.2f}s, skipped {2:.2f}s".format(
            label, normal["realtime"] - normal_pre["realtime"], skipped["realtime"] - skipped_pre["realtime"]))
    except (OSError, KeyError):
        pass

    for key in ("debugTimeScale", "fadeCanvas", "manualLoadingScreen", "audioLevel", "paused"):
        if skipped["presentation"].get(key) != normal["presentation"].get(key):
            failures.append("presentation {0}: normal={1} skipped={2}".format(key, normal["presentation"].get(key), skipped["presentation"].get(key)))

    print("units compared: party={0} area={1}; quests={2}; flags={3}; inventory stacks={4}".format(
        len(normal.get("party", [])), len(normal.get("areaUnits", [])), len(normal.get("quests", [])),
        len(normal.get("flags", [])), len(normal.get("inventory", []))))
    for note in notes:
        print("NOTE", note)
    for failure in failures:
        print("DIFF", failure)
    print("RESULT", "MATCH" if not failures else "DIFFERENT ({0})".format(len(failures)))
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
