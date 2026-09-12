# AI Progress Handoff

> Repository-wide durable integration/routing checkpoint. Before implementation always re-read the focused Issue, `docs/product_architecture.md`, latest `main`, open PR ownership and current CI. Lane handoffs contain implementation details; transient ownership belongs to live GitHub state.

## Source-of-truth split

Use each source for the kind of fact it can keep accurate:

- `docs/product_architecture.md` — durable product semantics and long-term direction.
- `docs/architecture.md` — durable technical architecture.
- `AGENTS.md` — AI ownership, concurrency, migration, stop, and handoff rules.
- `docs/AI_PROGRESS*.md` — durable completed contracts, routing, dependencies, blockers that remain meaningful across runs, and exact resume guidance.
- GitHub Issues — focused implementation contracts and acceptance criteria.
- GitHub PRs, CI, branches, rulesets/settings, and current `main` — transient ownership and current repository state.

Do **not** treat a handoff sentence such as “no open PRs”, a CI run number, or an old main SHA as authoritative later. Fresh runs must query live GitHub. Avoid adding volatile snapshots to durable handoffs unless preserving a historical checkpoint is the explicit purpose.

## Product direction

The product is a **local-first, Object-first personal knowledge/database application**, not a Bookmark-centric app.

Durable model:
- Object = global reusable entity inside a Vault.
- One Object has one primary ObjectType.
- ObjectType = schema/capabilities/default behavior.
- Property = structured characteristic/value.
- Relation = typed relationship/role between Objects.
- Tag/TagGroup = generic reusable ObjectTypes with hierarchy-aware semantics.
- Database = Object set/query context, not an owning folder.
- View = presentation/query configuration over a Database.
- Body = free-form versioned block document attached to every Object.
- Weblink/Image/File are Objects with native capabilities.
- Person/Book/Paper/Project/Recipe/Tag/TagGroup/etc. use generic ObjectType persistence.
- `Bookmark` is legacy compatibility/migration input, **not a final ObjectType**. Saving a URL creates/reuses a canonical Weblink Object.

The complete durable contract is `docs/product_architecture.md`.

## Established foundations

The repository has durable foundations for:
- Object/ObjectType/Property/Body and shared Object opening/Inspector surfaces;
- generic Database/View Table/List/Gallery/Board, multiple Views, and schema editing;
- canonical Relation mutation/read/index/backlink/audit/reconcile lifecycle;
- canonical Weblink identity, metadata/enrichment, and representative media;
- Image/File native capability and managed-file infrastructure;
- canonical Object Search and focused freshness;
- Vault lifecycle/portable managed storage and release delivery;
- Photo→Image product-facing convergence while historical preservation remains intentional;
- parallel-development CI with a stable aggregate `merge-gate`, full-test sharding, docs-only fast path, immutable GitHub Action pinning, repository-pinned Flutter + tracked dependency lockfile reproducibility guards, deterministic AI PR-contract enforcement, a blocking deterministic migration single-writer gate, hotspot/Issue/dependency/handoff audits, and protected `main` integration;
- a read-only repository-settings audit that checks the observable effective default-branch integration contract on PR/scheduled/manual runs without adding privileged administration credentials or guessing omitted administration-only fields;
- a focused implementation Issue Form that captures lane ownership, dependencies, hotspots, migration/data impact, acceptance and non-goals before implementation.

Historical implementations that modeled `Bookmark` as a canonical mirrored Object remain transition compatibility only and must not be extended into the final architecture.

## Main architecture/migration umbrellas

Always re-check each Issue live before assuming state or ownership.

- **#56** — generic Object/Database/View daily-use integration umbrella.
- **#1039** — retire legacy Bookmark domain toward Weblink + generic Object/Database/Inbox UX.
- **#1040** — retire dedicated People subsystem toward generic Person ObjectType + generic Database/View/Relation UX.
- **#1050** — generic Tag/TagGroup hierarchy and hierarchy-aware query/UX.
- **#155** — Weblink native capability umbrella.
- **#225** — maintainability, hotspot reduction, caller-zero legacy retirement, and developer-workflow health.
- **#245** — completed Photo→Image product-facing convergence checkpoint; destructive historical schema retirement remains separate.
- **#242/#951** — completed real-macOS Vault/data-preservation checkpoints. They are evidence for the validated transitions, not blanket authorization for future destructive legacy retirement.

## Focused implementation routing

The Issue numbers below are durable roadmap/routing anchors, not claims that a PR is currently active. Verify live state before taking ownership. Completed focused Issues are checkpoints, not active work sources.

### A — Object Core & Body
- #1062 duplicate detection / Object merge / redirect semantics.
- #1064 durable Object/Property/Body/Relation history contract; split B/F slices when required.
- #1177 legacy-only Bookmark engagement/lifecycle preservation boundary where its acceptance remains open.
- Completed checkpoints: #1041 legacy Bookmark → canonical Weblink/generic Object migration authority; #1044 generic-first Person create/update/delete/reconciliation authority; #1057 Body contextual block handles/drag reorder; #1058/#1121 local structural Undo plus compatibility-safe persisted Body concurrency.

### B — Relations & Data Integrity
- Future #1062/#1064 Relation rewiring/restore slices belong in focused B Issues when explicitly split.
- Otherwise resume B only for a newly demonstrated Relation/integrity obligation from a live focused Issue rather than reopening completed migration queues.
- Completed checkpoints: #1042 retained Bookmark-era Relation convergence; #1045 generic Person roles/groups convergence; #1052 canonical Tag Parent/TagGroup integrity and cycle prevention; #1105 strict canonical Tag descendant reader.

### C — Database, View & Schema UX
- #1043 generic Weblink/Object Database/View + Inbox replacement for Stage1 normal ownership.
- #1046 generic Person Database/View/Inspector replacement after parity.
- #1061 Home/start UX centered on Inbox / Recent / Favorites / Pinned Databases.
- Broader #1050 Tag picker/tree/management UX remains an umbrella concern only where live acceptance is unfinished.
- Completed checkpoint: #1053 hierarchy-aware Tag predicates/filter UX, integrated through canonical B hierarchy semantics.

### D — Primitive Objects & Media
- #155 is the durable Weblink/Image/File native-capability umbrella; resume D only for a concrete native-capability obligation proven by a live focused Issue.
- Completed checkpoints: #1054 direct canonical URL capture to Weblink Object; #245 Photo→Image product-facing convergence.

Tag/TagGroup are not D-owned native primitives.

### E — Search & Indexing
Canonical Object Search is established. #1178 is a completed checkpoint for canonical Person mutation Search freshness. Resume E only for a newly demonstrated FTS/search correctness, freshness, ranking, projection, or opening obligation; do not create domain-specific long-term search stores for Bookmark/Person/Tag.

### F — Storage, Vault & Delivery
- #1063 open export/portability distinct from backup/restore is the current durable roadmap anchor; verify live ownership before taking it.
- #242/#951 are completed preservation checkpoints, not active Lane F stop gates.
- Destructive Bookmark/People/Photo schema retirement still requires preservation evidence appropriate to that future migration before data removal; completion of #242/#951 does not waive this.
- Durable history may later require a focused F managed-byte retention/GC slice.

### G — Refactor & Architecture Health
- #225 maintainability, hotspot reduction, developer workflow, architecture health.
- #950 is a completed caller-zero Photo compatibility checkpoint. Surviving Photo-era paths remain intentional compatibility/preservation infrastructure unless a new focused current-main caller audit proves otherwise; destructive persisted-schema retirement is separate preservation/migration/approval-gated work.
- #1107 Phase A non-self destructive approval is established: current-head approval must come from a distinct non-author GitHub User, complete paginated latest-review state is evaluated, and the reviewer must have write/admin permission. #1107 remains open for Phase B only: a trusted enforcement root/check or equivalent authorization boundary the implementation identity cannot modify or spoof.
- retire caller-zero Bookmark/People repositories/pages/bridges after owning-lane parity, and revisit Photo compatibility only through a new evidence-backed focused Issue rather than reopening #950.
- repository-wide handoff/guard synchronization belongs here when a focused Issue owns it.

### H — Architecture & Integration Oversight
H is the repository-wide control tower, not another runtime implementation owner. Durable handoff: `docs/AI_PROGRESS_OVERSIGHT.md`.

H audits architecture drift, duplicate ownership, cross-lane dependencies, shared-hotspot/migration-writer conflicts, combined-state test gaps, UX coherence, emerging technical debt, preservation risk, and roadmap/umbrella completeness. Product/runtime fixes are routed to exactly one A–G focused Issue.

## Near-term dependency shape

```text
Object-first constitution
        |
        +--> completed Body local Undo/concurrency #1058/#1121 [A]
        |      +--> #1064 [A/B/F] durable history remains distinct and open
        |
        +--> Tag #1050
        |      +--> completed #1052/#1105 [B] integrity/read
        |      +--> completed #1053 [C] query/filter UX
        |      +--> broader picker/tree/management UX only where live acceptance remains
        |
        +--> Bookmark retirement #1039
        |      +--> completed #1041 [A] identity/scalar migration authority
        |      +--> completed #1042 [B] retained Relation convergence
        |      +--> #1043 [C] generic daily-use UX
        |      +--> #1177 [A] retained legacy-only preservation boundary where applicable
        |      +--> G caller-zero retirement after parity
        |
        +--> People retirement #1040
        |      +--> completed #1044 [A] Person authority
        |      +--> completed #1045 [B] groups/roles integrity
        |      +--> #1046 [C] generic UX
        |      +--> completed #1178 [E] canonical Person mutation Search freshness
        |      +--> G caller-zero retirement after parity
        |
        +--> Platform contracts
               +--> #1061 [C] Home
               +--> #1062 [A/B] Object merge
               +--> #1063 [F + owning serializers] export
               +--> #1064 [A/B/F] durable history
               +--> #1107 [G] approval enforcement trust root
```

Each focused Issue has one active implementation owner/branch/PR. Shared hotspots use temporary ownership leases. Schema/migration writing is single-writer: non-migration PRs do not contend, the oldest open migration-sensitive PR is the unique active owner, and later migration PRs are blocked by the required gate until ownership advances.

## Core durable design contracts

### Object / ObjectType
- One Object = one primary ObjectType.
- Roles such as Author/Member are Relation semantics, not extra ObjectTypes.
- Classifications such as Favorite are Properties/Tags/query context.
- Type conversion preserves unknown/unmapped data.
- Duplicate suggestions never silently merge Objects; explicit merge/redirect semantics belong to #1062.

### Bookmark retirement

```text
URL → normalize → create/reuse Weblink Object → optional Inbox/Database/Tag/Relation organization
```

Richer semantic Objects may reference the Weblink. Do not guess semantic type during migration. Conflicting legacy collisions fail closed/preserve compatibility until a lossless merge policy exists.

### Person retirement
Person is a generic ObjectType, not a permanent People subsystem. Generic-first Person identity/write authority (#1044), roles/groups integrity (#1045), and canonical Person mutation Search freshness (#1178) are completed prerequisites, not active migration queues. Profile Image remains a Relation to Image. Generic Inspector/Database/View replace dedicated management only after remaining daily-use parity; future E work requires a newly demonstrated canonical Search defect rather than reopening #1178.

### Tag hierarchy
- Tag and TagGroup are generic Objects.
- Canonical hierarchy is `Tag --Parent--> Tag` through canonical Relation APIs.
- Store only directly assigned Tags; derive ancestors.
- Query distinguishes exact from hierarchy-aware predicates.
- #1052/#1105/#1053 are completed canonical integrity/read/query checkpoints; broader #1050 UX must reuse them rather than reopen parallel hierarchy authority.

### Database/View and Home
- Object identity is global; Database membership/query does not clone Object identity.
- Removing from Database ≠ deleting Object.
- View owns layout/filter/sort/group/visible Properties/opening configuration.
- Home converges on Inbox / Recent / Favorites / Pinned Databases after legacy-domain replacement parity.

### Lifecycle/deletion
Active → Archived → Trashed → explicit permanent deletion. Managed bytes are physically removed only with proven active-Vault ownership/shared-reference safety.

### Undo/history
Local Undo/concurrency correctness is established by #1058/#1121 and remains distinct from #1064 durable, restart-safe history/restore.

### Portability
Vault backup/restore is not open export. Portable export must preserve stable identity/graph/schema in a lossless structured layer where possible; Markdown/CSV are projections when they cannot encode the full model.

### Legacy retirement

```text
replacement contract
→ parity
→ caller-zero proof
→ legacy UI/API/code deletion
→ preservation validation
→ explicit destructive schema migration
```

Do not remove user data merely because replacement UI exists.

## Umbrella `Done` contract

A focused PR can be complete while its umbrella is not. Important umbrellas review every applicable dimension in `docs/product_architecture.md`: architecture, behavior, tests, UX, keyboard/accessibility/device interaction, error/recovery states, migration/reconciliation, parity, caller-zero, preservation before destruction, and durable docs/routing.

## Strict-main integration window

Protected `main` intentionally keeps strict/up-to-date `merge-gate`; do not weaken latest-main validation to reduce CI churn. Under parallel autonomous development, use this advisory merge-order convention instead:

- A **product/code PR** is in its final integration window when it has been synchronized to current `main` and its authoritative final `merge-gate` is running, or is green and awaiting immediate integration.
- An unrelated **non-urgent docs-only PR** is documentation/handoff/routing work that is file-disjoint from that product PR and does not correct an active safety, architecture, preservation, migration, ownership, or CI blocker.
- While such a product PR is in its final integration window, non-urgent file-disjoint docs-only PRs should normally wait rather than advance `main` and force another strict full-CI cycle.
- After the product PR integrates, coalesce waiting docs/handoff updates against the new `main` where practical instead of interleaving many tiny docs merges between product integrations.
- Safety-critical coordination or architecture corrections may take priority when delaying them would permit unsafe work; record the reason in the focused Issue/PR rather than treating every handoff refresh as urgent.
- Waiting docs work must never block the product PR through a declared dependency, shared-hotspot lease, duplicate focused-Issue claim, or migration ownership. If it would, resolve that coordination conflict rather than creating a circular wait.
- This convention is advisory merge scheduling only. Multiple product PRs still obey normal ownership/hotspot/migration rules, and no stale code may merge merely because intervening changes are docs-only.

This convention exists because strict latest-main validation is the safety property; repeated CI caused solely by merge ordering is the optimization target. It does not introduce a merge queue, bypass token, reduced test coverage, or weaker required checks.

## Repository integration contract

- `main` is protected by an active repository ruleset; changes integrate through PRs and the required strict `merge-gate`.
- The repository Flutter SDK is pinned through `pubspec.yaml`; `pubspec.lock` is tracked and CI verifies dependency resolution does not drift it.
- Deterministic AI coordination contract violations and migration single-writer contention are blocking in the required CI path; heuristic hotspot/staleness signals remain advisory.
- Critical observable protected-main settings are audited read-only on PR, scheduled and manual runs. Administration-only fields are validated whenever GitHub exposes them, but omission from non-privileged API payloads is not treated as a guessed configuration failure.
- Current branch/ruleset/PR/CI details must be queried live rather than copied into this handoff.
- GitHub CI is authoritative when local Flutter execution is unavailable.
- Keep Drift generation/Analyze safeguards and architecture/AI audits intact.
- Routine reversible AI work remains approval-free. High-confidence destructive/irreversible and approval-policy-sensitive changes require a distinct non-author current-head `APPROVED` review from a GitHub User whose complete latest-review history is evaluated and whose repository permission is write/admin. #1107 Phase B remains open because the repository-local workflow/guard enforcement root is still modifiable by the implementation authorization.

## Handoff rule

Lane progress files record durable contracts, completed checkpoints, meaningful blockers/dependencies, and exact resume actions. They should not preserve volatile claims such as “no open PR”, current CI run IDs, or current main tip as if those remain true later.

Before ending a run, update the active lane handoff only when durable state changed. A fresh run must always rebuild transient ownership from live GitHub.
