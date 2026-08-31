import 'dart:async';

import 'package:drift/drift.dart';

import 'app_database.dart';

class BookmarkAttachment {
  const BookmarkAttachment({
    required this.id,
    required this.bookmarkId,
    required this.fileName,
    required this.path,
    required this.kind,
    required this.sizeBytes,
    required this.createdAt,
  });

  final int id;
  final int bookmarkId;
  final String fileName;
  final String path;
  final String kind;
  final int sizeBytes;
  final DateTime createdAt;

  bool get isPdf => kind == 'pdf';
  bool get isVideo => kind == 'video';
}

class BookmarkAttachmentStore {
  BookmarkAttachmentStore(this.database);

  final AppDatabase database;
  final _changes = StreamController<void>.broadcast();

  Future<void> initialize() async {
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS bookmark_attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookmark_id INTEGER NOT NULL REFERENCES bookmarks(id) ON DELETE CASCADE,
        file_name TEXT NOT NULL,
        path TEXT NOT NULL UNIQUE,
        kind TEXT NOT NULL DEFAULT 'file',
        size_bytes INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS bookmark_attachments_bookmark_id_idx '
      'ON bookmark_attachments(bookmark_id)',
    );
  }

  BookmarkAttachment _fromRow(QueryRow row) => BookmarkAttachment(
        id: row.read<int>('id'),
        bookmarkId: row.read<int>('bookmark_id'),
        fileName: row.read<String>('file_name'),
        path: row.read<String>('path'),
        kind: row.read<String>('kind'),
        sizeBytes: row.read<int>('size_bytes'),
        createdAt: DateTime.tryParse(row.read<String>('created_at')) ?? DateTime.now(),
      );

  Future<List<BookmarkAttachment>> listForBookmark(int bookmarkId) async {
    final rows = await database.customSelect(
      '''
      SELECT id, bookmark_id, file_name, path, kind, size_bytes, created_at
      FROM bookmark_attachments
      WHERE bookmark_id = ?
      ORDER BY created_at DESC
      ''',
      variables: [Variable<int>(bookmarkId)],
    ).get();
    return rows.map(_fromRow).toList();
  }

  Stream<List<BookmarkAttachment>> watchForBookmark(int bookmarkId) async* {
    yield await listForBookmark(bookmarkId);
    await for (final _ in _changes.stream) {
      yield await listForBookmark(bookmarkId);
    }
  }

  Future<int> add({
    required int bookmarkId,
    required String fileName,
    required String path,
    required String kind,
    required int sizeBytes,
  }) async {
    await database.customStatement(
      '''
      INSERT INTO bookmark_attachments
        (bookmark_id, file_name, path, kind, size_bytes, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ''',
      [
        bookmarkId,
        fileName,
        path,
        kind,
        sizeBytes,
        DateTime.now().toIso8601String(),
      ],
    );
    final row = await database.customSelect(
      'SELECT id FROM bookmark_attachments WHERE path = ?',
      variables: [Variable<String>(path)],
    ).getSingle();
    _changes.add(null);
    return row.read<int>('id');
  }

  Future<void> remove(int id) async {
    await database.customUpdate(
      'DELETE FROM bookmark_attachments WHERE id = ?',
      variables: [Variable<int>(id)],
    );
    _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
