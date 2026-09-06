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
- Center-peek and full-page generic Database opening modes reuse `ObjectInspectorPage`; side peek still uses a separate `GenericDatabasePage._detail` Property/backlink surface and does not yet compose Body.

## Active checkpoint — #481 universal Body
Branch: `feature/object-universal-body-481`
PR: #503 `Make Object Body editable for every ObjectType`
Base main at branch creation: `844f6b77e7b6947bceaaf6986e6ff8182212e71b`
Latest implementation commit before this handoff refresh: `bde0c444d674e5a27cb10775e7ad4e1552dbe3f1`

Completed in this slice:
- verified latest seven-lane routing before editing; Object lane now owns #481/core #56 while #155/#245 primitive product behavior and #249 generic presentation are outside this lane;
- checked open PR ownership before touching `object_inspector_page.dart`; no current open PR overlapped the Body-edit hunk;
- removed only the system-type Body-edit restriction in the shared Inspector; all ObjectTypes now receive the existing shared Body edit actions;
- kept system Object title/Property/create identity guards unchanged;
- added `object_inspector_universal_body_test.dart`, proving Weblink and Image system Objects both expose the shared empty-Body insertion affordance and persist the first paragraph through `ObjectBodyStore`;
- audited opening-mode coverage: center peek and full page already render `ObjectInspectorPage`; side peek is a separate Property/backlink-only host without Body;
- recorded the side-peek parity gap on Issue #481 as a cross-lane sequencing point rather than broadening this patch into the Database/View hotspot;
- no Relation mutation/read semantics, primitive identity/services, search indexing, Database/View presentation, or schema/migration behavior changed.

Validation:
- Flutter CI #1691 passed maintainability guardrails/dependency setup/Drift generation but Analyze failed only because the new test omitted the `object_body_block_contracts.dart` import for `ObjectBodyBlockType`;
- fixed that test-only import in `bde0c444d674e5a27cb10775e7ad4e1552dbe3f1`; latest-head CI is expected to rerun;
- existing `object_inspector_body_actions_test.dart` covers ordinary/custom Object Body persistence/actions, and Daily Note host coverage already asserts the shared Body insertion affordance.

Hotspot ownership:
- Object lane owns only the patch-sized `_canEditBody` hunk for PR #503.
- Primitive PR #498 is service-only Image composition and does not touch `ObjectInspectorPage`.
- Refactor #500 and older #486/#477 are handoff/docs-oriented and do not overlap this hunk.
- `generic_database_page.dart` is a Database/View hotspot; do not add side-peek Body presentation there from Lane A without a clearly sequenced cross-lane patch.

Cross-lane dependencies:
- Body indexing belongs to Search lane/#494 and should not be added here.
- Weblink/Image identity and media behavior remain Primitive lane-owned; universal Body editing must remain orthogonal to those identities.
- Side-peek Body composition intersects Database/View presentation ownership. Reuse the canonical `ObjectBodyStore`/Body editor contract and avoid introducing a second persistence/editor path when Lane C wires parity.
- Any future generic List/Gallery Body excerpt belongs to Database/View presentation rather than this Phase 1 host-semantic slice.

## Next actions
1. Check the latest PR #503 CI after the import fix; fix only failures caused by this slice, then squash-merge when green and mergeable.
2. After #503 merges, treat Inspector universal editability as complete for Weblink/Image/custom/Daily Note and preserve existing identity guards.
3. Sequence side-peek Body parity with Database/View lane using the existing canonical Body contract; do not reconstruct the 2k-line `generic_database_page.dart` from Object lane merely to satisfy the visual host gap.
4. Hand Body indexing to Search lane/#494 rather than implementing FTS here.
5. For further Object-lane work, use current #56/#484 core semantics; do not resume #155/#245/#249 implementation in this lane under the obsolete pre-seven-lane routing.

## Stop reason
PR #503 remains the active Object-lane slice. Its first CI failure was a test-only missing import and is fixed; the latest head requires CI validation before merge. Independent opening-host audit is complete and identified side peek as a documented cross-lane presentation dependency rather than safe additional Lane-A production work.
