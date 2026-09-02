# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current integration state
`main` now contains the major Object/Relation foundations, Database collection services, multi-View management, opening-mode services, shared Object detail/value editing contracts, Daily Note navigation, and rich Body block persistence/presentation/action/reference foundations through merged PR #108.

The highest-priority Object work is **real-host integration**, especially `GenericDatabasePage`, the actual Object detail/navigation host, and Daily Note navigation. Do not add another parallel abstraction when an existing service/widget can be consumed by the real host.

## Active branch / PR
- No active Object implementation PR after #108 merged.
- PR #108 — `Add typed Object Body reference insertion` — passed Flutter CI #590 on its functional head and was squash-merged as `273578d94f272e9e37169f02afafcf1d60c60082`.
- PR #110 was closed unmerged as redundant after refreshing current Issue/handoff state; collection-aware page loading/creation is already integrated through #86/#87 and composed by #96.
- Relation PR #109 is active in the Relation lane and should remain Relation-owned.

## Checkpoints completed in the latest Object run
1. **Refreshed source-of-truth before continuing**
   - Re-read Issue #56, `AGENTS.md`, current Object handoff, open PRs, and current `main`.
   - Detected that overnight work had already integrated #86/#87/#96 and advanced the project from foundation work to real-host integration.

2. **Closed redundant loader replay**
   - Closed PR #110 instead of duplicating already-integrated `GenericDatabaseCollectionPageLoader` / collection-aware creation foundations.
   - Preserved the integration-first rule from Issue #56.

3. **Resolved and merged #108**
   - #108's functional head had green Flutter CI #590.
   - Its merge conflict was caused by the lane handoff changing on `main`, not by overlapping Body implementation files.
   - Reset the PR copy of `docs/AI_PROGRESS_OBJECT.md` to current `main`; PR became mergeable.
   - Squash-merged #108 as `273578d94f272e9e37169f02afafcf1d60c60082`.
   - Integrated typed Object/Database/View/Image/File Body reference insertion, deterministic semantic block-id allocation, payload-preserving block duplication, and shared duplicate/reference action chrome without unresolved placeholder persistence.

4. **Confirmed the next real integration boundary**
   - `GenericDatabasePageServices` already composes collection-aware loading/creation, canonical Relation editing, and collection settings.
   - Current `GenericDatabasePage` still does not consume that composition root end-to-end.
   - Issue #56 explicitly prioritizes patching the real host rather than adding another adapter/foundation.

## Integrated Object foundations available to consume
- Database collection: #82/#85/#86/#87
- Board grouped creation: #79/#87
- multi-View management/overflow: #88/#89/#94
- Object opening settings/resolution: #90/#92/#98
- URL -> Weblink promotion UI: #91
- shared Object detail/value editing/presentation: #93/#95/#97/#99/#100
- `GenericDatabasePageServices`: #96
- Body block editing/contracts/presentation/widgets/actions/references: #101/#103/#105/#106/#107/#108
- Daily Note navigation/detail/widgets: #102/#104/#106
- canonical Relation APIs consumed by Object UI: `RelationMutationService`, `RelationReadService.neighborhood()`, `RelationTargetService`

## Integration-first rule
1. Prefer connecting existing services/widgets to real user-facing hosts over creating more Object-layer abstractions.
2. New foundation work is appropriate only when it unblocks concrete host integration, fixes correctness, or can safely proceed while a required hotspot is unavailable.
3. `GenericDatabasePage`, Object detail/navigation, and Daily Note host work outrank speculative Body/Object expansions.
4. Broad edits to large hotspot files should use a patch-capable environment; the GitHub connector replaces complete file contents and is not appropriate for a risky broad host rewrite.
5. Finish Milestone A/B real-host integration and begin active app use before adding manual collection membership complexity.

## Exact next actions
1. In a patch-capable environment, wire `GenericDatabasePageServices` into real `GenericDatabasePage` for:
   - Database-first collection reload
   - collection-aware normal Object creation
   - Board create-in-group
   - canonical Relation picker/editor
   - collection settings
2. Add page/widget regression coverage proving Database membership resolves before View projection and creation targets the configured ObjectType.
3. Integrate `ObjectDetailPropertyView` and `ObjectBodyDocumentView` into the actual Object detail host.
4. Wire Body text/checklist edits, insert/remove/move, duplicate, and #108 reference insertion through the shared controllers without flattening rich/unknown blocks.
5. Consume `ObjectOpenPresentationService` in real View navigation and implement side peek / center peek / full page while preserving Database/View context.
6. Wire `DailyNoteNavigationBar` to `DailyNoteDetailNavigationService` in the shared Object host.
7. Add `RichText/Document Property` only in a patch-capable environment because it affects exhaustive Property switches and query/group/Board/detail paths.
8. Defer manuallyIncluded/manuallyExcluded collection membership until real dynamic collection + multi-View usage proves the need.

## Cross-lane boundaries
- Relation lifecycle, bidirectional integrity, source/target validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation remain Relation-owned.
- User-facing Relation writes must use canonical Relation mutation APIs; Object UI must not reimplement Relation validation/index lifecycle.
- `GenericDatabasePage`, Object detail UI, Database collection integration, Board create UI, Value promotion, Body/block editing, Daily Notes, and multi-View UX remain Object-owned.
- Relation PR #109 is tests-only Relation-lane work around the canonical editor boundary; do not absorb its ownership into this lane.

## Risks / blockers
- No product/design blocker is active.
- The next highest-value Object changes are broad, coordinated edits to `GenericDatabasePage` and then the real Object detail/navigation host.
- This chat remained in connector-only mode after the Work handoff was declined. The available GitHub file mutation primitive performs complete-file replacement rather than a surgical patch; Issue #56 and this handoff explicitly mark broad whole-file replacement of hotspot files as an avoidable corruption/merge risk.
- Legacy page logic still assumes Database id == ObjectType id in places; use merged collection adapters incrementally.
- Rich Body documents must never be flattened through the paragraph-safe adapter.
- Reference blocks require explicit target selection; unresolved placeholder blocks must never be persisted.

## Validation
- PR #108 functional head `07d4e7d34de9b5024e813c4f674f19f93cc38663`: Flutter CI #590 success.
- Final #108 head only reset the handoff document to current `main`; no functional code changed before merge.
- PR #108 merged as `273578d94f272e9e37169f02afafcf1d60c60082`.
- This connector runtime does not expose a local Flutter SDK; executable validation relies on GitHub Actions for connector-only runs.

## Stop reason
The current sustained run closed a redundant PR, resolved the active Object PR conflict, and merged the validated #108 reference-insertion slice. The next unfinished acceptance criteria require broad surgical edits to the real `GenericDatabasePage` / Object detail hosts. In this connector-only chat the mutation primitive is whole-file replacement, while Issue #56 explicitly requires a patch-capable environment for those hotspots. With no remaining independent high-priority Object slice that would not create another parallel abstraction, this is the tooling/environment stop condition from `AGENTS.md`, not a CI-wait or one-PR stopping condition.
