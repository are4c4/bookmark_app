import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS release workflow keeps RC and stable publication explicit', () {
    final workflow = File('.github/workflows/macos_release.yml').readAsStringSync();

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

  test('stable release identity cannot replace an existing tag or release', () {
    final workflow = File('.github/workflows/macos_release.yml').readAsStringSync();

    expect(workflow, contains(r'stable) RELEASE_TAG="v${BUILD_NAME}"'));
    expect(workflow, contains('gh release view "$RELEASE_TAG"'));
    expect(workflow, contains('git ls-remote --exit-code --tags origin'));
    expect(workflow, contains('releases are immutable'));
    expect(workflow, contains('refusing to replace it'));
  });
}
