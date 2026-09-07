# AI Progress — Storage, Vault & Delivery Lane

> Lane F handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` before implementation. Recheck Primitive/Refactor ownership before changing shared storage helpers or bootstrap hotspots.

## Lane goal
Own physical data-location lifecycle, Vault portability/recovery, filesystem-level managed storage contracts shared by primitives, and app delivery plumbing without taking over Object/Relation product semantics.

## Primary issues
- #242 — user-selectable Vault folders and safe create/open/switch/move/recovery lifecycle. Production implementation is complete; real-macOS validation remains before closure.
- #218 — installable macOS delivery. Repository packaging/CI is complete; user-machine install/launch/data-preservation validation remains.
- #489/#495 (Lane D dependency) — shared managed-file copy/ownership/delete filesystem contract. Lane F implementation is now available on `main`.

## Current checkpoint — 2026-09-07
Latest verified Storage integration commit: `3f3c63c024f6885c32f38fce94253ac368787857` (#771).

### Vault lifecycle (#242)
The end-to-end production path is implemented:
- persisted custom Vault paths are authoritative; legacy empty paths still fall back to the managed Documents location;
- missing custom Vaults/databases fail closed instead of being silently recreated;
- custom SQLite opens at `<Vault>/database.sqlite`;
- Settings shows current Vault name/path and supports Finder reveal, create, open, switch and move;
- Create requires a safe empty target and initializes the portable Vault structure/schema;
- Open validates `profile.json` + `database.sqlite` and opens in place;
- Switch uses the existing DB close/open/rollback lifecycle;
- backup/restore portability and profile-relative media resolution are regression-covered;
- startup recovery supports moved/missing Vaults and registry-only removal of unavailable inactive Vaults;
- Move performs preflight, FULL WAL checkpoint, source quiesce/close, full copy, target validation, registry commit, target reopen/verify, and registry/source rollback on failure;
- Move never automatically deletes the source Vault;
- Move-specific storage migration only rebases proven source-contained legacy absolute paths when the copied target exists; external absolute references remain external;
- user-facing `一覧から外す` is registry-only for app-managed and external Vaults; all Vault bytes remain intact;
- registry-save failure during removal rolls runtime state back;
- cloud-synced folders are supported only as filesystem locations; concurrent multi-device/process editing of one SQLite Vault is unsupported.

Relevant merged checkpoints include #509, #519, #525, #544, #549, #555, #564, #566, #574, #576, #580, #582, #591, #594, #600, #605, #607, #615, #619, #622, #636, #639, #648, #651, #664, #691, #708, #733 and #742.

The Vault v1 physical format remains:

```text
<My Vault>/
├─ database.sqlite
├─ profile.json
├─ photos/
└─ attachments/
```

Internal `DatabaseProfile` / `ProfileManager` names remain compatibility details; do not do a repository-wide Profile -> Vault rename as part of #242.

### Shared managed-file filesystem contract (#489/#495)
Lane F now provides the complete filesystem seam requested by Lane D:

- #750 (`fedcceb49463ac05dfa64f338620207f65bdf5b2`) added `VaultManagedFileCopyService` for arbitrary regular-file import into `<Vault>/attachments`.
- Copy returns a portable Vault-relative `storedPath`, resolved path, original filename, size, and explicit ownership key `vault-managed-copy-v1`.
- Ownership is granted only by the copy contract; it is never inferred from “path happens to be under the Vault”.
- Receipt rollback deletes only the just-created managed copy and preserves the source file.
- Missing/non-file sources, missing Vault roots, non-directory/symlink `attachments` roots and path escapes fail closed.
- #766 (`92680183cb0751049938be2f78226f335bb5be20`) moved legacy Bookmark attachment import onto the same managed-copy seam while preserving the existing public API/picker/extension behavior. If DB persistence fails after copy, that copy is rolled back and the source remains untouched.
- #771 (`3f3c63c024f6885c32f38fce94253ac368787857`) added persistent ownership-gated physical delete. `deleteOwnedCopy(...)` requires the explicit `vault-managed-copy-v1` key plus a safe Vault-relative `attachments/...` stored path.
- Owned delete rejects unknown ownership, traversal, external absolute paths, symlinks and non-file entities. A missing managed file is idempotent; an unavailable/missing Vault root fails closed and is not recreated.
- Receipt rollback now uses the same ownership-gated delete boundary.

Lane D has been notified on #489 and #495. It can now persist/use the ownership key for canonical File/Image lifecycle and wire content/MIME routing without introducing another filesystem root. Lane F must not add File/Image Object identity, MIME routing, primitive metadata or Relation semantics.

## Data-safety invariants
- Never silently replace a missing Vault with a new empty directory/database.
- The configured Vault path controls SQLite and managed-media resolution.
- Create/Open validate before mutating active state.
- Move checkpoints/closes before copy and validates target before registry commit.
- Failed Move never deletes the source Vault.
- Target reopen failure restores registry state before source reopen is attempted.
- External absolute references are not silently captured during Move.
- Removing a Vault from the registered/recent list never deletes its bytes.
- Generic physical file deletion requires explicit Storage ownership; path location alone is not authority.
- Managed copy/delete must fail closed on traversal, symlinks, unsafe roots and offline Vault roots.
- Raw filesystem/database exception details are not shown in user-facing recovery/Settings messages.

## Validation performed
- Vault lifecycle slices repeatedly passed maintainability guardrails, legacy dependency guard, Drift generation, `flutter analyze`, and the complete Flutter test suite before integration.
- #742 final head passed the full suite before merge and covers non-destructive Vault removal + registry rollback.
- #750 full CI passed with regressions for arbitrary extensions, portable paths, explicit ownership, non-overwrite behavior, rollback/source preservation, missing/non-file inputs, unsafe `attachments` roots and symlink escape prevention.
- #766 full CI run `34088918383` passed guardrails, Drift generation, Analyze and the complete Flutter test suite before merge.
- #771 final head `940273caf7e13ada11064591a41a2118876bbd13`, CI run `34090120344`, passed the complete Flutter CI suite before merge. Regressions cover owned delete, idempotent missing file, unknown ownership, traversal/external absolute paths, symlink targets and offline/missing Vault root fail-closed behavior.
- #218 main-push packaging validation already produced the `Bookmark-macOS` artifact from the real macOS release/DMG job.

## Cross-lane / hotspot coordination
- Lane D owns Image/File/Weblink identity, metadata, MIME/content routing and primitive mutation semantics. Lane F owns byte placement, portable stored paths, explicit ownership, rollback and physical delete safety.
- Lane D is no longer blocked on the managed-copy/ownership/delete filesystem seam; #750/#771 are on `main`.
- Lane G may refactor Storage/bootstrap code only behavior-preservingly and should not race active Storage product work.
- `main.dart`, `settings_page.dart`, `profile_manager.dart`, `app_shell.dart`, and `app_database.dart` remain shared hotspots. Recheck current open PR ownership before future non-trivial edits.
- No current Lane F work requires those shared hotspots.

## Remaining work / exact next actions
1. Real-macOS #242 validation: manually verify Create/Open/Switch/Move/Recovery with temporary app-managed and custom/external Vaults, including non-empty Move target, moved/missing Vault, restart-after-Move, and `一覧から外す` then reopen.
2. After the real-macOS pass, close #242. Optional physical “Delete Vault files” remains a separate explicit destructive future feature and is not required for #242.
3. #218 user-machine validation: run the packaged/install path on the user’s Mac and verify launch plus existing data visibility. Optional branded icon artwork remains a product/design follow-up, not a packaging blocker.
4. For #489/#495, only take new Lane F work if Lane D discovers a concrete filesystem/Vault contract gap. Do not implement primitive identity/MIME routing in Lane F.

## Work in progress
No production-code Storage PR is currently required after #771. The managed-file dependency is delivered and Vault lifecycle code is complete. This handoff update is the current Lane F bookkeeping slice.

## Known risks / non-goals
- Source Vault deletion after Move is intentionally absent.
- User-facing Vault unregister is intentionally non-destructive.
- Cloud provider conflict semantics and multi-process locking are non-goals.
- A path under `<Vault>/attachments` is not sufficient proof of ownership; callers must retain/persist the explicit Storage ownership key.
- The remaining #242/#218 uncertainty is real-host/platform validation, not a known repository code gap.

## Stop reason
After this handoff is merged, Lane F has no independent actionable repository implementation left under the current issues. The remaining #242 and #218 acceptance checks require execution on the user’s real macOS machine; future code work should resume only if those checks reveal a concrete defect or Lane D reports a specific missing filesystem contract.
