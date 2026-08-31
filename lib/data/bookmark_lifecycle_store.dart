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

  /// Imports data from pre-v11 runtime tables/columns when they still exist.
  ///
  /// Normal reads and writes use the Drift-managed bookmark columns only.
  /// Raw SQL is intentionally limited to compatibility discovery/reading here.
  Future<void> initialize() async {
    final columns = await database.customSelect('PRAGMA table_info(bookmarks)').get();
    final columnNames = columns.map((row) => row.read<String>('name')).toSet();

    final legacyTables = await database.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'bookmark_lifecycle'",
    ).get();
    if (legacyTables.isNotEmpty) {
      final rows = await database.customSelect(
        'SELECT bookmark_id, inbox, deleted_at FROM bookmark_lifecycle',
      ).get();
      for (final row in rows) {
        final bookmarkId = row.read<int>('bookmark_id');
        final inbox = row.read<int>('inbox') == 1;
        final rawDeletedAt = row.readNullable<String>('deleted_at');
        final deletedAt = rawDeletedAt == null ? null : DateTime.tryParse(rawDeletedAt);
        await (database.update(database.bookmarks)
              ..where((bookmark) => bookmark.id.equals(bookmarkId)))
            .write(
          BookmarksCompanion(
            storageState: Value(deletedAt != null ? 'trash' : inbox ? 'inbox' : 'active'),
            deletedAt: Value(deletedAt),
          ),
        );
      }
      await database.customStatement('DROP TABLE bookmark_lifecycle');
    }

    // Some development builds created legacy columns directly on bookmarks.
    // Import their values once when present, without recreating or dual-writing them.
    if (columnNames.contains('inbox_state') ||
        columnNames.contains('deleted_at_state') ||
        columnNames.contains('genre_state')) {
      final selectColumns = <String>[
        'id',
        if (columnNames.contains('inbox_state')) 'inbox_state',
        if (columnNames.contains('deleted_at_state')) 'deleted_at_state',
        if (columnNames.contains('genre_state')) 'genre_state',
      ].join(', ');
      final rows = await database.customSelect('SELECT $selectColumns FROM bookmarks').get();

      for (final row in rows) {
        final id = row.read<int>('id');
        final current = await (database.select(database.bookmarks)
              ..where((bookmark) => bookmark.id.equals(id)))
            .getSingleOrNull();
        if (current == null) continue;

        final inbox = columnNames.contains('inbox_state')
            ? row.readNullable<int>('inbox_state') == 1
            : false;
        final rawDeletedAt = columnNames.contains('deleted_at_state')
            ? row.readNullable<String>('deleted_at_state')
            : null;
        final legacyDeletedAt = rawDeletedAt == null ? null : DateTime.tryParse(rawDeletedAt);
        final legacyGenre = columnNames.contains('genre_state')
            ? row.readNullable<String>('genre_state')?.trim() ?? ''
            : '';

        final shouldImportStorage = current.storageState == 'active' &&
            (legacyDeletedAt != null || inbox);
        final shouldImportGenre = current.genre.isEmpty && legacyGenre.isNotEmpty;
        final shouldImportDeletedAt = current.deletedAt == null && legacyDeletedAt != null;
        if (!shouldImportStorage && !shouldImportGenre && !shouldImportDeletedAt) continue;

        await (database.update(database.bookmarks)
              ..where((bookmark) => bookmark.id.equals(id)))
            .write(
          BookmarksCompanion(
            storageState: shouldImportStorage
                ? Value(legacyDeletedAt != null ? 'trash' : 'inbox')
                : const Value.absent(),
            deletedAt: shouldImportDeletedAt ? Value(legacyDeletedAt) : const Value.absent(),
            genre: shouldImportGenre ? Value(legacyGenre) : const Value.absent(),
          ),
        );
      }
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

    final verification = await (database.select(database.bookmarks)
          ..where((bookmark) => bookmark.id.equals(bookmarkId)))
        .getSingleOrNull();
    if (verification == null ||
        verification.storageState == 'trash' ||
        verification.deletedAt != null) {
      throw StateError('復元状態を保存できませんでした (id=$bookmarkId)');
    }
  }

  Future<void> remove(int bookmarkId) async {}

  Future<void> dispose() async {}
}
