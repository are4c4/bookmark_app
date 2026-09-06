#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/tool/maintainability_report.sh"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/bookmark-maintainability-test.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

mkdir -p "$fixture/lib/views" "$fixture/lib/widgets" "$fixture/test"
cat > "$fixture/lib/views/example_page.dart" <<'EOF'
final first = repository.workspaceStore.database;
final second = repository.workspaceStore.database;
EOF
cat > "$fixture/lib/widgets/example_widget.dart" <<'EOF'
final database = repository.workspaceStore.database;
EOF
cat > "$fixture/test/example_test.dart" <<'EOF'
void main() {}
EOF

output="$(cd "$fixture" && bash "$script" --top 1 --max-boundary-refs 3)"
grep -Fq '3 workspaceStore.database reference(s) across 2 file(s)' <<<"$output"
grep -Fq 'Boundary regression threshold: 3 reference(s) maximum' <<<"$output"

set +e
failure_output="$(cd "$fixture" && bash "$script" --max-boundary-refs 2 2>&1)"
status=$?
set -e

if [[ "$status" -ne 1 ]]; then
  echo "Expected threshold breach to exit 1, got $status" >&2
  exit 1
fi
grep -Fq 'Maintainability regression: 3 presentation database reach-through references exceed maximum 2.' <<<"$failure_output"

echo "maintainability_report_test: PASS"
