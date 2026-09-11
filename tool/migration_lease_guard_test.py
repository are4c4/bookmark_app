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
            frozenset({guard.APP_DATABASE_SCHEMA_REASON}),
        )

    def test_unrelated_app_database_patch_does_not_acquire_migration_lease(self) -> None:
        patch = """
@@ -291 +291 @@ class AppDatabase extends _$AppDatabase {
-  Future<void> updatePerson(int id, String name, String? note, {int? photoId}) async {
+  Future<void> updatePerson(int id, String name, String? note) async {
"""
        reasons = guard.migration_reasons([guard.APP_DATABASE_FILE], patch)
        self.assertEqual(reasons, frozenset())

    def test_lazy_create_table_in_production_dart_acquires_lease(self) -> None:
        path = "lib/data/object_redirect_store.dart"
        files = guard.parse_changed_files(f"A\t{path}\n")
        patch = """
@@ -0,0 +1,8 @@
+Future<void> ensureSchema() async {
+  await database.customStatement('''
+    CREATE TABLE IF NOT EXISTS object_redirects (
+      retired_object_id INTEGER PRIMARY KEY
+    )
+  ''');
+}
"""
        reasons = guard.current_migration_reasons(
            files,
            file_patches={path: patch},
        )
        self.assertEqual(
            reasons,
            frozenset(
                {
                    f"{path}:durable-ddl:create-table:object_redirects",
                }
            ),
        )

    def test_create_index_and_alter_table_acquire_lease(self) -> None:
        path = "lib/data/custom_store.dart"
        patch = """
@@ -1 +1,5 @@
+await db.customStatement(
+  'CREATE UNIQUE INDEX IF NOT EXISTS object_alias_key ON object_aliases(alias)');
+await db.customStatement(
+  'ALTER TABLE object_aliases ADD COLUMN source TEXT');
"""
        self.assertEqual(
            guard.durable_schema_ddl_reasons(path, patch),
            frozenset(
                {
                    f"{path}:durable-ddl:create-unique-index:object_alias_key",
                    f"{path}:durable-ddl:alter-table:object_aliases",
                }
            ),
        )

    def test_sql_reads_and_dml_do_not_acquire_lazy_schema_lease(self) -> None:
        path = "lib/services/database_backup_service.dart"
        patch = """
@@ -1 +1,4 @@
+await database.customSelect(
+  "SELECT name FROM sqlite_master WHERE type = 'table'").get();
+await database.customStatement('INSERT INTO items(id) VALUES (1)');
+await database.customStatement('UPDATE items SET id = 2');
"""
        self.assertEqual(guard.durable_schema_ddl_reasons(path, patch), frozenset())

    def test_test_only_and_temporary_schema_do_not_acquire_lazy_schema_lease(self) -> None:
        production_path = "lib/data/diagnostic_store.dart"
        test_path = "test/diagnostic_store_test.dart"
        temporary_patch = """
@@ -1 +1 @@
+await db.customStatement('CREATE TEMP TABLE scratch(id INTEGER)');
"""
        durable_patch = """
@@ -1 +1 @@
+await db.customStatement('CREATE TABLE durable_table(id INTEGER)');
"""
        self.assertEqual(
            guard.durable_schema_ddl_reasons(production_path, temporary_patch),
            frozenset(),
        )
        self.assertEqual(
            guard.durable_schema_ddl_reasons(test_path, durable_patch),
            frozenset(),
        )

    def test_large_patch_fallback_only_reports_new_durable_authority(self) -> None:
        path = "lib/data/custom_store.dart"
        before = """
await db.customStatement('CREATE TABLE existing_table(id INTEGER)');
"""
        after = """
await db.customStatement('CREATE TABLE existing_table(id INTEGER)');
await db.customStatement('CREATE INDEX IF NOT EXISTS new_idx ON existing_table(id)');
"""
        self.assertEqual(
            guard.durable_schema_ddl_reasons_from_contents(path, before, after),
            frozenset({f"{path}:durable-ddl:create-index:new_idx"}),
        )

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

    def test_deleted_schema_and_migration_files_acquire_lease(self) -> None:
        files = guard.parse_changed_files(
            f"D\t{guard.SCHEMA_FILE}\nD\t{guard.MIGRATIONS_FILE}\n"
        )
        reasons = guard.current_migration_reasons(files)
        self.assertEqual(
            reasons,
            frozenset({guard.SCHEMA_FILE, guard.MIGRATIONS_FILE}),
        )

    def test_deleted_app_database_authority_acquires_lease(self) -> None:
        files = guard.parse_changed_files(f"D\t{guard.APP_DATABASE_FILE}\n")
        self.assertTrue(guard.app_database_authority_removed_or_renamed(files))
        self.assertEqual(
            guard.current_migration_reasons(files),
            frozenset({guard.APP_DATABASE_SCHEMA_REASON}),
        )

    def test_unrelated_deleted_file_remains_non_migration(self) -> None:
        files = guard.parse_changed_files("D\tlib/features/search/obsolete_cache.dart\n")
        self.assertFalse(guard.app_database_authority_removed_or_renamed(files))
        self.assertEqual(guard.current_migration_reasons(files), frozenset())

    def test_rename_preserves_old_migration_path_for_classification(self) -> None:
        renamed_schema = "lib/data/schema_v2.dart"
        files = guard.parse_changed_files(
            f"R100\t{guard.SCHEMA_FILE}\t{renamed_schema}\n"
        )
        self.assertEqual(
            guard.paths_for_migration_classification(files),
            [guard.SCHEMA_FILE, renamed_schema],
        )
        self.assertEqual(
            guard.current_migration_reasons(files),
            frozenset({guard.SCHEMA_FILE}),
        )

    def test_rename_away_app_database_authority_acquires_lease(self) -> None:
        renamed_database = "lib/data/application_database.dart"
        files = guard.parse_changed_files(
            f"R100\t{guard.APP_DATABASE_FILE}\t{renamed_database}\n"
        )
        self.assertTrue(guard.app_database_authority_removed_or_renamed(files))
        self.assertEqual(
            guard.paths_for_migration_classification(files),
            [guard.APP_DATABASE_FILE, renamed_database],
        )
        self.assertEqual(
            guard.current_migration_reasons(files),
            frozenset({guard.APP_DATABASE_SCHEMA_REASON}),
        )

    def test_copy_does_not_treat_source_path_as_removed_authority(self) -> None:
        copied_database = "lib/data/app_database_copy.dart"
        files = guard.parse_changed_files(
            f"C100\t{guard.APP_DATABASE_FILE}\t{copied_database}\n"
        )
        self.assertEqual(
            guard.paths_for_migration_classification(files),
            [copied_database],
        )
        self.assertFalse(guard.app_database_authority_removed_or_renamed(files))
        self.assertEqual(guard.current_migration_reasons(files), frozenset())

    def test_malformed_name_status_row_fails_closed(self) -> None:
        with self.assertRaises(ValueError):
            guard.parse_changed_files("R100\tonly-one-path\n")

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

    def test_lazy_schema_writer_is_blocked_by_earlier_migration_owner(self) -> None:
        path = "lib/data/object_redirect_store.dart"
        reasons = guard.durable_schema_ddl_reasons(
            path,
            "+await db.customStatement('CREATE TABLE object_redirects(id INTEGER)');",
        )
        blocker = guard.blocking_migration_owner(
            21,
            reasons,
            [self.claim(20, guard.SCHEMA_FILE)],
        )
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
