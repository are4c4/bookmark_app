import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Tag management failures keep useful messages without raw exceptions', () {
    final source = File('lib/views/tag_management_page.dart').readAsStringSync();

    const expectedMessages = <String>[
      '同名のタグが存在します',
      'タグ名を変更できませんでした',
      'タグを追加できませんでした',
      '移動できませんでした。',
      '同じ名前のタググループが既にあります',
      'グループを追加できませんでした。',
      'グループ名を変更できませんでした。',
      'グループを削除できませんでした。',
    ];

    for (final message in expectedMessages) {
      expect(source, contains(message), reason: 'missing stable message: $message');
    }

    expect(source, contains('on TagGroupNameConflictException'));
    expect(source, isNot(contains(r"_editError = '$error'")));
    expect(source, isNot(contains(r"_createError = '$error'")));
    expect(source, isNot(contains(r': $error')));
    expect(source, isNot(contains(r'${error')));
  });
}
