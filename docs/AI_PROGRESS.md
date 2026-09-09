# AI Progress Handoff

> Repository-wide durable integration/routing checkpoint. Before implementation always re-read the focused Issue, `docs/product_architecture.md`, latest `main`, open PR ownership and current CI. Lane handoffs contain implementation details; transient ownership belongs to live GitHub state.

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
- Weblink/Image/File remain Objects with native capabilities.
- Person/Book/Paper/Project/Recipe/Tag/TagGroup/etc. use generic ObjectType persistence.
- `Bookmark` is legacy compatibility/migration input, **not a final ObjectType**. Saving a URL creates/reuses a canonical Weblink Object.

The complete durable contract is `docs/product_architecture.md` (#1048/#1051, reinforced by #1060).

## Current repository position — 2026-09-09

The Object-first Product Architecture Constitution is on `main`, and #1055 synchronized the existing A–G AI handoffs/instructions with it. Body document-like phase 1 is also on `main` via #1056; follow-up interaction work is split into #1057/#1058.

Established foundations:
- Object/ObjectType/Property/Body foundations and shared Object opening/Inspector surfaces;
- generic Database/View Table/List/Gallery/Board, multiple Views and schema editing;
- mature canonical Relation mutation/read/index/backlink/audit/reconcile lifecycle;
- reusable canonical Weblink identity, metadata/enrichment and Representative Image pipeline;
- canonical Image/File native capability and managed-file infrastructure;
- canonical Object Search with focused freshness;
- Vault lifecycle/portable managed storage and release delivery;
- Photo→Image product-facing convergence with legacy preservation still intentionally retained;
- CI/parallel-development guardrails: full-test sharding/cache, stable `merge-gate`, docs-only fast path, merge-group support, hotspot/Issue/dependency/migration-lease/handoff audits.

Historical implementations that modeled `Bookmark` as a canonical mirrored Object remain transition compatibility only and must not be extended into the final architecture.

## Active architecture/migration umbrellas

- **#56** — generic Object/Database/View daily-use integration umbrella.
- **#1039** — retire legacy Bookmark domain toward Weblink + generic Object/Database/Inbox UX.
- **#1040** — retire dedicated People subsystem toward generic Person ObjectType + generic Database/View/Relation UX.
- **#1050** — generic Tag/TagGroup hierarchy and hierarchy-aware query/UX.
- **#155** — Weblink native capability umbrella.
- **#225** — maintainability, hotspot reduction, caller-zero legacy retirement.
- **#245** — Photo→Image convergence umbrella; destructive historical schema retirement remains separate.
- **#242/#951** — final real-macOS Vault/data-preservation validation.
- **#1060** — introduce H oversight/control-tower and reinforce completion/product roadmap contracts.

## Focused implementation routing

### A — Object Core & Body

Active/future focused work:
- **#1057** — Body contextual block handles and drag reorder.
- **#1058** — safe local Undo for reversible Body structural edits.
- **#1041** — collision-safe legacy Bookmark → canonical Weblink/generic Object migration authority.
- **#1044** — generic Person ObjectType normal write authority.
- **#1062** — explicit duplicate detection / Object merge / redirect semantics.
- **#1064** — durable Object/Property/Body/Relation history contract; split Relation/storage implementation slices when needed.

Body phase 1 #1049 is complete; do not re-open its already-landed scope instead of taking #1057/#1058.

### B — Relations & Data Integrity

Active focused work:
- **#1052** — canonical Tag Parent/TagGroup integrity, one-parent cardinality, cycle prevention and fail-closed hierarchy state.
- **#1042** — map retained Bookmark-era relationships to canonical Weblink/generic Object targets without silent collision merging.
- **#1045** — converge Person groups/roles onto generic Relation/Database/Tag contracts.

Future #1062/#1064 work that rewires/restores Relations must be split into focused B-owned integrity slices rather than implemented inside A.

### C — Database, View & Schema UX

Active/future focused work:
- **#1053** — hierarchy-aware Tag predicates (`exact`, `is-or-below`, etc.) and reusable filter UX.
- **#1043** — replace Stage1 normal ownership with generic Weblink/Object Database/View + Inbox/capture-first UX after migration parity.
- **#1046** — replace dedicated People management with generic Person Database/View/Inspector UX after authority/integrity parity.
- **#1061** — make Home a work-start surface centered on Inbox / Recent / Favorites / Pinned Databases.

### D — Primitive Objects & Media

Active focused work:
- **#1054** — direct canonical URL capture: normalize and create/reuse Weblink Object without creating a permanent Bookmark authority.

Conditional umbrellas:
- #155 Weblink native identity/metadata/media;
- #245 Image/File/Photo primitive obligations only when concrete defects appear.

Tag/TagGroup are not D-owned native primitives.

### E — Search & Indexing

Canonical Object Search is established. Resume only for demonstrated FTS/search freshness/ranking/projection obligations; do not create domain-specific long-term search stores for Bookmark/Person/Tag.

### F — Storage, Vault & Delivery

- **#951/#242** — real-machine preservation/validation gate for current Photo→Image/Vault work.
- **#1063** — open export/portability package distinct from backup/restore, with logical serialization contracts split to owning lanes as needed.
- Future destructive Bookmark/People/Photo schema retirement requires a preservation gate before data removal.
- Future durable history may need a focused F slice for managed-byte retention/GC; do not infer it from metadata history.

### G — Refactor & Architecture Health

- **#1047/#225** — behavior-preserving Generic Database hotspot reduction and architecture health.
- **#950** — proven caller-zero Photo compatibility cleanup where live caller audits justify deletion.
- after owning-lane parity, retire caller-zero Bookmark/People repositories/pages/bridges incrementally;
- **#1060** — repository-wide H/roadmap/completion-contract integration and guard synchronization.

### H — Architecture & Integration Oversight

H is a repository-wide control tower, not another product implementation owner. Durable handoff: `docs/AI_PROGRESS_OVERSIGHT.md`.

H continuously audits:
- architecture drift from the Object-first constitution;
- duplicate ownership / cross-lane dependency and shared-hotspot conflicts;
- combined-state integration/test gaps;
- product-wide UX inconsistency;
- emerging technical debt/new legacy dependencies;
- data-preservation/migration risks;
- roadmap and umbrella-completion coherence;
- newly discovered product gaps worth a focused Issue.

H routes concrete implementation to exactly one A–G lane. H may own focused coordination/guardrail/docs work, but does not normally implement runtime product behavior or migrations.

A fresh H chat should resume with only `Hレーンとして作業を続けて` and rebuild transient state from live GitHub.

## Reinforced future product roadmap

The following are now explicit roadmap contracts rather than untracked ideas:

- **#1061 [C] Home/start UX** — Inbox / Recent / Favorites / Pinned Databases; final Home is not a legacy-domain module catalog.
- **#1062 [A→B slices] Object merge** — advisory duplicate detection, explicit merge, surviving identity, redirect/tombstone semantics, conflict-safe Relation rewiring.
- **#1063 [F + logical cross-lane contracts] Portability/export** — open inspectable lossless package plus explicitly lossy Markdown/CSV projections; distinct from backup/restore.
- **#1064 [A→B/F slices] Durable history** — persisted Object/Property/Body/Relation history and conflict-safe restore, explicitly separate from local Undo.

## Near-term dependency shape

```text
Object-first constitution
        |
        +--> Body follow-ups #1057/#1058 [A]
        |
        +--> Tag #1050
        |      +--> #1052 [B] integrity
        |      +--> #1053 [C] query/UX
        |
        +--> Bookmark retirement #1039
        |      +--> #1041 [A] identity/migration
        |      +--> #1042 [B] relations
        |      +--> #1054 [D] direct Weblink capture
        |      +--> #1043 [C] generic daily-use UX
        |      +--> G caller-zero retirement after parity
        |
        +--> People retirement #1040
        |      +--> #1044 [A] Person authority
        |      +--> #1045 [B] groups/roles
        |      +--> #1046 [C] generic UX
        |      +--> G caller-zero retirement after parity
        |
        +--> Future platform contracts
               +--> #1061 [C] Home
               +--> #1062 [A/B] Object merge
               +--> #1063 [F + owning serializers] export
               +--> #1064 [A/B/F] durable history

H oversight continuously audits the whole graph and routes new findings.
```

Each focused Issue still has one active implementation owner/branch/PR. Shared hotspots and migrations remain single-owner.

## Core design contracts

### Object / ObjectType
- One Object = one primary ObjectType.
- Roles such as Author/Member are Relation semantics, not extra ObjectTypes.
- Classifications such as Favorite or “math material” are Properties/Tags/query context.
- Type conversion must preserve unknown/unmapped data; never silently discard values.
- Duplicate suggestion must not silently merge Objects; explicit merge/redirect semantics are #1062.

### Bookmark retirement

```text
URL → normalize → create/reuse Weblink Object → optional Inbox/Database/Tag/Relation organization
```

Richer semantic Objects may reference the Weblink (`Paper --Source--> Weblink`, etc.). Do not automatically guess semantic type during migration. Conflicting legacy collisions fail closed/preserve compatibility until a lossless merge policy exists.

### Person retirement
Person is a generic ObjectType, not a permanent People subsystem. Profile Image remains a Relation to Image. Generic Inspector/Database/View replaces dedicated management only after authority/integrity/daily-use parity.

### Tag hierarchy
- Tag and TagGroup are generic Objects.
- Canonical hierarchy: `Tag --Parent--> Tag` through canonical Relation APIs.
- Store only directly assigned Tags; derive ancestors.
- Query distinguishes exact from hierarchy-aware predicates.
- Specialized tree/picker/filter UX may sit over generic persistence.

### Database/View and Home
- Object identity is global; Database membership/query does not clone Object identity.
- Removing from Database ≠ deleting Object.
- Database may use manual membership, query-derived membership, or manual membership with View filters.
- View owns layout/filter/sort/group/visible Properties/opening configuration.
- Home converges on Inbox / Recent / Favorites / Pinned Databases after legacy-domain replacement parity.

### Lifecycle/deletion
Active → Archived → Trashed → explicit permanent deletion. Managed bytes are physically removed only with proven active-Vault ownership/shared-reference safety.

### Undo/history
Local Undo is short-lived interaction recovery; durable history is restart-safe persisted history/restore. Do not conflate the two into a speculative global command stack.

### Portability
Vault backup/restore is not the same as open export. Portable export must preserve stable identity/graph/schema in a lossless structured layer where possible; Markdown/CSV are projections when they cannot encode the full model.

### Legacy retirement

```text
replacement contract
→ parity
→ caller-zero proof
→ legacy UI/API/code deletion
→ preservation validation
→ explicit destructive schema migration
```

Do not remove user data merely because a replacement UI exists.

## Umbrella `Done` contract

A focused PR can be complete while its umbrella is not. Important umbrellas must review every applicable dimension in `docs/product_architecture.md`:
- architecture;
- behavior;
- contract/integration/real-host tests;
- UX efficiency/coherence;
- keyboard/focus/accessibility and desktop/mobile interaction;
- empty/loading/error/recovery states;
- migration/reconciliation;
- replacement parity;
- legacy caller-zero retirement;
- preservation before destructive migration;
- durable docs/handoff/routing.

Mark dimensions explicitly non-applicable/deferred rather than silently treating them as complete.

## Shared-hotspot / migration rules

Shared hotspots include `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `bookmark_reorderable_properties.dart`, `people_management_page.dart`, `settings_page.dart`, `profile_manager.dart`, and `app_database.dart`.

Re-audit live open PRs before broad edits. One lane at a time owns a broad hotspot. Schema/migration writer is single-writer. Patch-sized non-overlapping edits still require behavior/region verification. H audits ownership but does not seize product hotspot leases merely to fix a finding.

## Validation / repository settings

- GitHub CI is authoritative when local Flutter execution is unavailable.
- Keep full-test `merge-gate`, Drift generation/Analyze safeguards and architecture/AI audits intact.
- `main` remains unprotected in repository settings at this checkpoint; #980 tracks required branch protection/merge-gate settings. Repository code already supports merge-group execution.

## Handoff rule

Lane progress files should record durable contracts and exact resume actions, not long-lived claims that a lane is “idle” when new focused Issues have since opened. Historical detail belongs in git/Issue/PR history. Live GitHub state always overrides stale snapshots.

H keeps `docs/AI_PROGRESS_OVERSIGHT.md` current with durable findings, routing rules and exact next audit targets so a new chat does not need prior conversation history.
