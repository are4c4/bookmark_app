import 'package:bookmark_app/features/object/presentation/widgets/object_file_pdf_preview.dart';
import 'package:bookmark_app/services/canonical_file_pdf_preview_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders transient PDF preview bytes for the canonical File',
      (tester) async {
    var requestedTypeId = 0;
    var requestedObjectId = 0;
    List<int>? renderedBytes;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectFilePdfPreview(
            fileObjectTypeId: 12,
            fileObjectId: 34,
            maxHeight: 240,
            previewResolver: ({
              required fileObjectTypeId,
              required fileObjectId,
            }) async {
              requestedTypeId = fileObjectTypeId;
              requestedObjectId = fileObjectId;
              return const CanonicalFilePdfPreview(
                fileObjectId: 34,
                pngBytes: <int>[1, 2, 3, 4],
              );
            },
            imageBuilder: (context, bytes) {
              renderedBytes = List<int>.of(bytes);
              return const ColoredBox(color: Colors.black);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requestedTypeId, 12);
    expect(requestedObjectId, 34);
    expect(renderedBytes, <int>[1, 2, 3, 4]);
    expect(
      find.byKey(const ValueKey('object-file-pdf-preview-34')),
      findsOneWidget,
    );
  });

  testWidgets('non-PDF or unavailable preview adds no PDF-specific empty state',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectFilePdfPreview(
            fileObjectTypeId: 12,
            fileObjectId: 35,
            previewResolver: ({
              required fileObjectTypeId,
              required fileObjectId,
            }) async => null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('object-file-pdf-preview-35')),
      findsNothing,
    );
    expect(find.textContaining('PDF'), findsNothing);
    expect(find.textContaining('プレビュー'), findsNothing);
  });

  testWidgets('resolver failure stays out of presentation text', (tester) async {
    Object? receivedError;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectFilePdfPreview(
            fileObjectTypeId: 12,
            fileObjectId: 36,
            previewResolver: ({
              required fileObjectTypeId,
              required fileObjectId,
            }) async {
              throw StateError(
                'private preview failure /Users/example/secret-paper.pdf',
              );
            },
            onError: (error) => receivedError = error,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(receivedError, isA<StateError>());
    expect(find.textContaining('private preview failure'), findsNothing);
    expect(find.textContaining('/Users/example'), findsNothing);
    expect(
      find.byKey(const ValueKey('object-file-pdf-preview-36')),
      findsNothing,
    );
  });
}
