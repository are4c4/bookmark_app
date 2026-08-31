import 'dart:async';

import 'package:drift/drift.dart';

import 'app_database.dart';

class PdfAnnotationRecord {
  const PdfAnnotationRecord({
    required this.id,
    required this.attachmentId,
    required this.pageNumber,
    required this.kind,
    required this.selectedText,
    required this.note,
    required this.createdAt,
  });

  final int id;
  final int attachmentId;
  final int pageNumber;
  final String kind;
  final String selectedText;
  final String note;
  final DateTime createdAt;
}

class PdfAnnotationStore {
  PdfAnnotationStore(this.database);

  final AppDatabase database;
  final _changes = StreamController<void>.broadcast();

  Future<void> initialize() async {
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS pdf_annotations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        attachment_id INTEGER NOT NULL REFERENCES bookmark_attachments(id) ON DELETE CASCADE,
        page_number INTEGER NOT NULL,
        kind TEXT NOT NULL DEFAULT 'note',
        selected_text TEXT NOT NULL DEFAULT '',
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS pdf_annotations_attachment_idx '
      'ON pdf_annotations(attachment_id, page_number)',
    );
  }

  PdfAnnotationRecord _fromRow(QueryRow row) => PdfAnnotationRecord(
        id: row.read<int>('id'),
        attachmentId: row.read<int>('attachment_id'),
        pageNumber: row.read<int>('page_number'),
        kind: row.read<String>('kind'),
        selectedText: row.read<String>('selected_text'),
        note: row.read<String>('note'),
        createdAt: DateTime.tryParse(row.read<String>('created_at')) ?? DateTime.now(),
      );

  Future<List<PdfAnnotationRecord>> listForAttachment(int attachmentId) async {
    final rows = await database.customSelect(
      '''
      SELECT id, attachment_id, page_number, kind, selected_text, note, created_at
      FROM pdf_annotations
      WHERE attachment_id = ?
      ORDER BY page_number, created_at
      ''',
      variables: [Variable<int>(attachmentId)],
    ).get();
    return rows.map(_fromRow).toList();
  }

  Stream<List<PdfAnnotationRecord>> watchForAttachment(int attachmentId) async* {
    yield await listForAttachment(attachmentId);
    await for (final _ in _changes.stream) {
      yield await listForAttachment(attachmentId);
    }
  }

  Future<void> add({
    required int attachmentId,
    required int pageNumber,
    required String kind,
    String selectedText = '',
    String note = '',
  }) async {
    await database.customStatement(
      '''
      INSERT INTO pdf_annotations
        (attachment_id, page_number, kind, selected_text, note, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ''',
      [
        attachmentId,
        pageNumber,
        kind,
        selectedText.trim(),
        note.trim(),
        DateTime.now().toIso8601String(),
      ],
    );
    _changes.add(null);
  }

  Future<void> remove(int id) async {
    await database.customUpdate(
      'DELETE FROM pdf_annotations WHERE id = ?',
      variables: [Variable<int>(id)],
    );
    _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
