#!/usr/bin/env python3
"""Advisory PR-contract validation for concurrent AI development lanes."""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path

from shared_hotspot_conflict_guard import HOTSPOTS

LANES = {"A", "B", "C", "D", "E", "F", "G"}
PREFIX_TO_LANE = {
    "feature/object-": "A",
    "feature/relation-": "B",
    "feature/database-view-": "C",
    "feature/primitives-": "D",
    "feature/search-": "E",
    "feature/storage-": "F",
    "refactor/": "G",
}
WORKFLOW_SUFFIXES = (".yml", ".yaml")


@dataclass(frozen=True)
class Contract:
    lane: str | None
    related_issue: int | None
    dependencies: tuple[int, ...]
    declared_hotspots: frozenset[str]
    hotspots_declared: bool
    migration_impact: str | None


@dataclass(frozen=True)
class OpenPullClaim:
    number: int
    title: str
    related_issue: int | None
    branch: str


def _extract_value(body: str, key: str) -> str | None:
    pattern = re.compile(
        rf"^\s*(?:-\s*)?{re.escape(key)}\s*:\s*(.*?)\s*$",
        re.MULTILINE | re.IGNORECASE,
    )
    match = pattern.search(body)
    return match.group(1).strip() if match else None


def _issue_numbers(value: str | None) -> tuple[int, ...]:
    if not value or value.strip().lower() in {"none", "n/a", "-"}:
        return ()
    return tuple(dict.fromkeys(int(number) for number in re.findall(r"#(\d+)", value)))


def _parse_hotspots(value: str | None) -> tuple[frozenset[str], bool]:
    if value is None:
        return frozenset(), False
    cleaned = value.strip()
    if cleaned.lower() in {"none", "n/a", "-"}:
        return frozenset(), True
    paths = {
        token.strip().strip("`")
        for token in re.split(r"[,;]", cleaned)
        if token.strip().strip("`")
    }
    return frozenset(paths), True


def parse_contract(body: str) -> Contract:
    lane_value = _extract_value(body, "Primary lane")
    lane = lane_value.upper() if lane_value else None
    related = _issue_numbers(_extract_value(body, "Related issue"))
    dependencies = _issue_numbers(_extract_value(body, "Depends on"))
    hotspots, hotspots_declared = _parse_hotspots(_extract_value(body, "Shared hotspots"))
    migration = _extract_value(body, "Migration/data impact")
    return Contract(
        lane=lane,
        related_issue=related[0] if related else None,
        dependencies=dependencies,
        declared_hotspots=hotspots,
        hotspots_declared=hotspots_declared,
        migration_impact=migration.lower() if migration else None,
    )


def expected_lane_for_branch(branch: str) -> str | None:
    if branch.startswith("docs/"):
        return None
    for prefix, lane in PREFIX_TO_LANE.items():
        if branch.startswith(prefix):
            return lane
    return None


def branch_has_issue_token(branch: str, issue_number: int) -> bool:
    return bool(re.search(rf"(?:^|[-_/]){issue_number}(?:$|[-_/])", branch))


def duplicate_issue_claims(
    current_number: int,
    related_issue: int | None,
    open_pulls: list[OpenPullClaim],
) -> list[OpenPullClaim]:
    if related_issue is None:
        return []
    return [
        pull
        for pull in open_pulls
        if pull.number != current_number and pull.related_issue == related_issue
    ]


def is_docs_only(paths: list[str]) -> bool:
    return bool(paths) and all(path.startswith("docs/") and path.endswith(".md") for path in paths)


def actual_hotspots(paths: list[str]) -> frozenset[str]:
    return frozenset(path for path in paths if path in HOTSPOTS)


def detects_branch_mutating_workflow(path: str, content: str) -> bool:
    if not path.startswith(".github/workflows/") or not path.endswith(WORKFLOW_SUFFIXES):
        return False
    has_write = bool(re.search(r"(?mi)^\s*contents\s*:\s*write\s*$", content))
    has_push = bool(re.search(r"(?mi)\bgit\s+push\b|\bpush\s+origin\b", content))
    return has_write and has_push


def changed_paths(base: str, head: str) -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--name-only", base, head],
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def _request_json(url: str, token: str) -> object:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "bookmark-app-pr-coordination-guard",
        },
    )
    with urllib.request.urlopen(request, timeout=15) as response:
        return json.load(response)


def _open_pull_claims(api_root: str, token: str) -> list[OpenPullClaim]:
    payload = _request_json(f"{api_root}/pulls?state=open&per_page=100", token)
    if not isinstance(payload, list):
        raise ValueError("Open pull request response was not a list")

    claims: list[OpenPullClaim] = []
    for row in payload:
        if not isinstance(row, dict):
            continue
        number = row.get("number")
        if not isinstance(number, int):
            continue
        contract = parse_contract(str(row.get("body") or ""))
        head = row.get("head")
        branch = str(head.get("ref") or "") if isinstance(head, dict) else ""
        claims.append(
            OpenPullClaim(
                number=number,
                title=str(row.get("title") or ""),
                related_issue=contract.related_issue,
                branch=branch,
            )
        )
    return claims


def _warn(message: str) -> None:
    escaped = message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    print(f"::warning title=AI PR coordination::{escaped}")


def _append_summary(lines: list[str]) -> None:
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not path:
        return
    with Path(path).open("a", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")


def collect_warnings(
    contract: Contract,
    branch: str,
    paths: list[str],
    open_dependencies: set[int],
    mutating_workflows: list[str],
    duplicate_claims: list[OpenPullClaim] | None = None,
) -> list[str]:
    warnings: list[str] = []
    docs_only = is_docs_only(paths)
    duplicates = duplicate_claims or []

    if contract.lane not in LANES:
        warnings.append("Missing or invalid `Primary lane`; use exactly one of A/B/C/D/E/F/G.")
    expected = expected_lane_for_branch(branch)
    if contract.lane in LANES and expected and contract.lane != expected:
        warnings.append(f"Primary lane {contract.lane} conflicts with branch prefix, which implies lane {expected}.")

    if not docs_only and contract.related_issue is None:
        warnings.append("Runtime/configuration PR is missing `Related issue: #...` metadata.")
    elif not docs_only and contract.related_issue is not None and not branch_has_issue_token(branch, contract.related_issue):
        warnings.append(
            f"Branch `{branch}` does not include Related issue #{contract.related_issue} as a delimited token; "
            "include the focused Issue number so pre-PR remote-branch audits can discover active ownership."
        )

    if duplicates:
        rendered = ", ".join(f"#{pull.number} {pull.title}" for pull in duplicates)
        warnings.append(
            f"Related issue #{contract.related_issue} is also claimed by open PR(s): {rendered}. "
            "Confirm this is intentional umbrella/sequenced work or supersede the duplicate before integration."
        )

    if contract.migration_impact not in {"yes", "no"}:
        warnings.append("`Migration/data impact` must be explicitly `yes` or `no`.")

    actual = actual_hotspots(paths)
    if not contract.hotspots_declared:
        warnings.append("Missing `Shared hotspots` declaration; use `none` or list the touched hotspot paths.")
    elif actual != contract.declared_hotspots:
        warnings.append(
            "Declared shared hotspots do not match the PR diff: "
            f"declared={sorted(contract.declared_hotspots)} actual={sorted(actual)}."
        )

    if open_dependencies:
        warnings.append(
            "Declared dependency is still open: " + ", ".join(f"#{number}" for number in sorted(open_dependencies)) + "."
        )

    if mutating_workflows:
        warnings.append(
            "PR-specific workflow appears to grant `contents: write` and push to a branch: "
            + ", ".join(f"`{path}`" for path in mutating_workflows)
            + ". CI should validate autonomous branches rather than mutate them."
        )
    return warnings


def main() -> int:
    event_path = os.environ.get("GITHUB_EVENT_PATH", "")
    repository = os.environ.get("GITHUB_REPOSITORY", "")
    token = os.environ.get("GITHUB_TOKEN", "")
    base_sha = os.environ.get("CI_BASE_SHA", "")
    head_sha = os.environ.get("CI_HEAD_SHA", "")

    if not event_path or not base_sha or not head_sha:
        _warn("Coordination audit unavailable because event/base/head metadata is missing.")
        return 0

    try:
        event = json.loads(Path(event_path).read_text(encoding="utf-8"))
        pull = event.get("pull_request", {})
        body = str(pull.get("body") or "")
        head = pull.get("head", {})
        branch = str(head.get("ref") or "")
        current_number = int(event.get("number") or pull.get("number") or 0)
        paths = changed_paths(base_sha, head_sha)
        contract = parse_contract(body)

        open_dependencies: set[int] = set()
        duplicates: list[OpenPullClaim] = []
        if repository and token:
            api_root = f"https://api.github.com/repos/{repository}"
            for number in contract.dependencies:
                payload = _request_json(f"{api_root}/issues/{number}", token)
                if isinstance(payload, dict) and payload.get("state") == "open":
                    open_dependencies.add(number)
            duplicates = duplicate_issue_claims(
                current_number,
                contract.related_issue,
                _open_pull_claims(api_root, token),
            )

        mutating_workflows: list[str] = []
        for path in paths:
            if not path.startswith(".github/workflows/") or not path.endswith(WORKFLOW_SUFFIXES):
                continue
            file_path = Path(path)
            if file_path.exists() and detects_branch_mutating_workflow(path, file_path.read_text(encoding="utf-8")):
                mutating_workflows.append(path)

        warnings = collect_warnings(
            contract,
            branch,
            paths,
            open_dependencies,
            mutating_workflows,
            duplicates,
        )
        for warning in warnings:
            _warn(warning)

        _append_summary(
            [
                "## AI PR coordination",
                "",
                f"- Primary lane: `{contract.lane or 'missing'}`",
                f"- Branch: `{branch or 'unknown'}`",
                f"- Related issue: `{('#' + str(contract.related_issue)) if contract.related_issue else 'missing/optional-docs'}`",
                f"- Branch contains issue token: `{'yes' if contract.related_issue and branch_has_issue_token(branch, contract.related_issue) else 'n/a/no'}`",
                f"- Other open PRs claiming Related issue: `{', '.join('#' + str(pull.number) for pull in duplicates) if duplicates else 'none'}`",
                f"- Declared dependencies: `{', '.join('#' + str(number) for number in contract.dependencies) if contract.dependencies else 'none'}`",
                f"- Actual shared hotspots: `{', '.join(sorted(actual_hotspots(paths))) if actual_hotspots(paths) else 'none'}`",
                f"- Coordination warnings: `{len(warnings)}`",
                "",
                *(["### Warnings", *[f"- ⚠️ {warning}" for warning in warnings]] if warnings else ["No coordination warnings."]),
            ]
        )
        return 0
    except (OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.CalledProcessError, urllib.error.URLError) as error:
        _warn(f"Coordination audit unavailable: {error}")
        return 0


if __name__ == "__main__":
    sys.exit(main())
