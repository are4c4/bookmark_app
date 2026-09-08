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

    def test_branch_prefix_lane_mapping(self) -> None:
        self.assertEqual(guard.expected_lane_for_branch("feature/object-daily-note"), "A")
        self.assertEqual(guard.expected_lane_for_branch("feature/primitives-image"), "D")
        self.assertEqual(guard.expected_lane_for_branch("refactor/ci-health"), "G")
        self.assertIsNone(guard.expected_lane_for_branch("docs/object-handoff"))

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
            branch="refactor/pr-contract",
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
            branch="feature/primitives-shell",
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
