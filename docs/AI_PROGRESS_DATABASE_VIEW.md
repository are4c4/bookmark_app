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
Latest verified `main` after this slice was opened: `71a8ed14acf10f8efd6d4c2592cffb029a88c00a`.

Recent Lane C work already merged on main includes generic Gallery cover media host wiring (#643), compact Property-add to canonical Relation authoring (#633), unified safe Relation/Value schema editor dispatch (#638), template-version ownership regression (#653), plus earlier #490/#491/#492 schema/template foundations.

Current open Lane C work:
- #657 — searchable Relation target/cardinality authoring fields; non-mergeable after later main changes and requires a careful refresh because merged #633/#638 overlap its presentation files.
- #666 — refreshed canonical Property schema-service composition; mergeable when last checked; Flutter CI run #2082 was in progress.
- #659 was closed as superseded by #666.

Current slice branch: `feature/database-view-page-schema-services-current-491-493`.
Latest implementation/test commit before this handoff update: `ee413869a7612bec4a62540f784b888c82b551e5`.

Completed in this run:
- refreshed the stale #659 service-composition slice onto a current-main branch without touching `generic_database_page.dart`;
- `GenericDatabasePageServices` now exposes the existing canonical `DatabasePropertyAuthoringService`, stable-id `DatabaseViewPropertySchemaService`, Lane B `RelationSchemaEvolutionService`, and Value conversion/migration services through one production composition root;
- all composed services reuse the same `GenericDatabaseStore`, `ObjectStore`, `DatabaseViewStore`, and page Relation mutation facade rather than reconstructing parallel schema paths;
- restored the focused in-memory regression proving Relation creation, Relation change preflight, Value type preflight, and delete-impact inspection through the composed page service stack;
- opened replacement PR #666 and closed obsolete PR #659;
- no Relation integrity semantics, primitive behavior, search, Vault, or shared page hotspot behavior changed.

## Validation
- No local Flutter/Dart runtime is available through this connector execution path.
- Repository CI is the executable validation source for this branch/PR.
- #666 Flutter CI run #2082 was still in progress at the final check; PR mergeability was `true`.

## Exact next actions
1. Check #666 CI; merge when green if main has not introduced a conflicting change.
2. Refresh #657 selectively rather than copying its old branch wholesale: merged #633/#638 touched the same Property-add/schema-editor files, so preserve their newer canonical behavior while reapplying only searchable target/cardinality UX.
3. Continue #490 with template-owned default View/property configuration using stable Property ids; do not add domain-specific pages.
4. Continue #491 inline target creation only through target-type-safe canonical creation/import APIs; Weblink/Image/File behavior remains Lane D-owned.
5. Keep #493 migration correctness in Lane B; Lane C owns explicit impact/confirmation UX and composition only.
6. For #492/#249, avoid broad Bookmark/generic host edits until hotspot leases are clear; prefer resolver/settings/service regressions meanwhile.

## Shared hotspot rule
`generic_database_page.dart`, `bookmark_unified_stage1_page.dart`, and `object_inspector_page.dart` require an open-PR ownership check before edits. This run deliberately stayed in `generic_database_page_services.dart` plus a focused test, so no broad hotspot lease was taken.

## Cross-lane dependencies
- Lane B owns destructive Relation target/cardinality migration correctness and fail-closed integrity behavior consumed by Lane C schema UX.
- Lane D owns canonical Weblink/Image/File creation/import semantics used by Relation quick-create and Gallery media resolution.
- Lane G may retire legacy presentation paths only after generic Database/View parity is proven.

## Stop reason
A coherent non-hotspot #491/#493 service-composition refresh is open and mergeable as #666 with CI running. The next obvious #657 refresh overlaps newer merged presentation changes and should be reapplied selectively rather than by branch-copy; broad shared-host wiring remains sequenced behind #666 and hotspot ownership checks.
