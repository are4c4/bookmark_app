#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

check_all=false
base_ref="${CHECK_BASE_REF:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      check_all=true
      shift
      ;;
    --base)
      if [[ $# -lt 2 ]]; then
        echo "check_format: --base requires a ref" >&2
        exit 2
      fi
      base_ref="$2"
      shift 2
      ;;
    -h|--help)
      cat <<'EOF'
Usage: bash tool/check_format.sh [--all] [--base <git-ref>]

By default, checks Dart files changed from a sensible local base plus staged,
unstaged, and untracked Dart files. Existing files are checked only for
formatter differences that overlap lines changed since the merge base, so
pre-existing formatting debt elsewhere in a touched file does not force broad
churn. New files are always checked in full.

Set CHECK_BASE_REF or pass --base to make the comparison explicit. --all checks
every tracked Dart file in full.
EOF
      exit 0
      ;;
    *)
      echo "check_format: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if ! command -v dart >/dev/null 2>&1; then
  echo "check_format: dart is required (install Flutter/Dart first)" >&2
  exit 127
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "check_format: python3 is required for hunk-aware formatting checks" >&2
  exit 127
fi

work_tmp="$(mktemp -d)"
files_tmp="$work_tmp/files"
trap 'rm -rf "$work_tmp"' EXIT
: >"$files_tmp"

base_available=false
comparison_base=""

if [[ "$check_all" == true ]]; then
  git ls-files '*.dart' >"$files_tmp"
else
  if [[ -z "$base_ref" ]]; then
    if git rev-parse --verify --quiet 'origin/main^{commit}' >/dev/null; then
      base_ref='origin/main'
    elif git rev-parse --verify --quiet 'main^{commit}' >/dev/null \
      && [[ "$(git rev-parse HEAD)" != "$(git rev-parse main)" ]]; then
      base_ref='main'
    elif git rev-parse --verify --quiet 'HEAD^1^{commit}' >/dev/null; then
      base_ref='HEAD^1'
    fi
  fi

  if [[ -n "$base_ref" ]]; then
    if git rev-parse --verify --quiet "${base_ref}^{commit}" >/dev/null; then
      base_available=true
      comparison_base="$(git merge-base "$base_ref" HEAD)"
      git diff --name-only --diff-filter=ACMR "${comparison_base}...HEAD" -- '*.dart' >>"$files_tmp"
    else
      echo "check_format: base ref '$base_ref' is unavailable; checking working-tree Dart changes in full" >&2
    fi
  fi

  git diff --name-only --diff-filter=ACMR -- '*.dart' >>"$files_tmp"
  git diff --cached --name-only --diff-filter=ACMR -- '*.dart' >>"$files_tmp"
  git ls-files --others --exclude-standard -- '*.dart' >>"$files_tmp"
fi

# macOS still ships Bash 3.2, so avoid mapfile/associative arrays here.
files=()
while IFS= read -r file; do
  [[ -n "$file" && -f "$file" ]] || continue
  duplicate=false
  for existing in "${files[@]:-}"; do
    if [[ "$existing" == "$file" ]]; then
      duplicate=true
      break
    fi
  done
  if [[ "$duplicate" == false ]]; then
    files+=("$file")
  fi
done < <(sort -u "$files_tmp")

if [[ ${#files[@]} -eq 0 ]]; then
  echo "check_format: no Dart files to check"
  exit 0
fi

echo "check_format: checking ${#files[@]} Dart file(s)"
failed=false
ignored_legacy_drift=0
index=0

for file in "${files[@]}"; do
  index=$((index + 1))
  file_tmp="$work_tmp/file-$index"
  mkdir -p "$file_tmp"
  current="$file_tmp/current.dart"
  formatted="$file_tmp/formatted.dart"
  changed_diff="$file_tmp/changed.diff"
  format_diff="$file_tmp/format.diff"

  cp "$file" "$current"
  cp "$file" "$formatted"

  if ! dart format "$formatted" >/dev/null 2>"$file_tmp/format-error.txt"; then
    echo "check_format: dart format could not parse '$file'" >&2
    cat "$file_tmp/format-error.txt" >&2 || true
    failed=true
    continue
  fi

  if cmp -s "$current" "$formatted"; then
    continue
  fi

  full_file_check=false
  if [[ "$check_all" == true || "$base_available" != true || -z "$comparison_base" ]]; then
    full_file_check=true
  elif ! git cat-file -e "${comparison_base}:${file}" 2>/dev/null; then
    # New/untracked files have no historical formatting debt to preserve.
    full_file_check=true
  fi

  if [[ "$full_file_check" == true ]]; then
    echo
    echo "check_format: '$file' is not dart-format compliant (full-file check)" >&2
    diff -u --label "a/$file" --label "b/$file (dart format)" "$current" "$formatted" || true
    failed=true
    continue
  fi

  # Compare the merge-base version directly with the current working tree so
  # committed, staged, and unstaged changes are all part of the changed-line
  # contract. Zero context prevents historical neighboring formatter debt from
  # being mistaken for this PR's edit.
  git diff --unified=0 --no-ext-diff "$comparison_base" -- "$file" >"$changed_diff" || true
  diff -U0 "$current" "$formatted" >"$format_diff" || true

  set +e
  python3 tool/check_format_hunks.py \
    --changed-diff "$changed_diff" \
    --format-diff "$format_diff"
  overlap_status=$?
  set -e

  if [[ $overlap_status -eq 0 ]]; then
    ignored_legacy_drift=$((ignored_legacy_drift + 1))
    echo "check_format: '$file' has pre-existing formatter drift outside this change; changed hunks are compliant"
    continue
  fi

  echo
  echo "check_format: '$file' needs dart format in lines changed by this work" >&2
  diff -u --label "a/$file" --label "b/$file (dart format)" "$current" "$formatted" || true
  failed=true
done

if [[ $ignored_legacy_drift -gt 0 ]]; then
  echo "check_format: tolerated pre-existing formatter drift in $ignored_legacy_drift touched file(s); do not add unrelated format churn to this PR"
fi

if [[ "$failed" == true ]]; then
  exit 1
fi
