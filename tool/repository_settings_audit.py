#!/usr/bin/env python3
"""Read-only audit for repository integration settings that protect main."""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

CONTRACT_PATH = Path(".github/repository-settings-contract.json")


def _request_json(url: str, token: str) -> object:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "bookmark-app-repository-settings-audit",
        },
        method="GET",
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.load(response)


def _rule(ruleset: dict[str, Any], rule_type: str) -> dict[str, Any] | None:
    rules = ruleset.get("rules")
    if not isinstance(rules, list):
        return None
    for row in rules:
        if isinstance(row, dict) and row.get("type") == rule_type:
            return row
    return None


def _targets_default_branch(ruleset: dict[str, Any], default_branch: str) -> bool:
    conditions = ruleset.get("conditions")
    if not isinstance(conditions, dict):
        return False
    ref_name = conditions.get("ref_name")
    if not isinstance(ref_name, dict):
        return False
    include = ref_name.get("include")
    if not isinstance(include, list):
        return False
    targets = {str(value) for value in include}
    return "~DEFAULT_BRANCH" in targets or f"refs/heads/{default_branch}" in targets


def _ruleset_errors(
    ruleset: dict[str, Any],
    default_branch: str,
    contract: dict[str, Any],
) -> list[str]:
    errors: list[str] = []
    expected = contract["ruleset"]

    if ruleset.get("target") != expected["target"]:
        errors.append(f"ruleset target is {ruleset.get('target')!r}, expected {expected['target']!r}")
    if ruleset.get("enforcement") != expected["enforcement"]:
        errors.append(
            f"ruleset enforcement is {ruleset.get('enforcement')!r}, expected {expected['enforcement']!r}"
        )
    if expected.get("include_default_branch") and not _targets_default_branch(
        ruleset, default_branch
    ):
        errors.append("ruleset does not target the repository default branch")

    bypass = ruleset.get("bypass_actors")
    if bypass != expected.get("bypass_actors"):
        errors.append(f"ruleset bypass_actors drifted: {bypass!r}")
    expected_user_bypass = expected.get("current_user_can_bypass")
    if expected_user_bypass is not None and ruleset.get("current_user_can_bypass") != expected_user_bypass:
        errors.append(
            "ruleset current_user_can_bypass is "
            f"{ruleset.get('current_user_can_bypass')!r}, expected {expected_user_bypass!r}"
        )

    if expected.get("require_deletion_protection") and _rule(ruleset, "deletion") is None:
        errors.append("ruleset is missing deletion protection")
    if expected.get("require_non_fast_forward_protection") and _rule(
        ruleset, "non_fast_forward"
    ) is None:
        errors.append("ruleset is missing non-fast-forward protection")

    pull_request = _rule(ruleset, "pull_request")
    if pull_request is None:
        errors.append("ruleset is missing pull-request protection")
    else:
        parameters = pull_request.get("parameters")
        parameters = parameters if isinstance(parameters, dict) else {}
        actual_methods = parameters.get("allowed_merge_methods")
        expected_methods = expected.get("allowed_merge_methods")
        if actual_methods != expected_methods:
            errors.append(
                f"protected-main merge methods are {actual_methods!r}, expected {expected_methods!r}"
            )

    status_rule = _rule(ruleset, "required_status_checks")
    if status_rule is None:
        errors.append("ruleset is missing required status checks")
    else:
        parameters = status_rule.get("parameters")
        parameters = parameters if isinstance(parameters, dict) else {}
        expected_checks = expected["required_status_checks"]
        if parameters.get("strict_required_status_checks_policy") is not expected_checks.get(
            "strict"
        ):
            errors.append("required status checks are not strict/up-to-date")
        rows = parameters.get("required_status_checks")
        rows = rows if isinstance(rows, list) else []
        actual_contexts = {
            str(row.get("context"))
            for row in rows
            if isinstance(row, dict) and row.get("context")
        }
        missing = set(expected_checks.get("contexts", [])) - actual_contexts
        if missing:
            errors.append(
                "ruleset is missing required status context(s): "
                + ", ".join(sorted(missing))
            )

    return errors


def validate_repository_settings(
    repository: dict[str, Any],
    rulesets: list[dict[str, Any]],
    contract: dict[str, Any],
) -> list[str]:
    errors: list[str] = []
    default_branch = str(repository.get("default_branch") or "")
    expected_default = str(contract["default_branch"])
    if default_branch != expected_default:
        errors.append(
            f"default_branch is {default_branch!r}, expected {expected_default!r}"
        )
    if repository.get("delete_branch_on_merge") is not contract.get(
        "delete_branch_on_merge"
    ):
        errors.append(
            "delete_branch_on_merge is "
            f"{repository.get('delete_branch_on_merge')!r}, expected {contract.get('delete_branch_on_merge')!r}"
        )

    candidates = [
        ruleset
        for ruleset in rulesets
        if ruleset.get("target") == contract["ruleset"]["target"]
        and ruleset.get("enforcement") == contract["ruleset"]["enforcement"]
        and _targets_default_branch(ruleset, expected_default)
    ]
    if not candidates:
        errors.append("no active branch ruleset targets the default branch")
        return errors

    candidate_errors = [
        _ruleset_errors(candidate, expected_default, contract) for candidate in candidates
    ]
    if any(not item for item in candidate_errors):
        return errors

    errors.append(
        "no default-branch ruleset satisfies the complete integration contract: "
        + " | ".join("; ".join(item) for item in candidate_errors)
    )
    return errors


def load_contract(path: Path = CONTRACT_PATH) -> dict[str, Any]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("repository settings contract must be a JSON object")
    return payload


def fetch_live_settings(repository: str, token: str) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    api_root = f"https://api.github.com/repos/{repository}"
    repository_payload = _request_json(api_root, token)
    ruleset_rows = _request_json(f"{api_root}/rulesets", token)
    if not isinstance(repository_payload, dict):
        raise ValueError("repository settings response was not an object")
    if not isinstance(ruleset_rows, list):
        raise ValueError("rulesets response was not a list")

    details: list[dict[str, Any]] = []
    for row in ruleset_rows:
        if not isinstance(row, dict) or not isinstance(row.get("id"), int):
            continue
        payload = _request_json(f"{api_root}/rulesets/{row['id']}", token)
        if isinstance(payload, dict):
            details.append(payload)
    return repository_payload, details


def main() -> int:
    repository = os.environ.get("GITHUB_REPOSITORY", "")
    token = os.environ.get("GITHUB_TOKEN", "")
    if not repository or not token:
        print(
            "repository_settings_audit: GITHUB_REPOSITORY/GITHUB_TOKEN are required",
            file=sys.stderr,
        )
        return 1

    try:
        contract = load_contract()
        repository_payload, rulesets = fetch_live_settings(repository, token)
        errors = validate_repository_settings(repository_payload, rulesets, contract)
    except (
        OSError,
        ValueError,
        KeyError,
        json.JSONDecodeError,
        urllib.error.URLError,
    ) as error:
        print(f"repository_settings_audit: read-only audit unavailable: {error}", file=sys.stderr)
        return 1

    if errors:
        print("repository_settings_audit: repository settings drift detected", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("repository_settings_audit: critical main integration settings match contract")
    return 0


if __name__ == "__main__":
    sys.exit(main())
