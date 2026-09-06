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
Open Lane C work observed before this slice:
- PR #520 — Relation schema-change impact confirmation UX, independent from `generic_database_page.dart`.
- PR #524 — generic Gallery Relation cover-target resolver, with host wiring intentionally deferred.

Current slice branch: `feature/database-view-plant-template-490`.
Latest branch commit: `c728285290142e351d32422f6ba4c600fbd6fada`.

Completed in this slice:
- added a built-in `Plant` domain template as the unrelated #490 architecture-success example;
- Plant is a normal user-owned custom ObjectType, not a system type or dedicated management page;
- its `写真` and `タグ` Properties resolve Image/Tag system ObjectTypes through the existing generic Relation-template path;
- it creates an ordinary generic Gallery View and ordinary Date/Text Properties;
- added regression coverage proving Image/Tag target resolution, multi cardinality, custom ObjectType kind and generic Gallery creation.

This intentionally adds no Plant-specific page/service/persistence path and does not modify Relation integrity internals, primitive behavior, search, Vault or shared presentation hotspots.

## Validation
- No local Flutter/Dart runtime was available through this connector execution path; repository PR CI is required for executable validation.
- The slice is limited to `object_type_template_store.dart`, its focused test, and this handoff.

## Exact next actions
1. Let #520/#524 clear or refresh before composing any shared-host schema/Gallery wiring.
2. Continue #490 with template-owned default View/property configuration only where generic APIs are insufficient; do not add domain pages.
3. For #491, prefer a focused Relation Property authoring widget/service seam rather than broad `generic_database_page.dart` edits while other Lane C PRs are open.
4. After Lane D lands canonical File primitive availability, add a Bookmark/Paper template using Weblink/Image/File/Tag Relations without hard-coded domain behavior.
5. Keep #493 migration correctness in Lane B; Lane C only owns explicit impact/confirmation UX.

## Shared hotspot rule
`generic_database_page.dart`, `bookmark_unified_stage1_page.dart`, and `object_inspector_page.dart` require an open-PR ownership check before edits. Prefer focused widgets/services/settings adapters while a hotspot is leased by another lane.

## Stop reason
A coherent, non-conflicting #490 template-composition slice is complete and ready for PR/CI. Further host composition should be sequenced behind currently open Lane C PRs rather than creating overlapping broad edits.
