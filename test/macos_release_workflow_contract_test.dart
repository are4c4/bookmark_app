import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Iterable<String> _shellRunBlockLines(String workflow) sync* {
  final lines = workflow.split('\n');
  int? runIndent;

  for (final line in lines) {
    final trimmed = line.trimLeft();
    final indent = line.length - trimmed.length;

    if (runIndent != null) {
      if (trimmed.isNotEmpty && indent <= runIndent) {
        runIndent = null;
      } else {
        yield line;
        continue;
      }
    }

    if (trimmed == 'run: |' || trimmed == 'run: >-') {
      runIndent = indent;
    }
  }
}

void main() {
  test('macOS release workflow keeps RC and stable publication explicit', () {
    final workflow = File('.github/workflows/macos_release.yml')
        .readAsStringSync();

    expect(workflow, contains('workflow_dispatch:'));
    expect(workflow, contains('source_sha:'));
    expect(workflow, contains('- rc'));
    expect(workflow, contains('- stable'));
    expect(workflow, contains('contents: write'));
    expect(workflow, contains('checks: read'));
    expect(workflow, contains('tool/release_ci_guard.py'));
    expect(workflow, contains('git merge-base --is-ancestor'));
    expect(workflow, contains('BOOKMARK_RELEASE_CHANNEL'));
    expect(workflow, contains('BOOKMARK_RELEASE_TAG'));
    expect(workflow, contains('bash tool/package_macos.sh'));
    expect(workflow, contains('hdiutil verify'));
    expect(workflow, contains('shasum -a 256'));
    expect(workflow, contains('release-provenance.json'));
    expect(workflow, contains('databaseSchemaVersion'));
    expect(workflow, contains('gh release create'));
    expect(workflow, contains('--prerelease'));
    expect(workflow, isNot(contains('git push')));
  });

  test('release source dispatch input reaches shell only through env data', () {
    final workflow = File('.github/workflows/macos_release.yml')
        .readAsStringSync();
    final shellSource = _shellRunBlockLines(workflow).join('\n');

    expect(
      workflow,
      contains(r'REQUESTED_SOURCE_SHA: ${{ inputs.source_sha }}'),
    );
    expect(shellSource, isNot(contains(r'${{ inputs.source_sha }}')));
    expect(shellSource, contains(r'SOURCE_SHA="${REQUESTED_SOURCE_SHA:-}"'));
    expect(shellSource, contains(r'^[0-9a-fA-F]{40}$'));
    expect(
      shellSource.indexOf(r'SOURCE_SHA="${REQUESTED_SOURCE_SHA:-}"'),
      lessThan(shellSource.indexOf(r'^[0-9a-fA-F]{40}$')),
    );
  });

  test('stable publication requires a matching immutable RC first', () {
    final workflow = File('.github/workflows/macos_release.yml')
        .readAsStringSync();

    expect(workflow, contains(r'RC_PREFIX="v${BUILD_NAME}-rc."'));
    expect(workflow, contains('gh release list'));
    expect(workflow, contains('isPrerelease'));
    expect(workflow, contains('CANDIDATE_SHA'));
    expect(
      workflow,
      contains(
        'stable publication requires a previously published RC for the same version and source commit',
      ),
    );
  });

  test('stable release identity cannot replace an existing tag or release', () {
    final workflow = File('.github/workflows/macos_release.yml')
        .readAsStringSync();

    expect(workflow, contains(r'stable) RELEASE_TAG="v${BUILD_NAME}"'));
    expect(workflow, contains(r'gh release view "$RELEASE_TAG"'));
    expect(workflow, contains('git ls-remote --exit-code --tags origin'));
    expect(workflow, contains('releases are immutable'));
    expect(workflow, contains('refusing to replace it'));
  });
}
