import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_file_detail_panel_host.dart';
import 'package:bookmark_app/services/canonical_file_detail_capabilities.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders only for the registered canonical File ObjectType',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final fileType = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: FileObjectService.systemKey,
      name: 'File',
      icon: '📄',
    );
    final customTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Custom attachment',
      icon: '📎',
    );
    final fileObjectId = await objectStore.createObject(
      objectTypeId: fileType.id,
      title: 'Canonical file',
    );
    final customObjectId = await objectStore.createObject(
      objectTypeId: customTypeId,
      title: 'Custom file-like Object',
    );
    final capabilities = CanonicalFileDetailCapabilities.fromDatabase(
      database: database,
      objectStore: objectStore,
    );

    final requests = <String>[];
    Widget host({required int typeId, required int objectId}) => MaterialApp(
          home: Scaffold(
            body: ObjectFileDetailPanelHost(
              key: const ValueKey('host'),
              capabilities: capabilities,
              fileObjectTypeId: typeId,
              fileObjectId: objectId,
              panelBuilder: (
                context, {
                required fileObjectTypeId,
                required fileObjectId,
              }) {
                requests.add('$fileObjectTypeId:$fileObjectId');
                return const SizedBox(
                  key: ValueKey('canonical-file-panel'),
                );
              },
            ),
          ),
        );

    await tester.pumpWidget(
      host(typeId: fileType.id, objectId: fileObjectId),
    );
    await tester.pumpAndSettle();
    expect(requests, <String>['${fileType.id}:$fileObjectId']);
    expect(
      find.byKey(const ValueKey('canonical-file-panel')),
      findsOneWidget,
    );

    requests.clear();
    await tester.pumpWidget(
      host(typeId: customTypeId, objectId: customObjectId),
    );
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    expect(
      find.byKey(const ValueKey('canonical-file-panel')),
      findsNothing,
    );
  });

  testWidgets('invalid identity fails closed before panel composition',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final capabilities = CanonicalFileDetailCapabilities.fromDatabase(
      database: database,
      objectStore: objectStore,
    );
    var built = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectFileDetailPanelHost(
            capabilities: capabilities,
            fileObjectTypeId: 0,
            fileObjectId: -1,
            panelBuilder: (
              context, {
              required fileObjectTypeId,
              required fileObjectId,
            }) {
              built = true;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(built, isFalse);
  });
}
