#!/usr/bin/env python3
"""Create and compare read-only Vault preservation manifests.

This helper supports the Lane F real-machine validation for #242/#951. It never
writes inside a Vault. It records Vault metadata, verifies SQLite with
PRAGMA quick_check, and hashes managed files under photos/ and attachments/
without following symlinks.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sqlite3
import stat
import sys
from pathlib import Path
from typing import Any, Iterable

MANIFEST_VERSION = 1
MANAGED_DIRS = ("photos", "attachments")
PROFILE_KEYS = ("formatVersion", "id", "database", "photos", "attachments")


class ManifestError(RuntimeError):
    pass


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _entry_kind(mode: int) -> str:
    if stat.S_ISREG(mode):
        return "file"
    if stat.S_ISDIR(mode):
        return "directory"
    if stat.S_ISLNK(mode):
        return "symlink"
    return "other"


def _scan_tree(root: Path, relative_root: str) -> list[dict[str, Any]]:
    start = root / relative_root
    if not start.exists() and not start.is_symlink():
        return [{"path": relative_root, "kind": "missing"}]

    entries: list[dict[str, Any]] = []

    def visit(path: Path) -> None:
        st = path.lstat()
        relative = path.relative_to(root).as_posix()
        kind = _entry_kind(st.st_mode)
        record: dict[str, Any] = {"path": relative, "kind": kind}
        if kind == "file":
            record["size"] = st.st_size
            record["sha256"] = _sha256(path)
        elif kind == "symlink":
            record["target"] = os.readlink(path)
        entries.append(record)
        if kind == "directory":
            for child in sorted(path.iterdir(), key=lambda item: item.name):
                visit(child)

    visit(start)
    return entries


def _read_profile(vault: Path) -> dict[str, Any]:
    profile_path = vault / "profile.json"
    try:
        st = profile_path.lstat()
    except FileNotFoundError as exc:
        raise ManifestError("profile.json is missing") from exc
    if not stat.S_ISREG(st.st_mode):
        raise ManifestError("profile.json must be a regular non-symlink file")
    try:
        decoded = json.loads(profile_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ManifestError("profile.json is unreadable or invalid JSON") from exc
    if not isinstance(decoded, dict):
        raise ManifestError("profile.json must contain a JSON object")
    return {key: decoded.get(key) for key in PROFILE_KEYS}


def _inspect_database(vault: Path) -> dict[str, Any]:
    database_path = vault / "database.sqlite"
    try:
        st = database_path.lstat()
    except FileNotFoundError as exc:
        raise ManifestError("database.sqlite is missing") from exc
    if not stat.S_ISREG(st.st_mode):
        raise ManifestError("database.sqlite must be a regular non-symlink file")

    uri = f"file:{database_path.resolve().as_posix()}?mode=ro"
    try:
        connection = sqlite3.connect(uri, uri=True)
        try:
            quick_check = [row[0] for row in connection.execute("PRAGMA quick_check")]
            user_version = int(connection.execute("PRAGMA user_version").fetchone()[0])
        finally:
            connection.close()
    except sqlite3.Error as exc:
        raise ManifestError("database.sqlite could not be opened read-only") from exc

    if quick_check != ["ok"]:
        raise ManifestError(f"database.sqlite quick_check failed: {quick_check!r}")

    return {
        "size": st.st_size,
        "sha256": _sha256(database_path),
        "quickCheck": "ok",
        "userVersion": user_version,
    }


def snapshot_vault(vault_path: Path) -> dict[str, Any]:
    vault = Path(os.path.abspath(os.fspath(vault_path.expanduser())))
    try:
        root_stat = vault.lstat()
    except FileNotFoundError as exc:
        raise ManifestError("Vault directory is missing") from exc
    if not stat.S_ISDIR(root_stat.st_mode):
        raise ManifestError("Vault path must be a real directory, not a symlink or file")

    managed_entries: list[dict[str, Any]] = []
    for directory in MANAGED_DIRS:
        managed_entries.extend(_scan_tree(vault, directory))

    return {
        "manifestVersion": MANIFEST_VERSION,
        "profile": _read_profile(vault),
        "database": _inspect_database(vault),
        "managedEntries": managed_entries,
    }


def _load_manifest(path: Path) -> dict[str, Any]:
    try:
        decoded = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ManifestError(f"Manifest is unreadable: {path}") from exc
    if not isinstance(decoded, dict) or decoded.get("manifestVersion") != MANIFEST_VERSION:
        raise ManifestError(f"Unsupported manifest format: {path}")
    if not isinstance(decoded.get("managedEntries"), list):
        raise ManifestError(f"Manifest managedEntries is invalid: {path}")
    return decoded


def _managed_index(manifest: dict[str, Any]) -> dict[str, dict[str, Any]]:
    index: dict[str, dict[str, Any]] = {}
    for raw in manifest["managedEntries"]:
        if not isinstance(raw, dict) or not isinstance(raw.get("path"), str):
            raise ManifestError("Manifest contains an invalid managed entry")
        index[raw["path"]] = raw
    return index


def compare_manifests(
    before: dict[str, Any],
    after: dict[str, Any],
    *,
    allow_extra: bool = False,
    allow_profile_id_change: bool = False,
) -> list[str]:
    problems: list[str] = []

    before_profile = before.get("profile") or {}
    after_profile = after.get("profile") or {}
    for key in ("formatVersion", "database", "photos", "attachments"):
        if before_profile.get(key) != after_profile.get(key):
            problems.append(
                f"profile.{key} changed: {before_profile.get(key)!r} -> {after_profile.get(key)!r}"
            )
    if not allow_profile_id_change and before_profile.get("id") != after_profile.get("id"):
        problems.append(
            f"profile.id changed: {before_profile.get('id')!r} -> {after_profile.get('id')!r}"
        )

    if after.get("database", {}).get("quickCheck") != "ok":
        problems.append("after database quick_check is not ok")

    before_entries = _managed_index(before)
    after_entries = _managed_index(after)

    for path, expected in sorted(before_entries.items()):
        actual = after_entries.get(path)
        if actual is None:
            problems.append(f"managed entry missing: {path}")
            continue
        if expected.get("kind") != actual.get("kind"):
            problems.append(
                f"managed entry kind changed: {path}: {expected.get('kind')} -> {actual.get('kind')}"
            )
            continue
        kind = expected.get("kind")
        if kind == "file":
            if expected.get("size") != actual.get("size"):
                problems.append(f"managed file size changed: {path}")
            if expected.get("sha256") != actual.get("sha256"):
                problems.append(f"managed file content changed: {path}")
        elif kind == "symlink" and expected.get("target") != actual.get("target"):
            problems.append(f"managed symlink target changed: {path}")

    if not allow_extra:
        for path in sorted(set(after_entries) - set(before_entries)):
            problems.append(f"unexpected managed entry added: {path}")

    return problems


def _ensure_output_outside_vault(vault_path: Path, output: Path) -> None:
    vault = Path(os.path.abspath(os.fspath(vault_path.expanduser()))).resolve(strict=True)
    target = Path(os.path.abspath(os.fspath(output.expanduser()))).resolve(strict=False)
    try:
        inside = os.path.commonpath((os.fspath(vault), os.fspath(target))) == os.fspath(vault)
    except ValueError:
        inside = False
    if inside:
        raise ManifestError("Manifest output must be outside the Vault being inspected")


def _write_manifest(manifest: dict[str, Any], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def _print_snapshot_summary(manifest: dict[str, Any], output: Path) -> None:
    files = sum(1 for entry in manifest["managedEntries"] if entry.get("kind") == "file")
    symlinks = sum(1 for entry in manifest["managedEntries"] if entry.get("kind") == "symlink")
    missing = [entry["path"] for entry in manifest["managedEntries"] if entry.get("kind") == "missing"]
    print(f"Wrote manifest: {output}")
    print(f"SQLite quick_check: {manifest['database']['quickCheck']}")
    print(f"Managed files hashed: {files}")
    print(f"Managed symlinks observed (not followed): {symlinks}")
    if missing:
        print(f"Managed directories missing: {', '.join(missing)}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    snapshot = subparsers.add_parser("snapshot", help="Create a read-only Vault manifest")
    snapshot.add_argument("vault", type=Path)
    snapshot.add_argument("--output", required=True, type=Path)

    compare = subparsers.add_parser("compare", help="Compare two Vault manifests")
    compare.add_argument("before", type=Path)
    compare.add_argument("after", type=Path)
    compare.add_argument(
        "--allow-extra",
        action="store_true",
        help="Do not fail when the after snapshot contains additional managed entries",
    )
    compare.add_argument(
        "--allow-profile-id-change",
        action="store_true",
        help="Allow duplicate/restore flows to use a new Vault profile id",
    )
    return parser


def main(argv: Iterable[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.command == "snapshot":
            _ensure_output_outside_vault(args.vault, args.output)
            manifest = snapshot_vault(args.vault)
            _write_manifest(manifest, args.output)
            _print_snapshot_summary(manifest, args.output)
            return 0

        before = _load_manifest(args.before)
        after = _load_manifest(args.after)
        problems = compare_manifests(
            before,
            after,
            allow_extra=args.allow_extra,
            allow_profile_id_change=args.allow_profile_id_change,
        )
        if problems:
            print("Vault preservation comparison FAILED:", file=sys.stderr)
            for problem in problems:
                print(f"- {problem}", file=sys.stderr)
            return 1
        print("Vault preservation comparison passed.")
        return 0
    except ManifestError as exc:
        print(f"Vault preservation check failed: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
