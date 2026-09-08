#!/usr/bin/env python3
"""Classify whether dart-format changes overlap lines changed by a PR diff."""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path

HUNK_RE = re.compile(
    r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@"
)


@dataclass(frozen=True)
class LineRange:
    start: int
    count: int

    @property
    def end(self) -> int:
        return self.start + self.count - 1

    def overlaps(self, other: "LineRange") -> bool:
        if self.count <= 0 or other.count <= 0:
            return False
        return self.start <= other.end and other.start <= self.end


def _count(raw: str | None) -> int:
    return 1 if raw is None else int(raw)


def changed_new_ranges(diff_text: str) -> list[LineRange]:
    """Return current-file line ranges changed by a base -> current unified diff."""
    ranges: list[LineRange] = []
    for line in diff_text.splitlines():
        match = HUNK_RE.match(line)
        if not match:
            continue
        new_start = int(match.group(3))
        new_count = _count(match.group(4))
        if new_count > 0:
            ranges.append(LineRange(new_start, new_count))
    return ranges


def formatter_old_ranges(diff_text: str) -> tuple[list[LineRange], list[int]]:
    """Return current-file ranges/anchors touched by current -> formatted diff."""
    ranges: list[LineRange] = []
    insertion_anchors: list[int] = []
    for line in diff_text.splitlines():
        match = HUNK_RE.match(line)
        if not match:
            continue
        old_start = int(match.group(1))
        old_count = _count(match.group(2))
        if old_count > 0:
            ranges.append(LineRange(old_start, old_count))
        else:
            # A formatter-only insertion is anchored between old_start and
            # old_start + 1 in the current file. Treat either adjacent changed
            # line as overlap, while ignoring insertions elsewhere in legacy
            # pre-existing formatting debt.
            insertion_anchors.extend(
                line_number
                for line_number in (old_start, old_start + 1)
                if line_number > 0
            )
    return ranges, insertion_anchors


def formatting_touches_changed_lines(changed_diff: str, format_diff: str) -> bool:
    changed = changed_new_ranges(changed_diff)
    formatter_ranges, anchors = formatter_old_ranges(format_diff)
    if not changed:
        return False
    if any(
        formatter_range.overlaps(changed_range)
        for formatter_range in formatter_ranges
        for changed_range in changed
    ):
        return True
    return any(
        changed_range.start <= anchor <= changed_range.end
        for anchor in anchors
        for changed_range in changed
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--changed-diff", required=True, type=Path)
    parser.add_argument("--format-diff", required=True, type=Path)
    args = parser.parse_args()

    changed = args.changed_diff.read_text(encoding="utf-8", errors="replace")
    formatted = args.format_diff.read_text(encoding="utf-8", errors="replace")
    return 1 if formatting_touches_changed_lines(changed, formatted) else 0


if __name__ == "__main__":
    raise SystemExit(main())
