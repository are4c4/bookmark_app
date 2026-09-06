import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_management_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('duplicated Relation uses canonical schema and preserves safe metadata',
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

    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Author',
      targetObjectTypeId: targetTypeId,
      multiple: false,
      metadata: const <String, dynamic>{
        'searchable': false,
        'hidden': true,
      },
    );

    final duplicatedId = await management.duplicateSchema(
      objectTypeId: sourceTypeId,
    );
    final relation = (await objectStore.getObjectType(duplicatedId))!
        .properties
        .singleWhere((property) => property.name == 'Author');

    expect(relation.isRelation, isTrue);
    expect(relation.targetObjectTypeId, targetTypeId);
    expect(relation.allowsMultipleRelations, isFalse);
    expect(relation.config['searchable'], isFalse);
    expect(relation.config['hidden'], isTrue);
    expect(relation.config['bidirectional'], isNull);
    expect(relation.config['inversePropertyId'], isNull);
    expect(relation.config['pairRole'], isNull);
  });

  test('duplicate rolls back when persisted Relation targets another workspace',
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

    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    final otherTargetTypeId = await objectStore.createObjectType(
      workspaceId: otherWorkspaceId,
      name: 'Other target',
    );

    // Simulate historical/corrupt schema by deliberately bypassing the
    // canonical Relation creation boundary.
    await objectStore.createProperty(
      objectTypeId: sourceTypeId,
      name: 'Invalid relation',
      type: ObjectPropertyType.objectRelation,
      config: <String, dynamic>{
        'targetObjectTypeId': otherTargetTypeId,
        'multiple': true,
      },
    );

    await expectLater(
      management.duplicateSchema(objectTypeId: sourceTypeId),
      throwsArgumentError,
    );

    final types = await objectStore.listObjectTypes(workspaceId);
    expect(types.where((type) => type.name == 'Source のコピー'), isEmpty);
    final source = types.singleWhere((type) => type.id == sourceTypeId);
    expect(source.properties.single.name, 'Invalid relation');
  });
}
