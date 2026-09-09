#!/usr/bin/env python3
"""Read-only audit for repository integration settings that protect main."""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class AuditResult:
    errors: tuple[str, ...]

    @property
    def ok(self) -> bool:
        return not self.errors


def _rule_by_type(ruleset: dict[str, object], rule_type: str) -> dict[str, object] | None:
    rules = ruleset.get("rules")
    if not isinstance(rules, list):
        return None
    matches = [
        row
        for row in rules
        if isinstance(row, dict) and row.get("type") == rule_type
    ]
    return matches[0] if len(matches) == 1 else None


def validates_default_branch_ruleset(ruleset: dict[str, object]) -> AuditResult:
    errors: list[str] = []

    if ruleset.get("target") != "branch":
        errors.append("main ruleset must target branches")
    if ruleset.get("enforcement") != "active":
        errors.append("main ruleset must be active")

    conditions = ruleset.get("conditions")
    ref_name = conditions.get("ref_name") if isinstance(conditions, dict) else None
    includes = ref_name.get("include") if isinstance(ref_name, dict) else None
    excludes = ref_name.get("exclude") if isinstance(ref_name, dict) else None
    if includes != ["~DEFAULT_BRANCH"] or excludes not in ([], None):
        errors.append("main ruleset must target only the default branch")

    if _rule_by_type(ruleset, "deletion") is None:
        errors.append("main ruleset must block branch deletion")
    if _rule_by_type(ruleset, "non_fast_forward") is None:
        errors.append("main ruleset must block non-fast-forward updates")

    pull_request = _rule_by_type(ruleset, "pull_request")
    pull_parameters = (
        pull_request.get("parameters") if isinstance(pull_request, dict) else None
    )
    allowed_methods = (
        pull_parameters.get("allowed_merge_methods")
        if isinstance(pull_parameters, dict)
        else None
    )
    if allowed_methods != ["squash"]:
        errors.append("main ruleset must allow squash merge only")

    status_rule = _rule_by_type(ruleset, "required_status_checks")
    status_parameters = (
        status_rule.get("parameters") if isinstance(status_rule, dict) else None
    )
    if not isinstance(status_parameters, dict):
        errors.append("main ruleset must require status checks")
    else:
        if status_parameters.get("strict_required_status_checks_policy") is not True:
            errors.append("main ruleset must require strict/up-to-date status checks")
        checks = status_parameters.get("required_status_checks")
        contexts = []
        if isinstance(checks, list):
            contexts = [
                row.get("context")
                for row in checks
                if isinstance(row, dict)
            ]
        if contexts != ["merge-gate"]:
            errors.append("main ruleset must require exactly `merge-gate`")

    # GitHub omits these administration-backed fields from ordinary Actions/public
    # payloads. Enforce them whenever the caller can observe them, but omission is
    # not itself drift; treating it as drift would permanently false-fail CI.
    if "bypass_actors" in ruleset and ruleset.get("bypass_actors") != []:
        errors.append("main ruleset must not define bypass actors")
    if (
        "current_user_can_bypass" in ruleset
        and ruleset.get("current_user_can_bypass") not in ("never", False)
    ):
        errors.append("current audit identity must not be able to bypass main rules")

    return AuditResult(tuple(errors))


def validates_repository(repository: dict[str, object]) -> AuditResult:
    errors: list[str] = []
    if repository.get("default_branch") != "main":
        errors.append("repository default branch must remain `main`")
    if (
        "delete_branch_on_merge" in repository
        and repository.get("delete_branch_on_merge") is not True
    ):
        errors.append("repository must keep delete_branch_on_merge=true")
    return AuditResult(tuple(errors))


def select_default_branch_ruleset(
    summaries: object,
) -> tuple[int | None, tuple[str, ...]]:
    if not isinstance(summaries, list):
        return None, ("rulesets API response was not a list",)
    active = [
        row
        for row in summaries
        if isinstance(row, dict)
        and row.get("target") == "branch"
        and row.get("enforcement") == "active"
    ]
    if len(active) != 1:
        return None, (
            f"expected exactly one active repository branch ruleset, found {len(active)}",
        )
    identifier = active[0].get("id")
    if not isinstance(identifier, int):
        return None, ("active branch ruleset is missing an integer id",)
    return identifier, ()


def _request_json(url: str) -> object:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "bookmark-app-repository-settings-guard",
        },
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.load(response)


def _error(message: str) -> None:
    escaped = message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    print(f"::error title=Repository settings drift::{escaped}")


def _append_summary(errors: list[str]) -> None:
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not path:
        return
    lines = ["## Repository settings audit", ""]
    if errors:
        lines.append("Drift detected:")
        lines.extend(f"- {error}" for error in errors)
    else:
        lines.append("All observable protected-main integration settings match the contract.")
        lines.append(
            "Administration-only fields are also validated when GitHub includes them in the API payload."
        )
    with Path(path).open("a", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")


def main() -> int:
    repository_name = os.environ.get("GITHUB_REPOSITORY", "")
    if not repository_name:
        _error("audit requires GITHUB_REPOSITORY")
        return 1

    api_root = f"https://api.github.com/repos/{repository_name}"
    errors: list[str] = []
    try:
        repository = _request_json(api_root)
        if not isinstance(repository, dict):
            raise ValueError("repository API response was not an object")
        errors.extend(validates_repository(repository).errors)

        summaries = _request_json(f"{api_root}/rulesets")
        ruleset_id, selection_errors = select_default_branch_ruleset(summaries)
        errors.extend(selection_errors)
        if ruleset_id is not None:
            ruleset = _request_json(f"{api_root}/rulesets/{ruleset_id}")
            if not isinstance(ruleset, dict):
                raise ValueError("ruleset API response was not an object")
            errors.extend(validates_default_branch_ruleset(ruleset).errors)
    except (
        OSError,
        ValueError,
        json.JSONDecodeError,
        urllib.error.URLError,
    ) as error:
        errors.append(f"read-only GitHub settings audit unavailable: {error}")

    for error in errors:
        _error(error)
    _append_summary(errors)
    if errors:
        return 1
    print("repository_settings_guard: observable protected-main settings match contract")
    return 0


if __name__ == "__main__":
    sys.exit(main())
