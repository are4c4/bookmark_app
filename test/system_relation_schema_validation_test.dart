import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('system Relation creation uses canonical target and workspace validation',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
    final otherWorkspaceId = await workspaceStore.createWorkspace('Other');
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final systemStore = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );

    final source = await systemStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'source',
      name: 'Source',
      icon: 'S',
    );
    final target = await systemStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'target',
      name: 'Target',
      icon: 'T',
    );
    final otherTarget = await systemStore.ensureSystemObjectType(
      workspaceId: otherWorkspaceId,
      systemKey: 'other-target',
      name: 'Other target',
      icon: 'O',
    );

    final created = await systemStore.ensureRelationProperty(
      objectTypeId: source.id,
      name: 'Related',
      targetObjectTypeId: target.id,
      multiple: false,
    );
    final repeated = await systemStore.ensureRelationProperty(
      objectTypeId: source.id,
      name: 'Related',
      targetObjectTypeId: target.id,
      multiple: false,
    );

    expect(repeated.id, created.id);
    expect(created.isRelation, isTrue);
    expect(created.targetObjectTypeId, target.id);
    expect(created.allowsMultipleRelations, isFalse);

    await expectLater(
      systemStore.ensureRelationProperty(
        objectTypeId: source.id,
        name: 'Cross workspace',
        targetObjectTypeId: otherTarget.id,
      ),
      throwsArgumentError,
    );
    final refreshed = await objectStore.getObjectType(source.id);
    expect(
      refreshed!.properties.where((property) => property.name == 'Cross workspace'),
      isEmpty,
    );
  });

  test('system Relation ensure fails closed on an incompatible existing Property',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final systemStore = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );

    final source = await systemStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'source',
      name: 'Source',
      icon: 'S',
    );
    final target = await systemStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'target',
      name: 'Target',
      icon: 'T',
    );
    final existing = await systemStore.ensureProperty(
      objectTypeId: source.id,
      name: 'Related',
      type: ObjectPropertyType.text,
    );

    await expectLater(
      systemStore.ensureRelationProperty(
        objectTypeId: source.id,
        name: 'Related',
        targetObjectTypeId: target.id,
      ),
      throwsStateError,
    );

    final refreshed = (await objectStore.getObjectType(source.id))!
        .properties
        .singleWhere((property) => property.id == existing.id);
    expect(refreshed.type, ObjectPropertyType.text);
  });

  test('system Relation ensure rejects target or cardinality drift', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final systemStore = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );

    final source = await systemStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'source',
      name: 'Source',
      icon: 'S',
    );
    final target = await systemStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'target',
      name: 'Target',
      icon: 'T',
    );
    final alternateTarget = await systemStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'alternate-target',
      name: 'Alternate target',
      icon: 'A',
    );
    final property = await systemStore.ensureRelationProperty(
      objectTypeId: source.id,
      name: 'Related',
      targetObjectTypeId: target.id,
      multiple: false,
    );

    await expectLater(
      systemStore.ensureRelationProperty(
        objectTypeId: source.id,
        name: 'Related',
        targetObjectTypeId: alternateTarget.id,
        multiple: false,
      ),
      throwsStateError,
    );
    await expectLater(
      systemStore.ensureRelationProperty(
        objectTypeId: source.id,
        name: 'Related',
        targetObjectTypeId: target.id,
        multiple: true,
      ),
      throwsStateError,
    );

    final refreshed = (await objectStore.getObjectType(source.id))!
        .properties
        .singleWhere((candidate) => candidate.id == property.id);
    expect(refreshed.targetObjectTypeId, target.id);
    expect(refreshed.allowsMultipleRelations, isFalse);
  });
}
