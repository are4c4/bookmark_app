#!/usr/bin/env python3
"""Advisory coordination checks for shared hotspots in pull requests."""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

HOTSPOTS = {
    "lib/views/generic_database_page.dart",
    "lib/views/app_shell.dart",
    "lib/views/object_inspector_page.dart",
    "lib/views/bookmark_unified_stage1_page.dart",
    "lib/widgets/bookmark_reorderable_properties.dart",
    "lib/views/people_management_page.dart",
    "lib/views/settings_page.dart",
    "lib/services/profile_manager.dart",
    "lib/data/app_database.dart",
}


@dataclass(frozen=True)
class PullRequestFiles:
    number: int
    title: str
    files: frozenset[str]


@dataclass(frozen=True)
class HotspotDiff:
    path: str
    additions: int
    deletions: int

    @property
    def changed_lines(self) -> int:
        return self.additions + self.deletions


@dataclass(frozen=True)
class BranchRisk:
    compare_status: str
    merge_base_sha: str
    base_sha: str
    main_changed_files: frozenset[str]
    hotspot_diffs: tuple[HotspotDiff, ...]


def hotspot_files(files: Iterable[str]) -> frozenset[str]:
    return frozenset(path for path in files if path in HOTSPOTS)


def find_overlaps(
    current_number: int,
    current_files: Iterable[str],
    open_prs: Iterable[PullRequestFiles],
) -> list[tuple[str, PullRequestFiles]]:
    current_hotspots = hotspot_files(current_files)
    if not current_hotspots:
        return []

    overlaps: list[tuple[str, PullRequestFiles]] = []
    for pull in open_prs:
        if pull.number == current_number:
            continue
        for path in sorted(current_hotspots.intersection(hotspot_files(pull.files))):
            overlaps.append((path, pull))
    return overlaps


def stale_hotspot_paths(
    current_files: Iterable[str], main_changed_files: Iterable[str]
) -> list[str]:
    return sorted(hotspot_files(current_files).intersection(hotspot_files(main_changed_files)))


def oversized_hotspot_diffs(
    diffs: Iterable[HotspotDiff], threshold: int
) -> list[HotspotDiff]:
    return sorted(
        (diff for diff in diffs if diff.changed_lines > threshold),
        key=lambda diff: diff.path,
    )


def _request_json(url: str, token: str) -> object:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "bookmark-app-hotspot-guard",
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


def _compare_files(payload: object) -> frozenset[str]:
    if not isinstance(payload, dict):
        raise ValueError("GitHub compare response was not an object")
    files = payload.get("files", [])
    if not isinstance(files, list):
        raise ValueError("GitHub compare files were not a list")
    return frozenset(
        str(row.get("filename", "")) for row in files if isinstance(row, dict)
    )


def _fetch_live(
    repository: str, current_number: int, token: str
) -> tuple[list[str], list[PullRequestFiles], BranchRisk | None]:
    api_root = f"https://api.github.com/repos/{repository}"
    current_file_rows = _paged_list(f"{api_root}/pulls/{current_number}/files", token)
    current_files = [str(row.get("filename", "")) for row in current_file_rows]
    current_hotspots = hotspot_files(current_files)

    # Avoid the more expensive PR/compare/open-PR scans when no shared hotspot is touched.
    if not current_hotspots:
        return current_files, [], None

    hotspot_diffs = tuple(
        HotspotDiff(
            path=str(row.get("filename", "")),
            additions=int(row.get("additions", 0) or 0),
            deletions=int(row.get("deletions", 0) or 0),
        )
        for row in current_file_rows
        if str(row.get("filename", "")) in current_hotspots
    )

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

    branch_compare = _request_json(f"{api_root}/compare/{base_sha}...{head_sha}", token)
    if not isinstance(branch_compare, dict):
        raise ValueError("Branch compare response was not an object")
    compare_status = str(branch_compare.get("status", "unknown"))
    merge_base = branch_compare.get("merge_base_commit")
    if not isinstance(merge_base, dict):
        raise ValueError("Merge-base metadata unavailable")
    merge_base_sha = str(merge_base.get("sha", ""))
    if not merge_base_sha:
        raise ValueError("Merge-base SHA unavailable")

    main_changed_files: frozenset[str] = frozenset()
    if merge_base_sha != base_sha:
        main_compare = _request_json(
            f"{api_root}/compare/{merge_base_sha}...{base_sha}", token
        )
        main_changed_files = _compare_files(main_compare)

    pull_rows = _paged_list(f"{api_root}/pulls?state=open", token)
    open_prs: list[PullRequestFiles] = []
    for row in pull_rows:
        number = row.get("number")
        title = row.get("title")
        if not isinstance(number, int) or number == current_number:
            continue
        file_rows = _paged_list(f"{api_root}/pulls/{number}/files", token)
        files = frozenset(str(file_row.get("filename", "")) for file_row in file_rows)
        open_prs.append(PullRequestFiles(number=number, title=str(title or ""), files=files))

    risk = BranchRisk(
        compare_status=compare_status,
        merge_base_sha=merge_base_sha,
        base_sha=base_sha,
        main_changed_files=main_changed_files,
        hotspot_diffs=hotspot_diffs,
    )
    return current_files, open_prs, risk


def _fetch_fixture(path: Path) -> tuple[int, list[str], list[PullRequestFiles]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    current = payload["current"]
    current_number = int(current["number"])
    current_files = [str(item) for item in current.get("files", [])]
    open_prs = [
        PullRequestFiles(
            number=int(item["number"]),
            title=str(item.get("title", "")),
            files=frozenset(str(path) for path in item.get("files", [])),
        )
        for item in payload.get("open", [])
    ]
    return current_number, current_files, open_prs


def _append_summary(lines: list[str]) -> None:
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not summary_path:
        return
    with open(summary_path, "a", encoding="utf-8") as summary:
        summary.write("\n".join(lines))
        summary.write("\n")


def _warning(title: str, message: str) -> None:
    escaped = (
        message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    )
    print(f"::warning title={title}::{escaped}")


def _emit_overlap_result(
    current_files: list[str], overlaps: list[tuple[str, PullRequestFiles]]
) -> None:
    touched = sorted(hotspot_files(current_files))
    if not touched:
        print("shared_hotspot_guard: current PR touches no shared hotspot")
        _append_summary(["## Shared hotspot audit", "", "No shared hotspots changed by this PR."])
        return

    if not overlaps:
        print(f"shared_hotspot_guard: no overlap across {len(touched)} shared hotspot(s)")
        _append_summary(
            [
                "## Shared hotspot audit",
                "",
                "No overlapping open PR ownership found.",
                "",
                *[f"- `{path}`" for path in touched],
            ]
        )
        return

    print("shared_hotspot_guard: overlapping open PR ownership detected")
    summary_lines = [
        "## Shared hotspot audit",
        "",
        "> ⚠️ Another open PR touches the same shared hotspot. This is a coordination warning, not an automatic conflict verdict.",
        "",
        "| Hotspot | Other PR |",
        "| --- | --- |",
    ]
    for path, pull in overlaps:
        _warning("Shared hotspot overlap", f"{path} also changed by #{pull.number} {pull.title}")
        summary_lines.append(f"| `{path}` | #{pull.number} — {pull.title} |")
    summary_lines.extend(
        [
            "",
            "Re-audit the overlapping behavior/hunks before continuing; AGENTS.md still permits a proven patch-sized non-overlapping edit.",
        ]
    )
    _append_summary(summary_lines)


def _emit_branch_risk(current_files: list[str], risk: BranchRisk | None, large_diff_threshold: int) -> None:
    if risk is None:
        return

    stale = stale_hotspot_paths(current_files, risk.main_changed_files)
    oversized = oversized_hotspot_diffs(risk.hotspot_diffs, large_diff_threshold)
    lines = [
        "## Shared hotspot branch freshness",
        "",
        f"- Compare status against current base: `{risk.compare_status}`",
        f"- Merge base: `{risk.merge_base_sha[:12]}`",
        f"- Current base: `{risk.base_sha[:12]}`",
    ]

    if stale:
        for path in stale:
            _warning(
                "Stale shared hotspot",
                f"{path} changed on main after this branch diverged; refresh/re-audit before integration.",
            )
        lines.extend(
            [
                "- ⚠️ Shared hotspots changed on main after branch divergence:",
                *[f"  - `{path}`" for path in stale],
            ]
        )
    else:
        lines.append("- No touched shared hotspot changed on main after branch divergence.")

    if risk.hotspot_diffs:
        lines.extend(
            [
                "",
                "| Hotspot | Additions | Deletions | Changed lines |",
                "| --- | ---: | ---: | ---: |",
            ]
        )
        for diff in sorted(risk.hotspot_diffs, key=lambda item: item.path):
            lines.append(
                f"| `{diff.path}` | {diff.additions} | {diff.deletions} | {diff.changed_lines} |"
            )

    for diff in oversized:
        _warning(
            "Large shared hotspot diff",
            f"{diff.path} changes {diff.changed_lines} lines (advisory threshold {large_diff_threshold}); check for unrelated formatter/refactor churn.",
        )
    if oversized:
        lines.extend(
            [
                "",
                f"⚠️ Hotspot diff exceeds the advisory `{large_diff_threshold}` changed-line threshold. Confirm that the breadth is intentional and not unrelated formatting churn.",
            ]
        )

    _append_summary(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fixture", type=Path, help="Read deterministic PR/file data from JSON instead of GitHub")
    parser.add_argument(
        "--large-diff-threshold",
        type=int,
        default=int(os.environ.get("HOTSPOT_LARGE_DIFF_WARN", "200")),
    )
    args = parser.parse_args()

    try:
        risk: BranchRisk | None = None
        if args.fixture:
            current_number, current_files, open_prs = _fetch_fixture(args.fixture)
        else:
            repository = os.environ.get("GITHUB_REPOSITORY", "")
            token = os.environ.get("GITHUB_TOKEN", "")
            current_raw = os.environ.get("CURRENT_PR_NUMBER", "")
            if not repository or not token or not current_raw:
                _warning(
                    "Hotspot audit unavailable",
                    "Missing GITHUB_REPOSITORY, GITHUB_TOKEN, or CURRENT_PR_NUMBER",
                )
                return 0
            current_number = int(current_raw)
            current_files, open_prs, risk = _fetch_live(repository, current_number, token)

        _emit_overlap_result(
            current_files, find_overlaps(current_number, current_files, open_prs)
        )
        _emit_branch_risk(current_files, risk, args.large_diff_threshold)
        return 0
    except (OSError, ValueError, KeyError, json.JSONDecodeError, urllib.error.URLError) as error:
        _warning("Hotspot audit unavailable", str(error))
        _append_summary(
            [
                "## Shared hotspot audit",
                "",
                "⚠️ Hotspot ownership/freshness could not be inspected automatically; perform the normal manual open-PR and base-freshness audit.",
            ]
        )
        return 0


if __name__ == "__main__":
    sys.exit(main())
