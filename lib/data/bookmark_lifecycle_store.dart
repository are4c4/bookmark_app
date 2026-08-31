import 'dart:async';

import 'package:drift/drift.dart';

import 'app_database.dart';

class BookmarkLifecycleState {
  const BookmarkLifecycleState({
    required this.bookmarkId,
    required this.inbox,
    this.deletedAt,
  });

  final int bookmarkId;
  final bool inbox;
  final DateTime? deletedAt;

  bool get deleted => deletedAt != null;
}

class BookmarkLifecycleStore {
  BookmarkLifecycleStore(this.database);

  final AppDatabase database;
  final _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  Future<void> initialize() async {
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS bookmark_lifecycle (
        bookmark_id INTEGER PRIMARY KEY,
        inbox INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT,
        FOREIGN KEY(bookmark_id) REFERENCES bookmarks(id) ON DELETE CASCADE
      )
    ''');
    await database.customStatement('''
      INSERT OR IGNORE INTO bookmark_lifecycle(bookmark_id, inbox, deleted_at)
      SELECT id, 0, NULL FROM bookmarks
    ''');
  }

  Future<Map<int, BookmarkLifecycleState>> states() async {
    final rows = await database.customSelect(
      'SELECT bookmark_id, inbox, deleted_at FROM bookmark_lifecycle',
    ).get();
    return {
      for (final row in rows)
        row.read<int>('bookmark_id'): BookmarkLifecycleState(
          bookmarkId: row.read<int>('bookmark_id'),
          inbox: row.read<int>('inbox') != 0,
          deletedAt: row.readNullable<String>('deleted_at') == null
              ? null
              : DateTime.tryParse(row.read<String>('deleted_at')),
        ),
    };
  }

  Future<void> ensureBookmark(int bookmarkId, {bool inbox = false}) async {
    await database.customStatement(
      'INSERT INTO bookmark_lifecycle(bookmark_id, inbox, deleted_at) VALUES (?, ?, NULL) '
      'ON CONFLICT(bookmark_id) DO UPDATE SET inbox = excluded.inbox',
      [bookmarkId, inbox ? 1 : 0],
    );
    _changes.add(null);
  }

  Future<void> setInbox(int bookmarkId, bool value) async {
    await database.customStatement(
      'INSERT INTO bookmark_lifecycle(bookmark_id, inbox, deleted_at) VALUES (?, ?, NULL) '
      'ON CONFLICT(bookmark_id) DO UPDATE SET inbox = excluded.inbox',
      [bookmarkId, value ? 1 : 0],
    );
    _changes.add(null);
  }

  Future<void> moveToTrash(int bookmarkId) async {
    await database.customStatement(
      'INSERT INTO bookmark_lifecycle(bookmark_id, inbox, deleted_at) VALUES (?, 0, ?) '
      'ON CONFLICT(bookmark_id) DO UPDATE SET inbox = 0, deleted_at = excluded.deleted_at',
      [bookmarkId, DateTime.now().toIso8601String()],
    );
    _changes.add(null);
  }

  Future<void> restore(int bookmarkId) async {
    await database.customStatement(
      'INSERT INTO bookmark_lifecycle(bookmark_id, inbox, deleted_at) VALUES (?, 0, NULL) '
      'ON CONFLICT(bookmark_id) DO UPDATE SET deleted_at = NULL',
      [bookmarkId],
    );
    _changes.add(null);
  }

  Future<void> remove(int bookmarkId) async {
    await database.customStatement(
      'DELETE FROM bookmark_lifecycle WHERE bookmark_id = ?',
      [bookmarkId],
    );
    _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
