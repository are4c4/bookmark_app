import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BookmarkRepository does not restore legacy relation mutation forwarders', () {
    final source = File('lib/data/bookmark_repository.dart').readAsStringSync();

    expect(source, isNot(contains('Future<void> addRelation(')));
    expect(source, isNot(contains('Future<void> removeRelation(')));
    expect(source, contains('watchRelationsForBookmark('));
  });
}
