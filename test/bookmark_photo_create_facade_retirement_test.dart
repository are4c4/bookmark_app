import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy Bookmark photo create facade stays retired', () {
    final repository = File('lib/data/bookmark_repository.dart')
        .readAsStringSync();

    expect(repository, isNot(contains('addPhoto(')));
  });
}
