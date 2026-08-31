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

  Future<void> initialize() async {
    // Schema v13 owns pdf_annotations and its index.
  }

  PdfAnnotationRecord _fromRow(PdfAnnotationRow row) => PdfAnnotationRecord(
        id: row.id,
        attachmentId: row.attachmentId,
        pageNumber: row.pageNumber,
        kind: row.kind,
        selectedText: row.selectedText,
        note: row.note,
        createdAt: DateTime.tryParse(row.createdAt) ?? DateTime.now(),
      );

  Future<List<PdfAnnotationRecord>> listForAttachment(int attachmentId) async =>
      (await (database.select(database.pdfAnnotations)
                ..where((annotation) => annotation.attachmentId.equals(attachmentId))
                ..orderBy([
                  (annotation) => OrderingTerm.asc(annotation.pageNumber),
                  (annotation) => OrderingTerm.asc(annotation.createdAt),
                ]))
              .get())
          .map(_fromRow)
          .toList();

  Stream<List<PdfAnnotationRecord>> watchForAttachment(int attachmentId) =>
      (database.select(database.pdfAnnotations)
            ..where((annotation) => annotation.attachmentId.equals(attachmentId))
            ..orderBy([
              (annotation) => OrderingTerm.asc(annotation.pageNumber),
              (annotation) => OrderingTerm.asc(annotation.createdAt),
            ]))
          .watch()
          .map((rows) => rows.map(_fromRow).toList());

  Future<void> add({
    required int attachmentId,
    required int pageNumber,
    required String kind,
    String selectedText = '',
    String note = '',
  }) async {
    await database.into(database.pdfAnnotations).insert(
          PdfAnnotationsCompanion.insert(
            attachmentId: attachmentId,
            pageNumber: pageNumber,
            kind: Value(kind),
            selectedText: Value(selectedText.trim()),
            note: Value(note.trim()),
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
  }

  Future<void> remove(int id) async {
    await (database.delete(database.pdfAnnotations)..where((annotation) => annotation.id.equals(id))).go();
  }

  Future<void> dispose() async {}
}
