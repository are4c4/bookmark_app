# AI Progress — Database, View & Schema UX Lane

> Lane C handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` before implementation. Verify current open PR ownership before touching shared hosts.

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
Latest verified `main` before the current #490 slice: `c36315706b45bbfb73185c6a69c64993bf71e64b`.

### Completed in this run
- merged #760 (`9a4bd3ba71f48610d5290f2368ef53ea602dad12`) to make Flutter Test failures self-diagnosing: full expanded output is retained as a failure artifact and the final log tail is copied into GitHub Step Summary while preserving the original test exit code;
- rebuilt closed #726 as #763 from current main, preserving only the focused Relation schema-authoring production/tests and the canonical Lane B `RelationSchemaEvolutionService.inspectChange -> confirmation -> updateRelationSchema` path;
- used the new CI artifact to identify the exact #763 failure: a `RenderShrinkWrappingViewport` intrinsic-dimension assertion caused by the searchable target list inside `AlertDialog(scrollable: true)`;
- replaced that shrink-wrapping viewport with an explicitly bounded result list, added the compact dialog regression, passed full Flutter CI, and merged #763 as `2fdd340bb79fc408cf21b7926699803f47d54861`;
- closed stale #696 as superseded and updated #491 with the current remaining managed-import composition boundary;
- started #490 user-facing template-selection polish on `feature/database-view-template-picker-search-490` / PR #776;
- made the existing AppShell-reachable template picker searchable by template identity/description plus template-local Property and View metadata, while keeping the empty custom Database path visible under every search state;
- added stable empty-result/clear behavior and focused widget regressions using template keys rather than text-count assumptions.

## Current open Lane C work
- #776 — searchable generic template picker for #490. GitHub Flutter CI is the current validation gate; merge when the current head is green and clean.
- #491 — searchable target/cardinality authoring and safe existing-Relation editing are integrated. Remaining value-picker quick-create composition is primarily Image/File through D/F-owned managed-import callbacks; do not introduce title-only primitive creation.
- #492 — core cover-source contract, resolver, fixed/masonry dispatcher, compatibility service, toolbar menu, template configuration and View-aware cover wrapper are present. The next gap is final real `GenericDatabasePage` host convergence: the card still directly uses the older Weblink media widget and must consume the View-aware generic cover host once shared-hotspot ownership is clear.
- #493 — integrity substrate is largely integrated; remaining C work is broader impact/migration UX and explicit broken View-reference surfacing, not Relation mutation logic.

## Validation
- Local Flutter execution is not available in this automation environment; GitHub Flutter CI is the validation gate.
- #763 full CI passed after the compact viewport fix.
- #760 diagnostics are now available for future failing Flutter Test runs, including downloadable failure artifacts through the GitHub connector.
- #776 focused coverage lives in `test/object_type_template_picker_test.dart`.

## Exact next actions
1. Finish #776 CI triage, merge if green/clean, and record the #490 checkpoint on the Issue.
2. Re-fetch latest `main` and open PR ownership immediately before any shared-host work.
3. Continue #492 by replacing the remaining real generic Gallery card's direct Weblink-only media composition with `DatabaseGalleryViewCoverMedia`, and pass schema-discovered `galleryCoverSources` to the real toolbar without adding a domain-specific cover resolver.
4. Keep #491 Image/File quick-create blocked on canonical D/F managed-import composition rather than inventing an alternate primitive writer.
5. Continue #493 with user-facing impact/broken-reference UX only; destructive Relation migration correctness remains Lane B-owned.
6. Then audit #249 generic presentation parity and the generic Database side-peek/detail Body composition gap.

## Shared hotspot lease / ownership
Before the #776 picker slice, current open PR changed-file ownership was re-audited and no open PR edited `object_type_template_picker.dart`. The picker slice does not touch a shared hotspot. The latest audit also found no then-open PR editing `generic_database_page.dart`, but this must be checked again immediately before the #492 host slice because parallel lanes are active.

`generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `bookmark_reorderable_properties.dart`, `people_management_page.dart`, and `app_database.dart` remain shared hotspots.

## Cross-lane dependencies
- Lane B owns Relation mutation/index/backlink/audit/reconcile and destructive target/cardinality migration correctness; Lane C consumes those canonical services.
- Lane D owns Weblink/Image/File/Tag primitive creation/import semantics used by Relation quick-create and Gallery media resolution.
- Lane F owns managed filesystem/Vault copy and ownership/deletion lifecycle needed to finish Image/File quick-create composition.
- Lane A owns core Object/Body contracts; Lane C composes them into Database/View hosts only after hotspot ownership is clear.
- Lane G owns broad maintainability/refactor work.

## Stop reason
Do not stop on this checkpoint alone. Continue with #776 CI/merge, then proceed to the next safe #492 host convergence slice from fresh `main`.
