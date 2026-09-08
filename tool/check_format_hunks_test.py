#!/usr/bin/env python3

import unittest

from check_format_hunks import (
    LineRange,
    edited_current_ranges,
    formatter_changes_touching_edits,
    parse_hunks,
)


class CheckFormatHunksTest(unittest.TestCase):
    def test_formatted_edit_survives_pre_existing_formatter_drift(self):
        source = """@@ -6 +6 @@
-  print('old');
+  print('new');
"""
        original = """void main() {
  final legacy = <int>[
1,
2,
];
  print('new');
}
"""
        formatted = """void main() {
  final legacy = <int>[1, 2];
  print('new');
}
"""
        self.assertEqual(
            formatter_changes_touching_edits(source, original, formatted),
            [],
        )

    def test_unformatted_edit_fails_when_formatter_changes_that_line(self):
        source = """@@ -6 +6 @@
-  print('old');
+  print(  'bad'  );
"""
        original = """void main() {
  final legacy = <int>[
1,
2,
];
  print(  'bad'  );
}
"""
        formatted = """void main() {
  final legacy = <int>[1, 2];
  print('bad');
}
"""
        relevant = formatter_changes_touching_edits(source, original, formatted)
        self.assertEqual(len(relevant), 1)
        self.assertEqual(relevant[0].current_range, LineRange(2, 6))

    def test_pure_deletion_does_not_introduce_format_debt(self):
        source = """@@ -4 +4,0 @@
-  print('remove');
"""
        original = """void main() {
  final legacy = <int>[
1,
2,
];
}
"""
        formatted = """void main() {
  final legacy = <int>[1, 2];
}
"""
        self.assertEqual(edited_current_ranges(source), [])
        self.assertEqual(
            formatter_changes_touching_edits(source, original, formatted),
            [],
        )

    def test_equal_edited_block_survives_large_surrounding_reformat(self):
        source = """@@ -9,3 +9,3 @@
-  final person = 'old';
-  print(person);
-  print('done');
+  final person = 'new';
+  print(person);
+  print('done');
"""
        original = """void main() {
  final legacy = <int>[
1,
2,
3,
4,
5,
];
  final person = 'new';
  print(person);
  print('done');
}
"""
        formatted = """void main() {
  final legacy = <int>[1, 2, 3, 4, 5];
  final person = 'new';
  print(person);
  print('done');
}
"""
        self.assertEqual(
            formatter_changes_touching_edits(source, original, formatted),
            [],
        )

    def test_formatter_insertion_at_edit_boundary_fails_conservatively(self):
        source = """@@ -2 +2 @@
-  callOld();
+  callNew();
"""
        original = """void main() {
  callNew();
}
"""
        formatted = """void main() {
  callNew();
  // formatter inserted structure
}
"""
        relevant = formatter_changes_touching_edits(source, original, formatted)
        self.assertEqual(len(relevant), 1)
        self.assertEqual(relevant[0].tag, "insert")

    def test_missing_source_hunks_fails_closed(self):
        relevant = formatter_changes_touching_edits(
            "",
            "void main(){ }\n",
            "void main() {}\n",
        )
        self.assertEqual(len(relevant), 1)
        self.assertEqual(relevant[0].tag, "missing-source-diff")

    def test_hunk_parser_preserves_zero_new_count(self):
        hunks = parse_hunks("@@ -8 +8,0 @@\n-removed\n")
        self.assertEqual(hunks[0].new_count, 0)
        self.assertEqual(hunks[0].new_range, LineRange(8, 8))

    def test_hunk_parser_uses_new_and_old_coordinates(self):
        hunks = parse_hunks("@@ -10,2 +12,3 @@\n-a\n-b\n+c\n+d\n+e\n")
        self.assertEqual(hunks[0].old_range, LineRange(10, 11))
        self.assertEqual(hunks[0].new_range, LineRange(12, 14))
        self.assertEqual(hunks[0].new_count, 3)


if __name__ == "__main__":
    unittest.main()
