#!/usr/bin/env python3
"""Fail closed unless a selected release source passed authoritative CI."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import sys
import urllib.parse
import urllib.request

AUTHORITATIVE_CHECK = "merge-gate"
_SHA_PATTERN = re.compile(r"^[0-9a-fA-F]{40}$")


def normalize_sha(value: str) -> str:
    candidate = value.strip()
    if not _SHA_PATTERN.fullmatch(candidate):
        raise ValueError("release source SHA must be a full 40-character Git commit SHA")
    return candidate.lower()


def successful_authoritative_check(payload: object, source_sha: str) -> dict[str, object] | None:
    if not isinstance(payload, dict):
        raise ValueError("GitHub check-runs payload must be an object")
    rows = payload.get("check_runs")
    if not isinstance(rows, list):
        raise ValueError("GitHub check-runs payload is missing check_runs")

    source = normalize_sha(source_sha)
    for raw in rows:
        if not isinstance(raw, dict):
            continue
        if str(raw.get("name") or "") != AUTHORITATIVE_CHECK:
            continue
        if str(raw.get("conclusion") or "").lower() != "success":
            continue
        head_sha = str(raw.get("head_sha") or "").strip().lower()
        if head_sha != source:
            continue
        return raw
    return None


def _request_check_runs(repository: str, source_sha: str, token: str) -> dict[str, object]:
    rows: list[object] = []
    total_count: int | None = None
    page = 1
    while True:
        query = urllib.parse.urlencode({"per_page": 100, "page": page})
        url = (
            f"https://api.github.com/repos/{repository}/commits/{source_sha}/check-runs"
            f"?{query}"
        )
        request = urllib.request.Request(
            url,
            headers={
                "Accept": "application/vnd.github+json",
                "Authorization": f"Bearer {token}",
                "X-GitHub-Api-Version": "2022-11-28",
                "User-Agent": "bookmark-app-release-ci-guard",
            },
        )
        with urllib.request.urlopen(request, timeout=20) as response:
            payload = json.load(response)
        if not isinstance(payload, dict) or not isinstance(payload.get("check_runs"), list):
            raise ValueError("GitHub returned an invalid check-runs response")
        batch = payload["check_runs"]
        rows.extend(batch)
        raw_total = payload.get("total_count")
        if isinstance(raw_total, int):
            total_count = raw_total
        if len(batch) < 100 or (total_count is not None and len(rows) >= total_count):
            return {"total_count": total_count or len(rows), "check_runs": rows}
        page += 1


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sha", required=True)
    parser.add_argument("--repository")
    parser.add_argument(
        "--checks-json",
        help="Offline/test-only check-runs payload. Production release workflow omits this.",
    )
    return parser


def main() -> int:
    args = _parser().parse_args()
    try:
        source_sha = normalize_sha(args.sha)
        if args.checks_json:
            payload = json.loads(Path(args.checks_json).read_text(encoding="utf-8"))
        else:
            repository = (args.repository or os.environ.get("GITHUB_REPOSITORY") or "").strip()
            token = (os.environ.get("GITHUB_TOKEN") or "").strip()
            if not repository or "/" not in repository:
                raise ValueError("repository owner/name is required for release CI validation")
            if not token:
                raise ValueError("GITHUB_TOKEN is required for release CI validation")
            payload = _request_check_runs(repository, source_sha, token)

        check = successful_authoritative_check(payload, source_sha)
        if check is None:
            raise ValueError(
                f"source {source_sha} has no successful {AUTHORITATIVE_CHECK} check; "
                "refusing to publish a release"
            )
        html_url = str(check.get("html_url") or "unavailable")
        print(f"Authoritative CI verified for {source_sha}: {AUTHORITATIVE_CHECK} ({html_url})")
        return 0
    except (OSError, ValueError, json.JSONDecodeError, urllib.error.URLError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
