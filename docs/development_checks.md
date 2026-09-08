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

## Suggested use

- During a coherent implementation slice: run `check_fast` whenever practical.
- Before opening/updating a runtime PR: run `check_full` when the local environment supports Flutter.
- If local Flutter execution is unavailable, record that explicitly in the PR and rely on GitHub Flutter CI.
- CI reruns should use GitHub's rerun mechanism; never create no-op commits merely to trigger checks.
