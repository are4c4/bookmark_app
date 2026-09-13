# AI Product-Quality Priority

> Repository-wide near-term scheduling guidance for autonomous AI development.
>
> This document records **durable priority intent**, not transient branch/PR/CI state. Every lane must still re-read live GitHub Issues, PR ownership, shared-hotspot leases, dependencies, migration ownership, and current `main` before taking work.

## Why this document exists

The repository has strong code-level safety, CI, migration, ownership, and architecture guardrails. The current product risk is different: technically correct changes can accumulate without a proportional improvement in the app's visible quality or day-to-day usability.

For the near term, autonomous development should therefore optimize not only for safe implementation throughput, but for a closed product-feedback loop:

```text
focused Issue
  -> implementation
  -> tests / CI
  -> real-host or deterministic UI evidence
  -> user-journey/product acceptance
  -> follow-up when friction remains
  -> product-complete
```

A green PR is necessary evidence, but user-facing work is not automatically product-complete merely because code and tests are green.

## Near-term lane priority

### 1. G — autonomous product-feedback infrastructure

G has the highest near-term infrastructure priority because it closes the gap between "code changed" and "the product actually improved".

Primary anchors:
- **#1353** — deterministic UI snapshots / visual-regression audit artifacts;
- **#1367** — Core User Journeys and journey-level acceptance;
- **#1368** — Product Acceptance Evidence for user-facing PRs;
- **#1369** — user-visible impact / frequency / friction priority routing;
- **#1370** — PR-level H Product Review for user-facing changes.

G should prefer these product-feedback-loop foundations over unrelated low-impact cleanup when both are safe and ready. This does **not** override safety work, approval-sensitive guard ownership, migration rules, or a currently owned focused slice that must be completed cleanly first.

### 2. C — high-frequency visible UX

C is the main lane for direct day-to-day usability improvement. After completing any already-owned safe focused slice, C should choose the next ready Issue using the #1369 user-visible priority rubric rather than selecting work only because it is easy or conflict-free.

Current high-value themes include:
- Relation/filter/picker friction;
- Command Palette and navigation/search entry points;
- inline Object title and Property editing;
- responsive Object detail presentation;
- View creation / Database toolbar consistency;
- Property authoring;
- Table interaction;
- keyboard/focus/accessibility through #1361;
- Home / generic daily-use replacement UX where existing umbrellas require it.

Examples of focused anchors include #1343–#1349, #1361, #1061, #1043, #1046 and unfinished #1050 UX slices. Always verify live state and dependencies before ownership.

### 3. A — finish shared Body / Object interaction quality

A should continue high-impact shared Object/Body UX that affects many user journeys, especially the #1337 Body document-surface direction and focused children that remain unfinished.

The goal is not to keep adding Body features indefinitely. The near-term priority is to make the existing shared editor visibly and operationally document-like in the real hosts, with product evidence proving that the change is actually observable.

A's deeper roadmap work such as #1062 merge semantics and #1064 durable history remains important, but safe high-frequency Body friction may take precedence when an active focused Body slice is already underway and independent roadmap work is not a safety blocker.

### H — continuous oversight, not a sequential implementation slot

H should run continuously alongside G/C/A rather than waiting for them in sequence.

Near-term H emphasis:
- product and UX coherence;
- Core User Journey health (#1367);
- Product Acceptance Evidence quality (#1368);
- user-visible priority/routing (#1369);
- PR-level Product Review (#1370) once the supporting artifact flow is available;
- recurring UI/UX artifact review through #1354 after #1353 establishes the artifact contract;
- duplicate Issue avoidance and correct A–G routing for concrete findings.

H remains an oversight/control-tower lane. It does not take runtime product implementation away from A–G.

## Other lanes

B, D, E and F remain important and should run when there is a concrete, ready obligation in their ownership area:

- **B** — Relation/data-integrity correctness and hierarchy integrity;
- **D** — Weblink/Image/File native behavior and media presentation obligations;
- **E** — canonical Search correctness/freshness/ranking/opening and focused Search UX;
- **F** — Vault/storage/preservation/export/delivery/diagnostics.

Do not manufacture speculative work merely to keep every lane busy. A safety/correctness defect in these lanes may outrank the product-quality ordering above.

## Work-selection rubric

When several independent safe Issues are ready, prefer in roughly this order:

1. safety, preservation, data-integrity or correctness blockers;
2. high-frequency user-visible friction on shared surfaces;
3. blockers or regressions in Core User Journeys;
4. work that closes the autonomous product-feedback loop;
5. lower-frequency feature polish;
6. internal cleanup/refactor that does not currently unlock product or safety value.

For product/UX work, consider:
- **impact** — high / medium / low;
- **frequency** — daily / frequent / occasional / rare;
- **friction** — severe / moderate / minor;
- **breadth** — one niche host vs shared cross-product surface;
- **readiness** — ready vs blocked by dependency/hotspot/migration ownership.

Avoid fake numerical precision. The rubric is advisory prioritization, not a CI score.

## Product Definition of Done

For materially user-facing work, prefer this completion model where applicable:

```text
implementation
+ focused tests
+ authoritative CI
+ real-host / provenance-linked UI evidence
+ keyboard/focus/empty/error checks where relevant
+ affected user-journey check
+ acceptance criteria visibly satisfied
= product-complete
```

If evidence is unavailable, say so. Do not infer that a UI improved merely because internal code changed.

## Scheduling rules

- Finish an already-owned coherent safe slice before abandoning it solely because another lane has higher priority.
- Do not bypass shared-hotspot ownership, dependencies, migration single-writer, or destructive-approval rules to satisfy this priority order.
- Do not interpret this document as a claim that any listed Issue currently has no owner; query live GitHub.
- H may recommend reordering ready work, but product implementation remains with exactly one A–G primary lane per focused Issue.
- Do not create duplicate Issues merely to encode priority; refine/link existing focused Issues where possible.

## Re-evaluation triggers

H/G should re-evaluate this near-term ordering when one of these materially changes:
- #1353/#1367–#1370 establish a working autonomous product-acceptance loop;
- the major visible UX backlog is substantially reduced;
- a new preservation/security/correctness blocker emerges;
- an architecture dependency makes a different lane the critical path;
- user feedback shows a different daily workflow is the dominant source of friction.

Live GitHub remains authoritative for current ownership and completion state. This document describes **what kind of work should win when multiple safe choices exist**.
