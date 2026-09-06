import 'package:drift/drift.dart';

import 'app_database.dart';

/// Read-only compatibility boundary from a legacy Bookmark row to its mirrored
/// generic Object record.
///
/// Older installations may not have completed Object mirroring yet, so missing
/// tables/rows intentionally fail soft to `null`. Presentation callers can then
/// use their established legacy fallback without repairing data from a read path.
class BookmarkObjectLinkReadStore {
  const BookmarkObjectLinkReadStore(this.database);

  final AppDatabase database;

  Future<int?> objectIdForBookmark({
    required int workspaceId,
    required int bookmarkId,
  }) async {
    if (workspaceId <= 0 || bookmarkId <= 0) return null;
    try {
      final rows = await database.customSelect(
        '''SELECT object_id
           FROM bookmark_object_links
           WHERE workspace_id = ? AND bookmark_id = ?
           LIMIT 1''',
        variables: [
          Variable<int>(workspaceId),
          Variable<int>(bookmarkId),
        ],
      ).get();
      if (rows.isEmpty) return null;
      return rows.first.read<int>('object_id');
    } catch (_) {
      // Compatibility installations may not have completed Object mirroring.
      return null;
    }
  }
}
