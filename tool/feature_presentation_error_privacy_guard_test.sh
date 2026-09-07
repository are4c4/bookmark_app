#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/tool/feature_presentation_error_privacy_guard.sh"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/bookmark-feature-error-privacy-test.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

mkdir -p \
  "$fixture/lib/features/object/presentation/widgets" \
  "$fixture/lib/features/object/application"

cat > "$fixture/lib/features/object/presentation/widgets/safe_forwarding.dart" <<'EOF'
Future<void> runSafe(void Function(Object error) onError) async {
  try {
    throw StateError('private-value');
  } catch (error) {
    onError(error);
    final rawExample = r'$error';
    // '$error' in a comment is not rendered.
    if (rawExample.isEmpty) return;
  }
}
EOF

cat > "$fixture/lib/features/object/application/outside_presentation.dart" <<'EOF'
Future<void> applicationBoundary() async {
  try {
    throw StateError('application-only');
  } catch (error) {
    final diagnostic = 'application: $error';
    if (diagnostic.isEmpty) return;
  }
}
EOF

output="$(cd "$fixture" && bash "$script")"
grep -Fq 'feature_presentation_error_privacy_guard: PASS' <<<"$output"

cat > "$fixture/lib/features/object/presentation/widgets/unsafe_simple.dart" <<'EOF'
Future<void> runUnsafe() async {
  try {
    throw StateError('secret-path');
  } catch (error) {
    if (DateTime.now().microsecondsSinceEpoch > 0) {
      final message = 'Could not save: $error';
      if (message.isEmpty) return;
    }
  }
}
EOF

set +e
simple_failure="$(cd "$fixture" && bash "$script" 2>&1)"
simple_status=$?
set -e

if [[ "$simple_status" -ne 1 ]]; then
  echo "Expected direct caught-error interpolation to exit 1, got $simple_status" >&2
  exit 1
fi
grep -Fq 'Caught exception interpolation detected under canonical feature presentation:' <<<"$simple_failure"
grep -Fq "unsafe_simple.dart" <<<"$simple_failure"
grep -Fq "caught variable 'error' is interpolated into a string" <<<"$simple_failure"
rm "$fixture/lib/features/object/presentation/widgets/unsafe_simple.dart"

cat > "$fixture/lib/features/object/presentation/widgets/unsafe_braced.dart" <<'EOF'
Future<void> runUnsafeBraced() async {
  try {
    throw FormatException('secret-value');
  } catch (exception, stackTrace) {
    final message = 'Could not decode: ${exception.runtimeType}';
    if (message.isEmpty || stackTrace.toString().isEmpty) return;
  }
}
EOF

set +e
braced_failure="$(cd "$fixture" && bash "$script" 2>&1)"
braced_status=$?
set -e

if [[ "$braced_status" -ne 1 ]]; then
  echo "Expected braced caught-error interpolation to exit 1, got $braced_status" >&2
  exit 1
fi
grep -Fq 'unsafe_braced.dart' <<<"$braced_failure"
grep -Fq "caught variable 'exception' is interpolated into a string" <<<"$braced_failure"

echo "feature_presentation_error_privacy_guard_test: PASS"
