# AI Progress — Relation Lane

> Durable handoff for the Relation implementation lane. Update this file before every Relation-lane run ends.

## Lane scope
Own Relation/backlink lifecycle, bidirectional integrity, Relation write validation, target/cardinality constraints, stale/inconsistent metadata handling, deterministic index reconciliation, Relation-safe deletion/detach, Relation picker candidate/selection behavior, and focused regressions for Object-owned workflows that consume the canonical Relation boundary.

## Active issues
- `#155` — Architecture: make Weblink a reusable Object and relate Bookmarks to it
- `#56` — Integrate generic Object database UX toward Notion/Capacities workflow

`#166` (Object aliases / Relation picker alias resolution) is closed as completed.

## Current goal
Preserve one canonical Relation subsystem while Object lane moves into presentation/navigation and legacy-retirement work. Resume implementation only when a new Relation-producing workflow or a concrete Relation correctness regression appears.

## Current state
### Canonical Relation foundation
The generic Relation foundation through #109/#114 remains stable:
- `RelationMutationService` is the user-facing mutation boundary.
- `RelationReadService` resolves canonical outgoing/backlink state.
- `RelationIntegrityService` is read-only.
- `RelationIndexReconcileService` repairs deterministic index-only drift only.
- `RelationMutationService.deleteObject(...)` detaches surviving sources before target deletion.
- ambiguous missing-target/cardinality/bidirectional damage is never auto-repaired from editor paths.

No Weblink-specific Relation persistence service, alternate Relation index, or direct serialized-id user workflow has been introduced.

### #155 Bookmark -> Weblink / Weblink -> Image
Merged Relation coverage:
1. #174 — Bookmark -> Weblink attach, repeat idempotency, shared target, detach/delete.
2. #175 — Weblink Representative/Related Image target/cardinality/stale-metadata rules plus audit/reconcile.
3. #176 — Image deletion detaches incoming Weblink Image Relations while preserving unrelated targets.
4. #177 — stale caller metadata cannot override canonical target/cardinality; ambiguous repair fails closed.
5. #182 — real Object sync URL retarget and invalid-URL detach.
6. #184 — production Weblink Relation-safe deletion.
7. #188 — shared Weblink deletion across multiple Bookmarks plus deterministic index-only reconcile.
8. #190 — native Image targets survive compatibility sync and stale mirrored Image cleanup.
9. #192 — production Weblink/Image semantic Properties support canonical single/multi writes, repeat idempotency, backlinks/index/audit and Image deletion lifecycle.
10. #198 (`47e0c6ab2cdcbd4aba31c88ac9ca13eba0dc3718`) — real `WeblinkPreviewImagePipeline` Relation lifecycle: retry idempotency, Representative replacement, index-only reconcile, managed Image delete/detach.
11. #201 (`8c66cedc4d2d3f34ae467744d9b2cbc3a8e9c4c5`) — real `ObjectSyncService(enableRemotePreviewImages: true)` host: exactly-one edge/backlink, healthy audit, canonical managed Image deletion detach.

Object-owned production pieces consumed by that coverage:
- #179 production `Bookmark -> Weblink` Relation in `ObjectSyncService`.
- #191 production `Representative image` single Relation(Image) and `Related images` multi Relation(Image) schema.
- #193 managed preview -> managed Image Object -> canonical Representative Relation pipeline.
- #194 real app-host/background preview ingestion.
- #196 read-only managed visual resolution through `RelationReadService`.

Issue #155 Relation acceptance is complete for the currently existing Relation-producing workflows. Remaining #155 work is primarily presentation/navigation/legacy compatibility retirement and is Object-owned.

### #166 alias-aware Relation picker — complete
- #195 (`fc33bcc183020eb92ad0ff06064c01eff9664110`): `ObjectRelationEditorService.searchCandidates(...)` reuses shared `ObjectIdentitySearchService`, scopes to persisted target ObjectType, intersects with the canonical picker candidate set, and returns canonical Object ids with alias display context only.
- #200 (`1da14a7dbf5fd2e57307040768ac38f0a27bfdf1`): real `GenericDatabasePage` Relation picker consumes that search boundary, shows `別名: ...`, guards stale async search responses, and saves only canonical Object ids through the existing Relation editor/mutation path.
- #202 (`2f6a991104d68d3b4860061e234fc4f9c4acf099`): real-host ambiguous alias coverage proves two same-alias target Objects remain selectable while a same-alias Object from the wrong ObjectType is excluded; saved identity is canonical Object id.

Issue #166 is closed as completed. Future Object merge/deduplication is a separate deferred product workflow.

## Validation
Recent Relation-lane CI:
- #195 CI #811 — success.
- #198 CI #819 — success.
- #200 CI #823 — success.
- #201 CI #825 — success.
- #202 CI #828 — success.

Earlier relevant Relation CI:
- #174/#175/#176/#177 — #746/#747/#748/#750 success.
- #182 — #766 success.
- #184 — #771 success.
- #190 — #787 success.
- #188 corrected head — #790 success.
- #192 — #798 success.

GitHub Actions is the executable validation source in this connector-only environment.

## Canonical contracts to preserve
### Mutation
`RelationMutationService.setRelation(...)` must continue to:
- re-resolve persisted Property metadata;
- validate source/target ObjectType, target existence, same-workspace constraints and cardinality;
- persist Relation values and replace normalized edges canonically;
- remain idempotent for repeated identical assignment.

### Read / picker
- Relation picker candidate search may use title/alias identity search, but aliases are presentation/search metadata only.
- selected/persisted identity is always canonical Object id.
- picker search cannot broaden beyond its canonical `RelationSelectionContext.candidates`.
- target ObjectType and stale-context validation remain authoritative.

### Reconcile / repair
- deterministic index-only drift may be rebuilt from persisted Relation values.
- missing targets, cardinality conflicts and ambiguous bidirectional damage must remain visible rather than silently rewritten.

### Delete
All user-facing Relation-affecting Object deletion must preserve surviving Relation values/indexes/backlinks through canonical Relation-safe deletion.

## Latest audit
A repository search after #202 found no new view-level direct `ObjectStore.setRelation(...)` path. Production `setRelation(...)` consumers remain canonical Relation-layer/service users such as `BookmarkWeblinkObjectBridge`, `WeblinkPreviewImagePipeline`, Tag/core bridges and generic Relation mutation adapters. Low-level `ObjectStore.setRelation(...)` remains inside Relation internals/tests/corruption fixtures.

## Cross-lane production state
### Bookmark -> Weblink
Live and Relation-covered for:
- find/reuse and canonical Relation write;
- retry/shared targets;
- URL retarget;
- invalid URL detach;
- single/shared Weblink deletion;
- deterministic index-only reconcile.

### Weblink -> Image
Live and Relation-covered for:
- production Representative single + Related multi schema;
- managed Image creation/reuse by Object lane;
- real preview pipeline canonical Representative assignment;
- retry/replacement;
- edge/backlink/audit integrity;
- deterministic index-only reconcile;
- Relation-safe managed Image deletion/detach;
- real ObjectSync host path.

### Alias-aware Relation picker
Live and Relation-covered for:
- title + alias search;
- canonical id persistence;
- ambiguous alias results;
- target ObjectType scope;
- stale picker candidate-set boundary;
- stale async UI search response guard.

## Exact next Relation actions
1. Monitor Object-lane PRs for new Relation-producing workflows, especially new Image/Related-images assignment, Weblink edits, object merge/dedup, or new first-class Object migrations.
2. For each new workflow, audit for direct serialized-id or low-level Relation writes first.
3. Add focused real-host regression coverage for lifecycle/idempotency/backlinks/index/delete only when the workflow actually exists or exposes a concrete defect.
4. Do not create feature-specific Relation facades when generic canonical services already cover the behavior.
5. Keep deterministic reconciliation separate from ambiguous data repair.

## Cross-lane boundary
Object lane owns URL parsing/normalization, metadata acquisition, media download/storage, Image/Weblink Object creation/reuse, ObjectType product schema, navigation and presentation.

Relation lane owns correctness after source id, target id and persisted Relation Property exist, plus Relation picker candidate/selection semantics and focused workflow regressions.

Avoid editing Object-owned workflow/core files unless a concrete Relation defect requires a small sequenced fix.

## Known blockers / risks
- Current open #155 work is read-only presentation/navigation rather than a new Relation-producing path.
- Automatic repair of missing targets/cardinality conflicts remains intentionally prohibited because it can discard user intent.
- Future Object merge/deduplication will require a new explicit Relation policy before any automatic edge/value rewrites are introduced.

## Stop reason
No independent actionable Relation implementation remains after #198/#200/#201/#202. Issue #166 is complete and closed; the currently existing #155 managed-preview Relation workflow is covered through the real host. Remaining open work is Object-owned presentation/navigation/legacy retirement. Resume Relation lane when a new production Relation surface or concrete correctness regression appears, matching the `AGENTS.md` cross-lane dependency stopping criterion.
