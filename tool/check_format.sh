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
unstaged, and untracked Dart files. Set CHECK_BASE_REF or pass --base to make
the comparison explicit. --all checks every tracked Dart file.
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

files_tmp="$(mktemp)"
trap 'rm -f "$files_tmp"' EXIT

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
      echo "check_format: base ref '$base_ref' is unavailable; checking working-tree Dart changes only" >&2
    fi
  fi

  git diff --name-only --diff-filter=ACMR -- '*.dart' >>"$files_tmp"
  git diff --cached --name-only --diff-filter=ACMR -- '*.dart' >>"$files_tmp"
  git ls-files --others --exclude-standard -- '*.dart' >>"$files_tmp"
fi

mapfile_cmd_available=false
if builtin help mapfile >/dev/null 2>&1; then
  mapfile_cmd_available=true
fi

# macOS still ships Bash 3.2, so avoid relying on mapfile there.
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
dart format --output=none --set-exit-if-changed "${files[@]}"
