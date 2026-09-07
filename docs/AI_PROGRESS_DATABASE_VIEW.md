# AI Progress — Database, View & Schema UX Lane

> Lane C handoff. Always re-read `AGENTS.md`, the active Issue, `docs/AI_PROGRESS.md`, latest `main`, open PR ownership, and current CI before implementation. Do not treat commit SHAs in this handoff as fresher than GitHub.

## Lane goal
Make generic ObjectType/Database/View configuration expressive enough that new domains are created by configuration/templates rather than new management pages.

## Primary active work
- #490 — templates instantiate user-owned ObjectTypes/Databases/Views; next Lane C priority after #493.
- #493 — schema-evolution UX; real-host production composition is in PR #845 and is the current validation gate.
- #249 — Bookmark presentation parity is explicitly Object-lane owned. Lane C should not take the Bookmark shared hotspot unless ownership changes.
- #56 / #484 — umbrella product architecture.

## Completed Lane C checkpoints
- #760 merged: failed Flutter Test runs retain a diagnostic log artifact and summary without masking the original exit code.
- #763 merged (`2fdd340b…`): searchable Relation Property target authoring/editing with explicit cardinality and canonical Lane B schema evolution.
- #776 merged (`0e61b0c6…`): searchable user-facing ObjectType template picker while preserving the empty custom Database path.
- #792 merged (`9e35afa2…`), #492 closed: schema-derived Image/Weblink Gallery cover sources are wired through the real generic Database host and persist per View.
- #793 merged (`5a19a86d…`): explicit View Property-reference detach preserves schema/data/Relation state and unknown View payloads.
- #800 merged (`321fda6d…`): delete impact can explicitly detach View references and re-inspect before allowing deletion.
- #819 merged (`dfc07176…`), #491 closed: real generic Relation picker quick-create supports custom/Tag/Weblink/Image/File targets through canonical creation/import services and refreshed Relation context.
- #826 merged (`a2fd7e13…`): incompatible Value Property migration can use an explicit two-stage clear-values decision; value deletion and schema change rollback atomically on failure.
- #832 merged (`83a44e0d…`): production-ready safe Property schema management substrate. Delete impact includes Formula/Rollup dependencies, workspace-wide Views, and secondary Database Collection filters; ordinary and Relation deletion stay on their canonical service boundaries.

## Current Lane C work — #493 real-host completion
PR #845 — `Wire safe Property schema management into generic Database host`
Branch: `feature/database-view-schema-management-host-493`

The slice:
- adds `プロパティ設定` to the existing `GenericDatabasePage` settings menu only for a displayed custom ObjectType;
- delegates to `DatabasePropertySchemaManagementDialog` using `GenericDatabasePageServices` canonical schema/Relation services;
- passes `_objectType.id`, so a secondary Collection manages the schema it is actually displaying rather than the Database identity ObjectType;
- reloads the host after schema management closes;
- adds a real-host regression with `Plant Dashboard -> Collection target Plant`, proving Plant schema rename persists while Dashboard-only schema is untouched.

First #845 CI: Analyze green, full Test had one test-only finder ambiguity because `Score` was visible both in the background table and the modal. Product behavior was correct. The regression was updated to scope assertions to the stable `property-schema-management-<id>` row key. Latest test-fix commit at handoff preparation: `20b725ca…`; re-check current #845 head and CI before acting.

### #493 close decision
If #845 passes full CI and merges, #493's current close condition is satisfied by the combined merged work: stable rename; explicit compatible/incompatible Value migration; canonical Relation target/cardinality evolution; impact-aware delete; explicit View detach; computed/Collection blockers; transactional rollback; and real generic-host exposure. Add a completion comment and close #493 after the merged state is verified.

## Next Lane C priority — #490 Templates
Current Issue comments narrow the remaining C work to richer template View defaults and proving generic domain composition. Before implementing, inspect current `object_type_template_store.dart` and tests because Lane A is also strengthening template preflight.

Likely safe C-owned investigation:
1. determine whether template Views can already persist layout and whether symbolic group-by Property references are missing;
2. if group defaults are missing, add template-local Property-name -> canonical Property-id resolution using the existing View group contract, with transactional rollback on unknown/invalid references;
3. use an unrelated Plant/Paper regression; do not introduce a domain management page;
4. leave Bookmark-host convergence to its current owner unless ownership changes.

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

#845 currently owns only the patch-sized `generic_database_page.dart` schema-management host edit plus focused test/handoff changes. Release that lease immediately after merge/close.

## Cross-lane boundaries
- Lane B owns Relation mutation/index/backlink/audit/reconcile and destructive target/cardinality correctness; Lane C consumes canonical services.
- Lane A owns Object/ObjectType/Body/default integrity and is also active around template preflight.
- Lane D owns primitive creation/import semantics and media product behavior.
- Lane F owns managed filesystem/Vault copy/ownership/deletion lifecycle.
- Lane G owns broad behavior-preserving refactor/architecture-health work.

## Exact next actions
1. Read current #845 head and CI after the finder fix/handoff update.
2. If red, use CI diagnostics and fix the exact failure; if green, verify current main/open PR conflicts and squash-merge #845.
3. Add #493 completion comment and close the Issue only after #845 is merged.
4. Start #490 from fresh main with current open-PR ownership audit, then inspect template View group/layout support before choosing the next implementation slice.
