#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
guard="$script_dir/check_format.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cd "$tmp_dir"
git init -q
git config user.name "Format Guard Test"
git config user.email "format-guard@example.invalid"

cat >sample.dart <<'EOF'
void main() {
  final legacy = <int>[
1,
2,
];
  print('old');
}
EOF

git add sample.dart
git commit -qm "seed pre-existing formatter debt"

cat >sample.dart <<'EOF'
void main() {
  final legacy = <int>[
1,
2,
];
  print('new');
}
EOF

before="$(cat sample.dart)"
CHECK_BASE_REF=HEAD bash "$guard"
after="$(cat sample.dart)"
[[ "$before" == "$after" ]] || {
  echo "check_format_test: guard mutated a passing file" >&2
  exit 1
}

cat >sample.dart <<'EOF'
void main() {
  final legacy = <int>[
1,
2,
];
  print(  'bad'  );
}
EOF

before="$(cat sample.dart)"
if CHECK_BASE_REF=HEAD bash "$guard"; then
  echo "check_format_test: unformatted edited hunk unexpectedly passed" >&2
  exit 1
fi
after="$(cat sample.dart)"
[[ "$before" == "$after" ]] || {
  echo "check_format_test: guard mutated a failing file" >&2
  exit 1
}

git checkout -q -- sample.dart
cat >added.dart <<'EOF'
void added( ){print('new');}
EOF

if CHECK_BASE_REF=HEAD bash "$guard"; then
  echo "check_format_test: unformatted new file unexpectedly passed" >&2
  exit 1
fi

cat >added.dart <<'EOF'
void added() {
  print('new');
}
EOF

CHECK_BASE_REF=HEAD bash "$guard"

echo "check_format_test: PASS"
