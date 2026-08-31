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
    final columns = await database.customSelect('PRAGMA table_info(bookmarks)').get();
    final names = columns.map((row) => row.read<String>('name')).toSet();

    if (!names.contains('inbox_state')) {
      await database.customStatement(
        'ALTER TABLE bookmarks ADD COLUMN inbox_state INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (!names.contains('deleted_at_state')) {
      await database.customStatement(
        'ALTER TABLE bookmarks ADD COLUMN deleted_at_state TEXT',
      );
    }

    // Older experimental lifecycle data may exist. Import it once, then remove
    // the legacy table so bookmarks becomes the single source of truth.
    final tables = await database.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'bookmark_lifecycle'",
    ).get();
    if (tables.isNotEmpty) {
      await database.customStatement('''
        UPDATE bookmarks
        SET inbox_state = COALESCE(
              (SELECT inbox FROM bookmark_lifecycle bl WHERE bl.bookmark_id = bookmarks.id),
              inbox_state
            ),
            deleted_at_state = COALESCE(
              (SELECT deleted_at FROM bookmark_lifecycle bl WHERE bl.bookmark_id = bookmarks.id),
              deleted_at_state
            )
        WHERE EXISTS (
          SELECT 1 FROM bookmark_lifecycle bl WHERE bl.bookmark_id = bookmarks.id
        )
      ''');
      await database.customStatement('DROP TABLE bookmark_lifecycle');
    }
  }

  Future<Map<int, BookmarkLifecycleState>> states() async {
    final rows = await database.customSelect(
      'SELECT id AS bookmark_id, inbox_state AS inbox, deleted_at_state AS deleted_at FROM bookmarks',
      readsFrom: {database.bookmarks},
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
    await database.customUpdate(
      'UPDATE bookmarks SET inbox_state = ?, deleted_at_state = NULL WHERE id = ?',
      variables: [Variable<int>(inbox ? 1 : 0), Variable<int>(bookmarkId)],
      updates: {database.bookmarks},
    );
    _changes.add(null);
  }

  Future<void> setInbox(int bookmarkId, bool value) async {
    await database.customUpdate(
      'UPDATE bookmarks SET inbox_state = ?, deleted_at_state = NULL WHERE id = ?',
      variables: [Variable<int>(value ? 1 : 0), Variable<int>(bookmarkId)],
      updates: {database.bookmarks},
    );
    _changes.add(null);
  }

  Future<void> moveToTrash(int bookmarkId) async {
    final changed = await database.customUpdate(
      'UPDATE bookmarks SET inbox_state = 0, deleted_at_state = ? WHERE id = ?',
      variables: [
        Variable<String>(DateTime.now().toIso8601String()),
        Variable<int>(bookmarkId),
      ],
      updates: {database.bookmarks},
    );
    if (changed == 0) {
      throw StateError('削除対象のブックマークが見つかりませんでした (id=$bookmarkId)');
    }
    _changes.add(null);
  }

  Future<void> restore(int bookmarkId) async {
    final changed = await database.customUpdate(
      'UPDATE bookmarks SET deleted_at_state = NULL WHERE id = ?',
      variables: [Variable<int>(bookmarkId)],
      updates: {database.bookmarks},
    );
    if (changed == 0) {
      throw StateError('復元対象のブックマークが見つかりませんでした (id=$bookmarkId)');
    }
    _changes.add(null);
  }

  Future<void> remove(int bookmarkId) async {
    // Permanent deletion removes the bookmark row immediately after this call.
    _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
