#!/usr/bin/env python3
"""Advisory single-writer lease checks for Drift schema migrations."""

from __future__ import annotations

import base64
import difflib
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
from typing import Iterable

SCHEMA_FILE = "lib/data/app_database_schema.dart"
MIGRATIONS_FILE = "lib/data/app_database_migrations.dart"
APP_DATABASE_FILE = "lib/data/app_database.dart"
DIRECT_MIGRATION_FILES = frozenset({SCHEMA_FILE, MIGRATIONS_FILE})


@dataclass(frozen=True)
class MigrationClaim:
    number: int
    title: str
    reasons: frozenset[str]


def patch_changes_schema_version(patch: str) -> bool:
    for line in patch.splitlines():
        if line.startswith(("+++", "---")):
            continue
        if not line.startswith(("+", "-")):
            continue
        if re.search(r"\bschemaVersion\b", line[1:]):
            return True
    return False


def schema_version_signature(content: str) -> tuple[str, ...]:
    return tuple(
        line.strip()
        for line in content.splitlines()
        if re.search(r"\bschemaVersion\b", line)
    )


def migration_reasons(
    paths: Iterable[str],
    app_database_patch: str = "",
) -> frozenset[str]:
    path_set = set(paths)
    reasons = {path for path in DIRECT_MIGRATION_FILES if path in path_set}
    if APP_DATABASE_FILE in path_set and patch_changes_schema_version(app_database_patch):
        reasons.add(f"{APP_DATABASE_FILE}:schemaVersion")
    return frozenset(reasons)


def competing_claims(
    current_number: int,
    current_reasons: frozenset[str],
    open_claims: Iterable[MigrationClaim],
) -> list[MigrationClaim]:
    if not current_reasons:
        return []
    return [
        claim
        for claim in open_claims
        if claim.number != current_number and claim.reasons
    ]


def changed_paths(base: str, head: str) -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=ACMR", base, head],
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def changed_patch(base: str, head: str, path: str) -> str:
    result = subprocess.run(
        ["git", "diff", "--unified=0", base, head, "--", path],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout


def _request_json(url: str, token: str) -> object:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "bookmark-app-migration-lease-guard",
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


def _content_text(api_root: str, path: str, ref: str, token: str) -> str:
    quoted_path = urllib.parse.quote(path, safe="/")
    quoted_ref = urllib.parse.quote(ref, safe="")
    payload = _request_json(
        f"{api_root}/contents/{quoted_path}?ref={quoted_ref}", token
    )
    if not isinstance(payload, dict):
        raise ValueError(f"GitHub contents response was not an object for {path}")
    if payload.get("encoding") != "base64":
        raise ValueError(f"Unexpected GitHub contents encoding for {path}")
    encoded = str(payload.get("content") or "").replace("\n", "")
    return base64.b64decode(encoded).decode("utf-8")


def _schema_version_changed_from_contents(
    api_root: str,
    base_sha: str,
    head_sha: str,
    token: str,
) -> bool:
    base_content = _content_text(api_root, APP_DATABASE_FILE, base_sha, token)
    head_content = _content_text(api_root, APP_DATABASE_FILE, head_sha, token)
    return schema_version_signature(base_content) != schema_version_signature(head_content)


def _claim_for_open_pull(
    api_root: str,
    pull: dict[str, object],
    token: str,
) -> MigrationClaim | None:
    number = pull.get("number")
    if not isinstance(number, int):
        return None

    files = _paged_list(f"{api_root}/pulls/{number}/files", token)
    paths = [str(row.get("filename") or "") for row in files]
    reasons = {path for path in DIRECT_MIGRATION_FILES if path in paths}

    app_rows = [
        row for row in files if str(row.get("filename") or "") == APP_DATABASE_FILE
    ]
    if app_rows:
        patches = [str(row.get("patch") or "") for row in app_rows]
        if any(patch_changes_schema_version(patch) for patch in patches if patch):
            reasons.add(f"{APP_DATABASE_FILE}:schemaVersion")
        elif not any(patches):
            base = pull.get("base")
            head = pull.get("head")
            base_sha = str(base.get("sha") or "") if isinstance(base, dict) else ""
            head_sha = str(head.get("sha") or "") if isinstance(head, dict) else ""
            if base_sha and head_sha and _schema_version_changed_from_contents(
                api_root, base_sha, head_sha, token
            ):
                reasons.add(f"{APP_DATABASE_FILE}:schemaVersion")

    return MigrationClaim(
        number=number,
        title=str(pull.get("title") or ""),
        reasons=frozenset(reasons),
    )


def open_migration_claims(api_root: str, token: str) -> list[MigrationClaim]:
    pulls = _paged_list(f"{api_root}/pulls?state=open", token)
    claims: list[MigrationClaim] = []
    for pull in pulls:
        claim = _claim_for_open_pull(api_root, pull, token)
        if claim is not None and claim.reasons:
            claims.append(claim)
    return claims


def _warning(message: str) -> None:
    escaped = message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    print(f"::warning title=Migration single-writer lease::{escaped}")


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
    base_sha = os.environ.get("CI_BASE_SHA", "")
    head_sha = os.environ.get("CI_HEAD_SHA", "")

    if not repository or not token or not current_raw or not base_sha or not head_sha:
        _warning("Audit unavailable because repository/token/PR/base/head metadata is missing.")
        return 0

    try:
        current_number = int(current_raw)
        paths = changed_paths(base_sha, head_sha)
        app_patch = (
            changed_patch(base_sha, head_sha, APP_DATABASE_FILE)
            if APP_DATABASE_FILE in paths
            else ""
        )
        current_reasons = migration_reasons(paths, app_patch)

        lines = [
            "## Migration single-writer lease",
            "",
            f"- Current PR migration-sensitive: `{'yes' if current_reasons else 'no'}`",
            f"- Reasons: `{', '.join(sorted(current_reasons)) if current_reasons else 'none'}`",
        ]

        if not current_reasons:
            lines.extend(
                [
                    "- No migration lease acquired; ordinary non-schema AppDatabase edits remain outside this lease.",
                    "",
                    "No migration lease warnings.",
                ]
            )
            _append_summary(lines)
            print("migration_lease_guard: current PR does not change migration-sensitive state")
            return 0

        api_root = f"https://api.github.com/repos/{repository}"
        claims = open_migration_claims(api_root, token)
        competing = competing_claims(current_number, current_reasons, claims)

        if competing:
            lines.extend(
                [
                    "",
                    "### Competing migration owners",
                    "",
                    "| PR | Migration-sensitive reasons |",
                    "| --- | --- |",
                ]
            )
            for claim in competing:
                reasons = ", ".join(sorted(claim.reasons))
                _warning(
                    f"PR #{claim.number} {claim.title} also owns migration-sensitive work ({reasons}). "
                    "Sequence these migrations and rebase/re-audit after the active migration lands."
                )
                lines.append(f"| #{claim.number} — {claim.title} | `{reasons}` |")
        else:
            lines.extend(["", "No competing open migration owner detected."])

        _append_summary(lines)
        return 0
    except (
        OSError,
        ValueError,
        KeyError,
        UnicodeDecodeError,
        json.JSONDecodeError,
        subprocess.CalledProcessError,
        urllib.error.URLError,
    ) as error:
        _warning(f"Audit unavailable: {error}")
        return 0


if __name__ == "__main__":
    sys.exit(main())
