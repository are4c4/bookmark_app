#!/usr/bin/env bash
set -euo pipefail

source_root="$(git rev-parse --show-toplevel)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/repo/tool" "$tmp/repo/lib" "$tmp/fakebin"
cp "$source_root/tool/check_format.sh" "$tmp/repo/tool/check_format.sh"
cp "$source_root/tool/check_format_hunks.py" "$tmp/repo/tool/check_format_hunks.py"

cat >"$tmp/fakebin/dart" <<'EOF'
#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) < 3 or sys.argv[1] != "format":
    raise SystemExit(2)
path = Path(sys.argv[-1])
text = path.read_text(encoding="utf-8")
path.write_text(text.replace("BADFMT", "GOODFMT"), encoding="utf-8")
EOF
chmod +x "$tmp/fakebin/dart"

cd "$tmp/repo"
git init -q
git config user.email format-test@example.invalid
git config user.name format-test

cat >lib/example.dart <<'EOF'
BADFMT legacy debt
stable
value = 1;
EOF
git add lib/example.dart tool/check_format.sh tool/check_format_hunks.py
git commit -qm baseline

# Existing formatter debt on line 1 must not block a compliant edit on line 3.
cat >lib/example.dart <<'EOF'
BADFMT legacy debt
stable
value = 2;
EOF
PATH="$tmp/fakebin:$PATH" CHECK_BASE_REF=HEAD bash tool/check_format.sh \
  >"$tmp/pass.log" 2>&1
if ! grep -q 'pre-existing formatter drift outside this change' "$tmp/pass.log"; then
  echo "check_format_test: expected legacy-drift diagnostic" >&2
  cat "$tmp/pass.log" >&2
  exit 1
fi

# A formatter delta in the newly changed line must still fail.
git checkout -q -- lib/example.dart
cat >lib/example.dart <<'EOF'
BADFMT legacy debt
stable
BADFMT changed line
EOF
if PATH="$tmp/fakebin:$PATH" CHECK_BASE_REF=HEAD bash tool/check_format.sh \
  >"$tmp/fail-hunk.log" 2>&1; then
  echo "check_format_test: expected changed-hunk formatting failure" >&2
  exit 1
fi
if ! grep -q 'needs dart format in lines changed by this work' "$tmp/fail-hunk.log"; then
  echo "check_format_test: changed-hunk failure was not actionable" >&2
  cat "$tmp/fail-hunk.log" >&2
  exit 1
fi

# New files have no legacy debt baseline and therefore remain full-file checked.
git checkout -q -- lib/example.dart
cat >lib/new.dart <<'EOF'
BADFMT new file
EOF
if PATH="$tmp/fakebin:$PATH" CHECK_BASE_REF=HEAD bash tool/check_format.sh \
  >"$tmp/fail-new.log" 2>&1; then
  echo "check_format_test: expected new-file formatting failure" >&2
  exit 1
fi
if ! grep -q 'full-file check' "$tmp/fail-new.log"; then
  echo "check_format_test: new-file failure was not reported as full-file check" >&2
  cat "$tmp/fail-new.log" >&2
  exit 1
fi

echo "check_format_test: OK"
