#!/usr/bin/env python3

import base64
import unittest
from unittest import mock

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

    def test_open_pull_claims_finds_duplicate_on_second_page(self) -> None:
        first_page = [
            {
                "number": number,
                "title": f"PR {number}",
                "body": "- Related issue: #1000",
                "head": {"ref": f"feature/object-{number}"},
            }
            for number in range(1, 101)
        ]
        second_page = [
            {
                "number": 101,
                "title": "Page two duplicate",
                "body": "- Related issue: #999",
                "head": {"ref": "refactor/issue-999-duplicate"},
            }
        ]
        with mock.patch.object(
            guard,
            "_request_json",
            side_effect=[first_page, second_page],
        ) as request:
            pulls = guard._open_pull_claims(
                "https://api.github.com/repos/owner/repo",
                "token",
            )

        duplicates = guard.duplicate_issue_claims(200, 999, pulls)
        self.assertEqual([pull.number for pull in duplicates], [101])
        self.assertEqual(
            request.call_args_list,
            [
                mock.call(
                    "https://api.github.com/repos/owner/repo/pulls?state=open&per_page=100&page=1",
                    "token",
                ),
                mock.call(
                    "https://api.github.com/repos/owner/repo/pulls?state=open&per_page=100&page=2",
                    "token",
                ),
            ],
        )

    def test_open_pull_claims_multiple_pages_without_duplicate_passes(self) -> None:
        first_page = [
            {
                "number": number,
                "title": f"PR {number}",
                "body": "- Related issue: #1000",
                "head": {"ref": f"feature/object-{number}"},
            }
            for number in range(1, 101)
        ]
        second_page = [
            {
                "number": 101,
                "title": "Different issue",
                "body": "- Related issue: #1001",
                "head": {"ref": "feature/object-1001"},
            }
        ]
        with mock.patch.object(
            guard,
            "_request_json",
            side_effect=[first_page, second_page],
        ):
            pulls = guard._open_pull_claims(
                "https://api.github.com/repos/owner/repo",
                "token",
            )

        self.assertEqual(guard.duplicate_issue_claims(200, 999, pulls), [])

    def test_open_pull_claims_malformed_later_page_fails_closed(self) -> None:
        first_page = [
            {
                "number": number,
                "title": f"PR {number}",
                "body": "- Related issue: #1000",
                "head": {"ref": f"feature/object-{number}"},
            }
            for number in range(1, 101)
        ]
        with mock.patch.object(
            guard,
            "_request_json",
            side_effect=[first_page, {"message": "unexpected"}],
        ):
            with self.assertRaises(ValueError):
                guard._open_pull_claims(
                    "https://api.github.com/repos/owner/repo",
                    "token",
                )

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

    def test_non_self_current_head_approved_review_is_candidate(self) -> None:
        reviews = [
            {
                "id": 1,
                "state": "APPROVED",
                "commit_id": "head-sha",
                "submitted_at": "2026-09-09T00:00:00Z",
                "user": {"login": "reviewer", "type": "User"},
            }
        ]
        self.assertEqual(
            guard.current_distinct_approved_reviewers(reviews, "author", "head-sha"),
            ("reviewer",),
        )

    def test_self_stale_and_non_user_reviews_do_not_count(self) -> None:
        reviews = [
            {
                "id": 1,
                "state": "APPROVED",
                "commit_id": "head-sha",
                "submitted_at": "2026-09-09T00:00:00Z",
                "user": {"login": "author", "type": "User"},
            },
            {
                "id": 2,
                "state": "APPROVED",
                "commit_id": "old-sha",
                "submitted_at": "2026-09-09T00:00:01Z",
                "user": {"login": "stale-reviewer", "type": "User"},
            },
            {
                "id": 3,
                "state": "APPROVED",
                "commit_id": "head-sha",
                "submitted_at": "2026-09-09T00:00:02Z",
                "user": {"login": "review-bot[bot]", "type": "Bot"},
            },
        ]
        self.assertEqual(
            guard.current_distinct_approved_reviewers(reviews, "author", "head-sha"),
            (),
        )

    def test_latest_review_state_wins_for_reviewer(self) -> None:
        reviews = [
            {
                "id": 1,
                "state": "APPROVED",
                "commit_id": "head-sha",
                "submitted_at": "2026-09-09T00:00:00Z",
                "user": {"login": "reviewer", "type": "User"},
            },
            {
                "id": 2,
                "state": "CHANGES_REQUESTED",
                "commit_id": "head-sha",
                "submitted_at": "2026-09-09T00:01:00Z",
                "user": {"login": "reviewer", "type": "User"},
            },
        ]
        self.assertEqual(
            guard.current_distinct_approved_reviewers(reviews, "author", "head-sha"),
            (),
        )

    def test_paginated_review_history_later_page_overrides_approval(self) -> None:
        approval = {
            "id": 1,
            "state": "APPROVED",
            "commit_id": "head-sha",
            "submitted_at": "2026-09-09T00:00:00Z",
            "user": {"login": "reviewer", "type": "User"},
        }
        first_page = [approval, *({"id": index} for index in range(2, 101))]
        later_change_request = {
            "id": 101,
            "state": "CHANGES_REQUESTED",
            "commit_id": "head-sha",
            "submitted_at": "2026-09-09T01:00:00Z",
            "user": {"login": "reviewer", "type": "User"},
        }
        with mock.patch.object(
            guard,
            "_request_json",
            side_effect=[first_page, [later_change_request]],
        ) as request:
            reviews = guard._request_paginated_list(
                "https://api.github.com/repos/owner/repo/pulls/42/reviews",
                "token",
            )

        self.assertEqual(len(reviews), 101)
        self.assertEqual(
            guard.current_distinct_approved_reviewers(reviews, "author", "head-sha"),
            (),
        )
        self.assertEqual(
            request.call_args_list,
            [
                mock.call(
                    "https://api.github.com/repos/owner/repo/pulls/42/reviews?per_page=100&page=1",
                    "token",
                ),
                mock.call(
                    "https://api.github.com/repos/owner/repo/pulls/42/reviews?per_page=100&page=2",
                    "token",
                ),
            ],
        )

    def test_paginated_review_history_rejects_non_list_page(self) -> None:
        with mock.patch.object(
            guard,
            "_request_json",
            return_value={"message": "unexpected"},
        ):
            with self.assertRaises(ValueError):
                guard._request_paginated_list(
                    "https://api.github.com/repos/owner/repo/pulls/42/reviews",
                    "token",
                )

    def test_destructive_approver_requires_write_or_admin(self) -> None:
        reviews = [
            {
                "id": 1,
                "state": "APPROVED",
                "commit_id": "head-sha",
                "submitted_at": "2026-09-09T00:00:00Z",
                "user": {"login": "reader", "type": "User"},
            },
            {
                "id": 2,
                "state": "APPROVED",
                "commit_id": "head-sha",
                "submitted_at": "2026-09-09T00:00:01Z",
                "user": {"login": "writer", "type": "User"},
            },
        ]
        approver = guard.eligible_destructive_approver(
            reviews,
            "author",
            "head-sha",
            {
                "reader": {"permission": "read"},
                "writer": {"permission": "write"},
            },
        )
        self.assertEqual(approver, "writer")
        self.assertFalse(
            guard.permission_allows_destructive_approval({"permission": "read"})
        )
        self.assertTrue(
            guard.permission_allows_destructive_approval({"permission": "admin"})
        )

    def test_policy_self_protection_bootstrap_then_blocks_guard_changes(self) -> None:
        patch = """@@ -1 +1 @@
-old = 1
+new = 2
"""
        self.assertEqual(
            guard.approval_policy_risks_for_patch(
                guard.APPROVAL_GUARD_PATH,
                patch,
                policy_active=False,
            ),
            [],
        )
        risks = guard.approval_policy_risks_for_patch(
            guard.APPROVAL_GUARD_PATH,
            patch,
            policy_active=True,
        )
        self.assertTrue(any("guard policy" in risk for risk in risks))

    def test_required_gate_wiring_changes_are_policy_risk_after_bootstrap(self) -> None:
        patch = """@@ -1 +1 @@
-    name: merge-gate
+    name: anything-else
"""
        risks = guard.approval_policy_risks_for_patch(
            ".github/workflows/flutter_ci.yml",
            patch,
            policy_active=True,
        )
        self.assertTrue(any("workflow wiring" in risk for risk in risks))
        self.assertEqual(
            guard.approval_policy_risks_for_patch(
                ".github/workflows/flutter_ci.yml",
                "@@ -1 +1 @@\n-uses: actions/cache@old\n+uses: actions/cache@new\n",
                policy_active=True,
            ),
            [],
        )

    def test_current_base_policy_contents_detect_v2_sentinel(self) -> None:
        active = base64.b64encode(
            f"# {guard.APPROVAL_POLICY_SENTINEL}\n".encode("utf-8")
        ).decode("ascii")
        inactive = base64.b64encode(b"# old policy\n").decode("ascii")

        self.assertTrue(
            guard.approval_policy_active_from_contents(
                {"encoding": "base64", "content": active}
            )
        )
        self.assertFalse(
            guard.approval_policy_active_from_contents(
                {"encoding": "base64", "content": inactive}
            )
        )
        with self.assertRaises(ValueError):
            guard.approval_policy_active_from_contents(
                {"encoding": "utf-8", "content": "plain text"}
            )

    def test_current_base_policy_lookup_uses_live_base_ref(self) -> None:
        encoded = base64.b64encode(
            f"# {guard.APPROVAL_POLICY_SENTINEL}\n".encode("utf-8")
        ).decode("ascii")
        with mock.patch.object(
            guard,
            "_request_json",
            return_value={"encoding": "base64", "content": encoded},
        ) as request:
            self.assertTrue(
                guard._current_base_approval_policy_active(
                    "https://api.github.com/repos/owner/repo",
                    "token",
                    "main",
                )
            )

        request.assert_called_once_with(
            "https://api.github.com/repos/owner/repo/contents/tool/pr_coordination_guard.py?ref=main",
            "token",
        )

    def test_current_base_policy_override_blocks_stale_base_bootstrap(self) -> None:
        patch = """@@ -1 +1 @@
-old = 1
+new = 2
"""
        with mock.patch.object(
            guard, "approval_policy_active", return_value=False
        ) as stale_base, mock.patch.object(
            guard, "patch_for_path", return_value=patch
        ):
            risks = guard.destructive_risks(
                "stale-pre-v2-base",
                "head",
                [guard.APPROVAL_GUARD_PATH],
                policy_active=True,
            )

        stale_base.assert_not_called()
        self.assertTrue(any("guard policy" in risk for risk in risks))

    def test_runtime_paths_do_not_need_live_policy_lookup(self) -> None:
        self.assertFalse(
            guard.approval_policy_sensitive_paths(["lib/features/search/search.dart"])
        )
        self.assertTrue(
            guard.approval_policy_sensitive_paths([guard.APPROVAL_GUARD_PATH])
        )
        self.assertTrue(
            guard.approval_policy_sensitive_paths([".github/workflows/flutter_ci.yml"])
        )


if __name__ == "__main__":
    unittest.main()