import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Bookmark detail image presentation routes edits through canonical Relations',
      () {
    final section = File('lib/widgets/bookmark_image_relation_section.dart')
        .readAsStringSync();
    final detail =
        File('lib/widgets/bookmark_detail_panel.dart').readAsStringSync();

    expect(section, contains('showObjectRelationPickerDialog('));
    expect(section, contains('_service.saveImages('));
    expect(section, contains('_service.setCover('));
    expect(section, contains('_service.clearCover('));
    expect(section, contains('_service.detachImage('));
    expect(section, isNot(contains("import 'photo_database_picker.dart';")));
    expect(section, isNot(contains('attachPhotos(')));
    expect(section, isNot(contains('attachPhoto(')));

    expect(
      detail,
      contains("import 'bookmark_image_relation_section.dart';"),
    );
    expect(detail, contains('BookmarkImageRelationSection('));
    expect(detail, isNot(contains("import 'photo_database_picker.dart';")));
    expect(detail, isNot(contains('showPhotoDatabasePicker(')));
  });
}
