"""Print a compact, human-readable timeline of one native harness run.

Usage: python -I summarize_run.py <evidence-dir> [--all]
"""
import json
import os
import sys


def load(path):
    with open(path, encoding="utf-8-sig") as handle:
        return json.load(handle)


def describe_state(detail):
    presentation = detail.get("presentation") or {}
    dialog = detail.get("dialog") or {}
    return "mode={0} skip={1} fade={2} scale={3} unity={4} audio={5} loading={6} cue={7} cutscenes={8}".format(
        detail.get("mode"),
        detail.get("skipPhase"),
        presentation.get("fadeCanvas"),
        presentation.get("debugTimeScale"),
        round(presentation.get("unityTimeScale", -1), 2),
        round(presentation.get("audioLevel", -1), 1),
        presentation.get("loading"),
        dialog.get("cue"),
        ",".join(detail.get("cutscenes") or []),
    )


def main():
    evidence = sys.argv[1]
    show_all = "--all" in sys.argv
    result = load(os.path.join(evidence, "runtime-result.json"))
    print("result:", result.get("status"), result.get("failure") or "")
    timeline = load(os.path.join(evidence, "timeline.json"))
    start = timeline[0]["t"] if timeline else 0
    for entry in timeline:
        kind = entry["kind"]
        if kind == "screenshot" and not show_all:
            continue
        stamp = "{0:8.2f} f{1:<6}".format(entry["t"] - start, entry["frame"])
        detail = entry.get("detail")
        if kind == "state":
            print(stamp, "STATE", describe_state(detail))
        elif kind == "skipEnded":
            print(stamp, "SKIP-ENDED", json.dumps(detail))
        else:
            print(stamp, kind, detail if detail is not None else "")


if __name__ == "__main__":
    main()
