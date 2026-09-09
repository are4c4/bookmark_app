#!/usr/bin/env python3
"""Fail when a repository workflow uses an unpinned remote GitHub Action."""

from __future__ import annotations

import re
import sys
from pathlib import Path

WORKFLOW_DIR = Path(".github/workflows")
USES_RE = re.compile(r"^\s*uses:\s*([^\s#]+)")
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
    failures = audit_workflows()
    if not failures:
        print("github_actions_pin_guard: all remote actions use immutable commit SHAs")
        return 0
    print("Remote GitHub Actions must be pinned to a full 40-character commit SHA:")
    for failure in failures:
        print(f"- {failure}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
