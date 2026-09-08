#!/usr/bin/env python3
"""Check whether dart format changes PR-added/replaced current lines."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from difflib import SequenceMatcher
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
    old_count: int
    new_count: int
    text: str


@dataclass(frozen=True)
class FormatterChange:
    tag: str
    current_range: LineRange
    formatted_range: LineRange
    before: tuple[str, ...]
    after: tuple[str, ...]


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
                old_count=old_count,
                new_count=new_count,
                text="\n".join(lines[index:end]),
            )
        )
        index = end
    return hunks


def edited_current_ranges(source_patch: str) -> list[LineRange]:
    """Return only current-file lines introduced/replaced by the source diff.

    Pure deletions have no current lines and therefore cannot introduce new
    formatting debt by themselves.
    """
    return [
        hunk.new_range
        for hunk in parse_hunks(source_patch)
        if hunk.new_count > 0
    ]


def _range_for_opcode(start: int, end: int, fallback: int) -> LineRange:
    if start < end:
        return LineRange(start + 1, end)
    anchor = max(1, fallback)
    return LineRange(anchor, anchor)


def formatter_changes_touching_edits(
    source_patch: str,
    original_text: str,
    formatted_text: str,
) -> list[FormatterChange]:
    """Return formatter operations that affect PR-added/replaced current lines.

    The formatter is still authoritative. The important distinction is that
    we compare line sequences before/after formatting instead of trusting the
    coarse spans of a unified formatter diff. Git/diff may coalesce unrelated
    historical formatting into a large hunk that happens to span an edited
    coordinate even when the edited line itself survives formatting unchanged.
    """
    source_hunks = parse_hunks(source_patch)
    if original_text == formatted_text:
        return []

    if not source_hunks:
        # A selected tracked file should have source hunks. Fail closed if the
        # caller cannot establish them rather than silently ignoring drift.
        original_lines = original_text.splitlines(keepends=True)
        formatted_lines = formatted_text.splitlines(keepends=True)
        return [
            FormatterChange(
                tag="missing-source-diff",
                current_range=LineRange(1, max(1, len(original_lines))),
                formatted_range=LineRange(1, max(1, len(formatted_lines))),
                before=tuple(original_lines[:8]),
                after=tuple(formatted_lines[:8]),
            )
        ]

    edited_ranges = edited_current_ranges(source_patch)
    if not edited_ranges:
        return []

    original_lines = original_text.splitlines(keepends=True)
    formatted_lines = formatted_text.splitlines(keepends=True)
    matcher = SequenceMatcher(
        None,
        original_lines,
        formatted_lines,
        autojunk=False,
    )

    relevant: list[FormatterChange] = []
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == "equal":
            continue

        if i1 < i2:
            current_range = LineRange(i1 + 1, i2)
            touches = any(current_range.overlaps(edited) for edited in edited_ranges)
        else:
            # An insertion has no old/current lines. Treat the boundary on
            # either side as affected so formatter-only inserted structure
            # adjacent to newly edited code still fails conservatively.
            boundary_after_lines = i1
            touches = any(
                edited.start - 1 <= boundary_after_lines <= edited.end
                for edited in edited_ranges
            )
            current_range = _range_for_opcode(
                i1,
                i2,
                min(max(1, i1 + 1), max(1, len(original_lines))),
            )

        if not touches:
            continue

        formatted_range = _range_for_opcode(
            j1,
            j2,
            min(max(1, j1 + 1), max(1, len(formatted_lines))),
        )
        relevant.append(
            FormatterChange(
                tag=tag,
                current_range=current_range,
                formatted_range=formatted_range,
                before=tuple(original_lines[i1:i2]),
                after=tuple(formatted_lines[j1:j2]),
            )
        )

    return relevant


def _format_range(line_range: LineRange) -> str:
    if line_range.start == line_range.end:
        return str(line_range.start)
    return f"{line_range.start}-{line_range.end}"


def _print_lines(label: str, lines: tuple[str, ...]) -> None:
    if not lines:
        print(f"  {label}: <no lines>", file=sys.stderr)
        return
    print(f"  {label}:", file=sys.stderr)
    for line in lines[:8]:
        print(f"    {line.rstrip()}", file=sys.stderr)
    if len(lines) > 8:
        print(f"    ... ({len(lines) - 8} more line(s))", file=sys.stderr)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-diff", required=True)
    parser.add_argument("--original", required=True)
    parser.add_argument("--formatted", required=True)
    parser.add_argument("--path", required=True)
    args = parser.parse_args(argv)

    source_patch = Path(args.source_diff).read_text(encoding="utf-8")
    original_text = Path(args.original).read_text(encoding="utf-8")
    formatted_text = Path(args.formatted).read_text(encoding="utf-8")
    relevant = formatter_changes_touching_edits(
        source_patch,
        original_text,
        formatted_text,
    )
    if not relevant:
        print(
            f"check_format: {args.path}: formatter drift exists only outside "
            "PR-added/replaced current lines (or the PR only deletes lines); "
            "preserving the focused patch"
        )
        return 0

    edited_ranges = edited_current_ranges(source_patch)
    edited = ", ".join(_format_range(line_range) for line_range in edited_ranges)
    print(
        f"check_format: {args.path}: dart format changes PR-added/replaced "
        f"current line(s) {edited or 'unknown'}",
        file=sys.stderr,
    )
    for change in relevant[:4]:
        print(
            "check_format: formatter "
            f"{change.tag} current lines {_format_range(change.current_range)} "
            f"-> formatted lines {_format_range(change.formatted_range)}",
            file=sys.stderr,
        )
        _print_lines("before", change.before)
        _print_lines("formatted", change.after)
    if len(relevant) > 4:
        print(
            f"check_format: ... {len(relevant) - 4} additional formatter "
            "change(s) touching edited code",
            file=sys.stderr,
        )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
