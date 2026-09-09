#!/usr/bin/env python3

import unittest

import migration_lease_guard as guard


class MigrationLeaseGuardTest(unittest.TestCase):
    def claim(self, number: int, reason: str | None = None) -> guard.MigrationClaim:
        return guard.MigrationClaim(
            number=number,
            title=f"PR {number}",
            reasons=frozenset({reason}) if reason else frozenset(),
        )

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

    def test_non_migration_pr_has_no_owner_or_blocker(self) -> None:
        claims = [self.claim(20, guard.SCHEMA_FILE)]
        self.assertIsNone(guard.active_migration_owner(21, frozenset(), claims))
        self.assertIsNone(guard.blocking_migration_owner(21, frozenset(), claims))

    def test_single_migration_pr_owns_lease(self) -> None:
        reasons = frozenset({guard.SCHEMA_FILE})
        owner = guard.active_migration_owner(20, reasons, [])
        self.assertIsNotNone(owner)
        self.assertEqual(owner.number, 20)
        self.assertIsNone(guard.blocking_migration_owner(20, reasons, []))

    def test_earlier_current_owner_stays_green_when_later_pr_exists(self) -> None:
        reasons = frozenset({guard.SCHEMA_FILE})
        claims = [self.claim(21, guard.MIGRATIONS_FILE)]
        owner = guard.active_migration_owner(20, reasons, claims)
        self.assertEqual(owner.number, 20)
        self.assertIsNone(guard.blocking_migration_owner(20, reasons, claims))

    def test_later_current_pr_is_blocked_by_earlier_owner(self) -> None:
        reasons = frozenset({guard.MIGRATIONS_FILE})
        claims = [self.claim(20, guard.SCHEMA_FILE)]
        blocker = guard.blocking_migration_owner(21, reasons, claims)
        self.assertIsNotNone(blocker)
        self.assertEqual(blocker.number, 20)

    def test_claim_order_does_not_change_active_owner(self) -> None:
        reasons = frozenset({guard.MIGRATIONS_FILE})
        claims = [
            self.claim(24, guard.MIGRATIONS_FILE),
            self.claim(20, guard.SCHEMA_FILE),
            self.claim(22, guard.MIGRATIONS_FILE),
        ]
        forward = guard.active_migration_owner(23, reasons, claims)
        reverse = guard.active_migration_owner(23, reasons, reversed(claims))
        self.assertEqual(forward.number, 20)
        self.assertEqual(reverse.number, 20)

    def test_multiple_later_contenders_are_queued_behind_one_owner(self) -> None:
        owner = self.claim(20, guard.SCHEMA_FILE)
        claims = [
            self.claim(23, guard.MIGRATIONS_FILE),
            owner,
            self.claim(22, guard.MIGRATIONS_FILE),
            self.claim(24),
        ]
        queued = guard.queued_migration_claims(owner, claims)
        self.assertEqual([claim.number for claim in queued], [22, 23])

    def test_current_claim_is_injected_if_open_pr_listing_is_stale(self) -> None:
        reasons = frozenset({guard.SCHEMA_FILE})
        owner = guard.active_migration_owner(
            19,
            reasons,
            [self.claim(20, guard.MIGRATIONS_FILE)],
        )
        self.assertEqual(owner.number, 19)


if __name__ == "__main__":
    unittest.main()
