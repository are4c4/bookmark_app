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

class _Fixture {
  _Fixture({
    required this.database,
    required this.workspaceId,
    required this.genericStore,
    required this.objectStore,
    required this.mutations,
    required this.reads,
  });

  final AppDatabase database;
  final int workspaceId;
  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;
  final RelationMutationService mutations;
  final RelationReadService reads;
}

Future<_Fixture> _fixture() async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final workspaceId = await WorkspaceStore(database).initialize();
  final genericStore = GenericDatabaseStore(database);
  final objectStore = ObjectStore(genericStore);
  final bidirectionalStore = BidirectionalRelationStore(
    genericStore: genericStore,
    objectStore: objectStore,
  );
  return _Fixture(
    database: database,
    workspaceId: workspaceId,
    genericStore: genericStore,
    objectStore: objectStore,
    mutations: RelationMutationService(
      objectStore: objectStore,
      bidirectionalStore: bidirectionalStore,
      genericStore: genericStore,
    ),
    reads: RelationReadService(objectStore),
  );
}

Future<ObjectPropertyDefinition> _relationProperty(
  ObjectStore store,
  int objectTypeId,
  int propertyId,
) async {
  final type = (await store.getObjectType(objectTypeId))!;
  return type.properties.singleWhere((property) => property.id == propertyId);
}

void main() {
  test('Bookmark -> Weblink attach is idempotent and shared by many Bookmarks',
      () async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);

    final bookmarkTypeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Bookmark',
    );
    final weblinkTypeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Weblink',
    );
    final relationId = await fixture.objectStore.createRelationProperty(
      objectTypeId: bookmarkTypeId,
      name: 'Weblink',
      targetObjectTypeId: weblinkTypeId,
      multiple: false,
    );
    final relation = await _relationProperty(
      fixture.objectStore,
      bookmarkTypeId,
      relationId,
    );
    final firstBookmarkId = await fixture.objectStore.createObject(
      objectTypeId: bookmarkTypeId,
      title: 'First bookmark',
    );
    final secondBookmarkId = await fixture.objectStore.createObject(
      objectTypeId: bookmarkTypeId,
      title: 'Second bookmark',
    );
    final weblinkId = await fixture.objectStore.createObject(
      objectTypeId: weblinkTypeId,
      title: 'Reusable link',
    );

    await fixture.mutations.setRelation(
      objectId: firstBookmarkId,
      property: relation,
      targetObjectIds: <int>[weblinkId],
    );
    await fixture.mutations.setRelation(
      objectId: firstBookmarkId,
      property: relation,
      targetObjectIds: <int>[weblinkId],
    );
    await fixture.mutations.setRelation(
      objectId: secondBookmarkId,
      property: relation,
      targetObjectIds: <int>[weblinkId],
    );

    final bookmarks = await fixture.objectStore.listObjects(bookmarkTypeId);
    for (final bookmark in bookmarks) {
      expect(
        ObjectRelationValue.fromJson(bookmark.values[relationId]).objectIds,
        <int>[weblinkId],
      );
      final outgoing = await fixture.objectStore.outgoingRelations(bookmark.id);
      expect(outgoing, hasLength(1));
      expect(outgoing.single.targetObjectId, weblinkId);
      expect(outgoing.single.propertyId, relationId);
    }

    final rawBacklinks = await fixture.objectStore.backlinks(weblinkId);
    expect(rawBacklinks, hasLength(2));
    expect(
      rawBacklinks.map((edge) => edge.sourceObjectId).toSet(),
      <int>{firstBookmarkId, secondBookmarkId},
    );

    final resolved = await fixture.reads.backlinks(
      workspaceId: fixture.workspaceId,
      targetObjectId: weblinkId,
    );
    expect(resolved, hasLength(2));
    expect(
      resolved.map((item) => item.sourceObject.id).toSet(),
      <int>{firstBookmarkId, secondBookmarkId},
    );
  });

  test('detach and Weblink deletion keep surviving Bookmark relation state valid',
      () async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);

    final bookmarkTypeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Bookmark',
    );
    final weblinkTypeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Weblink',
    );
    final relationId = await fixture.objectStore.createRelationProperty(
      objectTypeId: bookmarkTypeId,
      name: 'Weblink',
      targetObjectTypeId: weblinkTypeId,
      multiple: false,
    );
    final relation = await _relationProperty(
      fixture.objectStore,
      bookmarkTypeId,
      relationId,
    );
    final detachedBookmarkId = await fixture.objectStore.createObject(
      objectTypeId: bookmarkTypeId,
      title: 'Detached bookmark',
    );
    final survivingBookmarkId = await fixture.objectStore.createObject(
      objectTypeId: bookmarkTypeId,
      title: 'Surviving bookmark',
    );
    final weblinkId = await fixture.objectStore.createObject(
      objectTypeId: weblinkTypeId,
      title: 'Shared link',
    );

    for (final bookmarkId in <int>[detachedBookmarkId, survivingBookmarkId]) {
      await fixture.mutations.setRelation(
        objectId: bookmarkId,
        property: relation,
        targetObjectIds: <int>[weblinkId],
      );
    }

    await fixture.mutations.setRelation(
      objectId: detachedBookmarkId,
      property: relation,
      targetObjectIds: const <int>[],
    );
    expect(await fixture.objectStore.outgoingRelations(detachedBookmarkId), isEmpty);
    expect(await fixture.objectStore.backlinks(weblinkId), hasLength(1));

    await fixture.mutations.deleteObject(
      workspaceId: fixture.workspaceId,
      objectTypeId: weblinkTypeId,
      objectId: weblinkId,
    );

    expect(await fixture.objectStore.listObjects(weblinkTypeId), isEmpty);
    expect(await fixture.objectStore.backlinks(weblinkId), isEmpty);
    expect(await fixture.objectStore.outgoingRelations(survivingBookmarkId), isEmpty);

    final bookmarks = await fixture.objectStore.listObjects(bookmarkTypeId);
    for (final bookmark in bookmarks) {
      expect(
        ObjectRelationValue.fromJson(bookmark.values[relationId]).objectIds,
        isEmpty,
      );
    }
  });
}
