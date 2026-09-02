# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope

Own Object/ObjectType architecture, Property value semantics, Database/View integration that is primarily Object-centric, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

## Current branch / PR

- Branch: `feature/object-body-defaults-persistence`
- PR #65 — `Persist Object Body and ObjectType defaults`
- Latest implementation checkpoints include commits through `0c819a6` (Weblink reuse test); this handoff update follows those commits.
- Base `main` includes merged PR #64 at `3358cb6d`.

## Checkpoints completed in this run

1. **Validated and landed PR #64**
   - Confirmed Flutter CI #346 succeeded on PR #64.
   - Merged promotion planning, versioned Body model, ObjectType defaults contract, and shared detail content into `main`.

2. **Object Body persistence**
   - Added `ObjectBodyStore` with additive `object_bodies` storage keyed by global Object id.
   - Persists the versioned `ObjectBodyDocument` JSON contract without rewriting `generic_records` or Property data.
   - Object deletion cascades Body deletion; Body can also be cleared independently.

3. **ObjectType defaults persistence**
   - Added JSON serialization for `ObjectTypeDefaults`.
   - Added additive `object_type_defaults` storage keyed by ObjectType id.
   - Stores only ObjectType-owned defaults; Database/View overrides remain outside this layer.
   - Writing empty defaults clears the persisted override row.

4. **Reusable Weblink Object**
   - Added idempotent `Weblink` system ObjectType with a URL Value Property.
   - Existing Bookmark storage remains unchanged.
   - Added URL Value -> Weblink promotion planning that preserves the original scalar URL.
   - Added `findOrCreate` so sequential reuse of the same normalized URL returns the existing Weblink Object rather than creating another one.

5. **Daily Note open-or-create**
   - Added Daily Note as a normal system ObjectType with a Date Value Property.
   - Added additive `daily_note_registry` enforcing one registered Daily Note per workspace/local calendar date.
   - `openOrCreate` reuses a registered note, adopts matching pre-registry Objects, or creates a normal Object and sets its date.
   - Daily Note defaults to full-page opening and remains compatible with the general Body/Property/Relation model.

6. **Shared Object detail loading**
   - Added `ObjectDetailContentLoader` to compose Object + ObjectType + persisted Body + Formula/Rollup values into one `ObjectDetailContent` payload.
   - Side peek, center peek, and full-page surfaces can consume this common payload without duplicating data logic.
   - Relation/backlink fetching remains outside the loader and can be composed from Relation-lane APIs.

## Tests added / updated

- `test/object_body_store_test.dart`
- `test/object_type_defaults_store_test.dart`
- `test/weblink_object_service_test.dart`
- `test/daily_note_service_test.dart`
- `test/object_detail_content_loader_test.dart`

## Validation

- PR #64 head passed Flutter CI #346 before merge.
- PR #65 is open and mergeable; CI has been triggered repeatedly as checkpoints were pushed. The latest complete executable validation must be read from the newest PR #65 head before merge.
- This chat has GitHub connector access but no local Flutter runtime, so `flutter analyze` / `flutter test` cannot be executed locally here.
- All new persistence is additive (`CREATE TABLE IF NOT EXISTS`); there is no destructive schema migration or Bookmark/Tag rewrite.

## Work in progress

- Validate PR #65 latest head and fix analyzer/test failures caused by this branch.
- Do not merge PR #65 until its latest-head CI is green.

## Exact next actions

1. Inspect the newest PR #65 Flutter CI run; fix failures caused by Object-lane changes, then merge when green.
2. Refresh from latest `main` after Relation PR #66 if it lands first; avoid force-merging shared handoff conflicts.
3. Connect `ObjectDetailContentLoader` to one existing Object detail presentation surface, then reuse the same content component for other opening modes.
4. Add a thin Body editor/rendering slice using `ObjectBodyStore`, starting with paragraph text and preserving unknown block kinds.
5. After Relation PR #66 stabilizes source/target validation and backlink helpers, implement the execution half of Value -> Object promotion as a small consumer of those APIs; preserve source Value by default.
6. Add Daily Note entry/navigation UX only through general Object detail/open-mode mechanisms; do not create a special note editor silo.
7. Keep Tag hierarchy mutation and Relation lifecycle work in the Relation lane.

## Cross-lane dependencies / boundaries

- Relation lifecycle, bidirectional pair integrity, source/target validation, backlink queries, and Relation deletion/rename propagation belong to `docs/AI_PROGRESS_RELATION.md`.
- Relation PR #66 (`feature/relation-write-integrity-v2`) is currently open on the same `3358cb6d` base and owns `object_store.dart` Relation integrity changes plus repository-wide handoff updates.
- This Object branch deliberately does not modify `object_store.dart`, `bidirectional_relation_store.dart`, or Relation lifecycle code.
- `docs/AI_PROGRESS.md` is not edited on PR #65 because Relation PR #66 is already updating that shared repository-wide handoff with the #64 integration state; avoid creating an avoidable cross-lane handoff conflict. If #65 merges after #66, update repository-wide state from latest `main` in the next integration checkpoint.
- Value-to-Object **link execution** should consume the stable Relation APIs after #66 rather than reimplement validation.

## Blockers / risks

- PR #65 still requires latest-head executable CI validation before merge.
- Connecting detail UI may touch files with broader presentation ownership; refresh latest `main` and keep the first integration slice narrow.
- Daily Note uniqueness is enforced through the additive registry; any future external imports should adopt/register matching date Objects rather than bypass the service.
- Weblink `findOrCreate` prevents ordinary sequential duplicates but does not yet add a database-level unique URL registry; add one only if concurrent creation becomes a real requirement.

## Stop reason

This run completed six new Object-lane checkpoints after landing PR #64. The remaining immediate gate is executable validation of PR #65's latest head; the next deeper integration step (Value-to-Object Relation execution) is intentionally sequenced after concurrent Relation PR #66 stabilizes its write-integrity APIs. This is a validation/cross-lane sequencing boundary under `AGENTS.md`, not a stop caused merely by opening one PR or by queued CI.
