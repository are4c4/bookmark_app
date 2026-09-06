# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files. Always verify live GitHub Issue/PR/CI state before editing shared hotspots.

## Current goal
Continue the transition from a Bookmark-specific application toward a composable Object/Relation/Database knowledge platform while preserving existing user data and reducing legacy maintenance cost.

Core product direction:
- Object is the durable reusable entity.
- ObjectType = schema/default behavior.
- Database = collection/query context.
- View = presentation/query configuration.
- Built-in code is reserved for irreducible primitives/behaviors; domain models such as Bookmark/Paper/Book/Project should increasingly be user-composable templates/configuration.

## Active architecture/product issues
- `#56` — generic Object/Database/View daily-use integration umbrella.
- `#155` — reusable Weblink Object and legacy Bookmark URL/media convergence.
- `#218` — macOS installable delivery; implementation is effectively complete, final issue cleanup/validation remains.
- `#225` — maintainability, hotspot reduction and legacy-path retirement.
- `#242` — user-selectable Vault/storage lifecycle.
- `#245` — legacy Photos -> canonical Image Objects.
- `#249` — remaining Bookmark presentation parity.
- `#481` — universal Body/note surface for every ObjectType.
- `#484` — built-in primitive ObjectTypes and user-composable domain databases.
- `#489` — capability-oriented shared native behavior.
- `#490` — templates instantiate user-owned ObjectTypes/Databases/Views.
- `#491` — Relation Property authoring and inline target creation UX.
- `#492` — generic Gallery cover source from Object Relations.
- `#493` — safe/reversible user-defined schema evolution.
- `#495` — MIME/content-aware import routing to Image/File.
- `#501` — 7-lane AI development ownership model.

Recently completed architecture/search work:
- `#414` — focused Bookmark FTS stale-token correctness; closed after rowid-based refresh regression coverage.
- `#494` — unified canonical Object search/indexing; closed after live Object Global Search, Weblink metadata and PDF-derived File text integration.
- Refactor `#654` — caller-zero legacy Bookmark `FullTextSearchRepository` retired after canonical Global Search replacement parity.

## Seven development lanes
- **A — Object Core & Body** — `docs/AI_PROGRESS_OBJECT.md`
- **B — Relations & Data Integrity** — `docs/AI_PROGRESS_RELATION.md`
- **C — Database, View & Schema UX** — `docs/AI_PROGRESS_DATABASE_VIEW.md`
- **D — Primitive Objects & Media** — `docs/AI_PROGRESS_PRIMITIVES.md`
- **E — Search & Indexing** — `docs/AI_PROGRESS_SEARCH.md`
- **F — Storage, Vault & Delivery** — `docs/AI_PROGRESS_STORAGE.md`
- **G — Refactor & Architecture Health** — `docs/AI_PROGRESS_REFACTOR.md`

Each implementation run/PR has exactly one primary lane. Issues may span lanes, but implementation should be split into coherent slices and sequenced across lane boundaries.

## Initial issue routing
### A — Object Core & Body
- #481 universal Body.
- Core Object/ObjectType/identity/Body portions of #56/#484.
- Daily Note, aliases and shared Object detail/opening contracts.

### B — Relations & Data Integrity
- Canonical Relation lifecycle and regressions.
- Integrity side of #493 schema evolution.
- New Relation-producing workflows from #491/#492/#245/#484.
- Cross-object delete/detach/retarget/cardinality correctness.

This lane is intentionally broader than the former Relation-only lane so mature Relation production code can remain stable while independent integrity/schema-correctness work proceeds.

### C — Database, View & Schema UX
- #490 template/domain model instantiation.
- #491 Relation Property authoring UX.
- #492 generic Gallery cover-source configuration.
- User-facing schema-editing portion of #493.
- Generic Database/View portions of #249/#56.

### D — Primitive Objects & Media
- #155 Weblink.
- #245 Image / Photo migration.
- #484 File primitive and built-in boundary.
- #489 native capabilities/shared managed-file semantics.
- #495 content-aware file import.
- Tag built-in/default semantics where not pure Relation integrity.

### E — Search & Indexing
- #414 and #494 are complete/closed.
- No active Search issue at this checkpoint; remain idle until a concrete Search/Indexing issue or cross-lane search obligation appears.
- The old Bookmark-only `FullTextSearchRepository` has already been retired by Refactor #654; do not recreate a parallel domain-specific search product.

### F — Storage, Vault & Delivery
- #242 Vault/Profile/filesystem lifecycle.
- #218 release/install delivery.
- Filesystem/backup/restore portions required by File/Image portability.

### G — Refactor & Architecture Health
- #225 only: behavior-preserving extraction/deletion, caller-zero legacy retirement, AppDatabase narrowing, failure policy and CI/architecture guardrails.

## Current implementation position — 2026-09-07
Latest Search feature completion checkpoint: `683bdbb74cc5dabd3ac067e9ce5a802fc16ca2b4` (#635). Legacy Bookmark FTS retirement followed in `c2d4bd082e1e88c6781db4f51b2c12998a6ff85f` (#654). The seven lanes continue merging concurrently; always re-read the actual latest main before starting work.

Major integrated state:
- generic Object/ObjectType/Database/View foundations are live in real hosts;
- canonical Relation mutation/read/index/backlink/audit/reconcile is mature;
- Bookmark -> Weblink and Weblink -> managed Image production paths are canonicalized;
- Weblinks / Images / Daily Notes are exposed through generic navigation hosts;
- Weblink URL creation, metadata enrichment and managed representative media are largely integrated;
- canonical Image import/reuse, Photo mirroring, Bookmark `Images`/`Cover Image` Relations, backlinks, safe deletion and editing are advanced;
- Image edit actions include rotate, horizontal/vertical flip, restore, crop presets and normalized free crop; missing persisted geometry can fall back read-only to managed bytes;
- Bookmark center peek, shared Property handle/add flows, Person chips and much of List metadata presentation are converged;
- generic fixed/masonry Gallery is implemented;
- **Global Search is canonical Object search:** one FTS projection covers title/aliases, selected typed Properties, universal Body, Relation labels, dedicated Weblink metadata and replaceable derived text; user-defined ObjectTypes and real Image/File primitives use the same repository;
- **PDF remains a File Object:** Primitive lane exposes content-first PDF extracted text and Search reconciles it as replaceable `pdf-text` during Global Search workspace rebuild/focused File refresh;
- live `GlobalSearchPage` routes through canonical Object search, and Refactor #654 has removed the superseded Bookmark-only `FullTextSearchRepository` implementation and its dedicated legacy-only tests;
- Refactor work has materially reduced caller-zero/dead layers and added architecture regression ceilings;
- macOS release packaging and local launch/data-preservation validation have succeeded.

The largest product gap is no longer the Object/Relation/search core. It is **composability and migration**: making generic schema/View/template primitives strong enough that Bookmark and future domains do not require dedicated management code, while safely retiring remaining legacy Bookmark/Photo paths.

## Repository-wide design contract
- Objects are global and are not owned/duplicated by Databases or Views.
- ObjectType defines schema/defaults; Database selects Objects; View controls presentation/query.
- Defaults resolve `View > Database > ObjectType > app`.
- Object content = typed Properties + versioned block-oriented Body.
- Weblink/Image/File/Tag are candidate built-in primitives because they have irreducible native behavior/default semantics.
- Image and File remain distinct ObjectTypes but should reuse managed-file capabilities where appropriate.
- PDF is initially a File Object with MIME/type-specific preview/enrichment/search behavior, not a parallel persistence model.
- Bookmark/Note/Paper/Book/Project/Recipe/etc. should normally be user-owned/template ObjectTypes built from generic Properties/Relations/Databases/Views.
- Relation writes/deletes use canonical Relation APIs; do not create format/domain-specific edge stores.
- New domains participate in canonical Object search rather than adding long-term domain-specific search indexes.
- New Object-first work must not deepen legacy Bookmark/Photo dependencies unless required for compatibility/migration.

## Concurrency / hotspot rule
Shared hotspots currently include:
- `generic_database_page.dart`
- `app_shell.dart`
- `object_inspector_page.dart`
- `bookmark_unified_stage1_page.dart`
- `bookmark_reorderable_properties.dart`
- `people_management_page.dart`
- `settings_page.dart`
- `profile_manager.dart`
- `app_database.dart`

Before a non-trivial edit, inspect open PR ownership. One lane at a time may hold a broad **hotspot lease**. Other lanes should choose service/domain/test-only work or a proven patch-sized non-overlapping hunk.

## Cross-lane boundaries
- Database/View lane owns generic presentation/settings; Primitive lane owns Weblink/Image/File product semantics.
- Primitive lane owns Object/file identity; Storage lane owns Vault/filesystem lifecycle and portability.
- Database/View lane owns schema authoring UX; Relation/Data Integrity lane owns correctness of destructive target/cardinality migrations.
- Object Core owns Body persistence/edit contracts; Search lane owns indexing Body text.
- Primitive lane owns PDF/File extraction behavior; Search lane owns derived-text persistence/index/reconciliation.
- Refactor deletes legacy code only after the owning product lane proves replacement parity; #654 is the completed Bookmark-FTS example of that policy.

## Immediate high-value parallel work
1. **A Object Core:** continue the remaining #481/#56 shared Object Core work identified in its lane handoff.
2. **B Relations/Integrity:** continue #493 integrity work and audit new Relation-producing workflows as they land.
3. **C Database/View:** continue generic schema/View/template UX from #490/#491/#492/#493 away from leased hotspots.
4. **D Primitives:** continue #155/#245/#484/#489/#495 primitive/media migration work from its current handoff.
5. **E Search:** #414/#494 complete and legacy Bookmark FTS retired; stay idle unless a new Search issue appears. Do not invent speculative search abstractions.
6. **F Storage:** continue #242/#218 Vault/storage/delivery work from its current handoff.
7. **G Refactor:** continue #225 with the next verified caller-zero/dependency-narrowing slice after #654.

## Known risks
- legacy Bookmark URL/thumbnail/Photo tables remain compatibility data while live/import/export/backup paths need them;
- user-defined schema evolution can silently corrupt data unless target/cardinality/type changes are explicit and transactional;
- Image/File shared infrastructure must not weaken current Image ownership/delete/edit safety;
- PDF text reconciliation currently runs during Global Search workspace rebuild; very large File sets may eventually justify separately scoped caching/performance work, but that is not required by completed #494;
- Vault changes must not silently replace inaccessible storage with a new empty database;
- current large shared hosts are still conflict magnets; throughput comes from responsibility splits plus hotspot leases, not from letting every lane edit the same host concurrently;
- an idle lane is preferable to speculative abstractions.

## Handoff rule
Each lane updates only its own progress file during normal work. Update this repository-wide file when lane routing, architecture decisions, cross-lane dependencies or global priorities materially change.
