#!/usr/bin/env python3

import unittest

from check_format_hunks import (
    LineRange,
    formatter_hunks_overlapping_edits,
    parse_hunks,
)


class CheckFormatHunksTest(unittest.TestCase):
    def test_formatted_new_hunk_ignores_pre_existing_formatter_drift(self):
        source = """@@ -20 +20 @@
-old
+new
"""
        formatter = """@@ -3,2 +3,3 @@
-old debt
+formatted debt
+continued
"""
        self.assertEqual(formatter_hunks_overlapping_edits(source, formatter), [])

    def test_unformatted_new_hunk_fails_when_formatter_touches_edit(self):
        source = """@@ -20 +20 @@
-old
+new
"""
        formatter = """@@ -20 +20 @@
-new
+new formatted
"""
        relevant = formatter_hunks_overlapping_edits(source, formatter)
        self.assertEqual(len(relevant), 1)
        self.assertEqual(relevant[0].old_range, LineRange(20, 20))

    def test_deletion_anchor_detects_formatter_change_at_same_location(self):
        source = """@@ -8 +8,0 @@
-removed
"""
        formatter = """@@ -8 +8 @@
-before
+after
"""
        self.assertEqual(len(formatter_hunks_overlapping_edits(source, formatter)), 1)

    def test_only_overlapping_formatter_hunk_is_reported(self):
        source = """@@ -30,2 +30,2 @@
-old a
-old b
+new a
+new b
"""
        formatter = """@@ -4 +4 @@
-old debt
+formatted debt
@@ -31 +31 @@
-new b
+new b formatted
"""
        relevant = formatter_hunks_overlapping_edits(source, formatter)
        self.assertEqual(len(relevant), 1)
        self.assertIn("@@ -31 +31 @@", relevant[0].text)

    def test_missing_source_hunks_fails_closed(self):
        formatter = """@@ -4 +4 @@
-old
+new
"""
        self.assertEqual(len(formatter_hunks_overlapping_edits("", formatter)), 1)

    def test_hunk_parser_uses_new_and_old_coordinates(self):
        hunks = parse_hunks("@@ -10,2 +12,3 @@\n-a\n-b\n+c\n+d\n+e\n")
        self.assertEqual(hunks[0].old_range, LineRange(10, 11))
        self.assertEqual(hunks[0].new_range, LineRange(12, 14))


if __name__ == "__main__":
    unittest.main()
