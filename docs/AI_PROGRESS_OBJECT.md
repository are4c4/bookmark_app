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

## Active checkpoint — #481 universal Body
Branch: `feature/object-universal-body-481`
PR: #503 `Make Object Body editable for every ObjectType`
Base main at branch creation: `844f6b77e7b6947bceaaf6986e6ff8182212e71b`
Latest implementation commit before handoff refresh: `88e46cf4f4ca40cdce0221a5f37f8f156d62f3eb`

Completed in this slice:
- verified latest seven-lane routing before editing; Object lane now owns #481/core #56 while #155/#245 primitive product behavior and #249 generic presentation are outside this lane;
- checked open PR ownership before touching `object_inspector_page.dart`; no current open PR overlapped the Body-edit hunk;
- removed only the system-type Body-edit restriction in the shared Inspector; all ObjectTypes now receive the existing shared Body edit actions;
- kept system Object title/Property/create identity guards unchanged;
- added `object_inspector_universal_body_test.dart`, proving Weblink and Image system Objects both expose the shared empty-Body insertion affordance and persist the first paragraph through `ObjectBodyStore`;
- no Relation mutation/read semantics, primitive identity/services, search indexing, Database/View presentation, or schema/migration behavior changed.

Validation:
- connector environment cannot execute Flutter locally; rely on PR CI for analyzer/test execution;
- PR #503 was opened successfully; workflow run had not appeared yet at the first post-open check.

Hotspot ownership:
- Object lane owns only the patch-sized `_canEditBody` hunk for PR #503.
- Primitive PR #498 is service-only Image composition and does not touch `ObjectInspectorPage`.
- Refactor #500 and older #486/#477 are handoff/docs-oriented and do not overlap this hunk.

Cross-lane dependencies:
- Body indexing belongs to Search lane/#494 and should not be added here.
- Weblink/Image identity and media behavior remain Primitive lane-owned; universal Body editing must remain orthogonal to those identities.
- Any future generic List/Gallery Body excerpt belongs to Database/View presentation rather than this Phase 1 host-semantic slice.

## Next actions
1. Check PR #503 CI; fix only failures caused by this slice, then squash-merge when green and mergeable.
2. Verify the shared side peek / center peek / full-page routes all consume `ObjectInspectorPage`/the same shared Body content contract; add a focused routing regression only if current coverage does not already prove it.
3. Verify ordinary/custom Object and Daily Note Body regressions remain covered; add only the smallest missing regression.
4. If those Phase 1 acceptance points are fully covered, update/close #481 Phase 1 status and hand off Body indexing to Search lane rather than implementing FTS here.
5. For further Object-lane work, use current #56/#484 core semantics; do not resume #155/#245/#249 implementation in this lane under the obsolete pre-seven-lane routing.

## Stop reason
Current implementation slice is open in PR #503 and awaiting CI. No additional production change was started because the next #481 step depends on validating shared opening-host coverage against current routes/tests; continue that audit independently if CI remains pending and runtime permits.
