import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BookmarkRepository keeps internal service details private', () {
    final source =
        File('lib/data/bookmark_repository.dart').readAsStringSync();

    expect(source, contains('final AutoOrganizeService _autoOrganize;'));
    expect(source, contains('String? get _photoDirectoryPath =>'));
    expect(source, isNot(contains('final AutoOrganizeService autoOrganize;')));
    expect(source, isNot(contains('String? get photoDirectoryPath =>')));
  });
}
