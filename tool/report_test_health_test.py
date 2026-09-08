#!/usr/bin/env python3

import tempfile
import unittest
from pathlib import Path

import report_test_health as health


class ReportTestHealthTest(unittest.TestCase):
    def test_balanced_shards_have_no_warning(self) -> None:
        timings = [
            health.ShardTiming(0, 200, "success", "skipped"),
            health.ShardTiming(1, 210, "success", "skipped"),
            health.ShardTiming(2, 205, "success", "skipped"),
        ]
        lines, warnings = health.summarize(
            timings,
            expected_shards=3,
            skew_warn=1.25,
            wall_warn_seconds=360,
        )
        self.assertEqual(warnings, [])
        self.assertTrue(any("Max / average skew" in line for line in lines))

    def test_skew_and_flake_are_reported(self) -> None:
        timings = [
            health.ShardTiming(0, 100, "success", "skipped"),
            health.ShardTiming(1, 300, "failure", "success"),
            health.ShardTiming(2, 100, "success", "skipped"),
        ]
        _, warnings = health.summarize(
            timings,
            expected_shards=3,
            skew_warn=1.25,
            wall_warn_seconds=360,
        )
        self.assertTrue(any("Shard skew" in warning for warning in warnings))
        self.assertTrue(any("Fail-then-pass" in warning for warning in warnings))

    def test_load_timings_reads_json_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "test-timing-2.json").write_text(
                '{"shard":2,"elapsed_seconds":123,"first_outcome":"success","rerun_outcome":"skipped"}',
                encoding="utf-8",
            )
            timings = health.load_timings(root)
        self.assertEqual(timings, [health.ShardTiming(2, 123, "success", "skipped")])


if __name__ == "__main__":
    unittest.main()
