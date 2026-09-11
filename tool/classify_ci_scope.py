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


def verified_pull_request_diff_refs(
    expected_checkout_sha: str,
    expected_pr_head_sha: str,
) -> tuple[str, str]:
    """Return current-base -> synthetic-merge refs for a verified PR checkout.

    GitHub Actions checks out refs/pull/<n>/merge for pull_request workflows.
    Its first parent is the current base and its second parent is the event PR head.
    Verify both identities before trusting HEAD^1 -> HEAD as the effective landing diff.
    """
    if not expected_checkout_sha:
        raise ValueError("GITHUB_SHA is missing for pull-request scope classification.")
    if not expected_pr_head_sha:
        raise ValueError("Pull-request head SHA is missing for scope classification.")

    head = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        check=False,
        capture_output=True,
        text=True,
    )
    if head.returncode != 0:
        raise ValueError("Unable to resolve the checked-out commit.")
    local_head = head.stdout.strip()
    if local_head != expected_checkout_sha:
        raise ValueError(
            "Checked-out commit does not match GITHUB_SHA; refusing a stale PR diff."
        )

    parents = subprocess.run(
        ["git", "rev-list", "--parents", "-n", "1", "HEAD"],
        check=False,
        capture_output=True,
        text=True,
    )
    if parents.returncode != 0:
        raise ValueError("Unable to inspect synthetic pull-request merge parents.")
    parts = parents.stdout.strip().split()
    if len(parts) != 3 or parts[0] != expected_checkout_sha:
        raise ValueError(
            "Pull-request checkout is not the expected two-parent synthetic merge."
        )
    if parts[2] != expected_pr_head_sha:
        raise ValueError(
            "Synthetic merge second parent does not match the event PR head."
        )

    return ("HEAD^1", "HEAD")


def effective_diff_refs(
    event: str,
    base: str,
    head: str,
    checkout_sha: str,
) -> tuple[str, str]:
    """Resolve the diff refs used for CI scope classification."""
    if event == "pull_request":
        return verified_pull_request_diff_refs(checkout_sha, head)
    return (base, head)


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

    try:
        base_ref, head_ref = effective_diff_refs(
            args.event,
            args.base,
            args.head,
            os.environ.get("GITHUB_SHA", ""),
        )
        paths = changed_paths(base_ref, head_ref)
    except (ValueError, subprocess.CalledProcessError) as error:
        print(f"Unable to classify effective PR landing diff: {error}", file=sys.stderr)
        return 2

    docs_only = is_docs_only(paths)
    write_output("docs_only", "true" if docs_only else "false")
    append_summary(
        [
            "## CI scope",
            "",
            f"- Files in effective PR landing diff: `{len(paths)}`",
            f"- Fast docs-only path: `{'true' if docs_only else 'false'}`",
            "- Eligible pattern: `docs/**/*.md` only",
        ]
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
