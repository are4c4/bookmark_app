# AI Progress — Storage, Vault & Delivery Lane

> Lane F handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` before implementation. Check Primitive/Refactor ownership before changing shared storage helpers.

## Lane goal
Own the physical data-location lifecycle independently from Object/Relation product semantics so Vault/file portability and app delivery can progress in parallel.

## Primary active issues
- #242 — user-selectable Vault folders and safe create/open/switch/move lifecycle.
- #218 — installable macOS delivery/packaging validation and follow-up.
- #484/#489/#495 only where filesystem/Vault contracts are dependencies of primitive File/Image behavior.

## Owns
- Profile/Vault directory lifecycle and persisted locations.
- Vault create/open/switch/move validation.
- profile-relative/Vault-relative path portability.
- backup/restore/profile duplication and filesystem recovery.
- missing/offline storage-location handling.
- app release/install packaging and delivery plumbing.
- filesystem-level managed-storage helpers shared by primitives when not identity/product-specific.

## Boundary with Primitive lane
- Storage lane owns where/how managed bytes live and survive Vault lifecycle.
- Primitive lane owns what Image/File/Weblink Objects mean, their identity, and domain mutation rules.
- Never add a second Image/File ownership model in Storage merely for Vault support.

## Current implementation checkpoint
Issue #242 is now in active implementation.

- #519 is merged on `main` (`19e881de`): Settings shows the active Vault folder name/path and provides `Finderで表示` through a Storage-owned reveal service. This slice deliberately avoids `app_shell.dart` and derives the physical location from `BookmarkRepository.profileDirectoryPath`.
- #509 (`feature/storage-vault-path-loading`) makes persisted non-empty `DatabaseProfile.directoryPath` authoritative, keeps legacy empty paths on the app-managed fallback, fails closed for unavailable custom Vault directories/databases, and points the native Drift connection at `<Vault>/database.sqlite`. Filesystem regressions cover custom path persistence, legacy fallback, missing Vaults, and actual SQLite placement. Current-head CI has passed maintainability checks, Drift generation and `flutter analyze`; full tests are running after adding the required `path_provider` test harness for native temporary-directory lookup.
- #525 (`feature/storage-vault-create-open-core`, stacked on #509) adds safe `createVault` / `openVault` core operations. Create refuses non-empty target directories, initializes the normal schema before registry mutation, and writes portable metadata. Open validates `profile.json` + `database.sqlite`, runs the normal Drift open/migration path in place, and registers only after validation. Removing an external/custom Vault from Profile state is unregister-only; physical recursive deletion remains limited to app-managed Profile directories.
- #525 filesystem tests now provide the same `path_provider` temporary-directory test boundary used by #509, so native custom-path Drift connections are testable without desktop plugins.

The existing Profile layout remains the Vault v1 layout: `database.sqlite`, `profile.json`, `photos/`, and `attachments/`. Internal `DatabaseProfile` / `ProfileManager` terminology is intentionally unchanged.

## Data-safety findings
- A persisted custom Vault must never be recreated as an empty directory/database when its configured path is missing.
- `profileDirectoryPath` must control both managed media resolution and the physical SQLite file; retaining only registry metadata is insufficient.
- External/custom Vault unregister/delete must not recursively delete user-owned folders.
- Create/Open must validate and initialize before registry mutation, then use the existing app-level Profile switch/bootstrap lifecycle rather than opening a second long-lived database graph.
- `ProfilePathResolver` and existing duplication logic already provide the foundation for profile-relative media/attachment portability. Move semantics should reuse these proven rules rather than introduce another path model.
- `ProfileBackupService` checkpoints SQLite before export and packages the whole Profile/Vault directory. Backup/restore portability still needs explicit regression coverage before safe move work changes copy semantics.

## Active PR stack
1. #509 — `feature/storage-vault-path-loading` -> `main`.
2. #525 — `feature/storage-vault-create-open-core` -> #509 branch; retarget to `main` after #509 lands.

#519 has already landed and should not be reimplemented.

## Next actions
1. Finish #509 full CI and merge when green; if `main` moves, verify the unchanged `AppDatabase` constructor / `ProfileManager.load()` hunks rather than blindly rebuilding large files.
2. Retarget #525 to `main`, obtain full CI, and merge the Create/Open core.
3. Add Settings `新しいVaultを作成` / `既存のVaultを開く` / `Vaultを切り替える` using the platform folder picker and the existing app-level Profile switch lifecycle. Do not open/switch databases directly inside Settings widgets.
4. Add backup/restore portability regressions covering complete Vault contents plus profile-relative photos/attachments.
5. Add recent/switch UX and missing/moved Vault relink recovery.
6. Implement safe move only after Create/Open/UI paths are proven: close/checkpoint -> copy -> validate -> registry update -> reopen/verify -> optional source deletion offered separately.
7. Document cloud-folder best-effort support and the no-concurrent-editing SQLite limitation.

## Safety
- Never silently replace a missing Vault with a new empty database.
- Never delete/move source Vault data before target validation and successful reopen.
- Never recursively delete external/custom Vault files as a side effect of removing a registry entry.
- Preserve external absolute file references; do not silently copy/rebase them.
- Keep SQLite concurrency limitations explicit for cloud-synced folders.
- Keep Object/Relation persistence semantics unchanged.
- Avoid large shared-hotspot rewrites; inspect open PR ownership before touching `app_shell.dart`, `main.dart`, `settings_page.dart`, or `profile_manager.dart`.

## Handoff checklist
Record active Issue, branch/PR/commit, filesystem operations changed, data-safety validation, Primitive/Refactor dependencies, hotspot ownership, next actions, and stop reason.
