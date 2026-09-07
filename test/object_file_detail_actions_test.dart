import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_file_detail_actions.dart';
import 'package:bookmark_app/services/canonical_file_action_service.dart';
import 'package:bookmark_app/services/canonical_file_export_service.dart';
import 'package:bookmark_app/services/file_managed_resource_resolver.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late File managed;
  late AppDatabase database;
  late FileObjectDefinition definition;
  late int fileObjectId;
  late CanonicalFileManagedResourceResolver resources;
  late CanonicalFileExportService exporter;
  late List<String> actionCalls;
  late CanonicalFileActionService actions;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('object_file_actions_');
    managed = File('${root.path}/attachments/report.txt');
    await managed.parent.create(recursive: true);
    await managed.writeAsString('canonical file bytes');

    database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: root.path,
    );
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final files = FileObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    definition = await files.ensureDefinition(workspaceId);
    final fileObject = await files.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: managed.path,
      originalFilename: 'report.txt',
      contentType: 'text/plain',
      sizeBytes: await managed.length(),
    );
    fileObjectId = fileObject.id;
    resources = CanonicalFileManagedResourceResolver(
      objectStore: objectStore,
      systemObjects: systemObjects,
      pathResolver: database.pathResolver,
    );
    exporter = CanonicalFileExportService(resources: resources);
    actionCalls = <String>[];
    actions = CanonicalFileActionService(
      resources: resources,
      openPath: (path) async {
        actionCalls.add('open:$path');
        return true;
      },
      revealPath: (path) async {
        actionCalls.add('reveal:$path');
        return true;
      },
    );
  });

  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });

  testWidgets('routes open reveal and export through canonical File services',
      (tester) async {
    final exportDirectory = Directory('${root.path}/exports');
    await exportDirectory.create();
    final destination = '${exportDirectory.path}/report-copy.txt';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectFileDetailActions(
            actions: actions,
            exporter: exporter,
            fileObjectTypeId: definition.objectType.id,
            fileObjectId: fileObjectId,
            exportDestinationPicker: () async => destination,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(ValueKey('object-file-open-$fileObjectId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('object-file-reveal-$fileObjectId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('object-file-export-$fileObjectId')));
    await tester.pumpAndSettle();

    expect(
      actionCalls,
      <String>['open:${managed.path}', 'reveal:${managed.path}'],
    );
    expect(await File(destination).readAsString(), 'canonical file bytes');
    expect(
      find.byKey(const ValueKey('object-file-detail-actions-error')),
      findsNothing,
    );
  });

  testWidgets('action failure shows only stable path-free presentation error',
      (tester) async {
    final failingActions = CanonicalFileActionService(
      resources: resources,
      openPath: (_) async => false,
      revealPath: (_) async => false,
    );
    Object? capturedError;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectFileDetailActions(
            actions: failingActions,
            exporter: exporter,
            fileObjectTypeId: definition.objectType.id,
            fileObjectId: fileObjectId,
            exportDestinationPicker: () async => null,
            onError: (error) => capturedError = error,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(ValueKey('object-file-open-$fileObjectId')));
    await tester.pumpAndSettle();

    expect(capturedError, isA<CanonicalFileActionException>());
    expect(find.text('ファイル操作に失敗しました。'), findsOneWidget);
    expect(find.textContaining(managed.path), findsNothing);
    expect(find.textContaining('report.txt'), findsNothing);
  });
}
