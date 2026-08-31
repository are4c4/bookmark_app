import 'package:drift/drift.dart';

import 'app_database.dart';

class BookmarkLifecycleState {
  const BookmarkLifecycleState({
    required this.bookmarkId,
    required this.inbox,
    required this.deleted,
    this.deletedAt,
  });

  final int bookmarkId;
  final bool inbox;
  final bool deleted;
  final DateTime? deletedAt;
}

class BookmarkLifecycleStore {
  BookmarkLifecycleStore(this.database);

  final AppDatabase database;

  Future<void> initialize() async {
    // Keep the legacy columns during the transition so older exports and
    // pre-v11 helper code can still be read safely. The source of truth is now
    // reading_status / storage_state / genre / deleted_at.
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
    if (!names.contains('genre_state')) {
      await database.customStatement(
        "ALTER TABLE bookmarks ADD COLUMN genre_state TEXT NOT NULL DEFAULT ''",
      );
    }

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

    await database.customStatement('''
      UPDATE bookmarks
      SET storage_state = CASE
            WHEN deleted_at_state IS NOT NULL THEN 'trash'
            WHEN inbox_state = 1 THEN 'inbox'
            WHEN status = 'archived' THEN 'archived'
            ELSE storage_state
          END,
          genre = CASE
            WHEN genre = '' AND genre_state != '' THEN genre_state
            ELSE genre
          END
    ''');

    final deletedRows = await database.customSelect('''
      SELECT id, deleted_at_state
      FROM bookmarks
      WHERE deleted_at_state IS NOT NULL AND deleted_at IS NULL
    ''').get();
    for (final row in deletedRows) {
      final parsed = DateTime.tryParse(row.read<String>('deleted_at_state'));
      if (parsed == null) continue;
      await (database.update(database.bookmarks)
            ..where((bookmark) => bookmark.id.equals(row.read<int>('id'))))
          .write(BookmarksCompanion(deletedAt: Value(parsed)));
    }
  }

  Future<Map<int, BookmarkLifecycleState>> states() async {
    final rows = await database.select(database.bookmarks).get();
    return {
      for (final bookmark in rows)
        bookmark.id: BookmarkLifecycleState(
          bookmarkId: bookmark.id,
          inbox: bookmark.storageState == 'inbox',
          deleted: bookmark.storageState == 'trash',
          deletedAt: bookmark.deletedAt,
        ),
    };
  }

  Stream<Map<int, BookmarkLifecycleState>> watchStates() => database.select(database.bookmarks).watch().map(
        (rows) => {
          for (final bookmark in rows)
            bookmark.id: BookmarkLifecycleState(
              bookmarkId: bookmark.id,
              inbox: bookmark.storageState == 'inbox',
              deleted: bookmark.storageState == 'trash',
              deletedAt: bookmark.deletedAt,
            ),
        },
      );

  Future<String> genre(int bookmarkId) async {
    final row = await (database.select(database.bookmarks)
          ..where((bookmark) => bookmark.id.equals(bookmarkId)))
        .getSingleOrNull();
    return row?.genre ?? '';
  }

  Stream<String> watchGenre(int bookmarkId) {
    final query = database.select(database.bookmarks)
      ..where((bookmark) => bookmark.id.equals(bookmarkId));
    return query.watchSingleOrNull().map((bookmark) => bookmark?.genre ?? '');
  }

  Future<void> setGenre(int bookmarkId, String value) async {
    final trimmed = value.trim();
    final changed = await (database.update(database.bookmarks)
          ..where((bookmark) => bookmark.id.equals(bookmarkId)))
        .write(BookmarksCompanion(genre: Value(trimmed)));
    if (changed == 0) {
      throw StateError('ジャンルを更新できませんでした (id=$bookmarkId)');
    }
    await database.customUpdate(
      'UPDATE bookmarks SET genre_state = ? WHERE id = ?',
      variables: [Variable<String>(trimmed), Variable<int>(bookmarkId)],
      updates: {database.bookmarks},
    );
  }

  Future<void> ensureBookmark(int bookmarkId, {bool inbox = false}) async {
    final state = inbox ? 'inbox' : 'active';
    final changed = await (database.update(database.bookmarks)
          ..where((bookmark) => bookmark.id.equals(bookmarkId)))
        .write(BookmarksCompanion(
          storageState: Value(state),
          deletedAt: const Value(null),
        ));
    if (changed == 0) {
      throw StateError('ブックマーク状態を初期化できませんでした (id=$bookmarkId)');
    }
    await _syncLegacyState(bookmarkId, inbox: inbox, deletedAt: null);
  }

  Future<void> setInbox(int bookmarkId, bool value) async {
    final changed = await (database.update(database.bookmarks)
          ..where((bookmark) => bookmark.id.equals(bookmarkId)))
        .write(BookmarksCompanion(
          storageState: Value(value ? 'inbox' : 'active'),
          deletedAt: const Value(null),
        ));
    if (changed == 0) {
      throw StateError('未整理状態を更新できませんでした (id=$bookmarkId)');
    }
    await _syncLegacyState(bookmarkId, inbox: value, deletedAt: null);
  }

  Future<void> moveToTrash(int bookmarkId) async {
    final deletedAt = DateTime.now();
    final changed = await (database.update(database.bookmarks)
          ..where((bookmark) => bookmark.id.equals(bookmarkId)))
        .write(BookmarksCompanion(
          storageState: const Value('trash'),
          deletedAt: Value(deletedAt),
        ));
    if (changed == 0) {
      throw StateError('削除対象のブックマークが見つかりませんでした (id=$bookmarkId)');
    }
    await _syncLegacyState(bookmarkId, inbox: false, deletedAt: deletedAt);

    final verification = await (database.select(database.bookmarks)
          ..where((bookmark) => bookmark.id.equals(bookmarkId)))
        .getSingleOrNull();
    if (verification?.storageState != 'trash' || verification?.deletedAt == null) {
      throw StateError('ゴミ箱への移動状態を保存できませんでした (id=$bookmarkId)');
    }
  }

  Future<void> restore(int bookmarkId) async {
    final changed = await (database.update(database.bookmarks)
          ..where((bookmark) => bookmark.id.equals(bookmarkId)))
        .write(const BookmarksCompanion(
          storageState: Value('active'),
          deletedAt: Value(null),
        ));
    if (changed == 0) {
      throw StateError('復元対象のブックマークが見つかりませんでした (id=$bookmarkId)');
    }
    await _syncLegacyState(bookmarkId, inbox: false, deletedAt: null);

    final verification = await (database.select(database.bookmarks)
          ..where((bookmark) => bookmark.id.equals(bookmarkId)))
        .getSingleOrNull();
    if (verification == null ||
        verification.storageState == 'trash' ||
        verification.deletedAt != null) {
      throw StateError('復元状態を保存できませんでした (id=$bookmarkId)');
    }
  }

  Future<void> _syncLegacyState(
    int bookmarkId, {
    required bool inbox,
    required DateTime? deletedAt,
  }) async {
    await database.customStatement(
      'UPDATE bookmarks SET inbox_state = ?, deleted_at_state = ? WHERE id = ?',
      [inbox ? 1 : 0, deletedAt?.toIso8601String(), bookmarkId],
    );
  }

  Future<void> remove(int bookmarkId) async {}

  Future<void> dispose() async {}
}
