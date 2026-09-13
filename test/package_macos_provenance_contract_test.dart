import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS packaging derives and embeds source provenance', () {
    final script = File('tool/package_macos.sh').readAsStringSync();

    expect(script, contains('git rev-parse HEAD'));
    expect(script, contains('git rev-parse --short=7 HEAD'));
    expect(script, contains('git status --porcelain --untracked-files=normal'));
    expect(script, contains('SOURCE_STATE="dirty"'));
    expect(script, contains('SOURCE_STATE="clean"'));
    expect(script, contains('BOOKMARK_APP_VERSION=$BUILD_NAME'));
    expect(script, contains('BOOKMARK_APP_BUILD_NUMBER=$BUILD_NUMBER'));
    expect(script, contains('BOOKMARK_GIT_SHA=$GIT_SHA'));
    expect(script, contains('BOOKMARK_SOURCE_STATE=$SOURCE_STATE'));
    expect(script, contains('DMG_PATH='));
    expect(script, contains('BUILD_PROVENANCE_LABEL.dmg'));
  });
}
