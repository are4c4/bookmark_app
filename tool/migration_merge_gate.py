#!/usr/bin/env python3
"""Run migration single-writer enforcement from the required merge-gate path."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

import migration_lease_guard


def _commit_available(ref: str) -> bool:
    if not ref:
        return False
    result = subprocess.run(
        ["git", "cat-file", "-e", f"{ref}^{{commit}}"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return result.returncode == 0


def _local_pull_merge_diff_refs(
    expected_checkout_sha: str,
    expected_pr_head_sha: str,
) -> tuple[str, str] | None:
    """Return current-base -> synthetic-merge refs for a verified PR checkout."""
    if not expected_checkout_sha or not expected_pr_head_sha:
        return None

    head = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        check=False,
        capture_output=True,
        text=True,
    )
    if head.returncode != 0:
        return None
    local_head = head.stdout.strip()
    if local_head != expected_checkout_sha:
        return None

    parents = subprocess.run(
        ["git", "rev-list", "--parents", "-n", "1", "HEAD"],
        check=False,
        capture_output=True,
        text=True,
    )
    if parents.returncode != 0:
        return None
    parts = parents.stdout.strip().split()
    if len(parts) != 3:
        return None
    if parts[2] != expected_pr_head_sha:
        return None
    return ("HEAD^1", "HEAD")


def hydrate_pull_request_metadata() -> None:
    event_path = os.environ.get("GITHUB_EVENT_PATH", "")
    if not event_path:
        return
    payload = json.loads(Path(event_path).read_text(encoding="utf-8"))
    pull = payload.get("pull_request")
    if not isinstance(pull, dict):
        return

    base = pull.get("base")
    head = pull.get("head")
    event_head_sha = str(head.get("sha") or "") if isinstance(head, dict) else ""
    if isinstance(base, dict):
        os.environ.setdefault("CI_BASE_SHA", str(base.get("sha") or ""))
    if event_head_sha:
        os.environ.setdefault("CI_HEAD_SHA", event_head_sha)
    number = payload.get("number") or pull.get("number")
    if number:
        os.environ.setdefault("CURRENT_PR_NUMBER", str(number))

    base_ref = os.environ.get("CI_BASE_SHA", "")
    head_ref = os.environ.get("CI_HEAD_SHA", "")
    if base_ref and head_ref and _commit_available(base_ref) and _commit_available(head_ref):
        return

    # For pull_request workflows, Actions defines GITHUB_SHA as the exact synthetic
    # refs/pull/<n>/merge commit that checkout uses. The REST/event
    # pull_request.merge_commit_sha can be regenerated independently and is not a
    # stable checkout identity, so it is deliberately not used as fallback authority.
    fallback = _local_pull_merge_diff_refs(
        os.environ.get("GITHUB_SHA", ""),
        event_head_sha,
    )
    if fallback is None:
        return

    # A verified synthetic PR merge has first parent=current base and second
    # parent=the event PR head. HEAD^1 -> HEAD is therefore exactly the effective
    # PR diff that would land now, without requiring an old historical base object.
    os.environ["CI_BASE_SHA"], os.environ["CI_HEAD_SHA"] = fallback


def main() -> int:
    try:
        hydrate_pull_request_metadata()
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(
            f"::error title=Migration single-writer lease::Unable to read pull-request event metadata: {error}"
        )
        return 1
    return migration_lease_guard.main()


if __name__ == "__main__":
    sys.exit(main())
