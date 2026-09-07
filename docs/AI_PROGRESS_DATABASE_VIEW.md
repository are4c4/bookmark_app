# AI Progress — Database, View & Schema UX Lane

> Lane C durable handoff. Always re-read `AGENTS.md`, the active GitHub Issue, `docs/AI_PROGRESS.md`, latest `main`, open PR ownership, and current CI before changing code. GitHub is the source of truth; commit SHAs below are checkpoints only.

## Lane goal
Make ObjectType / Database / View / schema configuration expressive and safe enough that new domains normally require configuration/templates rather than dedicated management pages.

## Current status
**Lane C currently has no independent actionable product implementation issue.**

The focused composability/schema Issues owned by this lane are complete:
- #490 — completed/closed after generic Bookmark template proof.
- #491 — completed/closed after Relation Property authoring and real target quick-create/import composition.
- #492 — completed/closed after configurable Relation-backed Gallery cover reached the real generic Database host.
- #493 — completed/closed after safe migration/delete UX and real-host Property schema management.
- #484 umbrella — completed/closed after primitive-vs-domain boundary plus Bookmark composability proof.

#56 remains open as the broader product umbrella, but its remaining concrete implementation is routed to other active owners or requires real-host validation rather than speculative Database/View work.

## Current coordination checkpoint — 2026-09-08
Repository-wide routing is being refreshed because `docs/AI_PROGRESS.md` had become stale after the composability milestone set completed.

Current live routing:
- #484/#489/#490/#491/#492/#493/#494/#495/#501 are completed/closed;
- exactly eight umbrella/product Issues remain open: #56/#155/#218/#225/#242/#245/#249/#481;
- Lane C is intentionally idle until a concrete Database/View/schema/template obligation appears;
- #481 side-peek Body parity is **Object/Lane A-owned** through active PR #874 even though the patch composes into `GenericDatabasePage`;
- #249 remaining Bookmark presentation is Object-owned;
- #155/#245 are Primitive/Object migration/presentation work;
- #225 is Refactor-owned;
- #242/#218 await final real-macOS validation.

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
- #861 (`87584453…`) — durable C-lane idle handoff after composability completion.

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
- #481 universal Body / side-peek parity — **Object/Lane A**; active PR #874 composes the canonical `ObjectBodyEditorSection` into generic side peek.
- #249 Bookmark presentation parity — **Object lane**; the primary remaining gap is real Stage1 fixed/masonry Gallery wiring.
- #155 Weblink/Image product presentation and legacy convergence — primarily **Primitive/Object**.
- #245 Photo -> Image migration — **Primitive/Object**; #869 List media is merged and active PR #876 owns the Table-media follow-up.
- #225 maintainability / legacy retirement / broad host extraction — **Refactor lane**.
- #242/#218 are held for final real-macOS validation, not Lane C implementation.

#495 content-aware Image/File import routing, #149 Property-handle polish and #156 masonry Gallery are completed/closed; do not resurrect them from stale umbrella prose.

Manual Database membership include/exclude remains explicitly deferred in #56 until real use demonstrates a need; do not invent it speculatively.

## Shared hotspot lease
Lane C currently holds **no shared-hotspot lease**.

`lib/views/generic_database_page.dart` is currently touched by active patch-sized PRs from other lanes:
- #874 — Object/Lane A side-peek Body composition;
- #876 — Primitive/Lane D Table-row media composition.

Future C work must re-audit live changed files before touching that host. Do not claim ownership merely because the file is a Database presentation host.

Also re-audit:
- `lib/views/app_shell.dart`
- `lib/views/object_inspector_page.dart`
- `lib/views/bookmark_unified_stage1_page.dart`
- `lib/widgets/bookmark_reorderable_properties.dart`
- `lib/views/people_management_page.dart`
- `lib/views/settings_page.dart`
- `lib/services/profile_manager.dart`
- `lib/data/app_database.dart`

## Cross-lane boundaries
- Lane B owns Relation mutation/index/backlink/audit/reconcile and fail-closed read correctness; C consumes canonical services.
- Lane A owns Object/ObjectType/Body/core identity and Object-owned opening/detail parity. A patch may compose a reusable Object seam into a Database host without becoming Lane C work.
- Lane D owns Weblink/Image/File/Tag primitive product semantics and import/media behavior. A patch may compose primitive media into a Database host without becoming Lane C work.
- Lane F owns Vault/filesystem lifecycle and managed-byte placement/ownership boundaries.
- Lane G owns behavior-preserving refactor, hotspot reduction and legacy retirement.

## Validation
GitHub Flutter CI is the validation gate because local Flutter/Dart execution is unavailable in this automation environment. Use the #760 diagnostic artifact path for Test failures rather than requesting pasted logs.

Latest functional Lane C checkpoint #856 passed maintainability guards, Drift generation, Flutter Analyze and the complete Flutter Test suite before merge. #861 was docs-only and also passed full Flutter Analyze/Test before merge.

## Stop reason / resume triggers
Current stop reason matches the AGENTS stopping criteria: **the active lane has no remaining independent actionable product work**. Idle is preferable to inventing speculative abstractions or taking another lane's ownership.

Resume Lane C when any of the following occurs:
1. a new focused Database/View/schema/template Issue is opened or explicitly assigned to C;
2. #56 gains a concrete Database/View acceptance gap not already routed elsewhere;
3. another lane lands a new capability that creates a specific C-owned View/schema composition obligation;
4. ownership of #249 or another presentation slice is explicitly reassigned to C.

On resume, start from live GitHub state; do not assume this idle checkpoint is still current.
