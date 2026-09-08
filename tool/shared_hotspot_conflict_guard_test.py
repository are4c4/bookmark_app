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


if __name__ == "__main__":
    unittest.main()
