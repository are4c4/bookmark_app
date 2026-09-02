# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope

Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current integration state

`main` contains the major Object/Relation foundations, Database/View integration services, shared Object-detail contracts through #99/#100, safe block-level Body mutation through #101, and Daily Note calendar navigation through #102.

Recent merged Object slices include #82/#85/#86/#87 collection semantics/integration services, #88/#89/#94 multi-View management/overflow, #90/#92/#98 Object opening-mode persistence/settings/resolution, #91 Value -> Weblink promotion UI, #93/#95/#97/#99/#100 shared Object detail editing/input/presentation, #96 the `GenericDatabasePageServices` composition root, #101 Body block editing, and #102 Daily Note navigation.

PR #103 (`feature/object-body-rich-block-contracts`) is the active Object PR. It is additive Body/domain work and does not touch Relation lifecycle or the large page hotspots.

PR #83 remains closed/unmerged and is not active.

## Checkpoints completed in the latest run

1. **Added typed rich Body block creation contracts — PR #103**
   - Added stable known type/attribute names while retaining string-based persisted block types so unknown future kinds still round-trip.
   - Added `ObjectBodyBlockFactory` for heading, checklist, code, divider, Object reference, embedded Database/View, and Image/File asset blocks.
   - Embedded/reference ids fail closed when non-positive; heading levels are restricted to 1–3.

2. **Added known-block validation without breaking forward compatibility — PR #103**
   - Added `ObjectBodyBlockValidator` for known payload requirements and document-level duplicate-id detection.
   - Unknown future block kinds remain accepted rather than being coerced or rejected.
   - Pre-CI review caught and corrected Dart switch-case termination before executable validation.

3. **Added embedded Body reference indexing — PR #103**
   - Added `ObjectBodyReferenceIndex` to inventory unique embedded Object, Database/View and asset ids from a Body document.
   - Unknown future reference-like payloads are not guessed into current semantics.
   - Added focused tests for factory/JSON behavior, validation, forward-compatible unknown blocks, reference extraction and deduplication.

4. **Re-checked the Milestone A patch-capability blocker**
   - `GenericDatabasePage` remains the highest-priority integration hotspot.
   - This runtime still has connector-level whole-file writes rather than safe textual patching for large existing files, so no broad page rewrite was attempted.
   - The independent Body slice stays within Issue #56 and does not compete with Relation-owned work.

## Work in progress

- PR #103 head `700fcdd7643abf806fc78c77656f086efb961b19` has Flutter CI #540 running. The workflow reached checkout/setup and will run dependency install, Drift generation, analyze and tests.
- Merge PR #103 only after latest-head CI succeeds; fix any branch-caused analyzer/test failure first.

## Exact next actions

1. Inspect Flutter CI #540 for PR #103; fix any branch-caused failure and merge when green.
2. In a patch-capable implementation environment, wire `GenericDatabasePageServices` into the real `GenericDatabasePage`: collection-aware reload/create, Board `onCreateInGroup`, canonical Relation picker/editor, and collection settings.
3. Add page/widget regression coverage proving Database membership resolves before View projection and creation targets the configured ObjectType.
4. Wire `ObjectOpenPresentationService.resolve()` into real View navigation and route side peek / center peek / full page while preserving Database/View context.
5. Replace remaining ad-hoc Object-detail Property display/editor branching with `ObjectDetailPropertyPresenter`, `ObjectDetailValueEditor`, and `ObjectDetailValueInputCodec` when a patch-capable environment is available.
6. Build real block UI incrementally on top of `ObjectBodyBlockEditService` and PR #103 rich-block contracts; do not flatten unknown/rich blocks through the paragraph adapter.
7. Expose previous/today/next Daily Note navigation through shared Object-detail/navigation surfaces rather than introducing a note-specific data silo.

## Cross-lane boundaries

- Relation lifecycle, bidirectional integrity, target/source validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation stay Relation-owned.
- Object UI consumes canonical Relation APIs and does not duplicate their validation/index lifecycle.
- `GenericDatabasePage`, Object detail UI, Database collection integration, Board create UI, Value promotion, Body/block editing, Daily Notes and multi-View UX are Object-owned.
- #103 is additive Object/Body domain work and does not modify Relation-owned lifecycle/index code.

## Validation

- Earlier merged #97/#98/#99/#100/#101/#102 and preceding Object integration slices passed their relevant PR CI as recorded in history.
- PR #103 head `700fcdd7643abf806fc78c77656f086efb961b19`: Flutter CI #540 in progress at latest handoff update.
- This connector runtime does not expose a local Flutter SDK, so executable validation is delegated to GitHub Actions.

## Risks / blockers

- No product/design blocker is active.
- `GenericDatabasePage` remains the main Milestone A integration hotspot. Broad direct whole-file replacement is an avoidable corruption/merge risk in this runtime.
- The existing full-page `ObjectInspectorPage` has similar whole-file patch risk for large UI rewrites.
- User-facing Relation writes must stay on canonical Relation services.
- Rich Body documents must never be flattened by the paragraph-safe editor; #101 supplies narrow mutations and #103 supplies typed rich-block/reference contracts while retaining unknown-block compatibility.

## Stop reason

The run should continue while PR #103 CI or another safe Object slice remains actionable. If #103 is green, merge it and update repository-wide handoff because integrated state changes. If the remaining higher-priority work is only the large page/UI hotspot that cannot be safely patched in this runtime, stop under the AGENTS.md tool/runtime/sequencing criterion rather than attempting a risky whole-file rewrite.
