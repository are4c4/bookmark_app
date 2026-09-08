# AI Development Instructions

This repository is developed with AI-assisted planning and implementation.

## Source of truth

Before changing code, read these in order:

1. The active focused GitHub Issue and its acceptance criteria.
2. `docs/product_architecture.md` for the durable product architecture constitution.
3. `docs/AI_PROGRESS.md` for repository-wide integration/routing state.
4. The progress file for the active implementation lane:
   - `docs/AI_PROGRESS_OBJECT.md` — Object Core & Body.
   - `docs/AI_PROGRESS_RELATION.md` — Relations & Data Integrity.
   - `docs/AI_PROGRESS_DATABASE_VIEW.md` — Database, View & Schema UX.
   - `docs/AI_PROGRESS_PRIMITIVES.md` — Weblink/Image/File native-capability Objects and media behavior.
   - `docs/AI_PROGRESS_SEARCH.md` — Search & Indexing.
   - `docs/AI_PROGRESS_STORAGE.md` — Storage, Vault & Delivery.
   - `docs/AI_PROGRESS_REFACTOR.md` — Refactor & Architecture Health.
5. Existing code, tests, and other repository documentation.

`docs/product_architecture.md` is a stable product contract. A focused Issue may refine implementation details, but it must not silently contradict that architecture. Resolve a real conflict explicitly before implementation.

`docs/AI_PROGRESS_OBJECT_RELATION.md` is legacy combined context only. New runs must not use it as their primary writable handoff.

GitHub is the durable handoff layer between chat sessions. Live Issues, PRs, CI and `main` are authoritative for transient state; do not rely on chat history or stale handoff snapshots alone.

## Product architecture baseline

The product is a local-first, Object-first personal knowledge/database application, not a Bookmark-centric application.

- Every durable user-facing entity is an Object.
- One Object has one primary ObjectType.
- ObjectType answers “what is this?”; roles/classifications normally belong to Relations, Properties, Tags or Database/query context.
- Objects are global inside a Vault and are not owned or duplicated by Databases or Views.
- Database defines an Object set/context; View defines presentation/query configuration over it.
- Object content is structured Properties/Relations plus a free-form versioned Body.
- Weblink, Image and File are Objects with native capabilities.
- Person, Book, Paper, Project, Recipe, Tag, TagGroup and similar concepts use the generic ObjectType system; specialized UX may exist without creating a parallel persistence subsystem.
- `Bookmark` is legacy compatibility/migration input, not a final ObjectType. Normal URL capture creates/reuses a canonical Weblink Object.
- Tag is not a native media primitive. Tag hierarchy uses canonical Object/Relation persistence; B owns integrity and C owns hierarchy-aware query/UX.
- Historical Bookmark/People/Photo schema/data remains until replacement parity, caller-zero proof, preservation validation and any explicit destructive migration are complete.

## Seven-lane development model

Each implementation run/PR has exactly one primary lane. The split is by responsibility, not by file count.

### Lane A — Object Core & Body

Owns:
- Object/ObjectType identity and core lifecycle semantics;
- generic Property value/type semantics that are not presentation-specific;
- universal Body/block/reference model and document-edit contracts;
- aliases/shared Object identity metadata;
- Daily Note identity/navigation/time-based Object patterns;
- generic Object opening/detail contracts;
- user-defined ObjectType core behavior;
- migration/reconciliation contracts when generic Object identity is authoritative.

Does not own Weblink/Image/File native behavior, Relation integrity, Database/View UX, FTS, Vault lifecycle or broad refactoring.

### Lane B — Relations & Data Integrity

Owns:
- canonical Relation mutation/read/index/backlink/audit/reconcile lifecycle;
- bidirectional Relation integrity;
- target/source/cardinality/order constraints;
- delete/detach/retarget/retry/idempotency correctness;
- fail-closed corruption handling;
- integrity-sensitive schema evolution;
- Tag hierarchy parent/group integrity and cycle prevention;
- Relation-producing workflow atomicity.

Preserve the canonical Relation subsystem. Do not invent parallel edge stores or speculative Relation abstractions.

### Lane C — Database, View & Schema UX

Owns:
- Database collection/query semantics;
- View persistence and Table/List/Gallery/Board presentation contracts;
- Filter/Sort/Group/Layout/visible Properties;
- Property-authoring and schema-editing UX;
- user-owned template/domain schema instantiation UX;
- generic Gallery cover/media-source configuration;
- Tag hierarchy query/filter/picker/tree UX;
- generic Person/Weblink/Object collection/navigation surfaces and legacy dedicated-page replacement after parity.

C owns generic presentation/configuration, not native Weblink/Image/File semantics or Relation integrity.

### Lane D — Primitive Objects & Media

Owns:
- Weblink identity, URL normalization, metadata/enrichment and capture-native behavior;
- Image identity/provenance/import/editing and Photo -> Image primitive migration behavior;
- canonical File primitive;
- managed-file/native capability infrastructure shared by Image/File;
- MIME/content import classification and routing;
- PDF/File preview, thumbnail, metadata and extracted-text producer behavior.

Tag/TagGroup are generic ObjectTypes, not D-owned native primitives. D may provide only a concrete native-capability prerequisite explicitly required by another issue.

### Lane E — Search & Indexing

Owns:
- canonical Object search architecture;
- FTS correctness, ranking and stale-token behavior;
- indexing title/aliases/Properties/Body/Weblink metadata and derived extracted text;
- focused refresh/rebuild/reconciliation;
- search-result resolution/opening behavior.

New domains contribute to canonical Object search rather than creating domain-specific long-term indexes.

### Lane F — Storage, Vault & Delivery

Owns:
- Vault/Profile directory lifecycle and user-selectable storage;
- filesystem-level managed storage boundaries;
- profile/Vault-relative path handling;
- backup/restore/duplication/move/recovery;
- app packaging/delivery;
- preservation validation before destructive legacy schema retirement.

F owns byte/location lifecycle, not Object identity or native media semantics.

### Lane G — Refactor & Architecture Health

Owns:
- Issue #225 maintainability work;
- behavior-preserving extraction/responsibility reduction;
- legacy Bookmark/People/Photo caller-zero retirement after owning-lane parity;
- `AppDatabase` narrowing and migration-body extraction with regressions;
- failure/privacy observability guardrails;
- CI/developer-loop and architecture-boundary enforcement;
- temporary shim retirement and incremental movement toward `lib/features/...` ownership;
- repository-wide architecture/handoff synchronization such as #1048.

G must not redesign working product semantics under a refactor label.

## Ownership and concurrency rules

- Identify exactly one primary lane before editing.
- One focused Issue has one active implementation owner/branch/PR. Umbrellas may have many focused child Issues.
- Do not modify another lane's progress file except for a repository-wide coordination/architecture change or an explicit cross-lane dependency.
- Split cross-lane work by coherent acceptance slices and sequence dependencies.
- Before non-trivial edits to shared hotspots such as `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `bookmark_reorderable_properties.dart`, `people_management_page.dart`, `settings_page.dart`, `profile_manager.dart`, or `app_database.dart`, inspect current open PR ownership.
- Shared hotspots use temporary ownership leases. Patch-sized non-overlapping work may proceed only after confirming behavior/region non-overlap.
- Schema/migration writer work is single-writer.
- Relation subsystem redesign is not a Refactor-lane goal.
- Idle is acceptable when no independent safe work exists; never invent speculative abstractions to keep a lane busy.

## Current issue routing

Always verify live Issues because this list is a routing aid, not transient ownership state.

- **A:** #1041 Bookmark→Weblink/generic Object migration contract; #1044 generic Person authority; #1049 document-like Body UX; #56 core follow-ups.
- **B:** #1042 Bookmark-era Relation convergence; #1045 Person groups/roles; #1052 Tag hierarchy integrity.
- **C:** #1043 Stage1→generic Weblink/Object Database/View + Inbox; #1046 People→generic Person Database/View; #1053 hierarchy-aware Tag filtering/UX.
- **D:** #1054 direct canonical Weblink capture; #155/#245 only for concrete native Weblink/Image/File obligations.
- **E:** focused Search issues when canonical FTS correctness/freshness obligations are demonstrated.
- **F:** #951/#242 preservation and real-machine Vault validation; later preservation gates for destructive legacy migration.
- **G:** #1048 architecture/handoff alignment, #1047/#225 maintainability, #950 and future caller-zero Bookmark/People/Photo retirement.

Umbrellas #56, #1039, #1040, #1050, #155, #225, #245 organize broader direction; implement through focused child Issues when possible.

## Autonomous implementation loop

When a focused task is active, continue without asking for confirmation for routine reversible engineering decisions inside its contract.

1. Inspect latest `main`, active Issue/branch, open PR ownership and relevant CI.
2. Read `docs/product_architecture.md`, repository handoff and active lane handoff.
3. Select the next unfinished acceptance criterion.
4. Implement one coherent slice.
5. Add/update tests where practical.
6. Run the most relevant validation available.
7. Fix failures caused by the change.
8. Commit/push the coherent slice.
9. Update the active lane handoff with durable facts.
10. Do not stop merely because one slice/commit/PR is complete; continue to the next safe non-conflicting slice.
11. If CI is pending, continue independent work rather than waiting idly.
12. Update `docs/AI_PROGRESS.md` when architecture/routing/global priority materially changes.

### Stop only when

- the active focused Issue/lane has no actionable work;
- a genuine product decision requires user input;
- the next step is destructive/irreversible or deletes user data and lacks explicit approval;
- an unavoidable cross-lane conflict/dependency blocks safe work;
- external infrastructure failure blocks all independent safe work;
- runtime/tool/session limits are reached.

One PR, one commit, one passing test suite or pending CI is not by itself a stop reason.

## Handoff requirement

Before a run ends, keep the active lane progress file usable without chat history. Record:
- current goal/focused Issue;
- durable branch/commit/PR checkpoint when one exists;
- completed checkpoints;
- work in progress and exact next actions;
- validation/results;
- cross-lane dependencies and hotspot/migration ownership;
- blockers/risks;
- stop reason.

Avoid durable claims such as “no PR currently exists” or “lane X is running now” unless they are explicitly labeled as time-sensitive and necessary. Live GitHub state must be rechecked on resume.

## Migration and legacy-retirement safety

Use this sequence:

```text
replacement contract
→ parity
→ caller-zero proof
→ legacy UI/API/code deletion
→ preservation validation
→ explicit destructive schema migration
```

Do not delete user data merely because replacement UI exists. Existing historical migrations are compatibility contracts; preserve semantics/order and add historical regressions when refactoring or retiring them.

## Branch, commit and CI hygiene

- Use dedicated branches for non-trivial work; prefer lane-identifiable names (`feature/object-*`, `feature/relation-*`, `feature/database-view-*`, `feature/primitives-*`, `feature/search-*`, `feature/storage-*`, `refactor/issue-*`, `docs/*`).
- Keep `main` releasable and refresh from latest `main` before integration when overlapping foundations changed.
- Do not create commits solely to trigger CI or manufacture activity.
- Do not add/remove temporary marker files, whitespace churn, unrelated formatting or meaningless comments as CI triggers.
- Rerun CI through workflow/check mechanisms when available; otherwise wait for the next meaningful change.
- Never merge artificial no-op commits.
- Prefer several small coherent commits over one oversized change.
- Merge only after relevant checks pass, unless the user explicitly directs otherwise.

## Safety and scope

- Do not expose secrets or credentials.
- Do not silently broaden a focused Issue.
- Do not perform destructive migration/user-data deletion without explicit approval and preservation evidence.
- If a major product decision is genuinely ambiguous, record alternatives/blocker instead of inventing semantics.
- Prefer deletion/small extraction over abstraction for its own sake.

## Planning vs implementation chats

Planning/design work should refine durable Issues and `docs/product_architecture.md` when architecture changes. Implementation chats adopt one lane and one focused Issue, execute it through multiple safe checkpoints, and keep the matching lane handoff current. Separate lane chats are useful for parallelism but are not required.