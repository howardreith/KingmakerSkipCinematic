"""Self-test for compare_runs.py: every consequential difference must be reported (run: python -I tools/native/test_compare_runs.py)."""
import copy
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compare_runs  # noqa: E402


def unit(**overrides):
    value = {
        "unit": "NPC", "id": "u1", "dead": False, "hp": 10, "position": "1.0,0.0,1.0", "inCombat": False,
        "faction": "Neutral", "resources": ["Ki=3"], "activeToggles": [],
        "buffs": [{"buff": "Permanent", "timeLeft": -1, "suppressed": False},
                  {"buff": "Bless", "timeLeft": 40.0, "suppressed": False}],
        "cooldowns": {"initiative": 0, "standard": 0, "move": 0, "swift": 0, "attackOfOpportunity": 0},
    }
    value.update(overrides)
    return value


def snapshot(game_time=100.0):
    return {
        "mode": "Dialog", "area": "A", "cutsceneLock": True, "inCombat": False, "money": 5, "quests": [], "flags": [],
        "inventory": [], "dialog": None, "gameTimeSeconds": game_time, "realtime": 10.0,
        "party": [unit(unit="Hero", id="p1")], "areaUnits": [unit()],
        "presentation": {"debugTimeScale": 1.0, "unityTimeScale": 1.0, "fadeCanvas": "Hidden",
                         "manualLoadingScreen": False, "audioLevel": 100.0, "paused": False},
    }


class CompareRunsTests(unittest.TestCase):
    def assertDifferent(self, skipped, normal=None, pre=None):
        normal = normal or snapshot()
        failures, _ = compare_runs.compare(normal, skipped, pre, pre)
        self.assertTrue(failures, "expected a difference")
        return failures

    def test_identical_snapshots_match(self):
        self.assertEqual([], compare_runs.compare(snapshot(), snapshot())[0])

    def test_faction_change_is_reported(self):
        skipped = snapshot()
        skipped["areaUnits"][0]["faction"] = "Hostile"
        self.assertIn("faction", self.assertDifferent(skipped)[0])

    def test_unity_time_scale_left_accelerated_is_reported(self):
        skipped = snapshot()
        skipped["presentation"]["unityTimeScale"] = 10.0
        self.assertIn("unityTimeScale", self.assertDifferent(skipped)[0])

    def test_missing_buff_is_reported(self):
        skipped = snapshot()
        skipped["party"][0]["buffs"] = skipped["party"][0]["buffs"][:1]
        self.assertIn("buffs differ", self.assertDifferent(skipped)[0])

    def test_buff_time_within_game_time_difference_is_a_note(self):
        normal, skipped = snapshot(100.0), snapshot(100.6)
        skipped["party"][0]["buffs"][1]["timeLeft"] = 39.4
        pre = {"gameTimeSeconds": 90.0, "realtime": 0.0}
        failures, notes = compare_runs.compare(normal, skipped, pre, pre)
        self.assertEqual([], failures)
        self.assertTrue(any("Bless" in note for note in notes))

    def test_buff_time_beyond_game_time_difference_is_reported(self):
        normal, skipped = snapshot(100.0), snapshot(100.6)
        skipped["party"][0]["buffs"][1]["timeLeft"] = 30.0
        pre = {"gameTimeSeconds": 90.0, "realtime": 0.0}
        self.assertIn("exceeds", self.assertDifferent(skipped, normal, pre)[0])

    def test_resource_change_is_reported(self):
        skipped = snapshot()
        skipped["party"][0]["resources"] = ["Ki=2"]
        self.assertIn("resources", self.assertDifferent(skipped)[0])

    def test_cooldown_change_is_reported(self):
        skipped = snapshot()
        skipped["areaUnits"][0]["cooldowns"]["standard"] = 3.0
        self.assertIn("cooldown standard", self.assertDifferent(skipped)[0])

    def test_toggle_change_is_reported(self):
        skipped = snapshot()
        skipped["party"][0]["activeToggles"] = ["PowerAttack"]
        self.assertIn("activeToggles", self.assertDifferent(skipped)[0])

    def test_spawned_unit_pairs_by_blueprint(self):
        normal, skipped = snapshot(), copy.deepcopy(snapshot())
        skipped["areaUnits"][0]["id"] = "random-spawn-id"
        self.assertEqual([], compare_runs.compare(normal, skipped)[0])


if __name__ == "__main__":
    unittest.main()
