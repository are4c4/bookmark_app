#!/usr/bin/env python3

import unittest

import migration_lease_guard as guard


class MigrationLeaseGuardTest(unittest.TestCase):
    def test_schema_file_acquires_migration_lease(self) -> None:
        reasons = guard.migration_reasons([guard.SCHEMA_FILE])
        self.assertEqual(reasons, frozenset({guard.SCHEMA_FILE}))

    def test_migrations_file_acquires_migration_lease(self) -> None:
        reasons = guard.migration_reasons([guard.MIGRATIONS_FILE])
        self.assertEqual(reasons, frozenset({guard.MIGRATIONS_FILE}))

    def test_schema_version_patch_acquires_migration_lease(self) -> None:
        patch = """
@@ -40 +40 @@ class AppDatabase extends _$AppDatabase {
-  int get schemaVersion => 16;
+  int get schemaVersion => 17;
"""
        reasons = guard.migration_reasons([guard.APP_DATABASE_FILE], patch)
        self.assertEqual(
            reasons,
            frozenset({f"{guard.APP_DATABASE_FILE}:schemaVersion"}),
        )

    def test_unrelated_app_database_patch_does_not_acquire_migration_lease(self) -> None:
        patch = """
@@ -291 +291 @@ class AppDatabase extends _$AppDatabase {
-  Future<void> updatePerson(int id, String name, String? note, {int? photoId}) async {
+  Future<void> updatePerson(int id, String name, String? note) async {
"""
        reasons = guard.migration_reasons([guard.APP_DATABASE_FILE], patch)
        self.assertEqual(reasons, frozenset())

    def test_patch_headers_do_not_count_as_schema_version_edits(self) -> None:
        patch = """
--- a/lib/data/schemaVersion.dart
+++ b/lib/data/schemaVersion.dart
@@ -1 +1 @@
-final value = 1;
+final value = 2;
"""
        self.assertFalse(guard.patch_changes_schema_version(patch))

    def test_schema_version_signature_tracks_declared_version_line(self) -> None:
        before = """
class AppDatabase {
  int get schemaVersion => 16;
  void other() {}
}
"""
        after = """
class AppDatabase {
  int get schemaVersion => 17;
  void other() {}
}
"""
        unrelated = """
class AppDatabase {
  int get schemaVersion => 16;
  void renamed() {}
}
"""
        self.assertNotEqual(
            guard.schema_version_signature(before),
            guard.schema_version_signature(after),
        )
        self.assertEqual(
            guard.schema_version_signature(before),
            guard.schema_version_signature(unrelated),
        )

    def test_competing_migration_claim_is_reported_and_self_excluded(self) -> None:
        claims = [
            guard.MigrationClaim(
                number=20,
                title="Current migration",
                reasons=frozenset({guard.SCHEMA_FILE}),
            ),
            guard.MigrationClaim(
                number=21,
                title="Other migration",
                reasons=frozenset({guard.MIGRATIONS_FILE}),
            ),
            guard.MigrationClaim(
                number=22,
                title="Ordinary AppDatabase refactor",
                reasons=frozenset(),
            ),
        ]
        competing = guard.competing_claims(
            20,
            frozenset({guard.SCHEMA_FILE}),
            claims,
        )
        self.assertEqual([claim.number for claim in competing], [21])

    def test_non_migration_current_pr_has_no_competing_claims(self) -> None:
        claims = [
            guard.MigrationClaim(
                number=21,
                title="Other migration",
                reasons=frozenset({guard.MIGRATIONS_FILE}),
            )
        ]
        self.assertEqual(guard.competing_claims(20, frozenset(), claims), [])


if __name__ == "__main__":
    unittest.main()
