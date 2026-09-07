# Feature presentation error privacy

Canonical feature presentation under `lib/features/**/presentation/` must not turn raw caught exceptions into interpolated strings.

This is a regression boundary, not a blanket ban on exception handling. Code may still:

- catch an error and map it to a stable user-safe message;
- forward the typed error through a callback such as `onError(error)`;
- emit privacy-safe diagnostics that do not interpolate exception text;
- use raw strings or escaped dollar signs when they are literal text rather than Dart interpolation.

`tool/feature_presentation_error_privacy_guard.sh` scans catch bodies in canonical feature presentation and fails when the caught variable is interpolated as `$error`, `${error...}`, or the equivalent for another catch variable. It intentionally does not scan legacy `lib/views/` / `lib/widgets/` so existing debt does not block unrelated work.

The guard is wired into Flutter CI and has an isolated fixture regression in `tool/feature_presentation_error_privacy_guard_test.sh`.

Legacy raw-error surfaces remain Issue #225 cleanup candidates. Migrate them only as focused, independently tested slices with current ownership checks; do not rewrite shared hotspots simply to satisfy this policy.
