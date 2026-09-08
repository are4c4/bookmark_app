import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Stage1 image drop cannot revive legacy Photo writes', () {
    final source =
        File('lib/views/bookmark_unified_stage1_page.dart').readAsStringSync();

    expect(
      source,
      contains(
        "import '../services/bookmark_stage1_image_drop_import_service.dart';",
      ),
    );
    expect(source, contains('_imageDropImport.importDroppedPaths(paths)'));
    expect(source, contains('枚をImagesへ追加しました'));
    expect(source, contains('画像を追加できませんでした。'));

    expect(source, isNot(contains('PhotoStorageService().importPaths')));
    expect(source, isNot(contains('repository.addPhoto(')));
    expect(source, isNot(contains('写真DBへ追加しました')));
  });
}
