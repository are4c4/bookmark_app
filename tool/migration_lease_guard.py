#!/usr/bin/env python3
"""Deterministic single-writer gate for durable application schema changes."""

from __future__ import annotations

import base64
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
from typing import Iterable, Mapping

SCHEMA_FILE = "lib/data/app_database_schema.dart"
MIGRATIONS_FILE = "lib/data/app_database_migrations.dart"
APP_DATABASE_FILE = "lib/data/app_database.dart"
APP_DATABASE_SCHEMA_REASON = f"{APP_DATABASE_FILE}:schemaVersion"
DIRECT_MIGRATION_FILES = frozenset({SCHEMA_FILE, MIGRATIONS_FILE})
PRODUCTION_DART_PREFIX = "lib/"
_DURABLE_DDL_PATTERN = re.compile(
    r"\b(?P<kind>CREATE\s+(?:UNIQUE\s+)?(?:TABLE|INDEX)|ALTER\s+TABLE)"
    r"\s+(?:IF\s+NOT\s+EXISTS\s+)?(?P<name>[A-Za-z_][A-Za-z0-9_]*)",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class MigrationClaim:
    number: int
    title: str
    reasons: frozenset[str]


@dataclass(frozen=True)
class ChangedFile:
    status: str
    path: str
    previous_path: str | None = None


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


def _production_dart_path(path: str) -> bool:
    return path.startswith(PRODUCTION_DART_PREFIX) and path.endswith(".dart")


def _added_patch_text(patch: str) -> str:
    return "\n".join(
        line[1:]
        for line in patch.splitlines()
        if line.startswith("+") and not line.startswith("+++")
    )


def durable_schema_ddl_signature(content: str) -> frozenset[tuple[str, str]]:
    """Return high-confidence persistent DDL authorities found in production text."""
    signatures: set[tuple[str, str]] = set()
    for match in _DURABLE_DDL_PATTERN.finditer(content):
        kind = "-".join(match.group("kind").lower().split())
        name = match.group("name").lower()
        signatures.add((kind, name))
    return frozenset(signatures)


def durable_schema_ddl_reasons(path: str, patch: str) -> frozenset[str]:
    """Classify newly-added production DDL from a unified patch."""
    if not _production_dart_path(path):
        return frozenset()
    return frozenset(
        f"{path}:durable-ddl:{kind}:{name}"
        for kind, name in durable_schema_ddl_signature(_added_patch_text(patch))
    )


def durable_schema_ddl_reasons_from_contents(
    path: str,
    before: str,
    after: str,
) -> frozenset[str]:
    """Fallback classification when GitHub omits a large-file patch."""
    if not _production_dart_path(path):
        return frozenset()
    added = durable_schema_ddl_signature(after).difference(
        durable_schema_ddl_signature(before)
    )
    return frozenset(
        f"{path}:durable-ddl:{kind}:{name}" for kind, name in added
    )


def migration_reasons(
    paths: Iterable[str],
    app_database_patch: str = "",
) -> frozenset[str]:
    path_set = set(paths)
    reasons = {path for path in DIRECT_MIGRATION_FILES if path in path_set}
    if APP_DATABASE_FILE in path_set and patch_changes_schema_version(app_database_patch):
        reasons.add(APP_DATABASE_SCHEMA_REASON)
    return frozenset(reasons)


def parse_changed_files(output: str) -> list[ChangedFile]:
    """Parse `git diff --name-status` while preserving rename source paths."""
    records: list[ChangedFile] = []
    for raw in output.splitlines():
        if not raw.strip():
            continue
        fields = raw.split("\t")
        status = fields[0].strip()
        if status.startswith(("R", "C")):
            if len(fields) != 3:
                raise ValueError(f"Unexpected renamed/copied git diff row: {raw}")
            records.append(
                ChangedFile(
                    status=status,
                    previous_path=fields[1].strip(),
                    path=fields[2].strip(),
                )
            )
            continue
        if len(fields) != 2:
            raise ValueError(f"Unexpected git diff row: {raw}")
        records.append(ChangedFile(status=status, path=fields[1].strip()))
    return records


def paths_for_migration_classification(files: Iterable[ChangedFile]) -> list[str]:
    """Return effective paths, retaining old names only for renames."""
    paths: list[str] = []
    for changed in files:
        candidates: list[str] = []
        if changed.status.startswith("R") and changed.previous_path:
            candidates.append(changed.previous_path)
        candidates.append(changed.path)
        for path in candidates:
            if path and path not in paths:
                paths.append(path)
    return paths


def app_database_authority_removed_or_renamed(files: Iterable[ChangedFile]) -> bool:
    for changed in files:
        if changed.status.startswith("D") and changed.path == APP_DATABASE_FILE:
            return True
        if (
            changed.status.startswith("R")
            and changed.previous_path == APP_DATABASE_FILE
            and changed.path != APP_DATABASE_FILE
        ):
            return True
    return False


def current_migration_reasons(
    files: Iterable[ChangedFile],
    app_database_patch: str = "",
    file_patches: Mapping[str, str] | None = None,
) -> frozenset[str]:
    file_list = list(files)
    reasons = set(
        migration_reasons(
            paths_for_migration_classification(file_list),
            app_database_patch,
        )
    )
    if app_database_authority_removed_or_renamed(file_list):
        reasons.add(APP_DATABASE_SCHEMA_REASON)
    if file_patches:
        for path, patch in file_patches.items():
            reasons.update(durable_schema_ddl_reasons(path, patch))
    return frozenset(reasons)


def active_migration_owner(
    current_number: int,
    current_reasons: frozenset[str],
    open_claims: Iterable[MigrationClaim],
    *,
    current_title: str = "Current migration PR",
) -> MigrationClaim | None:
    """Return the unique active migration owner, using the oldest open PR number."""
    if not current_reasons:
        return None

    claims_by_number = {
        claim.number: claim for claim in open_claims if claim.reasons
    }
    existing_current = claims_by_number.get(current_number)
    claims_by_number[current_number] = MigrationClaim(
        number=current_number,
        title=(existing_current.title if existing_current else current_title) or current_title,
        reasons=current_reasons,
    )
    return min(claims_by_number.values(), key=lambda claim: claim.number)


def blocking_migration_owner(
    current_number: int,
    current_reasons: frozenset[str],
    open_claims: Iterable[MigrationClaim],
    *,
    current_title: str = "Current migration PR",
) -> MigrationClaim | None:
    owner = active_migration_owner(
        current_number,
        current_reasons,
        open_claims,
        current_title=current_title,
    )
    if owner is None or owner.number == current_number:
        return None
    return owner


def queued_migration_claims(
    active_owner: MigrationClaim | None,
    open_claims: Iterable[MigrationClaim],
) -> list[MigrationClaim]:
    if active_owner is None:
        return []
    return sorted(
        (
            claim
            for claim in open_claims
            if claim.reasons and claim.number != active_owner.number
        ),
        key=lambda claim: claim.number,
    )


def changed_files(base: str, head: str) -> list[ChangedFile]:
    result = subprocess.run(
        [
            "git",
            "diff",
            "--name-status",
            "--find-renames",
            "--diff-filter=ACMRD",
            base,
            head,
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return parse_changed_files(result.stdout)


def changed_paths(base: str, head: str) -> list[str]:
    """Compatibility helper returning paths from the status-aware classifier."""
    return paths_for_migration_classification(changed_files(base, head))


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
    paths: list[str] = []
    for row in files:
        filename = str(row.get("filename") or "")
        previous = str(row.get("previous_filename") or "")
        if str(row.get("status") or "") == "renamed" and previous:
            paths.append(previous)
        if filename:
            paths.append(filename)
    reasons = {path for path in DIRECT_MIGRATION_FILES if path in paths}

    base = pull.get("base")
    head = pull.get("head")
    base_sha = str(base.get("sha") or "") if isinstance(base, dict) else ""
    head_sha = str(head.get("sha") or "") if isinstance(head, dict) else ""

    app_rows = [
        row
        for row in files
        if str(row.get("filename") or "") == APP_DATABASE_FILE
        or str(row.get("previous_filename") or "") == APP_DATABASE_FILE
    ]
    if app_rows:
        authority_removed = any(
            (
                str(row.get("status") or "") == "removed"
                and str(row.get("filename") or "") == APP_DATABASE_FILE
            )
            or (
                str(row.get("status") or "") == "renamed"
                and str(row.get("previous_filename") or "") == APP_DATABASE_FILE
                and str(row.get("filename") or "") != APP_DATABASE_FILE
            )
            for row in app_rows
        )
        if authority_removed:
            reasons.add(APP_DATABASE_SCHEMA_REASON)
        else:
            patches = [str(row.get("patch") or "") for row in app_rows]
            if any(patch_changes_schema_version(patch) for patch in patches if patch):
                reasons.add(APP_DATABASE_SCHEMA_REASON)
            elif not any(patches):
                if base_sha and head_sha and _schema_version_changed_from_contents(
                    api_root, base_sha, head_sha, token
                ):
                    reasons.add(APP_DATABASE_SCHEMA_REASON)

    for row in files:
        filename = str(row.get("filename") or "")
        status = str(row.get("status") or "")
        if not _production_dart_path(filename) or status == "removed":
            continue
        patch = str(row.get("patch") or "")
        if patch:
            reasons.update(durable_schema_ddl_reasons(filename, patch))
            continue
        if not head_sha:
            raise ValueError(
                f"Cannot classify durable schema DDL for PR #{number}: missing head SHA"
            )
        after = _content_text(api_root, filename, head_sha, token)
        before = ""
        if status != "added":
            if not base_sha:
                raise ValueError(
                    f"Cannot classify durable schema DDL for PR #{number}: missing base SHA"
                )
            before = _content_text(api_root, filename, base_sha, token)
        reasons.update(
            durable_schema_ddl_reasons_from_contents(filename, before, after)
        )

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


def _error(message: str) -> None:
    escaped = message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    print(f"::error title=Migration single-writer lease::{escaped}")


def _append_summary(lines: list[str]) -> None:
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not summary_path:
        return
    with Path(summary_path).open("a", encoding="utf-8") as summary:
        summary.write("\n".join(lines) + "\n")


def main() -> int:
    base_sha = os.environ.get("CI_BASE_SHA", "")
    head_sha = os.environ.get("CI_HEAD_SHA", "")
    if not base_sha or not head_sha:
        _error("Gate unavailable because base/head metadata is missing.")
        return 1

    try:
        files = changed_files(base_sha, head_sha)
        paths = paths_for_migration_classification(files)
        authority_removed = app_database_authority_removed_or_renamed(files)
        patches = {
            changed.path: changed_patch(base_sha, head_sha, changed.path)
            for changed in files
            if _production_dart_path(changed.path)
            and not changed.status.startswith("D")
        }
        app_patch = (
            patches.get(APP_DATABASE_FILE, "")
            if APP_DATABASE_FILE in paths and not authority_removed
            else ""
        )
        current_reasons = current_migration_reasons(
            files,
            app_patch,
            file_patches=patches,
        )
        lines = [
            "## Migration single-writer lease",
            "",
            f"- Current PR migration-sensitive: `{'yes' if current_reasons else 'no'}`",
            f"- Reasons: `{', '.join(sorted(current_reasons)) if current_reasons else 'none'}`",
        ]

        if not current_reasons:
            lines.extend(
                [
                    "- Ownership arbitration: `skipped` (non-migration PR)",
                    "",
                    "Non-migration PR: no lease contention and no GitHub ownership query required.",
                ]
            )
            _append_summary(lines)
            print("migration_lease_guard: non-migration PR passes without lease arbitration")
            return 0

        repository = os.environ.get("GITHUB_REPOSITORY", "")
        token = os.environ.get("GITHUB_TOKEN", "")
        current_raw = os.environ.get("CURRENT_PR_NUMBER", "")
        if not repository or not token or not current_raw:
            _error(
                "Migration-sensitive PR cannot arbitrate ownership because repository/token/PR metadata is missing."
            )
            return 1

        current_number = int(current_raw)
        api_root = f"https://api.github.com/repos/{repository}"
        claims = open_migration_claims(api_root, token)
        owner = active_migration_owner(current_number, current_reasons, claims)
        blocker = blocking_migration_owner(current_number, current_reasons, claims)
        queued = queued_migration_claims(owner, claims)

        lines.extend(
            [
                f"- Active migration owner: `#{owner.number if owner else current_number}`",
                f"- Queued migration PRs: `{', '.join('#' + str(claim.number) for claim in queued) if queued else 'none'}`",
            ]
        )

        if blocker is not None:
            reasons = ", ".join(sorted(blocker.reasons))
            message = (
                f"PR #{blocker.number} {blocker.title} is the active migration owner ({reasons}). "
                "This later migration PR is blocked until the active owner merges/closes; then rebase and rerun CI."
            )
            _error(message)
            lines.extend(["", f"❌ {message}"])
            _append_summary(lines)
            return 1

        if queued:
            _warning(
                "This PR remains the active migration owner; later migration PRs are queued and must not block this owner."
            )
        lines.extend(["", "Active migration owner confirmed; gate passes."])
        _append_summary(lines)
        print(f"migration_lease_guard: PR #{current_number} owns the migration lease")
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
        _error(f"Migration-sensitive ownership gate unavailable: {error}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
