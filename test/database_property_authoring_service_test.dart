import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_property_authoring_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Relation target catalog preserves built-in versus custom ObjectType kind',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final service = DatabasePropertyAuthoringService(objectStore);

    final imageType = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'image',
      name: 'Image',
      icon: '🖼️',
    );
    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
      icon: '📚',
    );

    final targets = await service.relationTargets(workspaceId: workspaceId);
    final image = targets.firstWhere((target) => target.id == imageType.id);
    final book = targets.firstWhere((target) => target.id == bookTypeId);

    expect(image.kind, ObjectTypeKind.system);
    expect(book.kind, ObjectTypeKind.custom);
    expect(image.name, 'Image');
    expect(book.name, 'Book');
  });

  test('creates Relation Property through canonical target/cardinality contract',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = DatabasePropertyAuthoringService(objectStore);

    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Plant',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Image',
    );

    final propertyId = await service.createProperty(
      objectTypeId: sourceTypeId,
      name: '  Cover  ',
      type: ObjectPropertyType.objectRelation,
      relationTargetObjectTypeId: targetTypeId,
      relationMultiple: false,
    );

    final property = (await objectStore.getObjectType(sourceTypeId))!
        .properties
        .firstWhere((candidate) => candidate.id == propertyId);
    expect(property.name, 'Cover');
    expect(property.type, ObjectPropertyType.objectRelation);
    expect(property.targetObjectTypeId, targetTypeId);
    expect(property.allowsMultipleRelations, isFalse);
  });

  test('ordinary Property creation preserves config and rejects Relation-only data',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = DatabasePropertyAuthoringService(objectStore);
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Project',
    );

    final propertyId = await service.createProperty(
      objectTypeId: typeId,
      name: 'Status',
      type: ObjectPropertyType.select,
      config: const <String, dynamic>{
        'options': ['Todo', 'Doing', 'Done'],
      },
    );
    final property = (await objectStore.getObjectType(typeId))!
        .properties
        .firstWhere((candidate) => candidate.id == propertyId);
    expect(property.config['options'], ['Todo', 'Doing', 'Done']);

    await expectLater(
      service.createProperty(
        objectTypeId: typeId,
        name: 'Broken',
        type: ObjectPropertyType.text,
        relationTargetObjectTypeId: typeId,
      ),
      throwsArgumentError,
    );
  });

  test('cross-workspace Relation target fails through ObjectStore validation',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceStore = WorkspaceStore(database);
    final firstWorkspace = await workspaceStore.initialize();
    final secondWorkspace = await workspaceStore.createWorkspace('Other');
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = DatabasePropertyAuthoringService(objectStore);

    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: firstWorkspace,
      name: 'Book',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: secondWorkspace,
      name: 'Person',
    );

    await expectLater(
      service.createProperty(
        objectTypeId: sourceTypeId,
        name: 'Author',
        type: ObjectPropertyType.objectRelation,
        relationTargetObjectTypeId: targetTypeId,
      ),
      throwsArgumentError,
    );
  });
}
