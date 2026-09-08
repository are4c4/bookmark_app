# AI Progress — Database, View & Schema UX Lane

> Lane C durable handoff. Always re-read `AGENTS.md`, the active GitHub Issue, `docs/AI_PROGRESS.md`, latest `main`, open PR ownership, and current CI before changing code. GitHub is the source of truth; commit SHAs below are checkpoints only.

## Lane goal
Make ObjectType / Database / View / schema configuration expressive and safe enough that new domains normally require configuration/templates rather than dedicated management pages.

## Current status
**Lane C is active on #949 — make canonical Images the single normal user-facing image collection/navigation surface.**

The dependency gates are resolved:
- #948 People profile Image migration is completed;
- #941 Image Inspector parity is completed via merged PR #1002;
- #999 changed-Dart format tooling is resolved via merged PR #1003.

Current #949 integration sequence:
1. PR #997 `Expose generic databases in command palette` is merged as `8d52f75f683851cecc8a65955bd8c509183b4a14` after Flutter CI #2983 full green. It makes persisted generic Databases, including canonical `Images`, reachable from ⌘K through the ordinary `GenericDatabasePage` host.
2. Draft PR #1015 `Retire legacy Photo shell navigation` is the final C navigation-retirement slice. Branch: `feature/database-view-retire-photo-navigation-949`, based on main `8d52f75f…`.
3. #1015 removes only the legacy AppShell navigation/caller surface: expanded `写真`, collapsed Photo icon, fixed ⌘K `写真`, and page-5 `PhotoManagementPage` route/import. Existing page numbers are not renumbered.
4. The focused real-shell regression proves expanded/collapsed/⌘K no longer expose legacy Photo navigation while canonical `Images` remains navigable and opens the real `GenericDatabasePage` containing a canonical Image object.
5. Underlying Photo schema/rows/Vault files remain untouched. `PhotoManagementPage` implementation deletion is explicitly left to Lane G #950 after caller-zero re-audit.

Latest #1015 commits:
- `612a7c04…` — retire legacy Photo shell navigation;
- `8d5abc83…` — extend real-shell Images-only navigation regression;
- `bec45efb…` / `2fcdbcf7…` — restore final newlines after connector file replacement; no semantic change.

Current authoritative CI for #1015 head `2fcdbcf7bd2b23dfaaa42c3e3ff10231d604e92e` is Flutter CI #2987. AI Handoff Audit and AI Migration Lease Audit are already green; Flutter CI is pending/in progress at this checkpoint.

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

## Current system-collection View/navigation contract
System collection behavior remains ordinary persisted Database/View configuration, not a second presentation authority:
- canonical Images: first zero-View open -> `ギャラリー`, `layoutType=gallery`, masonry, direct Image cover;
- canonical Weblinks: first zero-View open -> `リスト`, `layoutType=list`;
- any existing persisted View is returned unchanged;
- ordinary custom ObjectTypes continue to use the Database definition/default View path;
- system identity is recognized by stable system keys, never display names;
- user-facing system collection labels come from `GenericDatabaseStore.listDatabases()` (`Images`, `Weblinks`, `Daily Notes`);
- generic Databases are reachable from expanded sidebar and ⌘K through the same selected-Database/page-11 host;
- after #1015 integrates, legacy Photo has no normal AppShell navigation or page route, while compatibility data remains preserved.

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
- #949 — **current Lane C issue**. Close only after #1015 is merged/full-green and live AppShell navigation proves canonical Images is the sole normal image collection destination.
- #950 — Lane G caller-zero legacy Photo retirement. After #1015 merges, re-audit and remove `PhotoManagementPage`/other dead presentation code only if production callers are zero. Do not delete compatibility schema/data as routine refactor.
- #155 — Weblink/Image product semantics and remaining convergence: Primitive/Object ownership.
- #225 — maintainability / broad host reduction / legacy code retirement: Refactor ownership.
- #242 — final real-macOS Vault lifecycle validation: Storage/manual validation.
- #56 — usage-driven umbrella; take new C work only for a concrete Database/View/schema acceptance gap.

Manual Database membership include/exclude remains explicitly deferred in #56 until real use demonstrates a need; do not invent it speculatively.

## Shared hotspot lease
While PR #1015 is open, Lane C holds a **patch-sized lease on `lib/views/app_shell.dart` limited to the legacy Photo navigation removals above**.

The live #1015 production diff is intentionally tiny: remove the `PhotoManagementPage` import/route plus the expanded, collapsed and ⌘K legacy destinations. No broad formatting or unrelated shell restructuring is permitted in this slice.

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

For #1015 require before merge:
- changed-Dart format green;
- Analyze green;
- all Flutter Test shards green, including `test/app_shell_generic_database_command_palette_test.dart`;
- test-health / coordination audits green;
- current-main overlap audit still shows no competing `app_shell.dart` owner.

## Stop reason / resume triggers
Current work is **not stopped** while #1015 CI/integration remains actionable.

Immediate resume sequence:
1. inspect Flutter CI #2987 for head `2fcdbcf7…`;
2. if CI fails, fix only a demonstrated C-owned regression and rerun on current main;
3. if full green, re-check latest main/open `app_shell.dart` ownership, mark #1015 ready and squash merge;
4. comment #950 with caller-zero handoff evidence;
5. close #949 only after merged-main re-audit confirms no normal legacy `写真` AppShell destination remains;
6. update this handoff to Lane C idle unless another focused C issue exists.

On every resume, start from live GitHub state rather than this checkpoint alone.
