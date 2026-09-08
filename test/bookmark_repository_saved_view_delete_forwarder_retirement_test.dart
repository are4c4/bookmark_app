import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('caller-zero Bookmark Saved View delete forwarder stays retired', () {
    final repositorySource =
        File('lib/data/bookmark_repository.dart').readAsStringSync();
    final writeStoreSource =
        File('lib/data/saved_view_write_store.dart').readAsStringSync();

    expect(repositorySource, isNot(contains('deleteSavedView(')));
    expect(writeStoreSource, contains('Future<int> delete(int id)'));
  });
}
