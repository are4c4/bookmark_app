import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_file_detail_panel.dart';
import 'package:bookmark_app/services/canonical_file_action_service.dart';
import 'package:bookmark_app/services/canonical_file_export_service.dart';
import 'package:bookmark_app/services/canonical_file_pdf_preview_service.dart';
import 'package:bookmark_app/services/file_managed_resource_resolver.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late CanonicalFileActionService actions;
  late CanonicalFileExportService exporter;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final store = GenericDatabaseStore(database);
    final objectStore = ObjectStore(store);
    final resources = CanonicalFileManagedResourceResolver(
      objectStore: objectStore,
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      pathResolver: database.pathResolver,
    );
    actions = CanonicalFileActionService(
      resources: resources,
      openPath: (_) async => true,
      revealPath: (_) async => true,
    );
    exporter = CanonicalFileExportService(resources: resources);
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('composes PDF preview and native actions for one File identity',
      (tester) async {
    var requestedTypeId = 0;
    var requestedObjectId = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectFileDetailPanel(
            actions: actions,
            exporter: exporter,
            fileObjectTypeId: 12,
            fileObjectId: 34,
            maxPreviewHeight: 160,
            previewResolver: ({
              required fileObjectTypeId,
              required fileObjectId,
            }) async {
              requestedTypeId = fileObjectTypeId;
              requestedObjectId = fileObjectId;
              return const CanonicalFilePdfPreview(
                fileObjectId: 34,
                pngBytes: <int>[1, 2, 3],
              );
            },
            previewImageBuilder: (_, __) => const SizedBox.expand(
              key: ValueKey('panel-pdf-image'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requestedTypeId, 12);
    expect(requestedObjectId, 34);
    expect(
      find.byKey(const ValueKey('object-file-detail-panel-34')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('object-file-pdf-preview-34')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('panel-pdf-image')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('object-file-detail-actions-34')),
      findsOneWidget,
    );

    final previewBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('object-file-pdf-preview-34')))
        .dy;
    final actionsTop = tester
        .getTopLeft(find.byKey(const ValueKey('object-file-detail-actions-34')))
        .dy;
    expect(actionsTop - previewBottom, 12);
  });

  testWidgets('non-PDF File reserves no preview space before native actions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectFileDetailPanel(
            actions: actions,
            exporter: exporter,
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
    final panelTop = tester
        .getTopLeft(find.byKey(const ValueKey('object-file-detail-panel-35')))
        .dy;
    final actionsTop = tester
        .getTopLeft(find.byKey(const ValueKey('object-file-detail-actions-35')))
        .dy;
    expect(actionsTop, panelTop);
    expect(find.text('開く'), findsOneWidget);
    expect(find.text('場所を表示'), findsOneWidget);
    expect(find.text('書き出す'), findsOneWidget);
  });
}
