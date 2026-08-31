import 'package:drift/drift.dart';

import 'app_database.dart';

extension AppDatabaseTouch on AppDatabase {
  Future<void> touchBookmark(int bookmarkId) async {
    final bookmark = await (select(bookmarks)..where((b) => b.id.equals(bookmarkId))).getSingleOrNull();
    if (bookmark == null) return;
    await (update(bookmarks)..where((b) => b.id.equals(bookmarkId))).write(
      BookmarksCompanion(favorite: Value(bookmark.favorite)),
    );
  }
}
