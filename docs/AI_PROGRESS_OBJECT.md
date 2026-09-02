# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current integration state
`main` contains the major Object/Relation foundations, Database collection services, multi-View management, opening-mode services, shared Object detail/value editing contracts, Daily Note navigation, and rich Body block persistence/presentation/action/reference foundations through merged Object PR #108 and merged Relation regression PR #109.

The highest-priority Object work is **real-host integration**, especially `GenericDatabasePage`, the actual Object detail/navigation host, and Daily Note navigation. Do not add another parallel abstraction when an existing service/widget can be consumed by the real host.

## Active branch / PR
- No active Object implementation PR after #108 merged.
- PR #108 — `Add typed Object Body reference insertion` — passed Flutter CI #590 and was squash-merged as `273578d94f272e9e37169f02afafcf1d60c60082`.
- PR #110 was closed unmerged as redundant; collection-aware page loading/creation is already integrated through #86/#87 and composed by #96.
- Relation PR #109 — integration-safety regression coverage around the canonical Relation editor boundary — passed Drift generation, `flutter analyze`, and the full test suite, then was squash-merged as `d51b5023ede27bcf0c66670620e86643a1b07038`.

## Checkpoints completed in this run
1. **Re-read all required source-of-truth state**
   - Read `AGENTS.md`, Issue #56, `docs/AI_PROGRESS.md`, this Object handoff, and the latest PR/CI state.
   - Confirmed Issue #56 still explicitly prioritizes real-host integration over more parallel abstractions.

2. **Confirmed Object/Relation integration prerequisites are landed**
   - #108 is merged and provides typed Body reference insertion, deterministic block ids, block duplication, and reference action chrome.
   - #109 is merged and adds CI-green regression coverage for bidirectional Relation save/inverse synchronization, stale picker fail-closed behavior, missing-target non-mutation on load, explicit repair boundaries, and `GenericDatabasePageServices.relationEditor` composition behavior.
   - There is no active cross-lane PR blocking Object host integration.

3. **Re-validated the next implementation boundary**
   - `GenericDatabasePageServices` already composes Database-first collection loading, collection-aware normal/Board creation, canonical Relation editing, and collection settings.
   - The real `GenericDatabasePage` still contains legacy assumptions (including Database id == ObjectType id in places and a low-level Relation write path) and must be surgically migrated to the composed services.
   - The real Object detail/navigation host similarly still needs shared `ObjectDetailPropertyView`, `ObjectBodyDocumentView`, opening-mode navigation, and Daily Note navigation consumption.

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
4. Broad edits to large hotspot files should use a patch-capable environment; the current GitHub connector replaces complete file contents and is not appropriate for a risky broad host rewrite.
5. Finish Milestone A/B real-host integration and begin active app use before adding manual collection membership complexity.

## Exact next actions
1. In a patch-capable environment, wire `GenericDatabasePageServices` into real `GenericDatabasePage` for:
   - Database-first collection reload
   - collection-aware normal Object creation
   - Board create-in-group
   - canonical Relation picker/editor via `relationEditor.load/save`
   - collection settings
2. Add page/widget regression coverage proving Database membership resolves before View projection, creation targets the configured ObjectType, and canonical Relation editing preserves bidirectional behavior end-to-end.
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
- #109 is now merged; there is no active Relation PR conflicting with the Object host integration path.

## Risks / blockers
- No product/design blocker is active.
- The next highest-value Object changes require broad coordinated edits to `GenericDatabasePage` and then the real Object detail/navigation host.
- This runtime exposes GitHub whole-file replacement but not a surgical patch/worktree editor. Issue #56 and the repository handoffs explicitly classify broad whole-file replacement of these hotspot files as an avoidable corruption/merge risk.
- Legacy page logic still assumes Database id == ObjectType id in places; use merged collection adapters incrementally.
- Rich Body documents must never be flattened through the paragraph-safe adapter.
- Reference blocks require explicit target selection; unresolved placeholder blocks must never be persisted.

## Validation
- PR #108 functional head: Flutter CI #590 success before merge.
- PR #109 head `576346d836c2ad07c3f2a590640751dd8b107741`: Drift generation, `flutter analyze`, and full tests succeeded in Flutter CI #597 before merge.
- No Object code was changed in this run because the only remaining high-priority slices require patch-capable hotspot editing.

## Stop reason
This run refreshed all required source-of-truth state, confirmed #108 and #109 are merged and CI-green, and verified that no cross-lane dependency remains. The next actionable Object acceptance criteria are broad surgical migrations of `GenericDatabasePage` / Object detail-navigation hosts. In this runtime the only mutation primitive for existing GitHub files is whole-file replacement, while Issue #56 explicitly requires patch-capable editing for these hotspots. No independent high-priority Object slice remains that would not violate the integration-first rule by inventing another abstraction. This therefore matches the `AGENTS.md` tooling/environment stopping condition, not a CI-wait or one-PR stopping condition.
