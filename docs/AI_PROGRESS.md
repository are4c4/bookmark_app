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
- `#218` — macOS installable delivery; repository packaging/CI is complete, final user-machine install/launch/data-preservation validation remains.
- `#225` — maintainability, hotspot reduction and legacy-path retirement.
- `#242` — user-selectable Vault/storage lifecycle; production implementation is complete, final real-macOS validation remains.
- `#245` — legacy Photos -> canonical Image Objects.
- `#249` — remaining Bookmark presentation parity.
- `#481` — universal Body/note surface for every ObjectType.
- `#484` — built-in primitive ObjectTypes and user-composable domain databases.
- `#489` — capability-oriented shared native behavior.
- `#490` — templates instantiate user-owned ObjectTypes/Databases/Views.
- `#491` — Relation Property authoring and inline target creation UX.
- `#492` — generic Gallery cover source from Object Relations.
- `#493` — safe/reversible user-defined schema evolution.
- `#501` — 7-lane AI development ownership model.

Recently completed architecture/search/primitive work:
- `#414` — focused Bookmark FTS stale-token correctness; closed after rowid-based refresh regression coverage.
- `#494` — unified canonical Object search/indexing; closed after live Object Global Search, Weblink metadata and PDF-derived File text integration.
- `#495` — MIME/content-aware Image/File import routing; closed after #866 routed the real canonical Images picker through shared content classification before mutation while preserving the legacy Photo picker.
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
- #495 content-aware file import is complete/closed; future work needs a new concrete routing inconsistency rather than extending that issue speculatively.
- Tag built-in/default semantics where not pure Relation integrity.

### E — Search & Indexing
- #414 and #494 are complete/closed.
- No active Search issue at this checkpoint; remain idle until a concrete Search/Indexing issue or cross-lane search obligation appears.
- The old Bookmark-only `FullTextSearchRepository` has already been retired by Refactor #654; do not recreate a parallel domain-specific search product.

### F — Storage, Vault & Delivery
- #242 Vault/Profile/filesystem lifecycle: code complete; real-macOS validation pending.
- #218 release/install delivery: repository packaging complete; user-machine validation pending.
- Shared managed-file copy/ownership/rollback/delete filesystem contract for primitives is delivered on `main`.

### G — Refactor & Architecture Health
- #225 only: behavior-preserving extraction/deletion, caller-zero legacy retirement, AppDatabase narrowing, failure policy and CI/architecture guardrails.

## Current implementation position — 2026-09-08
The seven lanes continue merging concurrently; always re-read the actual latest `main` before starting work.

Major integrated state:
- generic Object/ObjectType/Database/View foundations are live in real hosts;
- canonical Relation mutation/read/index/backlink/audit/reconcile is mature;
- Bookmark -> Weblink and Weblink -> managed Image production paths are canonicalized;
- Weblinks / Images / Daily Notes are exposed through generic navigation hosts;
- Weblink URL creation, metadata enrichment and managed representative media are largely integrated;
- canonical Image import/reuse, Photo mirroring, Bookmark `Images`/`Cover Image` Relations, backlinks, safe deletion and editing are advanced;
- Image edit actions include rotate, horizontal/vertical flip, restore, crop presets and normalized free crop; missing persisted geometry can fall back read-only to managed bytes;
- canonical Image/File routing now uses shared content-aware classification at real generic entry points: #866 made the Images collection picker content-first, rejects mixed Image/File selections before mutation, and leaves the legacy Photo picker unchanged; #495 is closed;
- Bookmark center peek, shared Property handle/add flows, Person chips and much of List metadata presentation are converged;
- generic fixed/masonry Gallery is implemented;
- **Global Search is canonical Object search:** one FTS projection covers title/aliases, selected typed Properties, universal Body, Relation labels, dedicated Weblink metadata and replaceable derived text; user-defined ObjectTypes and real Image/File primitives use the same repository;
- **PDF remains a File Object:** Primitive lane exposes content-first PDF extracted text and Search reconciles it as replaceable `pdf-text` during Global Search workspace rebuild/focused File refresh;
- live `GlobalSearchPage` routes through canonical Object search, and Refactor #654 has removed the superseded Bookmark-only `FullTextSearchRepository` implementation and its dedicated legacy-only tests;
- **Storage-managed files use one Vault filesystem contract:** #750 provides copy + portable path + explicit ownership + rollback, #771 adds ownership-gated physical delete, #766 reuses the copy seam for legacy Bookmark attachments, and canonical generic File import consumes the shared copy/rollback boundary;
- Refactor work has materially reduced caller-zero/dead layers and added architecture regression ceilings;
- macOS release/DMG packaging CI has succeeded; the final user-machine install/launch/data-preservation check remains open in #218.

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
- Primitive lane owns Object/file identity, metadata and MIME/content routing; Storage lane owns Vault/filesystem byte placement, portable paths, explicit ownership, rollback and physical delete safety.
- Database/View lane owns schema authoring UX; Relation/Data Integrity lane owns correctness of destructive target/cardinality migrations.
- Object Core owns Body persistence/edit contracts; Search lane owns indexing Body text.
- Primitive lane owns PDF/File extraction behavior; Search lane owns derived-text persistence/index/reconciliation.
- Refactor deletes legacy code only after the owning product lane proves replacement parity; #654 is the completed Bookmark-FTS example of that policy.

## Immediate high-value parallel work
1. **A Object Core:** continue the remaining #481/#56 shared Object Core work identified in its lane handoff.
2. **B Relations/Integrity:** continue #493 integrity work and audit new Relation-producing workflows as they land.
3. **C Database/View:** continue generic schema/View/template UX from #490/#491/#492/#493 away from leased hotspots.
4. **D Primitives:** continue #155/#245 presentation/caller convergence. #495 is completed/closed; do not create speculative routing work to keep that issue alive.
5. **E Search:** #414/#494 complete and legacy Bookmark FTS retired; stay idle unless a new Search issue appears. Do not invent speculative search abstractions.
6. **F Storage:** no independent repository implementation is currently required; remain idle pending real-macOS #242/#218 validation or a concrete filesystem/Vault contract gap reported by another lane.
7. **G Refactor:** continue #225 with the next verified caller-zero/dependency-narrowing slice.

## Known risks
- legacy Bookmark URL/thumbnail/Photo tables remain compatibility data while live/import/export/backup paths need them;
- user-defined schema evolution can silently corrupt data unless target/cardinality/type changes are explicit and transactional;
- Image/File shared infrastructure must not weaken current Image ownership/delete/edit safety;
- PDF text reconciliation currently runs during Global Search workspace rebuild; very large File sets may eventually justify separately scoped caching/performance work, but that is not required by completed #494;
- Vault changes must not silently replace inaccessible storage with a new empty database;
- managed-file physical deletion must require explicit Storage ownership and must not infer authority from a Vault-relative-looking path alone;
- current large shared hosts are still conflict magnets; throughput comes from responsibility splits plus hotspot leases, not from letting every lane edit the same host concurrently;
- an idle lane is preferable to speculative abstractions.

## Handoff rule
Each lane updates only its own progress file during normal work. Update this repository-wide file when lane routing, architecture decisions, cross-lane dependencies or global priorities materially change.
