# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current integration state
`main` currently ends at `c3a6b47992865cecf814d3a0a1b67d9e4287730d` and includes the major Object/Relation foundations, Database/View integration services, multi-View management, opening-mode services, shared Object detail contracts, safe Body block persistence/presentation, Daily Note navigation, shared Flutter Body/Property/Daily Note widgets, and PR #107 block insert/remove/move action controls.

The highest-priority Milestone A work remains real `GenericDatabasePage` integration, but that large hotspot still requires a patch-capable environment to edit safely. No competing Relation PR is currently open.

## Active branch / PR
- Branch: `feature/object-body-reference-inserts`
- PR: #108 — `Add typed Object Body reference insertion`
- Latest implementation head before this handoff update: `a4b0fb75b6890bbeeba0ebec6c133e47f17319a6`
- PR is open and mergeable.

## Checkpoints completed in this sustained run

1. **Diagnosed and fixed PR #108 CI failure**
   - Flutter CI #580 passed dependency install, Drift generation, and `flutter analyze` with no issues.
   - 373 tests passed and exactly one new test failed: invalid asset reference construction threw synchronously before `expectLater` could observe the controller Future.
   - Changed `ObjectBodyReferenceInsertController.insert()` / `insertAfter()` to async Future boundaries so request validation errors are consistently awaitable while still occurring before persistence.

2. **Moved reference block id allocation into the Object application boundary**
   - Added `ObjectBodyReferenceInsertResult` and `insertAllocated()` / `insertAfterAllocated()`.
   - The controller reads the latest Body and uses `ObjectBodyBlockIdAllocator` with semantic prefixes (`object-ref`, `database-view`, `image`, `file`).
   - Shared hosts no longer need to invent their own reference block identity policy.
   - Under concurrent edits, the underlying latest-read editor still fails closed on a reused id or missing anchor.
   - Added focused tests for collision-free semantic ids and returned persisted identity.

3. **Added persisted payload-preserving block duplication**
   - Added `ObjectBodyBlockDuplicateService`.
   - It duplicates the latest persisted source block immediately after itself, assigns a new collision-free identity, and preserves text plus all known/unknown attributes.
   - Missing/blank sources fail without rewriting Body state.
   - Added regression tests covering order, stable identity, unknown future payloads, and fail-closed behavior.

4. **Extended shared per-block action chrome**
   - `ObjectBodyBlockActionBar` now optionally exposes duplicate and explicit reference-insert actions in addition to move, generic insert, and delete.
   - Reference insertion launches `ObjectBodyReferenceInsertMenuButton`, preserving the rule that menu selection only starts target selection and never persists an unresolved placeholder.
   - All new actions remain callback-only; persistence stays in Object-owned services.
   - Added widget tests for duplicate dispatch, reference kind dispatch, and optional action omission.

5. **Kept PR scope cross-lane safe**
   - No Relation lifecycle/index changes.
   - No `GenericDatabasePage`, Object inspector, schema, or migration changes.
   - No destructive data operations.

## Validation
- PR #108 CI #580 on earlier head `2e48a0a35fd25564492eed05221f1f3d1625e577`: Drift generation success, `flutter analyze` success, 373 tests passed / 1 failed. The only failure was the new synchronous validation expectation described above.
- The failure was repaired in `0c10baaf5c67a67ac8225f15c5efed59b3bc6a2f`, then additional safe Body checkpoints were added.
- Latest implementation head before handoff commit: `a4b0fb75b6890bbeeba0ebec6c133e47f17319a6`; latest-head CI may still be queued/not yet visible.
- This connector runtime does not expose a local Flutter SDK, so executable validation is delegated to GitHub Actions.

## Work in progress
- Do not merge PR #108 until CI on the final handoff head completes successfully or any branch-caused failure is fixed.
- If latest CI fails, inspect exact job logs and repair on the same branch.

## Exact next actions
1. Check final-head CI for PR #108; fix any branch-caused analyze/test failure and merge when green.
2. After #108 lands, update repository-wide `docs/AI_PROGRESS.md` to include typed reference insertion, controller-owned id allocation, persisted duplication, and duplicate/reference action chrome.
3. In a patch-capable environment, wire generic + reference Body actions through `ObjectBodyDocumentView.blockActionsBuilder` in the real shared Object detail host; use `ObjectBodyBlockDuplicateService` and `ObjectBodyReferenceInsertController` rather than recreating persistence logic.
4. Continue Milestone A integration: `GenericDatabasePageServices` -> real `GenericDatabasePage` for Database-first collection reload/create, Board create-in-group, canonical Relation picker/editor, and collection settings.
5. Integrate `ObjectDetailPropertyView` / `ObjectBodyDocumentView`, `DailyNoteNavigationBar`, and `ObjectOpenPresentationService` into real hosts/navigation.
6. Add `RichText/Document Property` only when broad enum/switch/query/UI changes can be safely patched across existing hotspots.

## Cross-lane boundaries
- Relation lifecycle, bidirectional integrity, target/source validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation remain Relation-owned.
- User-facing Relation writes must use canonical Relation APIs; Object UI must not duplicate Relation validation/index lifecycle.
- PR #108 is Object/Body-only and does not modify Relation lifecycle/index code, `GenericDatabasePage`, Object inspector, schema, or migrations.

## Risks / blockers
- No product/design blocker is active.
- `GenericDatabasePage` and real Object detail/navigation hosts remain large existing hotspots; broad whole-file replacement is unsafe in this connector runtime.
- Rich Body documents must never be flattened through the paragraph-safe adapter.
- Reference-bearing blocks require explicit target selection; generic insertion must not create unresolved placeholders.
- Automatic reference id allocation is intentionally optimistic across concurrent edits; the final latest-read insert remains the integrity boundary and fails closed on collision.

## Stop reason
This run progressed through multiple coherent Object checkpoints rather than stopping on the first CI result: it diagnosed/fixed #580, moved reference id allocation into the Object application boundary, added persisted payload-preserving block duplication, and extended shared action chrome with duplicate/reference flows plus regression coverage. The remaining immediately higher-value work requires broad patching of the real Object detail/`GenericDatabasePage` hosts, which is unsafe through whole-file replacement in this runtime. Final PR #108 CI still needs to complete before merge, so the current limit is the runtime/tooling sequencing constraint from `AGENTS.md`, not mere CI waiting or completion of one slice.
