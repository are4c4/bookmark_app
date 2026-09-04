# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal
Finish the transition from strong generic Object/Relation foundations to a coherent user-facing database workflow: **ObjectType = schema, Database = collection, View = presentation/query**.

Product direction: **Capacities-like Object-centric data model + Notion-like Database/View UX**.

Active architecture issues:
- `#56` — generic Object/Database/View integration.
- `#155` — make Weblink a reusable Object and relate Bookmarks to it.

## Current implementation position
The generic Object/Relation foundations are integrated into the real Database/Object hosts. Issue #155 has advanced to a live canonical Bookmark -> Weblink path plus production Weblink -> Image schema with Relation lifecycle coverage.

## Issue #155 production state
### Bookmark -> Weblink
- #179 adds `BookmarkWeblinkObjectBridge` to `ObjectSyncService`, ensures the single `Bookmark -> Weblink` Relation, find-or-creates reusable Weblinks, and writes only through `RelationMutationService`.
- #180 centralizes conservative URL normalization/reuse.
- #181 verifies persisted Relation value + normalized edge before retiring the mirrored Bookmark Object's direct URL Value; legacy `bookmarks.url` remains compatibility data and invalid URLs remain preserved.
- #183/#186 move/funnel resource-derived metadata into reusable Weblinks.
- Relation #182 locks real retarget and invalid-URL detach.
- Relation #184 locks canonical live Weblink deletion.
- Relation #188 locks shared-Weblink deletion across multiple Bookmarks plus deterministic index-only reconciliation.

### Managed Image / Weblink -> Image
- #185 preserves native first-class Image/Bookmark Objects during legacy mirror cleanup while stale mirrors still use Relation-safe deletion.
- #187 stores supported remote preview bytes in app-managed photo storage.
- #189 adds/reuses native managed Image Object identity/provenance using the existing system Image ObjectType.
- #190 proves native Image Relation targets survive compatibility sync and stale mirrored Image cleanup preserves surviving Relation value/edge/backlink state.
- #191 adds production `WeblinkImageSchemaService`:
  - `Representative image` = single Relation(system Image)
  - `Related images` = multi Relation(system Image)
  - conflicting existing Properties fail closed.
- #192 (`c0179751f22083552e253344626498527f111e25`) uses those production Properties directly and locks canonical write idempotency, persisted values, backlinks/index/audit, and Relation-safe Image deletion behavior.

The remaining #155 managed-media gap is Object-owned orchestration that chooses/downloads a preview, creates/reuses the managed Image Object, then calls canonical Relation mutation with the resulting Image id.

## Integrated Relation foundations
Canonical Relation validation/mutation/read/index lifecycle, backlinks, bidirectional integrity, target/source validation, integrity audit/reconciliation, Relation-safe Object deletion, picker diagnostics, real-host regressions and #155-specific production regressions are all on `main`.

#155 Relation sequence:
- #174 — Bookmark -> Weblink attach/detach, idempotency, shared target, deletion lifecycle.
- #175 — Weblink representative/related Image cardinality, target validation, stale metadata, audit/reconcile.
- #176 — Image deletion across incoming Weblink Image Relations.
- #177 — stale metadata and ambiguous missing-target guardrails.
- #182/#184/#188 — production Bookmark/Weblink retarget/detach/delete/reconcile.
- #190/#192 — native/production Weblink/Image Relation survival and lifecycle.

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
1. Object lane: complete real managed preview/thumbnail workflow: remote bytes -> app-managed storage -> managed Image Object -> canonical `Representative image` and optional `Related images` mutation.
2. Relation lane: review that real workflow for direct low-level Relation writes and add focused real-workflow regressions only when the workflow exists or a concrete defect appears.
3. Render related Weblink/Image richly in Table/Gallery/detail after the managed asset path is stable.
4. Keep `bookmarks.url` compatibility retirement separate until old Bookmark hosts no longer depend on it.
5. Continue #56 active-use polish without forking Object identity or Relation persistence.

## Validation status
Recent relevant green CI:
- #179 CI #760.
- #181 CI #765.
- #182 CI #766.
- #184 CI #771.
- #185 CI #782.
- #190 CI #787.
- #188 corrected head CI #790.
- #191 corrected/rebased head CI #796.
- #192 head `a64d74204f4ff02f932ef8112a0f90399fab1130`, CI #798 — Drift generation, `flutter analyze`, full tests — success.

Earlier #155 Relation boundary PRs #174/#175/#176/#177 passed CI #746/#747/#748/#750 before merge.

## Known risks / sequencing constraints
- Do not introduce Weblink-specific Relation persistence; reuse `RelationMutationService` and Relation read/index/audit/reconcile services.
- Do not silently repair missing Weblink/Image targets or cardinality conflicts; only deterministic index-only drift is automatically reconcilable.
- Legacy Bookmark URL retirement remains verification-first and compatibility data remains non-destructive.
- Native Image cleanup must continue distinguishing no-Legacy-ID first-class Objects from stale mirrored Objects.
- The managed thumbnail workflow must write `Representative image` / `Related images` only after a valid managed Image Object id exists.
- At this checkpoint no open PR remains. Relation lane is blocked on the Object-owned managed-thumbnail/Image workflow rather than on CI.
