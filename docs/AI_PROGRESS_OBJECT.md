# AI Progress — Object Core & Body Lane

> Lane A durable handoff. Read the latest `AGENTS.md`, `docs/AI_PROGRESS.md`, active Issues and open PR ownership before implementation. This lane does not own primitive-specific product behavior or generic Database/View presentation.

## Lane goal
Keep reusable Object/ObjectType identity, schema semantics, Body and generic opening/detail contracts coherent across built-in and user-defined ObjectTypes.

## Primary issues
- #481 — universal Body/note surface for every ObjectType.
- #56 — Object/ObjectType/detail/opening portions of the generic architecture umbrella.
- #484 — user-defined ObjectType core semantics and the built-in/custom boundary.
- #493 — only the ordinary Object/ObjectType core integrity portions; Relation migration correctness remains Lane B and schema-authoring UX remains Lane C.

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
Latest Lane A verified main checkpoint while writing this handoff: `71a8ed14acf10f8efd6d4c2592cffb029a88c00a`.

### Universal Body
- #503 merged as `a8cf84d3af59ef537ae66518b7c7a9f4206c43c5`.
- `ObjectInspectorPage` allows Body editing for every ObjectType, including system ObjectTypes, while system title/Property/create identity guards remain intact.
- Center peek and full-page generic opening already reuse `ObjectInspectorPage`.
- Side peek remains a Lane C presentation surface; Lane A must not reimplement Body persistence there.

### ObjectType defaults integrity
- #640 merged as `1c68d4fdecfec9791d630c37fb0a34e7db9f24e2` after full CI green.
- Non-empty ObjectType defaults writes now fail closed when the ObjectType is missing or `visiblePropertyIds` / `propertyOrder` reference missing or foreign Properties.
- Existing tests were corrected to create real owned Properties; historical-corruption regressions now seed corrupt JSON below the validated public write API rather than weakening validation.
- #650 merged as `cf347443173ad9a8bb834bd0a807c2765ef043e9` after full CI green.
- `ObjectTypeDefaults.fromJson` accepts a JSON object and fails closed on malformed top-level non-object shapes instead of silently treating corruption as no overrides.

### Daily Note identity
- #647 merged as `212b2626912332736dec2644669ce0c5cb398f36` after full CI green.
- Registry insertion is an explicit `(workspace, local-date)` claim; legacy adoption returns a concurrent winner, and lost new-object claims clean up the duplicate inside the same transaction so cleanup failure rolls the whole creation back.
- #656 merged as `71a8ed14acf10f8efd6d4c2592cffb029a88c00a` after full CI green.
- A registry row is authoritative only while its `object_id` still resolves inside the canonical Daily Note ObjectType. Exact stale claims are removed with `(workspace, date, object_id)` matching, then the normal race-safe open/create path reclaims the date.
- Superseded overlapping Daily Note PRs #644 and #655 were closed so there is no duplicate temporary lease on `daily_note_service.dart`.

## Active Lane A WIP
### #660 — ordinary Property deletion keeps ObjectType defaults valid
Branch: `fix-object-property-delete-defaults-integrity-56`

Design:
- new `ObjectPropertyDeletionService` composes existing `ObjectStore` and `ObjectTypeDefaultsStore` APIs rather than rewriting shared semantic-center files;
- ordinary Property deletion prunes that Property id from ObjectType `visiblePropertyIds` and `propertyOrder` before deleting the Property row;
- pruning and deletion occur in one database transaction;
- `openMode` and Body template are preserved;
- unrelated historical defaults corruption causes the deletion to fail closed rather than leave schema/defaults inconsistent;
- Relation Properties are explicitly rejected so paired/index lifecycle stays with Lane B canonical Relation APIs.

Validation:
- focused tests cover ordinary pruning/preservation, Relation boundary enforcement, and fail-closed rollback when unrelated stale defaults remain;
- Flutter CI #2074 was queued for head `736fd4d4f307f90019abdc9d128cf5207cdc9e20` at this checkpoint.

## Hotspot / ownership notes
- Open-PR audit immediately before #660 found no temporary lease on `object_store.dart` or `object_type_defaults_store.dart`.
- A direct whole-file change to `object_type_defaults_store.dart` was avoided; #660 uses a new narrow service and existing public APIs instead.
- Keep `object_store.dart`, `generic_database_store.dart`, `object_inspector_page.dart` and other semantic/shared hosts patch-sized and check leases again immediately before editing.
- Current unrelated open PRs own Lane B Relation internals and Lane C schema-authoring presentation; do not absorb their responsibilities into Lane A.

## Cross-lane dependencies
- Side-peek Body composition is Lane C; reuse canonical Body/detail contracts instead of creating a second persistence path.
- Ordinary Property deletion/default-reference integrity can be Lane A core, but Relation Property deletion/target/cardinality migration remains Lane B.
- Schema-authoring buttons/dialogs that invoke the core deletion boundary remain Lane C.

## Next actions
1. Process Flutter CI #2074 for #660; fix only focused service/test issues, and merge only after full CI green.
2. After #660, coordinate adoption of the ordinary-Property deletion boundary without editing Lane C presentation or Lane B Relation lifecycle.
3. Re-audit #56/#481/#484 for independent core/domain/test gaps: aliases, Body/reference semantics, Daily Note identity, typed non-Relation values, or user-defined ObjectType invariants.
4. Do not invent primitive/search/storage/refactor work when Lane A has no safe core slice.

## Stop rule
A green PR or one completed slice is not itself a stop condition. Continue to another independent Lane A core slice while safe work exists; stop rather than manufacture changes when only leased hotspots or other lanes' responsibilities remain.
