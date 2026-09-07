import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BookmarkRepository does not restore legacy Photo attachment forwarding', () {
    final source = File('lib/data/bookmark_repository.dart').readAsStringSync();

    for (final retired in <String>[
      'Future<void> attachPhoto(',
      'Future<void> attachPhotos(',
      'Future<void> attachPhotosByBookmarkId(',
      'Future<void> detachPhoto(',
      'Future<void> setCoverPhoto(',
      'Future<void> clearCoverPhoto(',
    ]) {
      expect(source, isNot(contains(retired)), reason: retired);
    }
  });
}
