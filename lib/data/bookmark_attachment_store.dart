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

  Future<void> initialize() async {
    // Schema v13 owns bookmark_attachments and its index.
  }

  BookmarkAttachment _fromRow(BookmarkAttachmentRecord row) => BookmarkAttachment(
        id: row.id,
        bookmarkId: row.bookmarkId,
        fileName: row.fileName,
        path: database.resolveStoredPath(row.path),
        kind: row.kind,
        sizeBytes: row.sizeBytes,
        createdAt: DateTime.tryParse(row.createdAt) ?? DateTime.now(),
      );

  Future<List<BookmarkAttachment>> listForBookmark(int bookmarkId) async =>
      (await (database.select(database.bookmarkAttachments)
                ..where((attachment) => attachment.bookmarkId.equals(bookmarkId))
                ..orderBy([(attachment) => OrderingTerm.desc(attachment.createdAt)]))
              .get())
          .map(_fromRow)
          .toList();

  Stream<List<BookmarkAttachment>> watchForBookmark(int bookmarkId) =>
      (database.select(database.bookmarkAttachments)
            ..where((attachment) => attachment.bookmarkId.equals(bookmarkId))
            ..orderBy([(attachment) => OrderingTerm.desc(attachment.createdAt)]))
          .watch()
          .map((rows) => rows.map(_fromRow).toList());

  Future<int> add({
    required int bookmarkId,
    required String fileName,
    required String path,
    required String kind,
    required int sizeBytes,
  }) =>
      database.into(database.bookmarkAttachments).insert(
            BookmarkAttachmentsCompanion.insert(
              bookmarkId: bookmarkId,
              fileName: fileName,
              path: database.toStoredPath(path),
              kind: Value(kind),
              sizeBytes: Value(sizeBytes),
              createdAt: DateTime.now().toIso8601String(),
            ),
          );

  Future<void> remove(int id) async {
    await (database.delete(database.bookmarkAttachments)..where((attachment) => attachment.id.equals(id))).go();
  }

  Future<void> dispose() async {}
}
