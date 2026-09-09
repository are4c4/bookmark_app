#!/usr/bin/env python3

import copy
import unittest

import repository_settings_audit as audit


CONTRACT = {
    "default_branch": "main",
    "delete_branch_on_merge": True,
    "ruleset": {
        "target": "branch",
        "enforcement": "active",
        "include_default_branch": True,
        "bypass_actors": [],
        "current_user_can_bypass": "never",
        "require_deletion_protection": True,
        "require_non_fast_forward_protection": True,
        "allowed_merge_methods": ["squash"],
        "required_status_checks": {"strict": True, "contexts": ["merge-gate"]},
    },
}

REPOSITORY = {"default_branch": "main", "delete_branch_on_merge": True}
RULESET = {
    "target": "branch",
    "enforcement": "active",
    "conditions": {"ref_name": {"exclude": [], "include": ["~DEFAULT_BRANCH"]}},
    "bypass_actors": [],
    "current_user_can_bypass": "never",
    "rules": [
        {"type": "deletion"},
        {"type": "non_fast_forward"},
        {"type": "pull_request", "parameters": {"allowed_merge_methods": ["squash"]}},
        {
            "type": "required_status_checks",
            "parameters": {
                "strict_required_status_checks_policy": True,
                "required_status_checks": [
                    {"context": "merge-gate", "integration_id": 15368}
                ],
            },
        },
    ],
}


class RepositorySettingsAuditTest(unittest.TestCase):
    def validate(self, repository=None, ruleset=None):
        return audit.validate_repository_settings(
            copy.deepcopy(repository or REPOSITORY),
            [copy.deepcopy(ruleset or RULESET)],
            copy.deepcopy(CONTRACT),
        )

    def test_current_contract_passes(self) -> None:
        self.assertEqual(self.validate(), [])

    def test_default_branch_drift_fails(self) -> None:
        repository = copy.deepcopy(REPOSITORY)
        repository["default_branch"] = "develop"
        errors = self.validate(repository=repository)
        self.assertTrue(any("default_branch" in error for error in errors))

    def test_delete_branch_on_merge_drift_fails(self) -> None:
        repository = copy.deepcopy(REPOSITORY)
        repository["delete_branch_on_merge"] = False
        errors = self.validate(repository=repository)
        self.assertTrue(any("delete_branch_on_merge" in error for error in errors))

    def test_required_merge_gate_must_be_strict(self) -> None:
        ruleset = copy.deepcopy(RULESET)
        status = next(
            rule for rule in ruleset["rules"] if rule["type"] == "required_status_checks"
        )
        status["parameters"]["strict_required_status_checks_policy"] = False
        errors = self.validate(ruleset=ruleset)
        self.assertTrue(any("not strict" in error for error in errors))

    def test_required_merge_gate_context_must_exist(self) -> None:
        ruleset = copy.deepcopy(RULESET)
        status = next(
            rule for rule in ruleset["rules"] if rule["type"] == "required_status_checks"
        )
        status["parameters"]["required_status_checks"] = [{"context": "quality"}]
        errors = self.validate(ruleset=ruleset)
        self.assertTrue(any("merge-gate" in error for error in errors))

    def test_protected_main_is_squash_only(self) -> None:
        ruleset = copy.deepcopy(RULESET)
        pull = next(rule for rule in ruleset["rules"] if rule["type"] == "pull_request")
        pull["parameters"]["allowed_merge_methods"] = ["squash", "merge"]
        errors = self.validate(ruleset=ruleset)
        self.assertTrue(any("merge methods" in error for error in errors))

    def test_bypass_actor_drift_fails(self) -> None:
        ruleset = copy.deepcopy(RULESET)
        ruleset["bypass_actors"] = [{"actor_id": 1, "actor_type": "RepositoryRole"}]
        errors = self.validate(ruleset=ruleset)
        self.assertTrue(any("bypass_actors" in error for error in errors))

    def test_deletion_and_force_push_protection_are_required(self) -> None:
        ruleset = copy.deepcopy(RULESET)
        ruleset["rules"] = [
            rule
            for rule in ruleset["rules"]
            if rule["type"] not in {"deletion", "non_fast_forward"}
        ]
        errors = self.validate(ruleset=ruleset)
        self.assertTrue(any("deletion protection" in error for error in errors))
        self.assertTrue(any("non-fast-forward" in error for error in errors))

    def test_semantically_complete_ruleset_can_coexist_with_other_ruleset(self) -> None:
        incomplete = copy.deepcopy(RULESET)
        incomplete["rules"] = []
        errors = audit.validate_repository_settings(
            copy.deepcopy(REPOSITORY),
            [incomplete, copy.deepcopy(RULESET)],
            copy.deepcopy(CONTRACT),
        )
        self.assertEqual(errors, [])


if __name__ == "__main__":
    unittest.main()
