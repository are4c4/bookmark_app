# Feature presentation error privacy

Canonical feature presentation under `lib/features/**/presentation/` must not turn raw caught exceptions into interpolated strings.

This is a regression boundary, not a blanket ban on exception handling. Code may still:

- catch an error and map it to a stable user-safe message;
- forward the typed error through a callback such as `onError(error)`;
- emit privacy-safe diagnostics that do not interpolate exception text;
- use raw strings or escaped dollar signs when they are literal text rather than Dart interpolation.

`tool/feature_presentation_error_privacy_guard.sh` scans catch bodies in canonical feature presentation and fails when the caught variable is interpolated as `$error`, `${error...}`, or the equivalent for another catch variable.

Legacy `lib/views/` / `lib/widgets/` still contain Issue #225 debt, but that debt is now frozen to an explicit host allowlist rather than left unguarded. Raw caught-error interpolation may temporarily remain only in these existing hosts:

- `lib/views/app_shell.dart`;
- `lib/views/bookmark_unified_stage1_page.dart`;
- `lib/views/generic_database_page.dart`;
- `lib/views/image_editor_page.dart`;
- `lib/views/object_inspector_page.dart`;
- `lib/views/photo_management_page.dart`;
- `lib/views/tag_management_page.dart`;
- `lib/widgets/bookmark_detail_panel.dart`.

The guard fails if the pattern spreads to another legacy presentation host. It also fails when an existing allowlisted file is cleaned but left on the allowlist, forcing the boundary to ratchet smaller in the same change. This deliberately avoids rewriting large shared hosts just to satisfy the policy while ensuring new legacy presentation code cannot repeat the debt.

The guard is wired into Flutter CI and has isolated fixture coverage in `tool/feature_presentation_error_privacy_guard_test.sh` for canonical rejection, safe forwarding/escaping, legacy no-spread behavior, and stale-allowlist ratcheting.

Legacy raw-error surfaces remain Issue #225 cleanup candidates. Migrate them only as focused, independently tested slices with current ownership checks; do not rewrite shared hotspots simply to satisfy this policy.
