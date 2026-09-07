# AI Progress — Storage, Vault & Delivery Lane

> Lane F handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` before implementation. Check Primitive/Refactor ownership before changing shared storage helpers or bootstrap hotspots.

## Lane goal
Own the physical data-location lifecycle independently from Object/Relation product semantics so Vault/file portability and app delivery can progress in parallel.

## Primary active issues
- #242 — user-selectable Vault folders and safe create/open/switch/move/recovery lifecycle. Production code is implemented; real-macOS validation remains before closure.
- #218 — installable macOS delivery/packaging validation and final user-machine follow-up.
- #484/#489/#495 — filesystem/Vault contracts needed by canonical File/Image import, especially the remaining generic managed-copy + explicit ownership seam.

## Owns
- Profile/Vault directory lifecycle and persisted locations.
- Vault create/open/switch/move validation and bootstrap orchestration.
- profile-relative/Vault-relative path portability.
- backup/restore/profile duplication and filesystem recovery.
- missing/offline storage-location handling.
- app release/install packaging and delivery plumbing.
- filesystem-level managed-storage helpers shared by primitives when not identity/product-specific.

## Boundary with Primitive lane
- Storage lane owns where/how managed bytes live, explicit filesystem ownership/rollback, and survival across Vault lifecycle.
- Primitive lane owns what Image/File/Weblink Objects mean, their identity, metadata, capability behavior and domain mutation rules.
- Never add a second Image/File identity or persistence model in Storage merely for Vault support.
- Generic File import must reuse one Storage-owned managed-copy boundary instead of duplicating `AttachmentStorageService` or introducing another filesystem root.

## Current implementation checkpoint — 2026-09-07
Latest verified Storage integration commit in this run: `4f81530da196e4f489645b24d9ded7e9dfdc892d` (`#742`).

Issue #242 now has a working end-to-end Vault lifecycle in production code:

- Persisted non-empty custom `DatabaseProfile.directoryPath` is authoritative; legacy empty paths still fall back to the app-managed Documents location. Missing custom Vault directories/databases fail closed rather than being recreated as empty Vaults.
- `AppDatabase` opens custom Vault SQLite at `<Vault>/database.sqlite`; registry location and the physical DB connection no longer diverge.
- Settings shows current Vault name/path and supports `Finderで表示`, create, open, switch and move actions through platform pickers rather than typed filesystem paths.
- Create validates an empty target, creates the portable Vault structure and initializes the current Drift schema before registration.
- Open validates `profile.json` + `database.sqlite`, opens/migrates the database in place and never copies the selected Vault into the app-managed Profiles root.
- Create/Open/Switch use the existing bootstrap/switch lifecycle; normal app flow does not keep two active DB graphs for one Vault.
- Complete Vault backup/restore portability is covered by regressions, including profile-relative photo/attachment resolution after restoring under a different root.
- Cloud/external-folder safety is documented in `docs/VAULTS.md`: cloud folders are best-effort filesystem locations and concurrent editing of one SQLite Vault from multiple computers/processes is unsupported.
- Missing/moved Vault recovery is integrated into startup. Registry inspection occurs before destructive fallback; users can locate the same Vault again, and unavailable inactive Vaults can be unregistered without deleting files.
- Safe Move is integrated end-to-end: preflight, FULL WAL checkpoint, source quiesce/close, complete copy, target validation, registry commit, target reopen/verify and rollback/source reopen on failure.
- Move never automatically deletes the source Vault. Failed copy/validation leaves source files untouched; target reopen failure restores registry state before source reopen is attempted.
- #691 (`57ee49920a0047d29d9b88fc64c0a5cc37c9b64f`) proved the Move path boundary: source-Vault-contained legacy absolute Photo/attachment paths are rebased only when the copied target counterpart exists; absolute references outside the Vault remain external and are not silently copied or rewritten. Source rollback reopen skips storage migration.
- #708 (`f125c1c48d8aa079ff1ddc14112849834b0ccaa6`) aligned Vault management/backup copy with product terminology and clarified filesystem safety.
- #733 (`786af273f32e2bd8d9a27048557b16c51056b38f`) finished the remaining user-facing `Profile` -> `Vault` terminology in the shared app shell while intentionally retaining internal compatibility class/API names.
- #742 (`4f81530da196e4f489645b24d9ded7e9dfdc892d`) changed user-facing Vault removal to `一覧から外す`: app-managed and external Vaults are now registry-only removal and all Vault bytes remain intact. Registry-save failure rolls in-memory state back. Destructive cleanup remains private and limited to partial app-managed copies created by failed duplicate/backup-restore setup.

Major merged checkpoints include #509, #519, #525, #544, #549, #555, #564, #566, #574, #576, #580, #582, #591, #594, #600, #605, #607, #615, #619, #622, #636, #639, #648, #651, #664, #691, #708, #733 and #742.

The Vault v1 physical format remains intentionally unchanged:

```text
<My Vault>/
├─ database.sqlite
├─ profile.json
├─ photos/
└─ attachments/
```

Internal `DatabaseProfile` / `ProfileManager` names remain compatibility-oriented implementation details; do not perform a repository-wide Profile -> Vault rename as part of #242.

## Data-safety invariants now enforced
- Never silently replace a missing Vault with a new empty directory/database.
- The configured Vault path controls both SQLite and managed-media resolution.
- Create/Open validate before mutating active state.
- Open-existing never copies a selected Vault into the default Profiles root.
- Move checkpoints and closes the active database before physical copy.
- Move copies the complete Vault and validates the target before registry commit.
- Failed Move never deletes the source Vault.
- Target reopen failure rolls registry state back before source reopen is attempted.
- Move-specific storage migration may rebase only proven source-contained legacy absolute paths; external absolute references remain untouched.
- Removing any inactive Vault from the recent/registered list does not delete its directory or bytes.
- Failed registry persistence during ordinary Vault removal restores in-memory state instead of leaving registry/runtime disagreement.
- Internal failed duplicate/restore cleanup may delete only the partial app-managed copy that operation created.
- Recovery repairs only registry location state after validating selected Vault identity/database.
- Raw filesystem/database exception details are not shown in user-facing recovery/Settings messages.
- Cloud-synced folders are locations, not a concurrent multi-device sync protocol.

## Validation performed
- Repeated GitHub Actions runs across Vault slices passed maintainability guardrails, feature legacy dependency guard, Drift generation, `flutter analyze`, and the complete Flutter test suite.
- #691 path-boundary/Move-prepare heads passed the complete CI suite before integration.
- #708 and #733 terminology/safety copy heads passed the complete CI suite before integration.
- #742 final head `aa208e2e43022dae52659c90d924d678aeae7465`, CI run `34084240050`, passed guardrails, Drift generation, Analyze and the complete Flutter test suite before merge.
- Move services have focused regressions for same-path/non-empty target rejection, copy inventory validation, registry conflicts/stale state, target reopen rollback, source restore ordering, primary-error preservation and legacy absolute-path boundaries.
- Startup recovery has focused regressions for missing-directory vs missing-database classification, active/inactive actions, picker cancellation, unregister confirmation, retry ordering and privacy-safe errors.
- Backup portability regressions verify complete Vault restore and profile-relative photo/attachment resolution at a new root.
- Vault removal regressions verify app-managed bytes are preserved after unregister, persisted registry state remains unregistered after reload, and save failure restores the prior runtime state.
- #218 main-push packaging validation previously succeeded with analyze/test plus macOS release build and produced the `Bookmark-macOS` artifact. Final user-machine install/launch/data-preservation verification remains manual.

## Remaining work / next actions
1. **Lane F -> Lane D dependency:** add one generic managed-file copy/ownership boundary for arbitrary source files. Reuse the existing `<Vault>/attachments` storage location, return a Vault-relative/canonical stored path plus explicit ownership metadata, and provide rollback for a copy whose downstream Object creation fails. Do not couple the service to File Object identity.
2. After that Storage seam lands, update #242/#495 coordination so Lane D can wire `PrimitiveObjectImportService` / canonical File creation without duplicating storage logic.
3. Manually verify Create/Open/Switch/Move/Recovery on a real macOS build with temporary app-managed and custom/external folders. Include non-empty Move target, moved/missing Vault, restart-after-move and `一覧から外す` then reopen cases.
4. Complete #218's remaining user-machine DMG/install/launch/upgrade data-preservation check.
5. Once the real-macOS Vault pass is confirmed, close #242. Optional physical `Delete Vault files` remains a separate explicitly destructive future feature and is not required for #242.

## Cross-lane / hotspot coordination
- Lane D owns Image/File/Weblink Object semantics; Lane F must not add Object identity, MIME routing or primitive metadata to the managed-copy service.
- Lane D handoff currently states generic File import is blocked on this Lane F managed-copy + explicit ownership seam.
- Lane G may refactor storage/bootstrap code only after behavior is covered and without racing active Storage product changes.
- `main.dart`, `settings_page.dart`, `profile_manager.dart`, `app_shell.dart`, and `app_database.dart` remain shared hotspots. Recheck open PR ownership before each non-trivial edit.
- Prefer a new focused storage service + tests for the generic managed-copy seam; avoid shared UI/bootstrap hotspots.

## Known risks / non-goals
- Source Vault deletion after Move is intentionally absent. Any future `Delete old Vault files` flow must be separate, explicit, post-success and destructive-action reviewed.
- User-facing recent-list removal is intentionally non-destructive for both app-managed and external Vaults.
- Cloud provider conflict semantics and multi-process locking remain non-goals; fail closed when a configured filesystem location is unavailable.
- Generic File physical deletion must not infer ownership merely because a path happens to be under the Vault. Ownership must originate from the Storage copy contract.
- The remaining #242 uncertainty is real-host/platform validation, not an unimplemented production lifecycle path.

## Work in progress
- #242 production implementation is integrated through #742; no known code-level Vault lifecycle acceptance gap remains.
- Next independent implementation slice is the generic managed-copy/ownership seam requested by Lane D for #484/#489/#495.

## Stop reason
No product blocker is known. Continue with the managed-copy/ownership seam while #242 awaits real-macOS validation; then return to #218 delivery verification when a user-machine run is available.
