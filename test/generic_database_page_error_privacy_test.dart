import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Generic Database failures do not expose caught exceptions', () {
    final source =
        File('lib/views/generic_database_page.dart').readAsStringSync();

    const stableMessages = <String>[
      'データベースを更新できませんでした。',
      'データベースを複製できませんでした。',
      'コレクション設定を保存できませんでした。',
      'データベースを削除できませんでした。',
      'プロパティを追加できませんでした。',
      'Objectを作成できませんでした。',
      'カードを移動できませんでした。',
      'Relationを更新できませんでした。',
      'Objectを削除できませんでした。',
    ];

    for (final message in stableMessages) {
      expect(source, contains(message), reason: 'missing stable message: $message');
    }

    expect(source, isNot(contains(r': $error')));
    expect(source, isNot(contains(r'${error')));
  });
}
