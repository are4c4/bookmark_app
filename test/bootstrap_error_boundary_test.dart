import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bootstrap failure boundary is stable and privacy-safe', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(
      source,
      contains(
        "'起動またはProfile切替に失敗しました。\\n"
        "アプリを再起動して、もう一度お試しください。'",
      ),
    );
    expect(source, isNot(contains(r"$_error")));
    expect(source, contains("name: 'bookmark.bootstrap'"));
    expect(source, contains("'Bookmark bootstrap failed.'"));
    expect(source, contains("'Profile switch failed.'"));
    expect(source, contains("'Profile switch rollback failed.'"));
    expect(source, isNot(contains('error: error')));
  });
}
