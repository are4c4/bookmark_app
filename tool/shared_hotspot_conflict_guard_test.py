#!/usr/bin/env python3

import unittest

import shared_hotspot_conflict_guard as guard


class SharedHotspotConflictGuardTest(unittest.TestCase):
    def test_non_hotspot_changes_have_no_overlap(self) -> None:
        pulls = [
            guard.PullRequestFiles(
                number=12,
                title="Other",
                files=frozenset({"lib/views/app_shell.dart"}),
            )
        ]
        self.assertEqual(
            guard.find_overlaps(10, ["lib/services/example.dart"], pulls),
            [],
        )

    def test_same_hotspot_in_another_pr_is_reported(self) -> None:
        pulls = [
            guard.PullRequestFiles(
                number=12,
                title="Shell work",
                files=frozenset({"lib/views/app_shell.dart", "README.md"}),
            )
        ]
        overlaps = guard.find_overlaps(
            10,
            ["lib/views/app_shell.dart", "docs/note.md"],
            pulls,
        )
        self.assertEqual(len(overlaps), 1)
        self.assertEqual(overlaps[0][0], "lib/views/app_shell.dart")
        self.assertEqual(overlaps[0][1].number, 12)

    def test_current_pr_is_ignored(self) -> None:
        pulls = [
            guard.PullRequestFiles(
                number=10,
                title="Current",
                files=frozenset({"lib/data/app_database.dart"}),
            )
        ]
        self.assertEqual(
            guard.find_overlaps(10, ["lib/data/app_database.dart"], pulls),
            [],
        )

    def test_stale_unrelated_main_change_is_not_hotspot_drift(self) -> None:
        self.assertEqual(
            guard.stale_hotspot_paths(
                ["lib/views/app_shell.dart"],
                ["lib/services/example.dart", "README.md"],
            ),
            [],
        )

    def test_same_hotspot_changed_on_main_is_stale_hotspot_drift(self) -> None:
        self.assertEqual(
            guard.stale_hotspot_paths(
                ["lib/views/app_shell.dart", "docs/note.md"],
                ["lib/views/app_shell.dart", "lib/services/example.dart"],
            ),
            ["lib/views/app_shell.dart"],
        )

    def test_large_hotspot_diff_is_reported_by_threshold(self) -> None:
        diffs = [
            guard.HotspotDiff("lib/views/app_shell.dart", additions=150, deletions=75),
            guard.HotspotDiff("lib/data/app_database.dart", additions=10, deletions=8),
        ]
        oversized = guard.oversized_hotspot_diffs(diffs, threshold=200)
        self.assertEqual([item.path for item in oversized], ["lib/views/app_shell.dart"])
        self.assertEqual(oversized[0].changed_lines, 225)

    def test_exact_large_diff_threshold_is_not_warned(self) -> None:
        diffs = [
            guard.HotspotDiff("lib/views/app_shell.dart", additions=120, deletions=80),
        ]
        self.assertEqual(guard.oversized_hotspot_diffs(diffs, threshold=200), [])


if __name__ == "__main__":
    unittest.main()
