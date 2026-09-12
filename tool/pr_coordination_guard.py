#!/usr/bin/env python3
"""PR-contract enforcement for concurrent AI development lanes.

Deterministic violations are blocking. Heuristic coordination signals remain warnings.
Dependabot dependency PRs are exempt from AI metadata requirements, but never from
workflow self-mutation safety checks.
"""

from __future__ import annotations

import base64
import binascii
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path

from shared_hotspot_conflict_guard import HOTSPOTS

LANES = {"A", "B", "C", "D", "E", "F", "G", "H"}
PREFIX_TO_LANE = {
    "feature/object-": "A",
    "feature/relation-": "B",
    "feature/database-view-": "C",
    "feature/primitives-": "D",
    "feature/search-": "E",
    "feature/storage-": "F",
    "refactor/": "G",
    "oversight/": "H",
}
WORKFLOW_SUFFIXES = (".yml", ".yaml")
APPROVAL_POLICY_SENTINEL = "DESTRUCTIVE_APPROVAL_POLICY_V2"
APPROVAL_GUARD_PATH = "tool/pr_coordination_guard.py"
APPROVAL_ELIGIBLE_PERMISSIONS = frozenset({"write", "admin"})


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


def is_dependency_bot(author_login: str, branch: str) -> bool:
    normalized = author_login.strip().lower()
    return normalized == "dependabot[bot]" or branch.startswith("dependabot/")


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


def patch_for_path(base: str, head: str, path: str) -> str:
    result = subprocess.run(
        ["git", "diff", "--unified=0", base, head, "--", path],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout


def _added_lines(patch: str) -> list[str]:
    return [
        line[1:]
        for line in patch.splitlines()
        if line.startswith("+") and not line.startswith("+++")
    ]


def destructive_risks_for_patch(path: str, patch: str) -> list[str]:
    added = _added_lines(patch)
    if not added:
        return []
    joined = "\n".join(added)
    reasons: list[str] = []

    if path == "lib/data/app_database.dart" and re.search(r"\bschemaVersion\b", joined):
        reasons.append("Drift schemaVersion changes")

    if path.endswith((".dart", ".sql")) and re.search(
        r"(?i)\bDROP\s+(?:TABLE|COLUMN|INDEX)\b|\bALTER\s+TABLE\b[^\n;]*\bDROP\b",
        joined,
    ):
        reasons.append("destructive SQL/schema operation")

    if path.startswith("macos/") and re.search(
        r"\bPRODUCT_BUNDLE_IDENTIFIER\s*=|\bCFBundleIdentifier\b", joined
    ):
        reasons.append("macOS Bundle Identifier changes")

    sensitive_storage_path = (
        path == "lib/services/profile_manager.dart"
        or "vault" in path.lower()
        or "managed_file" in path.lower()
        or path.startswith("lib/features/storage/")
    )
    if sensitive_storage_path and re.search(r"\.(?:delete|deleteSync)\s*\(", joined):
        reasons.append("physical Vault/managed-file deletion behavior")

    return reasons


def approval_policy_active(base: str) -> bool:
    """Return whether a specific git base already contains the v2 approval contract."""
    result = subprocess.run(
        ["git", "show", f"{base}:{APPROVAL_GUARD_PATH}"],
        check=False,
        capture_output=True,
        text=True,
    )
    return result.returncode == 0 and APPROVAL_POLICY_SENTINEL in result.stdout


def approval_policy_sensitive_paths(paths: list[str]) -> bool:
    return APPROVAL_GUARD_PATH in paths or any(
        path.startswith(".github/workflows/") and path.endswith(WORKFLOW_SUFFIXES)
        for path in paths
    )


def approval_policy_active_from_contents(payload: object) -> bool:
    """Read the v2 sentinel from a GitHub contents API response."""
    if not isinstance(payload, dict):
        raise ValueError("Approval policy contents response was not an object")
    if payload.get("encoding") != "base64":
        raise ValueError("Approval policy contents response was not base64 encoded")
    encoded = str(payload.get("content") or "").replace("\n", "")
    try:
        content = base64.b64decode(encoded).decode("utf-8")
    except (binascii.Error, UnicodeDecodeError) as error:
        raise ValueError("Approval policy contents response could not be decoded") from error
    return APPROVAL_POLICY_SENTINEL in content


def approval_policy_risks_for_patch(
    path: str,
    patch: str,
    *,
    policy_active: bool,
) -> list[str]:
    if not policy_active:
        return []
    if path == APPROVAL_GUARD_PATH:
        return ["destructive-approval guard policy changes"]
    if path.startswith(".github/workflows/") and re.search(
        r"(?mi)^[+-].*(?:\bmerge-gate\b|pr_coordination_guard\.py|AI PR coordination audit)",
        patch,
    ):
        return ["destructive-approval/required-gate workflow wiring changes"]
    return []


def destructive_risks(
    base: str,
    head: str,
    paths: list[str],
    *,
    policy_active: bool | None = None,
) -> list[str]:
    rendered: list[str] = []
    if policy_active is None:
        policy_active = approval_policy_active(base)
    for path in paths:
        patch = patch_for_path(base, head, path)
        reasons = destructive_risks_for_patch(path, patch)
        reasons.extend(
            approval_policy_risks_for_patch(
                path,
                patch,
                policy_active=policy_active,
            )
        )
        for reason in reasons:
            rendered.append(f"{reason} in `{path}`")
    return rendered


def _review_sort_key(row: dict[str, object]) -> tuple[str, int]:
    return str(row.get("submitted_at") or ""), int(row.get("id") or 0)


def current_distinct_approved_reviewers(
    reviews: object,
    author_login: str,
    head_sha: str,
) -> tuple[str, ...]:
    """Return distinct reviewers whose latest review approves the current head."""
    if not isinstance(reviews, list):
        return ()
    author = author_login.strip().lower()
    latest: dict[str, dict[str, object]] = {}
    for raw in reviews:
        if not isinstance(raw, dict):
            continue
        user = raw.get("user")
        if not isinstance(user, dict):
            continue
        login = str(user.get("login") or "").strip()
        if not login or str(user.get("type") or "User") != "User":
            continue
        key = login.lower()
        current = latest.get(key)
        if current is None or _review_sort_key(raw) >= _review_sort_key(current):
            latest[key] = raw

    approved: list[str] = []
    for key, row in latest.items():
        if key == author:
            continue
        if str(row.get("state") or "").upper() != "APPROVED":
            continue
        if str(row.get("commit_id") or "") != head_sha:
            continue
        user = row.get("user")
        if isinstance(user, dict):
            approved.append(str(user.get("login") or ""))
    return tuple(sorted(set(approved), key=str.lower))


def permission_allows_destructive_approval(payload: object) -> bool:
    return (
        isinstance(payload, dict)
        and str(payload.get("permission") or "").lower() in APPROVAL_ELIGIBLE_PERMISSIONS
    )


def eligible_destructive_approver(
    reviews: object,
    author_login: str,
    head_sha: str,
    permission_by_login: dict[str, object],
) -> str | None:
    for login in current_distinct_approved_reviewers(reviews, author_login, head_sha):
        payload = permission_by_login.get(login.lower())
        if permission_allows_destructive_approval(payload):
            return login
    return None


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


def _request_paginated_list(
    url: str,
    token: str,
    *,
    per_page: int = 100,
) -> list[object]:
    """Fetch every page of a GitHub list endpoint or fail closed."""
    if per_page < 1 or per_page > 100:
        raise ValueError("GitHub pagination page size must be between 1 and 100")
    separator = "&" if "?" in url else "?"
    rows: list[object] = []
    page = 1
    while True:
        payload = _request_json(
            f"{url}{separator}per_page={per_page}&page={page}",
            token,
        )
        if not isinstance(payload, list):
            raise ValueError("Paginated GitHub response was not a list")
        rows.extend(payload)
        if len(payload) < per_page:
            return rows
        page += 1


def _current_base_approval_policy_active(
    api_root: str,
    token: str,
    base_ref: str,
) -> bool:
    if not base_ref:
        raise ValueError("Pull-request base ref is unavailable for approval policy authority")
    quoted_path = urllib.parse.quote(APPROVAL_GUARD_PATH, safe="/")
    quoted_ref = urllib.parse.quote(base_ref, safe="")
    payload = _request_json(
        f"{api_root}/contents/{quoted_path}?ref={quoted_ref}",
        token,
    )
    return approval_policy_active_from_contents(payload)


def _open_pull_claims(api_root: str, token: str) -> list[OpenPullClaim]:
    payload = _request_paginated_list(f"{api_root}/pulls?state=open", token)

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


def collect_errors(
    contract: Contract,
    paths: list[str],
    mutating_workflows: list[str],
    duplicate_claims: list[OpenPullClaim] | None = None,
    dependency_bot: bool = False,
) -> list[str]:
    errors: list[str] = []

    if mutating_workflows:
        errors.append(
            "Workflow grants `contents: write` and pushes to a branch: "
            + ", ".join(f"`{path}`" for path in mutating_workflows)
            + ". CI validates autonomous branches; it must not self-mutate them."
        )

    if dependency_bot:
        return errors

    docs_only = is_docs_only(paths)
    duplicates = duplicate_claims or []

    if contract.lane not in LANES:
        errors.append("Missing or invalid `Primary lane`; use exactly one of A/B/C/D/E/F/G/H.")

    if not docs_only and contract.related_issue is None:
        errors.append("Runtime/configuration PR is missing `Related issue: #...` metadata.")

    if duplicates:
        rendered = ", ".join(f"#{pull.number} {pull.title}" for pull in duplicates)
        errors.append(
            f"Related issue #{contract.related_issue} is already claimed by open PR(s): {rendered}. "
            "One focused Issue may have only one active implementation owner/PR."
        )

    if contract.migration_impact not in {"yes", "no"}:
        errors.append("`Migration/data impact` must be explicitly `yes` or `no`.")

    actual = actual_hotspots(paths)
    if not contract.hotspots_declared:
        errors.append("Missing `Shared hotspots` declaration; use `none` or list the touched hotspot paths.")
    elif actual != contract.declared_hotspots:
        errors.append(
            "Declared shared hotspots do not match the PR diff: "
            f"declared={sorted(contract.declared_hotspots)} actual={sorted(actual)}."
        )

    return errors


def collect_warnings(
    contract: Contract,
    branch: str,
    paths: list[str],
    open_dependencies: set[int],
    dependency_bot: bool = False,
) -> list[str]:
    if dependency_bot:
        return []

    warnings: list[str] = []
    docs_only = is_docs_only(paths)

    expected = expected_lane_for_branch(branch)
    if contract.lane in LANES and expected and contract.lane != expected:
        warnings.append(
            f"Primary lane {contract.lane} conflicts with branch prefix, which implies lane {expected}."
        )

    if (
        not docs_only
        and contract.related_issue is not None
        and not branch_has_issue_token(branch, contract.related_issue)
    ):
        warnings.append(
            f"Branch `{branch}` does not include Related issue #{contract.related_issue} as a delimited token; "
            "include the focused Issue number so pre-PR remote-branch audits can discover active ownership."
        )

    if open_dependencies:
        warnings.append(
            "Declared dependency is still open: "
            + ", ".join(f"#{number}" for number in sorted(open_dependencies))
            + ". Confirm the PR is intentionally sequenced before integration."
        )
    return warnings


def _warning(message: str) -> None:
    escaped = message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    print(f"::warning title=AI PR coordination::{escaped}")


def _error(message: str) -> None:
    escaped = message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    print(f"::error title=AI PR coordination::{escaped}")


def _append_summary(lines: list[str]) -> None:
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not path:
        return
    with Path(path).open("a", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")


def main() -> int:
    event_path = os.environ.get("GITHUB_EVENT_PATH", "")
    repository = os.environ.get("GITHUB_REPOSITORY", "")
    token = os.environ.get("GITHUB_TOKEN", "")
    base_sha = os.environ.get("CI_BASE_SHA", "")
    head_sha = os.environ.get("CI_HEAD_SHA", "")

    if not event_path or not base_sha or not head_sha:
        _error("Coordination gate unavailable because event/base/head metadata is missing.")
        return 1

    try:
        event = json.loads(Path(event_path).read_text(encoding="utf-8"))
        pull = event.get("pull_request", {})
        body = str(pull.get("body") or "")
        head = pull.get("head", {})
        branch = str(head.get("ref") or "")
        base = pull.get("base", {})
        base_ref = str(base.get("ref") or "") if isinstance(base, dict) else ""
        author = pull.get("user", {})
        author_login = str(author.get("login") or "") if isinstance(author, dict) else ""
        current_number = int(event.get("number") or pull.get("number") or 0)
        paths = changed_paths(base_sha, head_sha)
        contract = parse_contract(body)
        dependency_bot = is_dependency_bot(author_login, branch)

        api_root = f"https://api.github.com/repos/{repository}" if repository else ""
        open_dependencies: set[int] = set()
        duplicates: list[OpenPullClaim] = []
        if api_root and token and not dependency_bot:
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
            if file_path.exists() and detects_branch_mutating_workflow(
                path, file_path.read_text(encoding="utf-8")
            ):
                mutating_workflows.append(path)

        errors = collect_errors(
            contract,
            paths,
            mutating_workflows,
            duplicates,
            dependency_bot=dependency_bot,
        )
        warnings = collect_warnings(
            contract,
            branch,
            paths,
            open_dependencies,
            dependency_bot=dependency_bot,
        )

        policy_active_override: bool | None = None
        if approval_policy_sensitive_paths(paths):
            if not api_root or not token:
                raise ValueError(
                    "Current-base destructive approval policy cannot be verified without repository/token metadata"
                )
            policy_active_override = _current_base_approval_policy_active(
                api_root,
                token,
                base_ref,
            )

        risks = destructive_risks(
            base_sha,
            head_sha,
            paths,
            policy_active=policy_active_override,
        )
        risk_approver: str | None = None
        review_candidates: tuple[str, ...] = ()
        if risks and api_root and token and current_number:
            reviews = _request_paginated_list(
                f"{api_root}/pulls/{current_number}/reviews",
                token,
            )
            review_candidates = current_distinct_approved_reviewers(
                reviews,
                author_login,
                head_sha,
            )
            permission_by_login: dict[str, object] = {}
            for login in review_candidates:
                quoted = urllib.parse.quote(login, safe="")
                permission_by_login[login.lower()] = _request_json(
                    f"{api_root}/collaborators/{quoted}/permission", token
                )
            risk_approver = eligible_destructive_approver(
                reviews,
                author_login,
                head_sha,
                permission_by_login,
            )

        if risks and risk_approver is None:
            errors.append(
                "High-confidence destructive/irreversible or approval-policy change detected: "
                + "; ".join(risks)
                + ". A GitHub user other than the PR author must submit an `APPROVED` pull-request review "
                "for the current head commit and have repository write/admin permission. "
                "PR-body markers, labels, conversation comments, self-review, stale reviews and read-only reviewers do not count."
            )

        for warning in warnings:
            _warning(warning)
        for error in errors:
            _error(error)

        _append_summary(
            [
                "## AI PR coordination",
                "",
                f"- Dependency bot exemption: `{'yes' if dependency_bot else 'no'}`",
                f"- Primary lane: `{contract.lane or 'missing'}`",
                f"- Branch: `{branch or 'unknown'}`",
                f"- Related issue: `{('#' + str(contract.related_issue)) if contract.related_issue else 'missing/optional-docs'}`",
                f"- Declared dependencies: `{', '.join('#' + str(number) for number in contract.dependencies) if contract.dependencies else 'none'}`",
                f"- Other open PRs claiming Related issue: `{', '.join('#' + str(pull.number) for pull in duplicates) if duplicates else 'none'}`",
                f"- Actual shared hotspots: `{', '.join(sorted(actual_hotspots(paths))) if actual_hotspots(paths) else 'none'}`",
                f"- Current-base approval policy: `{('active' if policy_active_override else 'bootstrap/inactive') if policy_active_override is not None else 'not-sensitive'}`",
                f"- Destructive/policy-risk findings: `{len(risks)}`",
                f"- Current-head distinct approval candidates: `{', '.join(review_candidates) if review_candidates else 'none'}`",
                f"- Eligible destructive-risk approver: `{risk_approver or 'none/not-required'}`",
                f"- Blocking coordination errors: `{len(errors)}`",
                f"- Advisory coordination warnings: `{len(warnings)}`",
                "",
                *(
                    ["### Blocking errors", *[f"- ❌ {error}" for error in errors]]
                    if errors
                    else ["No blocking coordination errors."]
                ),
                "",
                *(
                    ["### Advisory warnings", *[f"- ⚠️ {warning}" for warning in warnings]]
                    if warnings
                    else ["No advisory coordination warnings."]
                ),
            ]
        )
        return 1 if errors else 0
    except (
        OSError,
        ValueError,
        KeyError,
        binascii.Error,
        json.JSONDecodeError,
        subprocess.CalledProcessError,
        urllib.error.URLError,
    ) as error:
        _error(f"Coordination gate unavailable: {error}")
        return 1


if __name__ == "__main__":
    sys.exit(main())