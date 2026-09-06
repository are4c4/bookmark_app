# AI Progress — Storage, Vault & Delivery Lane

> Lane F handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` before implementation. Check Primitive/Refactor ownership before changing shared storage helpers or bootstrap hotspots.

## Lane goal
Own the physical data-location lifecycle independently from Object/Relation product semantics so Vault/file portability and app delivery can progress in parallel.

## Primary active issues
- #242 — user-selectable Vault folders and safe create/open/switch/move/recovery lifecycle.
- #218 — installable macOS delivery/packaging validation and final user-machine follow-up.
- #484/#489/#495 only where filesystem/Vault contracts are dependencies of primitive File/Image behavior.

## Owns
- Profile/Vault directory lifecycle and persisted locations.
- Vault create/open/switch/move validation and bootstrap orchestration.
- profile-relative/Vault-relative path portability.
- backup/restore/profile duplication and filesystem recovery.
- missing/offline storage-location handling.
- app release/install packaging and delivery plumbing.
- filesystem-level managed-storage helpers shared by primitives when not identity/product-specific.

## Boundary with Primitive lane
- Storage lane owns where/how managed bytes live and survive Vault lifecycle.
- Primitive lane owns what Image/File/Weblink Objects mean, their identity, and domain mutation rules.
- Never add a second Image/File ownership model in Storage merely for Vault support.

## Current implementation checkpoint — 2026-09-07
Latest verified Storage integration commit in this run: `4d29a7af292c5c51f99d1fa486f099787d4e7e9f` (`#664`).

Issue #242 has advanced from planning to a working end-to-end Vault lifecycle:

- Persisted non-empty custom `DatabaseProfile.directoryPath` is authoritative; legacy empty paths still fall back to the app-managed Documents location. Missing custom Vault directories/databases fail closed rather than being recreated as empty Vaults.
- `AppDatabase` opens custom Vault SQLite at `<Vault>/database.sqlite`; the registry path and the physical DB connection no longer diverge.
- Settings shows the current Vault name/path and supports `Finderで表示`.
- Create/Open/Switch are wired through the platform directory picker and the existing bootstrap/switch lifecycle. Create requires an empty target; Open validates `profile.json` + `database.sqlite` and uses normal Drift migration in place.
- Complete Vault backup/restore portability is covered by regression tests, including profile-relative photo/attachment resolution after restore to a different root.
- Cloud/external-folder safety is documented in `docs/VAULTS.md`: filesystem locations are best-effort and concurrent editing of one SQLite Vault from multiple computers/processes is unsupported.
- Missing/moved Vault recovery is integrated into startup. Registry inspection occurs before replacing anything; users can locate the same Vault again, and unavailable inactive Vaults can be removed from the registry without deleting files.
- External/custom Vault removal from Profile state is unregister-only. Recursive physical deletion remains limited to app-managed profile directories.
- Safe Move primitives are integrated: preflight, complete copy, target validation, registry commit with rollback, lifecycle ordering, Settings action, and real bootstrap host wiring.
- The real Move runtime now performs `PRAGMA wal_checkpoint(FULL)`, removes the live repository from the widget tree, disposes/closes the source DB graph, copies/validates the complete Vault, updates the registry, reloads `ProfileManager` from persisted registry state, and reopens/verifies the target through the normal repository bootstrap path.
- Move failure keeps the source Vault files untouched. Registry commit failure/target reopen failure rolls the registry back to source and attempts source reopen. The source Vault is never automatically deleted after a successful move.

Major merged checkpoints include #509, #519, #525, #544, #549, #555, #564, #566, #574, #576, #580, #582, #591, #594, #600, #605, #607, #615, #619, #622, #636, #639, #648, #651 and #664.

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
- Move checkpoints and closes the active database before physical copy.
- Move copies the complete Vault and validates the target before registry commit.
- Failed Move never deletes the source Vault.
- Target reopen failure rolls registry state back before source reopen is attempted.
- Removing a custom/external Vault from the registry does not delete its folder.
- Recovery repairs only registry location state after validating the selected Vault identity/database.
- Raw filesystem/database exception details are not shown in user-facing recovery/Settings messages.
- Cloud-synced folders are locations, not a concurrent multi-device sync protocol.

## Validation performed
- Repeated GitHub Actions runs across the Vault slices passed maintainability guardrails, feature legacy dependency guard, Drift generation, `flutter analyze`, and the complete Flutter test suite.
- #664 current-head CI run `34067462496` passed all checks, including the full test suite, before merge.
- Move services have focused regressions for same-path/non-empty target rejection, copy inventory validation, registry conflicts/stale state, target reopen rollback, source restore ordering, and primary-error preservation.
- Startup recovery has focused regressions for missing-directory vs missing-database classification, active/inactive actions, picker cancellation, unregister confirmation, retry ordering, and privacy-safe errors.
- Backup portability regression verifies complete Vault restore and profile-relative photo/attachment resolution at a new root.
- #218 main-push packaging validation previously succeeded with both analyze/test and macOS release build, producing the `Bookmark-macOS` artifact. Final user-machine install/launch/data-preservation verification remains manual.

## Remaining work / next actions
1. Add an explicit Move/path regression for legacy absolute paths inside the source Vault versus absolute references outside the Vault. Reuse the proven duplication/path-rewrite rule: only source-contained paths may be rebased; outside absolute references must not be silently rewritten by Move-specific code.
2. Re-audit `ProfileStorageMigrator` interaction during target reopen so Move does not accidentally broaden legacy migration semantics beyond #242's external-reference contract.
3. Finish user-facing terminology cleanup around the existing `ProfileManagementPage`/`Profile管理` surfaces so the product concept is consistently `Vault`, without renaming internal compatibility classes.
4. Verify Create/Open/Switch/Move/Recovery manually on a macOS build with a temporary external/custom folder. Include failed/non-empty target, moved/missing folder, and restart-after-move cases.
5. Complete #218's remaining user-machine DMG/install/launch/upgrade data-preservation check.
6. Update Issue #242 acceptance checkboxes after the path-boundary regression/manual validation is complete; split any optional destructive source-delete UX into a separate explicitly destructive follow-up rather than adding implicit deletion to Move.

## Cross-lane / hotspot coordination
- Lane D owns Image/File/Weblink object semantics; Lane F must not redesign primitive identity while testing file portability.
- Lane G may refactor storage/bootstrap code only after behavior is covered and without racing active #242 product changes.
- `main.dart`, `settings_page.dart`, `profile_manager.dart`, `app_shell.dart`, and `app_database.dart` remain shared hotspots. Recheck open PR ownership before each non-trivial edit.
- During the final Move wiring in this run, no other open PR owned `main.dart`; #664 was intentionally patch-scoped to bootstrap lifecycle behavior.

## Known risks
- The normal `ProfileStorageMigrator` historically canonicalizes managed photo/attachment paths when opening a profile. Before declaring #242 fully complete, explicitly prove that Move-specific behavior satisfies the issue's distinction between source-contained legacy absolute paths and external absolute references.
- Source Vault deletion is intentionally absent. Any future `Delete old Vault files` flow must be separate, explicit, post-success, and destructive-action reviewed.
- Cloud provider conflict semantics and multi-process locking remain non-goals; fail closed when a configured filesystem location is unavailable.

## Work in progress
- Production Move wiring is merged through #664 and no Storage production PR is currently required to make Create/Open/Switch/Recovery/Move reachable.
- Next implementation slice should be the path-boundary regression/audit above, preferably away from shared UI hotspots.

## Stop reason
No product blocker is known. This handoff was refreshed after the end-to-end Move integration checkpoint; continue with the path-boundary regression, terminology cleanup, and manual delivery validation in that order when execution continues.
