#!/usr/bin/env bash
set -euo pipefail

# Canonical feature presentation must not turn raw caught exceptions into
# user-visible/interpolated strings. Typed forwarding such as onError(error)
# remains valid: this guard targets string interpolation inside the same catch
# body, not the existence of catches or error callbacks themselves.
#
# Legacy presentation still has a small, explicit set of known hosts carrying
# this debt. Those hosts may remain temporarily, but the debt must not spread to
# another lib/views or lib/widgets file. Once a listed host is cleaned while the
# file still exists, this guard also forces removal of its stale allowlist entry.

if [[ ! -d lib/features ]]; then
  echo "Run this script from the repository root (lib/features was not found)." >&2
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required for feature presentation error privacy guard." >&2
  exit 2
fi

python3 - <<'PY'
import re
import sys
from pathlib import Path

feature_root = Path('lib/features')
identifier = r'[A-Za-z_$][A-Za-z0-9_$]*'
catch_pattern = re.compile(r'\bcatch\s*\(\s*(' + identifier + r')\s*(?:,|\))')

legacy_allowed_hosts = {
    'lib/views/generic_database_page.dart',
    'lib/views/tag_management_page.dart',
}


def _identifier_char(value: str) -> bool:
    return value.isalnum() or value in '_$'


def _raw_string_prefix(source: str, quote_index: int) -> bool:
    if quote_index == 0 or source[quote_index - 1] not in 'rR':
        return False
    before = source[quote_index - 2] if quote_index >= 2 else ''
    return not before or not _identifier_char(before)


def _skip_string(source: str, index: int) -> tuple[int, bool]:
    raw = _raw_string_prefix(source, index)
    quote = source[index]
    triple = source.startswith(quote * 3, index)
    delimiter_length = 3 if triple else 1
    cursor = index + delimiter_length
    while cursor < len(source):
        if triple:
            if source.startswith(quote * 3, cursor):
                return cursor + 3, raw
        elif source[cursor] == quote:
            return cursor + 1, raw

        if not raw and source[cursor] == '\\':
            cursor += 2
        else:
            cursor += 1
    return len(source), raw


def _code_mask(source: str) -> str:
    """Mask comments/string contents while preserving offsets and newlines."""
    masked = list(source)
    index = 0
    block_depth = 0
    while index < len(source):
        if block_depth:
            if source.startswith('/*', index):
                masked[index:index + 2] = '  '
                block_depth += 1
                index += 2
            elif source.startswith('*/', index):
                masked[index:index + 2] = '  '
                block_depth -= 1
                index += 2
            else:
                if source[index] != '\n':
                    masked[index] = ' '
                index += 1
            continue

        if source.startswith('//', index):
            end = source.find('\n', index + 2)
            end = len(source) if end < 0 else end
            for position in range(index, end):
                masked[position] = ' '
            index = end
            continue

        if source.startswith('/*', index):
            masked[index:index + 2] = '  '
            block_depth = 1
            index += 2
            continue

        if source[index] in "'\"":
            start = index
            end, _ = _skip_string(source, index)
            for position in range(start, end):
                if source[position] != '\n':
                    masked[position] = ' '
            index = end
            continue

        index += 1
    return ''.join(masked)


def _matching_brace(masked: str, open_index: int) -> int | None:
    depth = 0
    for index in range(open_index, len(masked)):
        value = masked[index]
        if value == '{':
            depth += 1
        elif value == '}':
            depth -= 1
            if depth == 0:
                return index
    return None


def _string_literals(source: str):
    index = 0
    block_depth = 0
    while index < len(source):
        if block_depth:
            if source.startswith('/*', index):
                block_depth += 1
                index += 2
            elif source.startswith('*/', index):
                block_depth -= 1
                index += 2
            else:
                index += 1
            continue

        if source.startswith('//', index):
            end = source.find('\n', index + 2)
            index = len(source) if end < 0 else end + 1
            continue

        if source.startswith('/*', index):
            block_depth = 1
            index += 2
            continue

        if source[index] in "'\"":
            start = index
            end, raw = _skip_string(source, index)
            quote = source[index]
            delimiter_length = 3 if source.startswith(quote * 3, index) else 1
            literal = source[
                index + delimiter_length:max(
                    index + delimiter_length,
                    end - delimiter_length,
                )
            ]
            yield start, literal, raw
            index = end
            continue

        index += 1


def _has_caught_interpolation(literal: str, variable: str) -> bool:
    cursor = 0
    while True:
        dollar = literal.find('$', cursor)
        if dollar < 0:
            return False

        slash_count = 0
        before = dollar - 1
        while before >= 0 and literal[before] == '\\':
            slash_count += 1
            before -= 1
        if slash_count % 2 == 1:
            cursor = dollar + 1
            continue

        after = literal[dollar + 1:]
        if after.startswith(variable):
            boundary_index = len(variable)
            if boundary_index == len(after) or not _identifier_char(
                after[boundary_index]
            ):
                return True

        if after.startswith('{'):
            expression = after[1:].lstrip()
            if expression.startswith(variable):
                boundary_index = len(variable)
                if boundary_index == len(expression) or not _identifier_char(
                    expression[boundary_index]
                ):
                    return True

        cursor = dollar + 1


def _scan(paths: list[Path]) -> list[tuple[str, int, str]]:
    violations: list[tuple[str, int, str]] = []
    for path in paths:
        source = path.read_text(encoding='utf-8')
        masked = _code_mask(source)
        for match in catch_pattern.finditer(masked):
            variable = match.group(1)
            if variable == '_':
                continue

            open_index = masked.find('{', match.end())
            if open_index < 0:
                continue
            close_index = _matching_brace(masked, open_index)
            if close_index is None:
                continue

            body = source[open_index + 1:close_index]
            for local_start, literal, raw in _string_literals(body):
                if raw:
                    continue
                if _has_caught_interpolation(literal, variable):
                    absolute = open_index + 1 + local_start
                    line = source.count('\n', 0, absolute) + 1
                    violations.append((path.as_posix(), line, variable))
                    break
    return violations


canonical_paths = [
    path
    for path in sorted(feature_root.rglob('*.dart'))
    if 'presentation' in path.parts
]
canonical_violations = _scan(canonical_paths)

if canonical_violations:
    print(
        'Caught exception interpolation detected under canonical feature presentation:',
        file=sys.stderr,
    )
    for path, line, variable in canonical_violations:
        print(
            f"  {path}:{line}: caught variable '{variable}' is interpolated into a string",
            file=sys.stderr,
        )
    print(file=sys.stderr)
    print(
        'Do not render raw caught exception text in feature presentation. Use a stable',
        file=sys.stderr,
    )
    print(
        'user-safe message and, when useful, a privacy-safe diagnostic or typed mapping.',
        file=sys.stderr,
    )
    sys.exit(1)

legacy_paths: list[Path] = []
for root in (Path('lib/views'), Path('lib/widgets')):
    if root.is_dir():
        legacy_paths.extend(sorted(root.rglob('*.dart')))

legacy_violations = _scan(legacy_paths)
unexpected_legacy = [
    violation
    for violation in legacy_violations
    if violation[0] not in legacy_allowed_hosts
]

if unexpected_legacy:
    print(
        'Caught exception interpolation spread into a new legacy presentation host:',
        file=sys.stderr,
    )
    for path, line, variable in unexpected_legacy:
        print(
            f"  {path}:{line}: caught variable '{variable}' is interpolated into a string",
            file=sys.stderr,
        )
    print(file=sys.stderr)
    print(
        'Legacy debt is temporarily allowlisted only in existing Issue #225 hosts.',
        file=sys.stderr,
    )
    print(
        'Use a stable user-safe message instead of extending raw-error presentation debt.',
        file=sys.stderr,
    )
    sys.exit(1)

active_legacy_hosts = {path for path, _, _ in legacy_violations}
existing_allowed_hosts = {
    path for path in legacy_allowed_hosts if Path(path).is_file()
}
stale_allowed_hosts = sorted(existing_allowed_hosts - active_legacy_hosts)

if stale_allowed_hosts:
    print(
        'Legacy error privacy allowlist is stale after debt removal:',
        file=sys.stderr,
    )
    for path in stale_allowed_hosts:
        print(f'  {path}', file=sys.stderr)
    print(file=sys.stderr)
    print(
        'Remove cleaned hosts from legacy_allowed_hosts so the privacy boundary ratchets.',
        file=sys.stderr,
    )
    sys.exit(1)

print('feature_presentation_error_privacy_guard: PASS')
PY
