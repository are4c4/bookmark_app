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
Latest verified `main` at run start: `41ec4470299a63849c5a282bd4f0bea0e8813c30`.

Recent Lane C work integrated on `main` includes generic Gallery cover media host wiring (#643), compact Property-add to canonical Relation authoring (#633), unified safe Relation/Value schema editor dispatch (#638), template ownership/version regressions (#653), canonical page schema-service composition (#666), subsequent template/schema slices including #700, and template View stable Property configuration (#703).

### Completed in the latest run
- re-read `AGENTS.md`, repository/lane handoffs, #490/#491/#492/#249/#56, latest `main`, and current open PR ownership before editing;
- confirmed no current open PR holds a broad Lane C lease on `generic_database_page.dart` or other shared presentation hotspots; this run deliberately stayed outside all shared hotspots because active Lane A/D/F/G work remains open;
- continued #490 on branch `feature/database-view-template-query-property-refs` from current `main`;
- added template-local `ObjectTypeTemplateFilter` / `ObjectTypeTemplateSort` declarations so static templates can target Properties by name rather than embedding workspace-specific numeric ids;
- template View creation now resolves those Property names only after the user-owned schema is created and persists canonical numeric `propertyId` query rules;
- existing raw `filters` / `sorts` remain supported and are preserved/appended, so existing template callers are not forced through a migration;
- unknown template-local query Property references fail closed inside the existing template transaction, rolling back the partially-created user-owned schema;
- added focused regression coverage proving filter/sort Property ids resolve to the newly-created schema ids, raw title query/sort rules remain intact, and unknown Property references roll back.

## Current open Lane C work
- current #490 PR: `feature/database-view-template-query-property-refs` (`e1b09d568457c10e3797dd6bf3feab02e84ae76f` before this handoff update). CI must pass before integration.
- #696 — existing Relation Property target/cardinality editing with searchable ObjectType selection. Keep the canonical `RelationSchemaEvolutionService.inspectChange -> confirmation -> updateRelationSchema` path unchanged. Its older head failed the full Flutter Test step and remains unsuitable for merge until refreshed onto current main and revalidated.

## Validation
- Local Flutter execution is not available in this automation environment, so the new #490 slice relies on GitHub Flutter CI after PR creation.
- Focused tests added: `test/object_type_template_view_query_property_refs_test.dart`.
- No shared hotspot edit, Relation integrity mutation, primitive-specific behavior, Search, or Vault change was introduced.

## Exact next actions
1. Check the new #490 PR CI; fix any compile/test failure caused by the template query Property-ref slice, then merge only when relevant checks pass.
2. Refresh #696 onto latest `main`, preserving only its focused Relation schema-authoring presentation files; reproduce/fix the compact/scroll widget failure without changing Relation integrity semantics.
3. Continue #490 with useful built-in template defaults that exercise filter/sort configuration only after the generic contract is green; do not bake Bookmark-only APIs into templates.
4. Continue #491 inline target creation only through target-type-safe canonical creation/import APIs; Weblink/Image/File behavior remains Lane D-owned.
5. Keep #493 destructive migration correctness in Lane B; Lane C owns explicit impact/confirmation UX and service composition only.
6. For #492/#249, avoid broad Bookmark/generic host edits while another lane owns the relevant hotspot; prefer settings/resolver/service/test slices.
7. Generic Database side-peek Body/detail composition remains a cross-lane integration gap noted by Lane A; re-audit `generic_database_page.dart` ownership immediately before taking that host slice.

## Shared hotspot lease / ownership
`generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, and the other AGENTS.md hotspots require a fresh open-PR ownership check before non-trivial edits. This run touched only `object_type_template_store.dart`, a focused test, and this Lane C handoff. No temporary broad hotspot lease was taken.

## Cross-lane dependencies
- Lane B owns destructive Relation target/cardinality migration correctness and fail-closed integrity behavior consumed by Lane C schema UX.
- Lane D owns canonical Weblink/Image/File creation/import semantics used by Relation quick-create and Gallery media resolution.
- Lane A owns core Object/Body contracts; Lane C may compose them into Database/View hosts only after hotspot ownership is clear.
- Lane G may retire legacy presentation paths only after generic Database/View parity is proven.

## Stop reason
A coherent non-hotspot #490 filter/sort template slice is implemented with focused regressions and durable handoff. GitHub CI is the next required validation for that branch; other independent Lane C work remains available after CI triage, especially refreshing #696 on current main.
