#!/usr/bin/env python3
"""Classify whether a GitHub pull request is strictly docs-only.

Only Markdown files below docs/ are eligible for the fast path. All non-PR
events deliberately classify as full CI.
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path


def is_docs_only(paths: list[str]) -> bool:
    normalized = [path.strip() for path in paths if path.strip()]
    return bool(normalized) and all(
        path.startswith("docs/") and path.endswith(".md") for path in normalized
    )


def changed_paths(base: str, head: str) -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--name-only", base, head],
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def write_output(name: str, value: str) -> None:
    output_path = os.environ.get("GITHUB_OUTPUT")
    if output_path:
        with Path(output_path).open("a", encoding="utf-8") as handle:
            handle.write(f"{name}={value}\n")
    else:
        print(f"{name}={value}")


def append_summary(lines: list[str]) -> None:
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not summary_path:
        return
    with Path(summary_path).open("a", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--event", default=os.environ.get("GITHUB_EVENT_NAME", ""))
    parser.add_argument("--base", default=os.environ.get("CI_BASE_SHA", ""))
    parser.add_argument("--head", default=os.environ.get("CI_HEAD_SHA", ""))
    args = parser.parse_args()

    if args.event != "pull_request":
        write_output("docs_only", "false")
        append_summary(
            [
                "## CI scope",
                "",
                f"- Event: `{args.event or 'unknown'}`",
                "- Fast docs-only path: `false` (non-PR events always run full CI)",
            ]
        )
        return 0

    if not args.base or not args.head:
        print("Pull-request scope classification requires base and head SHAs.", file=sys.stderr)
        return 2

    try:
        paths = changed_paths(args.base, args.head)
    except subprocess.CalledProcessError as error:
        print(f"Unable to classify complete PR diff: {error}", file=sys.stderr)
        return 2

    docs_only = is_docs_only(paths)
    write_output("docs_only", "true" if docs_only else "false")
    append_summary(
        [
            "## CI scope",
            "",
            f"- Files in complete PR diff: `{len(paths)}`",
            f"- Fast docs-only path: `{'true' if docs_only else 'false'}`",
            "- Eligible pattern: `docs/**/*.md` only",
        ]
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
