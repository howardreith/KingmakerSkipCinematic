"""Compare the semantic state a normal run and a skipped run reached from the same save.

Usage: python -I compare_runs.py <normal-evidence-dir> <skipped-evidence-dir> [label | normalLabel:skippedLabel] [--position-tolerance=1.5]

Must match exactly: mode, area, control lock, combat flag, money, quests and objectives, flags, inventory, dialogue
position; for every party and area unit: presence, death, HP, combat flag, faction, ability resources, active toggles
and the set of buffs. Positions are compared within a tolerance. Action cooldowns are compared within 0.05 s, except
the initiative cooldown: which unit acts first is decided by d20 rolls (UnityEngine.Random, unseeded per launch, so it
differs between two normal runs too); the initiative schedule (sorted values across combatants) must match and the
per-unit order is reported as a note.

Timed buffs: the remaining duration may differ only by the measured game-time difference between the runs (the
documented cost of a skip) plus 0.25 s; anything larger is a difference. Every remaining-duration delta is reported.

Presentation after the boundary (debug and Unity time scale, fade, manual loading screen, audio, pause) must match, so
an override left behind by the skip is reported.
"""
import json
import os
import sys

UNIT_EXACT_KEYS = ("dead", "hp", "inCombat", "faction", "resources", "activeToggles")
STORY_KEYS = ("mode", "area", "cutsceneLock", "inCombat", "money", "quests", "flags", "inventory", "dialog")
PRESENTATION_KEYS = ("debugTimeScale", "unityTimeScale", "fadeCanvas", "manualLoadingScreen", "audioLevel", "paused")
COOLDOWN_TOLERANCE = 0.05
BUFF_TIME_SLACK = 0.25


def load(directory, label):
    with open(os.path.join(directory, "snapshot-" + label + ".json"), encoding="utf-8-sig") as handle:
        return json.load(handle)


def position(text):
    return [float(part) for part in text.split(",")]


def distance(a, b):
    pa, pb = position(a), position(b)
    return ((pa[0] - pb[0]) ** 2 + (pa[2] - pb[2]) ** 2) ** 0.5


def pair_units(normal_units, skipped_units):
    """Pairs units by UniqueId; units spawned at runtime get random ids, so leftovers pair by blueprint and proximity."""
    a = {unit["id"]: unit for unit in normal_units}
    b = {unit["id"]: unit for unit in skipped_units}
    pairs = [(a[i], b[i]) for i in sorted(set(a) & set(b))]
    left = [a[i] for i in sorted(set(a) - set(b))]
    right = [b[i] for i in sorted(set(b) - set(a))]
    unmatched = []
    for unit in left:
        candidates = [other for other in right if other["unit"] == unit["unit"]]
        if not candidates:
            unmatched.append(("normal only", unit))
            continue
        best = min(candidates, key=lambda other: distance(unit["position"], other["position"]))
        right.remove(best)
        pairs.append((unit, best))
    unmatched.extend(("skipped only", unit) for unit in right)
    return pairs, unmatched


def buff_identity(buff):
    return (buff["buff"], buff.get("timeLeft", -1) < 0, bool(buff.get("suppressed")))


def compare_buffs(name, normal_buffs, skipped_buffs, allowed_delta, failures, notes):
    normal_ids = sorted(buff_identity(b) for b in normal_buffs)
    skipped_ids = sorted(buff_identity(b) for b in skipped_buffs)
    if normal_ids != skipped_ids:
        only_normal = sorted(set(normal_ids) - set(skipped_ids)) or "(counts differ)"
        only_skipped = sorted(set(skipped_ids) - set(normal_ids)) or "(counts differ)"
        failures.append("{0} buffs differ: normal only {1}; skipped only {2}".format(name, only_normal, only_skipped))
        return
    timed_normal = sorted((b["buff"], b["timeLeft"]) for b in normal_buffs if b.get("timeLeft", -1) >= 0)
    timed_skipped = sorted((b["buff"], b["timeLeft"]) for b in skipped_buffs if b.get("timeLeft", -1) >= 0)
    for (buff, left_normal), (_, left_skipped) in zip(timed_normal, timed_skipped):
        delta = left_skipped - left_normal
        text = "{0} buff {1} time left: normal {2:.2f}s, skipped {3:.2f}s ({4:+.2f}s)".format(name, buff, left_normal, left_skipped, delta)
        if abs(delta) > allowed_delta:
            failures.append(text + " exceeds the game-time difference allowance {0:.2f}s".format(allowed_delta))
        elif abs(delta) > 0.001:
            notes.append(text)


def compare_cooldowns(name, normal, skipped, failures):
    if normal == skipped:
        return
    if normal is None or skipped is None:
        failures.append("{0} cooldowns: normal={1} skipped={2}".format(name, normal, skipped))
        return
    for key in sorted((set(normal) | set(skipped)) - {"initiative"}):
        a, b = normal.get(key), skipped.get(key)
        if a is None or b is None or abs(a - b) > COOLDOWN_TOLERANCE:
            failures.append("{0} cooldown {1}: normal={2} skipped={3}".format(name, key, a, b))


def initiative_by_unit(snapshot):
    result = []
    for group in ("party", "areaUnits"):
        for unit in snapshot.get(group, []):
            cooldowns = unit.get("cooldowns") or {}
            if unit.get("inCombat") and cooldowns.get("initiative") is not None:
                result.append((unit["unit"], cooldowns["initiative"]))
    return sorted(result)


def compare_initiative(normal, skipped, failures, notes):
    a, b = initiative_by_unit(normal), initiative_by_unit(skipped)
    schedule_a, schedule_b = sorted(v for _, v in a), sorted(v for _, v in b)
    if len(schedule_a) != len(schedule_b) or any(abs(x - y) > COOLDOWN_TOLERANCE for x, y in zip(schedule_a, schedule_b)):
        failures.append("initiative schedule differs: normal={0} skipped={1}".format(a, b))
    elif any(ua != ub or abs(va - vb) > COOLDOWN_TOLERANCE for (ua, va), (ub, vb) in zip(a, b)):
        notes.append("initiative order differs (d20 rolls, varies between normal runs too): normal={0} skipped={1}".format(a, b))


def compare(normal, skipped, normal_pre=None, skipped_pre=None, tolerance=1.5, label="boundary"):
    """Returns (failures, notes) for two snapshots, optionally with their runs' "pre" snapshots for timing."""
    failures, notes = [], []

    for key in STORY_KEYS:
        if normal.get(key) != skipped.get(key):
            failures.append("{0}: normal={1} skipped={2}".format(key, json.dumps(normal.get(key)), json.dumps(skipped.get(key))))

    game_time_difference = None
    if normal_pre is not None and skipped_pre is not None:
        normal_elapsed = normal["gameTimeSeconds"] - normal_pre["gameTimeSeconds"]
        skipped_elapsed = skipped["gameTimeSeconds"] - skipped_pre["gameTimeSeconds"]
        game_time_difference = skipped_elapsed - normal_elapsed
        notes.append("game time pre->{0}: normal {1:.2f}s, skipped {2:.2f}s (difference {3:+.2f}s)".format(
            label, normal_elapsed, skipped_elapsed, game_time_difference))
        notes.append("real time pre->{0}: normal {1:.2f}s, skipped {2:.2f}s".format(
            label, normal["realtime"] - normal_pre["realtime"], skipped["realtime"] - skipped_pre["realtime"]))
    # Without "pre" snapshots the absolute game-time difference at the boundary bounds the allowance.
    if game_time_difference is None:
        game_time_difference = skipped.get("gameTimeSeconds", 0) - normal.get("gameTimeSeconds", 0)
    allowed_buff_delta = abs(game_time_difference) + BUFF_TIME_SLACK

    for group in ("party", "areaUnits"):
        pairs, unmatched = pair_units(normal.get(group, []), skipped.get(group, []))
        for side, unit in unmatched:
            failures.append("{0} {1} ({2}) present in {3}".format(group, unit["unit"], unit["id"], side))
        for ua, ub in pairs:
            name = "{0} {1}".format(group, ua["unit"])
            for key in UNIT_EXACT_KEYS:
                if ua.get(key) != ub.get(key):
                    failures.append("{0} {1}: normal={2} skipped={3}".format(name, key, ua.get(key), ub.get(key)))
            compare_buffs(name, ua.get("buffs", []), ub.get("buffs", []), allowed_buff_delta, failures, notes)
            compare_cooldowns(name, ua.get("cooldowns"), ub.get("cooldowns"), failures)
            moved = distance(ua["position"], ub["position"])
            if moved > tolerance:
                failures.append("{0} position differs by {1:.1f}m: normal={2} skipped={3}".format(name, moved, ua["position"], ub["position"]))
            elif moved > 0.25:
                notes.append("{0} position differs by {1:.2f}m (within tolerance)".format(name, moved))

    compare_initiative(normal, skipped, failures, notes)

    normal_presentation, skipped_presentation = normal.get("presentation", {}), skipped.get("presentation", {})
    for key in PRESENTATION_KEYS:
        a, b = normal_presentation.get(key), skipped_presentation.get(key)
        if isinstance(a, float) and isinstance(b, float):
            a, b = round(a, 3), round(b, 3)
        if a != b:
            failures.append("presentation {0}: normal={1} skipped={2}".format(key, normal_presentation.get(key), skipped_presentation.get(key)))

    return failures, notes


def main():
    normal_dir, skipped_dir = sys.argv[1], sys.argv[2]
    label = next((arg for arg in sys.argv[3:] if not arg.startswith("--")), "boundary")
    tolerance = 1.5
    for arg in sys.argv[3:]:
        if arg.startswith("--position-tolerance="):
            tolerance = float(arg.split("=", 1)[1])

    normal_label, _, skipped_label = label.partition(":")
    skipped_label = skipped_label or normal_label
    normal, skipped = load(normal_dir, normal_label), load(skipped_dir, skipped_label)
    try:
        normal_pre, skipped_pre = load(normal_dir, "pre"), load(skipped_dir, "pre")
    except OSError:
        normal_pre = skipped_pre = None

    failures, notes = compare(normal, skipped, normal_pre, skipped_pre, tolerance, label)
    buffs = sum(len(unit.get("buffs", [])) for group in ("party", "areaUnits") for unit in normal.get(group, []))
    print("units compared: party={0} area={1}; quests={2}; flags={3}; inventory stacks={4}; buffs={5}".format(
        len(normal.get("party", [])), len(normal.get("areaUnits", [])), len(normal.get("quests", [])),
        len(normal.get("flags", [])), len(normal.get("inventory", [])), buffs))
    for note in notes:
        print("NOTE", note)
    for failure in failures:
        print("DIFF", failure)
    print("RESULT", "MATCH" if not failures else "DIFFERENT ({0})".format(len(failures)))
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
