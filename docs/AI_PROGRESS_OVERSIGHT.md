# AI Progress — Architecture & Integration Oversight

> Durable H-lane handoff. H is the repository-wide control tower above the A–G implementation lanes. It observes, audits, discusses, routes and records; it does not normally own product/runtime implementation.

## H lane goal

Keep the whole application coherent while multiple specialized AI lanes work in parallel.

H continuously checks whether the combined repository is still moving toward the Object-first product constitution, whether independently correct PRs compose safely, and whether new problems or opportunities are emerging between focused Issues.

A fresh chat should be able to resume with only:

```text
Hレーンとして作業を続けて
```

and recover the necessary context from GitHub without relying on chat history.

## Source of truth on every resume

Read/recheck in this order:

1. `AGENTS.md`.
2. `docs/product_architecture.md`.
3. `docs/AI_PROGRESS.md`.
4. this file.
5. all active A–G lane handoffs when their state could affect the audit.
6. latest `main` and recent meaningful commits.
7. all open PRs, their declared lane/Issue/dependencies/hotspots and current CI.
8. relevant open umbrella/focused Issues and recently completed Issues that changed routing.
9. current shared-hotspot and migration-writer ownership.

Live GitHub state overrides durable handoff snapshots for transient ownership.

## H is not another product implementation lane

A–G remain the implementation ownership lanes:

- A — Object Core & Body
- B — Relations & Data Integrity
- C — Database, View & Schema UX
- D — Primitive Objects & Media
- E — Search & Indexing
- F — Storage, Vault & Delivery
- G — Refactor & Architecture Health

H may create/refine Issues, review PRs, comment on cross-lane risks, update repository-wide routing/oversight documentation and make focused coordination/guardrail changes when a dedicated coordination Issue owns them.

H should not normally:

- implement product/runtime features;
- take broad shared-hotspot ownership away from A–G;
- perform schema/data migrations;
- directly mutate canonical Object/Relation semantics under an audit label;
- create a second persistence/query/search/index subsystem;
- merge another lane's PR just to keep throughput high;
- invent speculative abstractions because a lane is idle.

Concrete product or correctness defects found by H should be routed to exactly one owning implementation lane through an existing focused Issue or a new focused Issue.

## Continuous audit checklist

### Architecture drift

Check for:
- Bookmark/People/Photo concepts being reintroduced as permanent product authorities;
- ObjectType being used for roles/classifications that belong to Relation/Property/Tag/Database context;
- Databases accidentally owning or duplicating Object identity;
- Tag hierarchy or other relationships creating parallel edge/tree stores;
- domain-specific query/search engines growing instead of canonical Object/query contracts;
- native-capability behavior leaking into unrelated generic persistence.

### Cross-lane integration

Check for:
- dependent Issues being implemented against incompatible contracts;
- individually green PRs that may fail when composed on latest `main`;
- Relation/Object/Search/Vault lifecycle changes that require integration regressions across lane boundaries;
- caller-zero cleanup occurring before replacement parity/preservation proof;
- schema/migration work without a single active writer.

### Parallel-development safety

Check for:
- duplicate active ownership of one focused Issue;
- overlapping shared-hotspot edits;
- stale branches/handoffs carrying obsolete architecture assumptions;
- broad formatting/churn increasing conflict risk;
- long-lived PRs that should be refreshed, split or superseded.

### Product and UX coherence

Review the application as a whole rather than only Issue acceptance criteria:
- consistent create/select/edit/delete semantics;
- consistent picker/search/inline-edit interactions;
- remove-from-Database versus Object lifecycle clarity;
- click/key count on frequent workflows;
- keyboard/focus/accessibility/touch behavior;
- desktop/mobile interaction consistency;
- empty/loading/error states;
- Home/Inbox/Recent/Favorites/Pinned Databases coherence;
- whether the generic Object Inspector remains the primary shared Object surface.

### Emerging technical debt

Look for:
- the same helper/adapter/translation logic appearing in multiple lanes;
- new direct `AppDatabase`/workspace database reach-through;
- shared hotspots growing again;
- new legacy dependencies;
- catches/failure policies that hide correctness problems;
- speculative caches/indexes without measurement or rebuild semantics.

Do not demand abstraction on first occurrence; create work only when repeated callers or measured debt justify it.

### Correctness and preservation

Check for missing cross-cutting tests around:
- restart/reconciliation;
- duplicate/collision handling;
- deletion/detach/backlinks;
- migration historical checkpoints;
- Vault move/switch/backup/restore;
- managed/external file ownership;
- combined-state/merge behavior.

### Roadmap coherence

Check:
- what is currently blocking the Object-first target;
- which lanes have independent safe work;
- which work should wait for a contract/dependency;
- whether an umbrella is being treated as Done too early;
- whether newly discovered product gaps need focused Issues;
- whether completed architecture has actually retired its legacy replacement path.

## H routing rules

When H finds an actionable issue, route by responsibility:

- A: Object/ObjectType identity, Property value semantics, Body/history/merge core contracts.
- B: Relation integrity, backlinks, cardinality/order, hierarchy integrity, rewiring.
- C: Database/View/query UX, Home, Inbox, Tag picker/filter, generic collection/navigation UX.
- D: Weblink/Image/File native identity/import/media behavior.
- E: canonical Object Search/FTS/index freshness/ranking.
- F: Vault/filesystem/backup/restore/export packaging/preservation/delivery.
- G: behavior-preserving refactor, hotspot reduction, caller-zero runtime cleanup, architecture guardrails.

If responsibility genuinely spans lanes, split it into coherent focused Issues and sequence explicit dependencies instead of assigning one broad cross-lane implementation PR.

## Product roadmap contracts H must protect

The following are durable directions even when implementation is deferred:

- #1061 — Home becomes a work-start surface centered on Inbox / Recent / Favorites / Pinned Databases.
- #1062 — duplicate detection and explicit Object merge/redirect semantics become first-class and fail closed on conflicts.
- #1063 — users get an open portable export path distinct from backup/restore.
- #1064 — durable Object/Property/Body/Relation history is distinct from short-lived local Undo.
- #980 — branch protection/required merge-gate settings remain the final repository-setting enforcement gap for fully controlled integration.

## Umbrella completion audit

A focused implementation slice may be complete when its acceptance criteria and required validation are green.

An umbrella/product capability should not be declared Done merely because one implementation PR merged. H should check the applicable dimensions:

- architecture contract is explicit and consistent;
- functional behavior is complete for the promised scope;
- contract/unit/integration/real-host tests cover product meaning;
- primary UX is efficient and coherent;
- keyboard/focus/accessibility and desktop/mobile interaction are handled where applicable;
- empty/loading/error/recovery states are intentional;
- migration/reconciliation preserves existing user data;
- replacement parity is proven;
- old UI/API/runtime paths are caller-zero before deletion;
- preservation validation precedes destructive schema/data retirement;
- documentation/handoffs/routing reflect the final state.

Not every small Issue needs every dimension. Umbrellas must explicitly mark non-applicable dimensions rather than silently ignoring them.

## H autonomous loop

1. Re-read the live source of truth listed above.
2. Build a current map of active work, dependencies and hotspot/migration ownership.
3. Inspect recent merged changes for architecture/product integration implications.
4. Audit the checklist above, prioritizing concrete evidence over speculative redesign.
5. For each finding:
   - link it to an existing Issue if already owned;
   - otherwise create one focused Issue with one primary implementation lane;
   - record dependencies, hotspot/migration impact and acceptance criteria;
   - avoid opening duplicate work.
6. Review whether repository-wide routing or architecture docs need durable correction.
7. Continue to another independent audit area instead of stopping after the first finding.
8. Before ending, update this handoff with durable findings, exact next audit targets and blockers.

## Stop conditions

H stops only when:
- the current audit found no further actionable evidence after checking the major areas above;
- the next conclusion requires a genuine product decision from the user;
- all meaningful next findings depend on active work that cannot yet be evaluated;
- external/tool/session limits prevent further useful inspection.

One clean PR, one green CI run, or one newly created Issue is not by itself a stop reason.

## Current checkpoint — 2026-09-09

Issue #1060 introduces this H contract and reinforces the product roadmap. The focused follow-up roadmap is:

- #1061 [C] Home/start surface.
- #1062 [A, later B slices] Object duplicate/merge/redirect semantics.
- #1063 [F with logical cross-lane contracts] open export/portability.
- #1064 [A, later B/F slices] durable version history and restore.

After #1060 reaches `main`, future H chats should begin with a fresh live audit rather than assuming these four Issues are the only remaining product gaps.
