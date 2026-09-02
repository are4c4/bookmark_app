# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current integration state
`main` now contains the major Object/Relation foundations, Database collection services, multi-View management, opening-mode services, shared Object detail/value editing contracts, Daily Note navigation, and rich Body block persistence/presentation/action foundations through merged PR #107.

The highest-priority Object work is **real-host integration**, especially `GenericDatabasePage`, the actual Object detail/navigation host, and Daily Note navigation. Do not add another parallel abstraction when an existing service/widget can be consumed by the real host.

## Active branch / PR
- Branch: `feature/object-body-reference-inserts`
- PR: #108 — `Add typed Object Body reference insertion`
- Latest head: `07d4e7d34de9b5024e813c4f674f19f93cc38663`
- PR is open and mergeable.
- Flutter CI #590 succeeded on latest head.

## Recent integrated checkpoints
### #107 merged
PR #107 added:
- generic non-reference Body insert kinds
- latest-read `moveUp` / `moveDown`
- atomic `insertAfter`
- persisted `ObjectBodyBlockActionController`
- shared `ObjectBodyInsertMenuButton`
- shared per-block move/insert/delete action chrome
- `ObjectBodyDocumentView.blockActionsBuilder`

It passed Flutter CI #574 and was squash-merged as `39fdc54b276a5241eb2fd07214b868d1abb0e466`.

### #108 current work
PR #108 adds:
- deterministic Body block-id allocation
- payload-preserving block duplication
- typed insertion requests for Object / Database-View / Image / File references
- latest-read reference insertion controller that never persists unresolved placeholders
- semantic collision-free reference block ids
- persisted duplicate-after-source service
- duplicate/reference actions in shared block chrome
- shared reference-insert menu chrome
- focused tests for invalid-id fail-closed behavior, ordering, duplication payload preservation, and reference selection callbacks

Latest Flutter CI #590 is green.

## Integrated Object foundations available to consume
- Database collection: #82/#85/#86/#87
- Board grouped creation: #79/#87
- multi-View management/overflow: #88/#89/#94
- Object opening settings/resolution: #90/#92/#98
- URL -> Weblink promotion UI: #91
- shared Object detail/value editing/presentation: #93/#95/#97/#99/#100
- `GenericDatabasePageServices`: #96
- Body block editing/contracts/presentation/widgets/actions: #101/#103/#105/#106/#107
- Daily Note navigation/detail/widgets: #102/#104/#106
- canonical Relation APIs consumed by Object UI: `RelationMutationService`, `RelationReadService.neighborhood()`, `RelationTargetService`

## Integration-first rule
1. Prefer connecting existing services/widgets to real user-facing hosts over creating more Object-layer abstractions.
2. New foundation work is appropriate only when it unblocks concrete host integration, fixes correctness, or can safely proceed while a required hotspot is unavailable.
3. `GenericDatabasePage`, Object detail/navigation, and Daily Note host work outrank speculative Body/Object expansions.
4. Broad edits to large hotspot files should use a patch-capable environment; this GitHub connector performs whole-file replacement and is not appropriate for risky large rewrites.
5. Finish Milestone A/B real-host integration and begin active app use before adding manual collection membership complexity.

## Exact next actions
1. Merge PR #108 if latest head remains green and no new conflict appears.
2. In a patch-capable environment, wire `GenericDatabasePageServices` into real `GenericDatabasePage` for:
   - Database-first collection reload
   - collection-aware normal Object creation
   - Board create-in-group
   - canonical Relation picker/editor
   - collection settings
3. Add page/widget regression coverage proving Database membership resolves before View projection and creation targets the configured ObjectType.
4. Integrate `ObjectDetailPropertyView` and `ObjectBodyDocumentView` into the actual Object detail host.
5. Wire Body text/checklist edits, insert/remove/move, duplicate, and #108 reference insertion through the shared controllers without flattening rich/unknown blocks.
6. Consume `ObjectOpenPresentationService` in real View navigation and implement side peek / center peek / full page while preserving Database/View context.
7. Wire `DailyNoteNavigationBar` to `DailyNoteDetailNavigationService` in the shared Object host.
8. Add `RichText/Document Property` only in a patch-capable environment because it affects exhaustive Property switches and query/group/Board/detail paths.
9. Defer manuallyIncluded/manuallyExcluded collection membership until real dynamic collection + multi-View usage proves the need.

## Cross-lane boundaries
- Relation lifecycle, bidirectional integrity, source/target validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation remain Relation-owned.
- User-facing Relation writes must use canonical Relation mutation APIs; Object UI must not reimplement Relation validation/index lifecycle.
- `GenericDatabasePage`, Object detail UI, Database collection integration, Board create UI, Value promotion, Body/block editing, Daily Notes, and multi-View UX remain Object-owned.
- PR #108 is Object/Body-only and does not modify Relation lifecycle/index, `GenericDatabasePage`, Object inspector, schema, or migrations.

## Risks / blockers
- No product/design blocker is active.
- `GenericDatabasePage` and real Object detail/navigation hosts are large integration hotspots and should not be broadly replaced through this connector.
- Legacy page logic still assumes Database id == ObjectType id in places; use the merged collection adapters incrementally.
- Rich Body documents must never be flattened through the paragraph-safe adapter.
- Reference blocks require explicit target selection; unresolved placeholder blocks must never be persisted.

## Validation
- PR #107: Flutter CI #574 success before merge.
- PR #108: Flutter CI #590 success on latest head; PR remains open/mergeable.
- This connector runtime does not expose a local Flutter SDK; executable validation relies on GitHub Actions for connector-only runs.

## Stop reason
This handoff is a design/progress refresh, not an implementation stop caused by lack of Object work. The next highest-value changes require patch-capable edits to real host files; connector-only runs should avoid inventing additional abstractions merely to stay busy.
