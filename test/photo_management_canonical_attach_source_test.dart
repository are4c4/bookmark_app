import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Photo Management routes Bookmark attach through canonical Image Relations',
      () {
    final source = File('lib/views/photo_management_page.dart').readAsStringSync();

    expect(
      source,
      contains("import '../services/bookmark_image_relation_service_factory.dart';"),
    );
    expect(source, contains('createBookmarkImageRelationService(repository)'));
    expect(source, contains('imageRelations.attachLegacyPhoto('));
    expect(source, contains('workspaceId: repository.workspaceId'));
    expect(source, contains('bookmarkId: selected!.id'));
    expect(source, contains('photoId: photo.id'));
    expect(source, contains('asCover: asCover'));
    expect(source, isNot(contains('repository.attachPhoto(')));
  });
}
