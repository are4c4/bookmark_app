# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope

Own Object/ObjectType architecture, Property value semantics, Database/View integration that is primarily Object-centric, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

## Current branch

`feature/object-promotion-contracts`

Latest relevant commits:
- `b4b3845` — PR #61 merged: Value / Object Relation / Computed semantics
- `df08e74` / `4f19b14` — reversible Value-to-Object promotion planning + tests
- `e7c4036` / `5c73986` — versioned Object Body block model + tests
- `25999e2` / `bab99ef` — ObjectType defaults resolution contract + tests

## Checkpoints completed in this run

1. **Property semantics landed**
   - Resolved stale handoff conflicts on PR #61.
   - Confirmed Flutter CI #328 passed for the functional Property-semantics head.
   - Merged PR #61 into `main` as `b4b3845`.
   - `ObjectPropertySemantics` now distinguishes Value, Object Relation, and Computed without changing persistence strings or existing data.

2. **Reversible Value -> Object promotion contract**
   - Added side-effect-free `ObjectValuePromotionPlan` / `ObjectValuePromotionPlanner`.
   - Promotion accepts only Value properties.
   - Original scalar value is preserved by default.
   - Clearing the source value is explicitly marked as requiring destructive confirmation.
   - No Relation-store writes are implemented here; execution remains a later integration step after Relation APIs are stable.

3. **Forward-compatible Object Body / Block model**
   - Added versioned `ObjectBodyDocument` with ordered blocks.
   - Block type is persisted as a string so unknown future block kinds can round-trip without being coerced or lost.
   - Invalid block payloads are rejected instead of silently corrupting content.
   - This is domain-only; persistence/editor integration is intentionally deferred.

4. **ObjectType defaults contract**
   - Added `ObjectTypeDefaults`, `ObjectOpenMode`, and a resolver for the ObjectType > app-fallback portion of inheritance.
   - Database/View overrides are intentionally not stored in this Object-owned contract, preserving the architectural precedence `View > Database > ObjectType > app`.
   - Defaults cover visible Property ids, Property ordering, and Object opening mode.

## Validation

- PR #61 functional head (`4ac5ac1`) passed Flutter CI run #328 (`flutter analyze` + test workflow).
- Added focused tests:
  - `test/object_value_promotion_test.dart`
  - `test/object_body_test.dart`
  - `test/object_type_defaults_test.dart`
- This chat session only has GitHub connector access, so local `flutter analyze` / `flutter test` execution is unavailable. The new branch should use PR CI as executable validation.
- Changes after PR #61 are domain-only and do not touch Drift schema, existing bookmark/tag persistence, or Relation write lifecycle.

## Work in progress

- Open and validate the current branch PR.
- If CI reports failures caused by these domain contracts, fix them before integration.

## Exact next actions

1. Validate and land `feature/object-promotion-contracts` after CI is green.
2. Add a thin Object-owned detail-content model/component contract shared by side peek / center peek / full page, without owning navigation chrome.
3. Add persistence for `ObjectBodyDocument` in a backward-compatible, non-destructive slice; keep editor UI simple initially.
4. Persist ObjectType defaults only after confirming the smallest compatible storage location; avoid copying Database/View overrides into ObjectType data.
5. Add reusable Weblink ObjectType defaults/template and an explicit URL-value promotion mapper using the promotion plan.
6. Add Daily Note as a normal ObjectType with unique date semantics after Body/default foundations are persisted.
7. Keep Tag hierarchy lifecycle and Relation integrity changes in the Relation lane; Object lane may consume stable Relation APIs but should not duplicate them.

## Cross-lane dependencies / boundaries

- Relation lifecycle, bidirectional pair integrity, backlinks, relation write validation, and relation deletion/rename propagation belong to `docs/AI_PROGRESS_RELATION.md`.
- PR #62 currently owns bidirectional Relation pair integrity. This run deliberately avoided `object_store.dart` and `bidirectional_relation_store.dart`.
- Value-to-Object **execution** will eventually need Relation creation/write APIs; keep the current promotion layer as planning only until the Relation lane has landed its integrity work.
- Tag-as-Object hierarchy changes should be sequenced with Relation lane because hierarchy is represented through Relations.

## Blockers / risks

- No product blocker for the domain contracts in this run.
- Persisting Body/ObjectType defaults will require careful compatibility with existing generic storage; do not introduce destructive migrations.
- Relation execution for promotions should wait for stable Relation validation APIs to avoid cross-lane conflicts.

## Stop reason

This run completed four safe checkpoints. The next meaningful slices (Body persistence and promotion execution) begin to touch shared persistence/Relation integration and should be taken after CI validates the current domain branch and the concurrent Relation integrity branch stabilizes. This matches the cross-lane sequencing / validation boundary in `AGENTS.md` rather than stopping because a single PR or CI is pending.
