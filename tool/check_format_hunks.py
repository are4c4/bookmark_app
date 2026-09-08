#!/usr/bin/env python3
"""Compare edited Dart lines with formatter-induced line changes."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
import re
import sys


_HUNK_RE = re.compile(
    r"^@@ -(?P<old_start>\d+)(?:,(?P<old_count>\d+))? "
    r"\+(?P<new_start>\d+)(?:,(?P<new_count>\d+))? @@"
)


@dataclass(frozen=True)
class LineRange:
    start: int
    end: int

    def overlaps(self, other: "LineRange") -> bool:
        return self.start <= other.end and other.start <= self.end


@dataclass(frozen=True)
class Hunk:
    old_range: LineRange
    new_range: LineRange
    text: str


def _line_range(start: int, count: int) -> LineRange:
    if count == 0:
        anchor = max(1, start)
        return LineRange(anchor, anchor)
    return LineRange(start, start + count - 1)


def parse_hunks(patch: str) -> list[Hunk]:
    lines = patch.splitlines()
    hunks: list[Hunk] = []
    index = 0
    while index < len(lines):
        match = _HUNK_RE.match(lines[index])
        if match is None:
            index += 1
            continue

        end = index + 1
        while end < len(lines) and _HUNK_RE.match(lines[end]) is None:
            end += 1

        old_start = int(match.group("old_start"))
        old_count = int(match.group("old_count") or 1)
        new_start = int(match.group("new_start"))
        new_count = int(match.group("new_count") or 1)
        hunks.append(
            Hunk(
                old_range=_line_range(old_start, old_count),
                new_range=_line_range(new_start, new_count),
                text="\n".join(lines[index:end]),
            )
        )
        index = end
    return hunks


def formatter_hunks_overlapping_edits(
    source_patch: str,
    formatter_patch: str,
) -> list[Hunk]:
    """Return formatter hunks that touch lines edited by the source patch.

    Source hunks use their new/current-file coordinates. Formatter hunks use
    their old/pre-format coordinates, so both sets refer to the same file
    before `dart format` mutates the temporary working copy.
    """
    source_hunks = parse_hunks(source_patch)
    formatter_hunks = parse_hunks(formatter_patch)
    if not formatter_hunks:
        return []
    if not source_hunks:
        # A selected tracked file should have source hunks. Fail closed if the
        # caller cannot establish them rather than silently ignoring drift.
        return formatter_hunks

    edited_ranges = [hunk.new_range for hunk in source_hunks]
    return [
        hunk
        for hunk in formatter_hunks
        if any(hunk.old_range.overlaps(edited) for edited in edited_ranges)
    ]


def _format_range(line_range: LineRange) -> str:
    if line_range.start == line_range.end:
        return str(line_range.start)
    return f"{line_range.start}-{line_range.end}"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-diff", required=True)
    parser.add_argument("--format-diff", required=True)
    parser.add_argument("--path", required=True)
    args = parser.parse_args(argv)

    source_patch = Path(args.source_diff).read_text(encoding="utf-8")
    formatter_patch = Path(args.format_diff).read_text(encoding="utf-8")
    relevant = formatter_hunks_overlapping_edits(source_patch, formatter_patch)
    if not relevant:
        print(
            f"check_format: {args.path}: formatter drift exists only outside "
            "edited lines; preserving the focused patch"
        )
        return 0

    source_hunks = parse_hunks(source_patch)
    edited = ", ".join(_format_range(hunk.new_range) for hunk in source_hunks)
    print(
        f"check_format: {args.path}: dart format changes overlap edited "
        f"line(s) {edited or 'unknown'}",
        file=sys.stderr,
    )
    print("check_format: relevant formatter diff:", file=sys.stderr)
    for hunk in relevant:
        print(hunk.text, file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
