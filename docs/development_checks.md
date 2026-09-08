# Development checks

Use the same validation entry points across human and AI-assisted development lanes.

## Fast preflight

```bash
bash tool/check_fast.sh
```

Runs the cheap checks that should be used repeatedly while editing:

- Dart formatting for changed/staged/untracked Dart files;
- maintainability guard tests and regression ceilings;
- feature legacy-dependency guard;
- presentation error-privacy guard.

The format check compares against `origin/main` when available and also includes local staged, unstaged, and untracked Dart files. Override the comparison with `CHECK_BASE_REF=<ref>` or run `bash tool/check_format.sh --all` when a deliberate repository-wide format audit is needed.

For existing tracked Dart files, the normal changed-file check is patch-aware: it temporarily runs `dart format`, maps the pre-format/current line sequence to the formatted line sequence, and fails only when formatter operations actually change PR-added/replaced current lines. Pure deletions introduce no new current lines and therefore do not fail merely because historical formatter debt surrounds the deletion point. Formatter drift elsewhere in the same file is preserved rather than forcing unrelated churn into a focused PR. New/untracked files, renamed paths that do not exist at the selected base, an unavailable base, and explicit `--all` checks remain conservative whole-file formatting checks. The guard restores every inspected file after comparison and `dart format` remains the sole formatting authority.

The line mapping uses exact line-sequence matching with automatic junk suppression disabled. Formatter insertions immediately adjacent to edited lines are treated conservatively as affecting the edit. CI exercises the comparator and a temporary-repository integration regression before checking the repository diff. Those regressions cover a formatted edit inside a historically unformatted file, a pure deletion beside formatter debt, a genuinely unformatted edited hunk, and newly added Dart files.

## Full gate

```bash
bash tool/check_full.sh
```

Runs `check_fast` first, then:

1. `flutter pub get`;
2. fresh Drift generation;
3. `flutter analyze`;
4. the complete Flutter Test suite with the repository's 2-minute per-test timeout.

This is the local equivalent of the authoritative runtime/configuration merge gate. Do not replace it with changed-files-only testing for final validation.

## Pull-request CI paths

Flutter CI classifies the **complete pull-request diff**, not only the latest commit.

- A PR qualifies for the docs-only fast path only when every changed path matches `docs/**/*.md`.
- Mixed docs + code/tool/workflow/config PRs always use the full Flutter gate.
- Pushes to `main` and manual workflow runs always use the full gate.
- Docs-only PRs run a cheap complete-diff classification plus `git diff --check`; they intentionally skip Flutter setup, Drift generation, Analyze, and full Flutter Test.
- `merge-gate` is the stable aggregate status for both paths. Future branch protection should require this stable check rather than shard-count-specific job names.

The classifier is deliberately fail-closed: if the complete PR diff cannot be determined, CI does not silently grant the fast path.

## AI PR coordination contract

The pull-request template begins with five machine-readable coordination fields:

- `Primary lane: A|B|C|D|E|F|G`
- `Related issue: #...`
- `Depends on: none` or explicit `#...` dependencies
- `Shared hotspots: none` or comma-separated AGENTS.md hotspot paths
- `Migration/data impact: yes|no`

On pull requests, the cheap `ci-scope` job audits these fields before Flutter setup. The audit is advisory initially and surfaces:

- missing/invalid lane metadata or a lane that contradicts the normal branch prefix;
- runtime/configuration work without a related Issue;
- declared dependencies that are still open;
- declared hotspot metadata that does not match the actual complete PR diff;
- PR-specific GitHub Actions workflows that combine `contents: write` with a branch `git push` pattern.

Docs-only handoff PRs may omit a related Issue, but they still declare a primary lane, hotspot state, dependencies, and migration/data impact. Formatting/fixups belong in the implementation environment; repository CI should validate autonomous branches rather than mutate them.

## Durable AI handoffs

GitHub Issues, pull requests, commits, and CI remain the live source of truth. Lane `docs/AI_PROGRESS*.md` files are durable resumable checkpoints rather than a second live dashboard. See [`ai_handoff_policy.md`](ai_handoff_policy.md) for the durable schema and supersede rules.

The lightweight `AI Handoff Audit` workflow is advisory and runs independently of the Flutter matrix. When a pull request changes a durable handoff file it warns if:

- another open PR changes the same handoff file;
- the same handoff file changed on `main` after the branch diverged;
- the handoff branch is materially behind `main` (initially 20 commits).

Prefer carrying a known durable handoff update in the same implementation PR. A separate post-merge handoff should contain only facts that genuinely depended on merge/CI completion. Volatile statements such as “no open PRs”, “CI is running”, or “this PR is the only current hotspot owner” must not be preserved as timeless truth; re-read live GitHub state on every implementation run.

When a handoff warning identifies a stale or competing checkpoint, choose the newer authoritative checkpoint and close/supersede the stale PR rather than merging snapshots in sequence.

## CI coordination and test-health diagnostics

Flutter CI also provides non-product coordination/diagnostic signals for the multi-lane workflow:

- **Shared hotspot audit:** on pull requests, compare the current PR with other open PRs and warn when both touch the same AGENTS.md shared hotspot. It also warns when a touched hotspot changed on `main` after branch divergence or when the PR's hotspot diff exceeds the configured changed-line threshold. These warnings are advisory: a patch-sized proven non-overlapping hunk can still proceed after a manual behavior/region audit.
- **Shard health summary:** persist each full-test shard's elapsed time, then report average, longest shard, and max/average skew after the matrix completes. The initial warning thresholds are `1.25x` skew or `360s` for the longest shard.
- **Flake diagnosis:** if a shard fails, rerun that same complete shard once. A fail-then-pass result is recorded as flaky, but the original first-pass failure still keeps the merge gate red.

These diagnostics must not be used to remove tests from the required merge gate or to silently accept flaky failures.

## Suggested use

- During a coherent implementation slice: run `check_fast` whenever practical.
- Before opening/updating a runtime PR: run `check_full` when the local environment supports Flutter.
- If local Flutter execution is unavailable, record that explicitly in the PR and rely on GitHub Flutter CI.
- Treat a shared-hotspot warning as a prompt to re-audit open PR ownership and overlapping behavior, not as proof that the PRs necessarily conflict.
- Treat lane/dependency/metadata warnings as coordination debt to resolve before merge rather than as reasons to add exceptions casually.
- Treat durable-handoff warnings as a prompt to refresh or supersede the checkpoint before merge.
- Investigate persistent shard-skew or flake warnings as developer-loop debt rather than increasing thresholds reflexively.
- CI reruns should use GitHub's rerun mechanism; never create no-op commits merely to trigger checks.
