import 'package:bookmark_app/features/object/presentation/widgets/object_file_pdf_summary.dart';
import 'package:bookmark_app/services/canonical_file_pdf_metadata_service.dart';
import 'package:bookmark_app/services/canonical_file_pdf_page_count_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders metadata and page count for one canonical File identity',
      (tester) async {
    final requested = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectFilePdfSummary(
            fileObjectTypeId: 12,
            fileObjectId: 34,
            metadataResolver: ({
              required fileObjectTypeId,
              required fileObjectId,
            }) async {
              requested.add('metadata:$fileObjectTypeId:$fileObjectId');
              return const CanonicalFilePdfMetadata(
                fileObjectId: 34,
                title: '  Paper title  ',
                authors: <String>[' Ada ', '', 'Grace'],
              );
            },
            pageCountResolver: ({
              required fileObjectTypeId,
              required fileObjectId,
            }) async {
              requested.add('pages:$fileObjectTypeId:$fileObjectId');
              return const CanonicalFilePdfPageCount(
                fileObjectId: 34,
                pageCount: 7,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      requested,
      <String>['metadata:12:34', 'pages:12:34'],
    );
    expect(
      find.byKey(const ValueKey('object-file-pdf-summary-34')),
      findsOneWidget,
    );
    expect(find.text('タイトル  Paper title'), findsOneWidget);
    expect(find.text('著者  Ada, Grace'), findsOneWidget);
    expect(find.text('ページ数  7'), findsOneWidget);
  });

  testWidgets('one PDF capability failure does not hide surviving metadata',
      (tester) async {
    final errors = <Object>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectFilePdfSummary(
            fileObjectTypeId: 12,
            fileObjectId: 35,
            metadataResolver: ({
              required fileObjectTypeId,
              required fileObjectId,
            }) async {
              throw StateError(
                'private metadata failure /Users/example/secret.pdf',
              );
            },
            pageCountResolver: ({
              required fileObjectTypeId,
              required fileObjectId,
            }) async => const CanonicalFilePdfPageCount(
              fileObjectId: 35,
              pageCount: 9,
            ),
            onError: errors.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(errors.single, isA<StateError>());
    expect(find.text('ページ数  9'), findsOneWidget);
    expect(find.textContaining('private metadata failure'), findsNothing);
    expect(find.textContaining('/Users/example'), findsNothing);
  });

  testWidgets('empty PDF capability result reserves no presentation state',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectFilePdfSummary(
            fileObjectTypeId: 12,
            fileObjectId: 36,
            metadataResolver: ({
              required fileObjectTypeId,
              required fileObjectId,
            }) async => const CanonicalFilePdfMetadata(
              fileObjectId: 36,
              title: '  ',
              authors: <String>['', '   '],
            ),
            pageCountResolver: ({
              required fileObjectTypeId,
              required fileObjectId,
            }) async => null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('object-file-pdf-summary-36')),
      findsNothing,
    );
    expect(find.text('PDF情報'), findsNothing);
  });
}
