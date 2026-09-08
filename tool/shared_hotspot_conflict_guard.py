#!/usr/bin/env python3
"""Warn when this PR and another open PR touch the same shared hotspot."""

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


def _fetch_live(repository: str, current_number: int, token: str) -> tuple[list[str], list[PullRequestFiles]]:
    api_root = f"https://api.github.com/repos/{repository}"
    current_file_rows = _paged_list(f"{api_root}/pulls/{current_number}/files", token)
    current_files = [str(row.get("filename", "")) for row in current_file_rows]

    # Avoid scanning every open PR when the current PR has no shared hotspot.
    if not hotspot_files(current_files):
        return current_files, []

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
    return current_files, open_prs


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


def _emit_result(current_files: list[str], overlaps: list[tuple[str, PullRequestFiles]]) -> None:
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
        message = f"{path} also changed by #{pull.number} {pull.title}".replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
        print(f"::warning title=Shared hotspot overlap::{message}")
        summary_lines.append(f"| `{path}` | #{pull.number} — {pull.title} |")
    summary_lines.extend(
        [
            "",
            "Re-audit the overlapping behavior/hunks before continuing; AGENTS.md still permits a proven patch-sized non-overlapping edit.",
        ]
    )
    _append_summary(summary_lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fixture", type=Path, help="Read deterministic PR/file data from JSON instead of GitHub")
    args = parser.parse_args()

    try:
        if args.fixture:
            current_number, current_files, open_prs = _fetch_fixture(args.fixture)
        else:
            repository = os.environ.get("GITHUB_REPOSITORY", "")
            token = os.environ.get("GITHUB_TOKEN", "")
            current_raw = os.environ.get("CURRENT_PR_NUMBER", "")
            if not repository or not token or not current_raw:
                print("::warning title=Hotspot audit unavailable::Missing GITHUB_REPOSITORY, GITHUB_TOKEN, or CURRENT_PR_NUMBER")
                return 0
            current_number = int(current_raw)
            current_files, open_prs = _fetch_live(repository, current_number, token)

        _emit_result(current_files, find_overlaps(current_number, current_files, open_prs))
        return 0
    except (OSError, ValueError, KeyError, json.JSONDecodeError, urllib.error.URLError) as error:
        message = str(error).replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
        print(f"::warning title=Hotspot audit unavailable::{message}")
        _append_summary(["## Shared hotspot audit", "", "⚠️ Hotspot ownership could not be inspected automatically; perform the normal manual open-PR audit."])
        return 0


if __name__ == "__main__":
    sys.exit(main())
