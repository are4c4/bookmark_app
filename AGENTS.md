# AI Development Instructions

This repository is developed with AI-assisted planning and implementation.

## Source of truth

Before changing code, read these in order:

1. The active focused GitHub Issue and its acceptance criteria, when an implementation/coordination Issue is active.
2. `docs/product_architecture.md` for the durable product architecture constitution.
3. `docs/AI_PROGRESS.md` for repository-wide integration/routing state.
4. The progress file for the active lane:
   - `docs/AI_PROGRESS_OBJECT.md` — Object Core & Body.
   - `docs/AI_PROGRESS_RELATION.md` — Relations & Data Integrity.
   - `docs/AI_PROGRESS_DATABASE_VIEW.md` — Database, View & Schema UX.
   - `docs/AI_PROGRESS_PRIMITIVES.md` — Weblink/Image/File native-capability Objects and media behavior.
   - `docs/AI_PROGRESS_SEARCH.md` — Search & Indexing.
   - `docs/AI_PROGRESS_STORAGE.md` — Storage, Vault & Delivery.
   - `docs/AI_PROGRESS_REFACTOR.md` — Refactor & Architecture Health.
   - `docs/AI_PROGRESS_OVERSIGHT.md` — H Architecture & Integration Oversight / control tower.
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
- Home should converge on Inbox / Recent / Favorites / Pinned Databases rather than permanent legacy domain modules.
- Object merge, open export/portability and durable version history are explicit future first-class contracts; do not improvise lossy substitutes.

## Seven implementation lanes + H oversight

A–G are implementation ownership lanes. Each implementation run/PR has exactly one primary implementation lane, split by responsibility rather than file count.

H is a repository-wide oversight/control-tower lane. It may own focused coordination/guardrail/documentation work but does not normally own product/runtime implementation.

### Lane A — Object Core & Body

Owns:
- Object/ObjectType identity and core lifecycle semantics;
- generic Property value/type semantics that are not presentation-specific;
- universal Body/block/reference model and document-edit contracts;
- aliases/shared Object identity metadata;
- Daily Note identity/navigation/time-based Object patterns;
- generic Object opening/detail contracts;
- user-defined ObjectType core behavior;
- migration/reconciliation contracts when generic Object identity is authoritative;
- Object duplicate/merge/redirect and durable history core contracts when focused Issues activate them.

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
- Relation-producing workflow atomicity;
- Relation rewiring/integrity slices required by future Object merge/history contracts.

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
- generic Person/Weblink/Object collection/navigation surfaces and legacy dedicated-page replacement after parity;
- Home/Inbox/Recent/Favorites/Pinned Database work-start UX through canonical contracts.

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
- preservation validation before destructive legacy schema retirement;
- portable export packaging/filesystem semantics and managed/external byte handling when the export roadmap activates;
- managed-byte retention/GC boundaries required by durable history when explicitly split to F.

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
- repository-wide architecture/handoff synchronization such as #1048/#1060.

G must not redesign working product semantics under a refactor label.

### Lane H — Architecture & Integration Oversight

H is the control tower for the whole repository. Its durable handoff is `docs/AI_PROGRESS_OVERSIGHT.md`.

Owns observation/routing work such as:
- architecture drift audits against `docs/product_architecture.md`;
- cross-lane dependency/integration review;
- duplicate Issue/implementation ownership detection;
- shared-hotspot and migration-writer conflict review;
- product-wide UX consistency audits;
- discovery of emerging technical debt or new legacy dependencies;
- combined-state/test/preservation gap discovery;
- roadmap/umbrella-completion review;
- creating/refining focused Issues and routing them to exactly one A–G implementation lane;
- repository-wide oversight/routing documentation and focused coordination guardrails when a coordination Issue owns the change.

H does not normally:
- implement runtime product features;
- take broad shared-hotspot ownership from A–G;
- perform schema/data migrations;
- redesign canonical Object/Relation semantics under an audit label;
- create duplicate persistence/query/search/index systems;
- merge another lane's PR merely to keep work moving.

A fresh H chat should be able to resume with only `Hレーンとして作業を続けて`, re-read GitHub live state, perform a broad audit and route concrete findings without chat history.

## Ownership and concurrency rules

- Identify exactly one primary A–G implementation lane before product/runtime editing. H is valid only for oversight/coordination work within its contract.
- One focused Issue has one active implementation owner/branch/PR. Umbrellas may have many focused child Issues.
- Do not modify another lane's progress file except for a repository-wide coordination/architecture change or an explicit cross-lane dependency.
- Split cross-lane work by coherent acceptance slices and sequence dependencies.
- Before non-trivial edits to shared hotspots such as `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `bookmark_reorderable_properties.dart`, `people_management_page.dart`, `settings_page.dart`, `profile_manager.dart`, or `app_database.dart`, inspect current open PR ownership.
- Shared hotspots use temporary ownership leases. Patch-sized non-overlapping work may proceed only after confirming behavior/region non-overlap.
- Schema/migration writer work is single-writer.
- Relation subsystem redesign is not a Refactor- or Oversight-lane goal.
- Idle is acceptable when no independent safe work exists; never invent speculative abstractions to keep a lane busy.
- H findings that require product/runtime code must be routed to an A–G focused Issue rather than implemented directly by H.

## Current issue routing

Always verify live Issues because this list is a routing aid, not transient ownership state.

- **A:** #1062 Object merge/redirect; #1064 durable history contract; #1177 legacy-only Bookmark preservation where its acceptance remains open; #56 core follow-ups through focused Issues. #1044/#1058/#1121 are completed checkpoints, not active work sources.
- **B:** future #1062/#1064 Relation-integrity slices when explicitly split, plus newly demonstrated Relation/integrity gaps through focused B Issues. #1042/#1045 are completed migration/integrity checkpoints, not active work sources.
- **C:** #1043 Stage1→generic Weblink/Object Database/View + Inbox; #1046 People→generic Person Database/View; #1061 Home/start UX; broader #1050 Tag picker/tree/management UX only where live acceptance remains. #1053 hierarchy-aware Tag filtering/query UX is a completed checkpoint, not an active work source.
- **D:** #155 is the durable Weblink/Image/File native-capability umbrella; resume D only for concrete native Weblink/Image/File obligations proven by live focused Issues.
- **E:** focused Search issues when canonical FTS correctness/freshness obligations are demonstrated.
- **F:** #1063 export/portability is the current durable roadmap anchor; #242/#951 are completed preservation checkpoints, not active stop gates; future destructive retirement still requires migration-specific preservation evidence and explicit single-writer/destructive-approval handling.
- **G:** #225 maintainability and live focused G Issues; #1047/#950 are completed checkpoints, and future caller-zero Bookmark/People retirement begins only after owning-lane parity; surviving Photo-era paths remain compatibility/preservation infrastructure unless a new focused caller audit proves otherwise; repository-wide architecture/guardrail sync such as #1060.
- **H:** continuous architecture/integration oversight via `docs/AI_PROGRESS_OVERSIGHT.md`; #1060 establishes the lane. H routes implementation findings to A–G.

Umbrellas #56, #1039, #1040, #1050, #155, #225, #245 organize broader direction; implement through focused child Issues when possible.

## Autonomous implementation loop

When an A–G focused task is active, continue without asking for confirmation for routine reversible engineering decisions inside its contract.

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

### H autonomous oversight loop

H follows `docs/AI_PROGRESS_OVERSIGHT.md` rather than the product implementation loop:

1. Re-read architecture, repository routing, all relevant A–G handoffs and live GitHub state.
2. Build the current dependency/hotspot/migration ownership map.
3. Inspect recent `main` changes and active PRs for cross-lane composition risks.
4. Audit architecture, UX, technical debt, correctness/preservation and roadmap coherence.
5. Link findings to existing Issues or create one focused Issue with exactly one owning A–G implementation lane.
6. Update oversight/repository routing only when durable facts changed.
7. Continue to another independent audit area instead of stopping after the first finding.
8. Keep `docs/AI_PROGRESS_OVERSIGHT.md` resumable without chat history.

Any H PR that changes repository files still needs a focused coordination Issue and normal PR/CI discipline.

## Lane continuation and resume/stop contract

All A–H runs inherit this contract, including a fresh chat started with only `<lane>レーンとして作業を続けて`. The goal is continuous useful work, not continuous activity: keep going while concrete safe work exists, and stop cleanly when it does not.

### After every coherent slice, PR, or merge

Do not treat completion of the current item as the end of the lane. Before stopping or declaring the lane idle:

1. Refresh latest `main` after the most recent integration that could affect the lane.
2. Re-read live open PRs, focused Issues, relevant CI, shared-hotspot ownership and migration-writer ownership.
3. If the current focused Issue still has unfinished acceptance criteria, continue it.
4. If the current focused Issue is complete, search for the next safe lane-local task using the discovery order below.
5. If CI is pending for one PR, continue only work that is independent of that pending result; pending CI by itself is not a stop reason.

### Next-work discovery order

Use this order so a lane does not stop merely because its first Issue finished:

1. unfinished acceptance criteria in the current focused Issue;
2. an explicit next slice or unmet acceptance dimension in the same umbrella Issue;
3. another live open focused Issue routed to the lane and not already owned by another active branch/PR;
4. a lane-local dependency that became actionable because another PR merged or current `main` changed;
5. a concrete, evidence-backed acceptance/correctness/parity gap discovered from current `main`, tests or the active umbrella; create/refine one focused Issue before implementing a new gap rather than silently broadening scope;
6. for H, a newly actionable previously-idle lane, cross-lane integration gap, or architecture/roadmap inconsistency that should be routed to exactly one A–G lane.

At every step, preserve existing ownership, hotspot leases, schema/migration single-writer rules and product boundaries. Do not invent speculative features, abstractions, refactors or documentation churn merely to avoid an idle lane. There is no minimum PR count, minimum runtime, or activity quota.

### Final resume audit before stopping

A lane may report `idle` or another stop only after all of these have been checked against live state at the end of the run:

- latest `main` was refreshed after the last relevant merge;
- open PR ownership and focused Issues were re-read;
- the lane handoff and relevant umbrella acceptance were re-read;
- newly-unblocked dependencies were checked;
- shared-hotspot and migration-writer conflicts were checked;
- independent work that could proceed while CI is pending was considered;
- the next-work discovery order above found no further safe task, or found a specific blocker that matches a stop category below.

If this audit has not happened, “current PR merged”, “tests are green”, “CI is running”, or “the listed Issue is done” is not valid stop evidence.

### Stop reason categories

Record one of these exact categories in the durable handoff when a run stops:

- `idle-no-work` — final resume audit found no concrete safe lane-local work; include the live evidence searched.
- `dependency` — all meaningful next work is blocked by an explicit Issue/PR/contract dependency; name it.
- `decision` — a genuine product/architecture choice requires user input; summarize the alternatives without choosing silently.
- `destructive-approval` — the next step is destructive/irreversible or deletes user data and lacks required explicit approval/preservation evidence.
- `conflict` — active hotspot ownership, duplicate focused-Issue ownership or migration-writer ownership blocks all independent safe work; identify the owner.
- `external-infra` — required external/real-machine infrastructure is unavailable and no independent safe work remains.
- `tool-session-limit` — runtime/tool/session limits stopped the run despite remaining safe work; record the exact next action so a fresh chat can resume immediately.

Use the form `Stop reason: <category> — <evidence/next action>`. Do not use a vague “done”, “finished”, or “waiting” as the durable stop reason.

### Lane activity intent

- **A/B/C/D/G:** normally continue across multiple focused slices while concrete safe lane-local work exists.
- **E:** may legitimately use `idle-no-work` when no demonstrated Search/Indexing correctness obligation exists after the final resume audit; do not manufacture Search work.
- **F:** may legitimately stop on `external-infra`/`dependency` for real-machine preservation gates, but only after checking for other independent Vault/storage/export/delivery work.
- **H:** remains a broad oversight/reactivation lane. On every resume, explicitly check whether a previously idle A–G lane became actionable because dependencies merged, ownership cleared, or new evidence appeared; route implementation back to exactly one owning A–G lane rather than taking it over.

Hourly/background automatic restarts are outside this contract and must not be introduced implicitly.

### Stop only when

For A–G implementation runs, after the final resume audit:
- `idle-no-work` applies because the lane has no actionable concrete work;
- a genuine product decision requires user input;
- the next step is destructive/irreversible or deletes user data and lacks explicit approval;
- an unavoidable cross-lane conflict/dependency blocks all independent safe work;
- external infrastructure failure blocks all independent safe work;
- runtime/tool/session limits are reached.

For H audits, after the final resume audit:
- the major oversight areas have been checked and no further actionable evidence exists;
- the next conclusion needs a genuine product decision;
- all meaningful next findings depend on active work that cannot yet be evaluated;
- tool/session limits prevent further useful inspection.

One PR, one commit, one passing test suite, one newly created Issue or pending CI is not by itself a stop reason.

## Handoff requirement

Before a run ends, keep the active lane progress file usable without chat history. Record:
- current goal/focused Issue or H audit scope;
- durable branch/commit/PR checkpoint when one exists;
- completed checkpoints/findings;
- work in progress and exact next actions/audit targets;
- validation/results;
- cross-lane dependencies and hotspot/migration ownership;
- blockers/risks;
- `Stop reason: <category> — <evidence/next action>` using the shared resume/stop categories above.

Avoid durable claims such as “no PR currently exists” or “lane X is running now” unless they are explicitly labeled as time-sensitive and necessary. Live GitHub state must be rechecked on resume.

## Product / umbrella completion

A green focused PR does not automatically make its umbrella Done. For important product capabilities, use the completion dimensions in `docs/product_architecture.md`: architecture, behavior, tests, UX, keyboard/accessibility/device interaction, empty/loading/error/recovery states, migration/reconciliation, replacement parity, legacy caller-zero retirement, preservation before destructive migration, and durable handoff/routing.

Small focused Issues may mark dimensions non-applicable. Umbrellas should not silently omit them.

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

- Use dedicated branches for non-trivial work; prefer lane-identifiable names (`feature/object-*`, `feature/relation-*`, `feature/database-view-*`, `feature/primitives-*`, `feature/search-*`, `feature/storage-*`, `refactor/issue-*`, `oversight/issue-*`, `docs/*`).
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

## Planning, implementation and oversight chats

Planning/design work should refine durable Issues and `docs/product_architecture.md` when architecture changes. A–G implementation chats adopt one lane and one focused Issue, execute it through multiple safe checkpoints, and keep the matching lane handoff current. H oversight chats inspect the whole system, route concrete work to A–G, and keep the oversight handoff current. Separate chats are useful for parallelism but are not required.