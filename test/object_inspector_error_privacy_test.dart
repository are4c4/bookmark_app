import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Object Inspector failure messages do not expose caught exceptions', () {
    final source = File('lib/views/object_inspector_page.dart').readAsStringSync();

    const stableMessages = <String>[
      '別名を追加できませんでした。',
      '別名を削除できませんでした。',
      'Daily Noteを開けませんでした。',
      'Bodyを更新できませんでした。',
      'Object参照を追加できませんでした。',
      'Database / View参照を追加できませんでした。',
      'Object名を変更できませんでした。',
      'を更新できませんでした。',
      'Weblinkに昇格できませんでした。',
    ];

    for (final message in stableMessages) {
      expect(source, contains(message), reason: 'missing stable message: $message');
    }

    expect(source, isNot(contains(r'$error')));
    expect(source, isNot(contains(r'${error')));
  });
}
