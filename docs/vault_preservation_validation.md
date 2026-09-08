# Vault preservation validation

This guide supports the final real-macOS preservation checks in #242 and #951.
It complements the user-visible validation matrix with a read-only manifest of the
Vault's SQLite integrity and managed file bytes.

## Safety rules

- Use a temporary/non-destructive validation Vault where practical.
- Keep the source Vault intact during Move/recovery checks.
- Quit Bookmark before taking each snapshot so the database and managed files are
  not changing while they are inspected.
- Write manifests outside the Vault. The helper rejects output paths inside the
  Vault so validation cannot accidentally become part of the data set being moved
  or backed up.
- The helper opens `database.sqlite` read-only and never writes into the Vault.
- Managed-directory symlinks are recorded but never followed.
- Manifest files may contain relative managed filenames and literal symlink target
  strings. Treat them as local diagnostic data; do not attach a raw manifest to a
  public Issue/PR. Report only the command result and any deliberately redacted
  failure summary.

## What the helper verifies

`tool/vault_preservation_manifest.py` records:

- the stable Vault v1 `profile.json` contract (`formatVersion`, Vault id,
  `database.sqlite`, `photos`, `attachments`);
- that `database.sqlite` is a real regular file and passes read-only
  `PRAGMA quick_check`;
- the database size/SHA-256 for diagnostics;
- every entry beneath `photos/` and `attachments/` without following symlinks;
- regular managed-file size and SHA-256;
- missing, changed, type-changed, removed, or unexpectedly added managed entries.

The comparison deliberately does **not** require identical SQLite bytes. Reopen,
migration, and proven path-rewrite flows may legitimately change database bytes;
SQLite `quick_check` is the storage-integrity gate while the app/UI checks below
verify semantic preservation.

## Snapshot before an operation

Quit Bookmark, then run:

```bash
python3 tool/vault_preservation_manifest.py snapshot \
  "/path/to/source-vault" \
  --output /tmp/bookmark-vault-before.json
```

A successful snapshot prints `SQLite quick_check: ok` plus the number of managed
files hashed.

## Snapshot after restart/open/switch/move

Perform the intended app operation, verify the app reopens the expected Vault,
then quit Bookmark again and run:

```bash
python3 tool/vault_preservation_manifest.py snapshot \
  "/path/to/target-vault" \
  --output /tmp/bookmark-vault-after.json

python3 tool/vault_preservation_manifest.py compare \
  /tmp/bookmark-vault-before.json \
  /tmp/bookmark-vault-after.json
```

For a pure restart/open/switch/move preservation check, the strict comparison is
preferred. It fails if managed entries disappear, change bytes/type, or appear
unexpectedly.

## Duplicate / backup-restore

Those flows intentionally create a different Vault/profile identity, so compare
with:

```bash
python3 tool/vault_preservation_manifest.py compare \
  /tmp/bookmark-vault-before.json \
  /tmp/bookmark-vault-after.json \
  --allow-profile-id-change
```

Use `--allow-extra` only when the validation flow intentionally created new
managed files between snapshots. Do not use it merely to make an unexplained
comparison failure disappear.

## Manual semantic checks still required

The manifest validates filesystem/database preservation, not Object/Relation/UI
meaning. For #951, still verify in the real app that:

1. an existing legacy Photo promoted to a canonical Image renders after restart;
2. existing Bookmark `Images` / `Cover Image` media renders after restart;
3. an existing Person profile Image renders after restart;
4. a native canonical Image with no legacy Photo remains intact;
5. after Vault Move, the same canonical/compatibility media resolves at the target;
6. switching default/custom Vaults keeps their data isolated;
7. external absolute image/file references remain external and are not copied,
   rebased, or deleted;
8. a missing/offline Vault fails closed instead of creating an empty replacement;
9. duplicate/reopen/backup-restore preserves the Photo/Image compatibility mapping
   needed by the migration path.

For #242, record the overlapping Create/Open/Switch/Move/Recovery result on that
Issue as well. A failure that points to a concrete repository defect should become
a focused owner-lane Issue before changing semantics: filesystem/Vault defects are
Lane F; Image product semantics are Lane D; Relation integrity is Lane B;
navigation is Lane C; caller-zero legacy deletion is Lane G.
