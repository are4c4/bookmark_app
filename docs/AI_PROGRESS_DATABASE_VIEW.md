# AI Progress — Database, View & Schema UX Lane

> Lane C handoff. Always re-read `AGENTS.md`, the active Issue, `docs/AI_PROGRESS.md`, latest `main`, open PR ownership, and current CI before implementation. Do not treat commit SHAs in this handoff as fresher than GitHub.

## Lane goal
Make generic ObjectType/Database/View configuration expressive enough that new domains are created by configuration/templates rather than new management pages.

## Primary active work
- #490 — user-owned templates and generic domain instantiation. Current validation gate is PR #856.
- #56 / #484 — umbrella product architecture.
- #249 — Bookmark presentation parity remains Object-lane owned; Lane C should not take Bookmark shared presentation hotspots unless ownership changes.

## Completed Lane C checkpoints
- #760 merged: failed Flutter Test runs retain a diagnostic log artifact and summary without masking the original exit code.
- #763 merged (`2fdd340b…`): searchable Relation Property target authoring/editing with explicit cardinality and canonical Lane B schema evolution.
- #776 merged (`0e61b0c6…`): searchable user-facing ObjectType template picker while preserving the empty custom Database path.
- #792 merged (`9e35afa2…`), #492 closed: schema-derived Image/Weblink Gallery cover sources are wired through the real generic Database host and persist per View.
- #793 merged (`5a19a86d…`): explicit View Property-reference detach preserves schema/data/Relation state and unknown View payloads.
- #800 merged (`321fda6d…`): delete impact can explicitly detach View references and re-inspect before allowing deletion.
- #819 merged (`dfc07176…`), #491 closed: real generic Relation picker quick-create supports custom/Tag/Weblink/Image/File targets through canonical creation/import services and refreshed Relation context.
- #826 merged (`a2fd7e13…`): incompatible Value Property migration can use an explicit two-stage clear-values decision; value deletion and schema change rollback atomically on failure.
- #832 merged (`83a44e0d…`): safe Property schema management substrate. Delete impact includes Formula/Rollup dependencies, workspace-wide Views, and secondary Database Collection filters.
- #845 merged (`a320a5b8…`), #493 closed: real `GenericDatabasePage` exposes safe Property schema management and secondary Collections manage the displayed target ObjectType schema.
- #851 merged (`0ca36410…`): template Views can declare Group by template-local Property name; the name resolves to the created canonical Property id through `DatabaseViewGroupAdapter`, with fail-closed preflight for unknown/non-groupable/raw-collision cases.

## Current Lane C work — #490 Bookmark-like template proof
PR #856 — `Prove Bookmark as a generic user-owned template`
Branch: `feature/database-view-bookmark-template-490`
Latest known head at handoff update: `7f0f7401…` before this documentation commit; always re-read live PR head/CI.

The slice:
- adds built-in `bookmark` only as template/configuration, producing a user-owned custom ObjectType;
- provisions Weblink/Tag/Image/File primitive Relation targets through the existing template primitive resolver;
- adds generic Rating, Status and Favorite Properties;
- creates generic `すべて`, `あとで読む`, and `お気に入り` Gallery Views with symbolic visible/order/filter/cover references resolved to stable created Property ids;
- adds no Bookmark-only persistence API, presentation API, or management page;
- proves post-create schema customization remains user-owned;
- adds a generic-operation regression using canonical `WeblinkObjectService`, `ObjectStore.setRelation`, generic Property values, `DatabaseViewQueryAdapter`, and `ObjectQueryEngine`, demonstrating Bookmark-like daily behavior without Bookmark-only APIs.

## #490 close decision
After #856 is full CI green and merged, re-read current #490 comments and latest main before closing. The architecture success criterion is materially satisfied if the merged state proves:
- ordinary ObjectType/Property/Relation/Database/View APIs instantiate the domain;
- built-in primitive Relations are provisioned generically;
- template-derived schema is editable and not silently rewritten by later template versions;
- default Views, filters, visible/order settings, Gallery covers, layout, and Group are generic contracts;
- empty custom Database creation remains available;
- an unrelated Plant/Paper regression continues to guard against Bookmark-only assumptions;
- Bookmark-like normal operation can be exercised without introducing any new Bookmark-only persistence/presentation API.
Legacy Bookmark host retirement/parity itself remains owned by #249/Object and #225/Refactor as applicable; do not broaden #490 into those lanes solely to close the template architecture Issue.

## Validation
Local Flutter/Dart execution is unavailable in this automation environment; GitHub Flutter CI is the validation gate. On failures use the retained CI artifact/log path from #760 instead of requesting manual logs.

## Shared hotspot lease / ownership
Always re-check open PR changed files before editing:
- `lib/views/generic_database_page.dart`
- `lib/views/app_shell.dart`
- `lib/views/object_inspector_page.dart`
- `lib/views/bookmark_unified_stage1_page.dart`
- `lib/widgets/bookmark_reorderable_properties.dart`
- `lib/views/people_management_page.dart`
- `lib/data/app_database.dart`

PR #856 does not own those presentation hotspots. Its production edit is limited to `lib/data/object_type_template_store.dart` plus focused tests and this Lane C handoff.

## Cross-lane boundaries
- Lane B owns Relation mutation/index/backlink/audit/reconcile and destructive target/cardinality correctness; Lane C consumes canonical services.
- Lane A owns Object/ObjectType/Body/default integrity and isolated template-core identity invariants.
- Lane D owns primitive creation/import semantics and media product behavior.
- Lane F owns managed filesystem/Vault copy/ownership/deletion lifecycle.
- Lane G owns broad behavior-preserving refactor/architecture-health work.

## Exact next actions
1. Read live PR #856 head and Flutter CI after this handoff commit.
2. If red, fetch the CI diagnostics and fix the exact failure; if green, re-check latest main/open PR overlap and squash-merge #856.
3. Add a #490 completion checkpoint. Close #490 only if its current close condition remains satisfied after the merged-state audit above.
4. Re-read #56/current open C-owned issues for the next actionable Database/View slice; do not take #249 Bookmark presentation ownership unless GitHub explicitly changes that routing.
