# AI Progress — Object Core & Body Lane

> Lane A durable handoff. Read the latest `AGENTS.md`, `docs/AI_PROGRESS.md`, active Issues and open PR ownership before implementation. This lane does not own primitive-specific product behavior or generic Database/View presentation.

## Lane goal
Keep reusable Object/ObjectType identity, schema semantics, Body and generic opening/detail contracts coherent across built-in and user-defined ObjectTypes.

## Primary issues
- #481 — universal Body/note surface for every ObjectType.
- #56 — Object/ObjectType/detail/opening portions of the generic architecture umbrella.
- #484 — user-defined ObjectType core semantics and the built-in/custom boundary.
- #493 — only ordinary Object/ObjectType core-integrity portions; Relation migration correctness remains Lane B and schema-authoring UX remains Lane C.

## Owns
- Object/ObjectType identity and core semantics.
- Typed Property value semantics outside presentation-specific hosts.
- Versioned Body/block/reference persistence and editing contracts.
- Universal Body capability across ordinary/system ObjectTypes.
- Aliases and shared Object identity metadata contracts.
- Daily Note identity/navigation and time-based Object patterns.
- Generic Object opening/detail contracts.
- User-defined ObjectType core behavior.

## Does not own
- Weblink/Image/File/Tag primitive implementation -> Lane D.
- Database/View/Table/List/Gallery/Board/schema-authoring UX -> Lane C.
- Relation pair/index/lifecycle/data-integrity internals -> Lane B.
- Search/FTS/indexing -> Lane E.
- Vault/filesystem/delivery -> Lane F.
- behavior-preserving cleanup / #225 -> Lane G.

## Integrated state — 2026-09-07
Latest repository main observed while refreshing this handoff: `7b34fbd9be85b5586626b36103339b5b45ec8da0`.
Latest Lane A production merge in that history: #670 `488ec5d2ebf629e915a18eaffb239a2486079119`.

### Universal Body and Body persistence
- #503 merged as `a8cf84d3af59ef537ae66518b7c7a9f4206c43c5`: `ObjectInspectorPage` permits Body editing for every ObjectType, including system ObjectTypes, while identity-sensitive title/Property/create guards remain intact.
- Weblink/Image real-host regressions cover shared Body creation/edit persistence. Existing ordinary/custom and Daily Note Body regressions remain on the same Body contract.
- ObjectType Body creation templates are applied through the canonical Object creation path; existing Objects retain their own Body when templates later change.
- Body block/document validation fails closed for structurally ambiguous identities while preserving unknown/future block payloads.
- #661 merged as `9f8799c5773982b5c1de971fec383f2fedc43818`: clearing actual Body content advances the parent Object `updated_at` in the same transaction; re-clearing an empty Body is a true no-op; failure to touch parent freshness rolls the Body deletion back.
- Concurrent duplicate #667 was closed unmerged after #661 fully subsumed it with stronger rollback coverage.
- #670 merged as `488ec5d2ebf629e915a18eaffb239a2486079119`: valid JSON with a non-object top-level Body shape now throws `FormatException` instead of silently becoming an empty Body. `{}` remains the canonical empty document and unknown/future block kinds remain round-trippable.

### ObjectType/default/schema integrity
- ObjectType defaults support reusable Property visibility/order/open mode plus a Body creation template without flattening Database/View overrides into the same layer.
- #621 merged: malformed persisted Property-id entries fail closed rather than being silently dropped.
- #624 merged: ObjectType schema duplication rejects stale default Property references atomically rather than copying a partially valid defaults document.
- #640 merged as `1c68d4fdecfec9791d630c37fb0a34e7db9f24e2`: validated defaults writes require the ObjectType to exist and every `visiblePropertyIds` / `propertyOrder` reference to belong to that ObjectType.
- #650 merged as `cf347443173ad9a8bb834bd0a807c2765ef043e9`: non-object top-level ObjectType-default JSON fails closed instead of being treated as no overrides.
- #660 merged as `f103862a2de73cfd5d5c460a1a37a34e30c0a13f`: ordinary Property deletion prunes that Property from ObjectType visibility/order defaults in the same transaction while preserving open mode and Body template. Relation Properties are deliberately rejected so Relation lifecycle stays canonical in Lane B.

### Daily Note identity
- #618 merged: newly created Daily Note Object identity, Date value, optional Body template and registry claim are one transaction.
- #647 merged as `212b2626912332736dec2644669ce0c5cb398f36`: `(workspace, local-date)` registry claims are race-safe; legacy adoption returns the actual concurrent winner and lost new-object claims clean up the duplicate inside the creation transaction.
- #656 merged as `71a8ed14acf10f8efd6d4c2592cffb029a88c00a`: stale registry claims whose Object no longer resolves inside the canonical Daily Note ObjectType are removed by exact observed identity and reclaimed through the normal race-safe open/create path.
- Overlapping temporary Daily Note implementations were closed rather than kept as competing leases.

### Alias / Object identity metadata
- Aliases remain Object-scoped alternate names; the same alias may intentionally resolve to multiple Objects and normalized duplicates within one Object remain suppressed.
- #669 merged as `d305f47aae1c04464bc286fe0322c5eec85ac28e`: actual alias add/replace/remove/clear mutations advance parent Object freshness; duplicate add, identical replace, missing remove and empty clear remain true no-ops.
- Alias deletion/position compaction and parent freshness update are transactional; failure-injection coverage proves identity metadata is not left half-mutated.

### Opening/search cross-lane state
- Center peek and full-page generic openings reuse the shared Object Inspector/detail path.
- Side peek is still a Database/View-owned alternate presentation surface. Lane A must not create a second Body persistence/editor path there; Lane C should compose the canonical shared Body/detail contract.
- Lane E has completed canonical Object Body search indexing and Global Search routing. Lane A should not add a second Body/Note search repository.

## Active Lane A WIP
No independent Lane A production PR is active at this checkpoint. This handoff PR is docs-only.

Before starting new production work, search open PRs again: multiple lanes and more than one autonomous Lane A execution have been active concurrently, and duplicate work has already occurred once (#661/#667).

## Hotspot / ownership notes
- `object_inspector_page.dart`, `generic_database_page.dart`, `app_shell.dart`, `object_store.dart` and other semantic/shared hosts require a fresh open-PR lease check immediately before editing.
- Do not broaden universal Body work into `generic_database_page.dart`; generic side-peek composition belongs to Lane C.
- Do not route Relation Property deletion or target/cardinality changes around Lane B canonical Relation APIs.
- Do not absorb primitive, Search, Vault or Refactor work simply because it operates on canonical Objects.

## Exact next actions
1. Audit #481 close-condition coverage against current main, especially whether Bookmark and Person real opening surfaces actually reach the universal shared Body contract. Distinguish a missing Lane A shared-detail contract from a legacy/product-host presentation gap before changing code.
2. Leave side-peek Body composition to Lane C; coordinate only on reuse of the existing canonical Body/detail seam.
3. Re-audit #56/#484 for a concrete Object/ObjectType invariant or corruption case before adding another core validation rule. Do not manufacture speculative restrictions such as new defaults-list constraints without a demonstrated semantic failure.
4. If no independent A-owned correctness gap remains after the real-host audit, stop production changes and wait for a concrete Object-core issue rather than crossing lane boundaries.

## Stop rule
A green PR or one completed slice is not itself a stop condition. Continue to another independent Lane A core slice while safe work exists; stop rather than manufacture changes when only leased hotspots, speculative invariants, or other lanes' responsibilities remain.
