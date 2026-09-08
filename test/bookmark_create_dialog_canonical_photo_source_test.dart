import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Bookmark create selects and saves canonical Image Objects directly', () {
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
      contains("import 'bookmark_create_image_picker.dart';"),
    );
    expect(
      source,
      contains('createBookmarkImageRelationService(repository)'),
    );
    expect(source, contains('showBookmarkCreateImagePicker('));
    expect(source, contains('.saveImagesAfterCreate('));
    expect(source, contains('workspaceId: repository.workspaceId'));
    expect(source, contains('bookmarkId: bookmarkId'));
    expect(
      source,
      contains('imageObjectIds: selectedImages.map((image) => image.objectId)'),
    );
    expect(source, contains('coverImageObjectId: coverImageObjectId'));
    expect(source, contains('Imagesから選択'));

    expect(source, isNot(contains("import 'photo_database_picker.dart';")));
    expect(source, isNot(contains('showPhotoDatabasePicker(')));
    expect(source, isNot(contains('PhotoRecord')));
    expect(source, isNot(contains('.saveLegacyPhotosAfterCreate(')));
    expect(source, isNot(contains('写真DBから選択')));
    expect(source, isNot(contains('Image.file(')));
  });
}
