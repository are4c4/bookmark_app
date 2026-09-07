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
Latest verified `main` at run start: `31b20f248d38bb3c3a4191dec18032ab429d22f9` (`docs: refresh Relation audit on latest main (#725)`).

Recent Lane C work integrated on `main` includes generic Gallery cover media host wiring (#643), compact Property-add to canonical Relation authoring (#633), unified safe Relation/Value schema editor dispatch (#638), template ownership/version regressions (#653), canonical page schema-service composition (#666), subsequent template/schema slices including #700, template View stable Property configuration (#703), and template-local Filter/Sort Property references resolved to generated canonical ids (#722).

### Completed in the latest run
- re-read `AGENTS.md`, repository/lane handoffs, #490/#491/#492/#249/#56, latest `main`, current open PR ownership, branches/commits, and the stale #696 CI before editing;
- re-confirmed Lane C must keep Relation data integrity in Lane B and deliberately avoided shared presentation hotspots (`generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`);
- rebuilt the #491 Relation Property target/cardinality authoring slice on fresh branch `feature/database-view-relation-authoring-search-491-v2` from current `main`, instead of rebasing the stale #696 branch;
- added a presentation-only `RelationPropertyAuthoringFields` widget with searchable target ObjectType discovery, built-in/custom labels, explicit target clear, and explicit single/multi cardinality choice;
- wired the existing Relation Property schema editor to that authoring widget while preserving the canonical `RelationSchemaEvolutionService.inspectChange -> impact confirmation -> updateRelationSchema` mutation path unchanged;
- kept the editor scrollable and hardened integration tests with `ensureVisible` plus search narrowing so compact test viewports do not rely on offscreen hit testing;
- added focused widget coverage for search, canonical ObjectType-id selection, clear behavior, cardinality choice, target-change impact preview, and multi-to-single safe migration flow.

## Current open Lane C work
- Fresh #491 branch: `feature/database-view-relation-authoring-search-491-v2`. Create a replacement PR for stale #696 and validate Analyze + Flutter Test before merge.
- #696 remains stale on old head `1759bbe183f3729c7f95a9d9a08f7226e67e9288`; close it after the replacement PR is established to avoid duplicate ownership/confusion.
- #490 template View query Property references are already integrated via #722; continue with useful generic template defaults only after the current #491 slice is green.

## Validation
- Local Flutter execution is not available in this automation environment, so this slice relies on GitHub Actions after PR creation.
- Focused tests: `test/relation_property_authoring_fields_test.dart` and `test/relation_property_schema_editor_test.dart`.
- No Relation integrity mutation, primitive-specific behavior, Search, Vault, or shared-hotspot edit was introduced.

## Exact next actions
1. Create the replacement #491 PR from `feature/database-view-relation-authoring-search-491-v2`, inspect Analyze + Flutter Test, and fix only presentation/test failures in Lane C scope.
2. Once replacement CI is green, close stale #696 and merge the replacement PR.
3. Continue #491 inline target creation only through target-type-safe canonical creation/import APIs; Weblink/Image/File behavior remains Lane D-owned.
4. Continue #490 with useful built-in template defaults that exercise generic View filter/sort/group/layout configuration; do not bake Bookmark-only APIs into templates.
5. Keep #493 destructive migration correctness in Lane B; Lane C owns explicit impact/confirmation UX and service composition only.
6. For #492/#249, avoid broad Bookmark/generic host edits while another lane owns the relevant hotspot; prefer settings/resolver/service/test slices.
7. Re-audit `generic_database_page.dart` ownership immediately before any generic Database side-peek/detail composition work.

## Shared hotspot lease / ownership
`generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, and the other AGENTS.md hotspots require a fresh open-PR ownership check before non-trivial edits. This run touched only the focused Relation authoring widget, its existing schema-editor host, focused widget tests, and this Lane C handoff. No temporary broad hotspot lease was taken.

## Cross-lane dependencies
- Lane B owns destructive Relation target/cardinality migration correctness and fail-closed integrity behavior consumed by Lane C schema UX.
- Lane D owns canonical Weblink/Image/File creation/import semantics used by Relation quick-create and Gallery media resolution.
- Lane A owns core Object/Body contracts; Lane C may compose them into Database/View hosts only after hotspot ownership is clear.
- Lane G may retire legacy presentation paths only after generic Database/View parity is proven.

## Stop reason
A fresh, non-hotspot #491 Relation authoring UX slice is implemented with focused regression coverage and durable handoff. GitHub CI on the replacement PR is the next validation gate; independent Lane C work remains available after CI triage.
