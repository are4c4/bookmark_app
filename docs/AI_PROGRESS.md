# AI Progress Handoff

> Repository-wide durable integration/routing checkpoint. Before implementation always re-read the focused Issue, `docs/product_architecture.md`, latest `main`, open PR ownership and current CI. Lane handoffs contain implementation details; transient ownership belongs to live GitHub state.

## Product direction

The product is now explicitly a **local-first, Object-first personal knowledge/database application**, not a Bookmark-centric app.

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

The complete durable contract is `docs/product_architecture.md` (#1048/#1051).

## Current repository position — 2026-09-09

Main has the Product Architecture Constitution via #1051. The next phase is implementation/migration toward that constitution while preserving existing user data.

Important recent established foundations remain valid:
- Object/ObjectType/Property/Body foundations and shared Object opening/Inspector surfaces;
- generic Database/View Table/List/Gallery/Board, multiple Views and schema editing;
- mature canonical Relation mutation/read/index/backlink/audit/reconcile lifecycle;
- reusable canonical Weblink identity, metadata/enrichment and Representative Image pipeline;
- canonical Image/File native capability and managed-file infrastructure;
- canonical Object Search with focused freshness;
- Vault lifecycle/portable managed storage and release delivery;
- Photo→Image product-facing convergence with legacy preservation still intentionally retained;
- CI/parallel-development guardrails: full-test sharding/cache, stable `merge-gate`, docs-only fast path, merge-group support, hotspot/Issue/dependency/migration-lease/handoff audits.

Historical implementations that modeled `Bookmark` as a canonical mirrored Object remain **transition compatibility only** and must not be extended into the final architecture.

## Active architecture/migration umbrellas

- **#56** — generic Object/Database/View daily-use integration umbrella.
- **#1039** — retire legacy Bookmark domain toward Weblink + generic Object/Database/Inbox UX.
- **#1040** — retire dedicated People subsystem toward generic Person ObjectType + generic Database/View/Relation UX.
- **#1048** — architecture/AI handoff alignment. `docs/product_architecture.md` is integrated; remaining stale handoff/instruction synchronization is being completed here.
- **#1050** — generic Tag/TagGroup hierarchy and hierarchy-aware query/UX.
- **#155** — Weblink native capability umbrella; final architecture supersedes old “Bookmark as permanent user-context Object” wording where any historical text remains.
- **#225** — maintainability, hotspot reduction, caller-zero legacy retirement.
- **#245** — Photo→Image convergence umbrella; destructive historical schema retirement remains separate.
- **#242/#951** — final real-macOS Vault/data-preservation validation.

## Focused implementation routing

### A — Object Core & Body
Active focused work:
- **#1049** — document-like Body UX phase 1: Enter split, Shift+Enter line break, safe Backspace merge/focus, contextual block controls and interaction regressions.
- **#1041** — collision-safe legacy Bookmark → canonical Weblink/generic Object migration authority; no final Bookmark ObjectType.
- **#1044** — make generic Person ObjectType the normal Person write authority while preserving transition compatibility.

Lane A should not treat older “idle after #909” handoff language as current routing.

### B — Relations & Data Integrity
Active focused work:
- **#1052** — canonical Tag Parent/TagGroup integrity, one-parent cardinality, cycle prevention, fail-closed hierarchy state.
- **#1042** — map retained Bookmark-era relationships to canonical Weblink/generic Object targets without silent collision merging.
- **#1045** — converge Person groups/roles onto generic Relation/Database/Tag contracts.

The canonical Relation subsystem remains authoritative; no parallel tag-tree or domain edge store.

### C — Database, View & Schema UX
Active focused work:
- **#1053** — hierarchy-aware Tag predicates (`exact`, `is-or-below`, etc.) and reusable filter UX.
- **#1043** — replace Stage1 normal ownership with generic Weblink/Object Database/View + Inbox/capture-first UX after migration parity.
- **#1046** — replace dedicated People management with generic Person Database/View/Inspector UX after authority/integrity parity.

Lane C should not treat older “idle after #949” language as current routing.

### D — Primitive Objects & Media
Active focused work:
- **#1054** — direct canonical URL capture: normalize and create/reuse Weblink Object without creating a permanent Bookmark authority.

Conditional umbrellas:
- #155 Weblink native identity/metadata/media;
- #245 Image/File/Photo primitive obligations only when concrete defects appear.

**Tag/TagGroup are not D-owned native primitives.** Their generic Object core needs route to A, hierarchy integrity to B and hierarchy query/UX to C.

### E — Search & Indexing
Canonical Object Search is established. No focused new E issue is currently required by the architecture transition. Resume only for a demonstrated FTS/search freshness/ranking/projection obligation; do not create domain-specific search stores for Bookmark/Person/Tag.

### F — Storage, Vault & Delivery
- **#951/#242** remain the real-machine preservation/validation gate for current Photo→Image/Vault work.
- Future destructive Bookmark/People/Photo schema retirement must receive a preservation gate before data removal.
- No Object/Relation/native-media identity redesign from F.

### G — Refactor & Architecture Health
- **#1048** — synchronize durable instructions/handoffs with the Object-first constitution.
- **#1047/#225** — behavior-preserving Generic Database hotspot reduction and architecture health.
- **#950** — proven caller-zero Photo compatibility cleanup.
- After owning-lane parity, retire caller-zero Bookmark/People repositories/pages/bridges incrementally; destructive schema removal remains separate.

## Near-term dependency graph

```text
Product constitution #1048/#1051
        |
        +--> Body UX #1049 [A]
        |
        +--> Tag umbrella #1050
        |      +--> #1052 [B] integrity
        |      +--> #1053 [C] query/UX
        |
        +--> Bookmark retirement #1039
        |      +--> #1041 [A] identity/migration contract
        |      +--> #1042 [B] relations/integrity
        |      +--> #1054 [D] direct Weblink capture
        |      +--> #1043 [C] generic daily-use UX
        |      +--> G caller-zero retirement after parity
        |
        +--> People retirement #1040
               +--> #1044 [A] Person authority
               +--> #1045 [B] groups/roles
               +--> #1046 [C] generic UX
               +--> G caller-zero retirement after parity
```

Parallel implementation may be enabled later, but each focused Issue still has one active owner/branch/PR and shared hotspots/migrations remain single-owner.

## Core design contracts

### Object / ObjectType
- One Object = one primary ObjectType.
- Roles such as Author/Member are Relation semantics, not extra ObjectTypes.
- Classifications such as Favorite or “math material” are Properties/Tags/query context.
- Type conversion must preserve unknown/unmapped data; never silently discard values.

### Bookmark retirement
Normal path:

```text
URL → normalize → create/reuse Weblink Object → optional Inbox/Database/Tag/Relation organization
```

Richer semantic Objects may reference the Weblink:

```text
Paper --Source--> Weblink
Recipe --Source--> Weblink
```

Do not automatically guess semantic type during migration. If multiple legacy Bookmark rows collide on one normalized Weblink and contain conflicting user-authored state, fail closed/preserve compatibility until an explicit merge policy exists.

### Person retirement
Person is a generic ObjectType, not a permanent People subsystem. Profile Image remains a Relation to Image. Generic Inspector/Database/View should replace dedicated management UI only after write/integrity/daily-use parity.

### Tag hierarchy
- Tag and TagGroup are generic Objects.
- Canonical hierarchy: `Tag --Parent--> Tag` through canonical Relation APIs.
- Store only directly assigned Tags on normal Objects; derive ancestors.
- Query distinguishes exact from hierarchy-aware predicates.
- Specialized tree/picker/filter UX may sit over generic persistence.

### Database/View
- Object identity is global; Database membership/query does not clone Object identity.
- Removing from Database ≠ deleting Object.
- Database may use manual membership, query-derived membership, or manual membership with View filters.
- View owns layout/filter/sort/group/visible Properties/opening configuration.

### Lifecycle/deletion
Direction is Active → Archived → Trashed → explicit permanent deletion. Managed bytes are physically removed only with proven active-Vault ownership/shared-reference safety.

### Legacy retirement
Required sequence:

```text
replacement contract
→ parity
→ caller-zero proof
→ legacy UI/API/code deletion
→ preservation validation
→ explicit destructive schema migration
```

Do not remove user data merely because a replacement UI exists.

## Shared-hotspot / migration rules

Shared hotspots include `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `bookmark_reorderable_properties.dart`, `people_management_page.dart`, `settings_page.dart`, `profile_manager.dart`, and `app_database.dart`.

Re-audit live open PRs before broad edits. One lane at a time owns a broad hotspot. Schema/migration writer is single-writer. Patch-sized non-overlapping edits still require behavior/region verification.

## Validation / repository settings

- GitHub CI is authoritative when local Flutter execution is unavailable.
- Keep full-test `merge-gate`, Drift generation/Analyze safeguards and architecture/AI audits intact.
- `main` currently remains unprotected in repository settings; #980 tracks enabling required branch protection/merge-gate settings. The GitHub App connection may lack administration permission to apply that setting.

## Handoff rule

Lane progress files should record current durable contracts and exact resume actions, not long-lived claims that a lane is “idle” when new focused Issues have since opened. Historical detail belongs in git/Issue/PR history. Live GitHub state always overrides stale snapshots.