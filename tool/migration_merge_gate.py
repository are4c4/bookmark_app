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


def _local_pull_merge_diff_refs(expected_merge_sha: str) -> tuple[str, str] | None:
    """Return current-base -> synthetic-merge refs for a pull-request checkout."""
    head = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        check=False,
        capture_output=True,
        text=True,
    )
    if head.returncode != 0:
        return None
    local_head = head.stdout.strip()
    if expected_merge_sha and local_head != expected_merge_sha:
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
    if len(parts) < 3:
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
    if isinstance(base, dict):
        os.environ.setdefault("CI_BASE_SHA", str(base.get("sha") or ""))
    if isinstance(head, dict):
        os.environ.setdefault("CI_HEAD_SHA", str(head.get("sha") or ""))
    number = payload.get("number") or pull.get("number")
    if number:
        os.environ.setdefault("CURRENT_PR_NUMBER", str(number))

    base_ref = os.environ.get("CI_BASE_SHA", "")
    head_ref = os.environ.get("CI_HEAD_SHA", "")
    if base_ref and head_ref and _commit_available(base_ref) and _commit_available(head_ref):
        return

    fallback = _local_pull_merge_diff_refs(str(pull.get("merge_commit_sha") or ""))
    if fallback is None:
        return

    # actions/checkout's pull-request merge ref represents exactly what would land on
    # the current base. Using HEAD^1 -> HEAD avoids requiring an old original base
    # object in a shallow checkout while still classifying only the effective PR diff.
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
