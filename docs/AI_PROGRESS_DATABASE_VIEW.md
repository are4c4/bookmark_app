# AI Progress — Database, View & Schema UX Lane

> Lane C durable handoff. Always re-read `AGENTS.md`, the active GitHub Issue, `docs/AI_PROGRESS.md`, latest `main`, open PR ownership, and current CI before changing code. GitHub is the source of truth; commit SHAs below are checkpoints only.

## Lane goal
Make ObjectType / Database / View / schema configuration expressive and safe enough that new domains normally require configuration/templates rather than dedicated management pages.

## Current status
Focused #490/#491/#492/#493 work is complete, but Lane C has one concrete cross-lane presentation obligation under #481:

**Generic Database side peek must compose the existing canonical Body surface so side/center/full opening modes expose the same Object Body.**

Lane A owns the Body persistence/editor contract and has already provided the reusable `ObjectBodyEditorSection`; Lane C owns composition into the Database/View side-peek host. Do not create another Body store/editor path.

## Coordination checkpoint — 2026-09-08
PR #873 refreshes repository-wide routing because `docs/AI_PROGRESS.md` had become stale after the composability milestone set completed.

The docs refresh records:
- #484/#489/#490/#491/#492/#493/#494/#495/#501 as completed/closed;
- #856 as the generic Bookmark template/operation proof;
- exactly eight current open umbrella/product Issues: #56/#155/#218/#225/#242/#245/#249/#481;
- #481 generic Database side-peek Body composition as the current Lane C slice;
- #249 remaining Bookmark presentation as Object-owned;
- #155/#245 as Primitive/Object migration/presentation work, #225 as Refactor, and #242/#218 as final real-macOS validation;
- the remaining product edge as presentation/migration/consolidation rather than missing generic schema composition.

Recent Primitive host work (#862 File collection import, #866 content-aware Image picker, #869 canonical List media) is already merged; #495 is completed/closed. No Primitive PR currently owns `GenericDatabasePage` at this checkpoint, but re-audit live PR files immediately before editing it.

PR #873 itself is docs-only; the #481 implementation belongs in a separate feature PR from latest main.

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
- #861 (`87584453…`) — durable C-lane composability handoff; full Flutter Analyze/Test green.

## #481 cross-lane contract
Issue #481's latest Object-lane audits establish:
- shared `ObjectInspectorPage` Body editing is universal for Weblink/Image/custom/Daily Note;
- Bookmark real detail has a canonical Body composition path;
- center peek and full-page generic Database openings already use `ObjectInspectorPage`;
- generic Database side peek remains an alternate `_detail(...)` surface with title/Properties/backlinks but no Body;
- `ObjectBodyEditorSection` is the reusable, non-Bookmark-specific canonical Body composition seam backed by `ObjectBodyStore` and existing Body edit/action/reference services;
- Lane C should compose that seam into side peek, while Lane A should not broaden into Database/View presentation.

Acceptance for the C slice:
1. side peek renders/edits the same canonical Body as center/full;
2. custom and system Object identity semantics remain unchanged;
3. no second Body store/editor or flattened Body representation is introduced;
4. side-peek Property/backlink behavior remains intact;
5. focused real-host regression proves Body visibility/edit persistence through side peek.

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
- #481 generic Database side-peek Body composition — **Lane C current slice**, using Lane A's canonical Body seam.
- #249 Bookmark presentation parity — **Object lane**; primary remaining gap is real Stage1 fixed/masonry Gallery wiring.
- #155 Weblink/Image product presentation and legacy convergence — primarily **Primitive/Object**.
- #245 Photo -> Image migration — **Primitive/Object**, with Refactor cleanup after parity.
- #225 maintainability / legacy retirement / broad host extraction — **Refactor lane**.
- #242/#218 are held for final real-macOS validation, not Lane C implementation.

#495 content-aware Image/File import routing, #149 Property-handle polish and #156 masonry Gallery are completed/closed; do not resurrect them from stale umbrella prose.

Manual Database membership include/exclude remains explicitly deferred in #56 until real use demonstrates a need; do not invent it speculatively.

## Shared hotspot lease
Before #481 implementation, re-audit current open PRs. The intended production host is:
- `lib/views/generic_database_page.dart`

Also re-audit:
- `lib/views/app_shell.dart`
- `lib/views/object_inspector_page.dart`
- `lib/views/bookmark_unified_stage1_page.dart`
- `lib/widgets/bookmark_reorderable_properties.dart`
- `lib/views/people_management_page.dart`
- `lib/views/settings_page.dart`
- `lib/services/profile_manager.dart`
- `lib/data/app_database.dart`

Use a patch-sized host change. Do not rewrite the large page or absorb Body internals into it.

## Cross-lane boundaries
- Lane B owns Relation mutation/index/backlink/audit/reconcile and fail-closed read correctness; C consumes canonical services.
- Lane A owns Object/ObjectType/Body/core identity and the reusable Body contract; C may compose the shared Body seam into Database/View hosts.
- Lane D owns Weblink/Image/File/Tag primitive product semantics and import/media behavior.
- Lane F owns Vault/filesystem lifecycle and managed-byte placement/ownership boundaries.
- Lane G owns behavior-preserving refactor, hotspot reduction and legacy retirement.

## Validation
GitHub Flutter CI is the validation gate because local Flutter/Dart execution is unavailable in this automation environment. Use the #760 diagnostic artifact path for Test failures rather than requesting pasted logs.

Latest functional Lane C checkpoint #856 passed maintainability guards, Drift generation, Flutter Analyze and the complete Flutter Test suite before merge. #861 was docs-only and also passed full Flutter Analyze/Test before merge.

## Exact next actions
1. Finish PR #873 routing refresh and merge it when the latest head is full CI green.
2. Re-audit live open PR changed files for `generic_database_page.dart`.
3. Start a fresh #481 Lane C branch from latest main.
4. Inspect current `GenericDatabasePage._detail(...)`, `ObjectBodyEditorSection`, and existing side/center/full opening regressions.
5. Compose the canonical Body section into generic side peek with a patch-sized host change and add real-host side-peek Body persistence coverage.
6. Run full Flutter CI, fix exact failures, merge when green, then update #481/C handoff.

## Stop reason / resume triggers
Lane C is **not idle** while the #481 side-peek composition remains open. After that slice is merged, re-audit live Issues/PRs; idle is appropriate only if no new Database/View/schema/template or explicitly assigned cross-lane composition obligation remains.

On every resume, start from live GitHub state rather than this checkpoint alone.
