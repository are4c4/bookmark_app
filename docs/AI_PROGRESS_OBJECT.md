# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope

Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current integration state

`main` contains the major Object/Relation foundations, Database/View integration services, shared Object-detail contracts through #99/#100, safe block-level Body mutation through #101, Daily Note calendar navigation through #102, rich Body block/reference contracts through #103, Daily Note calendar-to-shared-detail composition through #104, and shared Body block presentation metadata through #105.

Recent merged Object slices include #82/#85/#86/#87 collection semantics/integration services, #88/#89/#94 multi-View management/overflow, #90/#92/#98 Object opening-mode persistence/settings/resolution, #91 Value -> Weblink promotion UI, #93/#95/#97/#99/#100 shared Object detail editing/input/presentation, #96 `GenericDatabasePageServices`, #101 Body block editing, #102 Daily Note navigation, #103 rich block contracts/reference indexing, #104 shared-detail Daily Note navigation composition, and #105 shared rich-block presentation.

No Object PR remains open from this run. PR #83 remains closed/unmerged and is not active.

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

3. **Landed shared rich Body block presentation — PR #105**
   - Added widget-independent `ObjectBodyBlockPresenter` and presentation kinds for text, heading, checklist, code, divider, Object reference, Database View, asset and unknown blocks.
   - Heading/checklist/code metadata is interpreted centrally while Flutter layout remains outside the domain layer.
   - Unknown future blocks remain opaque/preserved rather than being flattened or guessed.
   - Flutter CI #547 passed Drift generation, `flutter analyze`, and tests on latest head `06beba7089c5bcfd2818e89819873c1ad0e96a9a`.
   - PR #105 squash-merged as `273711991160abde872948e2cb71b99d52b7aff2`.

4. **Kept the Milestone A hotspot safe and assessed the next Milestone D slice**
   - `GenericDatabasePage` remains the highest-priority integration surface, but broad whole-file replacement is still an avoidable corruption/conflict risk in this runtime.
   - `RichText/Document Property` was scoped and found to require edits across `ObjectPropertyType`, query/group/Board/editor behavior, tests, and the large `GenericDatabasePage` hotspot; it is not a safe narrow additive slice under the current whole-file connector.
   - All merged slices in this run stayed Object-owned and did not edit Relation lifecycle/index code.

## Work in progress

- No Object PR is open from this run.
- The next meaningful work is real UI integration rather than another isolated domain primitive.

## Exact next actions

1. In a patch-capable implementation environment, wire `GenericDatabasePageServices` into the real `GenericDatabasePage`: collection-aware reload/create, Board `onCreateInGroup`, canonical Relation picker/editor, and collection settings.
2. Add page/widget regression coverage proving Database membership resolves before View projection and creation targets the configured ObjectType.
3. Wire `ObjectOpenPresentationService.resolve()` into real View navigation and route side peek / center peek / full page while preserving Database/View context.
4. Replace remaining ad-hoc Object-detail Property display/editor branching with the merged shared presenter/editor/input contracts when large UI surfaces can be safely patched.
5. Expose previous/today/next Daily Note controls through shared Object navigation using #104 rather than a note-specific data path.
6. Build real block UI incrementally on `ObjectBodyBlockEditService`, #103 rich-block contracts/reference index, and #105 `ObjectBodyBlockPresenter`; never flatten unknown/rich blocks through the paragraph adapter.
7. Add `RichText/Document Property` only in a patch-capable environment because the enum introduction has broad switch/UI/query impact including the page hotspot.

## Cross-lane boundaries

- Relation lifecycle, bidirectional integrity, target/source validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation stay Relation-owned.
- Object UI consumes canonical Relation APIs and does not duplicate validation/index lifecycle.
- `GenericDatabasePage`, Object detail UI, Database collection integration, Board create UI, Value promotion, Body/block editing, Daily Notes and multi-View UX are Object-owned.
- #103/#104/#105 are additive Object-only work and do not modify Relation-owned lifecycle/index code.

## Validation

- Earlier merged Object integration slices passed their relevant PR CI as recorded in history.
- #103 latest head: Flutter CI #541 success before merge.
- #104 head: Flutter CI #542 success before merge.
- #105 latest head: Flutter CI #547 success before merge.
- This connector runtime does not expose a local Flutter SDK, so executable validation was delegated to GitHub Actions.

## Risks / blockers

- No product/design blocker is active.
- `GenericDatabasePage` remains the main Milestone A integration hotspot; broad direct whole-file replacement is an avoidable corruption/merge risk in this runtime.
- `ObjectInspectorPage` has a similar risk for broad navigation/detail rewrites.
- `RichText/Document Property` is now known to have broad exhaustive-switch and UI/query impact, including the page hotspot, so it should be sequenced in a patch-capable environment.
- User-facing Relation writes must stay on canonical Relation services.
- Rich Body documents must never be flattened by the paragraph-safe editor.

## Stop reason

This run completed and merged three coherent Object checkpoints with green CI: rich Body block/reference contracts (#103), Daily Note calendar navigation composed into shared Object detail (#104), and shared rich Body block presentation (#105). Independent narrow additive work directly supporting Issue #56 is now exhausted for this runtime. The materially higher-priority remaining work is real `GenericDatabasePage`/Object navigation/block UI integration, plus the broad `RichText/Document Property` enum/UI/query change, all of which require safely patching large existing surfaces. Attempting whole-file rewrites would create avoidable corruption/cross-lane risk, so this run stops under the AGENTS.md tool/runtime/sequencing criterion.
