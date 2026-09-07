import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppShell failure messages do not expose caught exceptions', () {
    final source = File('lib/views/app_shell.dart').readAsStringSync();

    const stableMessages = <String>[
      'データベースを作成できませんでした。',
      'Workspaceを作成できませんでした。',
      'データ操作に失敗しました。',
    ];

    for (final message in stableMessages) {
      expect(source, contains(message), reason: 'missing stable message: $message');
    }

    expect(source, isNot(contains(r'$error')));
    expect(source, isNot(contains(r'${error')));
  });
}
