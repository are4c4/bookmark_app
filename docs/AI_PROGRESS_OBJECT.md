# AI Progress — Object Core & Body Lane

> Lane A durable handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` before implementation. This file no longer owns Weblink/Image/File product work or generic Database/View presentation.

## Lane goal
Keep the reusable Object/ObjectType core coherent while making Body and Object detail capabilities universal across built-in and user-defined ObjectTypes.

## Primary active issues
- #481 — universal Body/note surface for every ObjectType.
- #56 — Object/ObjectType/detail/opening portions of the generic architecture umbrella.
- #484 — core user-defined ObjectType semantics and built-in-vs-user-defined boundary only; primitive implementation belongs to the Primitive lane.

## Owns
- Object/ObjectType identity and core schema semantics.
- Typed Property value semantics that are not presentation-host-specific.
- Versioned Body/block/reference persistence and editing contracts.
- Universal Body capability across ordinary/system ObjectTypes.
- Aliases/shared Object identity metadata contracts.
- Daily Note identity/navigation and time-based Object patterns.
- Shared Object detail/opening semantics.
- User-defined ObjectType core behavior.

## Does not own anymore
- Weblink/Image/File/Tag primitive product behavior -> `docs/AI_PROGRESS_PRIMITIVES.md`.
- Database/View/Table/List/Gallery/Board/schema-authoring UX -> `docs/AI_PROGRESS_DATABASE_VIEW.md`.
- Relation lifecycle/data-integrity internals -> `docs/AI_PROGRESS_RELATION.md`.
- Search/FTS/indexing -> `docs/AI_PROGRESS_SEARCH.md`.
- Vault/filesystem/delivery -> `docs/AI_PROGRESS_STORAGE.md`.
- behavior-preserving cleanup -> `docs/AI_PROGRESS_REFACTOR.md`.

## Current core state
- Object/ObjectType persistence, generic Object records, aliases, shared detail content and typed Property presentation are integrated.
- Body is already versioned/block-oriented and supports text/checklist/reference-style blocks plus Object and Database/View references.
- Daily Note uses the shared Object model with unique-by-date workflow semantics.
- Shared Object opening modes and detail content are integrated in side/center/full-page hosts.

## Current gap — #481
The shared inspector historically restricted Body editing for most system ObjectTypes while allowing ordinary types and Daily Note. Product direction now treats Body as universal Object content:

```text
Object
├ typed Properties
└ Body
```

Weblink/Image/File/Tag identity rules remain intact; enabling Body must not weaken their canonical creation/identity semantics.

## Initial next actions
1. Re-read #481 and current `ObjectInspectorPage` before editing; check hotspot ownership first.
2. Remove only the system-type Body-edit restriction through a patch-sized change or focused seam.
3. Add regression proving Body create/edit persists for at least Weblink and Image system Objects while ordinary/custom Objects and Daily Note retain behavior.
4. Verify side peek / center peek / full page consume the same Body content through the shared detail contract.
5. Coordinate Body indexing with Search lane rather than adding search logic here.

## Shared hotspot rule
`object_inspector_page.dart` requires an open-PR ownership check. If it is leased by Primitive/Refactor/Database-View work, choose domain/service/test slices or sequence the patch rather than reconstructing the whole host.

## Handoff checklist
Record active Issue, branch/commit/PR, core semantic change, validation, hotspot lease, cross-lane dependencies, next actions, and stop reason before ending a run.
