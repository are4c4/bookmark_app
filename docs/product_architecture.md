# Product Architecture Constitution

Related: #56, #1048

This document defines the default product direction for new implementation work. It is a durable product contract, not a snapshot of current PR ownership. When a focused Issue conflicts with this document, the conflict must be resolved explicitly before implementation proceeds.

## Product direction

The product is a **local-first, Object-first personal knowledge/database application**. It is no longer designed as a Bookmark-centric application.

The target combines:
- Object-first identity and backlinks;
- Notion-like Database/View flexibility;
- local Vault ownership and offline-first operation;
- native Weblink/Image/File capabilities without turning every domain into bespoke app code.

## Core model

Every durable user-facing entity is an Object.

```text
Object
├─ primary ObjectType
├─ Properties
├─ Relations
├─ Body
└─ system metadata / lifecycle
```

### One Object, one primary ObjectType

An Object has one primary ObjectType.

ObjectType answers **“what is this?”**. Roles and classifications are not extra ObjectTypes.

Examples:
- `Person` is an ObjectType.
- `Author` is normally a Relation role.
- `Mathematician` is normally a Property/Tag/Database classification.
- `Favorite` is state/query context, not an ObjectType.

Changing ObjectType must never silently discard data. Unsupported or unmapped values remain preserved until an explicit conversion/migration decision is made.

## Native-capability ObjectTypes

`Weblink`, `Image`, and `File` are still Objects, but the application understands native behavior associated with their type.

Examples:
- Weblink: URL normalization, metadata, favicon, preview, representative Image.
- Image: decode, thumbnail, crop/edit, managed-file ownership.
- File: MIME/content identity, managed/external path semantics, preview/extraction.

The persisted identity remains an Object; native behavior is capability attached to the type.

## Standard and user-defined ObjectTypes

`Person`, `Book`, `Paper`, `Project`, `Recipe`, `Tag`, `TagGroup`, and similar concepts should use the generic ObjectType system. They may ship as defaults/templates, but should not require independent persistence/presentation subsystems merely because they are common domains.

## Bookmark is not a target ObjectType

`Bookmark` is a legacy product/domain concept, not a final ObjectType.

Normal URL capture should:

```text
URL
 ↓
create/reuse Weblink Object
 ↓
optional Inbox / Database / Tag / Relation organization
```

A richer semantic Object can reference a Weblink, for example:

```text
Paper --Source--> Weblink
Recipe --Source--> Weblink
```

Migration must not guess semantic types. Existing Bookmark data is preserved until a lossless migration contract is proven. Existing mirrored `bookmark` Objects are transition compatibility, not the permanent replacement model.

## Object identity and duplicate safety

Identity must be stable and independent of display names.

Where native canonical identity exists, use it (for example normalized Weblink URL). For generic ObjectTypes, duplicate detection is advisory unless a type-specific stable key exists.

Duplicate detection and Object merge are distinct concepts:
- detection may suggest that two Objects could represent the same entity;
- merge is an explicit user/system-authorized operation with a reviewed merge plan;
- fuzzy similarity must never silently collapse canonical Objects.

Object merge is a future first-class capability tracked by #1062. Its contract must:
- choose or preserve one surviving canonical Object identity;
- define redirect/tombstone behavior for the retired identity so old references do not silently dangle;
- preserve or explicitly reconcile Body, Properties, aliases, lifecycle metadata and other user-authored state;
- rewire Relations only through canonical Relation integrity APIs;
- fail closed on cardinality/order/role or scalar-value conflicts rather than overwrite data;
- preserve Database/View behavior without cloning Object identity;
- remain restart/reconciliation safe and retry/idempotency aware;
- avoid inferring managed Image/File byte-deletion authority from identity merge alone.

Until merge/redirect semantics exist, migrations must fail closed rather than silently combine Objects with conflicting user-authored data or Relations.

## Properties

Property definitions have stable identity independent of their display name.

Property architecture separates three layers:

```text
Value type
  ↓
Constraints / semantics
  ↓
Presentation
```

Examples:
- Rating = Number + min/max/step + stars presentation.
- Progress = Number + range constraint + progress-bar presentation.
- Currency = Number + currency presentation.

The goal is a small set of strong value types with extensible constraints/presentation rather than a large closed enum of narrowly named property types.

Property type implementations should be registry-friendly and able to provide:
- encoding/decoding;
- validation;
- comparison/sort semantics;
- available query operators;
- renderer/editor behavior;
- conversion/migration rules.

Unknown future property types or values must be preserved rather than deleted by older code paths.

## Select versus Tag

`Select` / `Multi-select` are lightweight finite choices local to one Property definition.

`Tag` is a reusable Object with identity, hierarchy, aliases/description, relationships, and workspace-wide query meaning.

A lightweight Select may later be promoted/migrated to Tag/TagGroup, but the two concepts are not interchangeable by default.

## Relations

Relation is a first-class typed Property and uses the canonical Relation subsystem.

A Relation definition can describe:
- target ObjectType;
- one/many cardinality;
- ordering;
- inverse/backlink behavior;
- role semantics where appropriate.

Roles such as `Author`, `Member`, or `Designer` belong to Relation semantics rather than becoming additional ObjectTypes.

Do not create domain-specific edge stores when canonical Relations can represent the relationship.

## Tags and Tag Groups

`Tag` and `TagGroup` use generic Object/Relation persistence with specialized query semantics and UX.

### Canonical hierarchy

Tag hierarchy is represented by a canonical relation such as:

```text
Tag --Parent--> Tag
```

An Object stores only its directly assigned Tag Relations. Ancestors are derived and are **not** redundantly auto-assigned.

Example:

```text
くだもの
└─ りんご
   └─ 青りんご

Object direct tag = 青りんご
```

The stored assignment remains only `青りんご`.

### Hierarchy-aware query semantics

The query system must distinguish exact and hierarchical predicates.

For the example above:
- exact `くだもの` => no match;
- `くだもの` including descendants / `is or below` => match;
- `りんご` including descendants => match.

Extensible operators should include concepts such as:
- exact;
- is-or-below;
- below-only;
- exclude branch.

TagGroup may carry group-level semantics such as single/multiple selection, required/optional, ordering, and hierarchy-matching defaults.

### Specialized UX over generic persistence

Generic persistence does not imply generic-only UI. The product should provide a hierarchy-aware tree picker/editor, parent-context child creation, path display, descendant-filter controls, and clear direct-versus-derived classification.

## Database and View

Objects are global within a Vault and are not owned by Databases or Views.

```text
Object != Database row identity
```

The same Object may appear through many Database contexts without duplication.

A Database defines an Object set/context. It may use:
- manual membership;
- query-derived membership;
- manual membership plus View filters.

A View defines how a Database context is presented and refined:
- layout;
- filter;
- sort;
- group;
- visible Properties;
- opening/presentation behavior.

The target layouts include Table/List/Gallery/Board and may expand to Calendar/timeline-style views later.

## Query architecture

Database filtering should converge on an extensible typed query model rather than domain-specific filter engines.

The internal query representation should be capable of composing:
- AND / OR / NOT;
- typed Property predicates;
- Relation predicates;
- Tag hierarchy predicates;
- lifecycle predicates;
- derived Formula/Rollup predicates when introduced.

Canonical state remains separate from rebuildable search/index/cache structures.

## Formula and Rollup direction

Formula and Rollup are derived values, not independent canonical stored values.

Formula results should be typed so they can participate in filter/sort/group semantics. Dependency cycles must be rejected. Implement incrementally after the basic Property/query contracts are stable.

## Body

Body is the free-form document side of every Object; Properties are the structured side.

```text
Object
├─ structured Properties / Relations
└─ free-form Body block document
```

The editor should feel like a document, not a form containing block rows and permanent toolbars.

Baseline interaction direction:
- Enter creates/splits the next paragraph;
- Shift+Enter inserts an in-block line break where appropriate;
- Backspace merges/focuses adjacent text blocks where appropriate;
- block actions are contextual rather than permanently occupying a toolbar row;
- blocks support drag/reorder with accessible move-command fallback;
- slash commands progressively expose headings/lists/todo/quote/code/math/media/Object references;
- Undo is preferred over confirmation dialogs for reversible editing operations;
- keyboard/focus behavior is part of acceptance, not post-polish.

Persisted Body compatibility must be preserved while the editor UX evolves.

## Undo and durable version history

Short-lived local Undo and durable version history are different product layers.

**Local Undo** reverses recent, losslessly invertible interaction changes and may use transient UI feedback such as `元に戻す`. It should fail closed if a later mutation makes the stored inverse unsafe.

**Durable history** survives restart and explains/restores earlier Object state. The future contract is tracked by #1064 and should be capable of accounting for Object/lifecycle, Property, Body and Relation changes without turning the entire application into an event-sourcing rewrite by default.

Durable restore must:
- keep current canonical state authoritative;
- distinguish whole-Object restore from selective field/Body restore;
- detect conflicts with newer state rather than blindly overwrite it;
- validate restored Relations through current canonical integrity/cardinality rules;
- treat managed Image/File byte retention as an explicit Storage concern, not as an automatic consequence of metadata history;
- define retention/compaction semantics before unbounded history storage is introduced.

Do not force local Undo and durable history into one global command-stack abstraction merely because both can reverse changes.

## Generic Object Inspector

The shared Object Inspector is a primary product surface. It should compose Title, Properties, Relations, Tags, native type capabilities and Body with consistent inline editing.

Do not create a dedicated management page for every ObjectType when the generic Inspector/Database/View contracts can provide the workflow.

## Capture and Inbox

The default capture philosophy is:

> Capture first, organize later.

Saving a URL/Image/File/text should be fast and should not require choosing every Tag/Database/Relation up front.

Inbox is a standard Object collection/query context for items that still need organization; it is not a special ObjectType.

Normal URL capture should target roughly 1–2 primary actions.

## Home and work-start surface

The long-term Home/start surface is a place to begin work, not a catalog of legacy domain modules.

The target composition is:

```text
Home
├─ Inbox
├─ Recent
├─ Favorites
└─ Pinned Databases
```

This direction is tracked by #1061.

- Inbox surfaces captured Objects that still need organization.
- Recent surfaces recently opened/changed Objects and useful contexts.
- Favorites is reusable user state/query context, not a new ObjectType.
- Pinned Databases are user-chosen entry points into canonical Database/View contexts.

Legacy normal-use navigation such as `ブックマーク`, `人物`, or `写真` should disappear from the final Home only after the corresponding generic Weblink/Person/Image replacement has parity and the dedicated path is caller-zero. Do not remove transition navigation early merely to make Home look finished.

Home must follow the same UX contract as the rest of the product: low click/key count, useful empty/loading/error states, keyboard navigation on desktop, touch reachability on mobile, and consistent create/open behavior.

## Object lifecycle and deletion

Removing an Object from a Database is not Object deletion.

The lifecycle direction is:
- Active;
- Archived;
- Trashed;
- permanent deletion only through an explicit final action.

Managed Image/File bytes should not be physically deleted merely because an Object leaves a Database or enters Trash. Permanent deletion must prove active-Vault ownership and shared-reference safety.

## Templates

ObjectType defines schema/capabilities. Template defines creation defaults, initial Property values, and initial Body content.

One ObjectType can have multiple Templates.

## Search and command navigation

Search is a shared application capability, not a domain-specific repository per ObjectType.

`Cmd/Ctrl+K` should progressively become global navigation/command infrastructure for Object search, Database navigation, creation, recent items, Tags and commands.

Pickers should reuse canonical search behavior rather than implementing isolated search engines.

## UX quality contract

A feature is not complete merely because an action is technically possible.

Focused UI issues should define both:
- functional acceptance;
- interaction acceptance.

Review high-frequency flows for:
- click/key count;
- inline creation/editing;
- staying in the current context;
- consistent shared picker behavior;
- keyboard/focus behavior;
- empty/error/loading states;
- reversible actions / Undo;
- mobile versus desktop interaction differences;
- accessibility and touch-target/contrast/focus requirements.

Prefer context-local actions (for example child Tag creation next to its parent) over routing users to separate management screens.

## Vault, portability, and future sync

A Vault is one local Object universe containing Objects, schema, Relations, Databases/Views, Body data and managed files.

The canonical model must remain portable/exportable and must not depend on one UI representation. Future sync/collaboration/plugin support is not required now, but data identities and registries should not make those directions impossible.

### Open export and portability

Backup/restore and portable export are distinct capabilities.

Backup/restore preserves an application Vault for recovery. Portable export exists so users can intentionally take their information out of the application in documented, inspectable formats. The focused contract is tracked by #1063.

A future lossless export package must be able to preserve enough information to reconstruct or verify:
- stable Object IDs and ObjectTypes;
- typed Property definitions/values, including preserved unknown future values where possible;
- Relations by stable identity with ordering/role/cardinality semantics;
- Body block documents and Object/file references;
- Database/View definitions and query configuration for whole-context exports;
- managed Image/File bytes with explicit provenance/ownership metadata;
- external references without silently copying/rebasing them unless the chosen export mode requests inclusion.

Open projections such as Markdown or CSV are valuable, but they are lossy projections whenever they cannot represent the complete typed graph. Do not claim Markdown/CSV round-trip fidelity if Object IDs, Relations, unknown Property types, View configuration or block semantics are omitted.

Prefer an inspectable structured layer such as JSON for the canonical export graph/schema plus human-friendly Markdown/CSV projections where appropriate, and a directory/ZIP package when managed bytes are included. Exact formats should be decided contract-first and tested for lossless versus intentionally lossy behavior.

## Migration and legacy retirement

Historical schema is a compatibility contract until explicitly retired.

The standard retirement sequence is:

```text
replacement contract
→ parity
→ caller-zero proof
→ legacy UI/API/code deletion
→ preservation validation
→ explicit destructive schema migration
```

Do not delete user data because a replacement UI exists. Schema migrations are single-writer work and require historical upgrade regressions where feasible.

## Product / umbrella completion contract

A focused implementation slice may be complete when its own acceptance criteria and required validation are green. That does **not** automatically mean the umbrella/product capability is Done.

For an important umbrella, review every applicable dimension:

1. **Architecture** — the durable model and ownership boundaries are explicit and do not contradict the constitution.
2. **Behavior** — the promised functional scope works through canonical contracts.
3. **Tests** — product meaning is locked by appropriate contract/unit/integration/real-host regressions, not only implementation-detail tests.
4. **UX** — primary flows are efficient, coherent and stay in context where appropriate.
5. **Keyboard / accessibility / device interaction** — keyboard/focus, screen-reader/touch-target/contrast and desktop/mobile behavior are addressed where applicable.
6. **Empty / loading / error / recovery states** — non-happy paths are intentional and usable.
7. **Migration / reconciliation** — existing data survives restart/reconciliation and supported historical transitions.
8. **Replacement parity** — the new generic/native path covers the product behavior worth preserving.
9. **Legacy retirement** — old UI/API/runtime paths become caller-zero before deletion.
10. **Preservation before destruction** — destructive schema/data removal happens only after preservation evidence and a separate explicit migration.
11. **Durable handoff** — Issues, architecture docs and lane/repository handoffs reflect the resulting state.

Not every small Issue needs every dimension. Umbrella Issues should explicitly mark a dimension non-applicable or deferred rather than silently treating it as complete.

## AI parallel-development contract

Architecture decisions in this document are stable product constraints. Implementation agents may make scoped reversible engineering decisions, but must not silently change these product semantics.

Parallel development rules:
- one focused Issue has one active implementation owner/branch/PR;
- split umbrella work by stable responsibility/contracts, not temporary file availability;
- define interfaces/contract tests before broad parallel implementation where practical;
- treat tests that encode product semantics as contracts between agents;
- reduce shared hotspots structurally instead of only adding coordination machinery;
- schema/migration writer is single-writer;
- replacement and legacy retirement are separate phases;
- live GitHub Issue/PR/CI/main state is authoritative for ownership and progress;
- handoffs store durable facts, not ephemeral “currently running/no PR” snapshots;
- combined-state/merge-queue CI is the desired final integration gate once repository settings permit it.

### H — Architecture & Integration Oversight

A–G are the product/engineering implementation ownership lanes. H is a repository-wide **control-tower / oversight lane**, not a competing product implementation lane. Its durable contract is `docs/AI_PROGRESS_OVERSIGHT.md` and #1060.

H should continuously inspect live `main`, Issues, PRs, CI and A–G handoffs for:
- architecture drift;
- duplicate/overlapping work;
- cross-lane dependency and integration gaps;
- shared-hotspot/migration-writer conflicts;
- UX inconsistency across independently implemented features;
- newly emerging technical debt and legacy growth;
- missing combined-state/correctness/preservation tests;
- roadmap or umbrella-completion incoherence;
- newly discovered product gaps that deserve a focused Issue.

H may investigate, review, discuss, comment, create/refine Issues and update repository-wide routing/oversight documentation. Concrete implementation work should be routed to exactly one owning A–G lane. H should not normally implement runtime product behavior, perform schema migrations, take broad shared-hotspot ownership, redesign canonical Object/Relation semantics under an audit label, or merge another lane's work merely to maintain throughput.

A fresh H chat must be able to resume from GitHub alone with `Hレーンとして作業を続けて`.

## Near-term migration and roadmap routing

- #1039 / #1041 / #1042 / #1043 — retire the legacy Bookmark domain toward Weblink + generic Object/Database/Inbox UX. Do not make Bookmark a final ObjectType.
- #1040 / #1044 / #1045 / #1046 — retire the dedicated People subsystem toward generic Person ObjectType + generic Relation/Database/View UX.
- #1049 / #1057 / #1058 — make Body editing document-like and locally undoable while preserving Body persistence.
- #1050 / #1052 / #1053 — generic Tag/TagGroup hierarchy and hierarchy-aware query/UX contracts.
- #1061 — Home/start surface centered on Inbox / Recent / Favorites / Pinned Databases.
- #1062 — explicit Object duplicate detection, merge and redirect/tombstone contract.
- #1063 — open export/portability contract distinct from backup/restore.
- #1064 — durable Object/Property/Body/Relation version history and conflict-safe restore contract.
- #1060 — H oversight/control-tower and completion-contract integration.

New work should reference the focused Issue and this architecture contract.
