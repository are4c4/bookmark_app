# AI Progress — Database, View & Schema UX Lane

> Lane C durable handoff. Always re-read `AGENTS.md`, the active GitHub Issue, `docs/AI_PROGRESS.md`, latest `main`, open PR ownership, and current CI before changing code. GitHub is the source of truth; commit SHAs below are checkpoints only.

## Lane goal
Make ObjectType / Database / View / schema configuration expressive and safe enough that new domains normally require configuration/templates rather than dedicated management pages.

## Current status
**Lane C currently has no independent actionable implementation issue.**

The most recent C-owned product gaps are complete:
- #896 — canonical Images first-run shared Gallery provisioning — completed/closed via PR #908.
- #920 — canonical Weblinks first-run shared List provisioning — completed/closed via PR #925.

The broader composability/schema work is also complete for the current scope:
- #484 — primitive-vs-user-owned-domain architecture.
- #490 — user-owned ObjectType/Database/View templates.
- #491 — Relation Property authoring + real target quick-create/import composition.
- #492 — configurable Relation-backed Gallery cover in the real generic Database host.
- #493 — safe/reversible schema evolution + real-host Property management.
- #481 — universal Object Body, including Lane C side-peek composition.

#56 remains the broader product umbrella, but the live Issue audit after #925 shows no open focused Issue independently owned by Lane C. Idle is intentional; do not invent speculative Database/View abstractions merely to keep the lane busy.

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
- #925 (`b8646d370035940222921d49ba1812a78d056523`) — canonical Weblinks seed exactly one ordinary shared List View on first use; later user rename/layout/settings survive full host reopen without reseeding. Real `GenericDatabasePage` coverage uses the existing `SystemObjectListMedia` renderer. Flutter CI #2789 full green; #920 closed.

## Current system-collection View contract
System collection first-use behavior remains normal persisted View configuration, not a second presentation authority:
- canonical Images: first zero-View open -> `ギャラリー`, `layoutType=gallery`, masonry, direct Image cover;
- canonical Weblinks: first zero-View open -> `リスト`, `layoutType=list`;
- any existing persisted View is returned unchanged for either system collection;
- ordinary custom ObjectTypes continue to use the Database definition/default View path;
- system identity is recognized by stable system keys, never display names;
- Lane C does not own Image/Weblink identity, import, metadata, Relation mutation, or media-resolution semantics.

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
Repository Issue state is time-sensitive. Re-audit live Issues on resume; the durable architecture umbrellas relevant to Lane C remain #56, #155, #225, #242 and #245, none of which is a focused Lane C implementation assignment by itself.

Do not take these merely to keep Lane C busy:
- #155 Weblink/Image product presentation and legacy convergence — primarily Primitive/Object ownership. Lane C already delivered the current default Weblinks View in #920.
- #245 Photo -> Image migration — Primitive/Object ownership; Lane C already delivered canonical Images default Gallery provisioning in #896.
- #225 maintainability / legacy retirement / broad host extraction — Refactor lane.
- #242 final real-macOS Vault lifecycle validation — Storage lane / real-machine validation.
- #56 usage-driven umbrella — create or take a C slice only after a concrete Database/View/schema acceptance gap is identified.

Completed issues such as #249, #877, #895, #896, #897, #907, #909, #920 and #218 must not be resurrected from stale handoff text or older umbrella prose.

Manual Database membership include/exclude remains explicitly deferred in #56 until real use demonstrates a need; do not invent it speculatively.

## Shared hotspot lease
Lane C currently holds **no shared-hotspot lease**.

Open PR and hotspot ownership are time-sensitive and are intentionally not frozen as durable handoff state. Re-audit live PR diffs immediately before any future edit.

Before future C work, re-audit open PRs for:
- `lib/views/generic_database_page.dart`
- `lib/views/app_shell.dart`
- `lib/views/object_inspector_page.dart`
- `lib/views/bookmark_unified_stage1_page.dart`
- `lib/widgets/bookmark_reorderable_properties.dart`
- `lib/views/people_management_page.dart`
- `lib/views/settings_page.dart`
- `lib/services/profile_manager.dart`
- `lib/data/app_database.dart`

Patch-sized changes in a shared host still require a live diff-overlap audit even when they belong to different lanes.

## Cross-lane boundaries
- Lane B owns Relation mutation/index/backlink/audit/reconcile and integrity-sensitive Relation schema changes; C consumes canonical services.
- Lane A owns Object/ObjectType/Body/core identity and reusable opening/detail contracts; C may compose those contracts into Database/View hosts without taking over Object semantics.
- Lane D owns Weblink/Image/File/Tag primitive product semantics, canonical create/import, metadata and media behavior; C owns only generic Database/View configuration and presentation contracts.
- Lane E owns Search indexing/freshness orchestration.
- Lane F owns Vault/filesystem lifecycle and managed-byte placement/ownership boundaries.
- Lane G owns behavior-preserving refactor, hotspot reduction and legacy retirement.

## Validation
GitHub Flutter CI is the validation gate because local Flutter/Dart execution is unavailable in this automation environment. Use the #760 diagnostic artifact path for Test failures rather than requesting pasted logs.

Latest functional Lane C checkpoint #925 passed maintainability guards, Drift generation, Flutter Analyze and the complete Flutter Test suite in CI #2789 before squash merge `b8646d37…`.

## Stop reason / resume triggers
Current stop reason matches the AGENTS stopping criteria: **Lane C has no remaining independent actionable work.** Idle is preferable to speculative abstractions or taking another lane's ownership.

Resume Lane C when any of the following occurs:
1. a new focused Database/View/schema/template Issue is opened or explicitly assigned to C;
2. #56 gains a concrete Database/View acceptance gap not already routed elsewhere;
3. another lane lands a capability that creates a specific C-owned View/schema composition obligation;
4. ownership of another presentation slice is explicitly assigned to C.

On every resume, start from live GitHub state rather than this checkpoint alone.
