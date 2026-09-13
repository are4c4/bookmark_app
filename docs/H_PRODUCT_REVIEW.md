# H PR-level Product Review

This contract defines the advisory H-lane product review for pull requests that materially change normal user-facing behavior or presentation.

It reuses the Product Acceptance Evidence classification and evidence from `docs/PRODUCT_ACCEPTANCE_EVIDENCE.md`. It does **not** create a second label, classifier, approval authority, or merge gate.

## When H reviews a PR

Use the repository's existing Product Acceptance Evidence result as the default applicability signal:

- `required=true` / a likely user-facing production UI diff: H should perform PR-level product review before the focused work is called product-complete;
- `not-required`: no product review is required merely to satisfy process, unless H can point to actual user-visible behavior that the conservative path classifier missed;
- docs-only, test-only, invisible refactor/backend correctness and persistence-only work must not fabricate UI review evidence.

The classifier is a routing heuristic, not a product truth source. H may request review evidence for a real user-facing change that the path heuristic misses, but must explain the concrete surface/behavior rather than adding a new manual bypass/label authority.

## Review inputs

For an applicable PR, H should inspect the smallest relevant set of live evidence:

1. the focused Issue acceptance criteria and non-goals;
2. the PR's Product Acceptance Evidence and exact current head SHA;
3. interaction tests or real-host runtime evidence for the changed path;
4. source-SHA-bound UI Audit screenshots / `machine-summary.json` / `h-review-input.md` when the representative scenario is relevant;
5. affected Core User Journeys when `docs/CORE_USER_JOURNEYS.md` or later journey coverage exists;
6. current related Issues so a known finding is not duplicated;
7. shared-host parity such as Side Peek / full page / Database / picker variants where the changed surface is reused.

Do not infer persistence, accessibility, keyboard semantics, error recovery, or data correctness from screenshots when those claims require code/tests/runtime evidence.

## Review questions

H asks only questions material to the focused change:

- Is the user-visible change observable in the intended real host?
- Does it satisfy the focused Issue's user-facing acceptance rather than only changing internals?
- Does the supplied interaction/visual evidence belong to the current PR head or tested synthetic merge state?
- Are equivalent shared hosts unintentionally inconsistent?
- Are keyboard/focus and empty/loading/error/recovery states coherent when relevant?
- Did a legacy compatibility path remain the primary UX even though the Issue claims replacement?
- Is there a concrete clipping/overflow/internal-metadata/layout/control problem rather than only a stylistic preference?
- Does the affected user journey become better or at least not regress?

## Outcome model

Record exactly one of these advisory outcomes:

- `product-evidence-sufficient` — the available evidence supports the focused product acceptance and no new actionable product gap was found;
- `follow-up-required` — a concrete reproducible gap exists; reuse/refine a live focused Issue when possible, otherwise route exactly one new focused Issue to one A–G implementation lane;
- `needs-human-confirmation` — the observation is subjective, ambiguous, or requires a product decision; do not turn it into a blocking AI aesthetic preference;
- `evidence-unavailable` — required product evidence is missing, stale, mismatched to the current head, or otherwise insufficient to claim the UI was reviewed.

`product-evidence-sufficient` is **not** GitHub code approval, destructive-change authorization, security approval, or an automatic merge signal. Existing required CI, preservation, migration, ownership and approval contracts remain independent.

## Durable PR comment format

H records the outcome as a top-level PR conversation comment so the result is visible with the PR but is not copied into long-lived handoff docs.

```text
<!-- h-product-review:v1 -->
## H Product Review
- Reviewed head: `<40-char PR head SHA>`
- Outcome: `product-evidence-sufficient | follow-up-required | needs-human-confirmation | evidence-unavailable`
- Product Acceptance Evidence: `<complete | incomplete | not-required | unavailable>`
- Evidence reviewed: `<focused tests / UI Audit source SHA / real-host scenario / none>`
- Acceptance match: `<concise statement>`
- Cross-surface / journey note: `<concise statement or n/a>`
- Follow-up: `<none | #issue | human decision needed>`
```

The `Reviewed head` is mandatory. Any later PR commit makes the previous H Product Review stale; H must not present the old outcome as current without rechecking the new head.

Do not use a GitHub `APPROVED` review merely to represent this advisory product outcome. In particular, this contract never satisfies destructive-approval requirements such as the distinct write/admin approval path.

## Follow-up routing

For `follow-up-required`:

1. search live Issues first;
2. reuse/refine an existing focused Issue when its acceptance already covers the gap;
3. otherwise create exactly one focused Issue with one primary A–G implementation owner, concrete reproduction/evidence, acceptance, hotspot/migration impact and non-goals;
4. H does not take runtime product hotspot ownership to fix its own finding;
5. the original PR must not be called product-complete until the deterministic gap is resolved or explicitly split/accepted by the appropriate product/Issue owner.

A separate follow-up is not required for purely subjective taste. Use `needs-human-confirmation` instead.

## Missing evidence

When Product Acceptance Evidence is incomplete or stale:

- record `evidence-unavailable` rather than guessing success;
- state exactly what is missing or mismatched;
- keep the first rollout advisory/non-blocking for subjective product judgment;
- continue unrelated H repository/architecture oversight;
- do not request screenshots from non-UI PRs solely to satisfy process.

## Blocking boundary

This first rollout does not add a subjective H Product Review check to required `merge-gate`.

A concrete deterministic violation already covered by the focused Issue/tests may still prevent the work from being considered product-complete, but that is because the acceptance is unmet, not because H assigned an aesthetic score.

Promoting any PR-level product-evidence omission to a blocking CI contract requires a separate evidence-backed G/product decision after the advisory signal proves stable and low-noise.
