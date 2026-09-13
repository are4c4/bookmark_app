# AI Product-Quality Priority

> Advisory repository-wide work-selection guidance for autonomous AI development.
>
> This document defines **what kind of safe ready work should win when multiple choices exist**. It does not override architecture ownership, dependencies, migration single-writer, shared-hotspot leases, preservation requirements, destructive approval, or other safety gates. Live GitHub remains authoritative for current ownership and readiness.

## Why this exists

The repository deliberately makes safe, well-scoped internal work easy to execute. Without an explicit product-priority signal, an autonomous lane can therefore keep choosing low-risk internal cleanup while higher-frequency user-visible friction in the same lane remains ready.

Work selection should optimize for both repository safety and actual product improvement.

## Product-priority signal

For focused product/UX Issues, record or infer a concise signal:

- **Impact:** high / medium / low — how much the user-visible outcome matters;
- **Frequency:** daily / frequent / occasional / rare — how often the affected workflow occurs;
- **Friction:** severe / moderate / minor — how much the current behavior slows, confuses, or blocks the user;
- **Breadth:** shared / multi-surface / local — whether the issue affects a shared cross-product surface or one niche host;
- **Readiness:** ready / dependency-blocked / hotspot-blocked / migration-blocked / approval-blocked.

Avoid fake numerical precision. This is an advisory prioritization signal, not a score used by CI.

A concise Issue entry is enough, for example:

```text
Impact: high
Frequency: daily
Friction: moderate
Breadth: shared
```

Invisible refactor, backend-only correctness, documentation, and developer-workflow Issues may use `n/a`; they must not fabricate product priority.

## Selection rule

Safety and correctness dominate first. A preservation, data-integrity, security, migration, or deterministic correctness blocker may outrank visible UX regardless of its product-priority signal.

After safety/dependency/ownership gates are satisfied, when a lane has multiple independent **safe and ready** choices, prefer roughly:

1. high-frequency user-visible friction on shared surfaces;
2. blockers/regressions in core user journeys;
3. work that makes a major existing capability complete in its real host;
4. lower-frequency product polish;
5. internal cleanup/refactor that does not currently unlock product or safety value.

A lane must not choose lower-impact work solely because it is easier when a higher-impact safe Issue in that same lane is ready. Finish an already-owned coherent safe slice before switching merely because a different Issue has a higher priority signal.

## H oversight/routing behavior

H uses the signal when several findings or ready Issues compete for attention:

- check live dependency/hotspot/migration/approval readiness first;
- compare impact, frequency, friction and breadth among the remaining safe choices;
- prefer shared daily-use friction over equally safe niche/internal work;
- annotate/refine an existing Issue rather than duplicating it solely to add priority;
- route concrete implementation to exactly one A–G owner;
- report genuine ties/ambiguity instead of pretending the rubric is mathematically precise.

H remains an oversight lane and does not take product implementation ownership itself.

## Lane behavior

A–G lanes should use the priority signal during next-work discovery after the current focused Issue is complete. It applies **within the lane's existing ownership boundary**; it is not permission to steal another lane's work or broaden an Issue.

Examples of commonly high-value shared surfaces include Body/Object detail, Relation/Tag pickers, Database/View authoring, Search/command entry points, and Home/start workflows, but these examples are calibration only. Their live priority depends on current Issues and product state.

## Product acceptance loop

For materially user-facing work, prefer completion evidence shaped like:

```text
implementation
+ focused tests
+ authoritative CI
+ provenance-linked real-host/UI evidence where relevant
+ affected user-journey/acceptance check
= product-complete
```

#1353 established the advisory deterministic UI-audit evidence foundation. #1367/#1368/#1370 or successor Issues may extend journey/evidence/review policy; always verify their live state rather than treating these numbers as permanent active blockers.

## Non-goals

- no rigid project-management scoring bureaucracy;
- no automatic priority derived from reactions/comments alone;
- no subjective priority as a required merge-gate check;
- no mass backfill of every historical Issue;
- no bypass of safety, dependencies, hotspot ownership, migration ownership, or approval policy;
- no claim that the highest-priority Issue must run immediately when it is blocked.

## Re-evaluation

Re-evaluate priority when dependencies clear, a major product gap closes, user evidence changes the dominant friction, or new preservation/security/correctness risk appears. Do not preserve transient branch/PR/CI state in this document.
