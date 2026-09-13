import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS packaging derives and embeds source provenance', () {
    final syntax = Process.runSync('bash', ['-n', 'tool/package_macos.sh']);
    expect(syntax.exitCode, 0, reason: '${syntax.stderr}');

    final script = File('tool/package_macos.sh').readAsStringSync();

    expect(script, contains('git rev-parse HEAD'));
    expect(script, contains('git rev-parse --short=7 HEAD'));
    expect(script, contains('git status --porcelain --untracked-files=normal'));
    expect(script, contains('SOURCE_STATE="dirty"'));
    expect(script, contains('SOURCE_STATE="clean"'));
    expect(script, contains(r'BOOKMARK_APP_VERSION=$BUILD_NAME'));
    expect(script, contains(r'BOOKMARK_APP_BUILD_NUMBER=$BUILD_NUMBER'));
    expect(script, contains(r'BOOKMARK_GIT_SHA=$GIT_SHA'));
    expect(script, contains(r'BOOKMARK_SOURCE_STATE=$SOURCE_STATE'));
    expect(script, contains(r'BOOKMARK_RELEASE_CHANNEL=$RELEASE_CHANNEL'));
    expect(script, contains('DMG_PATH='));
    expect(script, contains('BUILD_PROVENANCE_LABEL.dmg'));
  });

  test('local packages cannot silently masquerade as RC or stable', () {
    final script = File('tool/package_macos.sh').readAsStringSync();

    expect(
      script,
      contains(r'RELEASE_CHANNEL="${BOOKMARK_RELEASE_CHANNEL:-development}"'.replaceAll(r'\"', '"')),
    );
    expect(script, contains('development|rc|stable'));
    expect(script, contains('packaging requires a clean Git source tree'));
    expect(script, contains('BOOKMARK_RELEASE_TAG is required'));
    expect(script, contains(r'EXPECTED_TAG="v$BUILD_NAME"'.replaceAll(r'\"', '"')));
    expect(script, contains(r'RC_PREFIX="v$BUILD_NAME-rc."'.replaceAll(r'\"', '"')));
    expect(script, contains(r'git rev-parse "$RELEASE_TAG^{commit}"'.replaceAll(r'\"', '"')));
    expect(script, contains('must resolve to source HEAD'));
  });
}
