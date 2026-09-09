#!/usr/bin/env python3

import unittest

import pr_coordination_guard as guard


class PrCoordinationGuardTest(unittest.TestCase):
    def contract(self, body: str) -> guard.Contract:
        return guard.parse_contract(body)

    def test_parse_complete_contract(self) -> None:
        contract = self.contract(
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
        contract = self.contract(
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

    def test_missing_lane_and_issue_are_blocking(self) -> None:
        contract = self.contract(
            """
- Depends on: none
- Shared hotspots: none
- Migration/data impact: no
"""
        )
        errors = guard.collect_errors(
            contract,
            paths=["lib/services/image_service.dart"],
            mutating_workflows=[],
        )
        self.assertTrue(any("Primary lane" in error for error in errors))
        self.assertTrue(any("Related issue" in error for error in errors))

    def test_wrong_branch_prefix_remains_advisory(self) -> None:
        contract = self.contract(
            """
- Primary lane: A
- Related issue: #941
- Depends on: none
- Shared hotspots: none
- Migration/data impact: no
"""
        )
        warnings = guard.collect_warnings(
            contract,
            branch="feature/primitives-image-941",
            paths=["lib/services/image_service.dart"],
            open_dependencies=set(),
        )
        self.assertTrue(any("branch prefix" in warning for warning in warnings))

    def test_runtime_branch_without_issue_token_warns(self) -> None:
        contract = self.contract(
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
        )
        self.assertTrue(any("delimited token" in warning for warning in warnings))

    def test_docs_only_may_omit_related_issue_but_still_needs_contract(self) -> None:
        contract = self.contract(
            """
- Primary lane: H
- Depends on: none
- Shared hotspots: none
- Migration/data impact: no
"""
        )
        errors = guard.collect_errors(
            contract,
            paths=["docs/AI_PROGRESS_OVERSIGHT.md"],
            mutating_workflows=[],
        )
        self.assertFalse(any("Related issue" in error for error in errors))
        self.assertFalse(errors)

    def test_duplicate_related_issue_claim_is_found(self) -> None:
        pulls = [
            guard.OpenPullClaim(10, "Current", 999, "refactor/issue-999-current"),
            guard.OpenPullClaim(11, "Duplicate", 999, "refactor/issue-999-other"),
            guard.OpenPullClaim(12, "Different", 1000, "refactor/issue-1000-other"),
        ]
        duplicates = guard.duplicate_issue_claims(10, 999, pulls)
        self.assertEqual([pull.number for pull in duplicates], [11])

    def test_duplicate_related_issue_is_blocking(self) -> None:
        contract = self.contract(
            """
- Primary lane: G
- Related issue: #999
- Depends on: none
- Shared hotspots: none
- Migration/data impact: no
"""
        )
        duplicate = guard.OpenPullClaim(
            11, "Other implementation", 999, "refactor/issue-999-other"
        )
        errors = guard.collect_errors(
            contract,
            paths=["tool/example.py"],
            mutating_workflows=[],
            duplicate_claims=[duplicate],
        )
        self.assertTrue(any("#11" in error for error in errors))

    def test_open_dependency_remains_advisory(self) -> None:
        contract = self.contract(
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
        )
        self.assertTrue(any("#991" in warning for warning in warnings))

    def test_declared_hotspot_mismatch_is_blocking(self) -> None:
        contract = self.contract(
            """
- Primary lane: D
- Related issue: #245
- Depends on: none
- Shared hotspots: none
- Migration/data impact: no
"""
        )
        errors = guard.collect_errors(
            contract,
            paths=["lib/views/app_shell.dart"],
            mutating_workflows=[],
        )
        self.assertTrue(any("Declared shared hotspots" in error for error in errors))

    def test_malformed_migration_impact_is_blocking(self) -> None:
        contract = self.contract(
            """
- Primary lane: G
- Related issue: #992
- Depends on: none
- Shared hotspots: none
- Migration/data impact: maybe
"""
        )
        errors = guard.collect_errors(
            contract,
            paths=["tool/example.py"],
            mutating_workflows=[],
        )
        self.assertTrue(any("Migration/data impact" in error for error in errors))

    def test_branch_mutating_workflow_is_blocking_even_for_dependency_bot(self) -> None:
        content = """
permissions:
  contents: write
jobs:
  fix:
    steps:
      - run: git push origin HEAD:feature/example
"""
        path = ".github/workflows/temporary_fix.yml"
        self.assertTrue(guard.detects_branch_mutating_workflow(path, content))
        errors = guard.collect_errors(
            guard.Contract(None, None, (), frozenset(), False, None),
            paths=[path],
            mutating_workflows=[path],
            dependency_bot=True,
        )
        self.assertEqual(len(errors), 1)
        self.assertIn("contents: write", errors[0])

    def test_dependency_bot_is_exempt_from_ai_metadata(self) -> None:
        contract = guard.Contract(None, None, (), frozenset(), False, None)
        errors = guard.collect_errors(
            contract,
            paths=[".github/workflows/flutter_ci.yml"],
            mutating_workflows=[],
            dependency_bot=True,
        )
        warnings = guard.collect_warnings(
            contract,
            branch="dependabot/github_actions/main/actions/cache-6.1.0",
            paths=[".github/workflows/flutter_ci.yml"],
            open_dependencies=set(),
            dependency_bot=True,
        )
        self.assertEqual(errors, [])
        self.assertEqual(warnings, [])
        self.assertTrue(
            guard.is_dependency_bot(
                "dependabot[bot]", "dependabot/github_actions/main/actions/cache-6.1.0"
            )
        )

    def test_schema_version_change_is_high_risk(self) -> None:
        patch = """diff --git a/lib/data/app_database.dart b/lib/data/app_database.dart
@@ -1 +1 @@
-  int get schemaVersion => 16;
+  int get schemaVersion => 17;
"""
        risks = guard.destructive_risks_for_patch("lib/data/app_database.dart", patch)
        self.assertTrue(any("schemaVersion" in risk for risk in risks))

    def test_destructive_sql_is_high_risk(self) -> None:
        patch = """@@ -1,0 +2 @@
+await customStatement('DROP TABLE bookmarks');
"""
        risks = guard.destructive_risks_for_patch(
            "lib/data/app_database_migrations.dart", patch
        )
        self.assertTrue(any("destructive SQL" in risk for risk in risks))

    def test_bundle_identifier_change_is_high_risk(self) -> None:
        patch = """@@ -1 +1 @@
-PRODUCT_BUNDLE_IDENTIFIER = old.id;
+PRODUCT_BUNDLE_IDENTIFIER = new.id;
"""
        risks = guard.destructive_risks_for_patch(
            "macos/Runner/Configs/AppInfo.xcconfig", patch
        )
        self.assertTrue(any("Bundle Identifier" in risk for risk in risks))

    def test_sensitive_storage_delete_is_high_risk(self) -> None:
        patch = """@@ -1,0 +2 @@
+await managedFile.delete();
"""
        risks = guard.destructive_risks_for_patch(
            "lib/features/storage/managed_file_gc.dart", patch
        )
        self.assertTrue(any("physical Vault" in risk for risk in risks))

    def test_unrelated_delete_call_is_not_high_risk(self) -> None:
        patch = """@@ -1,0 +2 @@
+await temporaryThing.delete();
"""
        risks = guard.destructive_risks_for_patch("lib/features/search/cache.dart", patch)
        self.assertEqual(risks, [])

    def test_owner_risk_approval_requires_exact_marker_from_owner(self) -> None:
        comments = [
            {
                "user": {"login": "someone-else"},
                "body": guard.RISK_APPROVAL_MARKER,
            },
            {
                "user": {"login": "are4c4"},
                "body": "Looks good, but no explicit marker.",
            },
        ]
        self.assertFalse(guard.owner_risk_approval(comments, "are4c4"))
        comments.append(
            {
                "user": {"login": "are4c4"},
                "body": f"Reviewed preservation and rollback. {guard.RISK_APPROVAL_MARKER}",
            }
        )
        self.assertTrue(guard.owner_risk_approval(comments, "are4c4"))

    def test_owner_risk_approval_is_case_insensitive(self) -> None:
        comments = [
            {
                "user": {"login": "Are4c4"},
                "body": "RISK APPROVAL: APPROVED",
            }
        ]
        self.assertTrue(guard.owner_risk_approval(comments, "are4c4"))


if __name__ == "__main__":
    unittest.main()
