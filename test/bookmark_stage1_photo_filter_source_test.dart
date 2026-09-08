import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Stage1 Photo filter delegates to focused canonical backlink stream',
    () {
      final stage1 = File('lib/views/bookmark_unified_stage1_page.dart')
          .readAsStringSync();
      final query = File('lib/views/bookmark_query_engine.dart')
          .readAsStringSync();

      expect(stage1, contains('stream: _watchBookmarksForActiveFilters(),'));
      expect(
        stage1,
        contains('widget.repository.watchBookmarksForPhotoId(photoId)'),
      );
      expect(stage1, isNot(contains('widget.repository.watchPhotos()')));
      expect(stage1, contains("'photoId': _photoFilterId"));
      expect(stage1, isNot(contains('photoFilterId: _photoFilterId')));

      expect(query, isNot(contains('bookmark.photos.any')));
      expect(query, isNot(contains('final int? photoFilterId')));
    },
  );
}
