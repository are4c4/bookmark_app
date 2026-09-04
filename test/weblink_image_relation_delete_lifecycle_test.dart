import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/relation_read_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ObjectPropertyDefinition> _property(
  ObjectStore store,
  int typeId,
  int propertyId,
) async {
  final type = (await store.getObjectType(typeId))!;
  return type.properties.singleWhere((property) => property.id == propertyId);
}

void main() {
  test('deleting Image detaches representative and related Weblink Relations',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final mutations = RelationMutationService(
      objectStore: objectStore,
      bidirectionalStore: bidirectionalStore,
      genericStore: genericStore,
    );
    final reads = RelationReadService(objectStore);

    final weblinkTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Weblink',
    );
    final imageTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Image',
    );
    final representativeId = await objectStore.createRelationProperty(
      objectTypeId: weblinkTypeId,
      name: 'Representative image',
      targetObjectTypeId: imageTypeId,
      multiple: false,
    );
    final relatedId = await objectStore.createRelationProperty(
      objectTypeId: weblinkTypeId,
      name: 'Related images',
      targetObjectTypeId: imageTypeId,
      multiple: true,
    );
    final representative =
        await _property(objectStore, weblinkTypeId, representativeId);
    final related = await _property(objectStore, weblinkTypeId, relatedId);

    final firstWeblinkId = await objectStore.createObject(
      objectTypeId: weblinkTypeId,
      title: 'First Weblink',
    );
    final secondWeblinkId = await objectStore.createObject(
      objectTypeId: weblinkTypeId,
      title: 'Second Weblink',
    );
    final deletedImageId = await objectStore.createObject(
      objectTypeId: imageTypeId,
      title: 'Shared image',
    );
    final survivingImageId = await objectStore.createObject(
      objectTypeId: imageTypeId,
      title: 'Other image',
    );

    await mutations.setRelation(
      objectId: firstWeblinkId,
      property: representative,
      targetObjectIds: <int>[deletedImageId],
    );
    await mutations.setRelation(
      objectId: firstWeblinkId,
      property: related,
      targetObjectIds: <int>[deletedImageId, survivingImageId],
    );
    await mutations.setRelation(
      objectId: secondWeblinkId,
      property: related,
      targetObjectIds: <int>[deletedImageId],
    );

    expect(await objectStore.backlinks(deletedImageId), hasLength(3));
    expect(
      await reads.backlinks(
        workspaceId: workspaceId,
        targetObjectId: deletedImageId,
      ),
      hasLength(3),
    );

    await mutations.deleteObject(
      workspaceId: workspaceId,
      objectTypeId: imageTypeId,
      objectId: deletedImageId,
    );

    final weblinks = await objectStore.listObjects(weblinkTypeId);
    final first = weblinks.singleWhere((item) => item.id == firstWeblinkId);
    final second = weblinks.singleWhere((item) => item.id == secondWeblinkId);
    expect(
      ObjectRelationValue.fromJson(first.values[representativeId]).objectIds,
      isEmpty,
    );
    expect(
      ObjectRelationValue.fromJson(first.values[relatedId]).objectIds,
      <int>[survivingImageId],
    );
    expect(
      ObjectRelationValue.fromJson(second.values[relatedId]).objectIds,
      isEmpty,
    );

    expect(await objectStore.backlinks(deletedImageId), isEmpty);
    expect(
      await reads.backlinks(
        workspaceId: workspaceId,
        targetObjectId: deletedImageId,
      ),
      isEmpty,
    );
    expect(await objectStore.outgoingRelations(secondWeblinkId), isEmpty);
    final firstEdges = await objectStore.outgoingRelations(firstWeblinkId);
    expect(firstEdges, hasLength(1));
    expect(firstEdges.single.targetObjectId, survivingImageId);
    expect(firstEdges.single.propertyId, relatedId);
  });
}
