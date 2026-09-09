#!/usr/bin/env python3

import unittest

import pr_coordination_guard as guard


class PrCoordinationGuardTest(unittest.TestCase):
    def test_parse_complete_contract(self) -> None:
        contract = guard.parse_contract(
            """
- Primary lane: G
- Related issue: #992
- Depends on: #991, #979
- Shared hotspots: `lib/views/app_shell.dart`, `lib/data/app_database.dart`
- Migration/data impact: no
"""
        )
        self.assertEqual(contract.lane, "G")
        self.assertEqual(contract.related_issue, 992)
        self.assertEqual(contract.dependencies, (991, 979))
        self.assertEqual(
            contract.declared_hotspots,
            frozenset({"lib/views/app_shell.dart", "lib/data/app_database.dart"}),
        )
        self.assertEqual(contract.migration_impact, "no")

    def test_parse_contract_accepts_plain_machine_lines(self) -> None:
        contract = guard.parse_contract(
            """
Primary lane: D
Related issue: #941
Depends on: none
Shared hotspots: none
Migration/data impact: no
"""
        )
        self.assertEqual(contract.lane, "D")
        self.assertEqual(contract.related_issue, 941)

    def test_parse_contract_accepts_oversight_lane(self) -> None:
        contract = guard.parse_contract(
            """
Primary lane: H
Related issue: #1060
Depends on: none
Shared hotspots: none
Migration/data impact: no
"""
        )
        self.assertEqual(contract.lane, "H")
        warnings = guard.collect_warnings(
            contract,
            branch="oversight/issue-1060-contract",
            paths=["docs/AI_PROGRESS_OVERSIGHT.md"],
            open_dependencies=set(),
            mutating_workflows=[],
        )
        self.assertFalse(any("Primary lane" in warning for warning in warnings))

    def test_branch_prefix_lane_mapping(self) -> None:
        self.assertEqual(guard.expected_lane_for_branch("feature/object-daily-note"), "A")
        self.assertEqual(guard.expected_lane_for_branch("feature/primitives-image"), "D")
        self.assertEqual(guard.expected_lane_for_branch("refactor/ci-health"), "G")
        self.assertEqual(guard.expected_lane_for_branch("oversight/issue-1060-audit"), "H")
        self.assertIsNone(guard.expected_lane_for_branch("docs/object-handoff"))

    def test_branch_issue_token_matching(self) -> None:
        self.assertTrue(
            guard.branch_has_issue_token("feature/primitives-image-inspector-941-v2", 941)
        )
        self.assertTrue(guard.branch_has_issue_token("refactor/issue-1007-duplicate", 1007))
        self.assertFalse(guard.branch_has_issue_token("feature/primitives-image-1941", 941))
        self.assertFalse(guard.branch_has_issue_token("feature/primitives-image", 941))

    def test_runtime_missing_issue_and_wrong_lane_warn(self) -> None:
        contract = guard.parse_contract(
            """
- Primary lane: A
- Depends on: none
- Shared hotspots: none
- Migration/data impact: no
"""
        )
        warnings = guard.collect_warnings(
            contract,
            branch="feature/primitives-image",
            paths=["lib/services/image_service.dart"],
            open_dependencies=set(),
            mutating_workflows=[],
        )
        self.assertTrue(any("branch prefix" in warning for warning in warnings))
        self.assertTrue(any("Related issue" in warning for warning in warnings))

    def test_runtime_branch_without_issue_token_warns(self) -> None:
        contract = guard.parse_contract(
            """
- Primary lane: D
- Related issue: #941
- Depends on: none
- Shared hotspots: none
- Migration/data impact: no
"""
        )
        warnings = guard.collect_warnings(
            contract,
            branch="feature/primitives-image-inspector",
            paths=["lib/services/image_service.dart"],
            open_dependencies=set(),
            mutating_workflows=[],
        )
        self.assertTrue(any("delimited token" in warning for warning in warnings))

    def test_runtime_branch_with_issue_token_does_not_warn_about_token(self) -> None:
        contract = guard.parse_contract(
            """
- Primary lane: D
- Related issue: #941
- Depends on: none
- Shared hotspots: none
- Migration/data impact: no
"""
        )
        warnings = guard.collect_warnings(
            contract,
            branch="feature/primitives-image-inspector-941-v2",
            paths=["lib/services/image_service.dart"],
            open_dependencies=set(),
            mutating_workflows=[],
        )
        self.assertFalse(any("delimited token" in warning for warning in warnings))

    def test_docs_only_may_omit_related_issue(self) -> None:
        contract = guard.parse_contract(
            """
- Primary lane: A
- Depends on: none
- Shared hotspots: none
- Migration/data impact: no
"""
        )
        warnings = guard.collect_warnings(
            contract,
            branch="docs/object-handoff",
            paths=["docs/AI_PROGRESS_OBJECT.md"],
            open_dependencies=set(),
            mutating_workflows=[],
        )
        self.assertFalse(any("Related issue" in warning for warning in warnings))
        self.assertFalse(any("delimited token" in warning for warning in warnings))

    def test_duplicate_related_issue_claim_is_found_and_self_is_excluded(self) -> None:
        pulls = [
            guard.OpenPullClaim(
                number=10,
                title="Current",
                related_issue=999,
                branch="refactor/issue-999-current",
            ),
            guard.OpenPullClaim(
                number=11,
                title="Duplicate",
                related_issue=999,
                branch="refactor/issue-999-other",
            ),
            guard.OpenPullClaim(
                number=12,
                title="Different",
                related_issue=1000,
                branch="refactor/issue-1000-other",
            ),
        ]
        duplicates = guard.duplicate_issue_claims(10, 999, pulls)
        self.assertEqual([pull.number for pull in duplicates], [11])

    def test_duplicate_related_issue_is_warned(self) -> None:
        contract = guard.parse_contract(
            """
- Primary lane: G
- Related issue: #999
- Depends on: none
- Shared hotspots: none
- Migration/data impact: no
"""
        )
        duplicate = guard.OpenPullClaim(
            number=11,
            title="Other implementation",
            related_issue=999,
            branch="refactor/issue-999-other",
        )
        warnings = guard.collect_warnings(
            contract,
            branch="refactor/issue-999-current",
            paths=["tool/example.py"],
            open_dependencies=set(),
            mutating_workflows=[],
            duplicate_claims=[duplicate],
        )
        self.assertTrue(any("open PR(s)" in warning and "#11" in warning for warning in warnings))

    def test_different_related_issue_does_not_duplicate(self) -> None:
        pulls = [
            guard.OpenPullClaim(
                number=11,
                title="Other implementation",
                related_issue=1000,
                branch="refactor/issue-1000-other",
            )
        ]
        self.assertEqual(guard.duplicate_issue_claims(10, 999, pulls), [])

    def test_open_dependency_is_warned(self) -> None:
        contract = guard.parse_contract(
            """
- Primary lane: G
- Related issue: #992
- Depends on: #991
- Shared hotspots: none
- Migration/data impact: no
"""
        )
        warnings = guard.collect_warnings(
            contract,
            branch="refactor/issue-992-pr-contract",
            paths=["tool/example.py"],
            open_dependencies={991},
            mutating_workflows=[],
        )
        self.assertTrue(any("#991" in warning for warning in warnings))

    def test_declared_hotspot_mismatch_is_warned(self) -> None:
        contract = guard.parse_contract(
            """
- Primary lane: D
- Related issue: #245
- Depends on: none
- Shared hotspots: none
- Migration/data impact: no
"""
        )
        warnings = guard.collect_warnings(
            contract,
            branch="feature/primitives-shell-245",
            paths=["lib/views/app_shell.dart"],
            open_dependencies=set(),
            mutating_workflows=[],
        )
        self.assertTrue(any("Declared shared hotspots" in warning for warning in warnings))

    def test_branch_mutating_workflow_detection(self) -> None:
        content = """
permissions:
  contents: write
jobs:
  fix:
    steps:
      - run: git push origin HEAD:feature/example
"""
        self.assertTrue(
            guard.detects_branch_mutating_workflow(
                ".github/workflows/temporary_fix.yml", content
            )
        )
        self.assertFalse(
            guard.detects_branch_mutating_workflow(
                ".github/workflows/read_only.yml",
                "permissions:\n  contents: read\nsteps:\n  - run: git status\n",
            )
        )


if __name__ == "__main__":
    unittest.main()
