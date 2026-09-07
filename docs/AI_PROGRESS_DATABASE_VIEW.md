# AI Progress — Database, View & Schema UX Lane

> Lane C durable handoff. Always re-read `AGENTS.md`, the active GitHub Issue, `docs/AI_PROGRESS.md`, latest `main`, open PR ownership, and current CI before changing code. GitHub is the source of truth; commit SHAs below are checkpoints only.

## Lane goal
Make ObjectType / Database / View / schema configuration expressive and safe enough that new domains normally require configuration/templates rather than dedicated management pages.

## Current status
Focused #490/#491/#492/#493 work is complete, but Lane C has one concrete cross-lane presentation obligation under #481:

**Generic Database side peek must compose the existing canonical Body surface so side/center/full opening modes expose the same Object Body.**

Lane A owns Body persistence/editor semantics and the reusable `ObjectBodyEditorSection`; Lane C owns composition into the Database/View side-peek host. Do not create another Body store/editor path.

Active PR: **#874 — Compose canonical Object Body into generic Database side peek**.

After #874 merges and the real-host regression proves canonical Body persistence through side peek, re-audit #481 and current C-owned Issues. Lane C should return to idle if no new concrete Database/View/schema/template obligation remains.

## Repository coordination checkpoint — 2026-09-08
The focused composability/schema milestones are complete:
- #484/#489/#490/#491/#492/#493/#494/#495/#501 are completed/closed;
- #856 proves generic Bookmark template/operation through ordinary Object/Relation/Database/View APIs;
- exactly eight umbrella/product Issues remain open: #56/#155/#218/#225/#242/#245/#249/#481.

Current routing around Lane C:
- #481 side-peek Body host composition — **Lane C current slice (#874)**; Body semantics remain Lane A.
- #249 Bookmark presentation — **Object lane**.
- #155/#245 Weblink/Image/Photo presentation and migration — **Primitive/Object**.
- #225 maintenance/legacy retirement — **Refactor**.
- #242/#218 — final real-macOS validation.

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
- #861 (`87584453…`) — durable C-lane composability checkpoint.

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

## #481 cross-lane contract
Issue #481's current architecture split is:
- Lane A owns universal Body persistence/editor semantics and reusable Body components.
- Lane C owns generic Database/View opening-host composition.

The current C acceptance slice must:
1. render/edit the same canonical Body in side peek that center/full openings use;
2. reuse `ObjectBodyEditorSection` / `ObjectBodyStore` and existing Body edit/action/reference services;
3. preserve Object identity, Property, Relation and backlink behavior;
4. avoid another Body store/editor or flattened representation;
5. add a focused real-host side-peek regression proving persistence.

PR #874 implements this as a patch-sized `GenericDatabasePage` change.

## Remaining open work and ownership
Do not take these merely to keep Lane C busy:
- #249 Bookmark presentation parity — **Object lane**; primary remaining gap is real Stage1 fixed/masonry Gallery wiring.
- #155 Weblink/Image product presentation and legacy convergence — primarily **Primitive/Object**.
- #245 Photo -> Image migration — **Primitive/Object**; #869 List media is merged, #876 is the Table-media follow-up and #879 advances canonical Bookmark Image survival through legacy sync.
- #225 maintainability / legacy retirement / broad host extraction — **Refactor lane**.
- #242/#218 are held for final real-macOS validation.

#495 content-aware Image/File import routing, #149 Property-handle polish and #156 masonry Gallery are completed/closed; do not resurrect them from stale umbrella prose.

Manual Database membership include/exclude remains explicitly deferred in #56 until real use demonstrates a need; do not invent it speculatively.

## Shared hotspot lease
`lib/views/generic_database_page.dart` currently has two active patch-sized owners:
- #874 — Lane C side-peek Body composition;
- #876 — Lane D Table-row media composition.

Their documented hunks are separated, but every further edit must re-audit the live diffs. Avoid broad host rewrites until both clear.

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
- Lane A owns Object/ObjectType/Body/core identity and reusable Body contracts; C composes those contracts into Database/View hosts.
- Lane D owns Weblink/Image/File/Tag primitive product semantics and import/media behavior; D may compose primitive-specific presentation into generic hosts.
- Lane F owns Vault/filesystem lifecycle and managed-byte placement/ownership boundaries.
- Lane G owns behavior-preserving refactor, hotspot reduction and legacy retirement.

## Validation
GitHub Flutter CI is the validation gate because local Flutter/Dart execution is unavailable in this automation environment. Use the #760 diagnostic artifact path for Test failures rather than requesting pasted logs.

Latest completed functional Lane C checkpoint #856 passed maintainability guards, Drift generation, Flutter Analyze and the complete Flutter Test suite. #874 requires the same normal CI gate before merge.

## Exact next actions
1. Finish #874 and fix only concrete CI failures caused by that slice.
2. Merge #874 when green and re-audit #481 against its close condition.
3. Re-audit live Issues/PRs and shared hotspot ownership.
4. If no new focused Database/View/schema/template obligation exists, return Lane C to idle rather than inventing work.

## Stop reason / resume triggers
Lane C is **not idle while #874 remains active**. After #874 is integrated, idle is appropriate when no independent C-owned work remains.

Resume later when any of the following occurs:
1. a new focused Database/View/schema/template Issue is opened or explicitly assigned to C;
2. #56 gains a concrete Database/View acceptance gap not already routed elsewhere;
3. another lane lands a capability that creates a specific C-owned View/schema composition obligation;
4. ownership of #249 or another presentation slice is explicitly reassigned to C.

On every resume, start from live GitHub state rather than this checkpoint alone.
