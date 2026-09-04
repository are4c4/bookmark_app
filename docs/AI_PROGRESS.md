# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal
Finish the transition from strong generic Object/Relation foundations to a coherent user-facing database workflow: **ObjectType = schema, Database = collection, View = presentation/query**.

Product direction: **Capacities-like Object-centric data model + Notion-like Database/View UX**.

Active architecture issues:
- `#56` — generic Object/Database/View integration.
- `#155` — make Weblink a reusable Object and relate Bookmarks to it.

## Current implementation position
The generic Object/Relation foundations are integrated into the real Database/Object hosts. Issue #155 has advanced from a boundary-only design to a live production Bookmark -> Weblink path, and the production Weblink -> Image Relation schema now exists.

## Issue #155 production state
### Bookmark -> Weblink
Merged Object work now provides the live canonical path:
- #179 adds `BookmarkWeblinkObjectBridge` to `ObjectSyncService`, ensures the single `Bookmark -> Weblink` Relation, find-or-creates reusable Weblinks, and writes only through `RelationMutationService`.
- #180 centralizes conservative URL normalization/reuse.
- #181 verifies persisted Relation value + normalized edge before retiring the mirrored Bookmark Object's direct URL Value; legacy `bookmarks.url` remains the compatibility source and invalid URLs remain preserved.
- #183/#186 move/funnel resource-derived metadata into the reusable Weblink without changing Relation lifecycle.

Relation integration on the real production schema is locked by:
- #182 (`79fadb883d026de7111d101547a45e1b03e40e3a`) — live retarget and invalid-URL detach remove stale edges/backlinks and keep audit healthy.
- #184 (`c2dd18aef645397346bb3f7d9071ecd64368b898`) — canonical live Weblink deletion detaches the surviving Bookmark safely.
- #188 (`bcb153a5ddfcd4b82f3a6bebd8efeb0790c0ca89`) — a shared Weblink deletion detaches multiple Bookmarks and deterministic index-only drift reconciles from persisted Relation values without resurrecting retired direct URL Values.

### Managed Image / Weblink -> Image
- Object #185 preserves native first-class Image/Bookmark Objects during legacy mirror cleanup while stale mirrored Objects still use Relation-safe deletion. Latest head passed Flutter CI #782 and was merged.
- Object #189 adds/reuses native managed Image Object identity/provenance through the existing system Image ObjectType.
- Relation #190 (`799a4ecaf554f8574ae7792f0a91e42004c41280`) proves native Image Relation targets survive compatibility sync and stale mirrored Image cleanup removes only the stale target while preserving native Relation value/edge/backlink integrity.
- Object #191 (`46287873a97dad00db408f64f589b0d0ee8740a6`) adds production `WeblinkImageSchemaService`:
  - `Representative image` = single Relation(system Image)
  - `Related images` = multi Relation(system Image)
  - existing conflicting same-name Properties fail closed.
- Relation #192 is active tests-only coverage using these production Properties directly for canonical writes, idempotency, backlinks/index/audit and Image deletion lifecycle.
- Object #187 is remote-preview managed-storage groundwork. The final remote thumbnail -> managed Image Object -> canonical Weblink Relation orchestration is still Object-owned follow-up work.

## Integrated Relation foundations
Canonical Relation validation/mutation/read/index lifecycle, backlinks, bidirectional integrity, target/source validation, integrity audit/reconciliation, Relation-safe Object deletion, picker diagnostics, real-host regressions and #155-specific semantic coverage are all on `main`.

#155 Relation semantic history:
- #174 — Bookmark -> Weblink attach/detach, idempotency, shared target, deletion lifecycle.
- #175 — Weblink representative/related Image cardinality, target validation, stale caller metadata, audit/reconcile.
- #176 — Image deletion across incoming Weblink Image Relations.
- #177 — Bookmark -> Weblink stale metadata and ambiguous missing-target guardrails.
- #182/#184/#188/#190 extend those contracts into live production schema/sync/native-image scenarios.

No Weblink-specific Relation service, alternate index, or direct serialized-id persistence path has been introduced.

## Repository-wide design contract
- Object is global and unique; Databases collect/show Objects rather than own duplicate records.
- ObjectType = schema + reusable defaults.
- Database = target ObjectType + collection semantics.
- View = presentation/query over a Database collection.
- Database collection filtering and View filtering are separate stages.
- Defaults resolve `View > Database > ObjectType > app`.
- Object content = typed Properties + block-oriented Body.
- Value, Object Relation, and Computed remain distinct.
- Tags are Objects; Select/MultiSelect remain lightweight local options.
- Date is a Value; Daily Note is an Object keyed by date.
- Weblink stores resource-derived identity/facts; Bookmark stores user-specific organization/evaluation and relates to Weblink.
- User-facing Relation writes and Relation-affecting deletion must use canonical Relation APIs.

## Delivery priorities
1. Finish Relation PR #192 when CI is green.
2. Complete Object-owned managed preview/thumbnail workflow: remote bytes -> app-managed storage -> managed Image Object -> canonical `Representative image` and optional `Related images` mutation.
3. Relation lane reviews that real workflow for direct low-level Relation writes and adds focused end-to-end regressions.
4. Render related Weblink/Image richly in Table/Gallery/detail after the managed asset path is stable.
5. Keep `bookmarks.url` compatibility retirement separate until old Bookmark hosts no longer depend on it.
6. Continue #56 active-use polish without forking Object identity or Relation persistence.

## Validation status
Recent relevant green CI:
- #179 Flutter CI #760.
- #181 Flutter CI #765.
- #182 Flutter CI #766.
- #184 Flutter CI #771.
- #185 Flutter CI #782.
- #190 Flutter CI #787.
- #188 corrected head Flutter CI #790.
- #191 corrected/rebased head Flutter CI #796.
- #192 Flutter CI #798 is in progress at this handoff update.

Earlier #155 Relation boundary PRs #174/#175/#176/#177 passed CI #746/#747/#748/#750 before merge.

## Known risks / sequencing constraints
- Do not introduce Weblink-specific Relation persistence; reuse `RelationMutationService` and Relation read/index/audit/reconcile services.
- Do not silently repair missing Weblink/Image targets or cardinality conflicts; only deterministic index-only drift is automatically reconcilable.
- Legacy Bookmark URL retirement remains verification-first and compatibility data remains non-destructive.
- Native Image cleanup must continue distinguishing no-Legacy-ID first-class Objects from stale mirrored Objects.
- The final thumbnail workflow must write `Representative image` / `Related images` only after a valid managed Image Object id exists.
