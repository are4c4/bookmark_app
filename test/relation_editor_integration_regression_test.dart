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
  late BidirectionalRelationStore bidirectionalStore;
  late ObjectRelationEditorService editor;
  late int workspaceId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    editor = ObjectRelationEditorService(
      targets: RelationTargetService(objectStore),
      mutations: RelationMutationService(
        objectStore: objectStore,
        genericStore: genericStore,
        bidirectionalStore: bidirectionalStore,
      ),
    );
    workspaceId = await WorkspaceStore(database).initialize();
  });

  tearDown(() => database.close());

  test('editor save synchronizes the inverse side of a bidirectional Relation', () async {
    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final pair = await bidirectionalStore.createPair(
      sourceObjectTypeId: bookTypeId,
      sourceName: 'Authors',
      targetObjectTypeId: personTypeId,
      inverseName: 'Books',
    );
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Number Theory',
    );
    final personId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Serre',
    );

    final context = await editor.load(
      workspaceId: workspaceId,
      sourceObjectId: bookId,
      property: pair.sourceProperty,
    );
    await editor.save(context: context, selectedObjectIds: [personId]);

    final book = (await objectStore.listObjects(bookTypeId)).single;
    final person = (await objectStore.listObjects(personTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(book.values[pair.sourceProperty.id]).objectIds,
      [personId],
    );
    expect(
      ObjectRelationValue.fromJson(person.values[pair.inverseProperty.id]).objectIds,
      [bookId],
    );
  });

  test('stale picker context fails closed when a candidate is deleted before save', () async {
    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Target',
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
    final targetId = await objectStore.createObject(
      objectTypeId: targetTypeId,
      title: 'Target',
    );

    final context = await editor.load(
      workspaceId: workspaceId,
      sourceObjectId: sourceId,
      property: property,
    );
    expect(context.candidates.map((object) => object.id), contains(targetId));

    await objectStore.deleteObject(targetId);

    await expectLater(
      editor.save(context: context, selectedObjectIds: [targetId]),
      throwsArgumentError,
    );
    final source = (await objectStore.listObjects(sourceTypeId)).single;
    expect(source.values[property.id], isNull);
  });

  test('loading a picker preserves a legacy missing target value unchanged', () async {
    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Target',
    );
    await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Target',
      targetObjectTypeId: targetTypeId,
      multiple: true,
    );
    final property =
        (await objectStore.getObjectType(sourceTypeId))!.properties.single;
    final sourceId = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Source',
    );
    const missingTargetId = 999999;
    await genericStore.setValue(
      recordId: sourceId,
      propertyId: property.id,
      value: const <String, dynamic>{'objectIds': [missingTargetId]},
    );

    final before = (await objectStore.listObjects(sourceTypeId)).single;
    final context = await editor.load(
      workspaceId: workspaceId,
      sourceObjectId: sourceId,
      property: property,
    );
    final after = (await objectStore.listObjects(sourceTypeId)).single;

    expect(context.missingTargetObjectIds, [missingTargetId]);
    expect(after.values[property.id], before.values[property.id]);
    expect(
      ObjectRelationValue.fromJson(after.values[property.id]).objectIds,
      [missingTargetId],
    );
  });
}
