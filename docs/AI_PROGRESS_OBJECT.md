# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope

Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current integration state

`main` contains the major Object/Relation foundations, Database/View integration services, shared Object-detail contracts through #99/#100, safe block-level Body mutation through #101, and Daily Note calendar navigation through #102.

Recent merged Object slices include #82/#85/#86/#87 collection semantics/integration services, #88/#89/#94 multi-View management/overflow, #90/#92/#98 Object opening-mode persistence/settings/resolution, #91 Value -> Weblink promotion UI, #93/#95/#97/#99/#100 shared Object detail editing/input/presentation, #96 the `GenericDatabasePageServices` composition root, #101 Body block editing, and #102 Daily Note navigation.

PR #83 remains closed/unmerged and is not active.

## Checkpoints completed in the latest run

1. **Added and landed immutable block-level Body operations — PR #101**
   - Added `ObjectBodyEditor` with insert/update/remove/move operations.
   - Operations preserve unrelated unknown/future block types and attributes instead of routing rich documents through the paragraph-only adapter.
   - Duplicate ids, missing targets, and invalid indices fail closed.
   - Added focused pure-domain regression coverage.

2. **Added and landed persisted block-level Body editing — PR #101**
   - Added `ObjectBodyBlockEditService` over `ObjectBodyStore`.
   - Each mutation reads the latest persisted Body, applies one narrow immutable operation, then persists the resulting versioned document.
   - Regression coverage proves an embedded/future block round-trips unchanged and a failed edit leaves persisted Body untouched.
   - PR #101 head `33ba0a9cd42ac031d9a0100dfe52a543ff02ca4a` passed Flutter CI #531, then squash-merged as `e7a8f6aec9e9631f01e486a5f7671df7b3cd5010`.

3. **Added and landed Daily Note calendar navigation — PR #102**
   - Added `DailyNoteNavigationService` for today/previous/next navigation while keeping Daily Notes as ordinary Objects and delegating uniqueness/open-or-create behavior to `DailyNoteService`.
   - Adjacent dates are derived through calendar-date construction rather than fixed 24-hour arithmetic so DST boundaries do not change the intended note date.
   - Added coverage for previous/next/today, reuse of an existing date Object, and year-boundary navigation.
   - During pre-CI review, corrected the test fixture to construct `SystemObjectStore` with its actual `database` + `objectStore` dependencies.
   - Corrected head `b4034236a8abdf66ec807d15cabd9df2aeeab8f5` passed Flutter CI #533 and squash-merged as `bc6f5adc4d5c2c3a4d088de8cb84e09e1f9f4e16`.

4. **Re-checked the Milestone A patch-capability blocker**
   - Attempted to obtain a local patch-capable clone for the large `GenericDatabasePage` integration hotspot.
   - This runtime has no direct network/DNS access to GitHub (`Could not resolve host: github.com`), while the connector write API still replaces existing files whole.
   - Broad replacement of `GenericDatabasePage` therefore remains an avoidable corruption/conflict risk; no unsafe rewrite was attempted.

## Exact next actions

1. In a patch-capable implementation environment, wire `GenericDatabasePageServices` into the real `GenericDatabasePage`: collection-aware reload/create, Board `onCreateInGroup`, canonical Relation picker/editor, and collection settings.
2. Add page/widget regression coverage proving Database membership resolves before View projection and creation targets the configured ObjectType.
3. Wire `ObjectOpenPresentationService.resolve()` into real View navigation and route side peek / center peek / full page while preserving Database/View context.
4. Replace remaining ad-hoc Object-detail Property display/editor branching with `ObjectDetailPropertyPresenter`, `ObjectDetailValueEditor`, and `ObjectDetailValueInputCodec` when a patch-capable environment is available.
5. Build real block UI incrementally on top of `ObjectBodyBlockEditService`; do not flatten unknown/rich blocks through the paragraph adapter.
6. Expose previous/today/next Daily Note navigation through shared Object-detail/navigation surfaces rather than introducing a note-specific data silo.
7. Continue Milestone C/D only where the slice is independent and non-conflicting; do not let it displace the blocked Milestone A page integration priority.

## Cross-lane boundaries

- Relation lifecycle, bidirectional integrity, target/source validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation stay Relation-owned.
- Object UI consumes canonical Relation APIs and does not duplicate their validation/index lifecycle.
- `GenericDatabasePage`, Object detail UI, Database collection integration, Board create UI, Value promotion, Body/block editing, Daily Notes and multi-View UX are Object-owned.
- #101/#102 are additive Object-only integrations and do not edit Relation-owned lifecycle/index code.

## Validation

- Earlier merged #97/#98/#99/#100 and preceding Object integration slices passed their relevant PR CI as recorded in history.
- PR #101 head `33ba0a9cd42ac031d9a0100dfe52a543ff02ca4a`: Flutter CI #531 success before merge.
- PR #102 corrected head `b4034236a8abdf66ec807d15cabd9df2aeeab8f5`: Flutter CI #533 success before merge.
- This connector runtime does not expose a local Flutter SDK. Direct `git clone` was also unavailable because the execution container could not resolve GitHub, so executable validation was delegated to GitHub Actions.

## Risks / blockers

- No product/design blocker is active.
- `GenericDatabasePage` remains the main Milestone A integration hotspot. The available GitHub connector replaces existing files whole, and the local execution container cannot reach GitHub to obtain a patchable checkout. Broad direct replacement is therefore an avoidable corruption/merge risk.
- The existing full-page `ObjectInspectorPage` has similar whole-file patch risk for large UI rewrites.
- User-facing Relation writes must stay on canonical Relation services.
- Rich Body documents must never be flattened by the paragraph-safe editor; #101 establishes narrow block-level mutation primitives for that path.

## Stop reason

This run completed and merged three independent Object checkpoints with green CI: immutable Body block operations, persisted block editing, and Daily Note calendar navigation. The higher-priority remaining Milestone A/UI work requires safely patching large existing integration surfaces, but this runtime cannot obtain a patch-capable checkout and the connector only provides whole-file replacement. Further Milestone C/D expansion would broaden sequencing unnecessarily while that primary integration hotspot remains blocked. This matches the AGENTS.md tool/runtime/sequencing stop criteria.
