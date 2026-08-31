import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/repositories/backlink_repository.dart';
import 'package:flutter_test/flutter_test.dart';

BookmarkItem _bookmark(int id, String title) => BookmarkItem(
      id: id,
      url: 'https://example.com/$id',
      title: title,
      createdAt: DateTime(2026),
      favorite: false,
      status: 'unread',
      rating: 0,
      openCount: 0,
      tags: const [],
      people: const [],
      photos: const [],
      collections: const [],
    );

void main() {
  group('BacklinkRepository.buildEntries', () {
    test('classifies outgoing and incoming relations', () {
      final entries = BacklinkRepository.buildEntries(
        bookmarkId: 1,
        bookmarks: [
          _bookmark(1, 'Current'),
          _bookmark(2, 'Target'),
          _bookmark(3, 'Source'),
        ],
        relations: const [
          BookmarkRelation(
            sourceBookmarkId: 1,
            targetBookmarkId: 2,
            relationType: 'reference',
          ),
          BookmarkRelation(
            sourceBookmarkId: 3,
            targetBookmarkId: 1,
            relationType: 'source',
          ),
        ],
      );

      expect(entries, hasLength(2));
      expect(entries[0].bookmark.id, 2);
      expect(entries[0].direction, BacklinkDirection.outgoing);
      expect(entries[0].directionLabel, '→ outgoing');
      expect(entries[1].bookmark.id, 3);
      expect(entries[1].direction, BacklinkDirection.incoming);
      expect(entries[1].directionLabel, '← incoming');
    });

    test('sorts outgoing before incoming and titles within a direction', () {
      final entries = BacklinkRepository.buildEntries(
        bookmarkId: 1,
        bookmarks: [
          _bookmark(1, 'Current'),
          _bookmark(2, 'Zulu'),
          _bookmark(3, 'Alpha'),
          _bookmark(4, 'Beta'),
        ],
        relations: const [
          BookmarkRelation(sourceBookmarkId: 1, targetBookmarkId: 2, relationType: 'related'),
          BookmarkRelation(sourceBookmarkId: 1, targetBookmarkId: 3, relationType: 'related'),
          BookmarkRelation(sourceBookmarkId: 4, targetBookmarkId: 1, relationType: 'related'),
        ],
      );

      expect(entries.map((entry) => entry.bookmark.title), ['Alpha', 'Zulu', 'Beta']);
      expect(entries.map((entry) => entry.direction), [
        BacklinkDirection.outgoing,
        BacklinkDirection.outgoing,
        BacklinkDirection.incoming,
      ]);
    });

    test('ignores relations that do not touch the requested bookmark', () {
      final entries = BacklinkRepository.buildEntries(
        bookmarkId: 1,
        bookmarks: [_bookmark(1, 'Current'), _bookmark(2, 'A'), _bookmark(3, 'B')],
        relations: const [
          BookmarkRelation(sourceBookmarkId: 2, targetBookmarkId: 3, relationType: 'related'),
        ],
      );

      expect(entries, isEmpty);
    });
  });
}
