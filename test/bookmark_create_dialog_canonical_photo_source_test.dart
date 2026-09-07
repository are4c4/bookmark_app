import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Bookmark create routes selected Photos through canonical Image Relations',
      () {
    final source =
        File('lib/widgets/bookmark_create_dialog.dart').readAsStringSync();

    expect(
      source,
      contains(
        "import '../services/bookmark_image_relation_service_factory.dart';",
      ),
    );
    expect(
      source,
      contains('createBookmarkImageRelationService(repository)'),
    );
    expect(source, contains('.saveLegacyPhotosAfterCreate('));
    expect(source, contains('workspaceId: repository.workspaceId'));
    expect(source, contains('bookmarkId: bookmarkId'));
    expect(
      source,
      contains('photoIds: selectedPhotos.map((photo) => photo.id)'),
    );
    expect(source, contains('coverPhotoId: coverPhoto?.id'));
    expect(source, isNot(contains('attachPhotosByBookmarkId(')));
  });
}
