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

Future<ObjectPropertyDefinition> _property(
  ObjectStore store,
  int typeId,
  int propertyId,
) async {
  final type = (await store.getObjectType(typeId))!;
  return type.properties.singleWhere((property) => property.id == propertyId);
}

void main() {
  test('stale Bookmark Weblink metadata cannot bypass canonical constraints',
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

    final bookmarkTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Bookmark',
    );
    final weblinkTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Weblink',
    );
    final wrongTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Wrong type',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: bookmarkTypeId,
      name: 'Weblink',
      targetObjectTypeId: weblinkTypeId,
      multiple: false,
    );
    final canonical = await _property(objectStore, bookmarkTypeId, relationId);
    final staleCopy = ObjectPropertyDefinition(
      id: canonical.id,
      objectTypeId: canonical.objectTypeId,
      name: canonical.name,
      type: canonical.type,
      sortOrder: canonical.sortOrder,
      config: <String, dynamic>{
        ...canonical.config,
        'targetObjectTypeId': wrongTypeId,
        'multiple': true,
      },
    );

    final bookmarkId = await objectStore.createObject(
      objectTypeId: bookmarkTypeId,
      title: 'Bookmark',
    );
    final firstWeblinkId = await objectStore.createObject(
      objectTypeId: weblinkTypeId,
      title: 'First',
    );
    final secondWeblinkId = await objectStore.createObject(
      objectTypeId: weblinkTypeId,
      title: 'Second',
    );
    final wrongTargetId = await objectStore.createObject(
      objectTypeId: wrongTypeId,
      title: 'Wrong',
    );

    await mutations.setRelation(
      objectId: bookmarkId,
      property: staleCopy,
      targetObjectIds: <int>[firstWeblinkId],
    );

    final stored = (await objectStore.listObjects(bookmarkTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(stored.values[relationId]).objectIds,
      <int>[firstWeblinkId],
    );

    await expectLater(
      mutations.setRelation(
        objectId: bookmarkId,
        property: staleCopy,
        targetObjectIds: <int>[firstWeblinkId, secondWeblinkId],
      ),
      throwsArgumentError,
    );
    await expectLater(
      mutations.setRelation(
        objectId: bookmarkId,
        property: staleCopy,
        targetObjectIds: <int>[wrongTargetId],
      ),
      throwsArgumentError,
    );
  });

  test('ambiguous missing Weblink is audited and reconcile refuses to mutate it',
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
    final integrity = RelationIntegrityService(
      objectStore: objectStore,
      bidirectionalStore: bidirectionalStore,
    );
    final reconcile = RelationIndexReconcileService(
      integrityService: integrity,
      indexService: RelationIndexService(objectStore),
    );

    final bookmarkTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Bookmark',
    );
    final weblinkTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Weblink',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: bookmarkTypeId,
      name: 'Weblink',
      targetObjectTypeId: weblinkTypeId,
      multiple: false,
    );
    final relation = await _property(objectStore, bookmarkTypeId, relationId);
    final bookmarkId = await objectStore.createObject(
      objectTypeId: bookmarkTypeId,
      title: 'Bookmark',
    );
    final weblinkId = await objectStore.createObject(
      objectTypeId: weblinkTypeId,
      title: 'Weblink',
    );

    await mutations.setRelation(
      objectId: bookmarkId,
      property: relation,
      targetObjectIds: <int>[weblinkId],
    );

    // Corruption fixture only: bypass canonical deletion to simulate legacy
    // persisted data whose target disappeared without Relation-safe detach.
    await objectStore.deleteObject(weblinkId);

    final report = await integrity.auditWorkspace(workspaceId);
    expect(
      report.issuesOf(RelationIntegrityIssueKind.missingTargetObject),
      hasLength(1),
    );

    await expectLater(
      reconcile.reconcileWorkspace(workspaceId),
      throwsStateError,
    );

    final bookmark = (await objectStore.listObjects(bookmarkTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(bookmark.values[relationId]).objectIds,
      <int>[weblinkId],
    );
  });
}
