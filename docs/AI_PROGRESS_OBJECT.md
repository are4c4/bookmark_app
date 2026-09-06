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
- Body is versioned/block-oriented and supports text/checklist/reference-style blocks plus Object and Database/View references.
- Daily Note uses the shared Object model with unique-by-date workflow semantics.
- Center peek and full-page generic openings already reuse `ObjectInspectorPage`; side peek remains a Database/View-owned alternate presentation surface.

## Active #481 implementation
PR #503 — `feature/object-universal-body-481`.

Production change:
- `ObjectInspectorPage._canEditBody(...)` is universal instead of gating system ObjectTypes;
- system title/Property/create identity guards remain unchanged;
- no Relation, primitive identity, search, storage, or Database/View presentation behavior changes.

Validation history:
- earlier CI runs caught only test issues (missing/unused imports), then reached Analyze green;
- CI #1839 on head `cfa6856d...` again passed maintainability, generation, and Analyze, then failed during Test;
- the widget regression had been reusing the same stateful Inspector identity while switching Object ids and depended on popup/scroll interactions;
- commit `57501d2031d524b7464934d309f9717629e9e8bb` stabilizes the regression: each Weblink/Image mount uses a fresh keyed Inspector, verifies the empty Body insert affordance, seeds one canonical paragraph through `ObjectBodyStore`, edits it through the real Inspector, and verifies persistence;
- Flutter CI #1861 is running for that head.

Hotspot ownership:
- open PR audit on 2026-09-07 found no other lane currently editing `object_inspector_page.dart`; #503 itself is the only current hotspot lease holder;
- avoid broad Inspector rewrites; the production hunk remains one line.

Cross-lane dependency:
- side peek still uses `GenericDatabasePage._detail` and does not render Body;
- generic Database/View presentation belongs to Lane C, so Lane A should not broaden #503 into `generic_database_page.dart`;
- Lane C should reuse the canonical Body/detail contract rather than create another persistence/editor path.

## Other Lane A WIP
PR #550 — preserve source Property order while duplicating ObjectTypes (#56/#484). Its latest CI reached Analyze green and failed during Test. Keep it independent from #503; do not mix schema-duplication work into universal Body.

## Next actions
1. Process Flutter CI #1861 for #503; if green and mergeable, squash merge.
2. If #503 remains non-mergeable because its old branch has diverged heavily from main, refresh/recreate the same patch from latest main without reconstructing unrelated shared-host content.
3. After #503 integration, verify ordinary/custom and Daily Note regressions remain green and leave side-peek composition to Lane C.
4. Then return to independent ObjectType core work such as #550 or another #56/#484 service/domain slice, avoiding Primitive/Database-View/Search/Storage/Refactor ownership.

## Stop condition for this checkpoint
CI #1861 is in progress for the stabilized #503 test. No unrelated speculative core abstraction was added while waiting; next execution should process that result first.
