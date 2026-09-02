# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current integration state
`main` includes the major Object/Relation foundations, Database/View integration services, multi-View management, opening-mode services, shared Object detail contracts, safe Body block persistence/presentation, Daily Note navigation, shared Flutter Body/Property/Daily Note widgets, and PR #107 block insert/remove/move action controls.

PR #107 (`Add Object Body block action controls`) passed Flutter CI #574 on head `9c2c30b86bafb7bc652832a942a7b90fac867622` and squash-merged as `39fdc54b276a5241eb2fd07214b868d1abb0e466`.

The highest-priority Milestone A work remains real `GenericDatabasePage` integration, but that large hotspot still requires a patch-capable environment to edit safely.

## Active branch / PR
- Branch: `feature/object-body-reference-inserts`
- PR: #108 — `Add typed Object Body reference insertion`
- Latest head before handoff update: `70800ca86e85bd385fab2fd031bca9182eb71929`
- PR is open and mergeable; latest-head CI had not appeared yet when checked.

## Checkpoints completed in this run
1. **Validated and merged PR #107**
   - Flutter CI #574 completed successfully.
   - Merged #107 to `main` as `39fdc54b276a5241eb2fd07214b868d1abb0e466`.

2. **Added stable Body block identity utilities — PR #108**
   - Added deterministic `ObjectBodyBlockIdAllocator` that avoids collisions against current document ids and normalizes semantic prefixes.
   - Added `ObjectBodyBlockDuplicator` that assigns a new identity while preserving type/text and known/unknown attributes.

3. **Added typed reference-bearing Body insert contracts — PR #108**
   - Added explicit Object, Database/View, Image, and File insert requests.
   - Requests create fully-configured reference blocks only after targets are selected and fail closed for invalid ids.
   - Generic text-block insertion remains separate from reference target-selection flows.

4. **Added persisted reference insert controller — PR #108**
   - Added `ObjectBodyReferenceInsertController` that appends or inserts after an anchor using the existing latest-read `ObjectBodyBlockEditService`.
   - Invalid requests fail before persistence and do not mutate stored Body state.

5. **Added shared reference insertion chrome — PR #108**
   - Added `ObjectBodyReferenceInsertKind` and `ObjectBodyReferenceInsertMenuButton`.
   - The menu only starts Object / Database-View / Image / File target-selection flows; selection alone never persists unresolved placeholder blocks.

6. **Added focused regression coverage — PR #108**
   - Block id allocation, prefix normalization, duplicate payload preservation and invalid identity rejection.
   - Typed reference construction and fail-closed invalid target ids.
   - Persisted append/insert-after reference insertion and no mutation on invalid requests.
   - Shared reference-menu labels and selection callback.

## Validation
- #107 Flutter CI #574: success before merge.
- #108 latest head at handoff preparation: `70800ca86e85bd385fab2fd031bca9182eb71929`; workflow run was not yet visible on the first check.
- This connector runtime does not expose a local Flutter SDK, so executable validation is delegated to GitHub Actions.

## Exact next actions
1. Check latest-head CI for PR #108; fix branch-caused analyze/test failures, then merge when green.
2. In a patch-capable environment, wire generic + reference Body insert controls through `ObjectBodyDocumentView.blockActionsBuilder` in the real shared Object detail host.
3. Continue Milestone A integration: `GenericDatabasePageServices` -> real `GenericDatabasePage` for Database-first collection reload/create, Board create-in-group, canonical Relation picker/editor, and collection settings.
4. Integrate `ObjectDetailPropertyView` / `ObjectBodyDocumentView`, `DailyNoteNavigationBar`, and `ObjectOpenPresentationService` into real hosts/navigation.
5. Add `RichText/Document Property` only when broad enum/switch/query/UI changes can be safely patched across existing hotspots.

## Cross-lane boundaries
- Relation lifecycle, bidirectional integrity, target/source validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation remain Relation-owned.
- User-facing Relation writes must use canonical Relation APIs; Object UI must not duplicate Relation validation/index lifecycle.
- PR #108 is Object/Body-only and does not modify Relation lifecycle/index code, `GenericDatabasePage`, Object inspector, schema, or migrations.

## Risks / blockers
- No product/design blocker is active.
- `GenericDatabasePage` and real Object detail/navigation hosts remain large existing hotspots; broad whole-file replacement is unsafe in this connector runtime.
- Rich Body documents must never be flattened through the paragraph-safe adapter.
- Reference-bearing blocks require explicit target selection; generic insertion must not create unresolved placeholders.

## Stop reason
This run completed multiple safe Object checkpoints: merged #107 with green CI, added stable block identity/duplication, typed reference-bearing block requests, persisted reference insertion, shared reference-selection chrome, and regression coverage in PR #108. The remaining higher-priority host/page integration requires patch-capable editing of large existing files. PR #108 still requires latest-head GitHub Actions validation before merge, so the run stops on the runtime/tooling sequencing constraint rather than because a single PR completed.
