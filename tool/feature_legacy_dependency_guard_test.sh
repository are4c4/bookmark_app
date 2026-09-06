#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/tool/feature_legacy_dependency_guard.sh"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/bookmark-feature-legacy-guard-test.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

mkdir -p "$fixture/lib/features/object/presentation"
cat > "$fixture/lib/features/object/presentation/example.dart" <<'EOF'
class ExampleObjectFeature {
  const ExampleObjectFeature();
}
EOF

output="$(cd "$fixture" && bash "$script")"
grep -Fq 'feature_legacy_dependency_guard: PASS' <<<"$output"

cat > "$fixture/lib/features/object/presentation/legacy_example.dart" <<'EOF'
void useLegacy(BookmarkRepository repository, BookmarkItem bookmark) {}
EOF

set +e
failure="$(cd "$fixture" && bash "$script" 2>&1)"
status=$?
set -e

if [[ "$status" -ne 1 ]]; then
  echo "Expected legacy feature dependency to exit 1, got $status" >&2
  exit 1
fi
grep -Fq 'Legacy Bookmark dependency detected under lib/features:' <<<"$failure"
grep -Fq 'BookmarkRepository' <<<"$failure"
grep -Fq 'BookmarkItem' <<<"$failure"

echo "feature_legacy_dependency_guard_test: PASS"
