#!/usr/bin/env python3

import json
import tempfile
import unittest
from pathlib import Path

import report_flutter_test_file_timings as timings


def event(payload: dict) -> str:
    return json.dumps(payload, separators=(",", ":"))


class ReportFlutterTestFileTimingsTest(unittest.TestCase):
    def _collect(self, lines: list[str]) -> list[timings.FileTiming]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "test").mkdir()
            events = root / "events.jsonl"
            events.write_text("\n".join(lines) + "\n", encoding="utf-8")
            return timings.collect_file_timings(events, root)

    def test_collects_multiple_tests_and_overlapping_suites(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "test").mkdir()
            first = root / "test" / "a_test.dart"
            second = root / "test" / "b_test.dart"
            events = root / "events.jsonl"
            events.write_text(
                "\n".join(
                    [
                        event(
                            {
                                "type": "suite",
                                "time": 0,
                                "suite": {"id": 1, "path": str(first)},
                            }
                        ),
                        event(
                            {
                                "type": "suite",
                                "time": 2,
                                "suite": {"id": 2, "path": str(second)},
                            }
                        ),
                        event(
                            {
                                "type": "testStart",
                                "time": 10,
                                "test": {"id": 11, "suiteID": 1},
                            }
                        ),
                        event(
                            {
                                "type": "testStart",
                                "time": 15,
                                "test": {"id": 21, "suiteID": 2},
                            }
                        ),
                        event({"type": "testDone", "time": 30, "testID": 11}),
                        event(
                            {
                                "type": "testStart",
                                "time": 35,
                                "test": {"id": 12, "suiteID": 1},
                            }
                        ),
                        event({"type": "testDone", "time": 45, "testID": 21}),
                        event({"type": "testDone", "time": 65, "testID": 12}),
                    ]
                )
                + "\n",
                encoding="utf-8",
            )
            result = timings.collect_file_timings(events, root)

        self.assertEqual(
            result,
            [
                timings.FileTiming("test/a_test.dart", 50, 55, 2),
                timings.FileTiming("test/b_test.dart", 30, 30, 1),
            ],
        )

    def test_relative_suite_path_is_preserved(self) -> None:
        result = self._collect(
            [
                event(
                    {
                        "type": "suite",
                        "time": 0,
                        "suite": {"id": 1, "path": "test/example_test.dart"},
                    }
                ),
                event(
                    {
                        "type": "testStart",
                        "time": 5,
                        "test": {"id": 10, "suiteID": 1},
                    }
                ),
                event({"type": "testDone", "time": 25, "testID": 10}),
            ]
        )
        self.assertEqual(result[0].path, "test/example_test.dart")

    def test_path_outside_repo_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            outside = root.parent / "outside_test.dart"
            events = root / "events.jsonl"
            events.write_text(
                "\n".join(
                    [
                        event(
                            {
                                "type": "suite",
                                "time": 0,
                                "suite": {"id": 1, "path": str(outside)},
                            }
                        ),
                        event(
                            {
                                "type": "testStart",
                                "time": 1,
                                "test": {"id": 10, "suiteID": 1},
                            }
                        ),
                        event({"type": "testDone", "time": 2, "testID": 10}),
                    ]
                )
                + "\n",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "outside repository root"):
                timings.collect_file_timings(events, root)

    def test_malformed_json_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            events = root / "events.jsonl"
            events.write_text("{not json}\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "invalid JSON event"):
                timings.collect_file_timings(events, root)

    def test_incomplete_test_is_rejected(self) -> None:
        lines = [
            event(
                {
                    "type": "suite",
                    "time": 0,
                    "suite": {"id": 1, "path": "test/example_test.dart"},
                }
            ),
            event(
                {
                    "type": "testStart",
                    "time": 5,
                    "test": {"id": 10, "suiteID": 1},
                }
            ),
        ]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            events = root / "events.jsonl"
            events.write_text("\n".join(lines) + "\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "incomplete test events"):
                timings.collect_file_timings(events, root)

    def test_summary_ranks_by_active_time(self) -> None:
        lines = timings.summarize_file_timings(
            [
                (0, timings.FileTiming("test/a_test.dart", 1000, 1200, 1)),
                (1, timings.FileTiming("test/b_test.dart", 2500, 3000, 2)),
            ],
            limit=2,
        )
        table = "\n".join(lines)
        self.assertLess(table.index("b_test.dart"), table.index("a_test.dart"))
        self.assertIn("Advisory first-pass timing only", table)


if __name__ == "__main__":
    unittest.main()
