# Product Acceptance Evidence

User-facing focused work is not product-complete merely because code exists and required CI is green.

Where the change materially affects normal UI or interaction, the completion direction is:

```text
implementation + tests + real-host/product evidence + focused-Issue acceptance match
```

This contract is an **advisory first rollout**. It improves review evidence without turning subjective visual judgment into a required merge gate.

## When it applies

`Product Acceptance Evidence` inspects the effective current-base PR landing diff rather than trusting a manually applied label.

The conservative classifier treats production paths such as these as likely user-facing UI:

- `lib/main.dart`;
- `lib/ui/**`;
- `lib/views/**`;
- `lib/widgets/**`;
- `lib/features/**/presentation/**`;
- feature files whose basename is a common UI surface such as `*_page.dart`, `*_screen.dart`, `*_dialog.dart`, `*_view.dart`, `*_widget.dart`, `*_panel.dart`, `*_toolbar.dart`, or `*_picker.dart`.

This is intentionally a conservative heuristic, not a semantic proof. H/reviewers may request Product Acceptance Evidence when behavior is visibly user-facing even if the path heuristic misses it.

Documentation-only, backend-only, persistence-only, invisible correctness, pure refactor, and test-only PRs are not required to fabricate screenshots or interaction evidence.

Writing `n/a` in the PR body does not override a UI classification produced from the actual diff.

## PR evidence format

The repository PR template carries this section:

```text
## Product acceptance evidence
- Real host / user scenario:
- Interaction evidence:
- Visual evidence:
- Keyboard / focus: n/a
- Empty / loading / error: n/a
- Shared-host consistency: n/a
- Acceptance criterion:
```

For a likely user-facing UI PR, advisory completeness currently requires:

1. a concrete **Real host / user scenario**;
2. the focused-Issue **Acceptance criterion** being demonstrated;
3. at least one of **Interaction evidence** or **Visual evidence**.

The remaining fields are contextual. Use them when the changed behavior makes them relevant; `n/a` is acceptable when they genuinely do not apply.

Keep the evidence concise. A normal UI PR should not need a prose essay.

## What counts as useful evidence

### Real host / user scenario

Name the actual application surface and task, not only the helper/class under test.

Good examples:

- `Database List / add Relation filter and choose a Person`;
- `Object Inspector / edit Body and save`;
- `Global Search / zero-result empty state`.

### Interaction evidence

Use evidence that demonstrates the changed path, for example:

- a real-host widget regression covering click -> edit -> save;
- a picker test covering keyboard selection and dismissal;
- a concrete manual click/key sequence when automated evidence is not practical.

Tests remain authoritative for deterministic behavior. Screenshot evidence does not replace interaction/correctness tests.

### Visual evidence

When visual behavior changes, prefer provenance-linked repository evidence from the advisory UI Audit when its scenario covers the affected surface.

For a UI Audit artifact, verify:

- its manifest / `machine-summary.json` source SHA;
- scenario status and profile;
- that the screenshot is present and non-empty;
- that the artifact actually represents the state being reviewed.

For pull-request UI Audit runs, the artifact is tied to GitHub's tested synthetic merge/current-base state. For `main` runs, it is tied to the integrated main commit.

A manually supplied screenshot is still useful when no repository scenario covers the surface, but it should identify the host/scenario and the code state it represents.

**Never auto-accept a changed golden/screenshot merely because the implementation PR supplied it.** A visual change still has to match the focused Issue/product intent.

### Keyboard / focus and state evidence

Record these when relevant to the changed interaction:

- Tab/arrow/Enter/Escape behavior;
- focus restoration or focus-visible behavior;
- empty/loading/error/recovery state;
- shared-host consistency when one generic surface appears in multiple hosts.

## Advisory automation

The `Product Acceptance Evidence` GitHub Actions workflow:

- verifies the evidence-classifier regression suite;
- derives the effective current-base landing diff;
- classifies likely user-facing production UI from the actual changed paths;
- summarizes the exact PR head and classified UI paths;
- surfaces missing minimum evidence with a GitHub warning and step summary;
- succeeds for evidence omissions during this first rollout so subjective review does not become part of required `merge-gate`.

Classifier/diff failures themselves fail the advisory job rather than silently pretending the PR is non-UI.

A later change may promote a deterministic omission to a blocking contract only through a separate evidence-backed decision after the advisory signal proves stable and low-noise.

## H / reviewer contract

For a likely user-facing PR:

1. inspect the advisory Product Acceptance Evidence summary;
2. confirm the evidence belongs to the current PR/head or tested synthetic merge;
3. verify that the named real host/scenario exercises the behavior users actually see;
4. verify the focused-Issue acceptance criterion is specifically demonstrated;
5. use source-SHA-bound UI Audit evidence where it materially helps, while remembering that `evidenceStatus: complete` means evidence completeness, not product approval;
6. treat missing evidence as review debt to resolve before declaring the focused product work complete, even though the first-rollout workflow remains non-blocking;
7. do not ask non-UI PRs to manufacture screenshot evidence merely to satisfy a template.

Product Acceptance Evidence is one input to review, not an automatic approval system. Safety, preservation, data integrity, tests, architecture ownership, migration/hotspot policy, and required CI remain independent requirements.

## Non-goals

- no screenshot requirement for every PR;
- no external vision-model/API secret;
- no subjective visual score in `merge-gate`;
- no replacement of behavioral tests with screenshots;
- no automatic approval of changed goldens;
- no schema, migration, or product-persistence change.
