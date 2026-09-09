#!/usr/bin/env python3
"""Fail on mutable Actions or drift from the repository Flutter toolchain contract."""

from __future__ import annotations

import re
import sys
from pathlib import Path

import flutter_toolchain_guard

WORKFLOW_DIR = Path(".github/workflows")
USES_RE = re.compile(r"^\s*(?:-\s*)?uses:\s*([^\s#]+)")
REMOTE_PIN_RE = re.compile(
    r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.\-/]+)?@[0-9a-fA-F]{40}$"
)


def unpinned_uses(text: str) -> list[str]:
    failures: list[str] = []
    for line_number, line in enumerate(text.splitlines(), start=1):
        match = USES_RE.match(line)
        if not match:
            continue
        value = match.group(1)
        if value.startswith("./"):
            continue
        if not REMOTE_PIN_RE.fullmatch(value):
            failures.append(f"line {line_number}: {value}")
    return failures


def audit_workflows(root: Path = WORKFLOW_DIR) -> list[str]:
    failures: list[str] = []
    for path in sorted((*root.glob("*.yml"), *root.glob("*.yaml"))):
        for failure in unpinned_uses(path.read_text(encoding="utf-8")):
            failures.append(f"{path}: {failure}")
    return failures


def main() -> int:
    action_failures = audit_workflows()
    toolchain_failures = flutter_toolchain_guard.validate_repository(Path("."))
    if not action_failures and not toolchain_failures:
        print(
            "github_actions_pin_guard: immutable remote Actions, tracked pubspec.lock, "
            "and pinned Flutter setup are valid"
        )
        return 0

    if action_failures:
        print("Remote GitHub Actions must be pinned to a full 40-character commit SHA:")
        for failure in action_failures:
            print(f"- {failure}")

    if toolchain_failures:
        print("Flutter toolchain/dependency reproducibility contract failed:")
        for failure in toolchain_failures:
            print(f"- {failure}")

    return 1


if __name__ == "__main__":
    sys.exit(main())
