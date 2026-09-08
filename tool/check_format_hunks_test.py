#!/usr/bin/env python3

import unittest

import check_format_hunks as hunks


class CheckFormatHunksTest(unittest.TestCase):
    def test_pre_existing_formatter_drift_outside_changed_hunk_is_ignored(self) -> None:
        changed = "@@ -20 +20 @@\n-old\n+new\n"
        formatted = "@@ -5 +5 @@\n-old drift\n+formatted drift\n"
        self.assertFalse(hunks.formatting_touches_changed_lines(changed, formatted))

    def test_formatter_change_inside_changed_hunk_is_rejected(self) -> None:
        changed = "@@ -20,2 +20,3 @@\n-old\n+new\n+lines\n"
        formatted = "@@ -21 +21 @@\n-bad\n+good\n"
        self.assertTrue(hunks.formatting_touches_changed_lines(changed, formatted))

    def test_formatter_insertion_adjacent_to_changed_line_is_rejected(self) -> None:
        changed = "@@ -20 +20,2 @@\n-old\n+new\n+line\n"
        formatted = "@@ -20,0 +21 @@\n+inserted\n"
        self.assertTrue(hunks.formatting_touches_changed_lines(changed, formatted))

    def test_formatter_insertion_elsewhere_is_ignored(self) -> None:
        changed = "@@ -20 +20 @@\n-old\n+new\n"
        formatted = "@@ -4,0 +5 @@\n+inserted\n"
        self.assertFalse(hunks.formatting_touches_changed_lines(changed, formatted))

    def test_deletion_only_hunk_has_no_current_lines_to_format(self) -> None:
        changed = "@@ -20,2 +19,0 @@\n-old\n-lines\n"
        formatted = "@@ -5 +5 @@\n-old drift\n+formatted drift\n"
        self.assertFalse(hunks.formatting_touches_changed_lines(changed, formatted))

    def test_default_hunk_count_is_one(self) -> None:
        ranges = hunks.changed_new_ranges("@@ -3 +7 @@\n-a\n+b\n")
        self.assertEqual(ranges, [hunks.LineRange(7, 1)])


if __name__ == "__main__":
    unittest.main()
