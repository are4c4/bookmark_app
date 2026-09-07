# AI Progress — Database, View & Schema UX Lane

> Lane C durable handoff. Always re-read `AGENTS.md`, the active GitHub Issue, `docs/AI_PROGRESS.md`, latest `main`, open PR ownership, and current CI before changing code. GitHub is the source of truth; commit SHAs below are checkpoints only.

## Lane goal
Make ObjectType / Database / View / schema configuration expressive and safe enough that new domains normally require configuration/templates rather than dedicated management pages.

## Current status
**Lane C currently has no independent actionable implementation issue.**

The focused composability/schema Issues owned by this lane are complete:
- #490 — completed/closed after generic Bookmark template proof.
- #491 — completed/closed after Relation Property authoring and real target quick-create/import composition.
- #492 — completed/closed after configurable Relation-backed Gallery cover reached the real generic Database host.
- #493 — completed/closed after safe migration/delete UX and real-host Property schema management.
- #484 umbrella — completed/closed after primitive-vs-domain boundary plus Bookmark composability proof.

#56 remains open as the broader product umbrella, but its remaining concrete work is currently routed outside Lane C or requires real-host validation rather than speculative Database/View implementation.

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
- #856 (`7e103a02…`) — generic user-owned Bookmark template and generic-operation proof; full Flutter Analyze/Test green; #490 and #484 subsequently closed.

## What #856 proves
The built-in `bookmark` starting experience is configuration, not a hard-coded domain engine:
- user-owned custom ObjectType;
- Weblink/Tag/Image/File Relations provisioned through existing primitive contracts;
- generic Rating/Status/Favorite Properties;
- generic `すべて` / `あとで読む` / `お気に入り` Views;
- visible/order/filter/Gallery-cover references resolve to stable created Property ids;
- canonical Weblink creation, Relation assignment, Property edits and View filtering work without introducing Bookmark-only persistence/presentation APIs;
- template-derived schema remains editable by the user.

Together with Paper/Plant regressions, version/ownership tests, searchable template selection, Group/Layout defaults and empty custom Database creation, this satisfies the Lane C composability target.

## Remaining open work and ownership
Do not take these merely to keep Lane C busy:
- #249 Bookmark Gallery/List presentation parity — **Object lane**.
- #481 universal Body — **Object lane**.
- #495 content-aware Image/File import routing — **Primitive lane**.
- #155 Weblink/Image product presentation and legacy convergence — primarily **Primitive/Object** according to current routing.
- #245 Photo -> Image migration — **Primitive/Object**, with Refactor cleanup after parity.
- #225 maintainability / legacy retirement / broad host extraction — **Refactor lane**.
- #149 final Property-handle close step — requires real-host visual validation on the user machine/theme.
- #156 is already completed/closed; do not reopen based on stale prose in #56.
- #242/#218 are held for real-macOS validation, not Lane C implementation.

Manual Database membership include/exclude remains explicitly deferred in #56 until real use demonstrates a need; do not invent it speculatively.

## Shared hotspot lease
Lane C currently holds **no shared-hotspot lease**.

Before future C work, re-audit open PRs for:
- `lib/views/generic_database_page.dart`
- `lib/views/app_shell.dart`
- `lib/views/object_inspector_page.dart`
- `lib/views/bookmark_unified_stage1_page.dart`
- `lib/widgets/bookmark_reorderable_properties.dart`
- `lib/views/people_management_page.dart`
- `lib/views/settings_page.dart`
- `lib/services/profile_manager.dart` / equivalent profile host
- `lib/data/app_database.dart`

## Cross-lane boundaries
- Lane B owns Relation mutation/index/backlink/audit/reconcile and destructive target/cardinality correctness; C consumes canonical services.
- Lane A owns Object/ObjectType/Body/core identity and Object-owned presentation work.
- Lane D owns Weblink/Image/File/Tag primitive product semantics and import/media behavior.
- Lane F owns Vault/filesystem lifecycle and managed-byte placement/ownership boundaries.
- Lane G owns behavior-preserving refactor, hotspot reduction and legacy retirement.

## Validation
GitHub Flutter CI is the validation gate because local Flutter/Dart execution is unavailable in this automation environment. Use the #760 diagnostic artifact path for Test failures rather than requesting pasted logs.

Latest functional Lane C checkpoint #856 passed maintainability guards, Drift generation, Flutter Analyze and the complete Flutter Test suite before merge.

## Stop reason / resume triggers
Current stop reason matches the AGENTS stopping criteria: **the active lane has no remaining independent actionable work**. Idle is preferable to inventing speculative abstractions or taking another lane's ownership.

Resume Lane C when any of the following occurs:
1. a new focused Database/View/schema/template Issue is opened or explicitly assigned to C;
2. #56 gains a concrete Database/View acceptance gap not already routed elsewhere;
3. another lane lands a new capability that creates a specific C-owned View/schema composition obligation;
4. ownership of #249 or another presentation slice is explicitly reassigned to C.

On resume, start from live GitHub state; do not assume this idle checkpoint is still current.
