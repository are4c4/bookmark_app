# AI Progress — Database, View & Schema UX Lane

> Lane C handoff. Read `AGENTS.md`, the active Issue, `docs/AI_PROGRESS.md`, and latest GitHub state before implementation. Verify current open PR ownership before touching shared hosts.

## Lane goal
Make generic ObjectType/Database/View configuration expressive enough that new domains are created by configuration/templates rather than new management pages.

## Primary active issues
- #490 — templates instantiate user-owned ObjectTypes/Databases/Views.
- #491 — first-class Relation Property authoring and inline target creation UX.
- #492 — generic Gallery cover/media source from Object Relations.
- #493 — schema-evolution UX side; coordinate integrity-sensitive changes with Relation/Data Integrity lane.
- #249 — remaining Bookmark presentation parity only where it is a generic Database/View contract.
- #56 / #484 — umbrella product architecture.

## Current checkpoint — 2026-09-07
Latest observed `main` while preparing this handoff: `c591cf7917de4bc3e4d78ea183d20d8f9f8eb7b5`.

### Completed checkpoints
- #760 merged: Flutter Test failures now retain self-service diagnostics while preserving the original test exit code.
- #763 merged as `2fdd340bb79fc408cf21b7926699803f47d54861`: Relation Property authoring uses searchable target selection, built-in/custom distinction, explicit single/multi selection, safe existing-Relation editing, and the canonical Lane B schema-evolution path; compact dialog regression is covered.
- stale #696 closed as superseded.
- #776 merged as `0e61b0c6bdc46efdfbb4fccc083a601a52612969`: the AppShell-reachable ObjectType template picker is searchable by template identity/description plus template-local Property/View metadata while the empty custom Database path remains available.
- stale #781 closed as superseded by #792.

## Current Lane C work
### #492 — real generic Gallery cover convergence
Active PR: #792, branch `feature/database-view-gallery-cover-host-492-v3`.

The current slice:
- exposes canonical `DatabaseViewGalleryCoverSourceService` through `GenericDatabasePageServices`, reusing the production `SystemObjectStore` composition;
- discovers schema-derived cover choices from the real `GenericDatabasePage` reload path;
- passes those choices into the existing `ObjectViewToolbar` cover selector;
- replaces the real Gallery card's direct Weblink-only media composition with `DatabaseGalleryViewCoverMedia`;
- preserves View-owned `galleryCoverSource` persistence and existing fixed/masonry contract;
- adds focused service and real-host regressions with an unrelated custom `Plant -> Photo Relation(Image)` schema, including actual toolbar selection and `DatabaseViewStore` persistence.

Old PR #781 is closed; do not revive it.

### #491 — Relation quick-create remainder
Searchable target/cardinality authoring and safe editing are integrated. Remaining Image/File quick-create must consume Lane D/F canonical managed-import composition. Do not introduce title-only primitive creation or another file writer.

### #493 — next C-owned schema UX slice
Integrity substrate is substantially integrated. The next safe Lane C slice is explicit View-reference handling around Property schema changes: surface which View settings reference a Property and provide an explicit C-owned detach/update path for View configuration only. Do not delete or retarget Relation data from this UX; destructive Relation target/cardinality correctness remains Lane B-owned.

## Validation
- Local Flutter/Dart execution is unavailable in this automation environment; GitHub Flutter CI is the validation gate.
- #763 and #776 passed full repository Flutter CI before merge.
- #792 is the current Gallery host validation gate. If red, use the CI failure artifact/summary introduced by #760 rather than asking for manual log paste.
- Focused #792 coverage:
  - `test/generic_database_page_services_gallery_cover_test.dart`
  - `test/generic_database_page_gallery_cover_integration_test.dart`

## Exact next actions
1. Triage #792 CI; fix any failure from the retained diagnostics, then merge when green and conflict-free.
2. Update/comment #492 with the merged real-host coverage; reassess whether any close-condition gap remains before closing the Issue.
3. Start #493 from fresh `main` with a focused View-reference detach/broken-reference UX service slice, avoiding Relation mutation semantics.
4. Re-check Lane D/F state for #491 Image/File managed-import quick-create before attempting production composition.
5. Then audit #249 generic presentation parity and generic Database side-peek/detail Body composition.

## Shared hotspot lease / ownership
Before #792, open PR changed-file ownership was re-audited. No other active PR edited `lib/views/generic_database_page.dart`; concurrent PRs were docs-only Search handoff, standalone performance probe, and primitive remote-image storage work. Lane C therefore owns the patch-sized `generic_database_page.dart` Gallery host edit for #792.

Re-check immediately before any subsequent shared-host edit. Shared hotspots remain:
- `lib/views/generic_database_page.dart`
- `lib/views/app_shell.dart`
- `lib/views/object_inspector_page.dart`
- `lib/views/bookmark_unified_stage1_page.dart`
- `lib/widgets/bookmark_reorderable_properties.dart`
- `lib/views/people_management_page.dart`
- `lib/data/app_database.dart`

## Cross-lane dependencies
- Lane B owns Relation mutation/index/backlink/audit/reconcile and destructive target/cardinality migration correctness; Lane C consumes canonical services.
- Lane D owns Weblink/Image/File/Tag primitive creation/import semantics and media resolution product behavior.
- Lane F owns managed filesystem/Vault copy/ownership/deletion lifecycle.
- Lane A owns core Object/Body contracts; Lane C composes them into Database/View hosts after hotspot ownership is clear.
- Lane G owns broad behavior-preserving refactor/architecture-health work.

## Stop reason
Do not stop merely because #792 CI is pending. Continue independent #493 contract/UX work where it does not conflict with the active Gallery host branch. Stop only at an `AGENTS.md` stop condition or tool/runtime boundary.
