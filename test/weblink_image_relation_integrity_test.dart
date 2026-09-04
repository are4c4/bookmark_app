import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_index_reconcile_service.dart';
import 'package:bookmark_app/data/relation_index_service.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
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
    required this.integrity,
    required this.reconcile,
  });

  final AppDatabase database;
  final int workspaceId;
  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;
  final RelationMutationService mutations;
  final RelationIntegrityService integrity;
  final RelationIndexReconcileService reconcile;
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
  final integrity = RelationIntegrityService(
    objectStore: objectStore,
    bidirectionalStore: bidirectionalStore,
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
    integrity: integrity,
    reconcile: RelationIndexReconcileService(
      integrityService: integrity,
      indexService: RelationIndexService(objectStore),
    ),
  );
}

Future<ObjectPropertyDefinition> _property(
  ObjectStore store,
  int typeId,
  int propertyId,
) async {
  final type = (await store.getObjectType(typeId))!;
  return type.properties.singleWhere((property) => property.id == propertyId);
}

void main() {
  test('Weblink image Relations enforce single/multi cardinality and target type',
      () async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);

    final weblinkTypeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Weblink',
    );
    final imageTypeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Image',
    );
    final otherTypeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Other',
    );
    final representativeId = await fixture.objectStore.createRelationProperty(
      objectTypeId: weblinkTypeId,
      name: 'Representative image',
      targetObjectTypeId: imageTypeId,
      multiple: false,
    );
    final relatedId = await fixture.objectStore.createRelationProperty(
      objectTypeId: weblinkTypeId,
      name: 'Related images',
      targetObjectTypeId: imageTypeId,
      multiple: true,
    );
    final representative = await _property(
      fixture.objectStore,
      weblinkTypeId,
      representativeId,
    );
    final related = await _property(
      fixture.objectStore,
      weblinkTypeId,
      relatedId,
    );
    final weblinkId = await fixture.objectStore.createObject(
      objectTypeId: weblinkTypeId,
      title: 'Example',
    );
    final firstImageId = await fixture.objectStore.createObject(
      objectTypeId: imageTypeId,
      title: 'Cover',
    );
    final secondImageId = await fixture.objectStore.createObject(
      objectTypeId: imageTypeId,
      title: 'Article image',
    );
    final wrongTargetId = await fixture.objectStore.createObject(
      objectTypeId: otherTypeId,
      title: 'Wrong target',
    );

    await fixture.mutations.setRelation(
      objectId: weblinkId,
      property: representative,
      targetObjectIds: <int>[firstImageId],
    );
    await fixture.mutations.setRelation(
      objectId: weblinkId,
      property: related,
      targetObjectIds: <int>[firstImageId, secondImageId],
    );

    final stored = (await fixture.objectStore.listObjects(weblinkTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(stored.values[representativeId]).objectIds,
      <int>[firstImageId],
    );
    expect(
      ObjectRelationValue.fromJson(stored.values[relatedId]).objectIds,
      <int>[firstImageId, secondImageId],
    );

    expect(
      () => fixture.mutations.setRelation(
        objectId: weblinkId,
        property: representative,
        targetObjectIds: <int>[firstImageId, secondImageId],
      ),
      throwsArgumentError,
    );
    expect(
      () => fixture.mutations.setRelation(
        objectId: weblinkId,
        property: related,
        targetObjectIds: <int>[wrongTargetId],
      ),
      throwsArgumentError,
    );
  });

  test('stale Relation metadata is canonicalized before Weblink image write',
      () async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);

    final weblinkTypeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Weblink',
    );
    final imageTypeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Image',
    );
    final staleTargetTypeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Stale target',
    );
    final propertyId = await fixture.objectStore.createRelationProperty(
      objectTypeId: weblinkTypeId,
      name: 'Representative image',
      targetObjectTypeId: imageTypeId,
      multiple: false,
    );
    final canonical = await _property(
      fixture.objectStore,
      weblinkTypeId,
      propertyId,
    );
    final staleCopy = ObjectPropertyDefinition(
      id: canonical.id,
      objectTypeId: canonical.objectTypeId,
      name: canonical.name,
      type: canonical.type,
      sortOrder: canonical.sortOrder,
      config: <String, dynamic>{
        ...canonical.config,
        'targetObjectTypeId': staleTargetTypeId,
        'multiple': true,
      },
    );
    final weblinkId = await fixture.objectStore.createObject(
      objectTypeId: weblinkTypeId,
      title: 'Example',
    );
    final imageId = await fixture.objectStore.createObject(
      objectTypeId: imageTypeId,
      title: 'Cover',
    );

    await fixture.mutations.setRelation(
      objectId: weblinkId,
      property: staleCopy,
      targetObjectIds: <int>[imageId],
    );

    final stored = (await fixture.objectStore.listObjects(weblinkTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(stored.values[propertyId]).objectIds,
      <int>[imageId],
    );
    expect((await fixture.objectStore.outgoingRelations(weblinkId)), hasLength(1));
  });

  test('audit and index-only reconcile cover Weblink semantic Relations',
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
    final imageTypeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Image',
    );
    final bookmarkLinkId = await fixture.objectStore.createRelationProperty(
      objectTypeId: bookmarkTypeId,
      name: 'Weblink',
      targetObjectTypeId: weblinkTypeId,
      multiple: false,
    );
    final representativeId = await fixture.objectStore.createRelationProperty(
      objectTypeId: weblinkTypeId,
      name: 'Representative image',
      targetObjectTypeId: imageTypeId,
      multiple: false,
    );
    final bookmarkLink = await _property(
      fixture.objectStore,
      bookmarkTypeId,
      bookmarkLinkId,
    );
    final representative = await _property(
      fixture.objectStore,
      weblinkTypeId,
      representativeId,
    );
    final bookmarkId = await fixture.objectStore.createObject(
      objectTypeId: bookmarkTypeId,
      title: 'Bookmark',
    );
    final weblinkId = await fixture.objectStore.createObject(
      objectTypeId: weblinkTypeId,
      title: 'Weblink',
    );
    final imageId = await fixture.objectStore.createObject(
      objectTypeId: imageTypeId,
      title: 'Image',
    );

    await fixture.mutations.setRelation(
      objectId: bookmarkId,
      property: bookmarkLink,
      targetObjectIds: <int>[weblinkId],
    );
    await fixture.mutations.setRelation(
      objectId: weblinkId,
      property: representative,
      targetObjectIds: <int>[imageId],
    );
    expect((await fixture.integrity.auditWorkspace(fixture.workspaceId)).isHealthy,
        isTrue);

    await fixture.database.customStatement(
      'DELETE FROM object_relation_edges WHERE source_object_id = ? AND property_id = ?',
      <Object>[bookmarkId, bookmarkLinkId],
    );

    final before = await fixture.integrity.auditWorkspace(fixture.workspaceId);
    expect(
      before.issuesOf(RelationIntegrityIssueKind.missingIndexEdge),
      hasLength(1),
    );

    final result = await fixture.reconcile.reconcileWorkspace(fixture.workspaceId);
    expect(result.rebuilt, isTrue);
    expect(result.after.isHealthy, isTrue);

    final bookmark = (await fixture.objectStore.listObjects(bookmarkTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(bookmark.values[bookmarkLinkId]).objectIds,
      <int>[weblinkId],
    );
    expect((await fixture.objectStore.backlinks(weblinkId)), hasLength(1));
  });
}
