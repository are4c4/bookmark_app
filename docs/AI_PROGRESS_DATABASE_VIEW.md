# AI Progress — Database, View & Schema UX Lane

> Lane C durable handoff. Always re-read `AGENTS.md`, the active GitHub Issue, `docs/AI_PROGRESS.md`, latest `main`, open PR ownership, and current CI before changing code. GitHub is the source of truth; commit SHAs below are checkpoints only.

## Lane goal
Make ObjectType / Database / View / schema configuration expressive and safe enough that new domains normally require configuration/templates rather than dedicated management pages.

## Current status
**Lane C currently has no independent actionable implementation issue.**

The latest concrete C-owned follow-up, #896, is completed/closed through #908. Canonical Images now receive a useful first-run Gallery View through the ordinary shared Database/View model, while existing user Views remain authoritative and are never reset on revisit.

The focused composability/schema work is complete:
- #484 — primitive-vs-user-owned-domain architecture — completed/closed.
- #490 — user-owned ObjectType/Database/View templates — completed/closed.
- #491 — Relation Property authoring + real target quick-create/import composition — completed/closed.
- #492 — configurable Relation-backed Gallery cover in the real generic Database host — completed/closed.
- #493 — safe/reversible schema evolution + real-host Property management — completed/closed.
- #481 — universal Object Body — completed/closed after the final Lane C side-peek composition merged in #874.
- #896 — canonical Images first-use default Gallery View — completed/closed via #908.

#56 remains the broader product umbrella, but a fresh post-#908 audit found no current acceptance gap independently owned by Lane C. Idle is intentional; do not invent speculative Database/View abstractions merely to keep the lane busy.

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
- #908 (`12994803…`) — canonical Images seed their first persisted View as shared `gallery + masonry + directImage` configuration, while any existing user View wins unchanged. A real `GenericDatabasePage` regression proves first-use Gallery rendering and full host reopen after user customization without reseeding; #896 closed. Flutter CI #2750 passed in full.

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

## #896 completion contract
#896 was a focused daily-use follow-up created by the Photo -> Image migration. Lane C owned only generic View provisioning/persistence; Image identity/import/media resolution remained Primitive-owned.

#908 completed it by:
- adding `DatabaseViewDefaultProvisioningService` as the first-View seeding boundary;
- identifying canonical Images by stable `ImageObjectService.systemKey`, never display-name heuristics;
- seeding only a genuinely zero-View Images collection;
- expressing the initial experience only through ordinary `DatabaseViewConfig` settings: `layoutType = gallery`, `galleryMode = masonry`, `galleryCoverSource = directImage`;
- preserving every existing View unchanged, including user rename/layout/settings;
- keeping ordinary ObjectTypes on the existing Database definition default path;
- changing only the existing default-View call in canonical `DatabaseViewTabs`, leaving duplicate/create/rename/reorder/delete/open-mode controls generic and unchanged;
- adding focused service regressions plus a real `GenericDatabasePage` first-load/dispose/reopen regression.

No Image import, MIME/content routing, file ownership, Relation mutation or legacy Photo persistence behavior changed. #908 head `546480ae…` passed Flutter CI #2750 in full before squash merge `12994803…`; #896 then closed as completed.

## #481 completion contract
#481 deliberately split ownership across lanes:
- Lane A owned universal Body persistence/editor semantics and the reusable `ObjectBodyEditorSection` seam.
- Lane C owned generic Database/View side-peek composition.

#874 completed the final cross-lane blocker by:
- composing `ObjectBodyEditorSection` into `GenericDatabasePage` side peek;
- preserving existing title/Property/Relation/backlink/detail chrome;
- reusing the canonical Object Body store/edit/action/reference services;
- routing Body Object references through the existing Object opening path;
- adding a real-host regression proving side-peek edits persist to the same canonical Object Body.

#874 head `cd57873b…` passed Flutter CI #2668 in full before squash merge `38c20b67…`. #481 was then audited and closed as completed.

## Remaining open work and ownership
Do not take these merely to keep Lane C busy:
- #155 Weblink/Image product presentation and legacy convergence — primarily **Primitive/Object**.
- #245 Photo -> Image migration — primarily **Primitive/Object**; #908 provides the C-owned first-use Images View portion, while remaining migration/read/write/legacy retirement work stays outside C unless a new focused generic View obligation is opened.
- #895 Bookmark Image Relation integrity — **Relations & Data Integrity**.
- #910 Daily Note Date identity protection — **Object Core & Body**.
- #225 maintainability / legacy retirement / broad host extraction — **Refactor**.
- #242/#218 — final real-macOS validation rather than Lane C implementation.

#249/#481/#484/#489/#490/#491/#492/#493/#494/#495/#501/#877/#888/#896 are completed/closed; do not resurrect them from stale umbrella prose.

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
- `lib/services/profile_manager.dart`
- `lib/data/app_database.dart`

Patch-sized changes in a shared host still require a live diff-overlap audit even when they belong to different lanes.

## Cross-lane boundaries
- Lane B owns Relation mutation/index/backlink/audit/reconcile and fail-closed read correctness; C consumes canonical services.
- Lane A owns Object/ObjectType/Body/core identity, Daily Note identity and reusable Body contracts; C consumes shared edit/opening contracts rather than adding type-name checks.
- Lane D owns Weblink/Image/File/Tag primitive product semantics and import/media behavior; C owns only generic View/configuration behavior such as #908's initial Images View.
- Lane E owns Search indexing/freshness orchestration.
- Lane F owns Vault/filesystem lifecycle and managed-byte placement/ownership boundaries.
- Lane G owns behavior-preserving refactor, hotspot reduction and legacy retirement.

## Validation
GitHub Flutter CI is the validation gate because local Flutter/Dart execution is unavailable in this automation environment. Use the #760 diagnostic artifact path for Test failures rather than requesting pasted logs.

Latest functional Lane C checkpoint #908 head `546480ae…` passed maintainability guards, Drift generation, Flutter Analyze and the complete Flutter Test suite in CI #2750 before squash merge `12994803…`.

## Stop reason / resume triggers
Current stop reason matches the AGENTS stopping criteria: **Lane C has no remaining independent actionable work after #896 completion.** Idle is preferable to speculative abstractions or taking another lane's ownership.

Resume Lane C when any of the following occurs:
1. a new focused Database/View/schema/template Issue is opened or explicitly assigned to C;
2. #56 gains a concrete Database/View acceptance gap not already routed elsewhere;
3. another lane lands a capability that creates a specific C-owned View/schema composition obligation;
4. ownership of another generic presentation slice is explicitly reassigned to C.

On every resume, start from live GitHub state rather than this checkpoint alone.
