import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppDatabase does not restore legacy Bookmark Photo mutation helpers', () {
    final source = File('lib/data/app_database.dart').readAsStringSync();

    for (final retired in <String>[
      'Future<void> attachPhotoToBookmark(',
      'Future<void> attachPhotosToBookmark(',
      'Future<void> detachPhotoFromBookmark(',
      'Future<void> setCoverPhoto(',
      'Future<void> clearCoverPhoto(',
    ]) {
      expect(source, isNot(contains(retired)), reason: retired);
    }
  });
}
