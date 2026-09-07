# AI Progress — Storage, Vault & Delivery Lane

> Lane F handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` before implementation. Recheck Primitive/Refactor ownership before changing shared storage helpers or bootstrap hotspots.

## Lane goal
Own physical data-location lifecycle, Vault portability/recovery, filesystem-level managed storage contracts shared by primitives, and app delivery plumbing without taking over Object/Relation product semantics.

## Primary issues
- **#897 — active:** make legacy Photo physical deletion Vault-safe during Photo -> Image migration.
- #242 — user-selectable Vault folders and safe create/open/switch/move/recovery lifecycle. Production implementation is complete; real-macOS validation remains before closure.
- #218 — installable macOS delivery. Repository packaging/CI is complete; user-machine install/launch/data-preservation validation remains.

## Current checkpoint — 2026-09-08
Active branch: `feature/storage-vault-safe-legacy-photo-delete-897`, based on main `94b3833106683745291470732331aef3d28d66d5` after Lane D merged #892.

Completed #897 checkpoints on the branch:
- `d50b44291f36bb0321b22adb959333edb90850cb` — hardened `PhotoStorageService.deleteManagedPhoto(...)` so deletion authority comes from the configured active managed `photos/` root rather than the legacy `PhotoRecord.path` alone.
- `42cc2fb4275dedac8c4be6d2e08a1ab5311467df` — added focused Storage regressions for managed delete, external paths, traversal, symlink target/root, offline root, missing file idempotency and `.bookmark_original` safety.
- `ceefd63993e5c039f66946a9a5254fe89d384d71` — updated the real `BookmarkRepository.deletePhoto(...)` regression fixture to use `<profile>/photos` and portable `photos/...` paths, and proved deleting an external-path Photo row preserves external bytes.

### #897 behavior now implemented
`PhotoManagedFileDeletionPolicy` remains the higher-level Object/Image sharing guard. The Storage layer does not duplicate Image identity logic.

`PhotoStorageService.deleteManagedPhoto(...)` now:
- accepts physical deletion authority only from explicit `photoDirectoryPath` or the active profile/Vault `PhotoStorageService.activePhotoDirectoryPath`; the import-time application-support fallback is not deletion authority;
- requires the configured `photos/` root itself to exist as a real directory with `followLinks: false`; missing/offline/symlink/non-directory roots fail closed and are never created by deletion;
- resolves relative/historical stored paths through `ProfilePathResolver` using the active profile/Vault parent of `photos/`;
- rejects empty paths, `.`/`..` segments, external absolute paths and lexical escapes outside the active `photos/` root;
- requires the target to be a regular non-symlink file and confirms its canonical resolved path remains inside the canonical managed root;
- treats a missing managed file as an idempotent no-op;
- deletes `.bookmark_original` only when that backup independently proves to be a regular non-symlink file inside the same managed root; an unsafe backup is preserved even when the primary managed Photo is safely deleted.

The existing `BookmarkRepository.deletePhoto(...)` call graph is intentionally unchanged: it first asks `PhotoManagedFileDeletionPolicy` whether canonical Images share the asset, deletes the legacy Photo row, then delegates byte cleanup to the now-safe Storage boundary. This keeps Object/Image ownership policy and filesystem ownership policy separate.

## Vault lifecycle (#242)
The end-to-end production path remains implemented:
- persisted custom Vault paths are authoritative; missing custom Vaults/databases fail closed instead of being silently recreated;
- custom SQLite opens at `<Vault>/database.sqlite`;
- Settings supports Finder reveal, create, open, switch and move;
- Create/Open validate before active-state mutation;
- Move checkpoints/quiesces/copies/validates/reopens with rollback and never automatically deletes the source;
- backup/restore portability, moved/missing Vault recovery and registry-only removal are regression-covered.

Vault v1 format remains:

```text
<My Vault>/
├─ database.sqlite
├─ profile.json
├─ photos/
└─ attachments/
```

## Shared managed-file filesystem contract
Lane F also owns the generic attachments managed-copy/delete seam already integrated on main:
- #750 `VaultManagedFileCopyService` copies arbitrary regular files into `<Vault>/attachments`, returns portable stored paths and explicit `vault-managed-copy-v1` ownership, and safely rolls back only the newly-created copy.
- #771 persistent delete requires that explicit ownership key plus a safe Vault-relative `attachments/...` path and fails closed on traversal, symlinks, non-files and unavailable Vault roots.
- Lane D consumes this contract for canonical File import. File/Image Object identity, MIME routing and primitive semantics remain Lane D responsibilities.

## Data-safety invariants
- Never silently replace or recreate an unavailable Vault merely to continue an operation.
- Configured Vault/profile roots control managed-media resolution.
- External absolute references remain external and never gain deletion authority from a legacy record.
- Physical delete fails closed on traversal, symlinks, unsafe roots, non-files and ambiguous ownership.
- Legacy Photo/Image sharing policy remains distinct from Storage path/byte ownership.
- Removing a Vault from the registered/recent list never deletes its bytes.
- Raw filesystem/database exception details are not exposed in user-facing recovery/Settings messages.

## Validation
Previous Storage/Vault work through #771 repeatedly passed repository guardrails, Drift generation, `flutter analyze`, and the full Flutter test suite.

For active #897, focused regression code is now present but **normal GitHub Flutter CI has not yet been observed on the latest branch head**. This is the next required validation. The connector environment does not provide a local Flutter checkout/runtime, so repository CI is the authoritative execution path for this slice.

## Cross-lane / hotspot coordination
- Lane D owns Image/Photo product migration and merged #892 at `94b3833106683745291470732331aef3d28d66d5`; #897 is based on that main state.
- Lane B owns Relation integrity and may now proceed with #895; #897 does not touch Relation services.
- Lane C owns #896 and generic View behavior; #897 does not touch `GenericDatabasePage`.
- Lane G currently owns the `GenericDatabasePage` import/shim lease in open PR #899. No #897 file overlaps that PR.
- #897 touches `photo_storage_service.dart`, focused tests and handoff documentation; it does not require `main.dart`, `settings_page.dart`, `profile_manager.dart`, `app_shell.dart`, or `app_database.dart` hotspot edits.

## Exact next actions
1. Open the focused Lane F PR for #897 and run normal Flutter CI.
2. Fix any Analyze/test/guard failure caused by the safe deletion boundary.
3. When CI is green, merge #897 and close the Issue.
4. Re-audit remaining Photo physical-delete callers for any path that bypasses `PhotoStorageService.deleteManagedPhoto(...)`; create a separate focused issue only if a concrete unsafe caller remains.
5. Then return Lane F to #242/#218 real-macOS validation unless another concrete filesystem/Vault obligation appears.

## Work in progress
#897 is implemented on `feature/storage-vault-safe-legacy-photo-delete-897` through `ceefd639…`. A PR/CI checkpoint is the immediate next step; do not call Lane F idle until that validation/integration completes.

## Known risks / non-goals
- This slice does not delete canonical Image Objects or change Photo UI semantics.
- It does not add destructive Vault deletion.
- It does not infer generic File attachment ownership from path location; explicit ownership remains required there.
- Legacy Photo paths may be historical or external, so preserving ambiguous bytes is intentional and safer than opportunistic cleanup.

## Stop reason
No stop condition has been reached yet. Continue #897 through PR/CI/integration before ending the Lane F run.
