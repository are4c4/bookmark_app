#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/tool/maintainability_report.sh"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/bookmark-maintainability-test.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

mkdir -p "$fixture/lib/views" "$fixture/lib/widgets" "$fixture/test"
cat > "$fixture/lib/views/example_page.dart" <<'EOF'
import '../widgets/database_view_tabs.dart';
final first = repository.workspaceStore.database;
final second = repository.workspaceStore.database;
EOF
cat > "$fixture/lib/widgets/example_widget.dart" <<'EOF'
import 'detail_property_row.dart';
final database = repository.workspaceStore.database;
EOF
cat > "$fixture/test/example_test.dart" <<'EOF'
import 'package:bookmark_app/widgets/database_create_tiles.dart';
void main() {}
EOF

output="$(
  cd "$fixture" &&
    bash "$script" --top 1 --max-boundary-refs 3 --max-legacy-shim-imports 3
)"
grep -Fq '3 workspaceStore.database reference(s) across 2 file(s)' <<<"$output"
grep -Fq 'Boundary regression threshold: 3 reference(s) maximum' <<<"$output"
grep -Fq '3 legacy shim import(s) across 3 file(s)' <<<"$output"
grep -Fq 'Legacy shim import regression threshold: 3 import(s) maximum' <<<"$output"

set +e
boundary_failure="$(
  cd "$fixture" &&
    bash "$script" --max-boundary-refs 2 --max-legacy-shim-imports 3 2>&1
)"
boundary_status=$?
set -e

if [[ "$boundary_status" -ne 1 ]]; then
  echo "Expected boundary threshold breach to exit 1, got $boundary_status" >&2
  exit 1
fi
grep -Fq 'Maintainability regression: 3 presentation database reach-through references exceed maximum 2.' <<<"$boundary_failure"

set +e
shim_failure="$(
  cd "$fixture" &&
    bash "$script" --max-boundary-refs 3 --max-legacy-shim-imports 2 2>&1
)"
shim_status=$?
set -e

if [[ "$shim_status" -ne 1 ]]; then
  echo "Expected legacy shim threshold breach to exit 1, got $shim_status" >&2
  exit 1
fi
grep -Fq 'Maintainability regression: 3 legacy Database presentation shim imports exceed maximum 2.' <<<"$shim_failure"

echo "maintainability_report_test: PASS"