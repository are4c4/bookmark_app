# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope

Own Object/ObjectType architecture, Property value semantics, Object-centric detail/content integration, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

## Current branch / PR

- Branch: `feature/object-detail-editing-final`
- PR #67 — `Add shared Object detail editing and Daily Note bridge`
- Latest implementation checkpoint before this handoff: `0d3ed6a` (reusable Image Object facade tests)
- Base `main` includes merged PR #65 at `93d8cf1`.

## Checkpoints completed in this continuation

1. **Validated and landed PR #65**
   - Confirmed latest-head Flutter CI #372 succeeded.
   - Merged Object Body persistence, ObjectType defaults persistence, reusable Weblink Object, Daily Note open-or-create, shared detail loading, Weblink reuse, and paragraph-safe Body editing into `main`.

2. **Shared Object detail editing**
   - Added `ObjectDetailEditService` for title, ordinary Value Property, and paragraph-safe Body edits.
   - Every successful mutation reloads the same `ObjectDetailContent` payload so side/center/full-page hosts do not fork state.
   - Relation and Computed properties are explicitly rejected by this Object-owned Value editor; Relation mutation remains owned by the Relation lane.
   - Rich/unknown Body blocks cannot be silently overwritten by the simple text path.

3. **Daily Note detail bridge**
   - Added `DailyNoteDetailService`.
   - Daily Note open-or-create immediately resolves through the general `ObjectDetailContentLoader`.
   - Daily Notes reuse ordinary Object content rather than introducing a separate editor/data silo.

4. **Persisted ObjectType default resolution**
   - Added `ObjectTypeDefaultsService` to load persisted ObjectType defaults and resolve them over app fallback values.
   - Database/View overrides remain outside this service, preserving `View > Database > ObjectType > app`.

5. **Object detail session**
   - Added `ObjectDetailSession` and `ObjectDetailSessionLoader`.
   - A detail host can load shared content plus resolved ObjectType defaults in one Object-owned payload before Database/View presentation overrides are applied.

6. **Reusable Image Object facade**
   - Confirmed `CoreObjectBridge` already owns system key `image` and mirrors legacy photos into that ObjectType.
   - Added `ImageObjectService` that deliberately reuses the same system Image ObjectType instead of creating a duplicate.
   - Exposes stable `File` and `Note` Property definitions for generic Object surfaces.
   - Installs ObjectType defaults for visible/order/open-mode behavior without rewriting legacy photo data.

## Tests added / updated

- `test/object_detail_edit_service_test.dart`
- `test/daily_note_detail_service_test.dart`
- `test/object_type_defaults_service_test.dart`
- `test/object_detail_session_loader_test.dart`
- `test/image_object_service_test.dart`

## Validation

- PR #65 latest head `56b443c` passed Flutter CI run #372 before merge.
- PR #67 is open and mergeable as of its latest inspected state; latest-head executable CI must pass before merge.
- Intermediate #67 CI runs may be cancelled as checkpoints are pushed; merge only after the newest final head is green.
- This chat has GitHub connector access but no local Flutter runtime, so local `flutter analyze` / `flutter test` execution is unavailable.
- PR #67 adds no schema migration and does not modify Relation lifecycle code.

## Work in progress

- Validate PR #67 latest head and fix analyzer/test failures caused by Object-lane changes.
- Do not merge #67 until its latest-head CI is green.

## Exact next actions

1. Inspect latest PR #67 Flutter CI; fix branch-caused failures and merge when green.
2. Re-read latest `main` and Relation PR #66 after the Relation lane lands/rebases its stable Relation APIs. Do not implement competing Relation validation or lifecycle code.
3. Once stable `RelationMutationService` is on `main`, implement the execution half of Value -> Object promotion as a narrow consumer: create/reuse target Object, link through the Relation facade, preserve source Value by default, and only clear it after explicit destructive confirmation.
4. Connect `ObjectDetailSession` / `ObjectDetailEditService` to one existing Object detail presentation surface after refreshing latest UI ownership; then reuse the same content component for side peek / center peek / full page.
5. Add a Daily Note entry/navigation action through the same general Object-open mechanism rather than a special editor.
6. Keep Tag hierarchy mutation and Relation lifecycle work in the Relation lane.

## Cross-lane dependencies / boundaries

- Relation lifecycle, bidirectional pair integrity, source/target validation, backlink/read helpers, Relation index repair, rename/delete propagation, and Relation mutation belong to `docs/AI_PROGRESS_RELATION.md`.
- Relation PR #66 is concurrently adding stable Relation read/mutation/index facades. This Object branch does not edit those files.
- PR #67 deliberately does not modify `object_store.dart`, `bidirectional_relation_store.dart`, Relation service files, or Database/View navigation code.
- Value-to-Object **execution** is intentionally sequenced after stable Relation mutation APIs land. The existing promotion planner remains side-effect free and source-preserving by default.
- Image Object work reuses the existing `CoreObjectBridge` system key and does not replace its legacy-photo mirror lifecycle.

## Blockers / risks

- Latest-head PR #67 CI is still required before merge.
- Relation PR #66 must stabilize before promotion execution can safely consume its APIs.
- Direct UI integration can overlap broader Database/View presentation work; keep the first UI slice narrow and refresh latest `main` first.

## Stop reason

This continuation landed #65 and completed five additional Object implementation checkpoints on #67, including reuse of the existing Image Object architecture. Remaining high-value work now depends on either latest-head #67 executable validation, stable Relation mutation APIs for promotion execution, or careful UI ownership sequencing. This is a validation/cross-lane boundary under `AGENTS.md`, not a stop caused merely by opening a PR.
