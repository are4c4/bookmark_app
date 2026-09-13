# AI Progress — Architecture & Integration Oversight

> Durable H-lane handoff. H is the repository-wide control tower above the A–G implementation lanes. It observes, audits, routes, and records; it does not normally own product/runtime implementation.

## H lane goal

Keep the whole application coherent while multiple specialized AI lanes work in parallel.

H continuously checks whether the combined repository is moving toward the Object-first product constitution, whether independently correct PRs compose safely, and whether new problems or opportunities are emerging between focused Issues.

A fresh chat should be able to resume with only:

```text
Hレーンとして作業を続けて
```

and reconstruct the necessary context from GitHub without relying on chat history.

## Source of truth on every resume

Read/recheck in this order:

1. `AGENTS.md`.
2. `docs/product_architecture.md`.
3. `docs/AI_PROGRESS.md`.
4. this file.
5. `docs/AI_PRODUCT_PRIORITY.md` for advisory safe/ready work selection.
6. relevant A–G lane handoffs.
7. latest `main` and recent meaningful commits.
8. all live open PRs, their declared lane/Issue/dependencies/hotspots, and current CI.
9. relevant open umbrella/focused Issues and recently completed Issues that changed routing.
10. current shared-hotspot, migration-writer, and repository-setting state.

**Live GitHub state overrides durable handoff snapshots for all transient facts.** Do not copy current open-PR counts, CI run numbers, branch tips, or other short-lived ownership facts into this handoff as long-lived truth. Record durable findings, contracts, dependencies, and resume targets instead.

## H is not another product implementation lane

A–G remain implementation ownership lanes:

- A — Object Core & Body
- B — Relations & Data Integrity
- C — Database, View & Schema UX
- D — Primitive Objects & Media
- E — Search & Indexing
- F — Storage, Vault & Delivery
- G — Refactor & Architecture Health

H may create/refine Issues, review PRs, comment on cross-lane risks, update repository-wide routing/oversight documentation, and make focused coordination/guardrail changes when a dedicated coordination Issue owns them.

H should not normally implement runtime features, take product hotspot ownership away from A–G, perform schema/data migrations, redesign canonical Object/Relation semantics under an audit label, create duplicate persistence/query/search/index systems, merge another lane's PR merely for throughput, or invent speculative work because a lane is idle.

Concrete product/correctness defects found by H are routed to exactly one owning implementation lane through an existing or new focused Issue.

## Continuous audit checklist

### Architecture drift
Check for:
- Bookmark/People/Photo concepts being reintroduced as permanent product authorities;
- ObjectType used for roles/classifications that belong to Relation/Property/Tag/Database context;
- Databases accidentally owning or duplicating Object identity;
- Tag hierarchy or relationships creating parallel edge/tree stores;
- domain-specific query/search engines growing instead of canonical Object/query contracts;
- native-capability behavior leaking into unrelated generic persistence.

### Cross-lane integration
Check for:
- dependent Issues implemented against incompatible contracts;
- individually green PRs that may fail when composed on latest `main`;
- Relation/Object/Search/Vault lifecycle changes missing cross-lane regressions;
- caller-zero cleanup before replacement parity/preservation proof;
- schema/migration work without a single active writer.

### Parallel-development safety
Check for:
- duplicate active ownership of one focused Issue;
- overlapping shared-hotspot edits;
- stale branches/handoffs carrying obsolete assumptions;
- broad formatting/churn increasing conflict risk;
- long-lived PRs that should be refreshed, split, or superseded;
- machine-certifiable PR contract violations that are still only advisory and should be hardened by a focused G/H guardrail Issue.

### Approval-sensitive / solo-maintainer safety
For high-confidence destructive or approval-policy-sensitive PRs, preserve the #1107 machine path and #1331 solo-maintainer boundary:
- the normal green path is a distinct non-author current-head `APPROVED` review from a write/admin GitHub User;
- if no independent reviewer exists, the only fallback is an explicit human repository-admin ruleset bypass on the final PR head, preferably PR-only;
- `tool/pr_coordination_guard.py` is expected to remain red on that manual path; H must not route work to weaken it merely to obtain green CI;
- the implementation/AI GitHub App, Actions identities and bots must never be bypass actors;
- H should verify live ruleset/bypass state when relevant, not assume it from documentation;
- before manual bypass, require one final synchronization to current `main`, all non-approval validation, and human inspection of the final diff/head; later commits invalidate the prepared decision;
- when waiting for this human action, record `Stop reason: destructive-approval` and continue unrelated audits/work rather than recommending a second/dummy account or repeated no-op branch churn;
- this manual path does not close #1107 Phase B or prove an independently immutable trust root.

### Durable-document freshness
Check for:
- transient facts copied into `AI_PROGRESS*.md` as if permanent;
- repository settings described differently from live GitHub;
- schema/tool/dependency versions duplicated in prose where code/config should be the single source of truth;
- completed Issues still listed as active blockers;
- README/product descriptions drifting from `docs/product_architecture.md`.

Prefer eliminating duplicated volatile facts over adding synchronization work. Machine-checkable drift should become a CI/repository-contract check where the signal is deterministic; semantic drift remains an H responsibility.

### Product and UX coherence
Review the application as a whole:
- consistent create/select/edit/delete semantics;
- consistent picker/search/inline-edit interactions;
- remove-from-Database versus Object lifecycle clarity;
- click/key count on frequent workflows;
- keyboard/focus/accessibility/touch behavior;
- desktop/mobile interaction consistency;
- empty/loading/error states;
- Home/Inbox/Recent/Favorites/Pinned Databases coherence;
- whether the generic Object Inspector remains the primary shared Object surface.

For visual/layout oversight, inspect the latest successful advisory UI Audit artifact when available. Treat the screenshots and manifest as evidence tied to an exact source SHA, not as a replacement for live code, behavioral tests, or product requirements. A visual finding becomes actionable only when H can describe a concrete problem and route it to exactly one A–G owning lane through a focused Issue; H does not implement product fixes under the label of screenshot review.

### User-visible priority routing
When multiple independent Issues/findings are both safe and ready, apply `docs/AI_PRODUCT_PRIORITY.md` rather than preferring whichever task is easiest to implement.

- Safety, preservation, data integrity, deterministic correctness, dependencies, hotspot ownership, migration ownership and approval policy are evaluated first and may override product priority.
- Among the remaining safe/ready choices, compare user-visible impact, frequency, friction and breadth. Prefer shared high-frequency friction and core-journey blockers over equally safe niche/internal cleanup.
- Use the focused Issue's `Product priority signal` when present. H may refine/annotate an existing Issue if the signal is missing; do not duplicate an Issue merely to encode priority.
- The rubric is advisory, not a numerical score or merge gate. Report genuine ties/ambiguity instead of manufacturing precision.
- Product implementation remains with exactly one A–G owner; H only routes/reorders attention.

### Emerging technical debt
Look for repeated helpers/adapters, new direct `AppDatabase` reach-through, shared hotspots growing again, new legacy dependencies, hidden-failure policies, and speculative caches/indexes without measurement/rebuild semantics. Do not demand abstraction on first occurrence.

### Correctness and preservation
Check missing cross-cutting tests around restart/reconciliation, duplicate/collision handling, deletion/detach/backlinks, historical migration checkpoints, Vault move/switch/backup/restore, managed/external file ownership, and combined-state behavior.

Real-macOS preservation evidence remains required before destructive legacy data/schema retirement where #242/#951 or successor preservation contracts apply.

### Roadmap coherence
Check what blocks the Object-first target, which lanes have independent safe work, which work must wait for a dependency, whether an umbrella is being declared Done too early, whether new product gaps need focused Issues, and whether completed replacement architecture actually retired its legacy normal-use path.

## H routing rules

- A: Object/ObjectType identity, Property value semantics, Body/history/merge core contracts.
- B: Relation integrity, backlinks, cardinality/order, hierarchy integrity, rewiring.
- C: Database/View/query UX, Home, Inbox, Tag picker/filter, generic collection/navigation UX.
- D: Weblink/Image/File native identity/import/media behavior.
- E: canonical Object Search/FTS/index freshness/ranking.
- F: Vault/filesystem/backup/restore/export packaging/preservation/delivery.
- G: behavior-preserving refactor, hotspot reduction, caller-zero cleanup, CI/developer-loop and architecture/handoff guardrails.

If responsibility genuinely spans lanes, split it into coherent focused Issues with explicit dependencies rather than one broad cross-lane implementation PR.

## Product roadmap contracts H must protect

These are durable directions; H must still check their live Issue state before describing them as active:

- #1061 — Home becomes a work-start surface centered on Inbox / Recent / Favorites / Pinned Databases.
- #1062 — duplicate detection and explicit Object merge/redirect semantics become first-class and fail closed on conflicts.
- #1063 — users get an open portable export path distinct from backup/restore.
- #1064 — durable Object/Property/Body/Relation history remains distinct from short-lived local Undo.

Repository branch protection/required `merge-gate` is now established; treat live rulesets/settings as the authority rather than preserving old #980 blocker text here.

## Advisory UI-audit oversight contract

#1353 established an advisory deterministic UI snapshot foundation owned by G and consumed by H.

- The audit uses repository-owned deterministic fixtures, a fixed dark desktop profile, source-SHA manifests, bounded GitHub Actions artifacts, and representative shared surfaces rather than full-app screenshots.
- The visual job is advisory: subjective or pixel-level opinions are not a required merge gate. Existing interaction/Analyze/full Flutter Test correctness remains authoritative for blocking behavior.
- H should inspect the latest successful artifact/report when visual evidence would materially improve an oversight conclusion. Prefer the artifact whose manifest source SHA matches the code state under review, and verify scenario status before relying on it.
- Screenshots are evidence only. Do not infer persistence, lifecycle, accessibility, or semantic correctness from pixels when those claims require code/tests/runtime evidence.
- When a screenshot reveals a concrete UX/layout problem, route one focused Issue to the owning A–G lane, record the exact affected surface/contract, and avoid bundling unrelated visual cleanup.
- Do not store external-model API credentials or introduce subjective AI screenshot scoring merely to automate H. Any later blocking golden contract requires a separate evidence-backed decision.

## Umbrella completion audit

A focused implementation slice may be complete when its acceptance criteria and required validation are green. An umbrella/product capability is not Done merely because one PR merged. H checks applicable architecture, behavior, tests, primary UX, accessibility/device interaction, empty/loading/error/recovery states, migration/reconciliation, replacement parity, caller-zero retirement, preservation before destructive changes, and durable documentation/routing.

## H autonomous loop

1. Re-read the live source of truth above.
2. Build a current map of active work, dependencies, hotspot leases, migration writer, and relevant repository settings.
3. Inspect recent `main` changes for architecture/product integration implications.
4. Audit architecture, integration, parallel safety, durable-doc freshness, UX, technical debt, correctness/preservation, and roadmap coherence.
5. When multiple independent safe/ready Issues or findings compete, apply the user-visible priority rubric before routing/choosing attention; do not favor lower-impact work solely because it is easier.
6. When visual/layout evidence would help, inspect the latest successful UI Audit artifact/report and tie observations to its source SHA; never treat screenshots as source-of-truth over live code/GitHub.
7. For each finding, link an existing Issue or create one focused Issue with one primary A–G owner; record dependencies, hotspot/migration impact, product-priority signal where applicable, and acceptance criteria.
8. Correct repository-wide durable routing/docs only when durable facts changed.
9. Continue to another independent audit area instead of stopping after the first finding.
10. Before ending, keep this handoff resumable without chat history.

## Stop conditions

H stops only when the major oversight areas have been checked and no further actionable evidence exists, the next conclusion needs a genuine product decision, all meaningful findings depend on work that cannot yet be evaluated, or tooling/session limits prevent useful inspection.

One clean PR, one green CI run, one completed Issue, or one newly created Issue is not by itself a stop reason.

When the sole blocker for an approval-sensitive PR is the #1331 solo-maintainer human ruleset action, classify it as `destructive-approval`, keep unrelated oversight active, and recheck live repository settings on the next run. Do not turn it into a permanent repository-wide idle state.

## Durable checkpoint — 2026-09-09

The Object-first constitution, A–G lane ownership model, H oversight contract, strict protected-main `merge-gate`, migration/hotspot/handoff audits, branch-cleanup policy, advisory deterministic UI-audit evidence path, and user-visible priority-routing rubric are established. H should not preserve exact current PR/branch/CI/artifact run identifiers here; every new run rebuilds them from live GitHub.

Immediate oversight priority is to keep the repository's AI coordination and reproducibility guardrails aligned with the increasing number of parallel implementation lanes, while protecting the near-term product focus on Bookmark retirement, People retirement, Tag hierarchy, Body interaction follow-ups, and Home/start UX before expanding speculative feature scope.
