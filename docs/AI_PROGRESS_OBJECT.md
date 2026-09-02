# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope

Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current integration state

`main` contains the major Object/Relation foundations, Database/View integration services, shared Object-detail contracts through #99/#100, safe block-level Body mutation through #101, Daily Note calendar navigation through #102, rich Body block/reference contracts through #103, and Daily Note calendar-to-shared-detail composition through #104.

Recent merged Object slices include #82/#85/#86/#87 collection semantics/integration services, #88/#89/#94 multi-View management/overflow, #90/#92/#98 Object opening-mode persistence/settings/resolution, #91 Value -> Weblink promotion UI, #93/#95/#97/#99/#100 shared Object detail editing/input/presentation, #96 `GenericDatabasePageServices`, #101 Body block editing, #102 Daily Note navigation, #103 rich block contracts/reference indexing, and #104 shared-detail Daily Note navigation composition.

PR #105 (`feature/object-body-block-presentation`) is the active Object PR. PR #83 remains closed/unmerged and is not active.

## Checkpoints completed in the latest sustained run

1. **Landed rich Object Body block contracts — PR #103**
   - Added stable known Body block type/attribute names while retaining string-based persisted types for forward compatibility.
   - Added typed factories for heading/checklist/code/divider/Object reference/Database View/Image/File blocks.
   - Added fail-closed validation for known rich payloads and duplicate document block ids while unknown future kinds remain accepted.
   - Added `ObjectBodyReferenceIndex` for unique embedded Object, Database/View and asset ids.
   - Latest head `eb0454e7466e38cdbd7252ca479f8920dceb8703` passed Flutter CI #541 (Drift generation, `flutter analyze`, tests) and PR #103 squash-merged as `32ab0dd7b57349060c4a98c5fad80573be19cca3`.

2. **Landed Daily Note navigation -> shared Object detail composition — PR #104**
   - Added `DailyNoteDetailNavigationService` combining previous/today/next `DailyNoteNavigationService` calls with `ObjectDetailContentLoader`.
   - Daily Notes continue to use normal Object detail content rather than a note-specific editor/state silo.
   - Flutter CI #542 passed on head `795fbdc39b1363b961113b19f18b1f724b739560`; PR #104 squash-merged as `60b2194bfcf602a7001c426b9459a3468126f092`.

3. **Prepared shared rich Body block presentation — PR #105**
   - Added widget-independent `ObjectBodyBlockPresenter` and presentation kinds for text, heading, checklist, code, divider, Object reference, Database View, asset and unknown blocks.
   - Heading/checklist/code metadata is interpreted centrally while Flutter layout remains outside the domain layer.
   - Unknown future blocks remain opaque/preserved rather than being flattened or guessed.
   - Added focused presentation/order tests.

4. **Kept the Milestone A hotspot safe**
   - `GenericDatabasePage` remains the highest-priority integration surface, but broad whole-file replacement is still an avoidable corruption/conflict risk in this runtime.
   - All slices in this run are additive Object-owned files and do not edit Relation lifecycle/index code or the large UI hotspots.

## Work in progress

- PR #105 is awaiting latest-head Flutter CI. Fix any branch-caused analyze/test failure, then merge when green.

## Exact next actions

1. Validate/land PR #105.
2. In a patch-capable implementation environment, wire `GenericDatabasePageServices` into the real `GenericDatabasePage`: collection-aware reload/create, Board `onCreateInGroup`, canonical Relation picker/editor, and collection settings.
3. Add page/widget regression coverage proving Database membership resolves before View projection and creation targets the configured ObjectType.
4. Wire `ObjectOpenPresentationService.resolve()` into real View navigation and route side peek / center peek / full page while preserving Database/View context.
5. Replace remaining ad-hoc Object-detail Property display/editor branching with the merged shared presenter/editor/input contracts when large UI surfaces can be safely patched.
6. Build real block UI incrementally on `ObjectBodyBlockEditService`, rich block contracts, and `ObjectBodyBlockPresenter`; never flatten unknown/rich blocks through the paragraph adapter.
7. Expose previous/today/next Daily Note controls through shared Object navigation using #104 rather than a note-specific data path.

## Cross-lane boundaries

- Relation lifecycle, bidirectional integrity, target/source validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation stay Relation-owned.
- Object UI consumes canonical Relation APIs and does not duplicate validation/index lifecycle.
- `GenericDatabasePage`, Object detail UI, Database collection integration, Board create UI, Value promotion, Body/block editing, Daily Notes and multi-View UX are Object-owned.
- #103/#104/#105 are additive Object-only work and do not modify Relation-owned lifecycle/index code.

## Validation

- Earlier merged Object integration slices passed their relevant PR CI as recorded in history.
- #103 latest head: Flutter CI #541 success before merge.
- #104 head: Flutter CI #542 success before merge.
- #105: latest-head CI pending at handoff update.
- This connector runtime does not expose a local Flutter SDK, so executable validation is delegated to GitHub Actions.

## Risks / blockers

- No product/design blocker is active.
- `GenericDatabasePage` remains the main Milestone A integration hotspot; broad direct whole-file replacement is an avoidable corruption/merge risk in this runtime.
- `ObjectInspectorPage` has a similar risk for broad navigation/detail rewrites.
- User-facing Relation writes must stay on canonical Relation services.
- Rich Body documents must never be flattened by the paragraph-safe editor.

## Stop reason

Continue while PR #105 validation or another independent safe Object slice remains actionable. Once independent additive slices are exhausted, the next materially higher-priority work is the large `GenericDatabasePage`/Object navigation UI integration that requires patch-capable editing; stop under the AGENTS.md runtime/sequencing criterion rather than attempting a risky whole-file rewrite.
