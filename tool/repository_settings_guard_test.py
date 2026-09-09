#!/usr/bin/env python3

import unittest

import repository_settings_guard as guard


def compliant_ruleset() -> dict[str, object]:
    return {
        "id": 1,
        "target": "branch",
        "enforcement": "active",
        "conditions": {
            "ref_name": {"exclude": [], "include": ["~DEFAULT_BRANCH"]},
        },
        "rules": [
            {"type": "deletion"},
            {"type": "non_fast_forward"},
            {
                "type": "pull_request",
                "parameters": {"allowed_merge_methods": ["squash"]},
            },
            {
                "type": "required_status_checks",
                "parameters": {
                    "strict_required_status_checks_policy": True,
                    "required_status_checks": [{"context": "merge-gate"}],
                },
            },
        ],
        "bypass_actors": [],
        "current_user_can_bypass": "never",
    }


class RepositorySettingsGuardTest(unittest.TestCase):
    def test_compliant_repository_and_ruleset_pass(self) -> None:
        repository = {"default_branch": "main", "delete_branch_on_merge": True}
        self.assertTrue(guard.validates_repository(repository).ok)
        self.assertTrue(guard.validates_default_branch_ruleset(compliant_ruleset()).ok)

    def test_repository_drift_is_named(self) -> None:
        result = guard.validates_repository(
            {"default_branch": "develop", "delete_branch_on_merge": False}
        )
        self.assertIn("repository default branch must remain `main`", result.errors)
        self.assertIn("repository must keep delete_branch_on_merge=true", result.errors)

    def test_required_merge_gate_must_be_strict_and_exact(self) -> None:
        ruleset = compliant_ruleset()
        status = next(
            rule
            for rule in ruleset["rules"]
            if isinstance(rule, dict) and rule.get("type") == "required_status_checks"
        )
        parameters = status["parameters"]
        parameters["strict_required_status_checks_policy"] = False
        parameters["required_status_checks"] = [
            {"context": "merge-gate"},
            {"context": "some-other-check"},
        ]
        result = guard.validates_default_branch_ruleset(ruleset)
        self.assertIn(
            "main ruleset must require strict/up-to-date status checks", result.errors
        )
        self.assertIn("main ruleset must require exactly `merge-gate`", result.errors)

    def test_squash_only_and_update_protection_are_required(self) -> None:
        ruleset = compliant_ruleset()
        ruleset["rules"] = [
            rule
            for rule in ruleset["rules"]
            if not (isinstance(rule, dict) and rule.get("type") == "non_fast_forward")
        ]
        pull = next(
            rule
            for rule in ruleset["rules"]
            if isinstance(rule, dict) and rule.get("type") == "pull_request"
        )
        pull["parameters"]["allowed_merge_methods"] = ["squash", "merge"]
        result = guard.validates_default_branch_ruleset(ruleset)
        self.assertIn("main ruleset must block non-fast-forward updates", result.errors)
        self.assertIn("main ruleset must allow squash merge only", result.errors)

    def test_deletion_and_bypass_drift_are_rejected(self) -> None:
        ruleset = compliant_ruleset()
        ruleset["rules"] = [
            rule
            for rule in ruleset["rules"]
            if not (isinstance(rule, dict) and rule.get("type") == "deletion")
        ]
        ruleset["bypass_actors"] = [{"actor_type": "RepositoryRole"}]
        ruleset["current_user_can_bypass"] = "always"
        result = guard.validates_default_branch_ruleset(ruleset)
        self.assertIn("main ruleset must block branch deletion", result.errors)
        self.assertIn("main ruleset must not define bypass actors", result.errors)
        self.assertIn(
            "current audit identity must not be able to bypass main rules", result.errors
        )

    def test_exactly_one_active_repository_branch_ruleset_is_required(self) -> None:
        identifier, errors = guard.select_default_branch_ruleset(
            [{"id": 7, "target": "branch", "enforcement": "active"}]
        )
        self.assertEqual(identifier, 7)
        self.assertEqual(errors, ())

        identifier, errors = guard.select_default_branch_ruleset([])
        self.assertIsNone(identifier)
        self.assertTrue(errors)

        identifier, errors = guard.select_default_branch_ruleset(
            [
                {"id": 7, "target": "branch", "enforcement": "active"},
                {"id": 8, "target": "branch", "enforcement": "active"},
            ]
        )
        self.assertIsNone(identifier)
        self.assertTrue(errors)


if __name__ == "__main__":
    unittest.main()
