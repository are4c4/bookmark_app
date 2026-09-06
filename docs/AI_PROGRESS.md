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
- `#414` — stale FTS token correctness bug.
- `#481` — universal Body/note surface for every ObjectType.
- `#484` — built-in primitive ObjectTypes and user-composable domain databases.
- `#489` — capability-oriented shared native behavior.
- `#490` — templates instantiate user-owned ObjectTypes/Databases/Views.
- `#491` — Relation Property authoring and inline target creation UX.
- `#492` — generic Gallery cover source from Object Relations.
- `#493` — safe/reversible user-defined schema evolution.
- `#494` — unified Object search/indexing.
- `#495` — MIME/content-aware import routing to Image/File.
- `#501` — 7-lane AI development ownership model.

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
- #414 stale FTS refresh correctness.
- #494 canonical Object search projection and indexing.

### F — Storage, Vault & Delivery
- #242 Vault/Profile/filesystem lifecycle.
- #218 release/install delivery.
- Filesystem/backup/restore portions required by File/Image portability.

### G — Refactor & Architecture Health
- #225 only: behavior-preserving extraction/deletion, caller-zero legacy retirement, AppDatabase narrowing, failure policy and CI/architecture guardrails.

## Current implementation position — 2026-09-07
Latest verified `main` while defining this routing: `f39f5e04d63795796cff8b25af3d06fd13518454`.

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
- Refactor work has materially reduced caller-zero/dead layers and added architecture regression ceilings;
- macOS release packaging and local launch/data-preservation validation have succeeded.

The largest product gap is no longer the Object/Relation core. It is **composability and migration**: making generic schema/View/template primitives strong enough that Bookmark and future domains do not require dedicated management code, while safely retiring legacy Bookmark/Photo paths.

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
- New domains should participate in canonical Object search rather than adding long-term domain-specific search indexes.
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
- Refactor deletes legacy code only after the owning product lane proves replacement parity.

## Immediate high-value parallel work
1. **A Object Core:** #481 universal Body with a focused shared-host regression.
2. **B Relations/Integrity:** define/test #493 Relation target/cardinality migration fail-closed rules; audit new #491/#492 workflows as they land.
3. **C Database/View:** start #491 generic Relation Property authoring or #490 template instantiation away from currently leased hotspots.
4. **D Primitives:** continue #245 shared-host/legacy Photo parity and design canonical File primitive/#489 capability seam.
5. **E Search:** reproduce and fix #414, then use that foundation for #494.
6. **F Storage:** begin #242 with custom directory-path regressions and read-only Vault path/Finder reveal slices.
7. **G Refactor:** continue #225 caller-zero/guardrail work that does not overlap product-owned hotspots.

## Known risks
- legacy Bookmark URL/thumbnail/Photo tables remain compatibility data while live/import/export/backup paths need them;
- user-defined schema evolution can silently corrupt data unless target/cardinality/type changes are explicit and transactional;
- Image/File shared infrastructure must not weaken current Image ownership/delete/edit safety;
- Vault changes must not silently replace inaccessible storage with a new empty database;
- current large shared hosts are still conflict magnets; throughput comes from responsibility splits plus hotspot leases, not from letting every lane edit the same host concurrently;
- an idle lane is preferable to speculative abstractions, but the expanded routing should provide independent work in Database/View, Search, Storage and integrity while Relation production semantics remain mature.

## Handoff rule
Each lane updates only its own progress file during normal work. Update this repository-wide file when lane routing, architecture decisions, cross-lane dependencies or global priorities materially change.
