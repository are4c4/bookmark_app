import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_management_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'duplicateSchema preserves safe Relation metadata through canonical creation',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final management = ObjectTypeManagementStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final sourceId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    final targetId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Target',
    );
    await genericStore.createProperty(
      databaseId: sourceId,
      name: 'Related',
      type: 'relation',
      config: <String, dynamic>{
        'targetObjectTypeId': targetId,
        'multiple': false,
        'searchable': false,
        'displayHint': 'compact',
        'bidirectional': true,
        'inversePropertyId': 999,
        'pairRole': 'source',
      },
    );

    final copyId = await management.duplicateSchema(objectTypeId: sourceId);
    final copiedType = (await objectStore.getObjectType(copyId))!;
    final relation = copiedType.properties.single;

    expect(relation.targetObjectTypeId, targetId);
    expect(relation.allowsMultipleRelations, isFalse);
    expect(relation.config['searchable'], isFalse);
    expect(relation.config['displayHint'], 'compact');
    expect(relation.config['bidirectional'], isNull);
    expect(relation.config['inversePropertyId'], isNull);
    expect(relation.config['pairRole'], isNull);
  });

  test('duplicateSchema rejects cross-workspace Relation targets atomically',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
    final otherWorkspaceId = await workspaceStore.createWorkspace('Other');
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final management = ObjectTypeManagementStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final sourceId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    final foreignTargetId = await objectStore.createObjectType(
      workspaceId: otherWorkspaceId,
      name: 'Foreign target',
    );
    await genericStore.createProperty(
      databaseId: sourceId,
      name: 'Broken cross-workspace relation',
      type: 'relation',
      config: <String, dynamic>{
        'targetObjectTypeId': foreignTargetId,
        'multiple': true,
      },
    );

    await expectLater(
      management.duplicateSchema(objectTypeId: sourceId),
      throwsArgumentError,
    );

    final sourceWorkspaceTypes = await objectStore.listObjectTypes(workspaceId);
    expect(sourceWorkspaceTypes.map((type) => type.id).toList(), <int>[sourceId]);
  });
}
