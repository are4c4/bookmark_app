#!/usr/bin/env python3
"""Guard the repository-owned Flutter pin and application dependency lock."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path
from typing import Iterable

LOCKFILE = "pubspec.lock"
WORKFLOW_ROOT = ".github/workflows"
FLUTTER_ACTION = "subosito/flutter-action@"
VERSION_FILE_LINE = "flutter-version-file: pubspec.yaml"


def _indent(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def flutter_setup_errors(path: Path, content: str) -> list[str]:
    errors: list[str] = []
    lines = content.splitlines()
    for index, line in enumerate(lines):
        stripped = line.strip()
        if not stripped.startswith("uses:") or FLUTTER_ACTION not in stripped:
            continue

        action_indent = _indent(line)
        block: list[str] = []
        for following in lines[index + 1 :]:
            if following.strip() and _indent(following) < action_indent:
                break
            block.append(following.strip())

        if VERSION_FILE_LINE not in block:
            errors.append(
                f"{path}: Flutter setup at line {index + 1} must use "
                f"`{VERSION_FILE_LINE}`"
            )
    return errors


def tracked_files(root: Path) -> frozenset[str]:
    result = subprocess.run(
        ["git", "-C", str(root), "ls-files"],
        check=True,
        capture_output=True,
        text=True,
    )
    return frozenset(line.strip() for line in result.stdout.splitlines() if line.strip())


def validate_repository(
    root: Path,
    *,
    tracked: Iterable[str] | None = None,
) -> list[str]:
    errors: list[str] = []
    lock_path = root / LOCKFILE
    if not lock_path.is_file():
        errors.append(f"{LOCKFILE}: required application lockfile is missing")

    tracked_set = frozenset(tracked) if tracked is not None else tracked_files(root)
    if LOCKFILE not in tracked_set:
        errors.append(f"{LOCKFILE}: required application lockfile is not tracked by git")

    workflow_root = root / WORKFLOW_ROOT
    if not workflow_root.is_dir():
        errors.append(f"{WORKFLOW_ROOT}: workflow directory is missing")
        return errors

    for workflow in sorted(
        path
        for pattern in ("*.yml", "*.yaml")
        for path in workflow_root.rglob(pattern)
        if path.is_file()
    ):
        errors.extend(
            flutter_setup_errors(
                workflow.relative_to(root),
                workflow.read_text(encoding="utf-8"),
            )
        )
    return errors


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    try:
        errors = validate_repository(root)
    except subprocess.CalledProcessError as error:
        print(
            f"flutter_toolchain_guard: unable to inspect git tracking: {error}",
            file=sys.stderr,
        )
        return 1

    if errors:
        for error in errors:
            print(f"flutter_toolchain_guard: {error}", file=sys.stderr)
        return 1

    print(
        "flutter_toolchain_guard: tracked pubspec.lock present and all Flutter setup steps use pubspec.yaml"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
