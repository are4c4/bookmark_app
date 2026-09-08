# AI Progress — Database, View & Schema UX Lane

> Lane C durable handoff. Always re-read `AGENTS.md`, the active GitHub Issue, `docs/AI_PROGRESS.md`, latest `main`, open PR ownership, and current CI before changing code. GitHub is the source of truth; commit SHAs below are checkpoints only.

## Lane goal
Make ObjectType / Database / View / schema configuration expressive and safe enough that new domains normally require configuration/templates rather than dedicated management pages.

## Current status
**Lane C is idle after completing #949 — canonical `Images` is now the single normal user-facing image collection/navigation surface.**

Completed dependency/integration chain:
- #948 People profile Image migration is completed;
- #941 Image Inspector parity is completed via merged PR #1002;
- #999 changed-Dart format tooling is resolved via merged PR #1003;
- #997 `Expose generic databases in command palette` merged as `8d52f75f683851cecc8a65955bd8c509183b4a14` after Flutter CI #2983 full green;
- #1015 `Retire legacy Photo shell navigation` merged as `5f03dccc55e9333c51ce3db2a2e8d8f6f2216f0f` after Flutter CI #2989 full green;
- #949 was then re-audited on merged main and closed completed.

#1015 removed only the legacy AppShell navigation/caller surface: expanded `写真`, collapsed Photo icon, fixed ⌘K `写真`, and page-5 `PhotoManagementPage` route/import. Existing page numbers were not renumbered. The focused real-shell regression proves expanded/collapsed/⌘K no longer expose legacy Photo navigation while canonical `Images` remains navigable and opens the real `GenericDatabasePage` containing a canonical Image object.

Fresh merged-main verification of `lib/views/app_shell.dart` found zero `PhotoManagementPage` references and zero fixed `'写真'` navigation labels. Underlying Photo schema/rows/Vault files remain untouched. `PhotoManagementPage` implementation deletion is explicitly handed to Lane G #950 for a current-main caller-zero audit.

No focused open Lane C issue was found in the post-#949 audit. Do not invent speculative C work from umbrellas; resume when a concrete Database/View/schema/navigation acceptance gap is opened or discovered.

## Latest completed checkpoints
- #760 — failed Flutter Test runs retain diagnostic logs/artifacts.
- #763 (`2fdd340b…`) — searchable Relation Property target authoring/editing with explicit cardinality and canonical Lane B schema evolution.
- #776 (`0e61b0c6…`) — searchable template picker while preserving empty custom Database creation.
- #792 (`9e35afa2…`) — real generic Gallery cover source wiring; #492 closed.
- #793 (`5a19a86d…`) — explicit View Property-reference detach.
- #800 (`321fda6d…`) — delete impact can detach View references then re-inspect.
- #819 (`dfc07176…`) — real Relation picker quick-create for custom/Tag/Weblink/Image/File through canonical services; #491 closed.
- #826 (`a2fd7e13…`) — explicit clear-values fallback for incompatible Value type migration with atomic rollback.
- #832 (`83a44e0d…`) — safe Property schema-management substrate including Formula/Rollup, workspace View and secondary Collection-filter blockers.
- #845 (`a320a5b8…`) — real `GenericDatabasePage` Property schema management; #493 closed.
- #851 (`0ca36410…`) — template View Group defaults resolve template-local Property names to created canonical Property ids.
- #856 (`7e103a02…`) — generic user-owned Bookmark template and generic-operation proof; #490/#484 subsequently closed.
- #874 (`38c20b67…`) — reusable canonical `ObjectBodyEditorSection` composed into real Generic Database side peek; #481 subsequently closed.
- #908 (`12994803b043c9da54da8c3175877512119d368b`) — canonical Images seed exactly one ordinary shared Gallery View on first use with `galleryMode=masonry` and `galleryCoverSource=directImage`; any existing user View wins unchanged. Flutter CI #2750 full green; #896 closed.
- #925 (`b8646d370035940222921d49ba1812a78d056523`) — canonical Weblinks seed exactly one ordinary shared List View on first use; later user rename/layout/settings survive full host reopen without reseeding. Flutter CI #2789 full green; #920 closed.
- #997 / `8d52f75f…` — persisted generic Database destinations participate in ⌘K and route through `GenericDatabasePage`; Flutter CI #2983 full green.
- #1015 / `5f03dccc…` — legacy Photo AppShell navigation and route retired while compatibility data/code remains preserved; Flutter CI #2989 full green; #949 closed.

## Current system-collection View/navigation contract
System collection behavior remains ordinary persisted Database/View configuration, not a second presentation authority:
- canonical Images: first zero-View open -> `ギャラリー`, `layoutType=gallery`, masonry, direct Image cover;
- canonical Weblinks: first zero-View open -> `リスト`, `layoutType=list`;
- any existing persisted View is returned unchanged;
- ordinary custom ObjectTypes continue to use the Database definition/default View path;
- system identity is recognized by stable system keys, never display names;
- user-facing system collection labels come from `GenericDatabaseStore.listDatabases()` (`Images`, `Weblinks`, `Daily Notes`);
- generic Databases are reachable from expanded sidebar and ⌘K through the same selected-Database/page-11 host;
- legacy Photo has no normal AppShell navigation or page route, while compatibility data remains preserved.

Lane C does not own Image/Weblink identity, import, metadata, Relation mutation, managed-file resolution, or legacy implementation deletion.

## What #856 proves
The built-in `bookmark` starting experience is configuration, not a hard-coded domain engine:
- user-owned custom ObjectType;
- Weblink/Tag/Image/File Relations provisioned through existing primitive contracts;
- generic Rating/Status/Favorite Properties;
- generic `すべて` / `あとで読む` / `お気に入り` Views;
- visible/order/filter/Gallery-cover references resolve to stable created Property ids;
- canonical Weblink creation, Relation assignment, Property edits and View filtering work without introducing Bookmark-only persistence/presentation APIs;
- template-derived schema remains editable by the user.

Together with Paper/Plant regressions, version/ownership tests, searchable template selection, Group/Layout defaults and empty custom Database creation, this satisfies the generic composability target.

## Remaining open work and ownership
- #950 — Lane G caller-zero legacy Photo retirement. C posted merged-main caller-zero handoff evidence after #1015. G must independently re-audit production callers and require Analyze + full Test before deleting `PhotoManagementPage` or related dead presentation code. Do not delete compatibility schema/data as routine refactor.
- #245 — Photo→Image umbrella. #949 is complete; remaining work is cross-lane, especially #950 and final preservation validation #951.
- #155 — Weblink/Image product semantics and remaining convergence: Primitive/Object ownership.
- #225 — maintainability / broad host reduction / legacy code retirement: Refactor ownership.
- #242 — final real-macOS Vault lifecycle validation: Storage/manual validation.
- #56 — usage-driven umbrella; take new C work only for a concrete Database/View/schema acceptance gap.

Manual Database membership include/exclude remains explicitly deferred in #56 until real use demonstrates a need; do not invent it speculatively.

## Shared hotspot lease
**Lane C currently holds no shared-hotspot lease.**

Open PR and hotspot ownership remain time-sensitive. Re-audit live PRs before every additional edit.

Shared hotspots requiring special care include:
- `lib/views/generic_database_page.dart`
- `lib/views/app_shell.dart`
- `lib/views/object_inspector_page.dart`
- `lib/views/bookmark_unified_stage1_page.dart`
- `lib/widgets/bookmark_reorderable_properties.dart`
- `lib/views/people_management_page.dart`
- `lib/views/settings_page.dart`
- `lib/services/profile_manager.dart`
- `lib/data/app_database.dart`

## Cross-lane boundaries
- Lane B owns Relation mutation/index/backlink/audit/reconcile and integrity-sensitive Relation schema changes; C consumes canonical services.
- Lane A owns Object/ObjectType/Body/core identity and reusable opening/detail contracts; C may compose those contracts into Database/View hosts without taking over Object semantics.
- Lane D owns Weblink/Image/File/Tag primitive product semantics, canonical create/import, metadata and media behavior; C owns only generic Database/View configuration and presentation/navigation contracts.
- Lane E owns Search indexing/freshness orchestration.
- Lane F owns Vault/filesystem lifecycle and managed-byte placement/ownership boundaries.
- Lane G owns behavior-preserving refactor, hotspot reduction and caller-zero legacy implementation retirement.

## Validation
GitHub Flutter CI is authoritative because local Flutter/Dart execution is unavailable in this automation environment.

Final #949 validation checkpoint:
- PR #1015 head `f0e979de84f14ee3cb57d8356c66e8e55c15da5d`;
- Flutter CI #2989: changed-Dart format green, Analyze green, all four Flutter Test shards green, test-health green, merge-gate green;
- AI Handoff Audit and AI Migration Lease Audit green;
- squash merge `5f03dccc55e9333c51ce3db2a2e8d8f6f2216f0f`;
- merged-main AppShell audit: no `PhotoManagementPage` route/import and no fixed `'写真'` navigation label.

## Stop reason / resume triggers
Lane C is **idle because no focused open C-owned implementation issue remains after #949 completion**.

Resume sequence:
1. re-read `AGENTS.md`, `docs/AI_PROGRESS.md`, this handoff, latest main and all open PR hotspot ownership;
2. search current open issues for an explicitly C-owned Database/View/schema/navigation acceptance gap;
3. if a gap exists, take the smallest coherent reversible slice and add real-host regression coverage;
4. if only umbrellas (#56/#245) or another lane's work remain, do not invent speculative C implementation;
5. keep legacy implementation deletion with Lane G and Vault/preservation validation with Lane F.

On every resume, start from live GitHub state rather than this checkpoint alone.
