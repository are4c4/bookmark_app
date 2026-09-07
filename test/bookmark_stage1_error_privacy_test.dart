import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Stage1 URL drop failure keeps a stable user-safe message', () {
    final source = File('lib/views/bookmark_unified_stage1_page.dart')
        .readAsStringSync();

    expect(
      source,
      contains(
        "const SnackBar(content: Text('URLを追加できませんでした。'))",
      ),
    );
    expect(
      source,
      isNot(contains('URLを追加できませんでした: \$error')),
    );
  });
}
