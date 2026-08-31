import 'package:drift/drift.dart';

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
    final relationStream = _database.customSelect(
      '''
      SELECT source_bookmark_id, target_bookmark_id, relation_type
      FROM bookmark_relations
      WHERE source_bookmark_id = ? OR target_bookmark_id = ?
      ''',
      variables: [Variable.withInt(bookmarkId), Variable.withInt(bookmarkId)],
      readsFrom: {_database.bookmarkRelations},
    ).watch();

    return relationStream.asyncMap((rows) async {
      final bookmarks = await _root.watchAll().first;
      final byId = {for (final bookmark in bookmarks) bookmark.id: bookmark};
      final entries = <BacklinkEntry>[];

      for (final row in rows) {
        final sourceId = row.read<int>('source_bookmark_id');
        final targetId = row.read<int>('target_bookmark_id');
        final type = row.read<String>('relation_type');
        if (sourceId == bookmarkId) {
          final target = byId[targetId];
          if (target != null) {
            entries.add(
              BacklinkEntry(
                bookmark: target,
                relationType: type,
                direction: BacklinkDirection.outgoing,
              ),
            );
          }
        } else {
          final source = byId[sourceId];
          if (source != null) {
            entries.add(
              BacklinkEntry(
                bookmark: source,
                relationType: type,
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
