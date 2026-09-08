# AI Progress — Storage, Vault & Delivery Lane

> Lane F handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` before implementation. Recheck Primitive/Refactor ownership before changing shared storage helpers or bootstrap hotspots.

## Lane goal
Own physical data-location lifecycle, Vault portability/recovery, filesystem-level managed storage contracts shared by primitives, and app delivery plumbing without taking over Object/Relation product semantics.

## Current status — 2026-09-08
Lane F now has one explicit active follow-up, **#951**, but the final real-macOS preservation pass is dependency-gated by the remaining Photo -> Image product/caller retirement work rather than by missing Storage production code.

Current checkpoint was re-audited from latest `main` `b35506224323d5e0c10c9dd527a18dca95f5db39` and live PR/Issue state:
- **#951 — active, dependency-gated.** Final real-macOS Vault/data-preservation validation for Photo -> Image consolidation. #941 Image Inspector parity is now completed/closed via `a74abec4cc231af91acbee956b4aaf131be87608`. Lane C #949 remains open with PR #997, and Lane G #950 remains active with current caller-zero cleanup PR #1005. Run the final #951 matrix only after #949 has retired normal legacy `写真` navigation and the applicable #950 caller-zero cleanup has integrated far enough to validate the intended final product path.
- **#242 — implementation complete; real-macOS validation remains.** Create/Open/Switch/Move/Recovery production code and automated regressions are integrated. Its remaining validation overlaps the Vault lifecycle portion of #951 and should be recorded together where practical.
- **#897 — completed/closed.** PR #906 was squash-merged as `b04ebeb1f354156873c51ca0eaaadb32e7cfb63e` after final rebased Flutter CI #2756 passed the complete suite.
- **#218 — completed/closed.** Repository release/DMG packaging is green, and the user already validated the release `Bookmark.app` on the actual Mac with existing data preserved. Finder installation is the safe fallback when automated `/Applications` copy lacks permission.

No open PR currently gives Lane F a shared-hotspot lease. Current open work is C/G-owned; do not edit `app_shell.dart`, `app_database.dart`, Inspector hosts or primitive migration code from Lane F merely to accelerate #951.

Do not invent new Storage abstractions merely to keep this lane active. Resume Storage implementation only for a concrete filesystem/Vault defect found by validation or an explicit cross-lane Storage dependency.

## #951 — Photo -> Image final preservation gate
#951 is a real-machine preservation checkpoint, not a request to redesign Vault storage.

Required final matrix after #949/#950 are sufficiently integrated:
1. Existing legacy Photos promoted to canonical Images still resolve after app restart.
2. Existing Bookmark Images / Cover Image migrated from legacy Photo data still render after restart.
3. Existing Person profile images migrated through canonical Image Relations still render after restart.
4. Native canonical Images that never had legacy Photos remain intact.
5. Move a Vault and confirm canonical Image paths plus remaining legacy compatibility paths resolve correctly at the target.
6. Switch between default/custom Vaults and confirm image/profile/cover data remains isolated to the correct Vault.
7. External absolute image/file references are not silently copied, rebased or deleted.
8. Missing/offline Vault behavior remains fail-closed and does not manufacture an empty replacement data set.
9. Duplicate/reopen/backup-restore behavior does not lose Image/Photo mapping required for migration compatibility.

If the pass exposes a reproducible repository defect, record it as a focused owner-lane Issue before changing code. Storage owns physical path/byte/Vault-lifecycle defects; Image identity/presentation belongs to Lane D, Relation corruption belongs to Lane B, navigation belongs to Lane C, and caller-zero compatibility cleanup belongs to Lane G.

## #897 — legacy Photo deletion safety
The remaining legacy Photo physical-delete path is Vault-safe.

`PhotoStorageService.deleteManagedPhoto(...)`:
- accepts deletion authority only from an explicit/active managed `photos/` root; the import-time application-support fallback is never deletion authority;
- requires the configured `photos/` root to exist as a real non-symlink directory;
- resolves portable/historical stored paths through `ProfilePathResolver` against the active Vault/profile root;
- rejects empty paths, `.` / `..` traversal, external absolute paths, lexical escapes, symlink roots/targets, non-file entities and ambiguous ownership;
- treats a missing managed file as an idempotent no-op;
- does not recreate an offline/missing Vault merely to clean up bytes;
- deletes `.bookmark_original` only when that backup independently proves to be a regular non-symlink file inside the same canonical managed root.

`BookmarkRepository.deletePhoto(...)` now explicitly passes its own active Vault `photoDirectoryPath` into the Storage boundary instead of depending on bootstrap-global state. `PhotoManagedFileDeletionPolicy` remains the separate higher-level canonical Image sharing guard, so Object/Image identity policy and filesystem ownership policy stay distinct.

Regression coverage includes managed delete, external absolute preservation, traversal, symlink file/root preservation, offline/missing Vault behavior, missing-file idempotency, paired backup safety, repository portable-path deletion, external-file preservation and canonical Image sharing.

Validation history:
- CI #2746 exposed the repository caller's implicit static-root dependency through the existing real `<Vault>/photos/...` fixture.
- The production caller was corrected to pass the repository's active Vault photo root explicitly.
- CI #2749 then passed the full suite on the corrected implementation.
- The branch was refreshed onto main without dropping concurrent Photo backlink/refactor/View work.
- Final rebased CI #2756 passed guardrails, Drift generation, `flutter analyze`, and the full Flutter test suite before #906 merged.

A post-implementation production audit found no remaining legacy Photo physical-delete caller that bypasses `PhotoStorageService.deleteManagedPhoto(...)`.

## Vault lifecycle (#242)
The end-to-end production path is implemented:
- persisted custom Vault paths are authoritative; missing custom Vaults/databases fail closed instead of being silently recreated;
- custom SQLite opens at `<Vault>/database.sqlite`;
- Settings supports Finder reveal, create, open, switch and move;
- Create/Open validate before active-state mutation;
- Move checkpoints/quiesces/copies/validates/reopens with rollback and never automatically deletes the source;
- legacy absolute managed Photo/attachment paths inside the source Vault are rebased only when a corresponding copied target exists;
- external absolute references remain external;
- backup/restore portability, moved/missing Vault recovery and registry-only removal are regression-covered;
- removing a Vault from the registered/recent list never deletes its files.

Vault v1 format remains:

```text
<My Vault>/
├─ database.sqlite
├─ profile.json
├─ photos/
└─ attachments/
```

### Remaining #242 validation
Real macOS only:
1. Create a Vault in a temporary custom/external location and restart successfully.
2. Open an existing Vault and confirm it stays in place rather than being copied to the default root.
3. Switch between default/custom Vaults and verify data separation/preservation.
4. Move a Vault, restart from the target and verify photos/attachments/external references.
5. Exercise invalid/non-empty Move target plus missing/moved-folder recovery and verify the source/current Vault stays intact.

These checks should be combined with the #951 image-preservation matrix rather than run as two unrelated destructive-looking exercises. The source Vault must remain intact throughout Move/recovery validation.

## Shared managed-file filesystem contract
The generic managed-file seam is integrated on `main`:
- **#750** `VaultManagedFileCopyService` copies arbitrary regular files into `<Vault>/attachments`, returns portable stored paths plus explicit `vault-managed-copy-v1` ownership, and can roll back only the exact newly-created copy.
- **#766** routes the legacy Bookmark attachment copy path through the same seam and rolls back the managed copy if downstream DB persistence fails.
- **#771** persistent physical delete requires the explicit ownership key plus a safe Vault-relative `attachments/...` path and fails closed on traversal, symlinks, non-files and unavailable Vault roots.
- Lane D canonical File import already consumes the managed-copy/rollback seam. File/Image identity, MIME/content routing and primitive-domain mutation remain Lane D responsibilities.

Do not infer generic File ownership merely because a path is under `attachments/`; persistent deletion requires the explicit Storage ownership contract.

## macOS delivery (#218)
Completed and closed:
- release `Bookmark.app` packaging is reproducible;
- DMG packaging and `Bookmark-macOS` artifact generation succeed in GitHub Actions;
- Bundle Identifier/data-preservation safeguards are documented and implemented;
- install/open-DMG helpers are available in `tool/package_macos.sh`;
- the user built and launched the release app on the actual Mac and confirmed existing Bookmark data remained visible;
- automated `/Applications` copy permission denial is non-blocking because Finder drag installation works without changing the app/data contract.

Optional branded icon artwork, Developer ID signing/notarization and automatic updates remain outside the completed #218 scope.

## Data-safety invariants
- Never silently replace or recreate an unavailable Vault merely to continue an operation.
- Configured Vault/profile roots control managed-media resolution.
- External absolute references remain external and never gain deletion authority from a legacy record.
- Physical delete fails closed on traversal, symlinks, unsafe roots, non-files and ambiguous ownership.
- Legacy Photo/Image sharing policy remains distinct from Storage path/byte ownership.
- Generic File physical delete requires explicit managed ownership, not path location alone.
- Removing a Vault from the registered/recent list never deletes its bytes.
- Raw filesystem/database exception details are not exposed in user-facing recovery/Settings messages.
- Final Photo -> Image preservation validation must not delete legacy schema/data; destructive schema retirement is a separate explicit migration decision.

## Cross-lane boundaries
- Lane D owns Image/Photo/File product migration, mappings, Object identity, MIME/content routing and user-facing primitive semantics.
- Lane B owns Relation mutation/index/delete integrity.
- Lane C owns generic Images navigation and final legacy `写真` navigation retirement (#949).
- Lane G owns caller-zero legacy compatibility deletion (#950) and tooling/refactor work.
- Lane F owns byte placement, portable paths, Vault lifecycle/recovery, physical-delete safety and the #951 preservation gate.
- Do not broaden Storage work into Photo UI, canonical Image identity, Relation design, AppShell navigation or caller-zero deletion.

## Active branch / checkpoint
- branch: `docs/storage-handoff-image-preservation-951`
- baseline: `main` `b35506224323d5e0c10c9dd527a18dca95f5db39`
- production code changed in this checkpoint: none
- shared hotspot lease: none
- validation performed: live Issue/PR/main/handoff audit; #941 completion confirmed, #949/#950 still open, no new independent Storage defect identified

## Next actions
1. Track #949 and #950 from live GitHub state; do not begin the final #951 pass from an intermediate product state.
2. Once `画像` is the single normal user-facing image collection and the applicable caller-zero cleanup has integrated, run the combined #951 + #242 real-macOS preservation matrix on a non-destructive test Vault while retaining the source Vault.
3. Record each matrix result on #951 and the overlapping Vault-lifecycle results on #242.
4. If a reproducible filesystem/Vault defect appears, open/follow a focused Lane F child Issue and implement a regression-backed fix; otherwise close #951/#242 when the manual validation criteria are satisfied.

## Stop reason
Lane F is **dependency-gated**, not idle: #951 is now the active F-owned completion gate, but the final real-machine preservation pass must wait for Lane C #949 and the applicable Lane G #950 retirement state. There is no safe independent Storage production-code change to make before those dependencies settle, and speculative Vault changes are explicitly out of scope.
