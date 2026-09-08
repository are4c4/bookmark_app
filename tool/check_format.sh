#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
unstaged, and untracked Dart files. Existing tracked files are checked only
where `dart format` changes overlap edited lines, so historical formatter debt
outside the patch does not force unrelated churn. New/untracked files and
--all remain whole-file checks.
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

tmp_dir="$(mktemp -d)"
files_tmp="$tmp_dir/files"
trap 'rm -rf "$tmp_dir"' EXIT

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
      git diff --name-only --diff-filter=ACMR "${base_ref}...HEAD" -- '*.dart' >>"$files_tmp"
    else
      echo "check_format: base ref '$base_ref' is unavailable; checking working-tree Dart changes as whole files" >&2
      base_ref=''
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
index=0

for file in "${files[@]}"; do
  index=$((index + 1))
  original="$tmp_dir/original-$index.dart"
  source_patch="$tmp_dir/source-$index.patch"
  format_patch="$tmp_dir/format-$index.patch"
  format_stderr="$tmp_dir/format-$index.stderr"
  cp "$file" "$original"

  whole_file="$check_all"
  if [[ "$whole_file" != true ]]; then
    if [[ -z "$base_ref" ]] \
      || ! git ls-files --error-unmatch "$file" >/dev/null 2>&1 \
      || ! git cat-file -e "${base_ref}:${file}" 2>/dev/null; then
      whole_file=true
    else
      git diff --unified=0 "$base_ref" -- "$file" >"$source_patch"
    fi
  fi

  set +e
  dart format "$file" >/dev/null 2>"$format_stderr"
  format_status=$?
  set -e

  if [[ $format_status -ne 0 ]]; then
    cat "$original" >"$file"
    echo "check_format: dart format failed for $file" >&2
    cat "$format_stderr" >&2
    failed=true
    continue
  fi

  set +e
  git diff --no-index --unified=0 -- "$original" "$file" >"$format_patch"
  diff_status=$?
  set -e
  cat "$original" >"$file"

  if [[ $diff_status -gt 1 ]]; then
    echo "check_format: could not inspect formatter diff for $file" >&2
    failed=true
    continue
  fi
  if [[ ! -s "$format_patch" ]]; then
    continue
  fi

  if [[ "$whole_file" == true ]]; then
    echo "check_format: $file requires dart format (whole-file check)" >&2
    cat "$format_patch" >&2
    failed=true
    continue
  fi

  set +e
  python3 "$script_dir/check_format_hunks.py" \
    --source-diff "$source_patch" \
    --format-diff "$format_patch" \
    --path "$file"
  hunk_status=$?
  set -e

  if [[ $hunk_status -eq 1 ]]; then
    failed=true
  elif [[ $hunk_status -ne 0 ]]; then
    echo "check_format: hunk comparison failed for $file" >&2
    failed=true
  fi
done

if [[ "$failed" == true ]]; then
  exit 1
fi
