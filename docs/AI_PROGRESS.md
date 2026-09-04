# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal
Finish the transition from strong generic Object/Relation foundations to a coherent user-facing database workflow: **ObjectType = schema, Database = collection, View = presentation/query**.

Product direction: **Capacities-like Object-centric data model + Notion-like Database/View UX**.

Active architecture issues now include:
- `#56` — generic Object/Database/View integration.
- `#155` — make Weblink a reusable Object and relate Bookmarks to it.

## Current implementation position
The generic Object/Relation foundations are substantially wired into real user-facing hosts. `GenericDatabasePage` consumes collection-aware services and canonical Relation editing; `ObjectInspectorPage` consumes shared Property presentation, rich Body editing/actions, Daily Note navigation, Object opening modes, references, and current Object alias features.

Issue #155 is now split cleanly at a stable cross-lane boundary. The Relation lane completed and merged semantic regression coverage for Bookmark -> Weblink and Weblink -> Image behavior through #174/#175/#176/#177, reusing the existing canonical Relation services without adding a Weblink-specific persistence layer. The remaining end-to-end Weblink work is Object-owned schema/workflow integration.

## Integrated Object / database foundations on `main`
- Object/ObjectType/Property semantics, defaults, Formula/Rollup, canonical Relations, Database collection semantics, Gallery/List/Table/Board, and Multi-View management are integrated.
- #111 wires real `GenericDatabasePage` collection-aware load/create/Board create, collection settings, and canonical Relation editing.
- Shared Object detail, rich Body editing/actions, Daily Note navigation, Body references, opening modes, side/center/full presentation, side-peek promotion/edit/delete safety, semantic Property UX, Tag management, and Object alias foundations have continued through the recent Object PR sequence.
- #171/#172/#173 add Object alias persistence, identity search, and shared detail editing without changing Relation lifecycle.
- Object PR #178 is active around alias-aware Body Object references and explicitly does not modify Relation lifecycle or schema.

## Integrated Relation foundations on `main`
Canonical Relation validation/mutation/read/index lifecycle, backlinks, bidirectional integrity, target/source validation, integrity audit/reconciliation, Relation-safe Object deletion, picker diagnostics, and real-host Relation regression coverage are integrated through #109/#114.

Issue #155 adds semantic coverage on top of those generic APIs:
- #174 (`2b50b2465521a7426baec37b9a4594f7d3b80327`) — Bookmark -> Weblink canonical attach/detach, idempotency, shared target, backlinks/index, and Weblink deletion lifecycle.
- #175 (`9e0565e228284d71c119c4b68836eb20036811ed`) — Weblink -> Representative image / Related images cardinality, target validation, stale caller metadata, audit, and index-only reconcile.
- #176 (`668af896556372b9ec55d57a98e24174a4010179`) — Image deletion detaches all incoming Weblink image Relations while preserving unrelated related-image targets.
- #177 (`78ba4f824e1edb4ea28ac7de81528844afd14355`) — Bookmark -> Weblink stale-metadata and ambiguous-missing-target audit/reconcile guardrails.

No Weblink-specific Relation service, alternate relation index, or direct serialized-id persistence path was introduced.

## Issue #155 cross-lane implementation state
### Relation lane — complete for the canonical boundary
All six Relation-lane acceptance items in #155 are checked. Given existing source/target Object ids and a persisted Relation Property, canonical services now have explicit semantic regression coverage for:
- Bookmark -> Weblink single Relation writes;
- repeated idempotent assignment;
- multiple Bookmarks sharing one Weblink;
- detach and Relation-safe Weblink deletion;
- Weblink representative-image single Relation(Image);
- Weblink related-images multi Relation(Image);
- target/cardinality/stale-metadata validation;
- backlinks/index/audit/reconcile/deletion integrity.

### Object lane — next end-to-end dependency
Production schemas currently still need Object-owned semantic Relation Properties:
- Bookmark -> Weblink (single Relation(Weblink));
- Weblink -> Representative image (single Relation(Image));
- Weblink -> Related images (multi Relation(Image)).

Object lane should then wire:
1. new Bookmark URL entry -> `WeblinkObjectService.findOrCreate(...)` -> canonical Relation mutation;
2. idempotent/non-destructive legacy Bookmark URL migration (attach and verify before clearing legacy Value);
3. Weblink metadata enrichment;
4. managed thumbnail/Image Object creation, followed by the already-covered canonical Weblink -> Image Relation writes;
5. Weblink/Image presentation in real hosts.

Relation lane should review those integrations for direct low-level Relation writes and add focused regressions only if a concrete lifecycle/index/backlink defect appears.

## Repository-wide design contract
- Object is global and unique; Databases collect/show Objects rather than own duplicate records.
- ObjectType = schema + reusable defaults.
- Database = target ObjectType + collection semantics.
- View = how to narrow/present a Database collection.
- Database collection filtering and View filtering are separate persistence/query stages.
- Defaults resolve `View > Database > ObjectType > app`.
- Object content = typed Properties + block-oriented Body.
- Value, Object Relation, and Computed remain distinct.
- Tags are Objects; Select/MultiSelect remain lightweight local options.
- Date is a Value; Daily Note is an Object keyed by date.
- Weblink is a reusable Object representing resource-derived facts; Bookmark represents user-specific organization/evaluation and should relate to Weblink rather than duplicate Weblink identity.
- Shared Object detail content should be reused across side peek, center peek, and full page.
- User-facing Relation writes and deletions that affect Relation lifecycle must use canonical Relation APIs; Body document references are separate from Relation Property lifecycle.

## Delivery priorities
1. For #155, Object lane should add/ensure the semantic Relation Properties and consume the already-validated canonical Relation boundary in new Bookmark creation and migration flows.
2. Keep migration non-destructive: create/reuse Weblink, attach Relation, verify success, then retire legacy URL only when explicitly safe.
3. Add managed Image/thumbnail pipeline as Object work; when Image ids exist, set representative/related images only through canonical Relation mutation.
4. Continue active-use polish and concrete Object/Database regressions rather than speculative alternate abstractions.
5. Preserve alias, Body, opening-mode, and shared-detail convergence without forking Object identity or Relation persistence.

## Validation status
Fresh Flutter CI succeeded for every #155 Relation slice before merge:
- #174 CI #746 — Drift generation, `flutter analyze`, full tests — success.
- #175 CI #747 — Drift generation, `flutter analyze`, full tests — success.
- #176 CI #748 — Drift generation, `flutter analyze`, full tests — success.
- #177 CI #750 — Drift generation, `flutter analyze`, full tests — success.
Earlier merged Object and Relation slices passed their relevant CI as recorded in lane handoffs.

## Known risks / sequencing constraints
- The canonical Relation boundary is ready, but production #155 behavior remains incomplete until Object-owned system schemas expose the semantic Relation Properties and Object-owned flows call the boundary.
- Do not add a Weblink-specific Relation persistence implementation; reuse `RelationMutationService`, Relation read/index/audit/reconcile services.
- Do not silently repair missing Weblink/Image targets or cardinality conflicts; only deterministic index-only drift is automatically reconcilable.
- Legacy Bookmark URL migration must attach/verify before clearing user data.
- User-facing Relation writes and Object deletions with possible incoming Relations must remain on canonical mutation/editor APIs.
- Rich Body documents must never be flattened by paragraph-only editing.
