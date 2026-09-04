# AI Progress — Relation Lane

> Durable handoff for the Relation implementation lane. Update this file before every Relation-lane run ends.

## Lane scope
Own Relation/backlink lifecycle, bidirectional integrity, relation write validation, rename/delete propagation, target constraints, stale/inconsistent metadata handling, Tag hierarchy through Relations, and reusable Relation APIs consumed by Object-owned hosts.

## Active Issues
- `#155` — Architecture: make Weblink a reusable Object and relate Bookmarks to it
- `#56` — Integrate generic Object database UX toward Notion/Capacities workflow

## Current goal
Complete the Relation-owned boundary for Weblink Objectization without creating a Weblink-specific Relation persistence path. Object-owned workflows provide existing Bookmark/Weblink/Image Object ids and the semantic Relation Properties; Relation writes, reads, indexes, audit/reconcile, detach, and deletion must use the existing canonical Relation APIs.

## Current state
- Relation foundation PRs #62/#66/#69/#73/#74/#75/#80/#81 are merged.
- #109 and #114 lock the canonical editor and real Database-host Relation lifecycle.
- Issue #155 Relation-lane semantic coverage is merged through:
  - #174 `Cover canonical Bookmark to Weblink Relation boundary` -> `2b50b2465521a7426baec37b9a4594f7d3b80327`.
  - #175 `Cover Weblink Image Relation integrity` -> `9e0565e228284d71c119c4b68836eb20036811ed`.
  - #176 `Cover Weblink Image Relation deletion lifecycle` -> `668af896556372b9ec55d57a98e24174a4010179`.
  - #177 `Cover Bookmark Weblink Relation guardrails` -> `78ba4f824e1edb4ea28ac7de81528844afd14355`.
- Issue #155 Relation-lane acceptance is now fully checked for the boundary where existing source/target Object ids and persisted Relation Properties are supplied.
- No Weblink-specific Relation service, index, serialization format, or repair path was introduced.
- No production schema or destructive migration was added by the Relation lane.
- No active Relation implementation PR remains from this run.

## Stable canonical Relation APIs used by #155

### Mutation / lifecycle
- `RelationMutationService.setRelation(...)`
  - re-resolves persisted Property metadata instead of trusting stale caller config;
  - validates source Object ownership, target ObjectType, target Object existence, and cardinality through the canonical ObjectStore boundary;
  - replaces normalized edges atomically with the persisted Relation value;
  - remains the only write boundary used by the #155 semantic regressions.
- `RelationMutationService.deleteObject(...)`
  - rebuilds the index before deletion;
  - discovers all incoming references;
  - validates detach plans before writes;
  - detaches surviving sources through canonical `setRelation(...)`;
  - deletes the target only after surviving Relation values/indexes are safe.

### Read / backlinks
- `RelationReadService.backlinks(...)` resolves normalized backlinks to canonical source Objects/Properties.
- Existing `ObjectStore.outgoingRelations(...)` / `backlinks(...)` are used only as normalized-index observations in tests, not as a parallel write API.

### Integrity / reconciliation
- `RelationIntegrityService` remains read-only and reports semantic Relation corruption such as missing targets and index drift.
- `RelationIndexReconcileService` repairs only deterministic index-only drift from persisted Relation values and refuses ambiguous missing-target/value repair.

## Issue #155 checkpoints completed in this sustained run
1. Re-read latest `AGENTS.md`, Issues #155/#56, repository handoff, Relation handoff, current main/open PRs, and canonical Relation implementation.
2. Audited `RelationMutationService`, `ObjectStore` validation/index replacement, `RelationReadService`, integrity audit, reconcile, `WeblinkObjectService`, and `CoreObjectBridge` schema ownership.
3. PR #174 added Bookmark -> Weblink semantic boundary coverage:
   - existing Bookmark/Weblink ids attach through `RelationMutationService` only;
   - setting the same single target twice is idempotent and leaves exactly one normalized edge;
   - multiple Bookmarks safely reference one Weblink;
   - raw and resolved backlinks contain both Bookmark sources;
   - explicit canonical detach removes only that Bookmark reference;
   - Relation-safe Weblink deletion empties surviving Bookmark Relation values and removes backlinks/index edges.
4. PR #175 added Weblink -> Image semantic integrity coverage:
   - `Representative image` is enforced as single Relation(Image);
   - `Related images` supports multi Relation(Image);
   - wrong target ObjectType and single-cardinality violations fail closed;
   - forged/stale caller target/cardinality metadata is ignored in favor of persisted canonical Property metadata;
   - a healthy Bookmark -> Weblink + Weblink -> Image graph audits healthy;
   - manually introduced missing index drift is detected and repaired by `RelationIndexReconcileService` without changing persisted Relation values.
5. PR #176 added Image deletion lifecycle coverage:
   - the same Image may be representative/related and referenced by multiple Weblinks;
   - canonical Image deletion detaches every incoming Weblink Relation;
   - unrelated Related-images targets are preserved;
   - deleted target backlinks and stale normalized edges disappear.
6. PR #177 added Bookmark -> Weblink guardrails:
   - stale caller metadata cannot redirect the canonical target ObjectType;
   - stale `multiple=true` cannot bypass the persisted single cardinality;
   - wrong target ids fail closed;
   - a deliberately corrupted missing Weblink target is reported by the audit;
   - reconciliation refuses that ambiguous repair and preserves the user's persisted Relation value.
7. Updated Issue #155 to mark all six Relation-lane acceptance items complete and recorded the remaining Object-owned integration dependency.

## Validation
All four Issue #155 Relation PRs passed fresh GitHub Actions before merge:
- #174 head `b7130dfd3798015d1e7dacd2a91d7740c93e76bf` — Flutter CI #746: dependency install, Drift generation, `flutter analyze`, full test suite — success.
- #175 head `4b4483b095438b5d294fe685a047a2aed72d18b3` — Flutter CI #747: dependency install, Drift generation, `flutter analyze`, full test suite — success.
- #176 head `0f727c7c6218896b02f4eeca548f01b92829caf8` — Flutter CI #748: dependency install, Drift generation, `flutter analyze`, full test suite — success.
- #177 head `44bc716f2053293af7e1b42af5b3b104a163625b` — Flutter CI #750: dependency install, Drift generation, `flutter analyze`, full test suite — success.

GitHub Actions is the executable validation source in this connector-only session.

## Object-lane schema audit / cross-lane dependency
Current production schema intentionally remains Object-owned:
- `CoreObjectBridge` Bookmark system schema currently has direct `URL`, plus existing `Images` and `Tags` Relations, but does **not** yet define the new `Bookmark -> Weblink` single Relation.
- `WeblinkObjectService.ensureDefinition(...)` currently ensures the Weblink ObjectType and `URL` Value Property only; it does **not** yet define `Representative image` or `Related images` Relations.
- Per Issue #155 ownership, Relation lane did not add these schema Properties or alter URL migration/creation behavior.

The next end-to-end #155 work therefore belongs to Object lane:
1. add/ensure the semantic Relation Properties in the system schemas using the agreed types/cardinality;
2. make new Bookmark URL entry find-or-create the Weblink, then call the existing canonical Relation mutation boundary;
3. orchestrate non-destructive legacy Bookmark URL migration (attach first, verify, then retire legacy Value when safe);
4. when Image Object ids exist, call canonical mutation for representative/related image Relations;
5. add real workflow/host integration regressions that consume these already-covered Relation boundaries.

## Exact next Relation actions
1. Do not create another Weblink-specific Relation facade merely to rename `RelationMutationService`; the generic canonical boundary already satisfies #155.
2. When Object lane lands the actual `Bookmark -> Weblink`, `Representative image`, or `Related images` schema/workflow, audit the diff for direct serialized-id writes or low-level Relation mutation and replace only concrete violations.
3. Add focused end-to-end Relation regressions if the Object-owned URL-entry/migration/thumbnail workflows expose a lifecycle, backlink, index, stale-metadata, or deletion failure.
4. Keep audit and repair separate: deterministic index drift may reconcile; missing targets/cardinality/bidirectional ambiguity must not be silently repaired.
5. Continue to use low-level direct deletion/value writes only in explicit corruption fixtures, never in normal user-facing #155 flows.

## Cross-lane boundary
- URL normalization, `WeblinkObjectService.findOrCreate(...)`, Bookmark creation UX, legacy URL migration orchestration, Weblink/Image system schema evolution, metadata fetching, thumbnail storage, Image Object creation, and presentation remain Object-lane owned under #155.
- Relation lane owns correctness after the source id, target id, and persisted Relation Property exist.
- `lib/data/object_store.dart` and other shared core files need no #155 Relation changes at this point; avoid speculative edits while Object work continues.
- Object PR #178 is Body alias-reference work and explicitly has no Relation lifecycle changes; it does not block the completed #155 Relation boundary.

## Known risks / blockers
- Production end-to-end Bookmark -> Weblink use cannot occur until Object lane adds the persisted semantic Relation Property and wires the URL-entry/migration flows.
- Production Weblink -> Image relations likewise depend on Object-owned Weblink/Image schema and Image creation/enrichment pipeline.
- Automatic repair of missing Weblink/Image targets could discard user intent and remains intentionally prohibited.

## Stop reason
Issue #155 has no remaining independent actionable Relation-lane work under the agreed ownership split: all six Relation-lane acceptance items are covered by canonical API regressions and are CI-green/merged. The remaining path requires Object-owned schema evolution and workflow orchestration to provide the actual semantic Relation Properties and Object ids. Continuing independently would either duplicate the generic Relation APIs or cross the explicit Object-lane schema/workflow boundary. This matches the AGENTS.md stopping condition: the next safe step is blocked by an unavoidable cross-lane dependency, not by pending CI or completion of one PR.
