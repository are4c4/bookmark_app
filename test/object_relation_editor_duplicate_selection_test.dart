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
  test('editor preserves duplicate multi-Relation input for canonical rejection',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = ObjectRelationEditorService(
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

    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final propertyId = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Authors',
      targetObjectTypeId: targetTypeId,
      multiple: true,
    );
    final property = (await objectStore.getObjectType(sourceTypeId))!
        .properties
        .singleWhere((item) => item.id == propertyId);
    final sourceId = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Book',
    );
    final originalTargetId = await objectStore.createObject(
      objectTypeId: targetTypeId,
      title: 'Original',
    );
    final duplicateTargetId = await objectStore.createObject(
      objectTypeId: targetTypeId,
      title: 'Duplicate candidate',
    );

    var context = await service.load(
      workspaceId: workspaceId,
      sourceObjectId: sourceId,
      property: property,
    );
    await service.save(
      context: context,
      selectedObjectIds: <int>[originalTargetId],
    );

    context = await service.load(
      workspaceId: workspaceId,
      sourceObjectId: sourceId,
      property: property,
    );
    await expectLater(
      service.save(
        context: context,
        selectedObjectIds: <int>[duplicateTargetId, duplicateTargetId],
      ),
      throwsArgumentError,
    );

    final source = (await objectStore.listObjects(sourceTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(source.values[property.id]).objectIds,
      <int>[originalTargetId],
    );
    final edges = await objectStore.outgoingRelations(sourceId);
    expect(edges, hasLength(1));
    expect(edges.single.propertyId, property.id);
    expect(edges.single.targetObjectId, originalTargetId);
  });
}
