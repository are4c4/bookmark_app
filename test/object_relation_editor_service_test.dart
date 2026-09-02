import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_relation_editor_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/relation_target_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late GenericDatabaseStore genericStore;
  late ObjectStore objectStore;
  late ObjectRelationEditorService service;
  late int workspaceId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workspaceId = await WorkspaceStore(database).initialize();
    genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    service = ObjectRelationEditorService(
      targets: RelationTargetService(objectStore),
      mutations: RelationMutationService(
        objectStore: objectStore,
        genericStore: genericStore,
        bidirectionalStore: BidirectionalRelationStore(
          genericStore: genericStore,
          objectStore: objectStore,
        ),
      ),
    );
  });

  tearDown(() => database.close());

  test('load uses canonical selection and save persists through mutation facade',
      () async {
    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
    );
    final property = (await objectStore.getObjectType(bookTypeId))!.properties.single;
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Book',
    );
    final authorId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Author',
    );

    final context = await service.load(
      workspaceId: workspaceId,
      sourceObjectId: bookId,
      property: property,
    );
    expect(context.selectedObjectIds, isEmpty);
    expect(context.candidates.map((object) => object.id), [authorId]);

    await service.save(
      context: context,
      selectedObjectIds: [authorId],
    );

    final updated = (await objectStore.listObjects(bookTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(updated.values[property.id]).objectIds,
      [authorId],
    );
  });

  test('save rejects Objects outside canonical picker candidates', () async {
    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Target',
    );
    final otherTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Other',
    );
    await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Target',
      targetObjectTypeId: targetTypeId,
    );
    final property =
        (await objectStore.getObjectType(sourceTypeId))!.properties.single;
    final sourceId = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Source',
    );
    await objectStore.createObject(
      objectTypeId: targetTypeId,
      title: 'Valid',
    );
    final invalidId = await objectStore.createObject(
      objectTypeId: otherTypeId,
      title: 'Invalid',
    );
    final context = await service.load(
      workspaceId: workspaceId,
      sourceObjectId: sourceId,
      property: property,
    );

    await expectLater(
      service.save(context: context, selectedObjectIds: [invalidId]),
      throwsArgumentError,
    );
  });

  test('save enforces canonical single Relation cardinality', () async {
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
    );
    final property =
        (await objectStore.getObjectType(sourceTypeId))!.properties.single;
    final sourceId = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Book',
    );
    final firstId = await objectStore.createObject(
      objectTypeId: targetTypeId,
      title: 'A',
    );
    final secondId = await objectStore.createObject(
      objectTypeId: targetTypeId,
      title: 'B',
    );
    final context = await service.load(
      workspaceId: workspaceId,
      sourceObjectId: sourceId,
      property: property,
    );

    await expectLater(
      service.save(
        context: context,
        selectedObjectIds: [firstId, secondId],
      ),
      throwsArgumentError,
    );
  });
}
