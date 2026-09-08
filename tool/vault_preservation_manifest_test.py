#!/usr/bin/env python3

import json
import sqlite3
import tempfile
import unittest
from pathlib import Path

import vault_preservation_manifest as manifest


def make_vault(root: Path, *, profile_id: str = "vault-1") -> Path:
    vault = root / "Vault"
    (vault / "photos").mkdir(parents=True)
    (vault / "attachments").mkdir()
    (vault / "profile.json").write_text(
        json.dumps(
            {
                "formatVersion": 1,
                "id": profile_id,
                "name": "Validation Vault",
                "database": "database.sqlite",
                "photos": "photos",
                "attachments": "attachments",
            }
        ),
        encoding="utf-8",
    )
    connection = sqlite3.connect(vault / "database.sqlite")
    connection.execute("CREATE TABLE example (id INTEGER PRIMARY KEY, value TEXT)")
    connection.execute("CREATE TABLE photos (id INTEGER PRIMARY KEY, path TEXT NOT NULL)")
    connection.execute(
        "CREATE TABLE bookmark_attachments (id INTEGER PRIMARY KEY, path TEXT NOT NULL)"
    )
    connection.execute("INSERT INTO example(value) VALUES ('preserved')")
    connection.execute("INSERT INTO photos(id, path) VALUES (1, 'photos/image.bin')")
    connection.execute(
        "INSERT INTO bookmark_attachments(id, path) "
        "VALUES (1, 'attachments/file.bin')"
    )
    connection.commit()
    connection.close()
    (vault / "photos" / "image.bin").write_bytes(b"image-bytes")
    (vault / "attachments" / "file.bin").write_bytes(b"attachment-bytes")
    return vault


def update_path(vault: Path, table: str, row_id: int, path: str) -> None:
    connection = sqlite3.connect(vault / "database.sqlite")
    connection.execute(f"UPDATE {table} SET path = ? WHERE id = ?", (path, row_id))
    connection.commit()
    connection.close()


class VaultPreservationManifestTest(unittest.TestCase):
    def test_snapshot_hashes_managed_files_and_checks_sqlite(self):
        with tempfile.TemporaryDirectory() as directory:
            vault = make_vault(Path(directory))
            snapshot = manifest.snapshot_vault(vault)
            self.assertEqual(snapshot["database"]["quickCheck"], "ok")
            files = {
                entry["path"]: entry
                for entry in snapshot["managedEntries"]
                if entry["kind"] == "file"
            }
            self.assertEqual(files["photos/image.bin"]["size"], len(b"image-bytes"))
            self.assertEqual(
                files["attachments/file.bin"]["size"], len(b"attachment-bytes")
            )
            self.assertEqual(len(files["photos/image.bin"]["sha256"]), 64)

    def test_snapshot_records_database_storage_path_references(self):
        with tempfile.TemporaryDirectory() as directory:
            vault = make_vault(Path(directory))
            snapshot = manifest.snapshot_vault(vault)
            references = {
                (entry["table"], entry["id"]): entry
                for entry in snapshot["pathReferences"]
            }
            self.assertEqual(
                references[("photos", 1)]["canonicalIdentity"],
                "photos/image.bin",
            )
            self.assertEqual(references[("photos", 1)]["scope"], "vault")
            self.assertEqual(
                references[("bookmark_attachments", 1)]["canonicalIdentity"],
                "attachments/file.bin",
            )

    def test_snapshot_rejects_invalid_vault_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            vault = make_vault(Path(directory))
            metadata = json.loads((vault / "profile.json").read_text(encoding="utf-8"))
            metadata["database"] = "elsewhere.sqlite"
            (vault / "profile.json").write_text(json.dumps(metadata), encoding="utf-8")
            with self.assertRaisesRegex(manifest.ManifestError, "Vault v1 metadata"):
                manifest.snapshot_vault(vault)

    def test_snapshot_rejects_traversing_database_path_reference(self):
        with tempfile.TemporaryDirectory() as directory:
            vault = make_vault(Path(directory))
            update_path(vault, "photos", 1, "../outside.png")
            with self.assertRaisesRegex(manifest.ManifestError, "escapes the Vault"):
                manifest.snapshot_vault(vault)

    def test_compare_accepts_unchanged_managed_content(self):
        with tempfile.TemporaryDirectory() as directory:
            vault = make_vault(Path(directory))
            before = manifest.snapshot_vault(vault)
            after = manifest.snapshot_vault(vault)
            self.assertEqual(manifest.compare_manifests(before, after), [])

    def test_compare_accepts_managed_absolute_to_relative_rebase_after_move(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            before_vault = make_vault(root / "before")
            after_vault = make_vault(root / "after")
            update_path(
                before_vault,
                "photos",
                1,
                str(before_vault / "photos" / "image.bin"),
            )
            before = manifest.snapshot_vault(before_vault)
            after = manifest.snapshot_vault(after_vault)
            self.assertEqual(manifest.compare_manifests(before, after), [])

    def test_compare_reports_external_path_text_rewrite(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            external = root / "external.bin"
            external.write_bytes(b"external")
            before_vault = make_vault(root / "before")
            after_vault = make_vault(root / "after")
            update_path(before_vault, "photos", 1, str(external))
            update_path(
                after_vault,
                "photos",
                1,
                f"{external.parent}//{external.name}",
            )
            before = manifest.snapshot_vault(before_vault)
            after = manifest.snapshot_vault(after_vault)
            problems = manifest.compare_manifests(before, after)
            self.assertTrue(
                any(
                    "external database path reference text changed: photos#1" in item
                    for item in problems
                )
            )

    def test_compare_reports_missing_database_path_reference(self):
        with tempfile.TemporaryDirectory() as directory:
            vault = make_vault(Path(directory))
            before = manifest.snapshot_vault(vault)
            connection = sqlite3.connect(vault / "database.sqlite")
            connection.execute("DELETE FROM bookmark_attachments WHERE id = 1")
            connection.commit()
            connection.close()
            after = manifest.snapshot_vault(vault)
            problems = manifest.compare_manifests(before, after)
            self.assertTrue(
                any(
                    "database path reference missing: bookmark_attachments#1" in item
                    for item in problems
                )
            )

    def test_compare_reports_missing_and_changed_files(self):
        with tempfile.TemporaryDirectory() as directory:
            vault = make_vault(Path(directory))
            before = manifest.snapshot_vault(vault)
            (vault / "photos" / "image.bin").write_bytes(b"changed")
            (vault / "attachments" / "file.bin").unlink()
            after = manifest.snapshot_vault(vault)
            problems = manifest.compare_manifests(before, after)
            self.assertTrue(
                any("content changed: photos/image.bin" in item for item in problems)
            )
            self.assertTrue(
                any("missing: attachments/file.bin" in item for item in problems)
            )

    def test_compare_can_allow_new_profile_id_for_duplicate_or_restore(self):
        with tempfile.TemporaryDirectory() as directory:
            before_vault = make_vault(Path(directory) / "before", profile_id="source")
            after_vault = make_vault(Path(directory) / "after", profile_id="copy")
            before = manifest.snapshot_vault(before_vault)
            after = manifest.snapshot_vault(after_vault)
            self.assertTrue(
                any(
                    "profile.id changed" in item
                    for item in manifest.compare_manifests(before, after)
                )
            )
            self.assertEqual(
                manifest.compare_manifests(
                    before, after, allow_profile_id_change=True
                ),
                [],
            )

    def test_symlinks_are_recorded_without_following(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            vault = make_vault(root)
            external = root / "external.bin"
            external.write_bytes(b"outside")
            (vault / "photos" / "external-link").symlink_to(external)
            snapshot = manifest.snapshot_vault(vault)
            link = next(
                entry
                for entry in snapshot["managedEntries"]
                if entry["path"] == "photos/external-link"
            )
            self.assertEqual(link["kind"], "symlink")
            self.assertEqual(link["target"], str(external))

    def test_snapshot_rejects_symlink_database(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            vault = make_vault(root)
            real_database = root / "external.sqlite"
            (vault / "database.sqlite").replace(real_database)
            (vault / "database.sqlite").symlink_to(real_database)
            with self.assertRaisesRegex(manifest.ManifestError, "regular non-symlink"):
                manifest.snapshot_vault(vault)

    def test_snapshot_rejects_symlink_vault_root(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            vault = make_vault(root / "real")
            alias = root / "vault-link"
            alias.symlink_to(vault, target_is_directory=True)
            with self.assertRaisesRegex(manifest.ManifestError, "real directory"):
                manifest.snapshot_vault(alias)

    def test_manifest_output_must_be_outside_vault(self):
        with tempfile.TemporaryDirectory() as directory:
            vault = make_vault(Path(directory))
            with self.assertRaisesRegex(manifest.ManifestError, "outside the Vault"):
                manifest._ensure_output_outside_vault(vault, vault / "manifest.json")

    def test_manifest_output_rejects_symlinked_parent_into_vault(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            vault = make_vault(root / "data")
            alias = root / "output-link"
            alias.symlink_to(vault, target_is_directory=True)
            with self.assertRaisesRegex(manifest.ManifestError, "outside the Vault"):
                manifest._ensure_output_outside_vault(vault, alias / "manifest.json")


if __name__ == "__main__":
    unittest.main()
