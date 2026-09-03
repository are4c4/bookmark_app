# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current integration state
The main real-host Database/View opening path is integrated. `main` contains collection-aware `GenericDatabasePage`, canonical Relation editing, shared Object Property/Body inspector content, Body actions and Object/Database/View references, Daily Note navigation, Multi-View management, persisted Object opening modes, contextual side/center/full Object opening, explicit side-peek → full-page promotion, and regression coverage that promotion/editing continues to operate on the same global Object.

The active Object slice now converges the real Database side peek onto the same shared Property presentation used by center/full Object detail. It also exposes the already-existing canonical `RelationMutationService` from the Database page composition root after auditing a concrete host correctness gap: the side-peek delete button still uses low-level record deletion and therefore must be moved to the Relation-safe Object deletion path in the next focused host edit.

## Active branch / PR
- Branch: `feature/object-side-peek-shared-property-host`
- PR: #146 — `Use shared Property rows in Database side peek`
- Latest head at this handoff: `85cd6adda23eb38c62555b2e09f19f84e257ee1c`
- PR is open and mergeable.
- Flutter CI #704 is running on the latest head.
- Base main at branch creation: `d26fef07184fb742eaf66e35d9e9e3ab0e3b2733` (#145).

## Checkpoints completed in the latest sustained run
1. Re-read `AGENTS.md`, Issue #56, `docs/AI_PROGRESS.md`, this Object handoff, latest PRs/commits/CI, and the exact current `GenericDatabasePage` host.
2. Overcame the previous connector retrieval blocker by reading the 67 KB hotspot in exact line ranges / blob form, reconstructing from the latest blob SHA, and diff-auditing the resulting branch before continuing.
3. Wired production `GenericDatabasePage._detail(...)` Property rows to `ObjectDetailContent` + `ObjectDetailPropertyPresenter` + `ObjectDetailPropertyView` while preserving Property reorder, non-computed edit-on-tap, canonical Relation chips, title edit, backlinks, pane sizing, full-page promotion, delete/close, and active View context.
4. Extended the existing real side-peek Value edit regression to assert the shared `ObjectDetailPropertyView` is actually consumed while retaining same-global-Object persistence coverage.
5. Added a real side-peek Formula regression proving shared computed presentation renders the derived value and remains read-only.
6. Audited the side-peek delete path and found it still calls low-level `_store.deleteRecord(record.id)`, bypassing incoming Relation cleanup. Confirmed `RelationMutationService.deleteObject(...)` is explicitly the Relation-safe path for Object-detail consumers.
7. Exposed the same canonical `RelationMutationService` instance already shared by Board creation and Relation editing through `GenericDatabasePageServices.relationMutations`; no new Relation abstraction or lifecycle implementation was added.
8. Added composition-root coverage proving Relation-safe deletion through page services removes the target Object and detaches surviving incoming Relation values.
9. Updated PR #146 description to reflect shared Property convergence, computed read-only coverage, and preparation for Relation-safe side-pane deletion.

## Exact next actions
1. Inspect latest Flutter CI #704 for PR #146; fix any branch-caused analyze/test failure.
2. Wire the real side-peek delete button to `_pageServices.relationMutations.deleteObject(...)` using `widget.repository.workspaceId`, the current collection target `_objectType.id`, and `record.id`; preserve close/reload/error UX.
3. Add a real `GenericDatabasePage` side-peek regression where another Object has an incoming Relation to the selected Object; delete through the side-pane UI and prove the selected Object is removed and the surviving Relation value is detached.
4. Re-run/inspect CI after that host wiring and diff-audit `GenericDatabasePage` so no unrelated hotspot behavior changes.
5. Merge #146 when latest head is green.
6. After merge, refresh `docs/AI_PROGRESS.md` because the repository-wide real-host integration state will have changed, then continue with the next smallest duplicated side-pane detail element rather than a broad rewrite.
7. Keep Image/File Body selectors, RichText/Document Property, and manual collection membership deferred until their recorded prerequisites are met.

## Cross-lane boundaries
- Relation lifecycle, bidirectional integrity, source/target validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation remain Relation-owned.
- User-facing Relation Property writes and Object deletion that can affect incoming Relations must consume canonical Relation mutation APIs.
- This branch does not modify Relation lifecycle implementation; it only exposes/consumes the already-integrated facade from an Object-owned host.
- Body Object/Database/View references remain document references, not Relation Property writes.
- `GenericDatabasePage`, Object detail/navigation, Body editing/reference insertion, Daily Notes, and Multi-View UX remain Object-owned.

## Validation
- Production shared-Property diff was compared against exact branch base: only intended Property-presentation imports/content mapping/manual-row replacement were present in `GenericDatabasePage` (+46/-77 before later non-host commits).
- Existing real side-peek Value edit regression now asserts `ObjectDetailPropertyView` consumption.
- New Formula side-peek regression covers computed display/read-only behavior.
- New page-services test covers canonical Relation-safe Object deletion and incoming Relation detachment.
- Latest Flutter CI #704 is in progress at this handoff; Drift generation/analyze/full-test result is not yet final.

## Risks / blockers
- No product/design blocker or Relation implementation blocker is active.
- `GenericDatabasePage` remains a large hotspot; every whole-file replacement must use the exact current blob and be diff-audited before merge.
- The previously recorded retrieval blocker is no longer active: `fetch_blob`/line-range reads can retrieve the exact current hotspot. The remaining risk is ordinary whole-file replacement discipline, not inability to proceed.
- Do not regress canonical Relation writes, rich Body preservation, opening context, or side-pane Value editing while converging detail UI.

## Stop reason
Not stopped for product scope. This handoff was refreshed while PR #146 CI is running. The next concrete Object-host action is already specified: Relation-safe side-pane deletion plus real-host regression, followed by latest-head CI and merge.
