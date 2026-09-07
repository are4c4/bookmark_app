# AI Progress — Database, View & Schema UX Lane

> Lane C durable handoff. Always re-read `AGENTS.md`, the active GitHub Issue, `docs/AI_PROGRESS.md`, latest `main`, open PR ownership, and current CI before changing code. GitHub is the source of truth; commit SHAs below are checkpoints only.

## Lane goal
Make ObjectType / Database / View / schema configuration expressive and safe enough that new domains normally require configuration/templates rather than dedicated management pages.

## Current status
**Lane C has no independent product implementation issue.**

The focused composability/schema Issues owned by this lane are complete:
- #490 — completed/closed after generic Bookmark template proof.
- #491 — completed/closed after Relation Property authoring and real target quick-create/import composition.
- #492 — completed/closed after configurable Relation-backed Gallery cover reached the real generic Database host.
- #493 — completed/closed after safe migration/delete UX and real-host Property schema management.
- #484 umbrella — completed/closed after primitive-vs-domain boundary plus Bookmark composability proof.

#56 remains open as the broader product umbrella, but its remaining concrete implementation is currently routed outside Lane C or requires real-host validation rather than speculative Database/View work.

## Current coordination checkpoint — 2026-09-08
A fresh GitHub audit found one safe Lane C coordination task even though no product slice was available: repository-wide `docs/AI_PROGRESS.md` had become stale and still listed #484/#490/#491/#492/#493 as active while telling Lane C to continue completed work.

PR #873 — `Refresh repository-wide routing after composability completion`
Branch: `docs/database-view-repo-handoff-refresh-20260908`
Live head changes during the docs refresh; always read current PR head/CI before acting.

The PR is docs-only and refreshes repository-wide routing so future lanes do not re-enter completed work. It records:
- #484/#490/#491/#492/#493/#494 as completed/closed;
- #856 as the generic Bookmark template/operation proof;
- Lane C as intentionally idle until a concrete Database/View/schema/template gap appears;
- #481/#249 as Object-owned, #155/#245/#495 as Primitive/Object, #225 as Refactor, #242/#218 as real-macOS validation;
- the remaining product edge as presentation/migration/consolidation rather than generic schema composability.

Recent Primitive host work (#862 File collection import and #869 canonical List media) is already merged; it remains evidence that primitive-specific composition in generic hosts belongs to D, not a current C hotspot lease.

No runtime behavior changes are included.

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
- #861 (`87584453…`) — durable C-lane idle handoff after composability completion; full Flutter Analyze/Test green.

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

Recent Primitive work has touched `GenericDatabasePage` in patch-sized primitive-specific composition. It is merged at this checkpoint, but future C changes must still re-audit open PR files before touching the host.

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

Latest functional Lane C checkpoint #856 passed maintainability guards, Drift generation, Flutter Analyze and the complete Flutter Test suite before merge. #861 was docs-only and also passed full Flutter Analyze/Test before merge.

## Exact next actions
1. Read live PR #873 head and Flutter CI after the latest handoff commit.
2. If red, fix only the concrete documentation/guard failure; if green, re-check main/open PR overlap and squash-merge #873.
3. Re-audit open Issues/PRs once more after #873 merge.
4. If no new focused Database/View/schema/template obligation exists, stop under the AGENTS idle criterion instead of inventing product work.

## Stop reason / resume triggers
After #873 is merged, the expected stop reason remains: **the active lane has no remaining independent actionable product work**.

Resume Lane C when any of the following occurs:
1. a new focused Database/View/schema/template Issue is opened or explicitly assigned to C;
2. #56 gains a concrete Database/View acceptance gap not already routed elsewhere;
3. another lane lands a new capability that creates a specific C-owned View/schema composition obligation;
4. ownership of #249 or another presentation slice is explicitly reassigned to C.

On resume, start from live GitHub state; do not assume this checkpoint is still current.
