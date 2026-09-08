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

## Full gate

```bash
bash tool/check_full.sh
```

Runs `check_fast` first, then:

1. `flutter pub get`;
2. fresh Drift generation;
3. `flutter analyze`;
4. the complete Flutter Test suite with the repository's 2-minute per-test timeout.

This is the local equivalent of the authoritative merge gate. Do not replace it with changed-files-only testing for final validation.

## CI coordination and test-health diagnostics

Flutter CI also provides non-product coordination/diagnostic signals for the multi-lane workflow:

- **Shared hotspot audit:** on pull requests, compare the current PR with other open PRs and warn when both touch the same AGENTS.md shared hotspot. This is deliberately advisory: a patch-sized non-overlapping hunk can still proceed after a manual behavior/region audit.
- **Shard health summary:** persist each full-test shard's elapsed time, then report average, longest shard, and max/average skew after the matrix completes. The initial warning thresholds are `1.25x` skew or `360s` for the longest shard.
- **Flake diagnosis:** if a shard fails, rerun that same complete shard once. A fail-then-pass result is recorded as flaky, but the original first-pass failure still keeps the merge gate red.

These diagnostics must not be used to remove tests from the required merge gate or to silently accept flaky failures.

## Suggested use

- During a coherent implementation slice: run `check_fast` whenever practical.
- Before opening/updating a runtime PR: run `check_full` when the local environment supports Flutter.
- If local Flutter execution is unavailable, record that explicitly in the PR and rely on GitHub Flutter CI.
- Treat a shared-hotspot warning as a prompt to re-audit open PR ownership and overlapping behavior, not as proof that the PRs necessarily conflict.
- Investigate persistent shard-skew or flake warnings as developer-loop debt rather than increasing thresholds reflexively.
- CI reruns should use GitHub's rerun mechanism; never create no-op commits merely to trigger checks.
