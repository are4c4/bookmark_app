import '../data/app_database.dart';
import '../data/bookmark_repository.dart';

class BacklinkEntry {
  const BacklinkEntry({
    required this.bookmark,
    required this.relationType,
    required this.direction,
  });

  final BookmarkItem bookmark;
  final String relationType;
  final BacklinkDirection direction;

  String get directionLabel =>
      direction == BacklinkDirection.outgoing ? '→ outgoing' : '← incoming';
}

enum BacklinkDirection { outgoing, incoming }

/// Presents BookmarkRelations as a bidirectional graph.
///
/// Existing rows remain directional in storage. This repository exposes both
/// outgoing links and incoming backlinks without duplicating relation rows.
class BacklinkRepository {
  BacklinkRepository(this._root)
      : _database = _root.lifecycleStore.database;

  final BookmarkRepository _root;
  final AppDatabase _database;

  Stream<List<BacklinkEntry>> watchFor(int bookmarkId) {
    final query = _database.select(_database.bookmarkRelations)
      ..where(
        (relation) =>
            relation.sourceBookmarkId.equals(bookmarkId) |
            relation.targetBookmarkId.equals(bookmarkId),
      );

    return query.watch().asyncMap((relations) async {
      final bookmarks = await _root.watchAll().first;
      final byId = {for (final bookmark in bookmarks) bookmark.id: bookmark};
      final entries = <BacklinkEntry>[];

      for (final relation in relations) {
        if (relation.sourceBookmarkId == bookmarkId) {
          final target = byId[relation.targetBookmarkId];
          if (target != null) {
            entries.add(
              BacklinkEntry(
                bookmark: target,
                relationType: relation.relationType,
                direction: BacklinkDirection.outgoing,
              ),
            );
          }
        } else {
          final source = byId[relation.sourceBookmarkId];
          if (source != null) {
            entries.add(
              BacklinkEntry(
                bookmark: source,
                relationType: relation.relationType,
                direction: BacklinkDirection.incoming,
              ),
            );
          }
        }
      }

      entries.sort((a, b) {
        final directionCompare = a.direction.index.compareTo(b.direction.index);
        if (directionCompare != 0) return directionCompare;
        return a.bookmark.title.toLowerCase().compareTo(b.bookmark.title.toLowerCase());
      });
      return entries;
    });
  }

  Future<void> link(
    BookmarkItem source,
    BookmarkItem target, {
    String relationType = 'related',
  }) =>
      _root.addRelation(source, target, relationType);

  Future<void> unlink(
    BookmarkItem source,
    BookmarkItem target, {
    String relationType = 'related',
  }) =>
      _root.removeRelation(source.id, target.id, relationType);
}
