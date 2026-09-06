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

## Owns
- Database collection semantics and View persistence.
- Table/List/Gallery/Board generic presentation contracts.
- Filter/Sort/Group/Layout/visible Properties.
- Property-add/schema-authoring UX.
- User-owned template/domain schema instantiation.
- Generic View media/cover configuration.

## Does not own
- Weblink/Image/File native product behavior: Primitive lane.
- Relation mutation/index/integrity internals: Relation/Data Integrity lane.
- Search index implementation: Search lane.
- Vault/filesystem lifecycle: Storage lane.
- Behavior-preserving cleanup only: Refactor lane.

## Initial next actions
1. Audit current Property-add flow and Relation Property schema-creation path for #491; prefer a patch-sized generic UX slice.
2. Define persisted generic Gallery cover-source settings for #492 without Bookmark-only fields.
3. Audit current template/default infrastructure and design user-owned instantiation for #490.
4. Split #493 changes into UI/configuration versus integrity/migration responsibilities before implementation.

## Shared hotspot rule
`generic_database_page.dart`, `bookmark_unified_stage1_page.dart`, and `object_inspector_page.dart` require an open-PR ownership check before edits. Prefer focused widgets/services/settings adapters while a hotspot is leased by another lane.

## Handoff checklist
Record active Issue, branch/commit/PR, completed slices, validation, hotspot lease, cross-lane dependencies, next actions, and stop reason before ending a run.
