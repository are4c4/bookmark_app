# AI Progress — Storage, Vault & Delivery Lane

> Lane F handoff. Read `AGENTS.md`, the active Issue, `docs/AI_PROGRESS.md`, and live GitHub PR/CI state before implementation. Recheck Primitive/Refactor ownership before changing shared storage/bootstrap hotspots.

## Lane goal
Own physical data-location lifecycle, Vault portability/recovery, filesystem-level managed-storage contracts shared by primitives, and app delivery plumbing without taking over Object/Relation product semantics.

## Current status — 2026-09-08
Lane F repository implementation work is complete for the currently known scope. The active F-owned completion gate is **#951**, coordinated with the final real-macOS lifecycle validation in **#242**.

Latest durable checkpoint is `main` **`78f5b989320008f214cbe526d0fbaaec34156cc0`**:
- **#949 completed**: canonical `画像` is the single normal user-facing image collection; legacy `写真` AppShell navigation is retired.
- **#941 completed**: canonical Image preview/edit parity exists in the shared Object Inspector.
- **#950 remains G-owned**, but the F prerequisite is released: caller-zero `PhotoManagementPage` is removed and later compatibility cleanup must preserve migration/Vault/backup semantics.
- **#1021 / PR #1025 remain D-owned**: safe deletion of exact legacy-Photo-mirrored canonical Images. Lane F audited the current PR boundary and found no physical-delete authority bypass; it continues to reuse `ImageManagedFileDeletionPolicy` and `PhotoStorageService` fail-closed ownership checks.
- **#242 production implementation is complete**; only real-macOS Create/Open/Switch/Move/Recovery validation remains.
- **#897 and #218 remain completed**: legacy Photo physical deletion is Vault-safe, and release packaging/basic real-Mac launch + existing-data preservation were already validated.

No independent production Storage/Vault defect is currently known. Do not invent new Storage abstractions merely to keep Lane F active.

## Integrated validation tooling
### #1026 — read-only Vault preservation manifest
PR #1026 merged as **`dc9a330896bb79b146b692b47b7fd38464311995`** after Flutter CI #3004 full green (Analyze, 4/4 Flutter Test shards, test-health, merge-gate; both AI audits green).

Integrated:
- `tool/vault_preservation_manifest.py`
- `tool/vault_preservation_manifest_test.py`
- `docs/vault_preservation_validation.md`
- one diagnostic-test invocation in existing Flutter CI quality checks

The helper is read-only with respect to the inspected Vault and:
- validates Vault v1 `profile.json`;
- requires real non-symlink Vault root plus regular non-symlink `profile.json` / `database.sqlite`;
- opens SQLite with `mode=ro` and requires `PRAGMA quick_check == ok`;
- inventories `photos/` and `attachments/` with `lstat` without following symlinks;
- hashes regular managed files with SHA-256 + size;
- detects missing/changed/type-changed/unexpected managed entries;
- rejects manifest output inside the inspected Vault, including symlink-parent redirection;
- supports explicit `--allow-profile-id-change` for Duplicate/backup-restore and explicit `--allow-extra` only for intentionally added data.

Raw manifests are local diagnostics and may contain filenames/path strings; do not attach them publicly without deliberate redaction.

### #1029 — persisted Photo/attachment path preservation
PR #1029 merged as **`78f5b989320008f214cbe526d0fbaaec34156cc0`** after Flutter CI #3020 full green (Analyze, expanded Python diagnostic suite, 4/4 Flutter Test shards, test-health, merge-gate; both AI audits green).

The same helper now also reads `photos.path` and `bookmark_attachments.path` from SQLite read-only and verifies the #242 Move contract:
- classify each path as Vault-owned vs external absolute;
- normalize Vault-owned paths to one canonical Vault-relative identity;
- allow the expected legacy source-Vault absolute -> equivalent portable relative representation after Move;
- require external absolute reference text to remain exactly unchanged;
- detect missing, retargeted, scope-changed and unexpected path references;
- reject relative `..` traversal fail-closed;
- remain compatible with pre-#1029 before-manifests that lack `pathReferences`.

This deliberately stops at the Storage boundary. Canonical Image Object `File` Property / Relation / UI meaning remains part of the required real-app semantic validation rather than teaching the Storage helper the Object subsystem's persistence representation.

## #951 — final Photo -> Image preservation matrix
The repository is ready for the actual real-macOS pass. Verify in the real app:
1. existing legacy Photos promoted to canonical Images still resolve after restart;
2. existing Bookmark `Images` / `Cover Image` media migrated from Photo data still render after restart;
3. existing Person profile Images still render after restart;
4. native canonical Images that never had legacy Photos remain intact;
5. Vault Move preserves canonical Image resolution and remaining migration-only compatibility paths at the target;
6. default/custom Vault switching keeps image/profile/cover data isolated;
7. external absolute image/file references are not silently copied, rebased or deleted;
8. missing/offline Vault behavior remains fail-closed and does not manufacture an empty replacement data set;
9. Duplicate/reopen/backup-restore does not lose Image/Photo mapping required for migration compatibility.

Use `docs/vault_preservation_validation.md` and the preservation manifest before/after filesystem-sensitive operations. The helper verifies SQLite integrity, exact managed bytes, and legacy Photo/Bookmark attachment path persistence; it does **not** replace Object/Relation/UI semantic checks.

## #242 — remaining real-macOS lifecycle matrix
Production lifecycle remains integrated: custom Vault paths are authoritative; unavailable Vaults fail closed; Create/Open/Switch/Move/Recovery use the normal bootstrap lifecycle; Move checkpoints/copies/validates/reopens with rollback and never auto-deletes the source; backup/restore and registry-only removal remain non-destructive.

Vault v1 remains:

```text
<My Vault>/
├─ database.sqlite
├─ profile.json
├─ photos/
└─ attachments/
```

Final real-Mac checks:
1. Create a Vault in a temporary custom/external location and restart successfully.
2. Open that Vault in place and confirm it is not copied to the default root.
3. Switch default/custom Vaults and verify data separation/preservation.
4. Move a Vault, restart at the target, verify managed photos/attachments plus external references, and confirm the source Vault still exists.
5. Exercise invalid/non-empty Move target plus missing/moved-folder recovery and confirm the current/source Vault remains intact with no manufactured empty replacement.

Run #242 and #951 as one non-destructive exercise where practical.

## Shared managed-file contract
Integrated contracts remain unchanged:
- `VaultManagedFileCopyService` copies regular files into `<Vault>/attachments`, returns portable paths plus explicit `vault-managed-copy-v1` ownership, and rolls back only the exact created copy.
- Legacy Bookmark attachment copy and canonical File import reuse that seam.
- Persistent attachment deletion requires explicit managed ownership plus a safe Vault-relative `attachments/...` path and fails closed on traversal, symlinks, non-files and unavailable roots.
- Legacy Photo physical deletion requires proven active-Vault managed ownership; external/ambiguous files are preserved.
- `ImageManagedFileDeletionPolicy` separately protects shared canonical/legacy Image files before `PhotoStorageService` can physically delete bytes.

Do not infer ownership from a Vault-looking path alone.

## Data-safety invariants
- Never silently replace/recreate an unavailable Vault to continue an operation.
- Configured Vault/profile roots control managed-media resolution.
- External absolute references remain external and never gain delete authority from path location.
- Physical delete fails closed on traversal, symlinks, unsafe roots, non-files and ambiguous/shared ownership.
- Generic File physical delete requires explicit managed ownership.
- Removing a Vault from the recent/registered list never deletes its bytes.
- Raw filesystem/database exception details must not leak to user-facing messages.
- #951 validation must not delete historical Photo schema/data; destructive schema retirement is a separate explicit migration decision.

## Cross-lane boundaries
- **D** owns Image/Photo/File identity, promotion/mapping, MIME/content routing and user-facing primitive semantics; #1021/#1025 remain D-owned.
- **B** owns Relation mutation/index/delete integrity.
- **C** completed #949; no remaining legacy `写真` navigation work belongs to F.
- **G** owns #950 caller-zero compatibility cleanup; do not follow it into `app_database.dart` or Bookmark hosts without a concrete F defect.
- **F** owns byte placement, portable paths, Vault lifecycle/recovery, physical-delete safety and final preservation validation.

## Current checkpoint / stop reason
- #1026 merged: `dc9a330896bb79b146b692b47b7fd38464311995`, CI #3004 full green.
- #1029 merged: `78f5b989320008f214cbe526d0fbaaec34156cc0`, CI #3020 full green.
- F boundary audit of D PR #1025 found no new filesystem/ownership defect requiring F changes.
- Open-Issue audit found no additional independent F-owned production implementation obligation.
- Production behavior changed by #1026/#1029: **none**; migration/data impact: **none**.

The remaining #242/#951 close condition requires **actual real-macOS app/Vault interaction**. This chat has no local desktop/Computer Use access to operate the user's Mac, so that validation cannot be truthfully marked complete here. If the real-machine pass exposes a reproducible filesystem/Vault defect, reopen Lane F implementation with a focused Issue and regression-backed fix; otherwise record the results on #242/#951 and close them when all manual criteria pass.
