# Human Approval Runbook

This document is an operator-facing checklist for approval-sensitive pull requests in a solo-maintainer repository.

`AGENTS.md` and Issue #1107 remain the approval-policy authority. This runbook does not create a new approval path, bypass token, or way for automation to self-authorize. It only defines how an AI lane must prepare a PR before asking the human repository administrator to use the existing PR-only ruleset bypass described by #1107/#1331.

## When this runbook applies

Use this runbook only when all of the following are true:

- the PR is approval-sensitive under the repository guard;
- the normal A1 path cannot be satisfied because no distinct trusted write/admin reviewer is available;
- the repository's active protection rules expose the intended human repository-admin bypass path;
- the owning lane has finished every safe machine-executable task it can perform without that bypass.

Routine reversible PRs do not use this flow.

## Final AI-to-human handoff checklist

Before asking the human repository administrator to bypass the red approval-sensitive check, the owning lane must:

1. **Synchronize to current `main`.** Restack/rebase once onto then-current `main` and re-evaluate the landing diff.
2. **Freeze the intended final head.** Record the exact final head SHA that the human decision will apply to.
3. **Complete non-approval validation.** Run every validation that can be performed without the human bypass and record the evidence.
4. **Inspect the final scope.** Confirm the final diff still matches the focused Issue, declared hotspots, migration/data impact, and non-goals.
5. **Refresh the PR body/checklist.** Update the PR description so it reflects the actual final-head state rather than an older checkpoint. Mark machine-executable validation items complete where evidence exists.
6. **Make the remaining action explicit.** The PR body must clearly state that the only remaining integration action is the human repository-admin PR-only ruleset bypass. It must not leave stale unchecked machine tasks that make the handoff ambiguous.
7. **Record the stop reason exactly.** Use:

   `Stop reason: destructive-approval — human repository-admin ruleset action required on final head`

8. **Park the PR without churn.** Do not create no-op commits, self-reviews, dummy reviewer accounts, labels/comments that act as approval tokens, or guard changes intended only to turn the check green.
9. **Continue unrelated safe work.** The owning lane may work on independent non-conflicting Issues while this PR waits for the human action.

Only after these steps are satisfied should the lane tell the human that the PR is ready for the manual repository-admin action.

## What the human action is — and is not

The human action is **not self-approval** in the normal GitHub review sense. A review from the PR author does not satisfy the distinct-reviewer A1 path.

For the solo-maintainer A2 path, the human repository administrator deliberately uses the active branch ruleset's approved PR-only admin bypass on the prepared final head after inspecting the final diff and validation state.

The repository guard may remain red because its independent-review condition is intentionally stricter. The manual bypass is an external repository-protection decision; it must not be reinterpreted as a green guard result.

## Any new commit invalidates the handoff

If any commit lands on the PR after the final handoff was prepared:

- the previously recorded final head is no longer authoritative;
- the human decision must not be reused automatically;
- the owning lane returns to the checklist above;
- latest `main`, the new final diff, non-approval validation, and PR-body/checklist state must be refreshed again before requesting the human action.

This rule also applies to seemingly harmless or no-op commits. Do not churn the branch merely to refresh status.

## After the human integration

After the PR is integrated through the permitted manual path:

- verify the expected commit is on `main`;
- update/close the focused Issue only when its acceptance is actually satisfied;
- release any hotspot/guard ownership held by the PR;
- resume dependent work from latest `main` rather than from the parked branch;
- do not claim that the solo-maintainer bypass solves #1107 Phase B trusted-enforcement-root work.

## Example readiness statement

A concise AI handoff to the human may look like:

> Final head `<sha>` is synchronized to current `main`. All non-approval validation available to automation is complete, the final diff has been rechecked, and the PR body/checklist now reflects that state. The only remaining integration action is the human repository-admin PR-only ruleset bypass. Stop reason: `destructive-approval — human repository-admin ruleset action required on final head`.

If the PR body still contains stale unchecked machine-executable validation items, the PR is **not yet ready** for this message.
