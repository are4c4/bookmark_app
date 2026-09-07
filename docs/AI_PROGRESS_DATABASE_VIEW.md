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
Latest verified `main`: `64b39591c09fdd8ac983a9e892bc637a39a17b90`.

Recent Lane C work integrated on `main` includes generic Gallery cover media host wiring (#643), compact Property-add to canonical Relation authoring (#633), unified safe Relation/Value schema editor dispatch (#638), template ownership/version regressions (#653), canonical page schema-service composition (#666), subsequent template/schema slices including #700, and template View stable Property configuration (#703).

### Completed in the latest run
- re-read the current lane contracts, repository handoff, #490/#491/#492/#249/#56, open PRs and hotspot ownership before editing;
- verified #703 was mergeable and Flutter CI #2248 passed;
- squash-merged #703 as `64b39591c09fdd8ac983a9e892bc637a39a17b90`;
- #703 lets template Views declare visible Properties and Property order by template-local Property name, resolves them after schema creation, and persists canonical `p:<id>` tokens; unknown/duplicate references fail closed inside the template transaction;
- audited the next #490 composability gap: template `filters` / `sorts` still carry raw numeric `propertyId`, so static templates cannot safely target Properties created by that same template without workspace-specific ids;
- rechecked #696. Its production scope remains presentation-only and non-hotspot, but current head `1759bbe183f3729c7f95a9d9a08f7226e67e9288` has Flutter CI #2241 failing in the full Test step while Analyze and all architecture/maintainability guards pass. The branch is also behind/conflicting with newer `main`, so it must be refreshed before integration.

## Current open Lane C work
- #696 — existing Relation Property target/cardinality editing with searchable ObjectType selection. Keep the canonical `RelationSchemaEvolutionService.inspectChange -> confirmation -> updateRelationSchema` path unchanged. Current full-suite failure must be reproduced/fixed on a current-main refresh before merge.

## Validation
- #703: Flutter CI #2248 completed successfully before merge.
- #696 head `1759bbe...`: Analyze succeeded; full Test step failed in Flutter CI #2241. Do not merge until a current-main refresh is green.
- No broad shared-host edit or Relation integrity mutation was introduced by the latest completed slice.

## Exact next actions
1. Refresh #696 onto latest `main`, preserving only its four focused files; reproduce the full-suite widget failure and fix the compact/scroll interaction without changing Relation integrity semantics.
2. Continue #490 with template-local Property references for View filters/sorts, resolving them to canonical numeric Property ids only after schema creation while preserving existing raw filter/sort compatibility.
3. Continue #491 inline target creation only through target-type-safe canonical creation/import APIs; Weblink/Image/File behavior remains Lane D-owned.
4. Keep #493 destructive migration correctness in Lane B; Lane C owns explicit impact/confirmation UX and service composition only.
5. For #492/#249, avoid broad Bookmark/generic host edits while another lane owns the relevant hotspot; prefer settings/resolver/service/test slices.
6. Generic Database side-peek Body/detail composition remains a cross-lane integration gap noted by Lane A; re-audit `generic_database_page.dart` ownership immediately before taking that host slice.

## Shared hotspot lease / ownership
`generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, and the other AGENTS.md hotspots require a fresh open-PR ownership check before non-trivial edits. The latest #703 work touched only template store/tests; #696 touches only Relation schema-authoring widgets/tests. Lane A currently has open Object detail/Body work (#698), Lane B has Relation-integrity work (#713), and Lane D/G/F also have active PRs, so do not broaden Lane C into their files or semantics.

## Cross-lane dependencies
- Lane B owns destructive Relation target/cardinality migration correctness and fail-closed integrity behavior consumed by Lane C schema UX.
- Lane D owns canonical Weblink/Image/File creation/import semantics used by Relation quick-create and Gallery media resolution.
- Lane A owns core Object/Body contracts; Lane C may compose them into Database/View hosts only after hotspot ownership is clear.
- Lane G may retire legacy presentation paths only after generic Database/View parity is proven.

## Stop reason
#703 is integrated and the durable handoff is refreshed. #696 still requires a current-main refresh plus a full-suite widget failure fix before integration. The next independent #490 filter/sort template slice is identified, but should be implemented as a separate focused PR rather than mixed into the failing #696 presentation branch.
