#!/usr/bin/env python3

import json
import tempfile
import unittest
from pathlib import Path

import plan_flutter_test_shards as planner


class PlanFlutterTestShardsTest(unittest.TestCase):
    def _write_payload(
        self,
        directory: Path,
        filename: str,
        shard: int,
        files: list[tuple[str, int, int, int]],
    ) -> None:
        payload = {
            "shard": shard,
            "files": [
                {
                    "path": path,
                    "active_milliseconds": active,
                    "wall_milliseconds": wall,
                    "test_count": count,
                }
                for path, active, wall, count in files
            ],
        }
        (directory / filename).write_text(
            json.dumps(payload),
            encoding="utf-8",
        )

    def _write_complete_run(
        self,
        directory: Path,
        a_values: list[int],
        b_values: list[int],
    ) -> None:
        for shard in range(4):
            self._write_payload(
                directory,
                f"test-file-timing-{shard}.json",
                shard,
                [
                    ("test/a_test.dart", a_values[shard], a_values[shard], 1),
                    ("test/b_test.dart", b_values[shard], b_values[shard], 1),
                ],
            )

    def test_complete_run_sums_same_file_across_builtin_shards(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self._write_complete_run(
                root,
                a_values=[100, 200, 300, 400],
                b_values=[10, 20, 30, 40],
            )
            result = planner.load_complete_run(root)

        self.assertEqual(
            result,
            {
                "test/a_test.dart": 1000,
                "test/b_test.dart": 100,
            },
        )

    def test_historical_weights_use_per_run_median_after_shard_aggregation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            first = root / "run-1"
            second = root / "run-2"
            first.mkdir()
            second.mkdir()
            self._write_complete_run(
                first,
                a_values=[100, 200, 300, 400],
                b_values=[10, 20, 30, 40],
            )
            self._write_complete_run(
                second,
                a_values=[200, 300, 400, 500],
                b_values=[20, 30, 40, 50],
            )
            weights = planner.build_historical_weights([first, second])

        self.assertEqual(weights["test/a_test.dart"].milliseconds, 1200)
        self.assertEqual(weights["test/a_test.dart"].samples, 2)
        self.assertEqual(weights["test/b_test.dart"].milliseconds, 120)

    def test_missing_or_duplicate_shards_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for shard in range(3):
                self._write_payload(
                    root,
                    f"test-file-timing-{shard}.json",
                    shard,
                    [("test/a_test.dart", 10, 10, 1)],
                )
            with self.assertRaisesRegex(ValueError, "incomplete timing run"):
                planner.load_complete_run(root)

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for shard in range(4):
                self._write_payload(
                    root,
                    f"test-file-timing-{shard}.json",
                    shard,
                    [("test/a_test.dart", 10, 10, 1)],
                )
            self._write_payload(
                root,
                "test-file-timing-duplicate.json",
                2,
                [("test/a_test.dart", 10, 10, 1)],
            )
            with self.assertRaisesRegex(ValueError, "duplicate shard payload"):
                planner.load_complete_run(root)

    def test_invalid_paths_and_metadata_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for shard in range(4):
                path = "../outside_test.dart" if shard == 0 else "test/a_test.dart"
                self._write_payload(
                    root,
                    f"test-file-timing-{shard}.json",
                    shard,
                    [(path, 10, 10, 1)],
                )
            with self.assertRaisesRegex(ValueError, "invalid test path"):
                planner.load_complete_run(root)

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for shard in range(4):
                self._write_payload(
                    root,
                    f"test-file-timing-{shard}.json",
                    shard,
                    [("test/a_test.dart", -1 if shard == 0 else 10, 10, 1)],
                )
            with self.assertRaisesRegex(ValueError, "active_milliseconds"):
                planner.load_complete_run(root)

    def test_unknown_inventory_file_uses_median_known_fallback(self) -> None:
        weights = {
            "test/a_test.dart": planner.FileWeight("test/a_test.dart", 1000, 2),
            "test/b_test.dart": planner.FileWeight("test/b_test.dart", 3000, 2),
        }
        plan = planner.build_plan(
            ["test/a_test.dart", "test/b_test.dart", "test/new_test.dart"],
            weights,
            shard_count=2,
        )
        files = {
            item.path: item
            for shard in plan.shards
            for item in shard.files
        }
        self.assertEqual(plan.fallback_milliseconds, 2000)
        self.assertEqual(files["test/new_test.dart"].milliseconds, 2000)
        self.assertEqual(files["test/new_test.dart"].source, "fallback")

    def test_lpt_plan_is_deterministic_balanced_and_covers_each_file_once(self) -> None:
        inventory = [f"test/t{i}_test.dart" for i in range(1, 9)]
        weights = {
            path: planner.FileWeight(path, milliseconds, 1)
            for path, milliseconds in zip(
                inventory,
                [8000, 7000, 6000, 5000, 4000, 3000, 2000, 1000],
            )
        }
        first = planner.build_plan(inventory, weights, shard_count=4)
        second = planner.build_plan(inventory, weights, shard_count=4)

        self.assertEqual(first, second)
        self.assertEqual(
            [shard.total_milliseconds for shard in first.shards],
            [9000, 9000, 9000, 9000],
        )
        assigned = [item.path for shard in first.shards for item in shard.files]
        self.assertCountEqual(assigned, inventory)
        self.assertEqual(len(assigned), len(set(assigned)))

    def test_discover_inventory_is_recursive_and_repo_relative(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "test" / "nested").mkdir(parents=True)
            (root / "test" / "a_test.dart").write_text("", encoding="utf-8")
            (root / "test" / "nested" / "b_test.dart").write_text("", encoding="utf-8")
            (root / "test" / "nested" / "helper.dart").write_text("", encoding="utf-8")

            result = planner.discover_test_inventory(root)

        self.assertEqual(
            result,
            ["test/a_test.dart", "test/nested/b_test.dart"],
        )


if __name__ == "__main__":
    unittest.main()
