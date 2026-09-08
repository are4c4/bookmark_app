#!/usr/bin/env python3

import unittest

import handoff_pr_guard as guard


class HandoffPrGuardTest(unittest.TestCase):
    def test_non_handoff_paths_are_ignored(self) -> None:
        self.assertEqual(
            guard.handoff_files(["docs/development_checks.md", "lib/main.dart"]),
            frozenset(),
        )

    def test_known_progress_files_are_handoffs(self) -> None:
        self.assertEqual(
            guard.handoff_files(
                ["docs/AI_PROGRESS_OBJECT.md", "docs/AI_PROGRESS_REFACTOR.md"]
            ),
            frozenset(
                {"docs/AI_PROGRESS_OBJECT.md", "docs/AI_PROGRESS_REFACTOR.md"}
            ),
        )

    def test_same_handoff_file_in_open_pr_is_competing(self) -> None:
        pulls = [
            guard.OpenPull(
                number=12,
                title="Newer object handoff",
                files=frozenset({"docs/AI_PROGRESS_OBJECT.md"}),
            )
        ]
        overlaps = guard.competing_handoffs(
            10,
            ["docs/AI_PROGRESS_OBJECT.md"],
            pulls,
        )
        self.assertEqual(len(overlaps), 1)
        self.assertEqual(overlaps[0][0], "docs/AI_PROGRESS_OBJECT.md")
        self.assertEqual(overlaps[0][1].number, 12)

    def test_other_lane_handoff_does_not_compete(self) -> None:
        pulls = [
            guard.OpenPull(
                number=12,
                title="Relation handoff",
                files=frozenset({"docs/AI_PROGRESS_RELATION.md"}),
            )
        ]
        self.assertEqual(
            guard.competing_handoffs(
                10,
                ["docs/AI_PROGRESS_OBJECT.md"],
                pulls,
            ),
            [],
        )

    def test_same_handoff_changed_on_main_is_stale(self) -> None:
        self.assertEqual(
            guard.stale_handoff_files(
                ["docs/AI_PROGRESS_OBJECT.md"],
                ["docs/AI_PROGRESS_OBJECT.md", "lib/main.dart"],
            ),
            ["docs/AI_PROGRESS_OBJECT.md"],
        )

    def test_unrelated_main_change_does_not_stale_handoff_file(self) -> None:
        self.assertEqual(
            guard.stale_handoff_files(
                ["docs/AI_PROGRESS_OBJECT.md"],
                ["lib/main.dart"],
            ),
            [],
        )

    def test_material_staleness_threshold(self) -> None:
        self.assertFalse(guard.materially_stale(19, 20))
        self.assertTrue(guard.materially_stale(20, 20))
        self.assertTrue(guard.materially_stale(40, 20))


if __name__ == "__main__":
    unittest.main()
