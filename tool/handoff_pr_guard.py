#!/usr/bin/env python3
"""Advisory freshness/overlap checks for durable AI handoff pull requests."""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

HANDOFF_FILES = {
    "docs/AI_PROGRESS.md",
    "docs/AI_PROGRESS_OBJECT.md",
    "docs/AI_PROGRESS_RELATION.md",
    "docs/AI_PROGRESS_DATABASE_VIEW.md",
    "docs/AI_PROGRESS_PRIMITIVES.md",
    "docs/AI_PROGRESS_SEARCH.md",
    "docs/AI_PROGRESS_STORAGE.md",
    "docs/AI_PROGRESS_REFACTOR.md",
    "docs/AI_PROGRESS_OVERSIGHT.md",
}


@dataclass(frozen=True)
class OpenPull:
    number: int
    title: str
    files: frozenset[str]


def handoff_files(paths: Iterable[str]) -> frozenset[str]:
    return frozenset(path for path in paths if path in HANDOFF_FILES)


def competing_handoffs(
    current_number: int,
    current_files: Iterable[str],
    open_pulls: Iterable[OpenPull],
) -> list[tuple[str, OpenPull]]:
    current = handoff_files(current_files)
    conflicts: list[tuple[str, OpenPull]] = []
    for pull in open_pulls:
        if pull.number == current_number:
            continue
        for path in sorted(current.intersection(handoff_files(pull.files))):
            conflicts.append((path, pull))
    return conflicts


def stale_handoff_files(
    current_files: Iterable[str], main_changed_files: Iterable[str]
) -> list[str]:
    return sorted(handoff_files(current_files).intersection(handoff_files(main_changed_files)))


def materially_stale(behind_by: int, threshold: int) -> bool:
    return behind_by >= threshold


def _request_json(url: str, token: str) -> object:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "bookmark-app-handoff-guard",
        },
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.load(response)


def _paged_list(url: str, token: str) -> list[dict[str, object]]:
    items: list[dict[str, object]] = []
    page = 1
    separator = "&" if "?" in url else "?"
    while True:
        payload = _request_json(f"{url}{separator}per_page=100&page={page}", token)
        if not isinstance(payload, list):
            raise ValueError(f"GitHub response was not a list for {url}")
        page_items = [item for item in payload if isinstance(item, dict)]
        items.extend(page_items)
        if len(payload) < 100:
            return items
        page += 1


def _compare_changed_files(payload: object) -> frozenset[str]:
    if not isinstance(payload, dict):
        raise ValueError("GitHub compare response was not an object")
    rows = payload.get("files", [])
    if not isinstance(rows, list):
        raise ValueError("GitHub compare files were not a list")
    return frozenset(
        str(row.get("filename", "")) for row in rows if isinstance(row, dict)
    )


def _warning(message: str) -> None:
    escaped = message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    print(f"::warning title=AI handoff freshness::{escaped}")


def _append_summary(lines: list[str]) -> None:
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not summary_path:
        return
    with Path(summary_path).open("a", encoding="utf-8") as summary:
        summary.write("\n".join(lines) + "\n")


def main() -> int:
    repository = os.environ.get("GITHUB_REPOSITORY", "")
    token = os.environ.get("GITHUB_TOKEN", "")
    current_raw = os.environ.get("CURRENT_PR_NUMBER", "")
    threshold = int(os.environ.get("HANDOFF_STALE_COMMIT_WARN", "20"))

    if not repository or not token or not current_raw:
        _warning("Audit unavailable because repository/token/current PR metadata is missing.")
        return 0

    try:
        current_number = int(current_raw)
        api_root = f"https://api.github.com/repos/{repository}"
        current_rows = _paged_list(f"{api_root}/pulls/{current_number}/files", token)
        current_files = [str(row.get("filename", "")) for row in current_rows]
        current_handoffs = handoff_files(current_files)
        if not current_handoffs:
            print("handoff_pr_guard: current PR changes no durable handoff file")
            return 0

        current_payload = _request_json(f"{api_root}/pulls/{current_number}", token)
        if not isinstance(current_payload, dict):
            raise ValueError("Current PR response was not an object")
        base = current_payload.get("base")
        head = current_payload.get("head")
        if not isinstance(base, dict) or not isinstance(head, dict):
            raise ValueError("Current PR base/head metadata unavailable")
        base_sha = str(base.get("sha", ""))
        head_sha = str(head.get("sha", ""))
        if not base_sha or not head_sha:
            raise ValueError("Current PR base/head SHA unavailable")

        compare = _request_json(f"{api_root}/compare/{base_sha}...{head_sha}", token)
        if not isinstance(compare, dict):
            raise ValueError("Branch compare response was not an object")
        behind_by = int(compare.get("behind_by", 0) or 0)
        merge_base = compare.get("merge_base_commit")
        if not isinstance(merge_base, dict):
            raise ValueError("Merge-base metadata unavailable")
        merge_base_sha = str(merge_base.get("sha", ""))

        main_changed_files: frozenset[str] = frozenset()
        if merge_base_sha and merge_base_sha != base_sha:
            main_compare = _request_json(
                f"{api_root}/compare/{merge_base_sha}...{base_sha}", token
            )
            main_changed_files = _compare_changed_files(main_compare)

        pull_rows = _paged_list(f"{api_root}/pulls?state=open", token)
        open_pulls: list[OpenPull] = []
        for row in pull_rows:
            number = row.get("number")
            if not isinstance(number, int) or number == current_number:
                continue
            files = _paged_list(f"{api_root}/pulls/{number}/files", token)
            open_pulls.append(
                OpenPull(
                    number=number,
                    title=str(row.get("title") or ""),
                    files=frozenset(str(item.get("filename", "")) for item in files),
                )
            )

        competing = competing_handoffs(current_number, current_files, open_pulls)
        stale_files = stale_handoff_files(current_files, main_changed_files)
        stale_by_age = materially_stale(behind_by, threshold)

        lines = [
            "## Durable handoff freshness",
            "",
            f"- Handoff files in this PR: `{', '.join(sorted(current_handoffs))}`",
            f"- Commits behind current base: `{behind_by}`",
            f"- Material staleness warning threshold: `{threshold}` commits",
        ]

        if competing:
            lines.extend(
                [
                    "",
                    "### Competing open handoffs",
                    "",
                    "| Handoff file | Other PR |",
                    "| --- | --- |",
                ]
            )
            for path, pull in competing:
                _warning(
                    f"{path} is also changed by open PR #{pull.number} {pull.title}; choose one durable checkpoint and supersede the other."
                )
                lines.append(f"| `{path}` | #{pull.number} — {pull.title} |")
        else:
            lines.append("- No other open PR changes the same durable handoff file.")

        if stale_files:
            for path in stale_files:
                _warning(
                    f"{path} changed on main after this branch diverged; refresh or supersede this handoff instead of merging a stale checkpoint."
                )
            lines.extend(
                [
                    "",
                    "### Handoff file changed on main since divergence",
                    *[f"- ⚠️ `{path}`" for path in stale_files],
                ]
            )

        if stale_by_age:
            _warning(
                f"This handoff branch is {behind_by} commits behind current main (threshold {threshold}); re-check every durable statement before merge."
            )
            lines.extend(
                [
                    "",
                    f"- ⚠️ Branch is materially stale by commit distance: `{behind_by}` commits behind.",
                ]
            )

        if not competing and not stale_files and not stale_by_age:
            lines.extend(["", "No handoff freshness warnings."])

        _append_summary(lines)
        return 0
    except (OSError, ValueError, KeyError, json.JSONDecodeError, urllib.error.URLError) as error:
        _warning(f"Audit unavailable: {error}")
        return 0


if __name__ == "__main__":
    sys.exit(main())
