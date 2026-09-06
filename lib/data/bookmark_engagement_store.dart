import 'package:drift/drift.dart';

import 'app_database.dart';

/// Owns user-specific Bookmark engagement mutations that do not belong to the
/// database root's schema/migration responsibilities.
class BookmarkEngagementStore {
  BookmarkEngagementStore(this.database);

  final AppDatabase database;

  Future<void> setFavorite(int id, bool favorite) async {
    await (database.update(database.bookmarks)..where((b) => b.id.equals(id)))
        .write(BookmarksCompanion(favorite: Value(favorite)));
  }

  Future<void> setStatus(int id, String status) async {
    await (database.update(database.bookmarks)..where((b) => b.id.equals(id)))
        .write(BookmarksCompanion(
      status: Value(status),
      readingStatus: Value(status == 'archived' ? 'unread' : status),
      storageState:
          status == 'archived' ? const Value('archived') : const Value.absent(),
    ));
  }

  Future<void> setRating(int id, int rating) =>
      (database.update(database.bookmarks)..where((b) => b.id.equals(id))).write(
        BookmarksCompanion(rating: Value(rating.clamp(0, 5))),
      );

  Future<void> batchSetStatus(Iterable<int> ids, String status) async {
    final readingStatus = status == 'archived' ? 'unread' : status;
    for (final id in ids.toSet()) {
      await (database.update(database.bookmarks)..where((b) => b.id.equals(id)))
          .write(BookmarksCompanion(
        status: Value(status),
        readingStatus: Value(readingStatus),
        storageState: status == 'archived'
            ? const Value('archived')
            : const Value.absent(),
      ));
    }
  }

  Future<void> batchSetRating(Iterable<int> ids, int rating) async {
    for (final id in ids.toSet()) {
      await (database.update(database.bookmarks)..where((b) => b.id.equals(id)))
          .write(
        BookmarksCompanion(rating: Value(rating.clamp(0, 5))),
      );
    }
  }

  Future<void> batchSetFavorite(Iterable<int> ids, bool favorite) async {
    for (final id in ids.toSet()) {
      await (database.update(database.bookmarks)..where((b) => b.id.equals(id)))
          .write(BookmarksCompanion(favorite: Value(favorite)));
    }
  }

  Future<void> recordOpen(int id) async {
    final bookmark = await (database.select(database.bookmarks)
          ..where((b) => b.id.equals(id)))
        .getSingleOrNull();
    if (bookmark == null) return;
    await (database.update(database.bookmarks)..where((b) => b.id.equals(id)))
        .write(BookmarksCompanion(
      lastOpenedAt: Value(DateTime.now()),
      openCount: Value(bookmark.openCount + 1),
    ));
  }
}
