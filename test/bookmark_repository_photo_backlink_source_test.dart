import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Photo reverse lookup routes through canonical Image backlinks', () {
    final source = File('lib/data/bookmark_repository.dart').readAsStringSync();

    expect(
      source,
      contains(
        "import '../services/legacy_photo_bookmark_backlink_service.dart';",
      ),
    );
    expect(source, contains('LegacyPhotoBookmarkBacklinkService(_database)'));
    expect(source, contains('.bookmarkIdsForPhoto('));
    expect(source, contains('workspaceId: workspaceId'));
    expect(source, contains('photoId: photo.id'));
    expect(
      source,
      isNot(
        contains(
          'item.photos.any((candidate) => candidate.id == photo.id)',
        ),
      ),
    );
  });
}
