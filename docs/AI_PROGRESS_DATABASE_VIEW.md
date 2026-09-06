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
Latest verified `main` for this run: `c2d4bd082e1e88c6781db4f51b2c12998a6ff85f`.

Recent Lane C work already merged on main includes generic Gallery cover media host wiring (#643), compact Property-add to canonical Relation authoring (#633), unified safe Relation/Value schema editor dispatch (#638), template-version ownership regression (#653), plus earlier #490/#491/#492 schema/template foundations.

Open Lane C PRs observed before this slice:
- #657 — searchable Relation target/cardinality authoring fields; currently non-mergeable after main advanced.
- #659 — canonical Property schema services composed at `GenericDatabasePageServices`; currently non-mergeable after main advanced; Flutter CI run #2070 was still in progress when checked.

Current slice branch: `feature/database-view-page-schema-services-current-491-493`.
Latest branch commit after handoff update: this file update follows `ee413869a7612bec4a62540f784b888c82b551e5`.

Completed in this run:
- refreshed the #659 service-composition slice onto latest verified main without touching `generic_database_page.dart`;
- `GenericDatabasePageServices` now exposes the existing canonical `DatabasePropertyAuthoringService`, stable-id `DatabaseViewPropertySchemaService`, Lane B `RelationSchemaEvolutionService`, and Value conversion/migration services through one production composition root;
- all composed services reuse the same `GenericDatabaseStore`, `ObjectStore`, `DatabaseViewStore`, and page Relation mutation facade rather than reconstructing parallel schema paths;
- restored the focused in-memory regression proving Relation creation, Relation change preflight, Value type preflight, and delete-impact inspection through the composed page service stack;
- no Relation integrity semantics, primitive behavior, search, Vault, or shared page hotspot behavior changed.

## Validation
- No local Flutter/Dart runtime is available through this connector execution path.
- Repository CI is the executable validation source for this branch/PR.
- Previous #659 CI was still running when inspected; this refreshed branch is based on newer main and must use its own CI result.

## Exact next actions
1. Merge/clear the refreshed schema-service composition PR before wiring `generic_database_page.dart`; keep the shared-host change dependency-only.
2. Refresh #657 onto current main if it remains non-mergeable, preserving the searchable Relation target/cardinality field behavior.
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
A coherent non-hotspot #491/#493 service-composition refresh is complete on current main and ready for PR/CI. The next shared-host wiring is intentionally sequenced behind this dependency and other non-mergeable Lane C PR refreshes to avoid concurrent hotspot edits.
