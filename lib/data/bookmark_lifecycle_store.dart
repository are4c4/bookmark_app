import 'dart:async';

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
      '''
      SELECT
        id AS bookmark_id,
        inbox_state AS inbox,
        deleted_at_state AS deleted_at,
        CASE WHEN deleted_at_state IS NULL THEN 0 ELSE 1 END AS is_deleted
      FROM bookmarks
      ''',
      readsFrom: {database.bookmarks},
    ).get();

    return {
      for (final row in rows)
        row.read<int>('bookmark_id'): BookmarkLifecycleState(
          bookmarkId: row.read<int>('bookmark_id'),
          inbox: row.read<int>('inbox') != 0,
          deleted: row.read<int>('is_deleted') != 0,
          deletedAt: _parseDeletedAt(row.readNullable<String>('deleted_at')),
        ),
    };
  }

  DateTime? _parseDeletedAt(String? value) {
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  Future<void> ensureBookmark(int bookmarkId, {bool inbox = false}) async {
    final changed = await database.customUpdate(
      'UPDATE bookmarks SET inbox_state = ?, deleted_at_state = NULL WHERE id = ?',
      variables: [Variable<int>(inbox ? 1 : 0), Variable<int>(bookmarkId)],
      updates: {database.bookmarks},
    );
    if (changed == 0) {
      throw StateError('ブックマーク状態を初期化できませんでした (id=$bookmarkId)');
    }
    _changes.add(null);
  }

  Future<void> setInbox(int bookmarkId, bool value) async {
    final changed = await database.customUpdate(
      'UPDATE bookmarks SET inbox_state = ?, deleted_at_state = NULL WHERE id = ?',
      variables: [Variable<int>(value ? 1 : 0), Variable<int>(bookmarkId)],
      updates: {database.bookmarks},
    );
    if (changed == 0) {
      throw StateError('Inbox状態を更新できませんでした (id=$bookmarkId)');
    }
    _changes.add(null);
  }

  Future<void> moveToTrash(int bookmarkId) async {
    final deletedAt = DateTime.now().toIso8601String();
    final changed = await database.customUpdate(
      'UPDATE bookmarks SET inbox_state = 0, deleted_at_state = ? WHERE id = ?',
      variables: [Variable<String>(deletedAt), Variable<int>(bookmarkId)],
      updates: {database.bookmarks},
    );
    if (changed == 0) {
      throw StateError('削除対象のブックマークが見つかりませんでした (id=$bookmarkId)');
    }

    // Read the same row back immediately. This makes a silent no-op impossible:
    // either the state is persisted or the caller receives an explicit error.
    final verification = await database.customSelect(
      '''
      SELECT
        deleted_at_state,
        CASE WHEN deleted_at_state IS NULL THEN 0 ELSE 1 END AS is_deleted
      FROM bookmarks
      WHERE id = ?
      ''',
      variables: [Variable<int>(bookmarkId)],
      readsFrom: {database.bookmarks},
    ).getSingleOrNull();

    if (verification == null || verification.read<int>('is_deleted') == 0) {
      throw StateError('ゴミ箱への移動状態を保存できませんでした (id=$bookmarkId)');
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

    final verification = await database.customSelect(
      '''
      SELECT CASE WHEN deleted_at_state IS NULL THEN 1 ELSE 0 END AS is_restored
      FROM bookmarks
      WHERE id = ?
      ''',
      variables: [Variable<int>(bookmarkId)],
      readsFrom: {database.bookmarks},
    ).getSingleOrNull();

    if (verification == null || verification.read<int>('is_restored') == 0) {
      throw StateError('復元状態を保存できませんでした (id=$bookmarkId)');
    }

    _changes.add(null);
  }

  Future<void> remove(int bookmarkId) async {
    // Permanent deletion removes the bookmark row immediately after this call.
    _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
