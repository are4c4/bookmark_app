#!/usr/bin/env python3
"""Run migration single-writer enforcement from the required merge-gate path."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import migration_lease_guard


def hydrate_pull_request_metadata() -> None:
    if (
        os.environ.get("CI_BASE_SHA")
        and os.environ.get("CI_HEAD_SHA")
        and os.environ.get("CURRENT_PR_NUMBER")
    ):
        return

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
